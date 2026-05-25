-- Tests/Strategies_spec.lua
local H = _G.__ACC_TEST_HELPERS
H.load("Data/Spells.lua")
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

-- =================================================================
-- InstantiateChains + ScoreAll integration (M8 #61)
-- =================================================================

H.it(g, "InstantiateChains resolves byClass + targetRole into concrete chains", function()
    local enemies = {
        a = { guid = "g-rogue",  class = "ROGUE",  alive = true },
        b = { guid = "g-mage",   class = "MAGE",   alive = true },
        c = { guid = "g-priest", class = "PRIEST", alive = true },
    }
    -- Pick the RMP comp (first one declared)
    local rmp
    for _, comp in ipairs(ST.comps) do if comp.id == "RMP" then rmp = comp; break end end
    H.assertNotNil(rmp.chains)
    local out = ST:InstantiateChains(rmp, "g-priest", "g-mage", enemies)
    H.assertTrue(#out >= 1, "expected at least one instantiated chain")
    -- First RMP chain (rmp_sap_into_kidney) has SAP / POLY / KIDNEY
    H.assertEq(out[1].id, "rmp_sap_into_kidney")
    H.assertEq(out[1].links[1].by, "g-rogue")
    H.assertEq(out[1].links[1].target, "g-mage")        -- "off-healer" -> secondary
    H.assertEq(out[1].links[3].target, "g-priest")      -- "primary"
end)

H.it(g, "InstantiateChains drops links whose byClass has no live enemy", function()
    -- Build a comp with a chain that mentions a class not present on the field.
    local fakeComp = {
        id    = "X",
        core  = { ROGUE = true, MAGE = true, PRIEST = true },
        chains = {
            { id = "x_chain", label = "x", links = {
                { spellID = 1, category = "STUN", byClass = "ROGUE",  targetRole = "primary" },
                { spellID = 2, category = "STUN", byClass = "PRIEST", targetRole = "primary" },  -- priest absent
            } },
        },
    }
    local enemies = {
        r = { guid = "g-r", class = "ROGUE", alive = true },
        m = { guid = "g-m", class = "MAGE",  alive = true },
    }
    local out = ST:InstantiateChains(fakeComp, "g-m", "g-r", enemies)
    H.assertEq(#out, 1)
    H.assertEq(#out[1].links, 1, "priest link should be dropped")
    H.assertEq(out[1].links[1].by, "g-r")
end)

H.it(g, "InstantiateChains omits chains that end up with zero links", function()
    local fakeComp = {
        id   = "X",
        core = { MAGE = true },
        chains = {
            { id = "all_priest", label = "all priest", links = {
                { spellID = 1, category = "STUN", byClass = "PRIEST", targetRole = "primary" },
            } },
        },
    }
    local out = ST:InstantiateChains(fakeComp, "g-m", nil,
        { m = { guid = "g-m", class = "MAGE", alive = true } })
    H.assertEq(#out, 0)
end)

H.it(g, "InstantiateChains returns empty for a comp without chains", function()
    local fakeComp = { id = "X", core = {} }
    H.assertEq(#ST:InstantiateChains(fakeComp, nil, nil, {}), 0)
end)

-- =================================================================
-- Built-in chains per comp (M8 #60)
-- =================================================================

H.it(g, "catalog contains at least 10 chain entries across all comps", function()
    local count = 0
    for _, comp in ipairs(ST.comps) do
        if comp.chains then count = count + #comp.chains end
    end
    H.assertTrue(count >= 10, "expected >=10 chain entries, got " .. count)
end)

H.it(g, "every chain link references a non-nil spell ID", function()
    for _, comp in ipairs(ST.comps) do
        if comp.chains then
            for _, c in ipairs(comp.chains) do
                for i, link in ipairs(c.links or {}) do
                    H.assertNotNil(link.spellID,
                        comp.id .. "/" .. c.id .. "/link[" .. i .. "] missing spellID")
                end
            end
        end
    end
end)

H.it(g, "every chain link's byClass is in the comp's core (or comp is dynamic)", function()
    for _, comp in ipairs(ST.comps) do
        if comp.chains and not comp.dynamic then
            for _, c in ipairs(comp.chains) do
                for i, link in ipairs(c.links or {}) do
                    H.assertTrue(comp.core[link.byClass] == true,
                        comp.id .. "/" .. c.id .. "/link[" .. i .. "] byClass="
                            .. tostring(link.byClass) .. " is not in core")
                end
            end
        end
    end
end)

H.it(g, "every built-in chain validates against a fresh Chain state", function()
    H.load("DRTracker.lua")
    H.load("CooldownTracker.lua")
    H.load("Chain.lua")
    local Chain = H.ns.Chain
    H.ns.DRTracker:Clear()
    H.ns.CooldownTracker:Clear()
    for _, comp in ipairs(ST.comps) do
        if comp.chains then
            for _, c in ipairs(comp.chains) do
                -- Instantiate the chain by mapping byClass/targetRole to
                -- placeholder GUIDs. Each role gets a distinct GUID so the
                -- chain primitive's per-target within-chain DR accumulation
                -- behaves as the catalog author intended.
                local concrete = { links = {} }
                for _, link in ipairs(c.links) do
                    table.insert(concrete.links, {
                        spellID    = link.spellID,
                        category   = link.category,
                        target     = "tgt-" .. tostring(link.targetRole),
                        by         = "by-" .. tostring(link.byClass),
                        castTimeS  = link.castTimeS,
                    })
                end
                local ok, reason = Chain:Validate(concrete)
                H.assertTrue(ok, comp.id .. "/" .. c.id
                    .. " did not validate: " .. tostring(reason))
            end
        end
    end
end)

H.it(g, "every chain has a labelKey that resolves in the enUS locale", function()
    H.load("Locales/enUS.lua")
    local L = H.ns.locales and H.ns.locales.enUS
    H.assertNotNil(L)
    for _, comp in ipairs(ST.comps) do
        if comp.chains then
            for _, c in ipairs(comp.chains) do
                H.assertNotNil(c.labelKey, comp.id .. "/" .. c.id .. " missing labelKey")
                H.assertNotNil(L[c.labelKey],
                    comp.id .. "/" .. c.id .. " labelKey " .. c.labelKey
                    .. " not found in enUS locale")
            end
        end
    end
end)

H.it(g, "every chain has an id and a non-empty links list", function()
    for _, comp in ipairs(ST.comps) do
        if comp.chains then
            for i, c in ipairs(comp.chains) do
                H.assertNotNil(c.id,    comp.id .. " chain[" .. i .. "] missing id")
                H.assertNotNil(c.label, comp.id .. " chain[" .. i .. "] missing label")
                H.assertTrue(c.links and #c.links > 0,
                    comp.id .. " chain[" .. i .. "] has empty links")
            end
        end
    end
end)

-- =================================================================
-- Comp-match confidence (M7 #56)
-- =================================================================

H.it(g, "Identify returns (comp, confidence=1.0) for spec-keyed match", function()
    local enemies = {
        a = { class = "ROGUE", roleGuess = "MELEE",  alive = true },
        b = { class = "MAGE",  roleGuess = "CASTER", alive = true, specGuess = "FROST" },
        c = { class = "PRIEST", specGuess = "DISCIPLINE", roleGuess = "HEALER", alive = true },
    }
    local comp, conf = ST:Identify({"ROGUE","MAGE","PRIEST"}, enemies, 3)
    H.assertEq(comp.id, "RMP_DISC_3V3")
    H.assertEq(conf, 1.0)
end)

H.it(g, "Identify returns (comp, confidence=0.0) for class-list-only callers", function()
    -- The legacy signature has no enemies map -> no spec data channel -> 0.0.
    local comp, conf = ST:Identify({"ROGUE","MAGE","PRIEST"}, nil, 3)
    H.assertEq(comp.id, "RMP_3V3")
    H.assertEq(conf, 0.0)
end)

H.it(g, "Identify confidence reflects known/total spec ratio for class-only match", function()
    -- All 3 enemies in the RMP core have specGuess known -> 3/3 = 1.0.
    local enemies = {
        a = { class = "ROGUE", roleGuess = "MELEE",  alive = true, specGuess = "COMBAT" },
        b = { class = "MAGE",  roleGuess = "CASTER", alive = true, specGuess = "FIRE" },
        c = { class = "PRIEST", roleGuess = "HEALER", alive = true, specGuess = "HOLY" },
    }
    local comp, conf = ST:Identify({"ROGUE","MAGE","PRIEST"}, enemies, 3)
    -- Holy priest doesn't trigger SMR or RMP_DISC -> class-only RMP_3V3
    -- catches. Conf = 3/3 = 1.0 (all core enemies have known specs).
    H.assertEq(comp.id, "RMP_3V3")
    H.assertEq(conf, 1.0)
end)

H.it(g, "Identify confidence is fractional when only some specs are known", function()
    local enemies = {
        a = { class = "ROGUE", roleGuess = "MELEE",  alive = true },  -- spec unknown
        b = { class = "MAGE",  roleGuess = "CASTER", alive = true, specGuess = "FIRE" },
        c = { class = "PRIEST", roleGuess = "HEALER", alive = true },  -- spec unknown
    }
    local comp, conf = ST:Identify({"ROGUE","MAGE","PRIEST"}, enemies, 3)
    H.assertEq(comp.id, "RMP_3V3")
    -- 1 of 3 core classes (MAGE) has a known spec
    H.assertTrue(math.abs(conf - (1 / 3)) < 1e-9, "expected ~0.333, got " .. tostring(conf))
end)

H.it(g, "Identify confidence is 1.0 for dynamic TRIPLE_DPS comp", function()
    local enemies = {
        a = { class = "WARRIOR", roleGuess = "MELEE",  alive = true },
        b = { class = "ROGUE",   roleGuess = "MELEE",  alive = true },
        c = { class = "MAGE",    roleGuess = "CASTER", alive = true },
    }
    local comp, conf = ST:Identify({"WARRIOR","ROGUE","MAGE"}, enemies)
    H.assertEq(comp.id, "TRIPLE_DPS")
    H.assertEq(conf, 1.0)
end)

H.it(g, "Identify confidence is 1.0 for dynamic DOUBLE_HEALER comp", function()
    local enemies = {
        a = { class = "PRIEST", alive = true },
        b = { class = "DRUID",  alive = true },
        c = { class = "WARRIOR", alive = true },
    }
    local comp, conf = ST:Identify({"PRIEST","DRUID","WARRIOR"}, enemies)
    H.assertEq(comp.id, "DOUBLE_HEALER")
    H.assertEq(conf, 1.0)
end)

H.it(g, "Identify returns (nil, 0.0) for empty class list", function()
    local comp, conf = ST:Identify({})
    H.assertNil(comp)
    H.assertEq(conf, 0.0)
end)

H.it(g, "Identify returns (nil, 0.0) when no comp matches at the requested bracket", function()
    local saved = ST.comps
    ST.comps = {
        { id = "ONLY_2V2", core = { MAGE = true, PRIEST = true }, bracket = 2 },
    }
    local comp, conf = ST:Identify({"MAGE","PRIEST"}, nil, 5)
    H.assertNil(comp)
    H.assertEq(conf, 0.0)
    ST.comps = saved
end)

-- =================================================================
-- Spec-keyed comp matching (M7 #55)
-- =================================================================

H.it(g, "spec-keyed comp matches when required spec is observed", function()
    local enemies = {
        a = { class = "ROGUE", roleGuess = "MELEE",  alive = true },
        b = { class = "MAGE",  roleGuess = "CASTER", alive = true },
        c = { class = "PRIEST", specGuess = "DISCIPLINE", roleGuess = "HEALER", alive = true },
    }
    local m = ST:Identify({"ROGUE","MAGE","PRIEST"}, enemies, 3)
    H.assertEq(m.id, "RMP_DISC_3V3", "should pick spec-keyed RMP_DISC variant when priest is Disc")
end)

H.it(g, "spec-keyed comp does NOT match when observed spec differs", function()
    local enemies = {
        a = { class = "ROGUE", roleGuess = "MELEE",  alive = true },
        b = { class = "MAGE",  roleGuess = "CASTER", alive = true },
        c = { class = "PRIEST", specGuess = "HOLY",  roleGuess = "HEALER", alive = true },
    }
    local m = ST:Identify({"ROGUE","MAGE","PRIEST"}, enemies, 3)
    H.assertEq(m.id, "RMP_3V3", "Holy spec should disqualify Disc-keyed variant; SMR/RMP_DISC both miss, fall through to class-only RMP_3V3")
end)

H.it(g, "spec-keyed comp falls back to class-only when spec is unknown", function()
    local enemies = {
        a = { class = "ROGUE", roleGuess = "MELEE",  alive = true },
        b = { class = "MAGE",  roleGuess = "CASTER", alive = true },
        c = { class = "PRIEST", specGuess = nil,     alive = true },
    }
    local m = ST:Identify({"ROGUE","MAGE","PRIEST"}, enemies, 3)
    H.assertEq(m.id, "RMP_3V3", "unknown spec should fall through spec-keyed variants to class-only RMP_3V3")
end)

H.it(g, "spec-keyed comp does NOT match when called via class-list path (no enemies)", function()
    -- Without an enemies map there's no specGuess channel, so no spec-keyed
    -- comp can ever match — callers using the legacy class-list signature
    -- always land on the class-only fallback.
    local m = ST:Identify({"ROGUE","MAGE","PRIEST"}, nil, 3)
    H.assertEq(m.id, "RMP_3V3", "class-list-only caller should pick the class-only RMP_3V3")
end)

H.it(g, "spec-keyed SHADOW priest comp picks SMR over RMP", function()
    local enemies = {
        a = { class = "ROGUE", roleGuess = "MELEE",  alive = true },
        b = { class = "MAGE",  roleGuess = "CASTER", alive = true },
        c = { class = "PRIEST", specGuess = "SHADOW", roleGuess = "CASTER", alive = true },
    }
    -- Note: roleGuess=CASTER on priest means 0 healers, which fires the
    -- TRIPLE_DPS dynamic comp branch first. So override that by giving the
    -- priest healer-equivalent state — actually the M7 #55 design is that
    -- SHADOW spec implies no priest healer, which is correct behaviour.
    -- For this test we assert that when there *is* still a healer
    -- (e.g. shadow priest paired with a hybrid), SMR is the right pick.
    enemies.c.roleGuess = "HEALER"  -- artificially keep it in the static branch
    local m = ST:Identify({"ROGUE","MAGE","PRIEST"}, enemies, 3)
    H.assertEq(m.id, "SMR_3V3", "Shadow priest should pick SMR variant")
end)

H.it(g, "spec-keyed comp requires a dead enemy's spec to NOT count", function()
    -- A spec-keyed comp must not match against a dead enemy's spec. Once
    -- the spec'd unit dies, the comp ID legitimately shifts.
    local enemies = {
        a = { class = "ROGUE", roleGuess = "MELEE",  alive = true },
        b = { class = "MAGE",  roleGuess = "CASTER", alive = true },
        c = { class = "PRIEST", specGuess = "DISCIPLINE", roleGuess = "HEALER", alive = false },
    }
    local m = ST:Identify({"ROGUE","MAGE","PRIEST"}, enemies, 3)
    -- The dead priest also fails the class presence check (alive=false),
    -- so we expect no static 3v3 match. With 0 healers in alive set we
    -- expect TRIPLE_DPS dynamic.
    H.assertEq(m.id, "TRIPLE_DPS")
end)

H.it(g, "catalog contains at least 6 spec-keyed comps", function()
    local count = 0
    for _, c in ipairs(ST.comps) do
        if c.specs then count = count + 1 end
    end
    H.assertTrue(count >= 6, "expected >=6 spec-keyed comps, got " .. count)
end)

H.it(g, "every spec-keyed comp references known classes in its specs map", function()
    for _, c in ipairs(ST.comps) do
        if c.specs then
            for cls, _ in pairs(c.specs) do
                H.assertNotNil(c.core[cls], c.id .. " requires spec on " .. cls .. " but " .. cls .. " is not in its core")
            end
        end
    end
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
