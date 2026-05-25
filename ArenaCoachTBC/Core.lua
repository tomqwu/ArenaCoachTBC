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
    frame    = { point = "CENTER", x = 0, y = 120, scale = 1.0, compactMode = false },
    alerts   = { sound = true, raidWarning = false, partyChat = false, screenFlash = true },
    strategy = {
        aggression = "balanced",
        preferHealerOpen = true,
        allowDpsSwap = true,
        callBurstOnlyWhenMSActive = true,
        requireWindfuryNearby = true,
        peelTriggerWindow = 5,    -- seconds of sliding window for "trained" detection
        peelTriggerDamage = 3,    -- damage events in window to force DEFEND
        -- M11 #71: rating-aware aggression. "auto" reads
        -- GetPersonalRatedInfo() and tunes aggression by bracket
        -- rating; "greedy" / "balanced" / "safe" override; a number
        -- pins a specific rating for testing.
        ratingAggression = "auto",
    },
    trace = {
        enabled  = false,
        maxLines = 200,
        log      = {},
    },
    record = {
        enabled   = false,
        maxEvents = 1000,
        events    = {},
    },
    profiles = {},  -- M9 #63: per-opponent-team Bayesian tendency profiles
    debug = false,
}

local RECORD_DEFAULT_CAP = 1000

-- Append a CLEU event to the recording buffer when enabled. Used by the
-- companion tools/replay.lua to re-run the engine on captured logs.
local function appendRecord(subEvent, ts, srcGUID, destGUID, spellID, spellName)
    local db = _G.ArenaCoachTBCDB
    if not (db and db.record and db.record.enabled and subEvent) then return end
    db.record.events = db.record.events or {}
    local cap = db.record.maxEvents or RECORD_DEFAULT_CAP
    table.insert(db.record.events, {
        ts    = ts or 0,
        sub   = subEvent,
        src   = srcGUID,
        dst   = destGUID,
        spell = spellID,
        name  = spellName,
    })
    while #db.record.events > cap do table.remove(db.record.events, 1) end
end

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
        profileContrib = rec.profileContrib or "",
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
Core._friendlyGUIDs    = {}  -- guid -> friendly model
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

local function resetVolatileUnitState(model)
    model.guid = nil
    model.name = nil
    model.class = nil
    model.specGuess = nil
    model.roleGuess = nil
    model.healthPct = 0
    model.manaPct = nil
    if model.hasTrinket ~= nil then model.hasTrinket = true end
    if model.importantBuffs then model.importantBuffs = {} end
    if model.importantDebuffs then model.importantDebuffs = {} end
    if model.observedSpells then model.observedSpells = {} end
    if model.buffs then model.buffs = {} end
    if model.debuffs then model.debuffs = {} end
    model.lastCast = nil
    model.ccDR = model.ccDR and {} or nil
    model.score = model.score and 0 or nil
end

local function resetForNewGUID(model)
    model.specGuess = nil
    model.roleGuess = nil
    if model.hasTrinket ~= nil then model.hasTrinket = true end
    if model.importantBuffs then model.importantBuffs = {} end
    if model.importantDebuffs then model.importantDebuffs = {} end
    if model.observedSpells then model.observedSpells = {} end
    if model.buffs then model.buffs = {} end
    if model.debuffs then model.debuffs = {} end
    model.lastCast = nil
    model.ccDR = model.ccDR and {} or nil
    model.score = model.score and 0 or nil
end

local function pct(cur, max)
    if not cur or not max or max == 0 then return 100 end
    return math.floor((cur / max) * 100 + 0.5)
end

