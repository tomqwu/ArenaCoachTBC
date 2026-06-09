-- Tests/StrategySignals_spec.lua
local H = _G.__ACC_TEST_HELPERS

H.load("Data/Spells.lua")
H.load("Data/Classes.lua")
H.load("Data/OwnComps.lua")
H.load("Data/Strategies.lua")
H.load("Data/SpellSpecHints.lua")
H.load("StrategyEngine.lua")

local SE = H.ns.StrategyEngine
local S = H.ns.Spells

local g = H.describe("StrategySignals")

local function baseState(overrides)
    local state = {
        now = 100,
        pvpContext = "arena",
        bracket = 3,
        combatPhase = "ACTIVE",
        observations = { windfuryActive = true, hojReady = true, msActiveOn = "enemy-priest" },
        friendlies = {
            player = { unit = "player", guid = "friendly-warrior", name = "You", class = "WARRIOR", spec = "ARMS", roleGuess = "MELEE", alive = true, healthPct = 100 },
            party1 = { unit = "party1", guid = "friendly-shaman", name = "Sweetshammy", class = "SHAMAN", spec = "ENHANCEMENT", roleGuess = "MELEE", alive = true, healthPct = 100 },
            party2 = { unit = "party2", guid = "friendly-druid", name = "Leaves", class = "DRUID", spec = "RESTORATION", roleGuess = "HEALER", alive = true, healthPct = 100 },
        },
        enemies = {
            arena1 = { unit = "arena1", guid = "enemy-rogue", name = "Sneakstab", class = "ROGUE", roleGuess = "MELEE", alive = true, healthPct = 100, hasTrinket = true },
            arena2 = { unit = "arena2", guid = "enemy-mage", name = "Frostbiter", class = "MAGE", specGuess = "FROST", roleGuess = "CASTER", alive = true, healthPct = 100, hasTrinket = true },
            arena3 = { unit = "arena3", guid = "enemy-priest", name = "Holyman", class = "PRIEST", specGuess = "DISCIPLINE", roleGuess = "HEALER", alive = true, healthPct = 35, manaPct = 20, hasTrinket = false, importantBuffs = { [S.ICY_VEINS] = true } },
        },
    }
    for k, v in pairs(overrides or {}) do state[k] = v end
    return state
end

local function findSignal(rec, kind, id)
    for _, signal in ipairs((rec and rec.signals) or {}) do
        if signal.kind == kind and (not id or signal.id == id) then return signal end
    end
end

local function countSignals(rec, kind)
    local n = 0
    for _, signal in ipairs((rec and rec.signals) or {}) do
        if signal.kind == kind then n = n + 1 end
    end
    return n
end

local function assertCalloutsProjected(rec)
    local projected = SE:CalloutsFromSignals(rec.signals)
    H.assertEq(#projected, #rec.callouts)
    for i, key in ipairs(rec.callouts) do
        H.assertEq(projected[i], key)
    end
end

H.it(g, "KILL recommendations include strategy, callout, and player action signals", function()
    local rec = SE:Evaluate(baseState())
    H.assertEq(rec.mode, "KILL")
    H.assertNotNil(rec.signals)
    H.assertTrue(#rec.signals >= 3, "expected strategy + callout + action signals")

    local strategy = findSignal(rec, "strategy", "strategy:KILL")
    H.assertNotNil(strategy)
    H.assertEq(strategy.ownerUnit, "player")
    H.assertEq(strategy.ownerGuid, "friendly-warrior")
    H.assertEq(strategy.targetGuid, rec.primaryTarget)
    H.assertEq(strategy.targetName, rec.primaryTargetName)
    H.assertEq(strategy.displayStyle, "alert")
    H.assertEq(strategy.expiresAt, 108)
    H.assertEq(strategy.duration, 8)
    H.assertEq(strategy.sourceEvidence.mode, "KILL")

    local purge = findSignal(rec, "callout", "callout:CALL_PURGE")
    H.assertNotNil(purge)
    H.assertEq(purge.reasonKey, "CALL_PURGE")
    H.assertEq(purge.ownerUnit, "team")
    H.assertEq(purge.targetName, rec.primaryTargetName)
    H.assertEq(purge.requiredCaps[1], "hasPurge")
    H.assertEq(purge.expiresAt, 106)

    local player = findSignal(rec, "player_action", "player_action:player:ACTION_WARRIOR_KILL")
    H.assertNotNil(player)
    H.assertEq(player.ownerUnit, "player")
    H.assertEq(player.ownerGuid, "friendly-warrior")
    H.assertEq(player.targetName, rec.primaryTargetName)
    H.assertEq(player.displayStyle, "bar")
    H.assertEq(player.expiresAt, 110)

    assertCalloutsProjected(rec)
end)

H.it(g, "DEFEND strategy signal targets the pressured friendly", function()
    local state = baseState({
        observations = {
            healerUnderPressure = true,
            healerPressure = {
                targetGuid = "friendly-druid",
                targetUnit = "party2",
                targetName = "Leaves",
                targetRole = "HEALER",
                events = 4,
                window = 5,
            },
        },
    })
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND")
    local signal = findSignal(rec, "strategy", "strategy:DEFEND")
    H.assertNotNil(signal)
    H.assertEq(signal.targetGuid, "friendly-druid")
    H.assertEq(signal.targetName, "Leaves")
    H.assertEq(signal.targetType, "friendly")
    H.assertEq(signal.priority, "URGENT")
    H.assertEq(signal.expiresAt, 106)
end)

H.it(g, "OPEN and RESET strategy signals keep stable shape", function()
    local openState = baseState({ combatPhase = "PRE" })
    local openRec = SE:Evaluate(openState)
    H.assertEq(openRec.mode, "OPEN")
    local openSignal = findSignal(openRec, "strategy", "strategy:OPEN")
    H.assertNotNil(openSignal)
    H.assertEq(openSignal.ownerUnit, "player")
    H.assertEq(openSignal.targetGuid, openRec.primaryTarget)
    H.assertEq(openSignal.expiresAt, 108)

    local resetRec = SE:Evaluate({
        now = 50,
        pvpContext = "arena",
        combatPhase = "ACTIVE",
        observations = {},
        friendlies = baseState().friendlies,
        enemies = {},
    })
    H.assertEq(resetRec.mode, "RESET")
    local resetSignal = findSignal(resetRec, "strategy", "strategy:RESET")
    H.assertNotNil(resetSignal)
    H.assertNil(resetSignal.targetGuid)
    H.assertEq(resetSignal.displayStyle, "fade")
    H.assertEq(resetSignal.expiresAt, 52)
end)

H.it(g, "signal expiration helpers filter stale signals", function()
    local rec = SE:Evaluate(baseState())
    local strategy = findSignal(rec, "strategy", "strategy:KILL")
    H.assertFalse(SE:IsSignalExpired(strategy, 107.9))
    H.assertTrue(SE:IsSignalExpired(strategy, 108))
    H.assertTrue(#SE:ActiveSignals(rec.signals, 105) > 0)
    H.assertEq(#SE:ActiveSignals(rec.signals, 111), 0)
end)

H.it(g, "signal counts match compatibility action and callout lists", function()
    local rec = SE:Evaluate(baseState())
    H.assertEq(countSignals(rec, "callout"), #rec.callouts)
    H.assertEq(countSignals(rec, "player_action"), #rec.playerActions)
    assertCalloutsProjected(rec)
end)
