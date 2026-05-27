-- Tests/UI_spec.lua
local H = _G.__ACC_TEST_HELPERS
H.load("Locales/enUS.lua")
H.load("Data/Spells.lua")
H.load("Data/Classes.lua")
H.load("Core.lua")
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


H.it(g, "CreateFrame builds prototype-A module set", function()
    UI.frame = nil
    UI.assignFrame = nil
    UI.unitFrame = nil
    UI.railFrame = nil
    local f = UI:CreateFrame()
    H.assertNotNil(f)
    H.assertNotNil(UI.unitFrame)
    H.assertNotNil(UI.railFrame)
    H.assertNotNil(UI.assignFrame)
    H.assertNotNil(f.arcadeText)
    H.assertNotNil(f.versionText)
    H.assertNotNil(f.dragBar)
    H.assertNotNil(f.dragGrip)
    H.assertNotNil(f.resizeGrip)
    H.assertNotNil(f.leftPanel)
    H.assertNotNil(f.centerPanel)
    H.assertNotNil(f.rightPanel)
    H.assertNotNil(f.assignPanel)
    H.assertNotNil(f.leftDivider)
    H.assertNotNil(f.rightDivider)
    H.assertNotNil(f.assignDivider)
    H.assertNotNil(f.unitText)
    H.assertNotNil(f.railText)
    H.assertNotNil(f.assignText)
    H.assertNotNil(UI.unitFrame.text)
    H.assertNotNil(UI.railFrame.text)
    H.assertNotNil(UI.assignFrame.actionText)
    H.assertTrue((f._width or 999) <= 480, "main board width should stay compact")
    H.assertTrue((f._height or 999) <= 180, "main board height should stay compact")
    H.assertTrue((UI.unitFrame._width or 999) <= 190, "left focus strip should stay compact")
    H.assertTrue((UI.railFrame._width or 999) <= 190, "right cue rail should stay compact")
    H.assertTrue((UI.assignFrame._height or 999) <= 90, "assignment module should stay compact")
    H.assertTrue((f.arcadeText._fontSize or 999) <= 20, "arcade cue should not be raid-warning sized")
    H.assertTrue((f.bigText._fontSize or 999) <= 24, "main action text should fit a compact toast")
    H.assertEq(f.leftPanel._width, 126)
    H.assertEq(f.centerPanel._width, 192)
    H.assertEq(f.rightPanel._width, 126)
    H.assertEq(f.assignPanel._width, 444)
    H.assertEq(f.leftPanel._height, 82)
    H.assertEq(f.centerPanel._height, 82)
    H.assertEq(f.rightPanel._height, 82)
    H.assertEq(f.assignPanel._height, 52)
    H.assertTrue(f._resizable, "main board should expose WoW resizing")
    H.assertEq(f._minResize[1], 360)
    H.assertEq(f._minResize[2], 132)
    H.assertEq(f._maxResize[1], 720)
    H.assertEq(f._maxResize[2], 280)
    H.assertTrue((f._accBg._color and f._accBg._color[4] or 1) <= 0.35,
        "main board background should stay light enough to see the fight")
    H.assertTrue((f.dragBar._color and f.dragBar._color[4] or 1) <= 0.45,
        "drag strip should identify the handle without darkening the screen")
    H.assertTrue((f.bigText._shadowColor and f.bigText._shadowColor[4] or 0) >= 0.95,
        "main text should carry readability through shadow/outline instead of a dark board")
    H.assertTrue((f.unitText._shadowColor and f.unitText._shadowColor[4] or 0) >= 0.90,
        "module text should remain readable on the lighter board")
    H.assertEq(f.dragGrip._text, "|||")
    H.assertFalse(UI.unitFrame:IsShown(), "detached left focus strip should start dormant")
    H.assertFalse(UI.railFrame:IsShown(), "detached right cue rail should start dormant")
    H.assertFalse(UI.assignFrame:IsShown(), "detached assignment module should start dormant")
    H.assertTrue((f.unitText._text or ""):find("Target", 1, true) ~= nil,
        "waiting focus strip should show structural labels")
    H.assertTrue((f.railText._text or ""):find("Burst", 1, true) ~= nil,
        "waiting cue rail should show structural labels")
    H.assertTrue((f.assignText._text or ""):find("Assignments", 1, true) ~= nil,
        "waiting assignment panel should show structural labels")
end)

