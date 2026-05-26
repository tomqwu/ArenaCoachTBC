-- Tests/WeakAuraBridge_spec.lua
local H = _G.__ACC_TEST_HELPERS
H.load("WeakAuraBridge.lua")
local WAB = H.ns.WeakAuraBridge
local API = _G.ArenaCoachTBC

local g = H.describe("WeakAuraBridge")

local sampleRec = {
    mode = "KILL",
    primaryTarget = "guid-priest",
    primaryTargetName = "Holyman",
    primaryTargetClass = "PRIEST",
    secondaryTarget = "guid-mage",
    secondaryTargetName = "Mageman",
    secondaryTargetClass = "MAGE",
    confidence = 0.7,
    reason = "test reason",
    callouts = { "CALL_HOJ_KILL", "CALL_PURGE" },
    priority = "HIGH",
    comp = "RMP",
    compLabel = "Rogue / Mage / Priest",
    compConfidence = 0.67,
    compSpecConfirmed = false,
    ownArchetype = "MELEE_CLEAVE",
    ownArchetypeLabel = "Melee cleave",
    ownCapabilities = { hasMortalStrike = true, hasBloodlust = true, hasCleanse = false },
    burstAllowed = true,
    burstBlockedBy = nil,
}

local sampleState = {
    enemies = {
        a1 = { unit = "arena1", guid = "guid-priest",  class = "PRIEST",  alive = true,  healthPct = 80 },
        a2 = { unit = "arena2", guid = "guid-mage",    class = "MAGE",    alive = true,  healthPct = 100 },
        a3 = { unit = "arena3", guid = "guid-rogue",   class = "ROGUE",   alive = false, healthPct = 0 },
    },
    friendlies = {
        player = { unit = "player", class = "WARRIOR", spec = "ARMS", alive = true, healthPct = 100 },
    },
    combatPhase = "ACTIVE",
}

H.it(g, "publish then GetRecommendation returns it", function()
    WAB:Publish(sampleRec, sampleState)
    H.assertEq(API.GetRecommendation(), sampleRec)
end)

H.it(g, "mode/priority/reason/confidence getters", function()
    WAB:Publish(sampleRec, sampleState)
    H.assertEq(API.GetMode(), "KILL")
    H.assertEq(API.GetPriority(), "HIGH")
    H.assertEq(API.GetReason(), "test reason")
    H.assertEq(API.GetConfidence(), 0.7)
end)

H.it(g, "target getters", function()
    WAB:Publish(sampleRec, sampleState)
    H.assertEq(API.GetPrimaryTarget(), "guid-priest")
    H.assertEq(API.GetPrimaryTargetName(), "Holyman")
    H.assertEq(API.GetPrimaryTargetClass(), "PRIEST")
    H.assertEq(API.GetSecondaryTarget(), "guid-mage")
    H.assertEq(API.GetSecondaryTargetName(), "Mageman")
    H.assertEq(API.GetSecondaryTargetClass(), "MAGE")
end)

H.it(g, "callouts / burst getters", function()
    WAB:Publish(sampleRec, sampleState)
    local co = API.GetCallouts()
    H.assertEq(co[1], "CALL_HOJ_KILL")
    H.assertTrue(API.IsBurstAllowed())
    H.assertNil(API.GetBurstBlocker())
end)

H.it(g, "comp identification getters", function()
    WAB:Publish(sampleRec, sampleState)
    H.assertEq(API.GetEnemyComp(), "RMP")
    H.assertEq(API.GetEnemyCompLabel(), "Rogue / Mage / Priest")
    H.assertEq(API.GetOwnComp(), "MELEE_CLEAVE")
    H.assertEq(API.GetOwnCompLabel(), "Melee cleave")
end)

H.it(g, "GetCompConfidence + GetCompSpecConfirmed expose comp match confidence", function()
    WAB:Publish(sampleRec, sampleState)
    H.assertEq(API.GetCompConfidence(), 0.67)
    H.assertFalse(API.GetCompSpecConfirmed())
end)

H.it(g, "GetChain / GetChainId / GetChainExpectedProb expose chain selection", function()
    local rec = {}
    for k, v in pairs(sampleRec) do rec[k] = v end
    rec.chain = { id = "rmp_sap_into_kidney", label = "Sap into Kidney", expectedProb = 0.75 }
    WAB:Publish(rec, sampleState)
    H.assertEq(API.GetChainId(), "rmp_sap_into_kidney")
    H.assertEq(API.GetChainExpectedProb(), 0.75)
    H.assertNotNil(API.GetChain())
end)

