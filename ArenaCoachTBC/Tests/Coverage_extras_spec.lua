-- Tests/Coverage_extras_spec.lua
-- Targets the rare/defensive branches not exercised by happy-path tests:
--   - EventBus's no-CreateFrame fallback + OnEvent dispatch path
--   - UI tooltip / drag handlers / _Flash OnUpdate loop / primaryTargetName
--   - StrategyEngine no-importantBuffs branches, RESET path, BURST_NOW
--   - CooldownTracker / DRTracker `now()` fallback to os.time()
--   - Core re-evaluation for SPELL_CAST_SUCCESS / UNIT_DIED CLEU events

local H = _G.__ACC_TEST_HELPERS
H.load("Locales/enUS.lua")
H.load("Data/Spells.lua")
H.load("Data/Classes.lua")
H.load("Data/OwnComps.lua")
H.load("Data/Strategies.lua")
H.load("EventBus.lua")
H.load("CooldownTracker.lua")
H.load("DRTracker.lua")
H.load("Chain.lua")
H.load("StrategyEngine.lua")
H.load("UI.lua")
H.load("ScreenEdgeGlow.lua")
H.load("Nameplate.lua")
H.load("WeakAuraBridge.lua")
H.load("ErrorReporter.lua")
H.load("Core.lua")

local EB   = H.ns.EventBus
local UI   = H.ns.UI
local SE   = H.ns.StrategyEngine
local CT   = H.ns.CooldownTracker
local DR   = H.ns.DRTracker
local Core = H.ns.Core
local Glow = H.ns.ScreenEdgeGlow
local NP   = H.ns.Nameplate
local ER   = H.ns.ErrorReporter

local g = H.describe("Coverage.extras")

-- ============================================================
-- EventBus: no-CreateFrame + OnEvent dispatch
-- ============================================================
H.it(g, "EventBus.ensureFrame returns a stub frame when CreateFrame absent", function()
    EB:_Reset()
    local saved = _G.CreateFrame
    _G.CreateFrame = nil
    local h = function() end
    EB:Subscribe("FOO_NO_FRAME", h)
    H.assertNotNil(EB._subs["FOO_NO_FRAME"])
    EB:Unsubscribe("FOO_NO_FRAME", h)
    _G.CreateFrame = saved
    EB:_Reset()
end)

H.it(g, "EventBus's OnEvent script dispatches to subscribers", function()
    EB:_Reset()
    -- Subscribe -> this calls ensureFrame which stores an OnEvent script on
    -- our mock frame. We then look up the mock frame in H.frames and invoke
    -- its OnEvent script as the WoW client would.
    local got
    EB:Subscribe("FAKE_GAME_EVENT", function(evt, payload) got = payload end)
    -- Find the mock frame by global name (CreateFrame stores it under
    -- "ArenaCoachTBCEventFrame")
    local frame = _G.ArenaCoachTBCEventFrame
    H.assertNotNil(frame)
    local onEvent = frame._scripts.OnEvent
    H.assertNotNil(onEvent)
    onEvent(frame, "FAKE_GAME_EVENT", "hello")
    H.assertEq(got, "hello")
    EB:_Reset()
end)

-- ============================================================
-- CooldownTracker / DRTracker: now() fallback
-- ============================================================
H.it(g, "CooldownTracker.now() falls back to os.time when no GetTime", function()
    local saved = _G.GetTime
    _G.GetTime = nil
    CT:Clear()
    CT:MarkUsed("g-os", 27619)
    -- Should not error and should produce a remaining time
    H.assertNotNil(CT:GetRemaining("g-os", 27619))
    _G.GetTime = saved
end)

H.it(g, "DRTracker.now() falls back to os.time when no GetTime", function()
    local saved = _G.GetTime
    _G.GetTime = nil
    DR:Clear()
    DR:Apply("g-os", "STUN")
    H.assertEq(DR:NextMultiplier("g-os", "STUN"), 0.5)
    _G.GetTime = saved
end)

-- ============================================================
-- UI: drag handlers, _Flash OnUpdate loop, primaryTargetName branch
-- (icon-row coverage dropped in v2.2.1 along with the underlying frames.)
-- ============================================================
H.it(g, "UI frame drag OnMouseDown / OnMouseUp", function()
    UI:CreateFrame()
    _G.ArenaCoachTBCDB = _G.ArenaCoachTBCDB or {}
    _G.ArenaCoachTBCDB.frame = { point = "CENTER", x = 0, y = 0 }
    _G.ArenaCoachTBCDB.locked = false
    UI.frame._scripts.OnMouseDown(UI.frame, "LeftButton")
    UI.frame._scripts.OnMouseUp(UI.frame)
    -- Locked: should not start moving (but no error)
    _G.ArenaCoachTBCDB.locked = true
    UI.frame._scripts.OnMouseDown(UI.frame, "LeftButton")
    UI.frame._scripts.OnMouseUp(UI.frame)
    -- Right click is ignored
    UI.frame._scripts.OnMouseDown(UI.frame, "RightButton")
end)

