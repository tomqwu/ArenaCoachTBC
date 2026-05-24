-- ArenaCoachTBC - Core
-- Wires the modules together:
--   - Initializes SavedVariables on PLAYER_LOGIN
--   - Subscribes to WoW events via EventBus
--   - Maintains live enemy/friendly state tables
--   - Drives StrategyEngine:Evaluate() on relevant events
--   - Pushes results into UI + WeakAuraBridge
--
-- Important: no protected actions. We never call CastSpellByName for the
-- player, never target enemies automatically, never modify macros in combat.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.Core = ns.Core or {}

local Core = ns.Core

-- ============================================================
-- SavedVariables defaults
-- ============================================================
local DEFAULTS = {
    enabled  = true,
    locked   = false,
    language = "auto",
    ownComp  = "WAR_ENH_RET_RDUID_DISC",
    frame    = { point = "CENTER", x = 0, y = 120, scale = 1.0 },
    alerts   = { sound = true, raidWarning = false, partyChat = false, screenFlash = true },
    strategy = {
        aggression = "balanced",
        preferHealerOpen = true,
        allowDpsSwap = true,
        callBurstOnlyWhenMSActive = true,
        requireWindfuryNearby = true,
        peelTriggerWindow = 5,    -- seconds of sliding window for "trained" detection
        peelTriggerDamage = 3,    -- damage events in window to force DEFEND
    },
    trace = {
        enabled  = false,
        maxLines = 200,
        log      = {},
    },
    debug = false,
}

local TRACE_DEFAULT_CAP = 200

local function appendTrace(rec, state)
    local db = _G.ArenaCoachTBCDB
    if not (db and db.trace and db.trace.enabled and rec) then return end
    db.trace.log = db.trace.log or {}
    local cap = db.trace.maxLines or TRACE_DEFAULT_CAP
    local snapshot = {
        ts             = (type(GetTime) == "function") and GetTime() or os.time(),
        mode           = rec.mode,
        primaryClass   = rec.primaryTargetClass,
        primaryName    = rec.primaryTargetName,
        secondaryClass = rec.secondaryTargetClass,
        reason         = rec.reason,
        confidence     = rec.confidence,
        priority       = rec.priority,
        comp           = rec.comp,
        ownArchetype   = rec.ownArchetype,
        bracket        = state and state.bracket,
        combatPhase    = state and state.combatPhase,
        callouts       = rec.callouts and table.concat(rec.callouts, ",") or "",
    }
    table.insert(db.trace.log, snapshot)
    while #db.trace.log > cap do table.remove(db.trace.log, 1) end
end

local function deepMerge(dest, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dest[k]) ~= "table" then dest[k] = {} end
            deepMerge(dest[k], v)
        elseif dest[k] == nil then
            dest[k] = v
        end
    end
end

function Core:InitDB()
    _G.ArenaCoachTBCDB = _G.ArenaCoachTBCDB or {}
    deepMerge(_G.ArenaCoachTBCDB, DEFAULTS)
    return _G.ArenaCoachTBCDB
end

-- ============================================================
-- Localization
-- ============================================================
function Core:CurrentLocale()
    local db = _G.ArenaCoachTBCDB or {}
    local lang = db.language or "auto"
    if lang == "auto" and type(GetLocale) == "function" then
        lang = GetLocale()
    end
    return lang
end

function Core.L(key)
    local lang = Core:CurrentLocale()
    local locales = ns.locales or {}
    local table_ = locales[lang] or locales.enUS
    if table_ and table_[key] then return table_[key] end
    if locales.enUS and locales.enUS[key] then return locales.enUS[key] end
    return key
end

-- ============================================================
-- Debug
-- ============================================================
function Core.DebugPrint(msg)
    local db = _G.ArenaCoachTBCDB
    if db and db.debug and type(print) == "function" then
        print((Core.L("DEBUG_PREFIX") or "[ACC]") .. " " .. tostring(msg))
    end
