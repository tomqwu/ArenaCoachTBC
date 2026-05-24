-- ArenaCoachTBC - Simulator
--
-- Drives the engine over time with a canned event script. Lets you validate
-- the live UI without queueing an arena: `/acc simulate rmp` sets up the
-- enemy team, schedules each event via C_Timer.After, and the existing
-- Core:Evaluate() pipeline animates the UI second-by-second.
--
-- Pure data + a small dispatch loop. No protected actions.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.Simulator = ns.Simulator or {}

local SIM = ns.Simulator
SIM.scenarios = SIM.scenarios or {}
SIM._timers   = SIM._timers   or {}    -- pending C_Timer.After cancellation tokens

local function chatPrint(msg)
    if ns.Core and ns.Core.L and type(print) == "function" then
        print((ns.Core.L("DEBUG_PREFIX") or "[ACC]") .. " " .. tostring(msg))
    elseif type(print) == "function" then
        print("[ACC] " .. tostring(msg))
    end
end

function SIM:Register(key, scenario)
    assert(type(key) == "string" and #key > 0, "scenario key required")
    assert(type(scenario) == "table", "scenario must be a table")
    assert(type(scenario.enemies) == "table", "scenario.enemies required")
    assert(type(scenario.events)  == "table", "scenario.events required")
    self.scenarios[key] = scenario
end

function SIM:Get(key) return self.scenarios[key] end

function SIM:List()
    local out = {}
    for k in pairs(self.scenarios) do table.insert(out, k) end
    table.sort(out)
    return out
end

-- Build the initial enemy state from the scenario's class list.
local function setupEnemies(scenario)
    if not (ns.Core and ns.Core.state) then return end
    ns.Core.state.enemies = {}
    local list = {}
    for i, class in ipairs(scenario.enemies) do
        local unit = "arena" .. i
        ns.Core.state.enemies[unit] = {
            unit             = unit,
            guid             = "sim-guid-" .. unit,
            name             = class:lower():gsub("^%l", string.upper),
            class            = class,
            specGuess        = nil,
            roleGuess        = nil,
            alive            = true,
            healthPct        = 100,
            manaPct          = 100,
            hasTrinket       = true,
            importantBuffs   = {},
            importantDebuffs = {},
            observedSpells   = {},
            ccDR             = {},
            score            = 0,
        }
        table.insert(list, class)
    end
    ns.Core.state.enemyClassList = list
    ns.Core.state.combatPhase    = "ACTIVE"
end

-- Apply one event to the engine state. Pure function over Core.state.
function SIM:Apply(ev)
    if not (ns.Core and ns.Core.state and ns.Core.state.enemies) then return end
    local function enemyAt(i) return ns.Core.state.enemies["arena" .. tostring(i)] end

    if ev.type == "cast" then
        local e = enemyAt(ev.by)
        if not e then return end
        e.observedSpells[ev.spell] = (e.observedSpells[ev.spell] or 0) + 1
        e.lastCast = ev.spell
        if ns.CooldownTracker and ev.spell then
            ns.CooldownTracker:MarkUsed(e.guid, ev.spell)
        end
        if ns.SpellSpecHints and ev.spell then
            ns.SpellSpecHints:Apply(e, ev.spell)
        end
        if ns.DRTracker and ns.Spells and ns.Spells.CATEGORIES and ev.spell then
            local cat = ns.Spells.CATEGORIES[ev.spell]
            if cat then ns.DRTracker:OnCC("SPELL_AURA_APPLIED", "sim-victim", ev.spell, cat) end
        end
    elseif ev.type == "aura" then
        local e = enemyAt(ev.on)
        if e and ev.spell then e.importantBuffs[ev.spell] = true end
    elseif ev.type == "aura_off" then
        local e = enemyAt(ev.on)
        if e and ev.spell then e.importantBuffs[ev.spell] = nil end
    elseif ev.type == "trinket" then
        local e = enemyAt(ev.unit)
        if e then e.hasTrinket = false end
    elseif ev.type == "health" then
        local e = enemyAt(ev.unit)
        if e then e.healthPct = ev.pct end
    elseif ev.type == "kill" then
        local e = enemyAt(ev.unit)
        if e then e.alive = false; e.healthPct = 0 end
    end
end

function SIM:Stop()
    -- Best-effort cancel of pending timers. C_Timer.After does not expose a
    -- cancel handle in TBC client, so we set a generation counter; pending
    -- callbacks compare it and bail out if Stop has fired.
    self._gen = (self._gen or 0) + 1
    self._timers = {}
end

-- Internal: schedule the events on a real timer when available, otherwise
-- apply them synchronously. Returns the table of "fired" events for tests.
function SIM:_dispatch(scenario, opts)
    opts = opts or {}
    local gen = (self._gen or 0) + 1
    self._gen = gen
    local fired = {}

    local function fire(ev)
        if self._gen ~= gen then return end
        self:Apply(ev)
        table.insert(fired, ev)
        if opts.printEvents then
            chatPrint(string.format("[%4.1fs] %s",
                ev.t or 0,
                ev.label or (ev.type .. " " .. tostring(ev.spell or ev.unit or ""))))
        end
        if ns.Core and ns.Core.Evaluate then ns.Core:Evaluate() end
    end

    local haveTimer = (type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function")
    for _, ev in ipairs(scenario.events) do
        if haveTimer and not opts.sync then
            local t = math.max(0, tonumber(ev.t) or 0)
            _G.C_Timer.After(t, function() fire(ev) end)
        else
            fire(ev)
        end
    end
    return fired
end

-- Run a scenario by key. Returns (ok, error_message).
function SIM:Run(key, opts)
    opts = opts or {}
    local scenario = self.scenarios[key]
    if not scenario then return false, "unknown scenario: " .. tostring(key) end

    self:Stop()  -- cancel any prior simulation
    setupEnemies(scenario)
    if ns.Core and ns.Core.Evaluate then ns.Core:Evaluate() end  -- show initial state

    opts.printEvents = opts.printEvents ~= false
    if opts.printEvents then
        chatPrint("Simulating: " .. (scenario.label or key))
    end
    self:_dispatch(scenario, opts)
    return true
end
