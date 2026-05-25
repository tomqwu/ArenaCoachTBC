-- Tests/SpecMatchE2E_spec.lua
--
-- End-to-end spec-match tests (M7 #58). Each test drives spec attribution
-- through the real SpellSpecHints:Apply path with concrete spell IDs from
-- Data/Spells.lua, then asserts Strategies:Identify picks the expected
-- spec-keyed variant with the expected confidence.
--
-- Existing Strategies_spec / StrategyEngine_extra_spec tests set
-- e.specGuess directly. This file is deliberately the lower-level
-- counterpart: it goes through the CLEU-driven inference pipeline so a
-- future change to either Spells, SpellSpecHints, or Strategies that
-- breaks the round-trip is caught here.
local H = _G.__ACC_TEST_HELPERS
H.load("Data/Spells.lua")
H.load("Data/Classes.lua")
H.load("Data/SpellSpecHints.lua")
H.load("Data/Strategies.lua")
H.load("Locales/enUS.lua")

local S    = H.ns.Spells
local SSH  = H.ns.SpellSpecHints
local ST   = H.ns.Strategies

local g = H.describe("SpecMatchE2E")

-- Build a fresh enemy table from a (class, alive=true, role=DPS) seed.
-- Each enemy is keyed by its assigned arena unit so callers can mutate
-- them and Strategies:Identify still sees the live map.
local function makeEnemies(seeds)
    local out = {}
    for _, s in ipairs(seeds) do
        out[s.unit] = {
            class      = s.class,
            roleGuess  = s.role or nil,
            alive      = true,
        }
    end
    return out
end

-- Apply a spec-defining cast to the enemy of class `class`. Returns the
-- enemy so callers can chain.
local function castOn(enemies, class, spellID)
    for _, e in pairs(enemies) do
        if e.class == class then
            SSH:Apply(e, spellID)
            return e
        end
    end
    error("no enemy of class " .. class)
end

local function classListOf(enemies)
    local out = {}
    for _, e in pairs(enemies) do table.insert(out, e.class) end
    return out
end

-- =================================================================
-- Per-variant end-to-end matches (acceptance #1)
-- =================================================================

H.it(g, "RMP_DISC_3V3 selected after observed Pain Suppression", function()
    local enemies = makeEnemies({
        { unit = "a1", class = "ROGUE", role = "MELEE"  },
        { unit = "a2", class = "MAGE",  role = "CASTER" },
        { unit = "a3", class = "PRIEST"                },
    })
    castOn(enemies, "PRIEST", S.PAIN_SUPPRESSION)  -- -> DISCIPLINE / HEALER
    local comp, conf = ST:Identify(classListOf(enemies), enemies, 3)
    H.assertEq(comp.id, "RMP_DISC_3V3")
    H.assertEq(conf, 1.0)
end)

H.it(g, "SMR_3V3 selected after observed Shadowform on the priest", function()
    local enemies = makeEnemies({
        { unit = "a1", class = "ROGUE", role = "MELEE"  },
        { unit = "a2", class = "MAGE",  role = "CASTER" },
        { unit = "a3", class = "PRIEST", role = "HEALER" },
    })
    -- Shadowform also flips the priest to roleGuess=CASTER, which would
    -- trigger TRIPLE_DPS via the dynamic branch. Pin the role back to
    -- HEALER after the cast so the static spec-keyed branch is the one
    -- exercised by this test. (Production behaviour: shadow priest goes
    -- to TRIPLE_DPS — see the dedicated test below.)
    local p = castOn(enemies, "PRIEST", S.SHADOWFORM)
    p.roleGuess = "HEALER"
    local comp, conf = ST:Identify(classListOf(enemies), enemies, 3)
    H.assertEq(comp.id, "SMR_3V3")
    H.assertEq(conf, 1.0)
end)

H.it(g, "Shadow priest in 3v3 with no other healer fires TRIPLE_DPS dynamic", function()
    local enemies = makeEnemies({
        { unit = "a1", class = "ROGUE", role = "MELEE"  },
        { unit = "a2", class = "MAGE",  role = "CASTER" },
        { unit = "a3", class = "PRIEST"                },
    })
    castOn(enemies, "PRIEST", S.SHADOWFORM)  -- specGuess=SHADOW, roleGuess=CASTER
    local comp, conf = ST:Identify(classListOf(enemies), enemies, 3)
    H.assertEq(comp.id, "TRIPLE_DPS")
    H.assertEq(conf, 1.0)
end)

H.it(g, "WLD_RESTO_3V3 selected after observed Lifebloom on the druid", function()
    local enemies = makeEnemies({
        { unit = "a1", class = "WARRIOR", role = "MELEE"  },
        { unit = "a2", class = "WARLOCK", role = "CASTER" },
        { unit = "a3", class = "DRUID"                  },
    })
    castOn(enemies, "DRUID", S.LIFEBLOOM)  -- -> RESTORATION / HEALER
    local comp, conf = ST:Identify(classListOf(enemies), enemies, 3)
    H.assertEq(comp.id, "WLD_RESTO_3V3")
    H.assertEq(conf, 1.0)
end)

H.it(g, "WLD_FERAL_3V3 selected after observed Mangle (Cat) on the druid (triple-DPS bypassed by role gate)", function()
    local enemies = makeEnemies({
        { unit = "a1", class = "WARRIOR", role = "MELEE"  },
        { unit = "a2", class = "WARLOCK", role = "CASTER" },
        { unit = "a3", class = "DRUID"                  },
    })
    local d = castOn(enemies, "DRUID", S.MANGLE_CAT)  -- specGuess=FERAL, roleGuess=MELEE
    -- With no healer in the alive set, the dynamic TRIPLE_DPS branch
    -- fires first. To exercise the WLD_FERAL_3V3 variant directly we
    -- have to keep some healer-equivalent present; the production
    -- counterpart of this state is "feral druid + warrior + warlock
    -- with an off-team healer", which would route here. For this test
    -- we just verify the variant is reachable when roles permit.
    d.roleGuess = "HEALER"
    local comp, conf = ST:Identify(classListOf(enemies), enemies, 3)
    -- Now spec is FERAL but role lookups still see "healer" so
    -- WLD_FERAL_3V3 should fire (its specs map is {DRUID="FERAL"}).
    H.assertEq(comp.id, "WLD_FERAL_3V3")
    H.assertEq(conf, 1.0)
end)

H.it(g, "SHATTERPLAY_SHADOW_3V3 selected after Frost+Shadow+Resto signals", function()
    local enemies = makeEnemies({
        { unit = "a1", class = "MAGE",   role = "CASTER" },
        { unit = "a2", class = "PRIEST", role = "CASTER" },  -- shadow priest is casting DPS, not healing
        { unit = "a3", class = "DRUID"                },
    })
    castOn(enemies, "MAGE",   S.ICY_VEINS)     -- FROST
    castOn(enemies, "PRIEST", S.SHADOWFORM)    -- SHADOW / CASTER (matches seed)
    castOn(enemies, "DRUID",  S.LIFEBLOOM)     -- RESTORATION / HEALER
    -- Result: 1 healer (druid), 2 DPS -> static matching runs. The
    -- spec-keyed shatterplay variant wins over the class-only fallback.
    local comp, conf = ST:Identify(classListOf(enemies), enemies, 3)
    H.assertEq(comp.id, "SHATTERPLAY_SHADOW_3V3")
    H.assertEq(conf, 1.0)
end)

H.it(g, "SHATTER_FROST_2V2 selected after Frost + Disc signals (bracket=2)", function()
    local enemies = makeEnemies({
        { unit = "a1", class = "MAGE",   role = "CASTER" },
        { unit = "a2", class = "PRIEST"               },
    })
    castOn(enemies, "MAGE",   S.ICY_VEINS)         -- FROST
    castOn(enemies, "PRIEST", S.PAIN_SUPPRESSION)  -- DISCIPLINE / HEALER
    local comp, conf = ST:Identify(classListOf(enemies), enemies, 2)
    H.assertEq(comp.id, "SHATTER_FROST_2V2")
    H.assertEq(conf, 1.0)
end)

H.it(g, "HUNTER_PRIEST_BM_2V2 selected after Bestial Wrath + Pain Suppression", function()
    local enemies = makeEnemies({
        { unit = "a1", class = "HUNTER", role = "RANGED" },
        { unit = "a2", class = "PRIEST"                },
    })
    castOn(enemies, "HUNTER", S.BESTIAL_WRATH)     -- BEAST_MASTERY / RANGED
    castOn(enemies, "PRIEST", S.PAIN_SUPPRESSION)  -- DISCIPLINE / HEALER
    local comp, conf = ST:Identify(classListOf(enemies), enemies, 2)
    H.assertEq(comp.id, "HUNTER_PRIEST_BM_2V2")
    H.assertEq(conf, 1.0)
end)

-- =================================================================
-- Confidence calibration: more confirmed specs => higher confidence
-- on class-only matches (acceptance #2)
-- =================================================================

H.it(g, "class-only confidence is 0/3 when no specs observed", function()
    local enemies = makeEnemies({
        { unit = "a1", class = "ROGUE", role = "MELEE"  },
        { unit = "a2", class = "MAGE",  role = "CASTER" },
        { unit = "a3", class = "PRIEST", role = "HEALER" },
    })
    local comp, conf = ST:Identify(classListOf(enemies), enemies, 3)
    H.assertEq(comp.id, "RMP_3V3")
    H.assertEq(conf, 0.0)
end)

H.it(g, "class-only confidence rises as more specs are observed (1/3 < 2/3)", function()
    local enemies = makeEnemies({
        { unit = "a1", class = "ROGUE", role = "MELEE"  },
        { unit = "a2", class = "MAGE",  role = "CASTER" },
        { unit = "a3", class = "PRIEST", role = "HEALER" },
    })
    -- One confirmed: rogue COMBAT (doesn't match RMP_DISC, RMP_3V3 catches)
    castOn(enemies, "ROGUE", S.BLADE_FLURRY)
    local _, conf1 = ST:Identify(classListOf(enemies), enemies, 3)

    -- Two confirmed: + mage FIRE
    castOn(enemies, "MAGE", S.PYROBLAST)
    local _, conf2 = ST:Identify(classListOf(enemies), enemies, 3)

    H.assertTrue(math.abs(conf1 - (1 / 3)) < 1e-9, "1/3 expected, got " .. tostring(conf1))
    H.assertTrue(math.abs(conf2 - (2 / 3)) < 1e-9, "2/3 expected, got " .. tostring(conf2))
    H.assertTrue(conf2 > conf1, "confidence should rise as more specs confirmed")
end)

-- =================================================================
-- Wrong-spec casts must not trigger a different comp's variant
-- (acceptance #3)
-- =================================================================

H.it(g, "Holy priest (Holy Shock would be paladin) doesn't trigger RMP_DISC or SMR", function()
    local enemies = makeEnemies({
        { unit = "a1", class = "ROGUE", role = "MELEE"  },
        { unit = "a2", class = "MAGE",  role = "CASTER" },
        { unit = "a3", class = "PRIEST", role = "HEALER" },
    })
    -- Circle of Healing implies HOLY priest — neither RMP_DISC (needs
    -- DISCIPLINE) nor SMR (needs SHADOW) matches. Class-only RMP_3V3
    -- catches.
    castOn(enemies, "PRIEST", S.CIRCLE_OF_HEALING)
    local comp, conf = ST:Identify(classListOf(enemies), enemies, 3)
    H.assertEq(comp.id, "RMP_3V3")
    H.assertTrue(comp.specs == nil, "fallback should be the class-only sibling")
    -- 1 of 3 core classes has a known spec
    H.assertTrue(math.abs(conf - (1 / 3)) < 1e-9, "expected 1/3, got " .. tostring(conf))
end)

H.it(g, "Affliction warlock cast (UA) doesn't promote WLD into a spec variant lacking that key", function()
    -- WLD has no spec-keyed variant keyed off WARLOCK spec, so observing
    -- a warlock spec should leave us at class-only WLD_3V3 (no Resto/Feral
    -- info on the druid).
    local enemies = makeEnemies({
        { unit = "a1", class = "WARRIOR", role = "MELEE"  },
        { unit = "a2", class = "WARLOCK", role = "CASTER" },
        { unit = "a3", class = "DRUID",   role = "HEALER" },
    })
    castOn(enemies, "WARLOCK", S.UNSTABLE_AFFLICTION)
    local comp, conf = ST:Identify(classListOf(enemies), enemies, 3)
    H.assertEq(comp.id, "WLD_3V3")
    H.assertTrue(comp.specs == nil)
    H.assertTrue(math.abs(conf - (1 / 3)) < 1e-9)
end)

H.it(g, "Disc priest cast does NOT trigger the SMR shadow variant", function()
    local enemies = makeEnemies({
        { unit = "a1", class = "ROGUE", role = "MELEE"  },
        { unit = "a2", class = "MAGE",  role = "CASTER" },
        { unit = "a3", class = "PRIEST", role = "HEALER" },
    })
    castOn(enemies, "PRIEST", S.PAIN_SUPPRESSION)  -- DISCIPLINE
    local comp, conf = ST:Identify(classListOf(enemies), enemies, 3)
    H.assertEq(comp.id, "RMP_DISC_3V3", "DISCIPLINE must pick the disc variant, not SMR")
    H.assertEq(conf, 1.0)
end)

H.it(g, "Shadowform on a priest in HUNTER_PRIEST_2V2 setup doesn't accidentally trigger SMR_3V3", function()
    -- Bracket isolation: a 2v2 hunter+priest with shadow spec must not
    -- match a 3v3 spec-keyed comp.
    local enemies = makeEnemies({
        { unit = "a1", class = "HUNTER", role = "RANGED" },
        { unit = "a2", class = "PRIEST", role = "HEALER" },
    })
    local p = castOn(enemies, "PRIEST", S.SHADOWFORM)
    p.roleGuess = "HEALER"
    local comp = ST:Identify(classListOf(enemies), enemies, 2)
    H.assertNotNil(comp)
    H.assertEq(comp.bracket, 2, "2v2 lookup must not return a 3v3 comp")
end)

-- =================================================================
-- Round-trip sanity: SpellSpecHints byID -> Identify behaviour
-- =================================================================

H.it(g, "every spec-keyed comp's required spec is reachable from at least one SpellSpecHints entry", function()
    -- Build a reverse index of spec -> {spellIDs that produce it}.
    local specToSpells = {}
    for spellID, hint in pairs(SSH.byID) do
        specToSpells[hint.spec] = specToSpells[hint.spec] or {}
        table.insert(specToSpells[hint.spec], spellID)
    end
    for _, comp in ipairs(ST.comps) do
        if comp.specs then
            for cls, spec in pairs(comp.specs) do
                H.assertNotNil(
                    specToSpells[spec],
                    comp.id .. " requires " .. cls .. "=" .. spec
                        .. " but no SpellSpecHints entry produces " .. spec)
            end
        end
    end
end)