local function refreshUnit(model, unit)
    if not unit or type(UnitExists) ~= "function" then return end
    if not UnitExists(unit) then
        model.alive = false
        resetVolatileUnitState(model)
        return
    end
    model.alive = true
    if type(UnitGUID) == "function" then
        local guid = UnitGUID(unit)
        if model.guid and guid and model.guid ~= guid then resetForNewGUID(model) end
        model.guid = guid
    end
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
        if e.alive ~= false and e.class then table.insert(list, e.class) end
    end
    self.state.enemyClassList = list
    if ns.ErrorReporter and ns.ErrorReporter.SetKnownNames then
        local names = {}
        for _, e in pairs(self.state.enemies) do
            if e.name then table.insert(names, e.name) end
        end
        for _, f in pairs(self.state.friendlies or {}) do
            if f.name then table.insert(names, f.name) end
        end
        ns.ErrorReporter:SetKnownNames(names)
    end
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
        if model.alive ~= false and model.guid then guids[model.guid] = model end
    end
    Core._friendlyGUIDs = guids
    if ns.ErrorReporter and ns.ErrorReporter.SetKnownNames then
        local names = {}
        for _, f in pairs(self.state.friendlies) do
            if f.name then table.insert(names, f.name) end
        end
        for _, e in pairs(self.state.enemies or {}) do
            if e.name then table.insert(names, e.name) end
        end
        ns.ErrorReporter:SetKnownNames(names)
    end
end

local function auraAPIAvailable()
    return type(UnitAura) == "function"
        or type(UnitBuff) == "function"
        or type(UnitDebuff) == "function"
end

local function eachAura(unit, filter, fn)
    if not unit then return end
    local auraFn
    local useFilter = false
    if type(UnitAura) == "function" then
        auraFn = UnitAura
        useFilter = true
    elseif filter == "HELPFUL" and type(UnitBuff) == "function" then
        auraFn = UnitBuff
    elseif filter == "HARMFUL" and type(UnitDebuff) == "function" then
        auraFn = UnitDebuff
    end
    if not auraFn then return end
    for i = 1, 40 do
        local values
        if useFilter then values = { auraFn(unit, i, filter) }
        else values = { auraFn(unit, i) } end
        local name = values[1]
        if not name then break end
        local spellID = values[10] or values[11]
        fn(spellID, name)
    end
end

local function spellNameMatches(spellID, name, id)
    if spellID and spellID == id then return true end
    local S = ns.Spells
    if name and S and S.Name and S:Name(id) == name then return true end
    return false
end

local function spellInSet(spellID, name, set)
    if not set then return false end
    if spellID and set[spellID] then return true end
    for id, _ in pairs(set) do
        if spellNameMatches(spellID, name, id) then return true, id end
    end
    return false
end

local function friendlyIsHealer(f)
    if not f then return false end
    if ns.Classes and ns.Classes.IsHealer then return ns.Classes:IsHealer(f.class, f.spec) end
    return f.class == "PRIEST" or f.class == "DRUID"
end

local function markFriendlyDebuff(f, spellID, name)
    local S = ns.Spells
    if not S then return end
    local cat = spellID and S.CATEGORIES and S.CATEGORIES[spellID] or nil
    if cat == "STUN" then f.debuffs.stunned = true
    elseif cat == "FEAR" then f.debuffs.feared = true
    elseif cat == "INCAPACITATE" then f.debuffs.sheeped = true
    elseif cat == "DISORIENT" then f.debuffs.disoriented = true
    elseif cat == "ROOT" or spellNameMatches(spellID, name, S.HAMSTRING) then f.debuffs.rooted = true end
    if spellNameMatches(spellID, name, S.COUNTERSPELL) or spellNameMatches(spellID, name, S.SPELL_LOCK) then
        f.debuffs.silenced = true
    end
end

