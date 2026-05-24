-- Tests/DRTracker_spec.lua
local H = _G.__ACC_TEST_HELPERS
H.load("DRTracker.lua")
local DR = H.ns.DRTracker

local g = H.describe("DRTracker")

H.it(g, "NextMultiplier defaults to 1.0 on fresh state", function()
    DR:Clear()
    H.assertEq(DR:NextMultiplier("g1", "STUN"), 1.0)
end)

H.it(g, "Apply -> NextMultiplier returns 0.5 after one application", function()
    DR:Clear()
    H._gameTime = 1000
    DR:Apply("g1", "STUN", 1000)
    H.assertEq(DR:NextMultiplier("g1", "STUN"), 0.5)
end)

H.it(g, "Two applications -> 0.25", function()
    DR:Clear()
    H._gameTime = 1000
    DR:Apply("g1", "FEAR", 1000)
    DR:Apply("g1", "FEAR", 1001)
    H.assertEq(DR:NextMultiplier("g1", "FEAR"), 0.25)
end)

H.it(g, "Three applications -> immune (0.0)", function()
    DR:Clear()
    DR:Apply("g1", "CYCLONE", 0)
    DR:Apply("g1", "CYCLONE", 1)
    DR:Apply("g1", "CYCLONE", 2)
    H._gameTime = 5
    H.assertEq(DR:NextMultiplier("g1", "CYCLONE"), 0.0)
    H.assertTrue(DR:IsImmune("g1", "CYCLONE"))
end)

H.it(g, "Reset window restores fresh mult", function()
    DR:Clear()
    DR.resetWindow = 17.0
    DR:Apply("g1", "ROOT", 0)
    H._gameTime = 100  -- well past resetWindow
    H.assertEq(DR:NextMultiplier("g1", "ROOT"), 1.0)
end)

H.it(g, "Apply with nil args is a no-op", function()
    DR:Clear()
    DR:Apply(nil, "STUN")
    DR:Apply("g1", nil)
    H.assertNil(next(DR._state))
end)

H.it(g, "OnCC ignores non-applied subevents", function()
    DR:Clear()
    DR:OnCC("SPELL_CAST_SUCCESS", "g1", 10308, "STUN", 0)
    H.assertEq(DR:NextMultiplier("g1", "STUN"), 1.0)
end)

H.it(g, "OnCC ignores nil category", function()
    DR:Clear()
    DR:OnCC("SPELL_AURA_APPLIED", "g1", 999, nil, 0)
    H.assertEq(DR:NextMultiplier("g1", "STUN"), 1.0)
end)

H.it(g, "OnCC applies for SPELL_AURA_APPLIED with category", function()
    DR:Clear()
    H._gameTime = 1000
    DR:OnCC("SPELL_AURA_APPLIED", "g1", 10308, "STUN", H._gameTime)
    H.assertEq(DR:NextMultiplier("g1", "STUN"), 0.5)
end)

H.it(g, "Forget drops a single guid", function()
    DR:Clear()
    DR:Apply("g1", "STUN", 0)
    DR:Forget("g1")
    H.assertEq(DR:NextMultiplier("g1", "STUN"), 1.0)
end)

H.it(g, "IsImmune false on fresh state", function()
    DR:Clear()
    H.assertFalse(DR:IsImmune("g1", "STUN"))
end)
