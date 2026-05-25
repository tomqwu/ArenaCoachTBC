-- Tests/Chain_spec.lua
local H = _G.__ACC_TEST_HELPERS
H.load("DRTracker.lua")
H.load("CooldownTracker.lua")
H.load("Chain.lua")

local DR    = H.ns.DRTracker
local CT    = H.ns.CooldownTracker
local Chain = H.ns.Chain

local g = H.describe("Chain")

local function freshState()
    DR:Clear()
    CT:Clear()
    H._gameTime = 1000
end

H.it(g, "Build wraps a list of links into a chain table", function()
    local c = Chain:Build({
        { target = "g-priest", category = "STUN", by = "g-rogue" },
        { target = "g-priest", category = "FEAR", by = "g-lock" },
    })
    H.assertEq(#c.links, 2)
    H.assertEq(c.links[1].category, "STUN")
end)

H.it(g, "Build with no args returns an empty chain", function()
    local c = Chain:Build()
    H.assertEq(#c.links, 0)
end)

H.it(g, "Validate rejects an empty chain", function()
    freshState()
    local ok, reason = Chain:Validate(Chain:Build({}))
    H.assertFalse(ok)
    H.assertEq(reason, "empty")
end)

H.it(g, "Validate accepts a fresh chain whose DR is clean", function()
    freshState()
    local c = Chain:Build({
        { target = "g-priest", category = "STUN" },
        { target = "g-priest", category = "FEAR" },
    })
    local ok = Chain:Validate(c)
    H.assertTrue(ok)
end)

H.it(g, "Validate rejects a 2-link chain when link 2 would land DR-immune", function()
    -- Pre-bump FEAR DR on the priest to immune (3 prior fears).
    freshState()
    DR:Apply("g-priest", "FEAR", 990)
    DR:Apply("g-priest", "FEAR", 991)
    DR:Apply("g-priest", "FEAR", 992)
    H._gameTime = 995  -- still within reset window
    local c = Chain:Build({
        { target = "g-priest", category = "STUN" },  -- fine
        { target = "g-priest", category = "FEAR" },  -- DR-immune
    })
    local ok, reason = Chain:Validate(c)
    H.assertFalse(ok)
    H.assertEq(reason, "DR_immune")
end)

H.it(g, "Validate rejects when caster CD is pending", function()
    freshState()
    -- Pretend rogue used Cheap Shot (id=1833 sentinel) recently
    CT.defaults = CT.defaults or {}
    CT.defaults[1833] = 60
    CT:_record("g-rogue", 1833, 60, 1000)
    H._gameTime = 1010  -- 50s remaining
    local c = Chain:Build({
        { target = "g-priest", category = "STUN", by = "g-rogue", spellID = 1833 },
    })
    local ok, reason = Chain:Validate(c)
    H.assertFalse(ok)
    H.assertEq(reason, "cd_pending")
end)

H.it(g, "Validate accepts when CD has elapsed", function()
    freshState()
    CT.defaults = CT.defaults or {}
    CT.defaults[1833] = 60
    CT:_record("g-rogue", 1833, 60, 1000)
    H._gameTime = 1070  -- 10s past ready
    local c = Chain:Build({
        { target = "g-priest", category = "STUN", by = "g-rogue", spellID = 1833 },
    })
    H.assertTrue(Chain:Validate(c))
end)

H.it(g, "Validate factors within-chain DR: two STUNs on same target rejects on the third", function()
    freshState()
    local c = Chain:Build({
        { target = "g-priest", category = "STUN" },  -- mult 1.0
        { target = "g-priest", category = "STUN" },  -- mult 0.5
        { target = "g-priest", category = "STUN" },  -- mult 0.25
        { target = "g-priest", category = "STUN" },  -- would be 0.0 -> reject
    })
    local ok, reason = Chain:Validate(c)
    H.assertFalse(ok)
    H.assertEq(reason, "DR_immune")
end)

H.it(g, "ExpectedProb of a fresh single-link chain is 1.0", function()
    freshState()
    local c = Chain:Build({
        { target = "g-priest", category = "STUN" },
    })
    H.assertEq(Chain:ExpectedProb(c), 1.0)
end)

H.it(g, "ExpectedProb multiplies DR multipliers across links of same category", function()
    freshState()
    local c = Chain:Build({
        { target = "g-priest", category = "STUN" },  -- 1.0
        { target = "g-priest", category = "STUN" },  -- 0.5
        { target = "g-priest", category = "STUN" },  -- 0.25
    })
    -- 1.0 * 0.5 * 0.25 = 0.125
    H.assertTrue(math.abs(Chain:ExpectedProb(c) - 0.125) < 1e-9)
end)

H.it(g, "ExpectedProb is 0 if any caster CD is pending", function()
    freshState()
    CT.defaults = CT.defaults or {}
    CT.defaults[1833] = 60
    CT:_record("g-rogue", 1833, 60, 1000)
    H._gameTime = 1010
    local c = Chain:Build({
        { target = "g-priest", category = "STUN", by = "g-rogue", spellID = 1833 },
    })
    H.assertEq(Chain:ExpectedProb(c), 0.0)
end)

H.it(g, "ExpectedProb factors observed DR (priest already stunned once)", function()
    freshState()
    DR:Apply("g-priest", "STUN", 990)
    H._gameTime = 995
    local c = Chain:Build({
        { target = "g-priest", category = "STUN" },  -- observed mult 0.5
    })
    H.assertEq(Chain:ExpectedProb(c), 0.5)
end)

H.it(g, "ExpectedProb returns 0.0 for an empty chain", function()
    H.assertEq(Chain:ExpectedProb(Chain:Build({})), 0.0)
end)

-- =================================================================
-- ScoreAll (M8 #61)
-- =================================================================

H.it(g, "ScoreAll returns chains sorted descending by ExpectedProb", function()
    freshState()
    -- Pre-bump STUN DR on g-priest so chain B (stun-priest) is halved.
    H.ns.DRTracker:Apply("g-priest", "STUN", 998)
    H._gameTime = 1000
    local chainA = Chain:Build({ { target = "g-mage",   category = "STUN" } })  -- fresh -> 1.0
    local chainB = Chain:Build({ { target = "g-priest", category = "STUN" } })  -- DRd  -> 0.5
    local scored = Chain:ScoreAll({ chainB, chainA })  -- intentionally out of order
    H.assertEq(scored[1].prob, 1.0)
    H.assertEq(scored[2].prob, 0.5)
end)

H.it(g, "ScoreAll keeps zero-prob chains in the output", function()
    freshState()
    H.ns.DRTracker:Apply("g-priest", "STUN", 998)
    H.ns.DRTracker:Apply("g-priest", "STUN", 998.1)
    H.ns.DRTracker:Apply("g-priest", "STUN", 998.2)
    H._gameTime = 1000
    local chainImmune = Chain:Build({ { target = "g-priest", category = "STUN" } })
    local scored = Chain:ScoreAll({ chainImmune })
    H.assertEq(#scored, 1)
    H.assertEq(scored[1].prob, 0.0)
end)

H.it(g, "ScoreAll honours topK to clip the output", function()
    freshState()
    local chains = {
        Chain:Build({ { target = "g-a", category = "STUN" } }),
        Chain:Build({ { target = "g-b", category = "STUN" } }),
        Chain:Build({ { target = "g-c", category = "STUN" } }),
        Chain:Build({ { target = "g-d", category = "STUN" } }),
    }
    local scored = Chain:ScoreAll(chains, { topK = 2 })
    H.assertEq(#scored, 2)
end)

H.it(g, "ScoreAll returns empty table when given nil", function()
    H.assertEq(#Chain:ScoreAll(nil), 0)
end)

H.it(g, "Validate handles missing target/category gracefully (treats as full mult)", function()
    -- A degenerate chain link with no target/category shouldn't crash;
    -- the link is treated as full-multiplier (no DR signal to consult).
    freshState()
    local c = Chain:Build({
        { spellID = 999, by = "g-rogue" },
    })
    H.assertTrue(Chain:Validate(c))
end)