end

local function chatPrint(msg)
    if type(print) == "function" then
        print((Core.L("DEBUG_PREFIX") or "[ACC]") .. " " .. tostring(msg))
    end
end

-- ============================================================
-- State
-- ============================================================
Core.state = {
    enemies        = {},
    friendlies     = {},
    observations   = {},
    config         = nil,    -- bound to SavedVariables on init
    enemyClassList = {},
    combatPhase    = "PRE",  -- PRE, ACTIVE, POST
    bracket        = 5,      -- 2 | 3 | 5; engine uses for comp filter + weights
    lastPrimaryGUID = nil,
}

-- Train-detection: ring of damage event timestamps against friendlies in the
-- last TRAIN_WINDOW seconds. When count exceeds TRAIN_THRESHOLD, the engine
-- forces DEFEND. Configurable via db.strategy.peelTriggerWindow / peelTriggerDamage.
Core._friendlyGUIDs    = {}  -- guid -> true
Core._friendlyDamageTs = {}  -- list of timestamps

local function pruneFriendlyDamage(now, window)
    local cutoff = (now or 0) - (window or 5)
    while #Core._friendlyDamageTs > 0 and Core._friendlyDamageTs[1] < cutoff do
        table.remove(Core._friendlyDamageTs, 1)
    end
end

-- Read the current arena bracket from the WoW battlefield API.
-- Returns 2/3/5 if in an arena queue or active arena; falls back to the
-- previously known bracket (default 5) when no battlefield is active.
function Core:UpdateBracket()
    local prev = self.state.bracket or 5
    if type(GetMaxBattlefieldID) ~= "function" or type(GetBattlefieldStatus) ~= "function" then
        return prev
    end
    for i = 1, GetMaxBattlefieldID() do
        local status, _mapName, _instanceID, _minLvl, _maxLvl, teamSize = GetBattlefieldStatus(i)
        if (status == "active" or status == "confirm") and teamSize and teamSize > 0 then
            self.state.bracket = teamSize
            return teamSize
        end
    end
    return prev
end

-- ============================================================
-- Build / update enemy & friendly tables from arena units
-- ============================================================
local function classToken(class)
    if not class then return nil end
    return class:upper()
end

local function newEnemy(unit)
    return {
        unit             = unit,
        guid             = nil,
        name             = nil,
        class            = nil,
        specGuess        = nil,
        roleGuess        = nil,
        alive            = true,
        healthPct        = 100,
        manaPct          = 100,
        hasTrinket       = true,
        importantBuffs   = {},
        importantDebuffs = {},
        observedSpells   = {},
        lastCast         = nil,
        ccDR             = {},
        score            = 0,
    }
end

local function newFriendly(unit)
    return {
        unit       = unit,
        class      = nil,
        spec       = nil,
        alive      = true,
        healthPct  = 100,
        manaPct    = nil,
        cooldowns  = {},
        buffs      = {},
        debuffs    = {},
    }
end

local function pct(cur, max)
    if not cur or not max or max == 0 then return 100 end
    return math.floor((cur / max) * 100 + 0.5)
end

local function refreshUnit(model, unit)
    if not unit or type(UnitExists) ~= "function" then return end
    if not UnitExists(unit) then
        model.alive = false
        return
    end
    if type(UnitGUID) == "function" then model.guid = UnitGUID(unit) end
    if type(UnitName) == "function" then model.name = UnitName(unit) end
    if type(UnitClass) == "function" then
        local _, classFile = UnitClass(unit)
        if classFile then model.class = classToken(classFile) end
    end
    if type(UnitHealth) == "function" and type(UnitHealthMax) == "function" then
        model.healthPct = pct(UnitHealth(unit), UnitHealthMax(unit))
    end
    if type(UnitPower) == "function" and type(UnitPowerMax) == "function" then
        local pm = UnitPowerMax(unit) or 0
        if pm > 0 then model.manaPct = pct(UnitPower(unit), pm) else model.manaPct = nil end
    end
    if type(UnitIsDeadOrGhost) == "function" then
        model.alive = not UnitIsDeadOrGhost(unit)
    end