function Core:RefreshAuraObservations()
    if not auraAPIAvailable() then return end
    local S = ns.Spells
    if not S then return end

    local obs = self.state.observations or {}
    local trained = obs.healerUnderPressure
    local ownCaps = ns.OwnComps and ns.OwnComps:Infer(self.state.friendlies or {}) or {}
    obs.msActiveOn = nil
    obs.windfuryActive = false
    obs.bloodlustActive = false
    obs.bloodlustReady = ownCaps.hasBloodlust == true
    obs.hojReady = ownCaps.hasHoJ == true
    obs.priestCanDispel = ownCaps.hasDispelMagic == true
    obs.enemyBloodlustActive = false
    obs.multipleBurstsDetected = false
    obs.healerUnderPressure = trained

    for _, f in pairs(self.state.friendlies or {}) do
        if f.alive ~= false and f.unit then
            f.buffs = {}
            f.debuffs = {}
            eachAura(f.unit, "HELPFUL", function(spellID, name)
                if spellNameMatches(spellID, name, S.BLESSING_FREEDOM) then f.buffs.freedom = true end
                if spellNameMatches(spellID, name, S.WINDFURY_TOTEM) then obs.windfuryActive = true end
                if spellNameMatches(spellID, name, S.BLOODLUST) or spellNameMatches(spellID, name, S.HEROISM) then
                    obs.bloodlustActive = true
                end
            end)
            eachAura(f.unit, "HARMFUL", function(spellID, name)
                markFriendlyDebuff(f, spellID, name)
                if ownCaps.hasDispelMagic and spellID and S.MAGIC_CC_TO_DISPEL and S.MAGIC_CC_TO_DISPEL[spellID] then
                    obs.priestCanDispel = true
                end
            end)
        end
    end

    local burstCount = 0
    for _, e in pairs(self.state.enemies or {}) do
        if e.alive ~= false and e.unit then
            local scannedBuffs = {}
            eachAura(e.unit, "HELPFUL", function(spellID, name)
                local matchedID
                local matched, id = spellInSet(spellID, name, S.IMMUNITY_BUFFS)
                if matched then
                    matchedID = spellID or id
                else
                    matched, id = spellInSet(spellID, name, S.MAJOR_DEFENSIVES)
                    if matched then
                        matchedID = spellID or id
                    else
                        matched, id = spellInSet(spellID, name, S.PURGEABLE)
                        if matched then matchedID = spellID or id end
                    end
                end
                if matchedID then scannedBuffs[matchedID] = true end
                if spellNameMatches(spellID, name, S.BLOODLUST) or spellNameMatches(spellID, name, S.HEROISM) then
                    obs.enemyBloodlustActive = true
                    burstCount = burstCount + 1
                elseif spellNameMatches(spellID, name, S.DEATH_WISH)
                    or spellNameMatches(spellID, name, S.AVENGING_WRATH)
                    or spellNameMatches(spellID, name, S.ICY_VEINS) then
                    burstCount = burstCount + 1
                end
            end)
            e.importantBuffs = scannedBuffs
            e.importantDebuffs = {}
            eachAura(e.unit, "HARMFUL", function(spellID, name)
                if e.guid and spellNameMatches(spellID, name, S.MORTAL_STRIKE) then
                    obs.msActiveOn = e.guid
                end
                if spellID then e.importantDebuffs[spellID] = true end
            end)
        end
    end
    obs.multipleBurstsDetected = burstCount >= 2
    self.state.observations = obs
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
    self:RefreshAuraObservations()

    -- M9 #65: resolve opponent profile from signature, attach to state
    -- so the engine's buildCallouts can consult Bayesian tendencies.
    -- Profile is created on-demand if this is a first encounter.
    if ns.OpponentProfile and _G.ArenaCoachTBCDB and self.state.enemies then
        local sig = ns.OpponentProfile:Signature(self.state.enemies)
        if sig then
            self.state.opponentSignature = sig
            self.state.opponentProfile = ns.OpponentProfile:Get(sig, _G.ArenaCoachTBCDB)
        end
    end

    -- M11 #71: resolve the rating-aware aggression and attach to state
    -- so the engine can read state.aggression directly.
    self.state.aggression = self:CurrentAggression(self.state)

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

    -- Recording (for offline replay)
    appendRecord(subEvent, ts, sourceGUID, destGUID, spellID, spellName)

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
    local damagedFriendly = Core._friendlyGUIDs[destGUID]
    if subEvent and damagedFriendly and friendlyIsHealer(damagedFriendly)
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

    -- Spec inference from observed casts AND from applied auras.
    -- Aura events catch spec-defining auras (Shadowform, Moonkin Form,
    -- Tree of Life, Soul Link, Vampiric Embrace, Spirit of Redemption)
    -- that never fire SPELL_CAST_SUCCESS on a unit already in form.
    if ns.SpellSpecHints and (
        subEvent == "SPELL_CAST_SUCCESS"
        or subEvent == "SPELL_AURA_APPLIED"
        or subEvent == "SPELL_AURA_REFRESH"
    ) then
        for _, e in pairs(Core.state.enemies or {}) do
            if e.guid == sourceGUID then
                ns.SpellSpecHints:Apply(e, spellID)
                break
            end
        end
    end

    -- M10 #69: feed the pattern recogniser. Only SPELL_CAST_SUCCESS
    -- counts as a step trigger (auras can fire spuriously from glance
    -- effects).
    if ns.Patterns and subEvent == "SPELL_CAST_SUCCESS" then
        ns.Patterns:Observe(spellID, ts)
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
    chatPrint(Core.L("HELP_RECORD"))
    chatPrint(Core.L("HELP_BUGREPORT"))
    chatPrint(Core.L("HELP_WHATIF"))
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
    elseif cmd == "record" then
        Core:HandleRecord(rest)
    elseif cmd == "bugreport" then
        Core:RunBugReport()
    elseif cmd == "whatif" then
        Core:RunWhatIf(rest)
    else
        chatPrint(Core.L("DEBUG_UNKNOWN_CMD"))
    end
