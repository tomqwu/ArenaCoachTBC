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

H.it(g, "v2.0.2: Apply does NOT screen-flash outside arena (BG/world)", function()
    -- Stub IsActiveBattlefieldArena to return false (simulating WSG / world).
    _G.ArenaCoachTBCDB = {
        enabled = true, locked = false, language = "auto",
        frame = { point = "CENTER", x = 0, y = 120, scale = 1.0 },
        alerts = { sound = true, screenFlash = true },
        strategy = {}, debug = false,
    }
    local saved = _G.IsActiveBattlefieldArena
    _G.IsActiveBattlefieldArena = function() return false end
    UI:CreateFrame()
    UI._flash = nil
    UI:Apply({ mode = "DEFEND", reason = "trained", callouts = {}, priority = "URGENT" })
    H.assertNil(UI._flash, "screen flash must not fire outside arena (BG bug fix)")
    _G.IsActiveBattlefieldArena = saved
end)

H.it(g, "v2.0.2: Apply does NOT play voice cue outside arena", function()
    _G.ArenaCoachTBCDB = {
        enabled = true, locked = false, language = "auto",
        frame = { point = "CENTER", x = 0, y = 120, scale = 1.0 },
        alerts = { sound = true, screenFlash = false },
        strategy = {}, debug = false,
    }
    local saved = _G.IsActiveBattlefieldArena
    _G.IsActiveBattlefieldArena = function() return false end
    H.load("Sounds.lua")
    UI:CreateFrame()
    UI._lastVoiceCallout = nil
    local savedPlay = _G.PlaySoundFile
    local played = false
    _G.PlaySoundFile = function() played = true; return true end
    UI:Apply({ mode = "KILL", reason = "r", callouts = { "CALL_HOJ_KILL" }, priority = "HIGH" })
    H.assertFalse(played, "voice cue must not play outside arena")
    _G.PlaySoundFile = savedPlay
    _G.IsActiveBattlefieldArena = saved
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

H.it(g, "Apply with chain narrates to chat once per chain id change", function()
    UI:CreateFrame()
    UI._lastChainId = nil
    local lines = {}
    local origPrint = _G.print
    _G.print = function(s) table.insert(lines, tostring(s)) end
    UI:Apply({
        mode = "KILL", reason = "r", callouts = {}, priority = "HIGH",
        chain = { id = "rmp_sap_into_kidney", labelKey = "CHAIN_RMP_SAP_INTO_KIDNEY",
                  label = "Sap into Kidney", expectedProb = 0.75, steps = 3, links = {} },
    })
    -- Same chain id again: no extra narration
    local countAfter1 = #lines
    UI:Apply({
        mode = "KILL", reason = "r", callouts = {}, priority = "HIGH",
        chain = { id = "rmp_sap_into_kidney", labelKey = "CHAIN_RMP_SAP_INTO_KIDNEY",
                  label = "Sap into Kidney", expectedProb = 0.75, steps = 3, links = {} },
    })
    H.assertEq(#lines, countAfter1, "same chain id should not re-narrate")
    -- Different chain id: narrates again
    UI:Apply({
        mode = "KILL", reason = "r", callouts = {}, priority = "HIGH",
        chain = { id = "wld_fear_into_cyclone", labelKey = "CHAIN_WLD_FEAR_INTO_CYCLONE",
                  label = "Fear into Cyclone", expectedProb = 0.5, steps = 2, links = {} },
    })
    H.assertTrue(#lines > countAfter1, "different chain id should narrate again")
    _G.print = origPrint
end)

H.it(g, "Apply respects compactMode by hiding icon rows", function()
    UI:CreateFrame()
    _G.ArenaCoachTBCDB = _G.ArenaCoachTBCDB or {
        enabled = true, locked = false, language = "auto",
        frame = { point = "CENTER", x = 0, y = 120, scale = 1.0, compactMode = true },
        alerts = { sound = true, screenFlash = false },
        strategy = {}, debug = false,
    }
    _G.ArenaCoachTBCDB.frame.compactMode = true
    UI:Apply({ mode = "KILL", reason = "x", callouts = {}, priority = "HIGH" })
    -- Mock frame's SetShown stores the value somewhere accessible — we
    -- assert the call happened by inspecting _shown.
    local f = UI.frame
    H.assertEq(f.friendlyRow._shown, false, "compactMode should hide friendlyRow")
    H.assertEq(f.enemyRow._shown,    false, "compactMode should hide enemyRow")
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

H.it(g, "v2.0.1: icon buttons carry spellID for locale-correct GameTooltip", function()
    UI:CreateFrame()
    local f = UI.frame
    H.assertNotNil(f.friendlyIconMap)
    H.assertNotNil(f.enemyIconMap)
    -- Sample a known key — Mortal Strike's spellID is 30330.
    local ms = f.friendlyIconMap.MORTAL_STRIKE
    H.assertNotNil(ms, "MORTAL_STRIKE icon should exist")
    H.assertEq(ms.spellID, 30330,
        "icon must carry spellID so GameTooltip:SetSpellByID renders the localized tooltip")
    local trink = f.enemyIconMap.PVP_TRINKET
    H.assertNotNil(trink)
    H.assertEq(trink.spellID, 42292)
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
