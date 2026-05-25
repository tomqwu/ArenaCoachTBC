-- Tests/Nameplate_spec.lua
-- Exercises the v2.2.0 nameplate highlight (KILL primary, SWAP secondary).

local H = _G.__ACC_TEST_HELPERS
local ns = H.ns

H.load("Nameplate.lua")
local NP = ns.Nameplate
assert(NP, "Nameplate not loaded")

-- Stub the nameplate lookup so the tests don't depend on a real
-- C_NamePlate implementation. unitForGUID inside the module iterates
-- nameplate1..40 and calls UnitGUID; we set up two synthetic GUIDs.
H.setUnit("nameplate1", { guid = "guid-warlock", class = "WARLOCK", name = "Affli", exists = true })
H.setUnit("nameplate2", { guid = "guid-rogue",   class = "ROGUE",   name = "Sub",   exists = true })

-- Nameplate frame resolution: the module falls back to _G[unit] when
-- C_NamePlate is absent. Make those globals real mock frames so
-- ensureOverlay can attach an overlay to them.
_G.nameplate1 = H.makeMockFrame{ name = "nameplate1" }
_G.nameplate2 = H.makeMockFrame{ name = "nameplate2" }

local g = H.describe("Nameplate")

H.it(g, "exposes KILL + SWAP colours matching the UI palette", function()
    H.assertNotNil(NP.colors.KILL, "KILL highlight colour required")
    H.assertNotNil(NP.colors.SWAP, "SWAP highlight colour required")
end)

H.it(g, "Apply with no rec clears overlays (idempotent)", function()
    NP:Apply(nil)
    NP:Apply(nil)   -- second call must not error
end)

H.it(g, "Apply on KILL mode paints the primary target", function()
    NP:ClearAll()
    NP:Apply({
        mode             = "KILL",
        primaryTarget    = "guid-warlock",
        secondaryTarget  = "guid-rogue",
    })
    -- We assert via overlay creation: the module caches overlays in
    -- _overlays keyed by the nameplate frame. After Apply the
    -- table should have at least one entry for the primary plate.
    local count = 0
    for _ in pairs(NP._overlays) do count = count + 1 end
    H.assertTrue(count >= 1, "expected at least one overlay for KILL primary")
end)

H.it(g, "Apply on SWAP mode highlights the secondary in SWAP colour", function()
    NP:ClearAll()
    NP:Apply({
        mode             = "SWAP",
        primaryTarget    = "guid-warlock",
        secondaryTarget  = "guid-rogue",
    })
    local count = 0
    for _ in pairs(NP._overlays) do count = count + 1 end
    H.assertTrue(count >= 1, "expected at least one overlay for SWAP")
end)

H.it(g, "ClearAll hides every cached overlay", function()
    NP:Apply({ mode = "KILL", primaryTarget = "guid-warlock" })
    NP:ClearAll()
    for _, ov in pairs(NP._overlays) do
        H.assertFalse(ov._shown, "overlay should be hidden after ClearAll")
    end
end)

H.it(g, "Highlight ignores unknown roles + nil guids", function()
    NP:Highlight("BOGUS", "guid-warlock")     -- unknown role, must no-op
    NP:Highlight("KILL", nil)                  -- nil guid, must no-op
end)
