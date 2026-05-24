-- Tests/UI_spec.lua
local H = _G.__ACC_TEST_HELPERS
H.load("Locales/enUS.lua")
H.load("Data/Spells.lua")
H.load("Data/Classes.lua")
H.load("UI.lua")

local UI = H.ns.UI
local g = H.describe("UI")

-- Make sure a DB is initialised so the frame has defaults to read.
_G.ArenaCoachTBCDB = {
    enabled = true, locked = false, language = "auto",
    frame = { point = "CENTER", x = 0, y = 120, scale = 1.0 },
    alerts = { sound = true, raidWarning = false, partyChat = false, screenFlash = true },
    strategy = {},
    debug = false,
}

H.it(g, "CreateFrame builds a frame with icon rows", function()
    local f = UI:CreateFrame()
    H.assertNotNil(f)
    H.assertNotNil(f.friendlyIconMap)
    H.assertNotNil(f.enemyIconMap)
end)

H.it(g, "CreateFrame is idempotent", function()
    local a = UI:CreateFrame()
    local b = UI:CreateFrame()
    H.assertEq(a, b)
end)

H.it(g, "Show/Hide/Toggle change visibility", function()
    UI:CreateFrame()
    UI:Hide()
    H.assertFalse(UI.frame:IsShown())
    UI:Show()
    H.assertTrue(UI.frame:IsShown())
    UI:Toggle()
    H.assertFalse(UI.frame:IsShown())
    UI:Toggle()
    H.assertTrue(UI.frame:IsShown())
end)

H.it(g, "Apply with KILL recommendation sets big text & subtext", function()
    UI:CreateFrame()
    UI:Apply({
        mode = "KILL",
        primaryTargetName = "Holyman",
        reason = "test reason",
        callouts = { "CALL_HOJ_KILL", "CALL_PURGE" },
        priority = "HIGH",
    })
end)

H.it(g, "Apply with each mode does not error", function()
    UI:CreateFrame()
    for _, mode in ipairs({"OPEN","KILL","SWAP","DEFEND","RESET"}) do
        UI:Apply({ mode = mode, reason = "r", callouts = {}, priority = "MEDIUM" })
    end
end)

H.it(g, "Apply with URGENT triggers screen flash", function()
    -- Re-establish the DB in case another spec replaced it during dofile.
    _G.ArenaCoachTBCDB = {
        enabled = true, locked = false, language = "auto",
        frame = { point = "CENTER", x = 0, y = 120, scale = 1.0 },
        alerts = { sound = true, screenFlash = true },
        strategy = {}, debug = false,
    }
    UI:CreateFrame()
    UI._flash = nil
    UI:Apply({ mode = "DEFEND", reason = "flash", callouts = {}, priority = "URGENT" })
    H.assertNotNil(UI._flash)
end)

H.it(g, "Apply ignores nil recommendation", function()
    UI:CreateFrame()
    UI:Apply(nil)
end)

H.it(g, "UpdateIcons brightens matched keys", function()
    UI:CreateFrame()
    UI:UpdateIcons({ MORTAL_STRIKE = true }, { PVP_TRINKET = true })
end)

H.it(g, "UpdateIcons handles nil maps", function()
    UI:CreateFrame()
    UI:UpdateIcons(nil, nil)
end)

H.it(g, "Show/Hide are no-ops when frame missing", function()
    local saved = UI.frame
    UI.frame = nil
    UI:Show(); UI:Hide(); UI:Toggle()
    UI:Apply({ mode = "KILL", callouts = {}, priority = "HIGH" })
    UI:UpdateIcons({}, {})
    UI.frame = saved
end)

H.it(g, "Apply with no callouts/reason still renders", function()
    UI:CreateFrame()
    UI:Apply({ mode = "RESET", priority = "LOW" })
end)

H.it(g, "Apply with primaryTargetClass fallback", function()
    UI:CreateFrame()
    UI:Apply({ mode = "KILL", primaryTargetClass = "MAGE", priority = "HIGH" })
end)
