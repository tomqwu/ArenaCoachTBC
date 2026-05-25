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
    H.assertEq(next(API.GetCapabilities()), nil)
    H.assertEq(next(API.GetEnemies()), nil)
    H.assertEq(next(API.GetFriendlies()), nil)
    H.assertFalse(API.HasCapability("foo"))
end)

H.it(g, "GetDebugState / GetVersion", function()
    WAB:Publish(sampleRec, sampleState)
    local d = API.GetDebugState()
    H.assertEq(d.version, "1.1.0")
    H.assertEq(d.addon, "ArenaCoachTBC")
    H.assertEq(API.GetVersion(), "1.1.0")
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