H.it(g, "GetKillProb + GetKillProbBreakdown surface the kill model (M11)", function()
    H.load("StrategyEngine.lua")
    WAB:Publish(sampleRec, {
        enemies = {
            x = { guid = "guid-priest", class = "PRIEST", roleGuess = "HEALER",
                  alive = true, healthPct = 30, importantBuffs = {}, hasTrinket = false },
        },
        observations = {},
    })
    local p = API.GetKillProb("guid-priest")
    H.assertTrue(p > 0, "kill prob should be > 0 for a low-HP trinket-down healer")
    local b = API.GetKillProbBreakdown("guid-priest")
    H.assertNotNil(b.hp)
end)

H.it(g, "GetBurstDecision surfaces the multi-gate burst breakdown (M11 #73)", function()
    local rec = {}
    for k, v in pairs(sampleRec) do rec[k] = v end
    rec.burstDecision = { allowed = false, blockedBy = "kill_prob",
        gates = { kill_prob = { allowed = false, value = 0.3, threshold = 0.45 } } }
    WAB:Publish(rec, sampleState)
    local out = API.GetBurstDecision()
    H.assertEq(out.blockedBy, "kill_prob")
    H.assertFalse(out.allowed)
end)

H.it(g, "GetPvPContext exposes state.pvpContext (v2.1.1)", function()
    WAB:Publish(sampleRec, { enemies = {}, pvpContext = "bg" })
    H.assertEq(API.GetPvPContext(), "bg")
    WAB:Publish(sampleRec, { enemies = {}, pvpContext = "arena" })
    H.assertEq(API.GetPvPContext(), "arena")
    WAB:Publish(sampleRec, { enemies = {} })
    H.assertNil(API.GetPvPContext())
end)

H.it(g, "GetKillProb returns 0 for unknown GUID", function()
    H.load("StrategyEngine.lua")
    H.assertEq(API.GetKillProb("nonexistent"), 0)
end)

H.it(g, "GetOpponentProfile + GetOpponentSignature + GetTendencyMean surface the profile (M9)", function()
    H.load("OpponentProfile.lua")
    -- Restore DB and pre-seed with a known profile.
    _G.ArenaCoachTBCDB = { profiles = {} }
    local OP = H.ns.OpponentProfile
    local sig = OP:Signature({
        a = { class = "MAGE",   name = "Alf"   },
        b = { class = "PRIEST", name = "Bea"   },
        c = { class = "ROGUE",  name = "Cal"   },
    })
    OP:Update(sig, { tendency = "trinketsFear", observed = true  }, _G.ArenaCoachTBCDB)
    OP:Update(sig, { tendency = "trinketsFear", observed = true  }, _G.ArenaCoachTBCDB)
    OP:Update(sig, { tendency = "trinketsFear", observed = false }, _G.ArenaCoachTBCDB)
    -- alpha=3, beta=2 -> mean = 0.6
    WAB:Publish(sampleRec, {
        enemies = {
            a = { class = "MAGE",   name = "Alf" },
            b = { class = "PRIEST", name = "Bea" },
            c = { class = "ROGUE",  name = "Cal" },
        },
    })
    H.assertEq(API.GetOpponentSignature(), sig)
    H.assertNotNil(API.GetOpponentProfile())
    H.assertTrue(math.abs(API.GetTendencyMean("trinketsFear") - 0.6) < 1e-9)
end)

H.it(g, "GetOpponentProfile returns nil when no state has been published", function()
    H.load("OpponentProfile.lua")
    WAB._last = nil
    WAB._state = nil
    H.assertNil(API.GetOpponentProfile())
    H.assertNil(API.GetOpponentSignature())
    H.assertEq(API.GetTendencyMean("trinketsFear"), 0.5)
end)

H.it(g, "GetChain returns nil and ExpectedProb returns 0 when no chain in rec", function()
    local rec = {}
    for k, v in pairs(sampleRec) do rec[k] = v end
    rec.chain = nil
    WAB:Publish(rec, sampleState)
    H.assertNil(API.GetChain())
    H.assertNil(API.GetChainId())
    H.assertEq(API.GetChainExpectedProb(), 0.0)
end)

H.it(g, "GetCompSpecConfirmed reflects true when spec-keyed comp matched", function()
    local rec = {}
    for k, v in pairs(sampleRec) do rec[k] = v end
    rec.compSpecConfirmed = true
    rec.compConfidence = 1.0
    WAB:Publish(rec, sampleState)
    H.assertTrue(API.GetCompSpecConfirmed())
    H.assertEq(API.GetCompConfidence(), 1.0)
end)

