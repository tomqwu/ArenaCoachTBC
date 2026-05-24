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
    },
    debug = false,
}

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
    lastPrimaryGUID = nil,
}

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
    for _, u in ipairs(units) do
        local model = self.state.friendlies[u] or newFriendly(u)
        refreshUnit(model, u)
        self.state.friendlies[u] = model
    end
end

-- ============================================================
-- Evaluate + publish
-- ============================================================
function Core:Evaluate()
    if not _G.ArenaCoachTBCDB or _G.ArenaCoachTBCDB.enabled == false then
        return
    end
    self.state.config = _G.ArenaCoachTBCDB
    local rec = ns.StrategyEngine and ns.StrategyEngine:Evaluate(self.state) or nil
    if not rec then return end
    self.state.lastPrimaryGUID = rec.primaryTarget
    if ns.UI then ns.UI:Apply(rec) end
    if ns.WeakAuraBridge then ns.WeakAuraBridge:Publish(rec, self.state) end
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

    -- Trinket tracking
    if subEvent == "SPELL_AURA_APPLIED" and spellID == 42292 then
        -- mark target's trinket gone
        for _, e in pairs(Core.state.enemies or {}) do
            if e.guid == destGUID then e.hasTrinket = false end
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
    else
        chatPrint(Core.L("DEBUG_UNKNOWN_CMD"))
    end
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
    if ns.UI and not ns.UI.frame then ns.UI:CreateFrame() end
    if ns.Spells and ns.Spells.RefreshNames then ns.Spells:RefreshNames() end
    Core:Evaluate()
end

local function onArenaOpponentUpdate()
    Core:RefreshArenaEnemies()
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