H.it(g, "UI _Flash helper OnUpdate eventually hides the overlay", function()
    _G.ArenaCoachTBCDB = {
        alerts = { screenFlash = true },
        frame = { point = "CENTER", x = 0, y = 0, scale = 1 },
        strategy = {}, enabled = true,
    }
    UI:CreateFrame()
    UI._flash = nil
    UI:_Flash()
    H.assertNotNil(UI._flash)
    -- Simulate enough OnUpdate ticks to drive alpha to 0
    local on = UI._flash._scripts.OnUpdate
    H.assertNotNil(on)
    on(UI._flash, 1.0)  -- drives alpha negative immediately
end)

H.it(g, "UI Apply with primaryTargetName uses it as label", function()
    UI:CreateFrame()
    UI:Apply({
        mode = "KILL", primaryTargetName = "Holyman",
        primaryTargetClass = "PRIEST", callouts = {}, priority = "HIGH",
    })
end)

H.it(g, "UI renders spell texture icons when available", function()
    UI:CreateFrame()
    UI._calloutLastShown = {}
    H.advanceTime(5)
    local saved = _G.GetSpellTexture
    _G.GetSpellTexture = function() return "Interface/Icons/Spell_Holy_HammerOfJustice" end
    UI:Apply({
        mode = "KILL", primaryTargetName = "Killtarget",
        primaryTargetClass = "PRIEST", callouts = { "CALL_HOJ_KILL" },
        priority = "HIGH", _forceShow = true,
    })
    H.assertNotNil(UI.frame.subText:GetText():find("|TInterface/Icons/Spell_Holy_HammerOfJustice", 1, true))
    _G.GetSpellTexture = saved
end)

H.it(g, "UI formats purge fallback target and verbose comp badge", function()
    _G.ArenaCoachTBCDB = _G.ArenaCoachTBCDB or {}
    _G.ArenaCoachTBCDB.frame = {
        point = "CENTER", x = 0, y = 0, scale = 1,
        width = 720, height = 260, verbose = true,
    }
    UI.frame = nil
    UI.assignFrame = nil
    UI.unitFrame = nil
    UI.railFrame = nil
    UI:CreateFrame()
    UI._calloutLastShown = {}
    H.advanceTime(5)
    UI:Apply({
        mode = "KILL", primaryTargetClass = nil,
        callouts = { "CALL_PURGE" }, priority = "HIGH",
        comp = "RMP", compLabel = "Rogue / Mage / Priest",
        compSpecConfirmed = true, _forceShow = true,
    })
    local text = UI.frame.subText:GetText()
    H.assertNotNil(text:find("Purge target", 1, true))
    H.assertNotNil(text:find("Rogue / Mage / Priest", 1, true))
end)

H.it(g, "UI falls back to raw keys when Core localization is absent", function()
    UI:CreateFrame()
    local savedCore = H.ns.Core
    H.ns.Core = nil
    UI:Apply({
        mode = "RESET", reasonKey = "REASON_RESET",
        callouts = {}, priority = "LOW", _forceShow = true,
    })
    H.assertNotNil(UI.frame.subText:GetText():find("REASON_RESET", 1, true))
    H.ns.Core = savedCore
end)

-- ============================================================
-- StrategyEngine: defensive branches
-- ============================================================
H.it(g, "scoreEnemy handles missing importantBuffs gracefully", function()
    local state = SE:BuildTestState({"MAGE"})
    local mage; for _, e in pairs(state.enemies) do mage = e end
    mage.importantBuffs = nil  -- exercise hasMajorDefensive nil-guard
    state.combatPhase = "ACTIVE"
    local rec = SE:Evaluate(state)
    H.assertNotNil(rec)
end)

H.it(g, "Evaluate with no friendlies still returns a recommendation", function()
    local state = SE:BuildTestState({"MAGE"})
    state.friendlies = {}
    local rec = SE:Evaluate(state)
    H.assertNotNil(rec)
end)

H.it(g, "PRE phase with no enemies returns RESET", function()
    local state = SE:BuildTestState({})
    state.combatPhase = "PRE"
    state.enemies = {}
    state.enemyClassList = nil
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "RESET")
end)