H.it(g, "HasCapability returns true/false correctly", function()
    WAB:Publish(sampleRec, sampleState)
    H.assertTrue(API.HasCapability("hasMortalStrike"))
    H.assertFalse(API.HasCapability("hasCleanse"))
    H.assertFalse(API.HasCapability("nonexistent"))
end)

H.it(g, "GetCapabilities returns the cap table", function()
    WAB:Publish(sampleRec, sampleState)
    local c = API.GetCapabilities()
    H.assertTrue(c.hasMortalStrike)
end)

H.it(g, "state getters", function()
    WAB:Publish(sampleRec, sampleState)
    H.assertEq(API.GetCombatPhase(), "ACTIVE")
    local enemies = API.GetEnemies()
    H.assertNotNil(enemies.a1)
    local friendlies = API.GetFriendlies()
    H.assertNotNil(friendlies.player)
end)

H.it(g, "GetEnemyByGUID finds the enemy", function()
    WAB:Publish(sampleRec, sampleState)
    local e = API.GetEnemyByGUID("guid-mage")
    H.assertEq(e.class, "MAGE")
    H.assertNil(API.GetEnemyByGUID("nonexistent"))
    H.assertNil(API.GetEnemyByGUID(nil))
end)

H.it(g, "no-state safety: getters return empty/nil when nothing published", function()
    WAB._last = nil
    WAB._state = nil
    H.assertNil(API.GetMode())
    H.assertNil(API.GetPriority())
    H.assertNil(API.GetReason())
    H.assertEq(#API.GetCallouts(), 0)
    H.assertFalse(API.IsBurstAllowed())
    H.assertNil(API.GetCombatPhase())
    H.assertNil(API.GetPrimaryTarget())
    H.assertNil(API.GetSecondaryTarget())
    H.assertNil(API.GetSecondaryTargetClass())
    H.assertNil(API.GetEnemyComp())
    H.assertNil(API.GetOwnComp())
    H.assertEq(API.GetCompConfidence(), 0.0)
    H.assertFalse(API.GetCompSpecConfirmed())
    H.assertNil(API.GetChain())
    H.assertEq(API.GetChainExpectedProb(), 0.0)
    H.assertEq(next(API.GetCapabilities()), nil)
    H.assertEq(next(API.GetEnemies()), nil)
    H.assertEq(next(API.GetFriendlies()), nil)
    H.assertFalse(API.HasCapability("foo"))
end)

H.it(g, "GetDebugState / GetVersion", function()
    WAB:Publish(sampleRec, sampleState)
    local d = API.GetDebugState()
    H.assertEq(d.version, "2.7.2")
    H.assertEq(d.addon, "ArenaCoachTBC")
    H.assertEq(API.GetVersion(), "2.7.2")
end)

H.it(g, "Publish handles missing WeakAuras global gracefully", function()
    local saved = _G.WeakAuras
    _G.WeakAuras = nil
    WAB:Publish(sampleRec, sampleState)
    _G.WeakAuras = saved
end)

H.it(g, "Publish swallows WeakAuras.ScanEvents errors", function()
    local saved = _G.WeakAuras
    _G.WeakAuras = { ScanEvents = function() error("boom") end }
    WAB:Publish(sampleRec, sampleState)
    _G.WeakAuras = saved
end)

H.it(g, "Publish triggers WeakAuras.ScanEvents when present", function()
    local got = nil
    _G.WeakAuras = { ScanEvents = function(evt, r) got = r end }
    WAB:Publish(sampleRec, sampleState)
    H.assertEq(got, sampleRec)
    _G.WeakAuras = nil
end)

H.it(g, "GetBracket returns the published state.bracket", function()
    WAB:Publish(sampleRec, { bracket = 3, combatPhase = "ACTIVE" })
    H.assertEq(_G.ArenaCoachTBC.GetBracket(), 3)
end)

H.it(g, "GetBracket returns nil when no state", function()
    WAB._state = nil
    H.assertNil(_G.ArenaCoachTBC.GetBracket())
end)

H.it(g, "L resolves callout keys via Core when present", function()
    -- Load Core so the L delegate has the locale table to read from.
    H.load("Locales/enUS.lua")
    H.load("Core.lua")
    local resolved = _G.ArenaCoachTBC.L("CALL_HOJ_KILL")
    H.assertEq(resolved, "HoJ kill target")
end)

H.it(g, "L falls back to the key when Core is missing", function()
    -- Temporarily wipe the Core reference and ensure L doesn't crash.
    local savedCore = H.ns.Core
    H.ns.Core = nil
    H.assertEq(_G.ArenaCoachTBC.L("NOT_A_REAL_KEY"), "NOT_A_REAL_KEY")
    H.ns.Core = savedCore
end)
