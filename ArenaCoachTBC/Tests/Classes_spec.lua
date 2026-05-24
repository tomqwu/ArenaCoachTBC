-- Tests/Classes_spec.lua
local H = _G.__ACC_TEST_HELPERS
H.load("Data/Classes.lua")
local C = H.ns.Classes

local g = H.describe("Classes")

H.it(g, "Info returns empty for nil class", function()
    H.assertType(C:Info(nil), "table")
    H.assertNil(next(C:Info(nil)))
end)

H.it(g, "Info returns table for known class", function()
    local info = C:Info("WARRIOR")
    H.assertEq(info.armor, "PLATE")
    H.assertEq(info.defaultRole, "MELEE")
end)

H.it(g, "Info returns empty for unknown class", function()
    local info = C:Info("FAKE_CLASS")
    H.assertNil(next(info))
end)

H.it(g, "DefaultRole returns MELEE for warrior", function()
    H.assertEq(C:DefaultRole("WARRIOR"), "MELEE")
end)

H.it(g, "DefaultRole returns HEALER for druid by default", function()
    H.assertEq(C:DefaultRole("DRUID"), "HEALER")
end)

H.it(g, "DefaultRole returns MELEE fallback for unknown class", function()
    H.assertEq(C:DefaultRole("FOO"), "MELEE")
end)

H.it(g, "IsCloth returns true for mage and priest", function()
    H.assertTrue(C:IsCloth("MAGE"))
    H.assertTrue(C:IsCloth("PRIEST"))
    H.assertTrue(C:IsCloth("WARLOCK"))
end)

H.it(g, "IsCloth returns false for warrior", function()
    H.assertFalse(C:IsCloth("WARRIOR"))
end)

H.it(g, "IsHealer for priest with no spec defaults true", function()
    H.assertTrue(C:IsHealer("PRIEST", nil))
end)

H.it(g, "IsHealer for priest SHADOW = false", function()
    H.assertFalse(C:IsHealer("PRIEST", "SHADOW"))
end)

H.it(g, "IsHealer for druid RESTO = true", function()
    H.assertTrue(C:IsHealer("DRUID", "RESTO"))
    H.assertTrue(C:IsHealer("DRUID", "RESTORATION"))
end)

H.it(g, "IsHealer for druid FERAL = false", function()
    H.assertFalse(C:IsHealer("DRUID", "FERAL"))
end)

H.it(g, "IsHealer for paladin HOLY = true", function()
    H.assertTrue(C:IsHealer("PALADIN", "HOLY"))
end)

H.it(g, "IsHealer for paladin RETRIBUTION = false", function()
    H.assertFalse(C:IsHealer("PALADIN", "RETRIBUTION"))
end)

H.it(g, "IsHealer for shaman RESTO = true", function()
    H.assertTrue(C:IsHealer("SHAMAN", "RESTORATION"))
end)

H.it(g, "IsHealer for unknown class returns false", function()
    H.assertFalse(C:IsHealer("WARRIOR", nil))
    H.assertFalse(C:IsHealer(nil, nil))
end)

H.it(g, "TokenToClass maps various shorthand", function()
    H.assertEq(C:TokenToClass("war"), "WARRIOR")
    H.assertEq(C:TokenToClass("enh"), "SHAMAN")
    H.assertEq(C:TokenToClass("ret"), "PALADIN")
    H.assertEq(C:TokenToClass("druid"), "DRUID")
    H.assertEq(C:TokenToClass("priest"), "PRIEST")
    H.assertEq(C:TokenToClass("mage"), "MAGE")
    H.assertEq(C:TokenToClass("lock"), "WARLOCK")
    H.assertEq(C:TokenToClass("warlock"), "WARLOCK")
    H.assertEq(C:TokenToClass("rogue"), "ROGUE")
    H.assertEq(C:TokenToClass("hunt"), "HUNTER")
    H.assertEq(C:TokenToClass("hunter"), "HUNTER")
end)

H.it(g, "TokenToClass returns nil for nil/unknown", function()
    H.assertNil(C:TokenToClass(nil))
    H.assertNil(C:TokenToClass("notarealthing"))
end)
