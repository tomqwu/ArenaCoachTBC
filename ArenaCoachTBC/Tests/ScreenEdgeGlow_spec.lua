-- Tests/ScreenEdgeGlow_spec.lua
-- Exercises the optional mode-coloured screen-edge cue.

local H = _G.__ACC_TEST_HELPERS
local ns = H.ns

H.load("ScreenEdgeGlow.lua")
local Glow = ns.ScreenEdgeGlow
assert(Glow, "ScreenEdgeGlow not loaded")

local g = H.describe("ScreenEdgeGlow")

H.it(g, "exposes a colour table covering the active engine modes", function()
    H.assertNotNil(Glow.colors.KILL,   "KILL must have a colour")
    H.assertNotNil(Glow.colors.SWAP,   "SWAP must have a colour")
    H.assertNotNil(Glow.colors.DEFEND, "DEFEND must have a colour")
    H.assertNotNil(Glow.colors.OPEN,   "OPEN must have a colour")
end)

H.it(g, "RESET intentionally has no colour", function()
    H.assertNil(Glow.colors.RESET, "RESET must be silent (no peripheral cue between fights)")
end)

H.it(g, "ColorFor returns nil for unknown modes", function()
    H.assertNil(Glow:ColorFor("BOGUS"))
end)

H.it(g, "visual profile stays thin and non-pulsing", function()
    local profile = Glow:VisualProfile()
    H.assertTrue(profile.edgeThickness <= 24, "edge cue must stay thin")
    H.assertTrue(profile.alpha <= 0.16, "edge cue alpha must stay subtle")
    H.assertFalse(profile.pulse, "edge cue must not pulse or flash")
end)

H.it(g, "SetMode records the current mode for known colours", function()
    Glow:Hide()
    Glow:SetMode("KILL")
    H.assertEq(Glow:CurrentMode(), "KILL")
end)

H.it(g, "SetMode with a colourless mode hides the glow", function()
    Glow:SetMode("KILL")
    Glow:SetMode("RESET")
    H.assertNil(Glow:CurrentMode())
end)

H.it(g, "Hide clears the current mode", function()
    Glow:SetMode("DEFEND")
    Glow:Hide()
    H.assertNil(Glow:CurrentMode())
end)