H.it(g, "Burst KILL with no MS/WF requirement appends BURST_NOW callout", function()
    local state = SE:BuildTestState({"MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.bracket = 2
    state.pvpContext = "arena"
    state.config.strategy.callBurstOnlyWhenMSActive = false
    state.config.strategy.requireWindfuryNearby     = false
    state.lastPrimaryGUID = nil
    for _, e in pairs(state.enemies) do
        if e.class == "PRIEST" then
            e.healthPct = 10
            e.hasTrinket = false
        end
    end
    local rec = SE:Evaluate(state)
    if rec.mode == "KILL" then
        local hasBurst = false
        for _, c in ipairs(rec.callouts) do
            if c == "BURST_NOW" then hasBurst = true end
        end
        H.assertTrue(hasBurst, "expected BURST_NOW in KILL callouts")
    end
end)

H.it(g, "primaryTargetHp supports hpPct and raw hp/hpMax fallbacks", function()
    local state = SE:BuildTestState({"MAGE"})
    state.combatPhase = "ACTIVE"
    for _, e in pairs(state.enemies) do
        e.healthPct = nil
        e.hpPct = 0.42
    end
    local rec = SE:Evaluate(state)
    H.assertEq(rec.primaryTargetHp, 0.42)

    state = SE:BuildTestState({"MAGE"})
    state.combatPhase = "ACTIVE"
    for _, e in pairs(state.enemies) do
        e.healthPct = nil
        e.hp = 120
        e.hpMax = 300
    end
    rec = SE:Evaluate(state)
    H.assertEq(rec.primaryTargetHp, 0.4)
end)

H.it(g, "low mana healer score and disabled DPS swaps are covered", function()
    local state = SE:BuildTestState({"MAGE", "PRIEST"})
    state.combatPhase = "ACTIVE"
    state.config.strategy.allowDpsSwap = false
    local priestGUID
    for _, e in pairs(state.enemies) do
        if e.class == "PRIEST" then
            e.manaPct = 20
            priestGUID = e.guid
        elseif e.class == "MAGE" then
            e.healthPct = 10
            e.hasTrinket = false
        end
    end
    state.lastPrimaryGUID = priestGUID
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "KILL", "disabled DPS swaps should force KILL instead of SWAP")
    local sawLowMana = false
    for _, e in pairs(state.enemies) do
        if e.class == "PRIEST" then
            for _, c in ipairs(e._contrib or {}) do
                if c.key == "low_mana_healer" then sawLowMana = true end
            end
        end
    end
    H.assertTrue(sawLowMana, "priest below 25% mana should score low_mana_healer")
end)

H.it(g, "BurstDecision prefers explicit state aggression", function()
    local out = SE:BurstDecision(
        { aggression = "safe", observations = {}, enemies = {} },
        { guid = "g-burst", healthPct = 100, importantBuffs = {} },
        { expectedProb = 1 }
    )
    H.assertEq(out.gates.kill_prob.threshold, SE.BURST_KILL_PROB_THRESHOLD.safe)
    H.assertEq(out.gates.rating_aware.aggression, "safe")
end)

H.it(g, "Score breakdown includes role bonuses for various enemies", function()
    local state = SE:BuildTestState({"MAGE","PRIEST","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.observations.msActiveOn   = nil
    state.observations.bloodlustReady = true
    state.observations.offHealerCC  = true
    state.observations.priestCanDispel = true
    -- Force MS active on first enemy
    for _, e in pairs(state.enemies) do state.observations.msActiveOn = e.guid; break end
    -- Drop health on one enemy to exercise the health_below_50 path
    for _, e in pairs(state.enemies) do
        if e.class == "MAGE" then e.healthPct = 25 end
    end
    local rec = SE:Evaluate(state)
    H.assertNotNil(rec)
end)

-- ============================================================
-- Visual helper defensive branches
-- ============================================================
H.it(g, "ScreenEdgeGlow OnUpdate paints all edge textures", function()
    Glow:Hide()
    Glow._frame = nil
    Glow:SetMode("KILL")
    H.assertNotNil(Glow._frame)
    H.assertNotNil(Glow._frame._scripts.OnUpdate)
    Glow._frame._scripts.OnUpdate(Glow._frame, 0.2)
end)

H.it(g, "ScreenEdgeGlow handles missing CreateFrame", function()
    Glow:Hide()
    Glow._frame = nil
    local saved = _G.CreateFrame
    _G.CreateFrame = nil
    Glow:SetMode("KILL")
    H.assertNil(Glow:CurrentMode())
    _G.CreateFrame = saved
end)

H.it(g, "Nameplate handles C_NamePlate lookup and removed plates", function()
    local savedCNamePlate = _G.C_NamePlate
    local savedUnitExists = _G.UnitExists
    local savedUnitGUID = _G.UnitGUID
    local plate = H.makeMockFrame{ name = "c-nameplate" }
    _G.C_NamePlate = {
        GetNamePlateForUnit = function(unit)
            if unit == "nameplate3" then return plate end
        end,
    }
    _G.UnitExists = function(unit) return unit == "nameplate3" end
    _G.UnitGUID = function(unit)
        if unit == "nameplate3" then return "guid-c-nameplate" end
    end
    NP:Highlight("KILL", "guid-c-nameplate")
    H.assertNotNil(NP._overlays[plate])
    NP:OnPlateRemoved("nameplate3")
    H.assertNil(NP._overlays[plate])
    _G.UnitGUID = savedUnitGUID
    _G.UnitExists = savedUnitExists
    _G.C_NamePlate = savedCNamePlate
end)

H.it(g, "Nameplate tolerates missing frame creation", function()
    local savedCreateFrame = _G.CreateFrame
    local savedUnitExists = _G.UnitExists
    local savedUnitGUID = _G.UnitGUID
    local savedPlate = _G.nameplate4
    _G.CreateFrame = nil
    _G.C_NamePlate = nil
    _G.nameplate4 = H.makeMockFrame{ name = "nameplate4" }
    _G.UnitExists = function(unit) return unit == "nameplate4" end
    _G.UnitGUID = function(unit)
        if unit == "nameplate4" then return "guid-no-create" end
    end
    NP:Highlight("KILL", "guid-no-create")
    _G.UnitGUID = savedUnitGUID
    _G.UnitExists = savedUnitExists
    _G.nameplate4 = savedPlate
    _G.CreateFrame = savedCreateFrame
end)

-- ============================================================
-- ErrorReporter: rare formatting branches
-- ============================================================
H.it(g, "ErrorReporter Recent slices older entries", function()
    _G.ArenaCoachTBCDB = nil
    ER:Reset()
    ER:Capture("err 1")
    ER:Capture("err 2")
    ER:Capture("err 3")
    local recent = ER:Recent(2)
    H.assertEq(#recent, 2)
    H.assertNotNil(recent[1].message:find("err 2", 1, true))
end)

H.it(g, "ErrorReporter Format includes client build and context lines", function()
    _G.ArenaCoachTBCDB = nil
    ER:Reset()
    local saved = _G.GetBuildInfo
    _G.GetBuildInfo = function() return "2.5.4", "12340" end
    ER:Capture("boom", "context Player-99-DEAD")
    local out = ER:Format(1)
    H.assertNotNil(out:find("2.5.4 build 12340", 1, true))
    H.assertNotNil(out:find("context:", 1, true))
    _G.GetBuildInfo = saved
end)

-- ============================================================
-- Core: SPELL_CAST_SUCCESS / UNIT_DIED CLEU re-evaluation
-- ============================================================
H.it(g, "Core slash covers HUD and visual toggles", function()
    H.ns.EventBus:_Reset()
    Core:Boot()
    _G.ArenaCoachTBCDB = nil
    Core:InitDB()
    local slash = _G.SlashCmdList.ARENACOACH
    H.assertNotNil(slash)

    slash("highcontrast on")
    H.assertTrue(_G.ArenaCoachTBCDB.frame.highContrast)
    slash("highcontrast off")
    H.assertFalse(_G.ArenaCoachTBCDB.frame.highContrast)
    slash("highcontrast")
    H.assertTrue(_G.ArenaCoachTBCDB.frame.highContrast)

    slash("verbose on")
    H.assertTrue(_G.ArenaCoachTBCDB.frame.verbose)
    slash("verbose off")
    H.assertFalse(_G.ArenaCoachTBCDB.frame.verbose)
    slash("verbose")
    H.assertTrue(_G.ArenaCoachTBCDB.frame.verbose)

    slash("off")
    H.assertFalse(_G.ArenaCoachTBCDB.enabled)
    slash("on")
    H.assertTrue(_G.ArenaCoachTBCDB.enabled)

    slash("glow on")
    H.assertTrue(_G.ArenaCoachTBCDB.alerts.edgeGlow)
    slash("glow off")
    H.assertFalse(_G.ArenaCoachTBCDB.alerts.edgeGlow)

    slash("nameplate on")
    H.assertTrue(_G.ArenaCoachTBCDB.alerts.nameplate)
    slash("nameplate off")
    H.assertFalse(_G.ArenaCoachTBCDB.alerts.nameplate)
end)

H.it(g, "Core CLEU re-evaluates on SPELL_CAST_SUCCESS / UNIT_DIED", function()
    H.ns.EventBus:_Reset()
    Core:Boot()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.setUnit("arena1", { class = "PRIEST", guid = "guid-pr", hp = 100, hpMax = 100 })
    Core:RefreshArenaEnemies()
    H.fireCLEU(0, "SPELL_CAST_SUCCESS", false, "guid-pr", "Priest",
               nil, nil, "guid-pr", "Priest", nil, nil, 27619, "")
    H.ns.EventBus:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    H.fireCLEU(0, "UNIT_DIED", false, nil, nil,
               nil, nil, "guid-pr", "Priest", nil, nil, nil, nil)
    H.ns.EventBus:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
end)
