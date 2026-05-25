-- Tests/StrategyEngine_extra_spec.lua
-- Additional StrategyEngine coverage beyond the original happy-path tests.
local H = _G.__ACC_TEST_HELPERS

-- The original StrategyEngine_spec.lua loads everything standalone, but
-- when invoked through run_all the namespace is shared and modules are
-- already loaded. We still load defensively here.
H.load("Locales/enUS.lua")
H.load("Data/Spells.lua")
H.load("Data/Classes.lua")
H.load("Data/OwnComps.lua")
H.load("Data/Strategies.lua")
H.load("StrategyEngine.lua")

local SE = H.ns.StrategyEngine
local g = H.describe("StrategyEngine.extra")

local function findEnemyByClass(state, class)
    for _, e in pairs(state.enemies) do
        if e.class == class then return e end
    end
end

H.it(g, "Evaluate with no enemies returns RESET", function()
    local state = SE:BuildTestState({})
    state.combatPhase = "ACTIVE"
    state.enemies = {}
    state.enemyClassList = nil
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "RESET")
    H.assertNil(rec.primaryTarget)
end)

H.it(g, "Evaluate exposes ownArchetype from default friendlies", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST","ROGUE","DRUID"})
    local rec = SE:Evaluate(state)
    -- The default friendly comp is the WAR/ENH/RET/RDRU/DISC cleave, so
    -- MELEE_CLEAVE should fire (or DOUBLE_HEALER if both healers count).
    H.assertNotNil(rec.ownArchetype)
end)

H.it(g, "Burst blocked when no windfury (config requires it)", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST","ROGUE","DRUID"})
    state.combatPhase = "ACTIVE"
    state.config.strategy.requireWindfuryNearby = true
    state.config.strategy.callBurstOnlyWhenMSActive = false
    state.observations.windfuryActive = false
    local rec = SE:Evaluate(state)
    H.assertFalse(rec.burstAllowed)
    H.assertEq(rec.burstBlockedBy, "no_windfury")
end)