end

function Core:RefreshArenaEnemies()
    if type(UnitExists) ~= "function" then return end
    self.state.enemies = self.state.enemies or {}
    for i = 1, 5 do
        local unit = "arena" .. i
        local model = self.state.enemies[unit] or newEnemy(unit)
        refreshUnit(model, unit)
        self.state.enemies[unit] = model
    end
    -- Rebuild class list
    local list = {}
    for _, e in pairs(self.state.enemies) do
        if e.class then table.insert(list, e.class) end
    end
    self.state.enemyClassList = list
end

function Core:RefreshFriendlies()
    if type(UnitExists) ~= "function" then return end
    local units = { "player", "party1", "party2", "party3", "party4" }
    self.state.friendlies = self.state.friendlies or {}
    local guids = {}
    for _, u in ipairs(units) do
        local model = self.state.friendlies[u] or newFriendly(u)
        refreshUnit(model, u)
        self.state.friendlies[u] = model
        if model.guid then guids[model.guid] = true end
    end
    Core._friendlyGUIDs = guids
end

-- ============================================================
-- Evaluate + publish
-- ============================================================
function Core:Evaluate()
    if not _G.ArenaCoachTBCDB or _G.ArenaCoachTBCDB.enabled == false then
        return
    end
    self.state.config = _G.ArenaCoachTBCDB
    -- Refresh train-detection signal before scoring.
    local now = (type(GetTime) == "function") and GetTime() or 0
    local strat = (_G.ArenaCoachTBCDB.strategy) or {}
    local window    = strat.peelTriggerWindow or 5
    local threshold = strat.peelTriggerDamage or 3
    pruneFriendlyDamage(now, window)
    self.state.observations = self.state.observations or {}
    self.state.observations.healerUnderPressure = (#Core._friendlyDamageTs >= threshold)

    local rec = ns.StrategyEngine and ns.StrategyEngine:Evaluate(self.state) or nil
    if not rec then return end
    self.state.lastPrimaryGUID = rec.primaryTarget
    if ns.UI then ns.UI:Apply(rec) end
    if ns.WeakAuraBridge then ns.WeakAuraBridge:Publish(rec, self.state) end
    appendTrace(rec, self.state)
    Core.DebugPrint(string.format(
        "Evaluate -> mode=%s target=%s comp=%s own=%s conf=%.2f",
        tostring(rec.mode), tostring(rec.primaryTargetClass),
        tostring(rec.comp), tostring(rec.ownArchetype), rec.confidence or 0))
    return rec
end

-- ============================================================
-- Combat log parsing
-- ============================================================
local function onCLEU()
    if type(CombatLogGetCurrentEventInfo) ~= "function" then return end
    local ts, subEvent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _,
          spellID, spellName = CombatLogGetCurrentEventInfo()
    if not subEvent then return end

    -- Cooldown tracking
    if ns.CooldownTracker then
        ns.CooldownTracker:OnCombatLogEvent(subEvent, sourceGUID, destGUID, spellID)
    end

    -- DR tracking
    if ns.DRTracker and ns.Spells and ns.Spells.CATEGORIES then
        local category = ns.Spells.CATEGORIES[spellID]
        if category then ns.DRTracker:OnCC(subEvent, destGUID, spellID, category, ts) end
    end

    -- Train detection: collect damage events landing on our friendlies.
    -- Pruned to the configured window in Evaluate.
    if subEvent and Core._friendlyGUIDs[destGUID]
       and (subEvent:find("_DAMAGE$") or subEvent == "SWING_DAMAGE") then
        table.insert(Core._friendlyDamageTs, ts or 0)
    end

    -- Trinket tracking
    if subEvent == "SPELL_AURA_APPLIED" and spellID == 42292 then
        -- mark target's trinket gone
        for _, e in pairs(Core.state.enemies or {}) do
            if e.guid == destGUID then e.hasTrinket = false end
        end
    end

    -- Spec inference from observed casts
    if subEvent == "SPELL_CAST_SUCCESS" and ns.SpellSpecHints then
        for _, e in pairs(Core.state.enemies or {}) do
            if e.guid == sourceGUID then
                ns.SpellSpecHints:Apply(e, spellID)
                break
            end
        end
    end

    -- Immunity / major defensives book-keeping on auras
    if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH" then
        for _, e in pairs(Core.state.enemies or {}) do
            if e.guid == destGUID then e.importantBuffs[spellID] = true end
        end
    elseif subEvent == "SPELL_AURA_REMOVED" then
        for _, e in pairs(Core.state.enemies or {}) do
            if e.guid == destGUID then e.importantBuffs[spellID] = nil end
        end
    end

    -- Re-evaluate cheaply on impactful events
    if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REMOVED"
       or subEvent == "UNIT_DIED" or subEvent == "SPELL_CAST_SUCCESS" then
        Core:Evaluate()
    end
end

-- ============================================================
-- Slash command handler
-- ============================================================
local function helpText()
    chatPrint(Core.L("HELP_HEADER"))
    chatPrint(Core.L("HELP_TOGGLE"))
    chatPrint(Core.L("HELP_LOCK"))
    chatPrint(Core.L("HELP_TEST"))
    chatPrint(Core.L("HELP_DEBUG"))
    chatPrint(Core.L("HELP_RESET"))
    chatPrint(Core.L("HELP_STRAT"))
    chatPrint(Core.L("HELP_ENEMY"))
    chatPrint(Core.L("HELP_SELFTEST"))
    chatPrint(Core.L("HELP_SIMULATE"))
    chatPrint(Core.L("HELP_TRACE"))
    chatPrint(Core.L("HELP_HELP"))
end

local function trim(s) return (s or ""):match("^%s*(.-)%s*$") end

local function handleSlash(input)
    local db = _G.ArenaCoachTBCDB
    if not db then Core:InitDB(); db = _G.ArenaCoachTBCDB end
    input = trim(input or "")
    if input == "" or input == "help" then return helpText() end

    local cmd, rest = input:match("^(%S+)%s*(.*)$")
    cmd = (cmd or ""):lower()

    if cmd == "toggle" then
        if ns.UI then ns.UI:Toggle() end
    elseif cmd == "lock" then
        db.locked = true; chatPrint("frame locked")
    elseif cmd == "unlock" then
        db.locked = false; chatPrint("frame unlocked")
    elseif cmd == "debug" then
        db.debug = not db.debug
        chatPrint(db.debug and Core.L("DEBUG_ENABLED") or Core.L("DEBUG_DISABLED"))
    elseif cmd == "reset" then
        _G.ArenaCoachTBCDB = nil
        chatPrint(Core.L("DEBUG_RESET_DONE"))
    elseif cmd == "strategy" then
        local mode = (rest or ""):lower()
        if mode == "safe" or mode == "balanced" or mode == "greedy" then
            db.strategy = db.strategy or {}
            db.strategy.aggression = mode
            chatPrint(string.format(Core.L("DEBUG_STRAT_SET"), mode))
        else
            chatPrint("usage: /acc strategy safe|balanced|greedy")
        end
    elseif cmd == "test" then
        Core:RunTestMode()
    elseif cmd == "enemy" then
        Core:RunEnemySim(rest)
    elseif cmd == "selftest" then
        Core:RunSelfTest((rest or ""):lower() == "verbose")
    elseif cmd == "simulate" then
        Core:RunSimulator(rest)
    elseif cmd == "trace" then
        Core:HandleTrace(rest)
    else
        chatPrint(Core.L("DEBUG_UNKNOWN_CMD"))
    end
end

function Core:HandleTrace(rest)
    local db = _G.ArenaCoachTBCDB
    if not db then Core:InitDB(); db = _G.ArenaCoachTBCDB end
    db.trace = db.trace or { enabled = false, maxLines = 200, log = {} }
    local arg = ((rest or ""):match("^%S*") or ""):lower()
    if arg == "" or arg == "status" then
        chatPrint(string.format("trace: %s (%d entries, cap %d)",
            db.trace.enabled and "ON" or "OFF",
            #(db.trace.log or {}),
            db.trace.maxLines or 200))
    elseif arg == "on" then
        db.trace.enabled = true
        chatPrint("trace ON (cap " .. (db.trace.maxLines or 200) .. ")")
    elseif arg == "off" then
        db.trace.enabled = false
        chatPrint("trace OFF")
    elseif arg == "clear" then
        db.trace.log = {}
        chatPrint("trace log cleared")
    elseif arg == "dump" then
        local log = db.trace.log or {}
        local last = log[#log]
        if not last then chatPrint("trace log is empty"); return end
        chatPrint(string.format(
            "trace[%d]: mode=%s target=%s reason=%s comp=%s bracket=%s callouts=[%s]",
            #log, tostring(last.mode), tostring(last.primaryClass),
            tostring(last.reason), tostring(last.comp),
            tostring(last.bracket), tostring(last.callouts)))
    else
        chatPrint("usage: /acc trace on|off|status|dump|clear")
    end
end

function Core:RunSimulator(rest)
    local SIM = ns.Simulator
    if not SIM then chatPrint("Simulator module not loaded"); return end
    local arg = (rest or ""):match("^%S*") or ""
    arg = arg:lower()
    if arg == "" or arg == "list" then
        chatPrint(Core.L("SIMULATE_HEADER"))
        for _, key in ipairs(SIM:List()) do
            local s = SIM:Get(key)
            chatPrint(string.format("  %s - %s", key, (s and s.label) or "?"))
        end
        return
    end
    if arg == "stop" then
        SIM:Stop()
        chatPrint(Core.L("SIMULATE_STOPPED") or "simulation stopped")
        return
    end
    local ok, err = SIM:Run(arg)
    if not ok then chatPrint(err or "simulation failed") end
end

function Core:RunSelfTest(verbose)
    local ST = ns.SelfTest
    if not ST then chatPrint("SelfTest module not loaded"); return end
    if ST.RegisterDefaults and (#ST.checks == 0) then ST:RegisterDefaults() end
    chatPrint(Core.L("SELFTEST_HEADER"))
    return ST:Run(verbose, chatPrint)
end

-- ============================================================
-- Test mode
-- ============================================================
local function recToString(rec)
    if not rec then return "(no recommendation)" end
    return string.format("mode=%s target=%s reason=%s conf=%.2f priority=%s",
        tostring(rec.mode), tostring(rec.primaryTargetClass or "?"),
        tostring(rec.reason), rec.confidence or 0, tostring(rec.priority))
end

function Core:RunTestMode()
    local Strategies = ns.Strategies
    local SE = ns.StrategyEngine
    if not Strategies or not SE then return end
    chatPrint(Core.L("TEST_HEADER"))
    for i, c in ipairs(Strategies.testComps) do
        chatPrint(string.format(Core.L("TEST_COMP_LABEL"), i, c.label))
        local state = SE:BuildTestState(c.classes)
        local rec = SE:Evaluate(state)
        chatPrint("  " .. recToString(rec))
        if ns.UI then ns.UI:Apply(rec) end
        if ns.WeakAuraBridge then ns.WeakAuraBridge:Publish(rec, ns.Core.state) end
    end
end

function Core:RunEnemySim(rest)
    local SE = ns.StrategyEngine
    local Classes = ns.Classes
    if not SE or not Classes then return end
    local classes = {}
    for token in (rest or ""):gmatch("%S+") do
        local cls = Classes:TokenToClass(token)
        if cls then table.insert(classes, cls) end
    end
    if #classes == 0 then
        chatPrint("usage: /acc enemy war mage priest druid paladin")
        return
    end
    local state = SE:BuildTestState(classes)
    local rec = SE:Evaluate(state)
    chatPrint("sim: " .. recToString(rec))
    if ns.UI then ns.UI:Apply(rec) end
    if ns.WeakAuraBridge then ns.WeakAuraBridge:Publish(rec, ns.Core.state) end
end

-- ============================================================
-- WoW event handlers
-- ============================================================
local function onPlayerEnteringWorld()
    Core:InitDB()
    Core:RefreshFriendlies()
    Core:UpdateBracket()
    if ns.UI and not ns.UI.frame then ns.UI:CreateFrame() end
    if ns.Spells and ns.Spells.RefreshNames then ns.Spells:RefreshNames() end
    Core:Evaluate()
end

local function onArenaOpponentUpdate()
    Core:RefreshArenaEnemies()
    Core:UpdateBracket()
    -- Phase transitions: we go PRE -> ACTIVE on first enemy seen
    Core.state.combatPhase = "ACTIVE"
    Core:Evaluate()
end

local function onGroupRosterUpdate()
    Core:RefreshFriendlies()
    Core:Evaluate()
end

local function onUnitAura(_, unit)
    if not unit then return end
    -- Re-evaluate cheaply (event-throttled by WoW itself)
    if unit:match("^arena") or unit == "player" or unit:match("^party") then
        Core:Evaluate()
    end
end

local function onRegenDisabled()
    Core.state.combatPhase = "ACTIVE"
    Core:Evaluate()
end

local function onRegenEnabled()
    Core.state.combatPhase = "POST"
end

local function onSpellSucceeded(_, unit, _, spellID)
    if not unit then return end
    if unit:match("^arena") and ns.CooldownTracker then
        local guid = (type(UnitGUID) == "function") and UnitGUID(unit) or nil
        if guid and spellID then
            ns.CooldownTracker:MarkUsed(guid, spellID)
        end
    end
end

-- ============================================================
-- Bootstrap
-- ============================================================
function Core:Boot()
    local EB = ns.EventBus
    if not EB then return end

    EB:Subscribe("PLAYER_LOGIN",          onPlayerEnteringWorld)
    EB:Subscribe("PLAYER_ENTERING_WORLD", onPlayerEnteringWorld)
    EB:Subscribe("ARENA_OPPONENT_UPDATE", onArenaOpponentUpdate)
    EB:Subscribe("GROUP_ROSTER_UPDATE",   onGroupRosterUpdate)
    EB:Subscribe("UPDATE_BATTLEFIELD_STATUS", function() Core:UpdateBracket() end)
    EB:Subscribe("UNIT_AURA",             onUnitAura)
    EB:Subscribe("PLAYER_REGEN_DISABLED", onRegenDisabled)
    EB:Subscribe("PLAYER_REGEN_ENABLED",  onRegenEnabled)
    EB:Subscribe("UNIT_SPELLCAST_SUCCEEDED", onSpellSucceeded)
    EB:Subscribe("COMBAT_LOG_EVENT_UNFILTERED", onCLEU)

    -- Slash commands
    if type(SlashCmdList) == "table" then
        _G.SLASH_ARENACOACH1 = "/acc"
        _G.SLASH_ARENACOACH2 = "/arenacoach"
        SlashCmdList["ARENACOACH"] = handleSlash
    end

    if ns.Options and ns.Options.BuildPanel then ns.Options:BuildPanel() end
end

-- Auto-boot when loaded inside WoW. When loaded in tests, this is harmless
-- because EventBus is no-op without CreateFrame.
Core:Boot()
