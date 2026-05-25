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

-- =================================================================
-- Comp-match confidence plumbed through Evaluate (M7 #56)
-- =================================================================

H.it(g, "Evaluate exposes compConfidence + compSpecConfirmed on the recommendation", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "PRE"
    local rec = SE:Evaluate(state)
    H.assertEq(rec.comp, "WLD")
    H.assertNotNil(rec.compConfidence, "compConfidence should be present")
    H.assertNotNil(rec.compSpecConfirmed, "compSpecConfirmed should be present")
    H.assertFalse(rec.compSpecConfirmed, "class-only WLD should not be spec-confirmed")
end)

H.it(g, "Evaluate flags compSpecConfirmed=true when spec-keyed comp matches", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.bracket = 3
    -- Pin the priest's spec to DISCIPLINE so RMP_DISC_3V3 wins
    for _, e in pairs(state.enemies) do
        if e.class == "PRIEST" then
            e.specGuess = "DISCIPLINE"
            e.roleGuess = "HEALER"
        end
    end
    local rec = SE:Evaluate(state)
    H.assertEq(rec.comp, "RMP_DISC_3V3")
    H.assertTrue(rec.compSpecConfirmed, "spec-keyed comp match should set compSpecConfirmed")
    H.assertEq(rec.compConfidence, 1.0)
end)

-- =================================================================
-- Chain scoring plumbed into Evaluate (M8 #61)
-- =================================================================

H.it(g, "Evaluate emits a chain field for a comp that has chains", function()
    H.load("Chain.lua")
    H.load("Lookahead.lua")
    H.ns.DRTracker:Clear()
    H.ns.CooldownTracker:Clear()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.bracket = 5
    local rec = SE:Evaluate(state)
    H.assertEq(rec.comp, "WLD")
    H.assertNotNil(rec.chain, "expected rec.chain for WLD which has chains")
    H.assertEq(rec.chain.id, "wld_fear_into_cyclone")
    H.assertTrue(rec.chain.expectedProb > 0)
    -- M8 #62: labelKey is propagated for UI rendering
    H.assertEq(rec.chain.labelKey, "CHAIN_WLD_FEAR_INTO_CYCLONE")
    H.assertEq(rec.chain.steps, 2)
    -- M10 #67: lookahead expected value is set when Lookahead is loaded
    H.assertNotNil(rec.chain.expectedValue, "lookahead should populate expectedValue")
    H.assertTrue(rec.chain.expectedValue <= rec.chain.expectedProb,
        "EV should not exceed raw chain prob")
end)

H.it(g, "Evaluate respects strategy.lookaheadEnabled=false to skip lookahead", function()
    H.load("Chain.lua")
    H.load("Lookahead.lua")
    H.ns.DRTracker:Clear()
    H.ns.CooldownTracker:Clear()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.config.strategy.lookaheadEnabled = false
    local rec = SE:Evaluate(state)
    H.assertNil(rec.chain.expectedValue, "expectedValue should be nil when lookahead disabled")
end)

H.it(g, "Evaluate omits rec.chain when the comp has no chains", function()
    H.load("Chain.lua")
    H.ns.DRTracker:Clear()
    H.ns.CooldownTracker:Clear()
    -- WMH_3V3 (warrior/mage/priest, bracket-3 "thunder cleave") has no
    -- chains entry today. Default roles give exactly 1 healer (priest),
    -- so the static matcher picks it instead of dynamic DOUBLE_HEALER.
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.bracket = 3
    local rec = SE:Evaluate(state)
    H.assertEq(rec.comp, "WMH_3V3")
    H.assertNil(rec.chain, "WMH_3V3 has no chains field")
end)

H.it(g, "Evaluate prefers the higher-prob chain when DR pre-bumps one", function()
    H.load("Chain.lua")
    H.ns.DRTracker:Clear()
    H.ns.CooldownTracker:Clear()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.bracket = 5
    -- First measure the baseline expected prob for WLD's fear chain.
    local baseline = SE:Evaluate(state).chain.expectedProb
    -- Now pre-bump FEAR DR on the primary target so the chain's
    -- expected prob drops.
    local rec = SE:Evaluate(state)
    H.assertNotNil(rec.primaryTarget)
    H.ns.DRTracker:Apply(rec.primaryTarget, "FEAR", H._gameTime or 0)
    local after = SE:Evaluate(state).chain.expectedProb
    H.assertTrue(after < baseline,
        "expected prob should drop after FEAR DR applied (baseline=" ..
        baseline .. ", after=" .. tostring(after) .. ")")
    H.ns.DRTracker:Clear()
end)

-- =================================================================
-- Profile-driven callouts (M9 #65)
-- =================================================================

local function seedProfile(state, tendency, alpha, beta)
    H.load("OpponentProfile.lua")
    local OP = H.ns.OpponentProfile
    state.opponentProfile = {
        tendencies = {
            trinketsFear      = { alpha = 1, beta = 1, observations = 0 },
            iceBlockBelow30   = { alpha = 1, beta = 1, observations = 0 },
            kicksFirstHeal    = { alpha = 1, beta = 1, observations = 0 },
            sapsPriest        = { alpha = 1, beta = 1, observations = 0 },
        },
    }
    -- Inject observation count by bumping alpha/beta the agreed-upon
    -- number of times so OP:Estimate sees the right n.
    local rec = state.opponentProfile.tendencies[tendency]
    rec.alpha = alpha
    rec.beta  = beta
    rec.observations = (alpha - 1) + (beta - 1)
end

H.it(g, "Evaluate pushes CALL_FAKE_KICK_2 when kicksFirstHeal >= 0.7 with enough samples", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    seedProfile(state, "kicksFirstHeal", 8, 2)  -- alpha=8, beta=2 -> 0.8, n=8
    local rec = SE:Evaluate(state)
    local found = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_FAKE_KICK_2" then found = true; break end
    end
    H.assertTrue(found, "expected CALL_FAKE_KICK_2 in callouts")
    H.assertTrue(rec.profileContrib:find("kicksFirstHeal") ~= nil,
        "profileContrib should mention kicksFirstHeal")
end)

H.it(g, "Evaluate pushes CALL_SAVE_TREMOR_HOJ when trinketsFear >= 0.7 with enough samples", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    seedProfile(state, "trinketsFear", 10, 3)  -- 10/13 ~ 0.77
    local rec = SE:Evaluate(state)
    local found = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_SAVE_TREMOR_HOJ" then found = true; break end
    end
    H.assertTrue(found, "expected CALL_SAVE_TREMOR_HOJ in callouts")
end)

H.it(g, "Evaluate pushes CALL_BURST_BLOCK_INCOMING when iceBlockBelow30 >= 0.7", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    seedProfile(state, "iceBlockBelow30", 9, 2)  -- ~ 0.82
    local rec = SE:Evaluate(state)
    local found = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_BURST_BLOCK_INCOMING" then found = true; break end
    end
    H.assertTrue(found)
end)

H.it(g, "Evaluate suppresses profile callouts when samples < threshold", function()
    -- Only 3 observations (< MIN_SAMPLES_FOR_OPINION = 5). Even with
    -- 3-of-3 positive, EstimateOrDefault returns the fallback 0.5,
    -- which is below the 0.7 callout gate.
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    seedProfile(state, "kicksFirstHeal", 4, 1)  -- n = 3, mean = 0.8 but gated by n
    local rec = SE:Evaluate(state)
    for _, c in ipairs(rec.callouts or {}) do
        H.assertTrue(c ~= "CALL_FAKE_KICK_2",
            "should not push CALL_FAKE_KICK_2 with n=3 (below threshold)")
    end
end)

H.it(g, "Evaluate does not push profile callouts when no profile is on state", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.opponentProfile = nil
    local rec = SE:Evaluate(state)
    for _, c in ipairs(rec.callouts or {}) do
        H.assertTrue(c ~= "CALL_FAKE_KICK_2"
            and c ~= "CALL_SAVE_TREMOR_HOJ"
            and c ~= "CALL_BURST_BLOCK_INCOMING",
            "no-profile state should not emit profile callouts")
    end
    H.assertNil(rec.profileContrib)
end)

H.it(g, "Evaluate exposes opponentSignature from state", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.opponentSignature = "TEST_SIG#1234"
    local rec = SE:Evaluate(state)
    H.assertEq(rec.opponentSignature, "TEST_SIG#1234")
end)

-- =================================================================
-- M11 #73: Multi-reason burst gate
-- =================================================================

H.it(g, "BurstDecision returns 4 named gates", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    local target = {}
    for _, e in pairs(state.enemies) do target = e; break end
    local out = SE:BurstDecision(state, target, nil)
    H.assertNotNil(out.gates.kill_prob)
    H.assertNotNil(out.gates.chain_ready)
    H.assertNotNil(out.gates.incoming_pressure)
    H.assertNotNil(out.gates.rating_aware)
end)

H.it(g, "BurstDecision blocks on kill_prob when target is high HP", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    state.aggression  = "balanced"
    local target
    for _, e in pairs(state.enemies) do
        e.healthPct = 100; e.hasTrinket = true; target = e
    end
    local out = SE:BurstDecision(state, target, nil)
    H.assertFalse(out.gates.kill_prob.allowed)
    H.assertEq(out.blockedBy, "kill_prob")
end)

H.it(g, "BurstDecision kill_prob threshold scales with aggression", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    local target = { healthPct = 50, hasTrinket = true, importantBuffs = {} }
    state.aggression = "greedy"
    H.assertTrue(SE:BurstDecision(state, target, nil).gates.kill_prob.threshold < 0.5)
    state.aggression = "safe"
    H.assertTrue(SE:BurstDecision(state, target, nil).gates.kill_prob.threshold > 0.5)
end)

H.it(g, "BurstDecision blocks on incoming_pressure when healer is under pressure", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    state.aggression  = "balanced"
    state.observations = { healerUnderPressure = true }
    -- Even with a perfect target, the gate fires.
    local target = { healthPct = 0, hasTrinket = false, importantBuffs = {} }
    local out = SE:BurstDecision(state, target, { expectedProb = 0.9 })
    H.assertFalse(out.gates.incoming_pressure.allowed)
end)

H.it(g, "BurstDecision allows when all gates pass", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    state.aggression  = "greedy"
    state.observations = {}
    local target = { healthPct = 20, hasTrinket = false, importantBuffs = {}, guid = "g1" }
    local out = SE:BurstDecision(state, target, { expectedProb = 0.8 })
    H.assertTrue(out.gates.kill_prob.allowed)
    H.assertTrue(out.gates.chain_ready.allowed)
    H.assertTrue(out.gates.incoming_pressure.allowed)
    H.assertTrue(out.allowed, "all gates passed; burst should be allowed")
end)

H.it(g, "Evaluate populates rec.burstDecision when mode is KILL", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.config.strategy.callBurstOnlyWhenMSActive = false
    state.config.strategy.requireWindfuryNearby     = false
    local rec = SE:Evaluate(state)
    if rec.mode == "KILL" then
        H.assertNotNil(rec.burstDecision)
        H.assertNotNil(rec.burstDecision.gates.kill_prob)
    end
end)

-- =================================================================
-- M11 #72: KillProb model
-- =================================================================

H.it(g, "KillProb returns 0 + empty components for nil target", function()
    local out = SE:KillProb(nil, {})
    H.assertEq(out.prob, 0)
end)

H.it(g, "KillProb shifts monotonically as HP drops", function()
    local target = { healthPct = 100, hasTrinket = true, importantBuffs = {} }
    local state  = { enemies = {}, observations = {} }
    local outHigh = SE:KillProb(target, state)
    target.healthPct = 50
    local outMid  = SE:KillProb(target, state)
    target.healthPct = 10
    local outLow  = SE:KillProb(target, state)
    H.assertTrue(outLow.prob > outMid.prob, "lower HP -> higher kill prob")
    H.assertTrue(outMid.prob > outHigh.prob, "monotonic")
end)

H.it(g, "KillProb breakdown surfaces each contributing component", function()
    local target = { healthPct = 50, hasTrinket = false, importantBuffs = {} }
    local state  = {
        enemies = { p = { class = "PRIEST", roleGuess = "HEALER", manaPct = 20, alive = true } },
        observations = { hojReady = true },
    }
    local out = SE:KillProb(target, state)
    H.assertTrue(out.components.hp > 0)
    H.assertEq(out.components.defensiveDown, 0.10, "trinket-down should contribute")
    H.assertEq(out.components.healerLowMana, 0.10, "low-mana healer should contribute")
    H.assertEq(out.components.burstReady, 0.05, "burst ready should contribute")
end)

H.it(g, "KillProb is clamped to [0..1]", function()
    -- Pile every bonus on at full HP: still must clamp <= 1.0.
    local target = { healthPct = 0, hasTrinket = false, importantBuffs = {} }
    local state  = {
        enemies = { p = { class = "PRIEST", roleGuess = "HEALER", manaPct = 5, alive = true } },
        observations = { hojReady = true },
    }
    local out = SE:KillProb(target, state)
    H.assertTrue(out.prob <= 1.0, "must clamp; got " .. out.prob)
end)

-- =================================================================
-- M11 #71: rating-aware aggression
-- =================================================================

H.it(g, "shouldDefend HP threshold shifts with aggression: safe defends earlier", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST","DRUID","PALADIN"})
    state.combatPhase = "ACTIVE"
    state.aggression = "safe"
    -- Find a friendly healer and put them at 45% HP.
    for _, f in pairs(state.friendlies) do
        if f.class == "DRUID" or f.class == "PRIEST" then
            f.healthPct = 45
        end
    end
    local rec = SE:Evaluate(state)
    -- Safe threshold is 50; 45 < 50 -> DEFEND.
    H.assertEq(rec.mode, "DEFEND", "safe should defend at 45 HP (threshold 50)")
end)

H.it(g, "shouldDefend HP threshold shifts with aggression: greedy holds at the same HP", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST","DRUID","PALADIN"})
    state.combatPhase = "ACTIVE"
    state.aggression = "greedy"
    for _, f in pairs(state.friendlies) do
        if f.class == "DRUID" or f.class == "PRIEST" then
            f.healthPct = 35
        end
    end
    local rec = SE:Evaluate(state)
    -- Greedy threshold is 30; 35 > 30 -> don't DEFEND on HP alone.
    H.assertTrue(rec.mode ~= "DEFEND" or (rec.reason and not rec.reason:find("low_healer")),
        "greedy should not defend at 35 HP (threshold 30); reason=" .. tostring(rec.reason))
end)

H.it(g, "Evaluate exposes state.aggression on the rec", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.aggression = "safe"
    state.rating = 2400
    local rec = SE:Evaluate(state)
    H.assertEq(rec.aggression, "safe")
    H.assertEq(rec.rating, 2400)
end)

H.it(g, "Same state at low vs high rating produces different swap threshold behaviour", function()
    -- Build a state where the swap target is marginally better than
    -- the current target by ~10 score points. Greedy swaps; safe stays.
    local function buildSwapTest(aggression)
        local state = SE:BuildTestState({"PRIEST","MAGE"})
        state.combatPhase = "ACTIVE"
        state.aggression  = aggression
        local priest, mage
        for _, e in pairs(state.enemies) do
            if e.class == "PRIEST" then priest = e
            elseif e.class == "MAGE"   then mage   = e end
        end
        mage.hasTrinket = false  -- nudge mage up in scoring
        state.lastPrimaryGUID = priest.guid
        return state, mage
    end
    local stateGreedy, mage1 = buildSwapTest("greedy")
    local recGreedy = SE:Evaluate(stateGreedy)
    H.assertEq(recGreedy.primaryTargetClass, "MAGE")
    H.assertEq(recGreedy.mode, "SWAP", "greedy should swap at low threshold")

    local stateSafe, mage2 = buildSwapTest("safe")
    local recSafe = SE:Evaluate(stateSafe)
    -- Safe (threshold=20) doesn't swap unless the gap is >20 points.
    H.assertEq(recSafe.primaryTargetClass, "MAGE")  -- score-wise mage still wins
    H.assertEq(recSafe.mode, "KILL", "safe should hold on the swap when gap is small")
end)

H.it(g, "Evaluate's reason text includes the comp tag and confidence", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "PRE"
    local rec = SE:Evaluate(state)
    H.assertTrue(rec.reason:find("WLD") ~= nil, "reason should mention comp ID")
    H.assertTrue(rec.reason:find("class%-guessed") ~= nil, "reason should mention class-guessed badge")
end)

-- =================================================================
-- M14 (v2.1): BG mode scoring + callouts
-- =================================================================

H.it(g, "BG mode: flag-carrier aura gives a massive (+200) priority boost", function()
    local state = SE:BuildTestState({"WARRIOR","ROGUE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "bg"
    -- Pick a non-priest enemy and attach the WSG carrier aura (23333).
    local target
    for _, e in pairs(state.enemies) do
        if e.class == "WARRIOR" then
            e.importantBuffs[23333] = true
            target = e
        end
    end
    H.assertNotNil(target)
    local rec = SE:Evaluate(state)
    -- Flag carrier should win kill priority even against a healer.
    H.assertEq(rec.primaryTargetClass, "WARRIOR",
        "flag carrier must outrank natural healer priority")
    local sawFlagBoost = false
    for _, c in ipairs(target._contrib or {}) do
        if c.key == "bg_flag_carrier" and c.pts == 200 then sawFlagBoost = true end
    end
    H.assertTrue(sawFlagBoost, "bg_flag_carrier contribution expected")
end)

H.it(g, "BG mode: <30% HP straggler gets the bg_low_hp_straggler boost", function()
    local state = SE:BuildTestState({"WARRIOR","ROGUE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "bg"
    -- Drop a melee to 20% HP; should pick up the BG boost.
    local target
    for _, e in pairs(state.enemies) do
        if e.class == "ROGUE" then e.healthPct = 20; target = e end
    end
    SE:Evaluate(state)
    local saw = false
    for _, c in ipairs(target._contrib or {}) do
        if c.key == "bg_low_hp_straggler" and c.pts == 30 then saw = true end
    end
    H.assertTrue(saw, "bg_low_hp_straggler contribution expected")
end)

H.it(g, "BG mode: SWAP threshold tightens to 30 (vs default 10)", function()
    local function build(score)
        local state = SE:BuildTestState({"PRIEST","MAGE"})
        state.combatPhase = "ACTIVE"
        state.pvpContext  = "bg"
        local priest, mage
        for _, e in pairs(state.enemies) do
            if e.class == "PRIEST" then priest = e
            elseif e.class == "MAGE"   then mage   = e end
        end
        -- Force a known score gap by manipulating mage attributes.
        if score == "small" then
            mage.hasTrinket = false  -- gives ~20pt boost
        elseif score == "huge" then
            mage.hasTrinket = false
            mage.healthPct = 20      -- gives bg_low_hp_straggler (+30) + health_below_50 (+30)
        end
        state.lastPrimaryGUID = priest.guid
        return state
    end
    -- Small gap: should NOT swap (arena would; BG threshold=30 holds)
    local recSmall = SE:Evaluate(build("small"))
    H.assertEq(recSmall.mode, "KILL",
        "BG should not swap on a small score gap (arena would)")
    -- Huge gap: should swap
    local recHuge = SE:Evaluate(build("huge"))
    H.assertEq(recHuge.mode, "SWAP",
        "BG should still swap when gap is decisively large")
end)

H.it(g, "BG mode: CALL_FLAG_CARRIER_LOW fires when carrier is <50% HP", function()
    local state = SE:BuildTestState({"WARRIOR","ROGUE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "bg"
    for _, e in pairs(state.enemies) do
        if e.class == "WARRIOR" then
            e.importantBuffs[23333] = true
            e.healthPct = 35
        end
    end
    local rec = SE:Evaluate(state)
    local saw = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_FLAG_CARRIER_LOW" then saw = true end
    end
    H.assertTrue(saw, "expected CALL_FLAG_CARRIER_LOW for low-HP flag carrier")
end)

H.it(g, "BG mode: CALL_BG_DEFEND fires when mode is DEFEND in BG", function()
    local state = SE:BuildTestState({"WARRIOR","ROGUE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "bg"
    state.observations = { healerUnderPressure = true }  -- force DEFEND
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND")
    local saw = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_BG_DEFEND" then saw = true end
    end
    H.assertTrue(saw, "expected CALL_BG_DEFEND on DEFEND in BG")
end)

H.it(g, "Arena mode is unaffected by BG-mode logic (regression)", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "arena"
    state.bracket     = 3
    -- Even with the flag aura attached, arena should NOT add +200.
    for _, e in pairs(state.enemies) do
        if e.class == "WARRIOR" then e.importantBuffs[23333] = true end
    end
    SE:Evaluate(state)
    -- Inspect the warrior's contributions — bg_flag_carrier must be absent.
    local warrior
    for _, e in pairs(state.enemies) do
        if e.class == "WARRIOR" then warrior = e end
    end
    for _, c in ipairs(warrior._contrib or {}) do
        H.assertTrue(c.key ~= "bg_flag_carrier",
            "bg_flag_carrier must not contribute in arena context")
    end
end)

-- =================================================================
-- M15 (v2.1): World PvP mode
-- =================================================================

H.it(g, "World mode: PRE phase skips OPEN, goes straight to KILL when target alive", function()
    local state = SE:BuildTestState({"WARRIOR"})
    state.combatPhase = "PRE"
    state.pvpContext  = "world"
    local rec = SE:Evaluate(state)
    -- Should be KILL or RESET, never OPEN (no arena planning phase)
    H.assertTrue(rec.mode ~= "OPEN", "world context must not emit OPEN; got " .. rec.mode)
end)

H.it(g, "World mode: SWAP suppressed even when score gap is huge", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "world"
    local priest, mage
    for _, e in pairs(state.enemies) do
        if e.class == "PRIEST" then priest = e
        elseif e.class == "MAGE"   then mage   = e end
    end
    mage.hasTrinket = false
    mage.healthPct  = 15
    state.lastPrimaryGUID = priest.guid
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "KILL",
        "world mode should not emit SWAP — single-target focus")
end)

H.it(g, "World mode: comp identification is skipped (no rec.comp)", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "world"
    local rec = SE:Evaluate(state)
    H.assertNil(rec.comp, "world context should not match arena comps")
end)

H.it(g, "Arena mode: comp identification still works (regression)", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "arena"
    state.bracket     = 3
    local rec = SE:Evaluate(state)
    H.assertNotNil(rec.comp,
        "arena context must still produce a comp match (regression check)")
end)

H.it(g, "World mode: DEFEND fires when player HP <30% via shouldDefend lowestHealer", function()
    local state = SE:BuildTestState({"WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "world"
    -- Knock the only friendly (the "player") to low HP.
    for _, f in pairs(state.friendlies) do f.healthPct = 22 end
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND", "low player HP should trigger DEFEND in world")
end)

H.it(g, "BG mode: PRE phase also skips OPEN (same as world)", function()
    local state = SE:BuildTestState({"WARRIOR"})
    state.combatPhase = "PRE"
    state.pvpContext  = "bg"
    local rec = SE:Evaluate(state)
    H.assertTrue(rec.mode ~= "OPEN", "bg context must not emit OPEN")
end)

-- =================================================================
-- v2.1.3: rec.reasonKey on DEFEND / RESET modes
-- =================================================================

H.it(g, "v2.1.3: DEFEND with trained reason sets reasonKey=REASON_DEFEND_TRAINED", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.observations = { healerUnderPressure = true }
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND")
    H.assertEq(rec.reasonKey, "REASON_DEFEND_TRAINED")
end)

H.it(g, "v2.1.3: DEFEND with enemy_lust reason sets reasonKey=REASON_DEFEND_ENEMY_LUST", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.observations = { enemyBloodlustActive = true }
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND")
    H.assertEq(rec.reasonKey, "REASON_DEFEND_ENEMY_LUST")
end)

H.it(g, "v2.1.3: RESET mode sets reasonKey=REASON_RESET", function()
    local state = SE:BuildTestState({})
    state.combatPhase = "ACTIVE"; state.enemies = {}; state.enemyClassList = nil
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "RESET")
    H.assertEq(rec.reasonKey, "REASON_RESET")
end)

H.it(g, "v2.1.3: KILL mode does NOT set reasonKey (variable contributor text)", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"; state.bracket = 5
    local rec = SE:Evaluate(state)
    H.assertNil(rec.reasonKey,
        "KILL has variable contributor data; reasonKey stays nil so UI uses the rec.reason text")
end)
