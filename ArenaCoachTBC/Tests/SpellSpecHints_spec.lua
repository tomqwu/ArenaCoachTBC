-- Tests/SpellSpecHints_spec.lua
local H = _G.__ACC_TEST_HELPERS
H.load("Data/Spells.lua")
H.load("Data/SpellSpecHints.lua")
local S    = H.ns.Spells
local SSH  = H.ns.SpellSpecHints

local g = H.describe("SpellSpecHints")

H.it(g, "Lookup returns nil for unknown spell IDs", function()
    H.assertNil(SSH:Lookup(nil))
    H.assertNil(SSH:Lookup(9999999))
end)

H.it(g, "Mind Flay implies SHADOW priest / CASTER", function()
    local hint = SSH:Lookup(S.MIND_FLAY)
    H.assertEq(hint.spec, "SHADOW")
    H.assertEq(hint.role, "CASTER")
end)

H.it(g, "Shadowform aura implies SHADOW priest / CASTER", function()
    local hint = SSH:Lookup(S.SHADOWFORM)
    H.assertEq(hint.role, "CASTER")
end)

H.it(g, "Holy Shock implies HOLY paladin / HEALER", function()
    local hint = SSH:Lookup(S.HOLY_SHOCK)
    H.assertEq(hint.spec, "HOLY")
    H.assertEq(hint.role, "HEALER")
end)

H.it(g, "Earth Shield implies RESTORATION shaman / HEALER", function()
    local hint = SSH:Lookup(S.EARTH_SHIELD)
    H.assertEq(hint.spec, "RESTORATION")
    H.assertEq(hint.role, "HEALER")
end)

H.it(g, "Stormstrike implies ENHANCEMENT / MELEE", function()
    H.assertEq(SSH:Lookup(S.STORMSTRIKE).role, "MELEE")
end)

H.it(g, "Mortal Strike implies ARMS warrior / MELEE", function()
    H.assertEq(SSH:Lookup(S.MORTAL_STRIKE).spec, "ARMS")
end)

H.it(g, "Bloodthirst implies FURY warrior / MELEE", function()
    H.assertEq(SSH:Lookup(S.BLOODTHIRST).spec, "FURY")
end)

H.it(g, "Crusader Strike implies RETRIBUTION paladin / MELEE", function()
    H.assertEq(SSH:Lookup(S.CRUSADER_STRIKE).spec, "RETRIBUTION")
end)

H.it(g, "Lifebloom implies RESTORATION druid / HEALER", function()
    H.assertEq(SSH:Lookup(S.LIFEBLOOM).role, "HEALER")
end)

H.it(g, "Mangle (cat) implies FERAL druid / MELEE", function()
    H.assertEq(SSH:Lookup(S.MANGLE_CAT).spec, "FERAL")
end)

H.it(g, "Unstable Affliction implies AFFLICTION lock / CASTER", function()
    H.assertEq(SSH:Lookup(S.UNSTABLE_AFFLICTION).spec, "AFFLICTION")
end)

H.it(g, "Apply updates enemy.specGuess and enemy.roleGuess", function()
    local enemy = { class = "PRIEST", specGuess = nil, roleGuess = nil }
    local changed = SSH:Apply(enemy, S.MIND_FLAY)
    H.assertTrue(changed)
    H.assertEq(enemy.specGuess, "SHADOW")
    H.assertEq(enemy.roleGuess, "CASTER")
end)

H.it(g, "Apply returns false if no hint matches", function()
    local enemy = { class = "WARRIOR" }
    H.assertFalse(SSH:Apply(enemy, 9999999))
    H.assertNil(enemy.specGuess)
end)

H.it(g, "Apply returns false on second identical call (no change)", function()
    local enemy = { class = "WARRIOR", specGuess = "ARMS", roleGuess = "MELEE" }
    H.assertFalse(SSH:Apply(enemy, S.MORTAL_STRIKE))
end)

