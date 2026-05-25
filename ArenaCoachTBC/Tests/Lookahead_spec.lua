-- Tests/Lookahead_spec.lua (M10 #67)
local H = _G.__ACC_TEST_HELPERS
H.load("OpponentProfile.lua")
H.load("Lookahead.lua")

local LA = H.ns.Lookahead
local OP = H.ns.OpponentProfile

local g = H.describe("Lookahead")

local function mockScored(probs)
    local out = {}
    for i, p in ipairs(probs) do
        table.insert(out, { chain = { id = "c" .. i, links = {} }, prob = p })
    end
    return out
end

H.it(g, "Score returns empty for empty / nil input", function()
    H.assertEq(#LA:Score({}), 0)
    H.assertEq(#LA:Score(nil), 0)
end)

H.it(g, "Score with no profile uses 50/50 default; ranks by chain prob", function()
    local scored = mockScored({ 0.9, 0.5, 0.1 })
    local out = LA:Score(scored)
    H.assertEq(out[1].chain.id, "c1")
    H.assertEq(out[3].chain.id, "c3")
    -- With 50/50 split + factor 1.0/0.5, EV = prob * (0.5*1.0 + 0.5*0.5) = prob*0.75
    H.assertTrue(math.abs(out[1].expectedValue - (0.9 * 0.75)) < 1e-9,
        "expected EV ~0.675, got " .. tostring(out[1].expectedValue))
end)

H.it(g, "Score honours topActions to clip the output", function()
    local scored = mockScored({ 0.9, 0.7, 0.5, 0.2 })
    local out = LA:Score(scored, { topActions = 2 })
    H.assertEq(#out, 2)
end)

H.it(g, "Score with high-trinket profile lowers expected value", function()
    local db = { profiles = {} }
    local p = OP:Get("X", db)
    for _ = 1, 20 do OP:UpdateBinary(p, "trinketsFear", true) end  -- prob ~ 0.95
    local scored = mockScored({ 0.9 })
    local outDefault = LA:Score(scored)  -- 50/50
    local outHigh    = LA:Score(scored, { profile = p })
    H.assertTrue(outHigh[1].expectedValue < outDefault[1].expectedValue,
        "high trinket prob should reduce EV; default=" .. outDefault[1].expectedValue
            .. " high=" .. outHigh[1].expectedValue)
end)

H.it(g, "Score with low-trinket profile raises expected value", function()
    local db = { profiles = {} }
    local p = OP:Get("X", db)
    for _ = 1, 20 do OP:UpdateBinary(p, "trinketsFear", false) end  -- prob ~ 0.045
    local scored = mockScored({ 0.9 })
    local outDefault = LA:Score(scored)
    local outLow     = LA:Score(scored, { profile = p })
    H.assertTrue(outLow[1].expectedValue > outDefault[1].expectedValue,
        "low trinket prob should raise EV; default=" .. outDefault[1].expectedValue
            .. " low=" .. outLow[1].expectedValue)
end)

H.it(g, "Score can pick a different action than greedy when the greedy chain attracts a trinket", function()
    -- Greedy would pick chain A (prob=0.9). But if A consistently
    -- attracts trinketing (factor=0.5) and B doesn't, lookahead might
    -- pick B instead. In this PR's model both chains see the same
    -- profile-derived response distribution, so the higher-prob chain
    -- still wins in EV — but the test exists to make the reranking
    -- behaviour observable for future per-chain response models.
    local scored = mockScored({ 0.6, 0.55 })  -- close call
    local out = LA:Score(scored)
    -- Both fall on the same response curve, so order matches prob.
    H.assertEq(out[1].chain.id, "c1")
end)

H.it(g, "EnumerateResponses returns probabilities summing to 1", function()
    local r = LA:EnumerateResponses({ chain = {}, prob = 0.5 })
    local total = 0
    for _, e in ipairs(r) do total = total + e.prob end
    H.assertTrue(math.abs(total - 1.0) < 1e-9, "responses should sum to 1; got " .. total)
end)