end

-- M10 #68: replay db.record.events through the engine offline and
-- return a sequence of (mode, comp, chainId) summaries — one per
-- evaluated event. `modifier` is an optional function (events,index)
-- -> events that mutates the event list before replay; absent
-- means baseline. Pure: builds a synthetic state, doesn't touch
-- the live one. Headless tests call this directly.
function Core:ReplayRecord(events, modifier)
    if type(events) ~= "table" then return {} end
    local replay = events
    if type(modifier) == "function" then replay = modifier(events) end

    local SE = ns.StrategyEngine
    local CT = ns.CooldownTracker
    local DR = ns.DRTracker
    local S  = ns.Spells
    if not (SE and CT and DR) then return {} end

    -- Snapshot live trackers so the replay's cooldown / DR observations
    -- don't bleed into the in-game state. We restore at the end.
    local savedCT = CT._cooldowns; CT._cooldowns = {}
    local savedDR = DR._state;     DR._state     = {}

    local state = {
        enemies        = {},
        friendlies     = {},
        observations   = {},
        enemyClassList = {},
        combatPhase    = "ACTIVE",
        bracket        = 5,
        config         = { strategy = {} },
    }
    local function ensureEnemy(guid)
        if not guid then return nil end
        if not state.enemies[guid] then
            state.enemies[guid] = {
                unit = guid, guid = guid, class = "WARRIOR",
                alive = true, healthPct = 100, hasTrinket = true,
                importantBuffs = {}, importantDebuffs = {}, observedSpells = {},
            }
        end
        return state.enemies[guid]
    end

    local out = {}
    for i, ev in ipairs(replay) do
        if CT.OnCombatLogEvent then CT:OnCombatLogEvent(ev.sub, ev.src, ev.dst, ev.spell) end
        if S and S.CATEGORIES and S.CATEGORIES[ev.spell] and DR.OnCC then
            DR:OnCC(ev.sub, ev.dst, ev.spell, S.CATEGORIES[ev.spell], ev.ts)
        end
        ensureEnemy(ev.src)
        local list = {}
        for _, e in pairs(state.enemies) do table.insert(list, e.class) end
        state.enemyClassList = list
        local rec = SE:Evaluate(state)
        if rec then
            table.insert(out, {
                index   = i,
                ts      = ev.ts,
                mode    = rec.mode,
                comp    = rec.comp,
                chainId = rec.chain and rec.chain.id or nil,
            })
        end
    end

    CT._cooldowns = savedCT
    DR._state     = savedDR
    return out