H.it(g, "Apply tolerates nil enemy or spellID", function()
    H.assertFalse(SSH:Apply(nil, S.MIND_FLAY))
    H.assertFalse(SSH:Apply({}, nil))
end)

-- ============================================================
-- Spec inference v2: aura + talent hints (issue #57)
-- One assertion per new hint so a regression names the broken spell.
-- ============================================================

-- Priest SHADOW talents / auras
H.it(g, "Vampiric Touch implies SHADOW priest", function()
    H.assertEq(SSH:Lookup(S.VAMPIRIC_TOUCH).spec, "SHADOW")
end)
H.it(g, "Vampiric Embrace aura implies SHADOW priest", function()
    H.assertEq(SSH:Lookup(S.VAMPIRIC_EMBRACE).spec, "SHADOW")
end)
H.it(g, "Priest Silence talent implies SHADOW", function()
    H.assertEq(SSH:Lookup(S.SILENCE_PRIEST).spec, "SHADOW")
end)
-- Priest HOLY talents / auras
H.it(g, "Circle of Healing implies HOLY priest", function()
    H.assertEq(SSH:Lookup(S.CIRCLE_OF_HEALING).spec, "HOLY")
    H.assertEq(SSH:Lookup(S.CIRCLE_OF_HEALING).role, "HEALER")
end)
H.it(g, "Spirit of Redemption aura implies HOLY priest", function()
    H.assertEq(SSH:Lookup(S.SPIRIT_OF_REDEMPTION).spec, "HOLY")
end)
-- Priest DISC talents
H.it(g, "Pain Suppression implies DISCIPLINE priest", function()
    H.assertEq(SSH:Lookup(S.PAIN_SUPPRESSION).spec, "DISCIPLINE")
    H.assertEq(SSH:Lookup(S.PAIN_SUPPRESSION).role, "HEALER")
end)
H.it(g, "Power Infusion implies DISCIPLINE priest", function()
    H.assertEq(SSH:Lookup(S.POWER_INFUSION).spec, "DISCIPLINE")
end)

-- Paladin
H.it(g, "Divine Favor talent implies HOLY paladin", function()
    H.assertEq(SSH:Lookup(S.DIVINE_FAVOR).spec, "HOLY")
end)
H.it(g, "Holy Shield implies PROTECTION paladin", function()
    H.assertEq(SSH:Lookup(S.HOLY_SHIELD).spec, "PROTECTION")
end)
H.it(g, "Avenger's Shield implies PROTECTION paladin", function()
    H.assertEq(SSH:Lookup(S.AVENGERS_SHIELD).spec, "PROTECTION")
end)
H.it(g, "Repentance implies RETRIBUTION paladin", function()
    H.assertEq(SSH:Lookup(S.REPENTANCE).spec, "RETRIBUTION")
end)

-- Shaman
H.it(g, "Mana Tide Totem implies RESTORATION shaman", function()
    H.assertEq(SSH:Lookup(S.MANA_TIDE_TOTEM).spec, "RESTORATION")
end)
H.it(g, "Tidal Force implies RESTORATION shaman", function()
    H.assertEq(SSH:Lookup(S.TIDAL_FORCE).spec, "RESTORATION")
end)
H.it(g, "Shamanistic Rage implies ENHANCEMENT shaman", function()
    H.assertEq(SSH:Lookup(S.SHAMANISTIC_RAGE).spec, "ENHANCEMENT")
end)
H.it(g, "Elemental Mastery implies ELEMENTAL shaman / CASTER", function()
    H.assertEq(SSH:Lookup(S.ELEMENTAL_MASTERY).spec, "ELEMENTAL")
    H.assertEq(SSH:Lookup(S.ELEMENTAL_MASTERY).role, "CASTER")
end)

-- Warrior PROT
H.it(g, "Shield Slam implies PROTECTION warrior", function()
    H.assertEq(SSH:Lookup(S.SHIELD_SLAM).spec, "PROTECTION")
end)
H.it(g, "Last Stand implies PROTECTION warrior", function()
    H.assertEq(SSH:Lookup(S.LAST_STAND).spec, "PROTECTION")
end)

-- Druid
H.it(g, "Swiftmend implies RESTORATION druid", function()
    H.assertEq(SSH:Lookup(S.SWIFTMEND).spec, "RESTORATION")
end)
H.it(g, "Tree of Life aura implies RESTORATION druid", function()
    H.assertEq(SSH:Lookup(S.TREE_OF_LIFE).spec, "RESTORATION")
end)
H.it(g, "Moonkin Form aura implies BALANCE druid / CASTER", function()
    H.assertEq(SSH:Lookup(S.MOONKIN_FORM).spec, "BALANCE")
    H.assertEq(SSH:Lookup(S.MOONKIN_FORM).role, "CASTER")
end)
H.it(g, "Mangle (bear) implies FERAL druid", function()
    H.assertEq(SSH:Lookup(S.MANGLE_BEAR).spec, "FERAL")
end)

-- Warlock
H.it(g, "Siphon Life implies AFFLICTION warlock", function()
    H.assertEq(SSH:Lookup(S.SIPHON_LIFE).spec, "AFFLICTION")
end)
H.it(g, "Soul Link aura implies DEMONOLOGY warlock", function()
    H.assertEq(SSH:Lookup(S.SOUL_LINK).spec, "DEMONOLOGY")
end)
H.it(g, "Conflagrate implies DESTRUCTION warlock", function()
    H.assertEq(SSH:Lookup(S.CONFLAGRATE).spec, "DESTRUCTION")
end)
H.it(g, "Shadowburn implies DESTRUCTION warlock", function()
    H.assertEq(SSH:Lookup(S.SHADOWBURN).spec, "DESTRUCTION")
end)
H.it(g, "Shadowfury implies DESTRUCTION warlock", function()
    H.assertEq(SSH:Lookup(S.SHADOWFURY).spec, "DESTRUCTION")
end)

-- Mage
H.it(g, "Arcane Power implies ARCANE mage", function()
    H.assertEq(SSH:Lookup(S.ARCANE_POWER).spec, "ARCANE")
end)
H.it(g, "Slow implies ARCANE mage", function()
    H.assertEq(SSH:Lookup(S.SLOW).spec, "ARCANE")
end)
H.it(g, "Presence of Mind implies ARCANE mage", function()
    H.assertEq(SSH:Lookup(S.PRESENCE_OF_MIND).spec, "ARCANE")
end)
H.it(g, "Pyroblast implies FIRE mage", function()
    H.assertEq(SSH:Lookup(S.PYROBLAST).spec, "FIRE")
end)
H.it(g, "Combustion implies FIRE mage", function()
    H.assertEq(SSH:Lookup(S.COMBUSTION).spec, "FIRE")
end)
H.it(g, "Dragon's Breath implies FIRE mage", function()
    H.assertEq(SSH:Lookup(S.DRAGONS_BREATH).spec, "FIRE")
end)
H.it(g, "Icy Veins implies FROST mage / CASTER", function()
    H.assertEq(SSH:Lookup(S.ICY_VEINS).spec, "FROST")
    H.assertEq(SSH:Lookup(S.ICY_VEINS).role, "CASTER")
end)
H.it(g, "Summon Water Elemental implies FROST mage", function()
    H.assertEq(SSH:Lookup(S.SUMMON_WATER_ELEM).spec, "FROST")
end)

-- Rogue
H.it(g, "Mutilate implies ASSASSINATION rogue", function()
    H.assertEq(SSH:Lookup(S.MUTILATE).spec, "ASSASSINATION")
end)
H.it(g, "Cold Blood implies ASSASSINATION rogue", function()
    H.assertEq(SSH:Lookup(S.COLD_BLOOD).spec, "ASSASSINATION")
end)
H.it(g, "Blade Flurry implies COMBAT rogue", function()
    H.assertEq(SSH:Lookup(S.BLADE_FLURRY).spec, "COMBAT")
end)
H.it(g, "Adrenaline Rush implies COMBAT rogue", function()
    H.assertEq(SSH:Lookup(S.ADRENALINE_RUSH).spec, "COMBAT")
end)
H.it(g, "Premeditation implies SUBTLETY rogue", function()
    H.assertEq(SSH:Lookup(S.PREMEDITATION).spec, "SUBTLETY")
end)
H.it(g, "Shadowstep implies SUBTLETY rogue", function()
    H.assertEq(SSH:Lookup(S.SHADOWSTEP).spec, "SUBTLETY")
end)
H.it(g, "Hemorrhage implies SUBTLETY rogue", function()
    H.assertEq(SSH:Lookup(S.HEMORRHAGE).spec, "SUBTLETY")
end)

-- Hunter
H.it(g, "Bestial Wrath implies BEAST_MASTERY hunter / RANGED", function()
    H.assertEq(SSH:Lookup(S.BESTIAL_WRATH).spec, "BEAST_MASTERY")
    H.assertEq(SSH:Lookup(S.BESTIAL_WRATH).role, "RANGED")
end)
H.it(g, "Intimidation implies BEAST_MASTERY hunter", function()
    H.assertEq(SSH:Lookup(S.INTIMIDATION).spec, "BEAST_MASTERY")
end)
H.it(g, "Silencing Shot implies MARKSMANSHIP hunter", function()
    H.assertEq(SSH:Lookup(S.SILENCING_SHOT).spec, "MARKSMANSHIP")
end)
H.it(g, "Readiness implies MARKSMANSHIP hunter", function()
    H.assertEq(SSH:Lookup(S.READINESS).spec, "MARKSMANSHIP")
end)
H.it(g, "Wyvern Sting implies SURVIVAL hunter", function()
    H.assertEq(SSH:Lookup(S.WYVERN_STING).spec, "SURVIVAL")
end)

-- Catalog-level invariants
H.it(g, "byID has at least 40 entries (issue #57 floor)", function()
    local n = 0
    for _ in pairs(SSH.byID) do n = n + 1 end
    H.assertTrue(n >= 40, "expected >= 40 hints, got " .. tostring(n))
end)

H.it(g, "every hint has spec + role and role is one of the 4 valid values", function()
    local valid = { CASTER=true, MELEE=true, HEALER=true, RANGED=true }
    for id, hint in pairs(SSH.byID) do
        H.assertNotNil(hint.spec, "missing spec for id " .. tostring(id))
        H.assertNotNil(hint.role, "missing role for id " .. tostring(id))
        H.assertTrue(valid[hint.role], "bad role " .. tostring(hint.role) .. " for id " .. tostring(id))
    end
end)

H.it(g, "every hint key is a positive numeric spell ID (catches nil-key regressions)", function()
    for id, _ in pairs(SSH.byID) do
        H.assertType(id, "number", "non-numeric key in byID")
        H.assertTrue(id > 0, "non-positive key " .. tostring(id))
    end
end)

-- Apply: aura-based hint flows through to enemy.specGuess
H.it(g, "Apply for Moonkin Form aura sets BALANCE spec + CASTER role", function()
    local enemy = { class = "DRUID" }
    H.assertTrue(SSH:Apply(enemy, S.MOONKIN_FORM))
    H.assertEq(enemy.specGuess, "BALANCE")
    H.assertEq(enemy.roleGuess, "CASTER")
end)

-- Apply: talent-based hint promotes role away from class default
H.it(g, "Apply for Shield Slam reclassifies druid-tank-impostor as PROTECTION warrior", function()
    -- a warrior who has only cast Hamstring so far defaults to MELEE/ARMS guess;
    -- Shield Slam should bump them to PROTECTION
    local enemy = { class = "WARRIOR", specGuess = "ARMS", roleGuess = "MELEE" }
    H.assertTrue(SSH:Apply(enemy, S.SHIELD_SLAM))
    H.assertEq(enemy.specGuess, "PROTECTION")
end)
