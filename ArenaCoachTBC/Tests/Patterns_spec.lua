-- Tests/Patterns_spec.lua (M10 #69)
local H = _G.__ACC_TEST_HELPERS
H.load("Data/Spells.lua")
H.load("Patterns.lua")

local P = H.ns.Patterns
local S = H.ns.Spells

local g = H.describe("Patterns")

local function reset() P:Clear() end

H.it(g, "defs catalog has at least 5 patterns", function()
    H.assertTrue(#P.defs >= 5, "expected >=5 patterns, got " .. #P.defs)
end)

H.it(g, "every pattern has id, labelKey, and a non-empty steps list", function()
    for _, def in ipairs(P.defs) do
        H.assertNotNil(def.id)
        H.assertNotNil(def.labelKey)
        H.assertTrue(def.steps and #def.steps > 0, def.id .. " missing steps")
    end
end)

H.it(g, "Observe of a pattern's full sequence fires the match", function()
    reset()
    -- RMP_CHEAP_BLIND: KIDNEY_SHOT -> BLIND within 6s
    P:Observe(S.KIDNEY_SHOT, 1000)
    P:Observe(S.BLIND,       1003)
    H.assertEq(P:Probability("RMP_CHEAP_BLIND"), 1.0)
    local matches = P:GetMatches(0.99)
    local found = false
    for _, m in ipairs(matches) do if m.id == "RMP_CHEAP_BLIND" then found = true end end
    H.assertTrue(found, "expected RMP_CHEAP_BLIND in matches")
end)

H.it(g, "Observe of partial sequence yields fractional probability", function()
    reset()
    P:Observe(S.KIDNEY_SHOT, 1000)
    H.assertEq(P:Probability("RMP_CHEAP_BLIND"), 0.5)
end)

H.it(g, "Observe out of order does not match", function()
    reset()
    P:Observe(S.BLIND, 1000)
    H.assertEq(P:Probability("RMP_CHEAP_BLIND"), 0.0)
end)

H.it(g, "Observe step 2 outside withinSeconds does not advance", function()
    reset()
    P:Observe(S.FROST_NOVA, 1000)
    P:Observe(S.POLYMORPH,  1010)  -- 10s > 3s window
    H.assertEq(P:Probability("SHATTER_NOVA_SHEEP"), 0.5,
        "step 1 should be matched, step 2 should fail the window")
end)

H.it(g, "STATE_TTL expires stale half-matches", function()
    reset()
    P:Observe(S.KIDNEY_SHOT, 1000)
    H.assertEq(P:Probability("RMP_CHEAP_BLIND"), 0.5)
    -- 20s later: TTL (12s default) has expired -> half-match dropped
    -- BUT this BLIND observe is also outside the 6s window, so it
    -- would fail step 2 anyway. The TTL guard kicks in to reset
    -- step counter to 0.
    P:Observe(S.BLIND, 1020)
    H.assertEq(P:Probability("RMP_CHEAP_BLIND"), 0.0,
        "stale half-match should have been forgotten")
end)

H.it(g, "GetMatches honours threshold", function()
    reset()
    P:Observe(S.KIDNEY_SHOT, 1000)  -- 50% only
    H.assertEq(#P:GetMatches(0.6), 0, "0.5 < 0.6 threshold => no match")
    H.assertEq(#P:GetMatches(0.4), 1, "0.5 >= 0.4 threshold => one match")
end)

H.it(g, "Clear resets all progress", function()
    reset()
    P:Observe(S.KIDNEY_SHOT, 1000)
    H.assertEq(P:Probability("RMP_CHEAP_BLIND"), 0.5)
    P:Clear()
    H.assertEq(P:Probability("RMP_CHEAP_BLIND"), 0.0)
end)

H.it(g, "Observe(nil, ts) is a no-op", function()
    reset()
    P:Observe(nil, 1000)
    H.assertEq(P:Probability("RMP_CHEAP_BLIND"), 0.0)
end)

H.it(g, "Each named pattern can match its full sequence (positive case)", function()
    reset()
    P:Observe(S.FROST_NOVA, 1000); P:Observe(S.POLYMORPH, 1002)
    H.assertEq(P:Probability("SHATTER_NOVA_SHEEP"), 1.0)

    reset()
    P:Observe(S.HOWL_OF_TERROR, 1000); P:Observe(S.POLYMORPH, 1003)
    H.assertEq(P:Probability("FEAR_INTO_POLY"), 1.0)

    reset()
    P:Observe(S.FREEZING_TRAP, 1000); P:Observe(S.SCATTER_SHOT, 1003)
    H.assertEq(P:Probability("HUNTER_TRAP_SCATTER"), 1.0)

    reset()
    P:Observe(S.HAMMER_OF_JUSTICE, 1000); P:Observe(S.INTERCEPT, 1002)
    H.assertEq(P:Probability("HOJ_INTO_INTERCEPT"), 1.0)
end)

H.it(g, "Unrelated cast in the middle does not break the chain", function()
    reset()
    P:Observe(S.KIDNEY_SHOT, 1000)
    P:Observe(S.MORTAL_STRIKE, 1001)  -- unrelated to RMP_CHEAP_BLIND
    P:Observe(S.BLIND, 1003)
    H.assertEq(P:Probability("RMP_CHEAP_BLIND"), 1.0,
        "unrelated casts should not reset the chain progress")
end)

-- =================================================================
-- M16 (v2.1): per-source progress tracking
-- =================================================================

H.it(g, "per-source progress: two priests casting PSYCHIC_SCREAM don't collide", function()
    reset()
    -- Two priests each cast PSYCHIC_SCREAM at the start of the FEAR_INTO_POLY
    -- chain. Before v2.1 progress was keyed by pattern only, so the second
    -- cast either reset state or false-completed via the next mage poly.
    P:Observe(S.HOWL_OF_TERROR, 1000, "g-priestA")
    P:Observe(S.HOWL_OF_TERROR, 1001, "g-priestB")
    -- priestA: stepIdx=1 (Howl); priestB: stepIdx=1 (Howl). Independent.
    H.assertEq(P:Probability("FEAR_INTO_POLY", "g-priestA"), 0.5)
    H.assertEq(P:Probability("FEAR_INTO_POLY", "g-priestB"), 0.5)
end)

H.it(g, "per-source progress: completing chain on one source doesn't advance another", function()
    reset()
    -- priestA completes the chain (Howl → Poly within 4s); priestB only has
    -- step 1. Probability per-source should reflect that.
    P:Observe(S.HOWL_OF_TERROR, 1000, "g-priestA")
    P:Observe(S.HOWL_OF_TERROR, 1001, "g-priestB")
    P:Observe(S.POLYMORPH, 1003, "g-mage")  -- mage casts the poly
    -- Without per-source semantics on step 2 this would NOT advance either
    -- priest's chain because the caster is different. Within-source
    -- semantics: neither priest's chain advances.
    H.assertEq(P:Probability("FEAR_INTO_POLY", "g-priestA"), 0.5,
        "priest A's chain should stay at step 1 (poly was cast by mage)")
    H.assertEq(P:Probability("FEAR_INTO_POLY", "g-priestB"), 0.5,
        "priest B's chain should stay at step 1")
end)

H.it(g, "legacy 2-arg Observe still works for callers that haven't been updated", function()
    reset()
    P:Observe(S.KIDNEY_SHOT, 1000)
    P:Observe(S.BLIND,       1003)
    -- The sourceGUID defaulted to "_anon" sentinel; chain completes.
    H.assertEq(P:Probability("RMP_CHEAP_BLIND"), 1.0,
        "legacy 2-arg Observe must still complete the chain")
end)

H.it(g, "Probability without sourceGUID returns MAX across all tracked sources", function()
    reset()
    P:Observe(S.KIDNEY_SHOT, 1000, "g-rogueA")
    P:Observe(S.KIDNEY_SHOT, 1000, "g-rogueB")
    P:Observe(S.BLIND,       1002, "g-rogueA")  -- rogueA completes
    -- rogueA: 1.0, rogueB: 0.5. Probability(id) with no source picks the max.
    H.assertEq(P:Probability("RMP_CHEAP_BLIND"), 1.0)
end)