H.it(g, "CreateFrame restores and saves resized prototype-A board dimensions", function()
    _G.ArenaCoachTBCDB = {
        enabled = true, locked = false, language = "auto",
        frame = { point = "CENTER", x = 0, y = 120, scale = 1.0, width = 520, height = 210 },
        alerts = { sound = false, screenFlash = false, edgeGlow = false, nameplate = false },
        strategy = {}, debug = false,
    }
    UI.frame = nil
    UI.assignFrame = nil
    UI.unitFrame = nil
    UI.railFrame = nil
    local f = UI:CreateFrame()
    H.assertEq(f._width, 520)
    H.assertEq(f._height, 210)
    H.assertTrue(f.centerPanel._width > 192, "center action panel should grow with a wider board")
    H.assertTrue(f.assignPanel._width > 444, "assignment panel should grow with a wider board")
    H.assertTrue(f.leftPanel._height > 82, "top-row modules should gain height on a taller board")
    H.assertEq(f.resizeGrip._point[1], "BOTTOMRIGHT")

    f.resizeGrip._scripts.OnMouseDown(f.resizeGrip, "LeftButton")
    H.assertEq(f._sizing, "BOTTOMRIGHT")
    f:SetSize(560, 220)
    f.resizeGrip._scripts.OnMouseUp(f.resizeGrip)
    H.assertFalse(f._sizing, "resize should stop when the grip is released")
    H.assertEq(_G.ArenaCoachTBCDB.frame.width, 560)
    H.assertEq(_G.ArenaCoachTBCDB.frame.height, 220)
    H.assertTrue(f.centerPanel._width > 210, "layout should recompute after resize")
end)

H.it(g, "master off keeps the HUD hidden even when a frame or forced beat exists", function()
    _G.ArenaCoachTBCDB = {
        enabled = false, locked = false, language = "auto",
        frame = { point = "CENTER", x = 0, y = 120, scale = 1.0 },
        alerts = { sound = false, screenFlash = false, edgeGlow = false, nameplate = false },
        strategy = {}, debug = false,
    }
    UI.frame = nil
    UI.assignFrame = nil
    UI.unitFrame = nil
    UI.railFrame = nil
    local f = UI:CreateFrame()
    H.assertFalse(f:IsShown(), "disabled addon should not leave a freshly-created HUD visible")

    UI:Show()
    H.assertFalse(f:IsShown(), "UI:Show should respect the master off switch")

    f:Show()
    UI:Apply({ mode = "KILL", primaryTargetName = "Holyman", _forceShow = true })
    H.assertFalse(f:IsShown(), "forced test/simulator beats should not override /acc off")

    UI:Toggle()
    H.assertFalse(f:IsShown(), "UI:Toggle should not reopen the HUD while disabled")
    _G.ArenaCoachTBCDB.enabled = true
end)

H.it(g, "CreateFrame shows addon version in the HUD", function()
    local savedAPI = _G.ArenaCoachTBC
    UI.frame = nil
    _G.ArenaCoachTBC = { GetVersion = function() return "9.9.9-test" end }
    local f = UI:CreateFrame()
    local text = f.versionText:GetText()
    _G.ArenaCoachTBC = savedAPI
    H.assertEq(text, "v9.9.9-test")
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
    local txt = UI.frame and UI.frame.assignText and UI.frame.assignText._text or ""
    H.assertTrue(txt:find("Assignments", 1, true) ~= nil, "assignment header missing: " .. txt)
    H.assertTrue(txt:find("Warrior:", 1, true) ~= nil, "player assignment missing: " .. txt)
    H.assertTrue(txt:find("Shaman:", 1, true) ~= nil, "party assignment missing: " .. txt)
    H.assertTrue(txt:find("Holyman", 1, true) ~= nil, "assignment target missing: " .. txt)
    H.assertTrue(UI.frame:IsShown(), "integrated assignment board should show when assignments exist")
end)

