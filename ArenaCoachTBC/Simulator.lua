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

local function shallowCopy(src)
    local out = {}
    for k, v in pairs(src or {}) do out[k] = v end
    return out
end

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
    for i, entry in ipairs(scenario.enemies) do
        local class = (type(entry) == "table" and entry.class) or entry
        local unit = "arena" .. i
        ns.Core.state.enemies[unit] = {
            unit             = unit,
            guid             = (type(entry) == "table" and entry.guid) or ("sim-guid-" .. unit),
            name             = (type(entry) == "table" and entry.name) or class:lower():gsub("^%l", string.upper),
            class            = class,
            specGuess        = type(entry) == "table" and entry.specGuess or nil,
            roleGuess        = type(entry) == "table" and entry.roleGuess or nil,
            alive            = type(entry) ~= "table" or entry.alive ~= false,
            healthPct        = (type(entry) == "table" and entry.healthPct) or 100,
            manaPct          = (type(entry) == "table" and entry.manaPct) or 100,
            hasTrinket       = type(entry) ~= "table" or entry.hasTrinket ~= false,
            importantBuffs   = shallowCopy(type(entry) == "table" and entry.importantBuffs or nil),
            importantDebuffs = shallowCopy(type(entry) == "table" and entry.importantDebuffs or nil),
            observedSpells   = shallowCopy(type(entry) == "table" and entry.observedSpells or nil),
            ccDR             = {},
            score            = 0,
        }
        table.insert(list, class)
    end
    ns.Core.state.enemyClassList = list
    ns.Core.state.combatPhase    = scenario.combatPhase or "ACTIVE"
    ns.Core.state.pvpContext     = scenario.context or "arena"
    ns.Core.state.bracket        = scenario.bracket or #scenario.enemies
    ns.Core.state.simulatorActive = true
    ns.Core.state.observations   = shallowCopy(scenario.observations or {
        windfuryActive = true,
        hojReady = true,
    })
    ns.Core._friendlyDamageTs = {}
end

local function setupFriendlies(scenario)
    if not (ns.Core and ns.Core.state) then return end
    local out = {}
    local source = scenario.friendlies

    if not source and ns.StrategyEngine and ns.StrategyEngine.DefaultFriendlies then
        source = ns.StrategyEngine:DefaultFriendlies()
    end

    for i, entry in pairs(source or {}) do
        local model = shallowCopy(entry)
        model.unit = model.unit or (i == 1 and "player" or ("party" .. tostring(i - 1)))
        model.guid = model.guid or ("sim-friendly-" .. tostring(model.unit))
        model.alive = model.alive ~= false
        model.healthPct = model.healthPct or 100
        model.cooldowns = shallowCopy(model.cooldowns)
        model.buffs = shallowCopy(model.buffs)
        model.debuffs = shallowCopy(model.debuffs)
        out[model.unit] = model
    end

    ns.Core.state.friendlies = out
    ns.Core._friendlyGUIDs = {}
    for _, f in pairs(out) do
        if f.guid then ns.Core._friendlyGUIDs[f.guid] = f end
    end
end

local function friendlyAt(unit)
    if not (ns.Core and ns.Core.state and ns.Core.state.friendlies) then return nil end
    if type(unit) == "number" then
        unit = (unit == 1) and "player" or ("party" .. tostring(unit - 1))
    end
    return ns.Core.state.friendlies[unit]
end

local function markFriendlyDebuff(f, spell)
    if not f then return end
    f.debuffs = f.debuffs or {}
    local cat = spell and ns.Spells and ns.Spells.CATEGORIES and ns.Spells.CATEGORIES[spell]
    if cat == "STUN" then f.debuffs.stunned = true
    elseif cat == "FEAR" then f.debuffs.feared = true
    elseif cat == "INCAPACITATE" then f.debuffs.sheeped = true
    elseif cat == "DISORIENT" then f.debuffs.disoriented = true
    elseif cat == "ROOT" then f.debuffs.rooted = true end
    if ns.Spells and (spell == ns.Spells.COUNTERSPELL or spell == ns.Spells.SPELL_LOCK) then
        f.debuffs.silenced = true
    end
end

