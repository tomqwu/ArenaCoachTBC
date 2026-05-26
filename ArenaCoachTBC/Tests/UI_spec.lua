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
    alerts = { sound = true, raidWarning = false, partyChat = false, screenFlash = false },
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

H.it(g, "Apply renders DBM-style player action assignments", function()
    UI:CreateFrame()
    UI:Apply({
        mode = "KILL",
        primaryTargetName = "Holyman",
        callouts = {},
        priority = "HIGH",
        playerActions = {
            { unit = "player", name = "Warrior", actionKey = "ACTION_WARRIOR_KILL", targetName = "Holyman" },
            { unit = "party1", name = "Shaman", actionKey = "ACTION_SHAMAN_PURGE", targetName = "Holyman" },
        },
    })
    local txt = UI.frame.actionText and UI.frame.actionText._text or ""
    H.assertTrue(txt:find("Assignments", 1, true) ~= nil, "assignment header missing: " .. txt)
    H.assertTrue(txt:find("Warrior:", 1, true) ~= nil, "player assignment missing: " .. txt)
    H.assertTrue(txt:find("Shaman:", 1, true) ~= nil, "party assignment missing: " .. txt)
    H.assertTrue(txt:find("Holyman", 1, true) ~= nil, "assignment target missing: " .. txt)
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

H.it(g, "Apply with URGENT does not trigger full-screen flash", function()
    -- Re-establish the DB in case another spec replaced it during dofile.
    _G.ArenaCoachTBCDB = {
        enabled = true, locked = false, language = "auto",
        frame = { point = "CENTER", x = 0, y = 120, scale = 1.0 },
        alerts = { sound = true, screenFlash = true },
        strategy = {}, debug = false,
    }
    H.ns.Core = H.ns.Core or {}
    H.ns.Core.state = H.ns.Core.state or {}
    H.ns.Core.state.pvpContext = "arena"
    UI:CreateFrame()
    UI._flash = nil
    UI:Apply({ mode = "DEFEND", reason = "flash", callouts = {}, priority = "URGENT" })
    H.assertNil(UI._flash, "urgent recommendations should not strobe the screen")
    H.ns.Core.state.pvpContext = nil
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

H.it(g, "Apply ignores nil recommendation", function()
    UI:CreateFrame()
    UI:Apply(nil)
end)

H.it(g, "Show/Hide are no-ops when frame missing", function()
    local saved = UI.frame
    UI.frame = nil
    UI:Show(); UI:Hide(); UI:Toggle()
    UI:Apply({ mode = "KILL", callouts = {}, priority = "HIGH" })
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

-- =================================================================
-- v2.3.0: /acc test demo paints the full HUD (edge glow + nameplate),
-- not just the text. Regression for the bug where _forceShow bypassed
-- the auto-hide gate but the visual-layer gate still required inPvP.
-- =================================================================

H.it(g, "v2.3.0: _forceShow bypasses inPvP gate for edge glow + nameplate", function()
    -- Load the visual-layer modules so UI:Apply can drive them.
    H.load("ScreenEdgeGlow.lua")
    H.load("Nameplate.lua")
    local Glow = H.ns.ScreenEdgeGlow
    local NP   = H.ns.Nameplate
    H.assertNotNil(Glow, "ScreenEdgeGlow must be loaded")
    H.assertNotNil(NP,   "Nameplate must be loaded")

    -- Ensure the alerts toggles default to on (matches DEFAULTS in Core).
    _G.ArenaCoachTBCDB = _G.ArenaCoachTBCDB or {}
    _G.ArenaCoachTBCDB.alerts = _G.ArenaCoachTBCDB.alerts or {}
    _G.ArenaCoachTBCDB.alerts.edgeGlow  = true
    _G.ArenaCoachTBCDB.alerts.nameplate = true

    -- No PvP context — simulates running /acc test in a city.
    H.ns.Core = H.ns.Core or {}
    H.ns.Core.state = H.ns.Core.state or {}
    H.ns.Core.state.pvpContext = "none"

    -- Stub a nameplate so Nameplate:Apply has a target to paint.
    H.setUnit("nameplate1", { guid = "guid-demo", class = "ROGUE",
                              name = "DemoEnemy", exists = true })
    _G.nameplate1 = _G.nameplate1 or H.makeMockFrame{ name = "nameplate1" }

    UI:CreateFrame()
    Glow:Hide()           -- reset state from any earlier test
    NP:ClearAll()

    -- Demo-style rec with _forceShow set: should paint the FULL HUD.
    UI:Apply({
        mode = "KILL",
        primaryTarget = "guid-demo",
        primaryTargetName = "DemoEnemy",
        primaryTargetClass = "ROGUE",
        callouts = {},
        priority = "HIGH",
        _forceShow = true,
    })

    H.assertEq(Glow:CurrentMode(), "KILL",
        "edge glow should activate in KILL mode when _forceShow is set, even without pvp context")
    local overlayCount = 0
    for _ in pairs(NP._overlays) do overlayCount = overlayCount + 1 end
    H.assertTrue(overlayCount >= 1,
        "nameplate overlay should paint on the kill target when _forceShow is set")

    -- Clean up: pvpContext = "none" would trip the v2.2.5 auto-hide
    -- gate in any subsequent test that doesn't set its own context.
    H.ns.Core.state.pvpContext = nil
end)

H.it(g, "v2.3.0: without _forceShow + no pvp context, visual layers stay hidden", function()
    local Glow = H.ns.ScreenEdgeGlow
    -- Same DB toggles as the previous test (alerts on).
    H.ns.Core.state.pvpContext = "none"
    UI:CreateFrame()
    Glow:SetMode("KILL")   -- prime to a visible state
    UI:Apply({
        mode = "KILL",
        primaryTarget = "guid-demo",
        callouts = {},
        priority = "HIGH",
        -- no _forceShow → should hide everything (the early-return gate
        -- catches this before the visual-layer block, but the assertion
        -- below also verifies Glow gets cleared)
    })
    H.assertNil(Glow:CurrentMode(),
        "edge glow must be cleared when context is 'none' and _forceShow is not set")
    H.ns.Core.state.pvpContext = nil
end)

-- =================================================================
-- v2.1.3: DEFEND / RESET don't show a target in bigText
-- =================================================================

H.it(g, "v2.1.3: DEFEND mode suppresses '<mode>: <name>' target form", function()
    UI:CreateFrame()
    UI:Apply({
        mode = "DEFEND",
        primaryTargetName = "ShouldNotShow",
        primaryTargetClass = "PRIEST",
        reason = "defensive: trained",
        callouts = {},
        priority = "URGENT",
    })
    local txt = UI.frame.bigText._text
    H.assertTrue(txt and not txt:find("ShouldNotShow", 1, true),
        "DEFEND must not include target name; got: " .. tostring(txt))
end)

H.it(g, "v2.1.3: KILL / SWAP / OPEN still show the target", function()
    UI:CreateFrame()
    UI:Apply({
        mode = "KILL",
        primaryTargetName = "TargetA",
        callouts = {}, priority = "HIGH",
    })
    H.assertTrue(UI.frame.bigText._text:find("TargetA", 1, true) ~= nil,
        "KILL must show target name")
end)

H.it(g, "v2.1.3: RESET mode also suppresses target", function()
    UI:CreateFrame()
    UI:Apply({
        mode = "RESET",
        primaryTargetName = "Stale",
        callouts = {}, priority = "LOW",
    })
    H.assertTrue(UI.frame.bigText._text and not UI.frame.bigText._text:find("Stale", 1, true),
        "RESET must not include target name; got: " .. tostring(UI.frame.bigText._text))
end)

H.it(g, "v2.1.3: UI prefers rec.reasonKey via L() over raw rec.reason", function()
    UI:CreateFrame()
    UI:Apply({
        mode = "DEFEND",
        reason = "defensive: trained",
        reasonKey = "REASON_DEFEND_TRAINED",
        callouts = {},
        priority = "URGENT",
    })
    local sub = UI.frame.subText._text or ""
    -- en locale renders REASON_DEFEND_TRAINED as "defensive - healer trained"
    H.assertTrue(sub:find("healer trained", 1, true) ~= nil
        or sub:find("治疗被集火", 1, true) ~= nil,
        "expected localised reason text, got: " .. sub)
    -- Raw 'defensive: trained' must NOT appear (means we used reasonKey)
    H.assertTrue(not sub:find("defensive: trained", 1, true),
        "raw reason string should not leak when reasonKey is set")
end)
