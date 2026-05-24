-- Tests/Strategies_spec.lua
local H = _G.__ACC_TEST_HELPERS
H.load("Data/Classes.lua")
H.load("Data/Strategies.lua")
local ST = H.ns.Strategies

local g = H.describe("Strategies")

H.it(g, "Identify returns nil for empty class list", function()
    H.assertNil(ST:Identify({}))
    H.assertNil(ST:Identify(nil))
end)

H.it(g, "Identify finds RMP when MAGE/PRIEST/ROGUE present (1 healer)", function()
    -- Druid is overridden to DPS so we don't trigger DOUBLE_HEALER
    local enemies = {
        a = { class = "MAGE", roleGuess = "CASTER" },
        b = { class = "PRIEST" },
        c = { class = "ROGUE", roleGuess = "MELEE" },
        d = { class = "WARRIOR", roleGuess = "MELEE" },
        e = { class = "DRUID", roleGuess = "MELEE" },
    }
    local c = ST:Identify({"MAGE","PRIEST","ROGUE","WARRIOR","DRUID"}, enemies)
    H.assertEq(c.id, "RMP")
end)

H.it(g, "Identify falls back to TRIPLE_DPS when 0 healers", function()
    -- Override roles via enemies map
    local enemies = {
        a = { class = "WARRIOR", roleGuess = "MELEE" },
        b = { class = "ROGUE",   roleGuess = "MELEE" },
        c = { class = "MAGE",    roleGuess = "CASTER" },
    }
    local c = ST:Identify({"WARRIOR","ROGUE","MAGE"}, enemies)
    H.assertEq(c.id, "TRIPLE_DPS")
    H.assertEq(c.defaultMode, "DEFEND")
end)

H.it(g, "Identify finds DOUBLE_HEALER when 2 healers", function()
    local enemies = {
        a = { class = "PRIEST" },
        b = { class = "DRUID" },
        c = { class = "WARRIOR" },
    }
    local c = ST:Identify({"PRIEST","DRUID","WARRIOR"}, enemies)
    H.assertEq(c.id, "DOUBLE_HEALER")
end)

H.it(g, "Identify chooses static comp when 1 healer + signature matches", function()
    local enemies = {
        a = { class = "WARLOCK", roleGuess = "CASTER" },
        b = { class = "DRUID" },  -- healer
        c = { class = "WARRIOR", roleGuess = "MELEE" },
    }
    local c = ST:Identify({"WARLOCK","DRUID","WARRIOR"}, enemies)
    H.assertEq(c.id, "WLD")
end)

H.it(g, "Identify uses class list path when no enemies table", function()
    local c = ST:Identify({"WARLOCK","DRUID","WARRIOR"})
    H.assertTrue(c ~= nil and c.id == "WLD")
end)