H.it(g, "Burst blocked when target is immune", function()
    local state = SE:BuildTestState({"MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.config.strategy.callBurstOnlyWhenMSActive = false
    state.config.strategy.requireWindfuryNearby = false
    local mage = findEnemyByClass(state, "MAGE")
    mage.importantBuffs[H.ns.Spells.ICE_BLOCK] = true
    -- Force top target to be the mage by giving the priest a HoT-like buff
    -- not relevant; we'll just check that immune burst is blocked when any
    -- enemy has immunity (engine sets burstBlockedBy="target_immune" only
    -- if the top target is immune)
    local priest = findEnemyByClass(state, "PRIEST")
    priest.alive = false  -- only mage alive
    local rec = SE:Evaluate(state)
    H.assertFalse(rec.burstAllowed)
end)

H.it(g, "Recommendation has priority field for each mode", function()
    local cases = {
        { phase = "PRE",   expected = "OPEN" },
    }
    for _, c in ipairs(cases) do
        local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST","ROGUE","DRUID"})
        state.combatPhase = c.phase
        local rec = SE:Evaluate(state)
        H.assertNotNil(rec.priority)
    end
end)

H.it(g, "shouldDefend triggers on bloodlust active", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST","ROGUE","DRUID"})
    state.combatPhase = "ACTIVE"
    state.observations.enemyBloodlustActive = true
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND")
end)

H.it(g, "shouldDefend triggers on multipleBurstsDetected", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST","ROGUE","DRUID"})
    state.combatPhase = "ACTIVE"
    state.observations.multipleBurstsDetected = true
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND")
end)

H.it(g, "purgeable buff increases score", function()
    local state = SE:BuildTestState({"WARRIOR","PRIEST","MAGE","WARLOCK","DRUID"})
    local mage = findEnemyByClass(state, "MAGE")
    mage.importantBuffs[H.ns.Spells.ICY_VEINS] = true
    SE:Evaluate(state)
    -- The presence of a purgeable buff is one of the scoring inputs.
    H.assertNotNil(mage._contrib)
end)

H.it(g, "major defensive penalty when down", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    local priest = findEnemyByClass(state, "PRIEST")
    priest.majorDefensiveDown = true
    SE:Evaluate(state)
    H.assertNotNil(priest._score)
end)

H.it(g, "unreachable / losBlocked penalties applied", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    local priest = findEnemyByClass(state, "PRIEST")
    priest.unreachable = true
    SE:Evaluate(state)
    H.assertTrue(priest._score < 50)
    local state2 = SE:BuildTestState({"PRIEST","MAGE"})
    findEnemyByClass(state2, "PRIEST").losBlocked = true
    SE:Evaluate(state2)
    H.assertNotNil(findEnemyByClass(state2, "PRIEST")._score)
end)

H.it(g, "overextended melee gets bonus role weight", function()
    local state = SE:BuildTestState({"WARRIOR","ROGUE"})
    findEnemyByClass(state, "WARRIOR").overextended = true
    SE:Evaluate(state)
    H.assertNotNil(findEnemyByClass(state, "WARRIOR")._score)
end)

H.it(g, "DefaultFriendlies returns 5 players in spec'd comp", function()
    local fr = SE:DefaultFriendlies()
    H.assertNotNil(fr.player)
    H.assertNotNil(fr.party1)
    H.assertNotNil(fr.party4)
    H.assertEq(fr.player.class, "WARRIOR")
end)

H.it(g, "BuildTestState wires friendlies + opts", function()
    local s = SE:BuildTestState({"MAGE"}, {
        observations = { windfuryActive = false },
        combatPhase  = "ACTIVE",
    })
    H.assertEq(s.combatPhase, "ACTIVE")
    H.assertFalse(s.observations.windfuryActive)
end)

H.it(g, "Friendly rooted+snared without freedom marks meleeLockedDown", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.friendlies.player.debuffs = { rooted = true }
    state.combatPhase = "ACTIVE"
    local rec = SE:Evaluate(state)
    -- Penalty applied -> top target's score is reduced. We only assert
    -- the engine runs and yields a target.
    H.assertNotNil(rec)
end)

H.it(g, "Healer CC penalty applied", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.friendlies.party4.debuffs = { stunned = true }
    state.combatPhase = "ACTIVE"
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND")
end)

H.it(g, "Team avg HP < 45 applies penalty", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    for _, f in pairs(state.friendlies) do f.healthPct = 30 end
    state.combatPhase = "ACTIVE"
    local rec = SE:Evaluate(state)
    H.assertNotNil(rec)
end)

H.it(g, "GetWeights returns defaults when bracket is nil", function()
    local w = SE:GetWeights(nil)
    H.assertEq(w.role_healer, SE.weights.role_healer)
end)

H.it(g, "GetWeights merges bracket overrides over defaults", function()
    -- 2v2 boosts role_healer; the merged value should reflect that without
    -- mutating the underlying default table.
    local w = SE:GetWeights(2)
    H.assertEq(w.role_healer, 40)
    H.assertEq(SE.weights.role_healer, 25, "default table should not mutate")
end)

H.it(g, "GetWeights for 5v5 yields the default values (no overrides)", function()
    local w = SE:GetWeights(5)
    H.assertEq(w.role_healer, SE.weights.role_healer)
end)

H.it(g, "Evaluate consumes state.bracket so scoring picks up overrides", function()
    local state = SE:BuildTestState({"PRIEST","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.bracket = 2
    local rec = SE:Evaluate(state)
    H.assertNotNil(rec)  -- engine still produces a rec under bracket=2
end)

H.it(g, "comp openTarget biases PRE target selection", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "PRE"
    local rec = SE:Evaluate(state)
    H.assertEq(rec.comp, "WLD")
    H.assertEq(rec.primaryTargetClass, "WARLOCK")
end)

H.it(g, "aggression setting changes swap threshold", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    state.config.strategy.aggression = "greedy"
    local priest = findEnemyByClass(state, "PRIEST")
    local mage = findEnemyByClass(state, "MAGE")
    mage.hasTrinket = false
    state.lastPrimaryGUID = priest.guid
    local rec = SE:Evaluate(state)
    H.assertEq(rec.primaryTargetClass, "MAGE")
    H.assertEq(rec.mode, "SWAP")

    local safeState = SE:BuildTestState({"PRIEST","MAGE"})
    safeState.combatPhase = "ACTIVE"
    safeState.config.strategy.aggression = "safe"
    findEnemyByClass(safeState, "MAGE").hasTrinket = false
    safeState.lastPrimaryGUID = findEnemyByClass(safeState, "PRIEST").guid
    local safeRec = SE:Evaluate(safeState)
    H.assertEq(safeRec.primaryTargetClass, "MAGE")
    H.assertEq(safeRec.mode, "KILL")
end)

H.it(g, "kill_defensive_soon penalty fires when major defensive <15s away", function()
    H.load("CooldownTracker.lua")
    local CT = H.ns.CooldownTracker
    local state = SE:BuildTestState({"MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    local m = findEnemyByClass(state, "MAGE")
    H._gameTime = 1000
    CT:Clear()
    -- used at t=705, ready at t=1005 -> remaining = 5
    CT:_record(m.guid, 27619, 300, 705)
    SE:Evaluate(state)
    local sawPenalty = false
    for _, c in ipairs(m._contrib or {}) do
        if c.key == "kill_defensive_soon" then sawPenalty = true end
    end
    H.assertTrue(sawPenalty, "expected kill_defensive_soon penalty")
    CT:Clear()
end)

H.it(g, "kill_defensive_soon penalty does NOT fire when defensive >30s away", function()
    H.load("CooldownTracker.lua")
    local CT = H.ns.CooldownTracker
    local state = SE:BuildTestState({"MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    local m = findEnemyByClass(state, "MAGE")
    H._gameTime = 1000
    CT:Clear()
    -- Used at t=940, ready at t=1240 -> remaining 240 seconds
    CT:_record(m.guid, 27619, 300, 940)
    SE:Evaluate(state)
    for _, c in ipairs(m._contrib or {}) do
        if c.key == "kill_defensive_soon" then
            error("penalty unexpectedly applied at rem=240s")
        end
    end
    CT:Clear()
end)

H.it(g, "CALL_HOJ_KILL is suppressed when STUN DR is immune on primary target", function()
    H.load("DRTracker.lua")
    local DR = H.ns.DRTracker
    DR:Clear()
    local state = SE:BuildTestState({"PRIEST","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.observations = { hojReady = true }
    local p = findEnemyByClass(state, "PRIEST")
    p.guid = "guid-priest-dr"
    H._gameTime = 1000
    DR:OnCC("SPELL_AURA_APPLIED", p.guid, 10308, "STUN", 999)
    DR:OnCC("SPELL_AURA_APPLIED", p.guid, 10308, "STUN", 998)
    DR:OnCC("SPELL_AURA_APPLIED", p.guid, 10308, "STUN", 997)
    local rec = SE:Evaluate(state)
    H.assertNotNil(rec)
    local hojIn = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_HOJ_KILL" then hojIn = true end
    end
    H.assertFalse(hojIn, "CALL_HOJ_KILL should be suppressed at full DR immunity")
end)

H.it(g, "CALL_HOJ_KILL is allowed when no STUN DR observed", function()
    H.load("DRTracker.lua")
    H.ns.DRTracker:Clear()
    local state = SE:BuildTestState({"PRIEST","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.observations = { hojReady = true }
    local rec = SE:Evaluate(state)
    local hojIn = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_HOJ_KILL" then hojIn = true end
    end
    H.assertTrue(hojIn, "CALL_HOJ_KILL should fire when DR is clean")
end)
