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

-- v2.10: shared class colours + display-name helpers
H.it(g, "Color returns the documented RGB for each class", function()
    -- Spot-check the four classes the user named explicitly. Tests
    -- run headless so RAID_CLASS_COLORS is absent — the local table wins.
    local r, g_, b = C:Color("MAGE")
    H.assertTrue(b > 0.9, "mage should be blue-dominant: got " .. tostring(b))
    r, g_, b = C:Color("PRIEST")
    H.assertEq(r, 1.0) H.assertEq(g_, 1.0) H.assertEq(b, 1.0)
    r, g_, b = C:Color("WARRIOR")
    H.assertTrue(r > 0.7 and b < 0.5, "warrior should read as brown")
    r, g_, b = C:Color("DRUID")
    H.assertTrue(r > 0.9 and b < 0.1, "druid should be orange")
end)

H.it(g, "Color prefers the client's RAID_CLASS_COLORS when available", function()
    local saved = _G.RAID_CLASS_COLORS
    _G.RAID_CLASS_COLORS = { MAGE = { r = 0.1, g = 0.2, b = 0.3 } }
    local r, g_, b = C:Color("MAGE")
    H.assertEq(r, 0.1) H.assertEq(g_, 0.2) H.assertEq(b, 0.3)
    _G.RAID_CLASS_COLORS = saved
end)

H.it(g, "Color returns a white fallback for nil/unknown", function()
    local r, g_, b = C:Color(nil)
    H.assertEq(r, 1) H.assertEq(g_, 1) H.assertEq(b, 1)
    r, g_, b = C:Color("NOTACLASS")
    H.assertEq(r, 1) H.assertEq(g_, 1) H.assertEq(b, 1)
end)

H.it(g, "ColorHex produces a 6-byte hex escape (e.g. ff112233)", function()
    local hex = C:ColorHex("PRIEST")
    H.assertEq(#hex, 8)
    H.assertEq(hex:sub(1, 2), "ff")
    -- Priest white -> ffffffff
    H.assertEq(hex, "ffffffff")
end)

H.it(g, "DisplayName uses LOCALIZED_CLASS_NAMES_MALE when present", function()
    local saved = _G.LOCALIZED_CLASS_NAMES_MALE
    _G.LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Magicien" }
    H.assertEq(C:DisplayName("MAGE"), "Magicien")
    _G.LOCALIZED_CLASS_NAMES_MALE = saved
end)

H.it(g, "DisplayName title-cases the class token as a last-ditch fallback", function()
    local saved = _G.LOCALIZED_CLASS_NAMES_MALE
    _G.LOCALIZED_CLASS_NAMES_MALE = nil
    H.assertEq(C:DisplayName("MAGE"), "Mage")
    H.assertEq(C:DisplayName("WARLOCK"), "Warlock")
    H.assertEq(C:DisplayName(nil), "")
    _G.LOCALIZED_CLASS_NAMES_MALE = saved
end)