H.it(g, "Apply renders left focus strip and right cue rail", function()
    H.ns.Core = H.ns.Core or {}
    H.ns.Core.state = H.ns.Core.state or {}
    H.ns.Core.state.pvpContext = "arena"
    H.ns.Core.state.friendlies = {
        player = { unit = "player", name = "You", class = "WARRIOR", alive = true, healthPct = 0.88 },
        party1 = { unit = "party1", name = "Leaves", class = "DRUID", alive = true, healthPct = 0.41 },
    }
    UI:CreateFrame()
    UI:Apply({
        mode = "KILL",
        primaryTargetName = "Holyman",
        primaryTargetHp = 0.42,
        secondaryTargetName = "Frostbiter",
        callouts = { "CALL_PURGE" },
        priority = "HIGH",
    })
    local focus = UI.frame and UI.frame.unitText and UI.frame.unitText._text or ""
    local rail = UI.frame and UI.frame.railText and UI.frame.railText._text or ""
    H.assertTrue(focus:find("Focus", 1, true) ~= nil, "focus strip header missing: " .. focus)
    H.assertTrue(focus:find("Holyman", 1, true) ~= nil, "primary target missing: " .. focus)
    H.assertTrue(focus:find("42", 1, true) ~= nil, "primary target hp missing: " .. focus)
    H.assertTrue(focus:find("Frostbiter", 1, true) ~= nil, "secondary target missing: " .. focus)
    H.assertTrue(focus:find("Leaves", 1, true) ~= nil, "lowest friendly missing: " .. focus)
    H.assertTrue(rail:find("Cues", 1, true) ~= nil, "cue rail header missing: " .. rail)
    H.assertTrue(rail:find("Holyman", 1, true) ~= nil, "cue rail should render target-aware callout: " .. rail)
    H.assertTrue(UI.frame:IsShown(), "integrated board should show when focus and cue content exists")
    H.ns.Core.state.pvpContext = nil
    H.ns.Core.state.friendlies = nil
end)

H.it(g, "Apply force-show keeps prototype-A scaffold visible without live data", function()
    H.ns.Core = H.ns.Core or {}
    H.ns.Core.state = H.ns.Core.state or {}
    H.ns.Core.state.pvpContext = "none"
    H.ns.Core.state.combatPhase = "PRE"
    UI:CreateFrame()
    UI:Apply({
        mode = "OPEN",
        callouts = {},
        priority = "MEDIUM",
        _forceShow = true,
    })
    H.assertTrue(UI.frame:IsShown(), "force-show should keep the center toast visible")
    H.assertNotNil(UI.frame.unitText)
    H.assertNotNil(UI.frame.railText)
    H.assertNotNil(UI.frame.assignText)
    H.assertTrue((UI.frame.unitText._text or ""):find("waiting", 1, true) ~= nil,
        "force-show focus scaffold should include placeholders")
    H.assertTrue((UI.frame.railText._text or ""):find("Burst", 1, true) ~= nil,
        "force-show cue scaffold should include burst placeholder")
    H.assertTrue((UI.frame.assignText._text or ""):find("Assignments", 1, true) ~= nil,
        "force-show assignments scaffold should include header")
    H.ns.Core.state.pvpContext = nil
    H.ns.Core.state.combatPhase = nil
end)

H.it(g, "Apply caps default assignments but verbose mode shows the full team", function()
    _G.ArenaCoachTBCDB = {
        enabled = true, locked = false, language = "auto",
        frame = { point = "CENTER", x = 0, y = 120, scale = 1.0, verbose = false },
        alerts = { sound = false, screenFlash = false, edgeGlow = false, nameplate = false },
        strategy = {}, debug = false,
    }
    UI:CreateFrame()
    local actions = {
        { name = "Warrior", actionKey = "ACTION_WARRIOR_KILL", targetName = "Holyman" },
        { name = "Shaman", actionKey = "ACTION_SHAMAN_PURGE", targetName = "Holyman" },
        { name = "Paladin", actionKey = "ACTION_PALADIN_HOJ", targetName = "Holyman" },
        { name = "Druid", actionKey = "ACTION_DRUID_CC", targetName = "Mage" },
        { name = "Priest", actionKey = "ACTION_PRIEST_DEFEND", targetName = "Warrior" },
    }
    UI:Apply({ mode = "KILL", primaryTargetName = "Holyman", callouts = {}, priority = "HIGH", playerActions = actions })
    local compact = UI.frame and UI.frame.assignText and UI.frame.assignText._text or ""
    H.assertTrue(compact:find("Warrior:", 1, true) ~= nil, "first assignment missing: " .. compact)
    H.assertTrue(compact:find("Paladin:", 1, true) ~= nil, "third assignment missing: " .. compact)
    H.assertTrue(compact:find("Druid:", 1, true) == nil, "compact HUD should cap after three assignments: " .. compact)

    _G.ArenaCoachTBCDB.frame.verbose = true
    UI:Apply({ mode = "KILL", primaryTargetName = "Holyman", callouts = {}, priority = "HIGH", playerActions = actions })
    local verbose = UI.frame and UI.frame.assignText and UI.frame.assignText._text or ""
    H.assertTrue(verbose:find("Druid:", 1, true) ~= nil, "verbose HUD should show fourth assignment: " .. verbose)
    H.assertTrue(verbose:find("Priest:", 1, true) ~= nil, "verbose HUD should show fifth assignment: " .. verbose)
end)