end

-- Diff two replay sequences. Returns the count of differing rows and
-- a small array of sample diffs (up to 5).
function Core:DiffReplays(a, b)
    local diffs, samples = 0, {}
    local n = math.max(#a, #b)
    for i = 1, n do
        local ra, rb = a[i], b[i]
        local sameMode  = ra and rb and ra.mode    == rb.mode
        local sameComp  = ra and rb and ra.comp    == rb.comp
        local sameChain = ra and rb and ra.chainId == rb.chainId
        if not (sameMode and sameComp and sameChain) then
            diffs = diffs + 1
            if #samples < 5 then
                table.insert(samples, {
                    index = i,
                    base  = ra and string.format("%s/%s/%s",
                        tostring(ra.mode), tostring(ra.comp), tostring(ra.chainId)) or "<nil>",
                    cf    = rb and string.format("%s/%s/%s",
                        tostring(rb.mode), tostring(rb.comp), tostring(rb.chainId)) or "<nil>",
                })
            end
        end
    end
    return diffs, samples
end

function Core:RunWhatIf(rest)
    local db = _G.ArenaCoachTBCDB
    if not (db and db.record and db.record.events and #db.record.events > 0) then
        chatPrint("/acc whatif: no recording loaded. Run /acc record on first.")
        return
    end
    local arg, restArg = (rest or ""):match("^(%S*)%s*(.*)$")
    arg = (arg or ""):lower()
    if arg == "" or arg == "help" then
        chatPrint("/acc whatif help            - show this help")
        chatPrint("/acc whatif summary         - describe the loaded recording")
        chatPrint("/acc whatif skip <i>        - replay with event #i skipped, print divergence")
        return
    end
    if arg == "summary" then
        local n = #db.record.events
        chatPrint(string.format("/acc whatif: %d events loaded, first ts=%s last ts=%s",
            n, tostring(db.record.events[1].ts), tostring(db.record.events[n].ts)))
        return
    end
    if arg == "skip" then
        local idx = tonumber(restArg)
        if not idx then chatPrint("/acc whatif skip <i>: i must be a number"); return end
        local baseline = self:ReplayRecord(db.record.events)
        local cf = self:ReplayRecord(db.record.events, function(ev)
            local copy = {}
            for i, e in ipairs(ev) do if i ~= idx then table.insert(copy, e) end end
            return copy
        end)
        local diffs, samples = self:DiffReplays(baseline, cf)
        chatPrint(string.format("/acc whatif skip %d: %d / %d recs diverged",
            idx, diffs, math.max(#baseline, #cf)))
        for _, s in ipairs(samples) do
            chatPrint(string.format("  [%d] baseline=%s cf=%s", s.index, s.base, s.cf))
        end
        return
    end
    chatPrint("/acc whatif: unknown subcommand '" .. arg .. "', try /acc whatif help")
end

-- M11 #71: query the WoW rating API for the current bracket. Returns
-- nil when not in a rated bracket or when the API isn't available
-- (headless tests). Stores the result on Core.state.rating.
function Core:UpdateRating()
    if type(GetPersonalRatedInfo) ~= "function" then return nil end
    local bracket = self.state and self.state.bracket
    local idx
    if bracket == 2 then idx = 1
    elseif bracket == 3 then idx = 2
    elseif bracket == 5 then idx = 3
    end
    if not idx then return nil end
    local ok, rating = pcall(GetPersonalRatedInfo, idx)
    if ok and type(rating) == "number" then
        self.state.rating = rating
        return rating
    end
    return nil
end

-- Resolve the active aggression label for the current state. Honours
-- the ratingAggression knob: "auto" derives from state.rating
-- (<1800 = greedy, 1800-2200 = balanced, >2200 = safe); explicit
-- "greedy"/"balanced"/"safe" override; a number is treated as a rating
-- override for testing. Falls back to config.strategy.aggression.
function Core:CurrentAggression(state)
    state = state or self.state or {}
    local cfg = (state.config and state.config.strategy)
        or (_G.ArenaCoachTBCDB and _G.ArenaCoachTBCDB.strategy)
        or {}
    local ra = cfg.ratingAggression
    if ra == "greedy" or ra == "balanced" or ra == "safe" then return ra end
    local rating = (type(ra) == "number") and ra or state.rating
    if not rating then return cfg.aggression or "balanced" end
    if rating < 1800 then return "greedy"
    elseif rating > 2200 then return "safe"
    else return "balanced" end
end

function Core:RunBugReport()
    local ER = ns.ErrorReporter
    if not ER then chatPrint("ErrorReporter module not loaded"); return end
    local payload = ER:Format(5)
    chatPrint(Core.L("BUGREPORT_HEADER") or "Bug report payload:")
    for line in payload:gmatch("[^\n]+") do chatPrint(line) end
end

function Core:HandleRecord(rest)
    local db = _G.ArenaCoachTBCDB
    if not db then Core:InitDB(); db = _G.ArenaCoachTBCDB end
    db.record = db.record or { enabled = false, maxEvents = 1000, events = {} }
    local arg = ((rest or ""):match("^%S*") or ""):lower()
    if arg == "" or arg == "status" then
        chatPrint(string.format("record: %s (%d events, cap %d)",
            db.record.enabled and "ON" or "OFF",
            #(db.record.events or {}),
            db.record.maxEvents or 1000))
    elseif arg == "on" then
        db.record.enabled = true
        chatPrint("record ON (cap " .. (db.record.maxEvents or 1000) .. ")")
    elseif arg == "off" then
        db.record.enabled = false
        chatPrint("record OFF")
    elseif arg == "clear" then
        db.record.events = {}
        chatPrint("recording cleared")
    elseif arg == "dump" then
        local n = #(db.record.events or {})
        if n == 0 then chatPrint("recording is empty"); return end
        local last = db.record.events[n]
        chatPrint(string.format("record: %d events, last: %s spell=%s @t=%s",
            n, tostring(last.sub), tostring(last.spell), tostring(last.ts)))
        chatPrint("Use tools/replay.lua against your SavedVariables file for full analysis.")
    else
        chatPrint("usage: /acc record on|off|status|dump|clear")
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

-- M12 (post-release polish): scripted DBM-style UI walk-through.
-- /acc test (default) walks the live UI through 7 beats over ~14 seconds:
-- OPEN -> KILL -> burst-ready -> SWAP -> DEFEND -> profile-driven callout
-- -> RESET. Each beat reuses the real UI:Apply path so the user sees
-- mode colour flips, chain block changes, BURST_NOW pulse, screen flash
-- on URGENT, and voice cues fire exactly as they would in a real match.
-- /acc test print preserves the legacy chat-only summary.
local DEMO_BEATS = {
    {
        delay = 0.0,
        note  = "Pre-combat. RMP detected. Plan opener.",
        rec = {
            mode = "OPEN",
            primaryTarget = "demo-priest", primaryTargetName = "Holyman", primaryTargetClass = "PRIEST",
            secondaryTarget = "demo-mage", secondaryTargetName = "Frostbiter", secondaryTargetClass = "MAGE",
            reason = "PRIEST [role_healer(25)] | RMP_DISC_3V3 spec-confirmed (1.00)",
            callouts = { "CALL_HOJ_KILL", "CALL_GROUND_POLY", "CALL_TREMOR_FEAR" },
            priority = "MEDIUM",
            comp = "RMP_DISC_3V3", compLabel = "RMP (confirmed Disc Priest)",
            compConfidence = 1.0, compSpecConfirmed = true,
            burstAllowed = false, burstBlockedBy = "no_ms",
            chain = {
                id = "rmp_sap_into_kidney",
                label = "Sap off-healer, kidney the target",
                labelKey = "CHAIN_RMP_SAP_INTO_KIDNEY",
                expectedProb = 0.62, expectedValue = 0.47, steps = 3,
                links = {
                    { spellID = 11297, category = "INCAPACITATE" },
                    { spellID = 28272, category = "INCAPACITATE" },
                    { spellID = 8643,  category = "STUN" },
                },
            },
        },
    },
    {
        delay = 2.0,
        note  = "Engaged. Mode flipped to KILL — note the red colour.",
        rec = {
            mode = "KILL",
            primaryTarget = "demo-priest", primaryTargetName = "Holyman", primaryTargetClass = "PRIEST",
            secondaryTarget = "demo-mage", secondaryTargetName = "Frostbiter", secondaryTargetClass = "MAGE",
            reason = "PRIEST [health_below_50(30), trinket_down(20), role_healer(25)] | RMP_DISC_3V3 spec-confirmed (1.00)",
            callouts = { "CALL_HOJ_KILL", "CALL_TREMOR_FEAR", "CALL_GROUND_POLY" },
            priority = "HIGH",
            comp = "RMP_DISC_3V3", compLabel = "RMP (confirmed Disc Priest)",
            compConfidence = 1.0, compSpecConfirmed = true,
            burstAllowed = false, burstBlockedBy = "no_ms",
            chain = {
                id = "rmp_sap_into_kidney",
                label = "Sap off-healer, kidney the target",
                labelKey = "CHAIN_RMP_SAP_INTO_KIDNEY",
                expectedProb = 0.71, expectedValue = 0.55, steps = 3,
                links = {
                    { spellID = 11297, category = "INCAPACITATE" },
                    { spellID = 28272, category = "INCAPACITATE" },
                    { spellID = 8643,  category = "STUN" },
                },
            },
        },
    },
    {
        delay = 4.0,
        note  = "Every burst gate passed — BURST_NOW callout fires.",
        rec = {
            mode = "KILL",
            primaryTarget = "demo-priest", primaryTargetName = "Holyman", primaryTargetClass = "PRIEST",
            reason = "PRIEST [health_below_50(30), trinket_down(20), role_healer(25), ms_active(25)] | RMP_DISC_3V3 spec-confirmed (1.00)",
            callouts = { "BURST_NOW", "CALL_HOJ_KILL", "CALL_TREMOR_FEAR" },
            priority = "HIGH",
            comp = "RMP_DISC_3V3", compLabel = "RMP (confirmed Disc Priest)",
            compConfidence = 1.0, compSpecConfirmed = true,
            burstAllowed = true, burstBlockedBy = nil,
        },
    },
    {
        delay = 6.0,
        note  = "Priest trinketed + Pain Sup popped. SWAP to mage.",
        rec = {
            mode = "SWAP",
            primaryTarget = "demo-mage", primaryTargetName = "Frostbiter", primaryTargetClass = "MAGE",
            secondaryTarget = "demo-priest", secondaryTargetName = "Holyman", secondaryTargetClass = "PRIEST",
            reason = "MAGE [role_cloth_dps(15), trinket_down(20)] | RMP_DISC_3V3 spec-confirmed (0.85)",
            callouts = { "CALL_GROUND_POLY", "CALL_DISP_FROST", "CALL_PURGE" },
            priority = "HIGH",
            comp = "RMP_DISC_3V3", compLabel = "RMP (confirmed Disc Priest)",
            compConfidence = 1.0, compSpecConfirmed = true,
            burstAllowed = false, burstBlockedBy = "target_immune",
        },
    },
    {
        delay = 8.0,
        note  = "Healer being trained — DEFEND (blue + screen flash if alerts enabled).",
        rec = {
            mode = "DEFEND",
            primaryTarget = nil, primaryTargetName = nil, primaryTargetClass = nil,
            reason = "defensive: trained | RMP_DISC_3V3 spec-confirmed (1.00)",
            callouts = { "CALL_PAIN_SUP_READY", "CALL_BOP_READY", "CALL_PEEL_DRUID" },
            priority = "URGENT",
            comp = "RMP_DISC_3V3", compLabel = "RMP (confirmed Disc Priest)",
            compConfidence = 1.0, compSpecConfirmed = true,
            burstAllowed = false, burstBlockedBy = "incoming_pressure",
        },
    },
    {
        delay = 10.0,
        note  = "Profile-driven callout: they trinket Fear, save Tremor for HoJ.",
        rec = {
            mode = "KILL",
            primaryTarget = "demo-priest", primaryTargetName = "Holyman", primaryTargetClass = "PRIEST",
            reason = "PRIEST [health_below_50(30), role_healer(25)] | RMP_DISC_3V3 spec-confirmed (1.00)",
            callouts = { "CALL_SAVE_TREMOR_HOJ", "CALL_HOJ_KILL", "CALL_GROUND_POLY" },
            priority = "HIGH",
            comp = "RMP_DISC_3V3", compLabel = "RMP (confirmed Disc Priest)",
            compConfidence = 1.0, compSpecConfirmed = true,
            profileContrib = "trinketsFear=0.91",
            opponentSignature = "MAGE_PRIEST_ROGUE#1834729871",
        },
    },
    {
        delay = 12.0,
        note  = "Match over. Frame returns to baseline.",
        rec = {
            mode = "RESET",
            reason = "reset / no clear target",
            callouts = {},
            priority = "LOW",
        },
    },
}

function Core:RunTestMode(rest)
    rest = (rest or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if rest == "print" then
        return Core:_RunTestPrintMode()
    end
    Core:_RunTestDemoMode()
end

-- DBM-style scripted walk-through: force the frame visible, step through
-- DEMO_BEATS via C_Timer, restore visibility at the end.
function Core:_RunTestDemoMode()
    if not ns.UI then chatPrint("UI not loaded"); return end
    if ns.UI.CreateFrame and not ns.UI.frame then ns.UI:CreateFrame() end
    if not ns.UI.frame then chatPrint(Core.L("TEST_DEMO_NO_UI") or "demo needs a live UI"); return end

    local wasShown = (ns.UI.frame.IsShown and ns.UI.frame:IsShown()) or false
    if not wasShown and ns.UI.Show then ns.UI:Show() end

    chatPrint(Core.L("TEST_DEMO_START") or "|cffc8a86b[ACC]|r demo starting — 14s RMP 3v3 walk-through")

    local total = #DEMO_BEATS
    for i, beat in ipairs(DEMO_BEATS) do
        local applyBeat = function()
            if ns.UI and ns.UI.Apply then ns.UI:Apply(beat.rec) end
            if ns.WeakAuraBridge and ns.WeakAuraBridge.Publish then
                ns.WeakAuraBridge:Publish(beat.rec, Core.state)
            end
            if beat.note then
                chatPrint(string.format("|cff8b7548[ACC %d/%d]|r %s", i, total, beat.note))
            end
        end
        if type(C_Timer) == "table" and type(C_Timer.After) == "function" and beat.delay > 0 then
            C_Timer.After(beat.delay, applyBeat)
        else
            applyBeat()
        end
    end

    -- Restore visibility 2s after the last beat
    local endDelay = (DEMO_BEATS[total] and DEMO_BEATS[total].delay or 0) + 2
    local restore = function()
        if not wasShown and ns.UI.Hide then ns.UI:Hide() end
        chatPrint(Core.L("TEST_DEMO_END") or "|cffc8a86b[ACC]|r demo complete · /acc test print for the chat-only version")
    end
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(endDelay, restore)
    else
        restore()
    end
end

-- Legacy chat-only behaviour, kept under /acc test print.
function Core:_RunTestPrintMode()
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