H.it(g, "testComps has all 5 entries", function()
    H.assertEq(#ST.testComps, 5)
    for _, t in ipairs(ST.testComps) do
        H.assertNotNil(t.label)
        H.assertEq(#t.classes, 5)
    end
end)

H.it(g, "ApplyOwnVariant returns base comp when no variants", function()
    local base = { id = "X", openTarget = "A" }
    local out = ST:ApplyOwnVariant(base, "MELEE_CLEAVE")
    H.assertEq(out.openTarget, "A")
end)

H.it(g, "ApplyOwnVariant merges variant fields", function()
    local rmp
    for _, c in ipairs(ST.comps) do if c.id == "RMP" then rmp = c end end
    H.assertNotNil(rmp)
    local out = ST:ApplyOwnVariant(rmp, "DRAIN")
    H.assertEq(out._variantApplied, "DRAIN")
    H.assertNotNil(out.note)
end)

H.it(g, "ApplyOwnVariant returns nil for nil input", function()
    H.assertNil(ST:ApplyOwnVariant(nil, "MELEE_CLEAVE"))
end)

H.it(g, "ApplyOwnVariant returns comp unchanged when archetype unknown", function()
    local base = { id = "X", openTarget = "A", ownVariants = { Y = { openTarget = "B" } } }
    local out = ST:ApplyOwnVariant(base, "Z")
    H.assertEq(out.openTarget, "A")
end)

H.it(g, "comps catalog contains expanded entries", function()
    local ids = {}
    for _, c in ipairs(ST.comps) do ids[c.id] = true end
    -- The expanded database should at least contain these
    for _, expected in ipairs({"RMP","WMS","WLD","WLS","WLP","HUNTER_COMP",
                                "BEAST_CLEAVE","TSG","RLS","MIRROR_MELEE",
                                "TRIPLE_CASTER","DOUBLE_HEALER","TRIPLE_DPS"}) do
        H.assertTrue(ids[expected], "missing comp: " .. expected)
    end
end)

H.it(g, "Identify accepts a bracket arg and skips non-matching brackets", function()
    -- Install a temporary bracket-2 comp; Identify with bracket=3 should miss it.
    local saved = ST.comps
    ST.comps = {
        { id = "DEMO_2V2", core = { MAGE = true, PRIEST = true }, bracket = 2 },
        { id = "GENERIC",  core = { MAGE = true, PRIEST = true } },
    }
    local m = ST:Identify({"MAGE", "PRIEST"}, nil, 3)
    H.assertEq(m.id, "GENERIC", "should fall back to generic when bracket=3 and demo is 2v2")

    -- With bracket=2, the bracket-specific comp wins.
    m = ST:Identify({"MAGE", "PRIEST"}, nil, 2)
    H.assertEq(m.id, "DEMO_2V2", "bracket=2 should pick the bracket-tagged comp")

    -- No bracket arg = bracket-agnostic, still finds whichever comes first.
    m = ST:Identify({"MAGE", "PRIEST"}, nil, nil)
    H.assertNotNil(m, "nil bracket should match any comp")
    ST.comps = saved
end)

H.it(g, "Identify with bracket-only catalog returns nil when bracket mismatches", function()
    local saved = ST.comps
    ST.comps = {
        { id = "ONLY_2V2", core = { MAGE = true, PRIEST = true }, bracket = 2 },
    }
    H.assertNil(ST:Identify({"MAGE", "PRIEST"}, nil, 5))
    ST.comps = saved
end)

H.it(g, "2v2 catalog contains at least 8 bracket-tagged entries", function()
    local found = {}
    for _, c in ipairs(ST.comps) do
        if c.bracket == 2 then table.insert(found, c.id) end
    end
    H.assertTrue(#found >= 8, "expected >=8 2v2 comps, got " .. #found)
end)

H.it(g, "3v3 catalog contains at least 10 bracket-tagged entries", function()
    local found = {}
    for _, c in ipairs(ST.comps) do
        if c.bracket == 3 then table.insert(found, c.id) end
    end
    H.assertTrue(#found >= 10, "expected >=10 3v3 comps, got " .. #found)
end)

H.it(g, "every bracket-tagged comp has core, openTarget, callouts", function()
    for _, c in ipairs(ST.comps) do
        if c.bracket then
            H.assertNotNil(c.id,         "comp missing id")
            H.assertNotNil(c.label,      c.id .. " missing label")
            H.assertNotNil(c.core,       c.id .. " missing core")
            H.assertNotNil(c.openTarget, c.id .. " missing openTarget")
            H.assertNotNil(c.callouts,   c.id .. " missing callouts")
        end
    end
end)

H.it(g, "bracket=2 RP comp matches when ROGUE+PRIEST present", function()
    local m = ST:Identify({"ROGUE","PRIEST"}, nil, 2)
    H.assertNotNil(m)
    H.assertEq(m.bracket, 2)
end)

H.it(g, "bracket=3 RMP comp matches when ROGUE+MAGE+PRIEST present", function()
    local m = ST:Identify({"ROGUE","MAGE","PRIEST"}, nil, 3)
    H.assertNotNil(m)
    H.assertEq(m.id, "RMP_3V3")
end)

H.it(g, "every bracket-tagged comp references existing locale keys", function()
    H.load("Locales/enUS.lua")
    local L = H.ns.locales and H.ns.locales.enUS
    H.assertNotNil(L, "enUS locale failed to load")
    for _, c in ipairs(ST.comps) do
        if c.bracket and c.callouts then
            for _, key in ipairs(c.callouts) do
                H.assertNotNil(L[key], c.id .. " uses missing locale key " .. key)
            end
        end
    end
end)