H.it(g, "prototype-A modules have independent movable saved positions", function()
    _G.ArenaCoachTBCDB = {
        enabled = true, locked = false, language = "auto",
        frame = { point = "CENTER", x = 0, y = 120, scale = 1.0 },
        assignmentFrame = { point = "CENTER", x = 0, y = 16, scale = 1.0 },
        unitFrame = { point = "CENTER", x = -258, y = 120, scale = 1.0 },
        railFrame = { point = "CENTER", x = 258, y = 120, scale = 1.0 },
        alerts = { sound = false, screenFlash = false, edgeGlow = false, nameplate = false },
        strategy = {}, debug = false,
    }
    UI.frame = nil
    UI.assignFrame = nil
    UI.unitFrame = nil
    UI.railFrame = nil
    UI:CreateFrame()
    H.assertNotNil(UI.assignFrame)
    H.assertNotNil(UI.unitFrame)
    H.assertNotNil(UI.railFrame)
    UI.frame._scripts.OnMouseDown(UI.frame, "LeftButton")
    UI.frame._scripts.OnMouseUp(UI.frame)
    UI.unitFrame._scripts.OnMouseDown(UI.unitFrame, "LeftButton")
    UI.unitFrame._scripts.OnMouseUp(UI.unitFrame)
    UI.railFrame._scripts.OnMouseDown(UI.railFrame, "LeftButton")
    UI.railFrame._scripts.OnMouseUp(UI.railFrame)
    UI.assignFrame._scripts.OnMouseDown(UI.assignFrame, "LeftButton")
    UI.assignFrame._scripts.OnMouseUp(UI.assignFrame)
    H.assertEq(_G.ArenaCoachTBCDB.frame.point, "CENTER")
    H.assertEq(_G.ArenaCoachTBCDB.assignmentFrame.point, "CENTER")
    H.assertEq(_G.ArenaCoachTBCDB.unitFrame.point, "CENTER")
    H.assertEq(_G.ArenaCoachTBCDB.railFrame.point, "CENTER")
    H.assertEq(_G.ArenaCoachTBCDB.assignmentFrame.x, 0)
    H.assertEq(_G.ArenaCoachTBCDB.assignmentFrame.y, 0)
end)

H.it(g, "Apply renders arcade warning cue for burst windows", function()
    UI:CreateFrame()
    UI._flash = nil
    UI:Apply({
        mode = "KILL",
        primaryTargetName = "Holyman",
        callouts = { "CALL_PURGE", "BURST_NOW" },
        burstAllowed = true,
        priority = "HIGH",
    })
    local txt = UI.frame.arcadeText and UI.frame.arcadeText._text or ""
    H.assertTrue(txt:find("BURST", 1, true) ~= nil, "burst arcade cue missing: " .. txt)
    H.assertNil(UI._flash, "arcade cue must not use the fullscreen flash helper")
end)

H.it(g, "Apply renders arcade pinch cue for outnumbered BG/world warnings", function()
    H.ns.Core = H.ns.Core or {}
    H.ns.Core.state = H.ns.Core.state or {}
    H.ns.Core.state.pvpContext = "bg"
    UI:CreateFrame()
    UI:Apply({
        mode = "KILL",
        primaryTargetName = "Rogue",
        callouts = { "CALL_OUTNUMBERED_DISENGAGE" },
        priority = "HIGH",
    })
    local txt = UI.frame.arcadeText and UI.frame.arcadeText._text or ""
    H.assertTrue(txt:find("PINCH", 1, true) ~= nil, "pinch arcade cue missing: " .. txt)
    H.ns.Core.state.pvpContext = nil
end)

H.it(g, "stale recommendations fade out and clear visual layers", function()
    H.load("ScreenEdgeGlow.lua")
    H.load("Nameplate.lua")
    local Glow = H.ns.ScreenEdgeGlow
    local NP = H.ns.Nameplate
    _G.ArenaCoachTBCDB = _G.ArenaCoachTBCDB or {}
    _G.ArenaCoachTBCDB.alerts = { edgeGlow = true, nameplate = true }
    H.ns.Core = H.ns.Core or {}
    H.ns.Core.state = H.ns.Core.state or {}
    H.ns.Core.state.pvpContext = "arena"

    UI:CreateFrame()
    Glow:SetMode("KILL")
    H.setUnit("nameplate1", { guid = "guid-target", class = "PRIEST",
                              name = "Holyman", exists = true })
    _G.nameplate1 = _G.nameplate1 or H.makeMockFrame{ name = "nameplate1" }
    UI:Apply({
        mode = "KILL",
        primaryTarget = "guid-target",
        primaryTargetName = "Holyman",
        callouts = {},
        priority = "HIGH",
    })
    local on = UI.frame._scripts.OnUpdate
    H.assertNotNil(on)
    H.assertEq(UI.frame._accAlpha, 1)
    on(UI.frame, UI.staleFadeStart + (UI.staleFadeSeconds / 2))
    H.assertTrue(UI.frame._accAlpha < 1 and UI.frame._accAlpha > 0,
        "stale frame should be partially faded")
    on(UI.frame, UI.staleFadeSeconds)
    H.assertFalse(UI.frame:IsShown(), "stale frame should hide after fading out")
    H.assertNil(Glow:CurrentMode(), "stale fade should clear edge cue")
    for _, ov in pairs(NP._overlays or {}) do
        H.assertFalse(ov:IsShown(), "stale fade should clear nameplate overlays")
    end
    H.ns.Core.state.pvpContext = nil
end)