local function clearFriendlyDebuff(f, spell)
    if not (f and f.debuffs) then return end
    local cat = spell and ns.Spells and ns.Spells.CATEGORIES and ns.Spells.CATEGORIES[spell]
    if cat == "STUN" then f.debuffs.stunned = nil
    elseif cat == "FEAR" then f.debuffs.feared = nil
    elseif cat == "INCAPACITATE" then f.debuffs.sheeped = nil
    elseif cat == "DISORIENT" then f.debuffs.disoriented = nil
    elseif cat == "ROOT" then f.debuffs.rooted = nil end
    if ns.Spells and (spell == ns.Spells.COUNTERSPELL or spell == ns.Spells.SPELL_LOCK) then
        f.debuffs.silenced = nil
    end
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
    elseif ev.type == "debuff" then
        local e = enemyAt(ev.on or ev.unit)
        if e and ev.spell then
            e.importantDebuffs[ev.spell] = true
            if ns.Spells and ev.spell == ns.Spells.MORTAL_STRIKE then
                ns.Core.state.observations = ns.Core.state.observations or {}
                ns.Core.state.observations.msActiveOn = e.guid
            end
        end
    elseif ev.type == "debuff_off" then
        local e = enemyAt(ev.on or ev.unit)
        if e and ev.spell then
            e.importantDebuffs[ev.spell] = nil
            if ns.Spells and ev.spell == ns.Spells.MORTAL_STRIKE
               and ns.Core.state.observations then
                ns.Core.state.observations.msActiveOn = nil
            end
        end
    elseif ev.type == "trinket" then
        local e = enemyAt(ev.unit)
        if e then e.hasTrinket = false end
    elseif ev.type == "health" then
        local e = enemyAt(ev.unit)
        if e then e.healthPct = ev.pct end
    elseif ev.type == "friendly_health" then
        local f = friendlyAt(ev.unit)
        if f then f.healthPct = ev.pct end
    elseif ev.type == "friendly_debuff" then
        markFriendlyDebuff(friendlyAt(ev.unit), ev.spell)
    elseif ev.type == "friendly_debuff_off" then
        clearFriendlyDebuff(friendlyAt(ev.unit), ev.spell)
    elseif ev.type == "damage" then
        local f = friendlyAt(ev.on or ev.unit)
        if f and ev.pct then f.healthPct = ev.pct end
        local hits = tonumber(ev.hits) or 1
        for _ = 1, hits do table.insert(ns.Core._friendlyDamageTs, ev.t or 0) end
        ns.Core.state.observations = ns.Core.state.observations or {}
        local strat = (_G.ArenaCoachTBCDB and _G.ArenaCoachTBCDB.strategy) or {}
        ns.Core.state.observations.healerUnderPressure =
            #ns.Core._friendlyDamageTs >= (strat.peelTriggerDamage or 3)
    elseif ev.type == "clear_pressure" then
        ns.Core._friendlyDamageTs = {}
        ns.Core.state.observations = ns.Core.state.observations or {}
        ns.Core.state.observations.healerUnderPressure = false
    elseif ev.type == "observation" then
        ns.Core.state.observations = ns.Core.state.observations or {}
        ns.Core.state.observations[ev.key] = ev.value
    elseif ev.type == "phase" then
        ns.Core.state.combatPhase = ev.phase or ns.Core.state.combatPhase
    elseif ev.type == "kill" then
        local e = enemyAt(ev.unit)
        if e then e.alive = false; e.healthPct = 0 end
    elseif ev.type == "reset" then
        ns.Core.state.enemies = {}
        ns.Core.state.enemyClassList = {}
        ns.Core.state.combatPhase = "POST"
        ns.Core._friendlyDamageTs = {}
        ns.Core.state.observations = {}
    end
end

function SIM:Stop()
    -- Best-effort cancel of pending timers. C_Timer.After does not expose a
    -- cancel handle in TBC client, so we set a generation counter; pending
    -- callbacks compare it and bail out if Stop has fired.
    self._gen = (self._gen or 0) + 1
    self._timers = {}
    if ns.Core and ns.Core.state then ns.Core.state.simulatorActive = false end
end

local function maxEventTime(scenario)
    local maxT = 0
    for _, ev in ipairs(scenario.events or {}) do
        local t = tonumber(ev.t) or 0
        if t > maxT then maxT = t end
    end
    return maxT
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
    setupFriendlies(scenario)
    if ns.Core and ns.Core.Evaluate then ns.Core:Evaluate() end  -- show initial state

    opts.printEvents = opts.printEvents ~= false
    if opts.printEvents then
        chatPrint("Simulating: " .. (scenario.label or key))
    end
    self:_dispatch(scenario, opts)
    local runGen = self._gen
    local function finish()
        if self._gen == runGen and ns.Core and ns.Core.state then
            ns.Core.state.simulatorActive = false
        end
    end
    local haveTimer = (type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function")
    if haveTimer and not opts.sync then
        _G.C_Timer.After(maxEventTime(scenario) + 0.5, finish)
    else
        finish()
    end
    return true
end
