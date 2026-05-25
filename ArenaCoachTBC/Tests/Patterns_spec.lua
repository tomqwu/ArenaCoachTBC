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