H.it(g, "fresh recommendations restore full opacity after stale fade", function()
    H.ns.Core = H.ns.Core or {}
    H.ns.Core.state = H.ns.Core.state or {}
    H.ns.Core.state.pvpContext = "arena"
    UI:CreateFrame()
    UI:Apply({ mode = "KILL", primaryTargetName = "Holyman", callouts = {}, priority = "HIGH" })
    local on = UI.frame._scripts.OnUpdate
    on(UI.frame, UI.staleFadeStart + UI.staleFadeSeconds + 0.1)
    H.assertFalse(UI.frame:IsShown())
    UI:Apply({ mode = "SWAP", primaryTargetName = "Mage", callouts = {}, priority = "HIGH" })
    H.assertTrue(UI.frame:IsShown())
    H.assertEq(UI.frame._accAlpha, 1)
    H.ns.Core.state.pvpContext = nil
end)

H.it(g, "pre-gates OPEN plan does not fade just because the room is quiet", function()
    H.ns.Core = H.ns.Core or {}
    H.ns.Core.state = H.ns.Core.state or {}
    H.ns.Core.state.pvpContext = "arena"
    H.ns.Core.state.combatPhase = "PRE"
    UI:CreateFrame()
    UI:Apply({ mode = "OPEN", primaryTargetName = "Priest", callouts = {}, priority = "MEDIUM" })
    local on = UI.frame._scripts.OnUpdate
    on(UI.frame, UI.staleFadeStart + UI.staleFadeSeconds + 5)
    H.assertTrue(UI.frame:IsShown(), "stable pre-gates opener plan should remain visible")
    H.assertTrue((UI.frame.unitText._text or ""):find("Priest", 1, true) ~= nil,
        "pre-gates opener should render in the integrated focus panel")
    H.assertTrue((UI.frame.railText._text or ""):find("Burst", 1, true) ~= nil,
        "pre-gates opener should keep the integrated cue scaffold visible")
    H.assertTrue((UI.frame.assignText._text or ""):find("Assignments", 1, true) ~= nil,
        "pre-gates opener should keep integrated assignments scaffold visible")
    H.assertEq(UI.frame._accAlpha, 1)
    H.ns.Core.state.pvpContext = nil
    H.ns.Core.state.combatPhase = nil
end)

H.it(g, "arena quality: formatted top callout renders with target name instead of raw percent-s", function()
    _G.ArenaCoachTBCDB = {
        enabled = true, locked = false, language = "auto",
        frame = { point = "CENTER", x = 0, y = 120, scale = 1.0, verbose = false },
        alerts = { sound = false, screenFlash = false, edgeGlow = false, nameplate = false },
        strategy = {}, debug = false,
    }
    UI:CreateFrame()
    UI._calloutLastShown = {}
    H.advanceTime(5)

    UI:Apply({
        mode = "KILL",
        primaryTargetName = "Holyman",
        primaryTargetClass = "PRIEST",
        callouts = { "CALL_PURGE" },
        priority = "HIGH",
        _forceShow = true,
    })

    local text = UI.frame.subText:GetText()
    H.assertTrue(text:find("Holyman", 1, true) ~= nil, "formatted callout should include target name")
    H.assertTrue(text:find("%%s") == nil, "formatted callout must not leak raw %s")
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
-- v2.3.0: /acc test demo paints optional edge cue + nameplate,
-- not just the text. Regression for the bug where _forceShow bypassed
-- the auto-hide gate but the visual-layer gate still required inPvP.
-- =================================================================

H.it(g, "v2.3.0: _forceShow bypasses inPvP gate for thin edge cue + nameplate", function()
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
        "thin edge cue should activate in KILL mode when _forceShow is set, even without pvp context")
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
        "thin edge cue must be cleared when context is 'none' and _forceShow is not set")
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
