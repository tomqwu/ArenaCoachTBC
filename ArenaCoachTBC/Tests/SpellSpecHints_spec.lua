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
