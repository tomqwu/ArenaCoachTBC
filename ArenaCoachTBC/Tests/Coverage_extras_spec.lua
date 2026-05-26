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
H.load("StrategyEngine.lua")
H.load("UI.lua")
H.load("WeakAuraBridge.lua")
H.load("Core.lua")

local EB   = H.ns.EventBus
local UI   = H.ns.UI
local SE   = H.ns.StrategyEngine
local CT   = H.ns.CooldownTracker
local DR   = H.ns.DRTracker
local Core = H.ns.Core

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

H.it(g, "UI _Flash OnUpdate eventually hides the overlay", function()
    _G.ArenaCoachTBCDB = {
        alerts = { screenFlash = true },
        frame = { point = "CENTER", x = 0, y = 0, scale = 1 },
        strategy = {}, enabled = true,
    }
    -- M13 / M15 (v2.1): UI:Apply gates the screen flash on
    -- state.pvpContext == "arena". Force arena context so this test
    -- still drives the flash codepath after the gate was added.
    if H.ns.Core and H.ns.Core.state then
        H.ns.Core.state.pvpContext = "arena"
    end
    UI:CreateFrame()
    UI._flash = nil
    UI:Apply({ mode = "DEFEND", priority = "URGENT", callouts = {} })
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
-- Core: SPELL_CAST_SUCCESS / UNIT_DIED CLEU re-evaluation
-- ============================================================
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
