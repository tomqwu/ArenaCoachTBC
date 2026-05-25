-- Tests/Spells_spec.lua
local H = _G.__ACC_TEST_HELPERS
H.load("Locales/enUS.lua")
H.load("Data/Spells.lua")
local S = H.ns.Spells

local g = H.describe("Spells")

H.it(g, "has all warrior IDs", function()
    H.assertEq(S.MORTAL_STRIKE, 30330)
    H.assertEq(S.HAMSTRING, 25212)
    H.assertEq(S.PUMMEL, 6554)
end)

H.it(g, "has CATEGORIES mappings for stuns/fears/CC", function()
    H.assertEq(S.CATEGORIES[S.HAMMER_OF_JUSTICE], "STUN")
    H.assertEq(S.CATEGORIES[S.PSYCHIC_SCREAM], "FEAR")
    H.assertEq(S.CATEGORIES[S.POLYMORPH], "INCAPACITATE")
    H.assertEq(S.CATEGORIES[S.CYCLONE], "CYCLONE")
    H.assertEq(S.CATEGORIES[S.FROST_NOVA], "ROOT")
    H.assertEq(S.CATEGORIES[S.BLIND], "DISORIENT")
end)

H.it(g, "IMMUNITY_BUFFS includes Ice Block + Divine Shield + BoP + Cloak", function()
    H.assertEq(S.IMMUNITY_BUFFS[S.ICE_BLOCK], "Ice Block")
    H.assertEq(S.IMMUNITY_BUFFS[S.DIVINE_SHIELD], "Divine Shield")
    H.assertEq(S.IMMUNITY_BUFFS[S.BLESSING_PROTECT], "Blessing of Protection")
    H.assertEq(S.IMMUNITY_BUFFS[S.CLOAK_OF_SHADOWS], "Cloak of Shadows")
end)

H.it(g, "MAJOR_DEFENSIVES includes Pain Suppression + Barkskin", function()
    H.assertNotNil(S.MAJOR_DEFENSIVES[S.PAIN_SUPPRESSION])
    H.assertNotNil(S.MAJOR_DEFENSIVES[S.BARKSKIN])
end)

H.it(g, "PURGEABLE includes Blessing of Freedom + Icy Veins", function()
    H.assertNotNil(S.PURGEABLE[S.BLESSING_FREEDOM])
    H.assertNotNil(S.PURGEABLE[S.ICY_VEINS])
end)

H.it(g, "Cold Snap and Icy Veins use distinct spell IDs", function()
    H.assertEq(S.COLD_SNAP, 11958)
    H.assertEq(S.ICY_VEINS, 12472)
    H.assertNotEq(S.COLD_SNAP, S.ICY_VEINS)
end)

H.it(g, "PVP_TRINKET_EFFECT is 42292 (shared trinket aura)", function()
    H.assertEq(S.PVP_TRINKET_EFFECT, 42292)
end)

H.it(g, "WILL_OF_THE_FORSAKEN is 7744 (Undead racial, distinct from trinket)", function()
    H.assertEq(S.WILL_OF_THE_FORSAKEN, 7744)
end)

H.it(g, "CC_BREAK_RACIALS lists WotF but not the shared trinket effect", function()
    H.assertNotNil(S.CC_BREAK_RACIALS[S.WILL_OF_THE_FORSAKEN])
    H.assertNil(S.CC_BREAK_RACIALS[S.PVP_TRINKET_EFFECT])
end)

H.it(g, "Name() returns name when GetSpellInfo exists", function()
    H.assertEq(S:Name(30330), "Spell30330")
end)

H.it(g, "Name() returns nil for nil ID", function()
    H.assertNil(S:Name(nil))
end)

H.it(g, "Name() returns cached value on second call", function()
    S.names[12345] = "MyCachedName"
    H.assertEq(S:Name(12345), "MyCachedName")
end)

H.it(g, "RefreshNames populates the names cache", function()
    S.names = {}
    S:RefreshNames()
    H.assertNotNil(S.names[S.MORTAL_STRIKE])
end)

H.it(g, "IdByName returns nil for unknown name", function()
    H.assertNil(S:IdByName(nil))
    H.assertNil(S:IdByName("DefinitelyNotASpellName"))
end)

H.it(g, "IdByName finds back a known id from its cached name", function()
    S:RefreshNames()
    local id = S:IdByName(S:Name(S.MORTAL_STRIKE))
    H.assertEq(id, S.MORTAL_STRIKE)
end)

H.it(g, "RefreshNames bails out without GetSpellInfo", function()
    local saved = _G.GetSpellInfo
    _G.GetSpellInfo = nil
    -- Should not error
    S:RefreshNames()
    _G.GetSpellInfo = saved
end)

H.it(g, "Name() falls back to tostring when no API", function()
    local saved = _G.GetSpellInfo
    _G.GetSpellInfo = nil
    S.names[9999] = nil
    H.assertEq(S:Name(9999), "9999")
    _G.GetSpellInfo = saved
end)
