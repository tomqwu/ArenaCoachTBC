-- Tests/CooldownTracker_spec.lua
local H = _G.__ACC_TEST_HELPERS
H.load("CooldownTracker.lua")
local CT = H.ns.CooldownTracker

local g = H.describe("CooldownTracker")

H.it(g, "IsReady returns true when never observed", function()
    CT:Clear()
    H.assertTrue(CT:IsReady("guid-a", 27619))
    H.assertNil(CT:GetRemaining("guid-a", 27619))
end)

H.it(g, "MarkUsed sets a remaining timer", function()
    CT:Clear()
    H._gameTime = 1000
    CT:MarkUsed("guid-a", 27619)  -- Ice Block, 300s
    H.assertFalse(CT:IsReady("guid-a", 27619))
    local r = CT:GetRemaining("guid-a", 27619)
    H.assertEq(r, 300)
end)

H.it(g, "GetRemaining returns 0 after duration elapsed", function()
    CT:Clear()
    H._gameTime = 0
    CT:MarkUsed("guid-a", 27619)
    H._gameTime = 999
    H.assertEq(CT:GetRemaining("guid-a", 27619), 0)
    H.assertTrue(CT:IsReady("guid-a", 27619))
end)

H.it(g, "GetRemaining returns nil for unknown duration spell", function()
    CT:Clear()
    H._gameTime = 0
    CT:MarkUsed("guid-a", 999999)  -- not in defaults
    H.assertNil(CT:GetRemaining("guid-a", 999999))
end)

H.it(g, "ForUnit returns observed records", function()
    CT:Clear()
    H._gameTime = 0
    CT:MarkUsed("guid-x", 27619)
    local recs = CT:ForUnit("guid-x")
    H.assertNotNil(recs[27619])
end)

H.it(g, "ForUnit returns empty table for unknown guid", function()
    CT:Clear()
    local recs = CT:ForUnit("guid-unknown")
    H.assertNil(next(recs))
end)

H.it(g, "Forget drops a single guid", function()
    CT:Clear()
    CT:MarkUsed("guid-a", 27619)
    CT:Forget("guid-a")
    H.assertNil(next(CT:ForUnit("guid-a")))
end)

H.it(g, "OnCombatLogEvent records on SPELL_CAST_SUCCESS for known spell", function()
    CT:Clear()
    H._gameTime = 100
    CT:OnCombatLogEvent("SPELL_CAST_SUCCESS", "guid-c", "guid-dest", 27619)
    H.assertFalse(CT:IsReady("guid-c", 27619))
end)

H.it(g, "OnCombatLogEvent ignores SPELL_CAST_SUCCESS for unknown spell", function()
    CT:Clear()
    CT:OnCombatLogEvent("SPELL_CAST_SUCCESS", "guid-c", "guid-dest", 999999)
    H.assertNil(next(CT:ForUnit("guid-c")))
end)

H.it(g, "OnCombatLogEvent records PvP trinket on aura applied", function()
    CT:Clear()
    H._gameTime = 200
    CT:OnCombatLogEvent("SPELL_AURA_APPLIED", "src", "guid-trinket", 42292)
    H.assertFalse(CT:IsReady("guid-trinket", 42292))
end)

H.it(g, "OnCombatLogEvent records Ice Block / Divine Shield from aura", function()
    CT:Clear()
    H._gameTime = 300
    CT:OnCombatLogEvent("SPELL_AURA_APPLIED", "src", "guid-mage", 27619)
    CT:OnCombatLogEvent("SPELL_AURA_APPLIED", "src", "guid-pala", 642)
    H.assertNotNil(CT:GetRemaining("guid-mage", 27619))
    H.assertNotNil(CT:GetRemaining("guid-pala", 642))
end)

H.it(g, "OnCombatLogEvent ignores nil subEvent / spell", function()
    CT:Clear()
    CT:OnCombatLogEvent(nil, "a", "b", 27619)
    CT:OnCombatLogEvent("SPELL_CAST_SUCCESS", "a", "b", nil)
    H.assertNil(next(CT:ForUnit("a")))
end)

H.it(g, "_record ignores nil guid or spellID", function()
    CT:Clear()
    CT:_record(nil, 27619)
    CT:_record("a", nil)
    H.assertNil(next(CT:ForUnit("a")))
end)

H.it(g, "tracks Will of the Forsaken from SPELL_CAST_SUCCESS for 120s", function()
    CT:Clear()
    H._gameTime = 1000
    CT:OnCombatLogEvent("SPELL_CAST_SUCCESS", "guid-undead", "guid-undead", 7744)
    H.assertEq(CT:GetRemaining("guid-undead", 7744), 120)
    H.assertFalse(CT:IsReady("guid-undead", 7744))
end)

H.it(g, "tracks Will of the Forsaken from SPELL_AURA_APPLIED too", function()
    CT:Clear()
    H._gameTime = 2000
    CT:OnCombatLogEvent("SPELL_AURA_APPLIED", "src", "guid-undead", 7744)
    H.assertEq(CT:GetRemaining("guid-undead", 7744), 120)
end)

H.it(g, "WotF and PvP trinket are tracked as separate cooldowns", function()
    CT:Clear()
    H._gameTime = 3000
    CT:OnCombatLogEvent("SPELL_AURA_APPLIED", "src", "guid-u", 42292)
    -- Trinket on CD, but WotF still ready
    H.assertFalse(CT:IsReady("guid-u", 42292))
    H.assertTrue(CT:IsReady("guid-u", 7744))
end)
