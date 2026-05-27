-- ArenaCoachTBC - UI layer
-- Compact movable frames that show the current recommendation (mode,
-- target, HP%, kill prob, callouts) and per-player assignments. Driven
-- event-by-event from Core; no polling.
-- v2.2.0 added two peripheral visual layers wired in here: a
-- mode-coloured thin edge cue (ScreenEdgeGlow.lua) and a coloured
-- border on the kill / swap target's nameplate (Nameplate.lua). No
-- protected actions are ever bound to any visible button.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.UI = ns.UI or {}

local UI = ns.UI
UI.frame = nil

local ADDON_VERSION = "2.8.18"
local STALE_FADE_START = 2.5
local STALE_FADE_SECONDS = 1.5
local COMPACT_WIDTH = 460
local COMPACT_HEIGHT = 168
local GRID_PADDING = 8
local HEADER_HEIGHT = 22
local GRID_TOP_Y = -30
local TOP_ROW_HEIGHT = 82
local SIDE_PANEL_WIDTH = 126
local CENTER_PANEL_WIDTH = COMPACT_WIDTH - (GRID_PADDING * 2) - (SIDE_PANEL_WIDTH * 2)
local ASSIGN_PANEL_HEIGHT = 52
local UNIT_WIDTH = 150
local UNIT_HEIGHT = 96
local RAIL_WIDTH = 150
local RAIL_HEIGHT = 118
local ASSIGN_WIDTH = 300
local ASSIGN_HEIGHT = 76
local DEFAULT_ACTION_LINES = 3
local VERBOSE_ACTION_LINES = 5

UI.staleFadeStart = STALE_FADE_START
UI.staleFadeSeconds = STALE_FADE_SECONDS

-- Resolve a localized string by key.
local function L(key, ...)
    local Core = ns.Core
    if Core and Core.L then
        local s = Core.L(key)
        if select("#", ...) > 0 then return string.format(s, ...) end
        return s
    end
    return key
end

local function addonVersion()
    local api = _G.ArenaCoachTBC
    if api and type(api.GetVersion) == "function" then
        local ok, version = pcall(api.GetVersion)
        if ok and version then return tostring(version) end
    end
    return ADDON_VERSION
end

function UI:RefreshVersionText()
    if self.frame and self.frame.versionText then
        self.frame.versionText:SetText("v" .. addonVersion())
    end
end

local function setBackdrop(frame, alpha, edgeSize)
    if not (frame and frame.SetBackdrop) then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = edgeSize or 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, alpha or 0.30)
end

local function colorTexture(tex, r, g, b, a)
    if not tex then return end
    local ok = false
    if tex.SetColorTexture then
        ok = pcall(tex.SetColorTexture, tex, r, g, b, a)
    end
    if not ok and tex.SetTexture then
        pcall(tex.SetTexture, tex, r, g, b, a)
    end
end

local function clearPoints(region)
    if region and region.ClearAllPoints then pcall(region.ClearAllPoints, region) end
end

local function point(region, ...)
    if region and region.SetPoint then pcall(region.SetPoint, region, ...) end
end

local function size(region, w, h)
    if not region then return end
    if region.SetSize then
        pcall(region.SetSize, region, w, h)
    else
        if region.SetWidth then pcall(region.SetWidth, region, w) end
        if region.SetHeight then pcall(region.SetHeight, region, h) end
    end
end

local function skinPanel(frame, alpha, borderAlpha)
    if not (frame and frame.CreateTexture) then return end
    frame._accBg = frame._accBg or frame:CreateTexture(nil, "BACKGROUND")
    clearPoints(frame._accBg)
    if frame._accBg.SetAllPoints then
        pcall(frame._accBg.SetAllPoints, frame._accBg, frame)
    else
        point(frame._accBg, "TOPLEFT", frame, "TOPLEFT", 0, 0)
        point(frame._accBg, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    end
    colorTexture(frame._accBg, 0, 0, 0, alpha or 0.44)

    local border = borderAlpha or 0.50
    local bars = {
        { "_accTop", "TOPLEFT", "TOPRIGHT", 0, -1, 0, -1, true },
        { "_accBottom", "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1, 0, 1, true },
        { "_accLeft", "TOPLEFT", "BOTTOMLEFT", 1, 0, 1, 0, false },
        { "_accRight", "TOPRIGHT", "BOTTOMRIGHT", -1, 0, -1, 0, false },
    }
    for i = 1, #bars do
        local b = bars[i]
        local tex = frame[b[1]] or frame:CreateTexture(nil, "BORDER")
        frame[b[1]] = tex
        clearPoints(tex)
        point(tex, b[2], frame, b[2], b[4], b[5])
        point(tex, b[3], frame, b[3], b[6], b[7])
        if b[8] then
            if tex.SetHeight then pcall(tex.SetHeight, tex, 1) end
        else
            if tex.SetWidth then pcall(tex.SetWidth, tex, 1) end
        end
        colorTexture(tex, 0.78, 0.62, 0.34, border)
    end
end

local function solidTexture(parent, key, layer, r, g, b, a)
    if not (parent and parent.CreateTexture) then return nil end
    local tex = parent[key] or parent:CreateTexture(nil, layer or "BACKGROUND")
    parent[key] = tex
    colorTexture(tex, r, g, b, a)
    return tex
end

local function placeLine(parent, key, w, h, x, y, alpha)
    local tex = solidTexture(parent, key, "ARTWORK", 0.95, 0.74, 0.36, alpha or 0.68)
    if not tex then return nil end
    clearPoints(tex)
    size(tex, w, h)
    point(tex, "TOPLEFT", parent, "TOPLEFT", x, y)
    return tex
end

local function createChildPanel(parent, key, width, height, pointA, relativePoint, x, y, alpha)
    if not (parent and type(CreateFrame) == "function") then return nil end
    local panel = parent[key] or CreateFrame("Frame", nil, parent)
    parent[key] = panel
    panel:SetSize(width, height)
    panel:ClearAllPoints()
    panel:SetPoint(pointA, parent, relativePoint or pointA, x or 0, y or 0)
    if panel.EnableMouse then panel:EnableMouse(false) end
    skinPanel(panel, alpha or 0.32, 0.36)
    return panel
end

local function moduleHeader(key)
    return "|cffc8a86b" .. L(key) .. "|r"
end

local function waitingValue()
    return "|cff8a8a8a" .. L("UI_MODULE_WAITING") .. "|r"
end

local function waitingLine(labelKey)
    return string.format("%s: %s", L(labelKey), waitingValue())
end

local function waitingUnitText()
    return table.concat({
        moduleHeader("UI_MODULE_FOCUS"),
        waitingLine("UI_MODULE_TARGET"),
        waitingLine("UI_MODULE_SWAP"),
        waitingLine("UI_MODULE_TEAM"),
    }, "\n")
end

local function waitingCueText()
    return table.concat({
        moduleHeader("UI_MODULE_CUES"),
        waitingLine("UI_MODULE_BURST"),
        waitingLine("UI_MODULE_UTILITY"),
    }, "\n")
end

local function waitingAssignmentText()
    return moduleHeader("UI_ACTIONS_HEADER") .. "\n" .. waitingValue()
end

local function layoutScaffoldActive(recommendation)
    if recommendation and recommendation._forceShow then return true end
    local phase = ns.Core and ns.Core.state and ns.Core.state.combatPhase
    return recommendation and recommendation.mode == "OPEN" and phase == "PRE"
end

local function saveFramePosition(key, frame)
    if not (ArenaCoachTBCDB and frame and frame.GetPoint) then return end
    ArenaCoachTBCDB[key] = ArenaCoachTBCDB[key] or {}
    local point, _, _, x, y = frame:GetPoint()
    ArenaCoachTBCDB[key].point = point
    ArenaCoachTBCDB[key].x = x
    ArenaCoachTBCDB[key].y = y
end

local function installDrag(frame, key)
    if not frame then return end
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not (ArenaCoachTBCDB and ArenaCoachTBCDB.locked) then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        saveFramePosition(key, self)
    end)
end

-- ============================================================
-- Build the main frame
-- ============================================================
function UI:CreateFrame()
    if self.frame then
        if not self.assignFrame then self:CreateAssignmentsFrame() end
        if not self.unitFrame then self:CreateUnitStripFrame() end
        if not self.railFrame then self:CreateCueRailFrame() end
        return self.frame
    end
    if type(CreateFrame) ~= "function" then return nil end

    local db = ArenaCoachTBCDB or {}
    local fcfg = db.frame or { point = "CENTER", x = 0, y = 120, scale = 1.0 }

    local f = CreateFrame("Frame", "ArenaCoachTBCFrame", UIParent)
    -- v2.8.15: prototype-A is now a single visible board. Earlier
    -- releases used separate satellite frames; if the user moved the
    -- center frame, those satellites could sit elsewhere and the HUD
    -- still looked like plain floating text. The board keeps the agreed
    -- left/center/right/bottom structure together.
    f:SetSize(COMPACT_WIDTH, COMPACT_HEIGHT)
    f:SetPoint(fcfg.point or "CENTER", UIParent, fcfg.point or "CENTER",
               fcfg.x or 0, fcfg.y or 120)
    f:SetScale(fcfg.scale or 1.0)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    if f.SetFrameStrata then pcall(f.SetFrameStrata, f, "HIGH") end
    if f.SetFrameLevel then pcall(f.SetFrameLevel, f, 20) end

    -- Backdrop (TBC client uses Backdrop trait built-in for Frame)
    setBackdrop(f, 0.52, 12)
    skinPanel(f, 0.58, 0.74)

    -- Title: small identity marker, not a full header row.
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -6)
    f.title:SetJustifyH("LEFT")
    f.title:SetWidth(190)
    f.title:SetText(L("UI_TITLE"))

    local dragBar = solidTexture(f, "dragBar", "BACKGROUND", 0.03, 0.025, 0.015, 0.76)
    if dragBar then
        clearPoints(dragBar)
        point(dragBar, "TOPLEFT", f, "TOPLEFT", 2, -2)
        point(dragBar, "TOPRIGHT", f, "TOPRIGHT", -2, -2)
        if dragBar.SetHeight then pcall(dragBar.SetHeight, dragBar, HEADER_HEIGHT) end
    end

    local topY = GRID_TOP_Y
    local leftX = GRID_PADDING
    local centerX = leftX + SIDE_PANEL_WIDTH
    local rightX = centerX + CENTER_PANEL_WIDTH
    local assignY = topY - TOP_ROW_HEIGHT
    local contentW = COMPACT_WIDTH - (GRID_PADDING * 2)

    local leftPanel = createChildPanel(f, "leftPanel", SIDE_PANEL_WIDTH, TOP_ROW_HEIGHT,
        "TOPLEFT", "TOPLEFT", leftX, topY, 0.48)
    local centerPanel = createChildPanel(f, "centerPanel", CENTER_PANEL_WIDTH, TOP_ROW_HEIGHT,
        "TOPLEFT", "TOPLEFT", centerX, topY, 0.42)
    local rightPanel = createChildPanel(f, "rightPanel", SIDE_PANEL_WIDTH, TOP_ROW_HEIGHT,
        "TOPLEFT", "TOPLEFT", rightX, topY, 0.48)
    local assignPanel = createChildPanel(f, "assignPanel", contentW, ASSIGN_PANEL_HEIGHT,
        "TOPLEFT", "TOPLEFT", leftX, assignY, 0.46)

    placeLine(f, "leftDivider", 1, TOP_ROW_HEIGHT, centerX, topY, 0.78)
    placeLine(f, "rightDivider", 1, TOP_ROW_HEIGHT, rightX, topY, 0.78)
    placeLine(f, "assignDivider", contentW, 1, leftX, assignY, 0.78)

    -- Small build marker for rapid local-copy/release verification.
    f.versionText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.versionText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
    f.versionText:SetJustifyH("RIGHT")
    f.versionText:SetWidth(70)
    f.versionText:SetTextColor(0.75, 0.75, 0.75)
    f.versionText:SetText("v" .. addonVersion())

    f.dragGrip = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.dragGrip:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
    f.dragGrip:SetJustifyH("LEFT")
    f.dragGrip:SetWidth(16)
    f.dragGrip:SetTextColor(0.78, 0.62, 0.34)
    f.dragGrip:SetText("|||")

    -- v2.8.1: Japanese-arcade-style warning plate. This is just a big,
    -- passive text cue inside the HUD, never a fullscreen flash.
    local actionParent = centerPanel or f
    f.arcadeText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    f.arcadeText:SetPoint("TOP", actionParent, "TOP", 0, -5)
    if f.arcadeText.SetFont then
        local fontPath = (f.arcadeText.GetFont and select(1, f.arcadeText:GetFont()))
            or "Fonts\\FRIZQT__.TTF"
        pcall(f.arcadeText.SetFont, f.arcadeText, fontPath, 17, "THICKOUTLINE")
    end
    f.arcadeText:SetJustifyH("CENTER")
    f.arcadeText:SetWidth(CENTER_PANEL_WIDTH - 10)
    f.arcadeText:SetText(string.format("!! %s !!", L("UI_ARCADE_READY")))

    -- Main recommendation line ("KILL: Warlock"). This remains the
    -- largest element, but no longer consumes a raid-warning sized band.
    f.bigText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    f.bigText:SetPoint("TOP", f.arcadeText, "BOTTOM", 0, -1)
    if f.bigText.SetFont then
        local fontPath = (f.bigText.GetFont and select(1, f.bigText:GetFont()))
            or "Fonts\\FRIZQT__.TTF"
        pcall(f.bigText.SetFont, f.bigText, fontPath, 20, "OUTLINE")
    end
    f.bigText:SetJustifyH("CENTER")
    f.bigText:SetWidth(CENTER_PANEL_WIDTH - 10)
    f.bigText:SetText(L("REASON_DEFAULT"))

    -- Target stats row (HP% + kill prob%) under the mode line. Kept
    -- compact so it reads as supporting context rather than another alert.
    f.statsText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.statsText:SetPoint("TOP", f.bigText, "BOTTOM", 0, -3)
    if f.statsText.SetFont then
        local fontPath = (f.statsText.GetFont and select(1, f.statsText:GetFont()))
            or "Fonts\\FRIZQT__.TTF"
        pcall(f.statsText.SetFont, f.statsText, fontPath, 11, "OUTLINE")
    end
    f.statsText:SetJustifyH("CENTER")
    f.statsText:SetWidth(CENTER_PANEL_WIDTH - 10)
    f.statsText:SetText("")

    -- Reason / top callout text. Default mode shows one line; verbose
    -- mode can still expand for debugging.
    f.subText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.subText:SetPoint("TOP", f.statsText, "BOTTOM", 0, -3)
    if f.subText.SetSpacing then pcall(f.subText.SetSpacing, f.subText, 2) end
    f.subText:SetJustifyH("CENTER")
    f.subText:SetWidth(CENTER_PANEL_WIDTH - 10)
    f.subText:SetText("")

    if leftPanel then
        f.unitText = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.unitText:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 8, -7)
        if f.unitText.SetFont then
            local fontPath = (f.unitText.GetFont and select(1, f.unitText:GetFont()))
                or "Fonts\\FRIZQT__.TTF"
            pcall(f.unitText.SetFont, f.unitText, fontPath, 10, "OUTLINE")
        end
        if f.unitText.SetSpacing then pcall(f.unitText.SetSpacing, f.unitText, 1) end
        f.unitText:SetJustifyH("LEFT")
        f.unitText:SetWidth(SIDE_PANEL_WIDTH - 16)
        f.unitText:SetText(waitingUnitText())
    end

    if rightPanel then
        f.railText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.railText:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 8, -7)
        if f.railText.SetFont then
            local fontPath = (f.railText.GetFont and select(1, f.railText:GetFont()))
                or "Fonts\\FRIZQT__.TTF"
            pcall(f.railText.SetFont, f.railText, fontPath, 10, "OUTLINE")
        end
        if f.railText.SetSpacing then pcall(f.railText.SetSpacing, f.railText, 1) end
        f.railText:SetJustifyH("LEFT")
        f.railText:SetWidth(SIDE_PANEL_WIDTH - 16)
        f.railText:SetText(waitingCueText())
    end

    if assignPanel then
        f.assignText = assignPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.assignText:SetPoint("TOPLEFT", assignPanel, "TOPLEFT", 10, -7)
        if f.assignText.SetFont then
            local fontPath = (f.assignText.GetFont and select(1, f.assignText:GetFont()))
                or "Fonts\\FRIZQT__.TTF"
            pcall(f.assignText.SetFont, f.assignText, fontPath, 10, "OUTLINE")
        end
        if f.assignText.SetSpacing then pcall(f.assignText.SetSpacing, f.assignText, 1) end
        f.assignText:SetJustifyH("LEFT")
        f.assignText:SetWidth(contentW - 20)
        f.assignText:SetText(waitingAssignmentText())
    end

    installDrag(f, "frame")
    f:SetScript("OnUpdate", function(_, dt)
        if UI and UI._UpdateStaleFade then UI:_UpdateStaleFade(dt) end
    end)

    self.frame = f
    self:CreateUnitStripFrame()
    self:CreateCueRailFrame()
    self:CreateAssignmentsFrame()
    return f
end

function UI:CreateUnitStripFrame()
    if self.unitFrame then return self.unitFrame end
    if type(CreateFrame) ~= "function" then return nil end

    local db = ArenaCoachTBCDB or {}
    local ucfg = db.unitFrame or { point = "CENTER", x = -230, y = 120, scale = 1.0 }
    local uf = CreateFrame("Frame", "ArenaCoachTBCUnitStripFrame", UIParent)
    uf:SetSize(UNIT_WIDTH, UNIT_HEIGHT)
    uf:SetPoint(ucfg.point or "CENTER", UIParent, ucfg.point or "CENTER",
                ucfg.x or -230, ucfg.y or 120)
    uf:SetScale(ucfg.scale or 1.0)
    uf:SetMovable(true)
    uf:SetClampedToScreen(true)
    uf:EnableMouse(true)
    if uf.SetFrameStrata then pcall(uf.SetFrameStrata, uf, "HIGH") end
    setBackdrop(uf, 0.34, 10)
    skinPanel(uf, 0.34, 0.42)

    uf.text = uf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    uf.text:SetPoint("TOPLEFT", uf, "TOPLEFT", 8, -8)
    if uf.text.SetFont then
        local fontPath = (uf.text.GetFont and select(1, uf.text:GetFont()))
            or "Fonts\\FRIZQT__.TTF"
        pcall(uf.text.SetFont, uf.text, fontPath, 11, "OUTLINE")
    end
    if uf.text.SetSpacing then pcall(uf.text.SetSpacing, uf.text, 1) end
    uf.text:SetJustifyH("LEFT")
    uf.text:SetWidth(UNIT_WIDTH - 16)
    uf.text:SetText(waitingUnitText())

    installDrag(uf, "unitFrame")
    uf._hasUnits = false
    uf:Hide()
    self.unitFrame = uf
    return uf
end

function UI:CreateCueRailFrame()
    if self.railFrame then return self.railFrame end
    if type(CreateFrame) ~= "function" then return nil end

    local db = ArenaCoachTBCDB or {}
    local rcfg = db.railFrame or { point = "CENTER", x = 230, y = 120, scale = 1.0 }
    local rf = CreateFrame("Frame", "ArenaCoachTBCCueRailFrame", UIParent)
    rf:SetSize(RAIL_WIDTH, RAIL_HEIGHT)
    rf:SetPoint(rcfg.point or "CENTER", UIParent, rcfg.point or "CENTER",
                rcfg.x or 230, rcfg.y or 120)
    rf:SetScale(rcfg.scale or 1.0)
    rf:SetMovable(true)
    rf:SetClampedToScreen(true)
    rf:EnableMouse(true)
    if rf.SetFrameStrata then pcall(rf.SetFrameStrata, rf, "HIGH") end
    setBackdrop(rf, 0.34, 10)
    skinPanel(rf, 0.34, 0.42)

    rf.text = rf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rf.text:SetPoint("TOPLEFT", rf, "TOPLEFT", 8, -8)
    if rf.text.SetFont then
        local fontPath = (rf.text.GetFont and select(1, rf.text:GetFont()))
            or "Fonts\\FRIZQT__.TTF"
        pcall(rf.text.SetFont, rf.text, fontPath, 11, "OUTLINE")
    end
    if rf.text.SetSpacing then pcall(rf.text.SetSpacing, rf.text, 2) end
    rf.text:SetJustifyH("LEFT")
    rf.text:SetWidth(RAIL_WIDTH - 16)
    rf.text:SetText(waitingCueText())

    installDrag(rf, "railFrame")
    rf._hasCues = false
    rf:Hide()
    self.railFrame = rf
    return rf
end

function UI:CreateAssignmentsFrame()
    if self.assignFrame then return self.assignFrame end
    if type(CreateFrame) ~= "function" then return nil end

    local db = ArenaCoachTBCDB or {}
    local acfg = db.assignmentFrame or { point = "CENTER", x = 0, y = 16, scale = 1.0 }
    local af = CreateFrame("Frame", "ArenaCoachTBCAssignmentsFrame", UIParent)
    af:SetSize(ASSIGN_WIDTH, ASSIGN_HEIGHT)
    af:SetPoint(acfg.point or "CENTER", UIParent, acfg.point or "CENTER",
                acfg.x or 0, acfg.y or 16)
    af:SetScale(acfg.scale or 1.0)
    af:SetMovable(true)
    af:SetClampedToScreen(true)
    af:EnableMouse(true)
    if af.SetFrameStrata then pcall(af.SetFrameStrata, af, "HIGH") end

    setBackdrop(af, 0.30, 10)
    skinPanel(af, 0.30, 0.42)

    af.actionText = af:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    af.actionText:SetPoint("TOPLEFT", af, "TOPLEFT", 10, -8)
    if af.actionText.SetFont then
        local fontPath = (af.actionText.GetFont and select(1, af.actionText:GetFont()))
            or "Fonts\\FRIZQT__.TTF"
        pcall(af.actionText.SetFont, af.actionText, fontPath, 11, "OUTLINE")
    end
    if af.actionText.SetSpacing then pcall(af.actionText.SetSpacing, af.actionText, 1) end
    af.actionText:SetJustifyH("LEFT")
    af.actionText:SetWidth(ASSIGN_WIDTH - 20)
    af.actionText:SetText(waitingAssignmentText())

    installDrag(af, "assignmentFrame")
    af._hasAssignments = false
    af:Hide()
    self.assignFrame = af
    return af
end

-- ============================================================
-- Apply a recommendation to the UI
-- ============================================================
local modeColors = {
    OPEN   = {1.0, 1.0, 0.4},
    KILL   = {1.0, 0.3, 0.3},
    SWAP   = {1.0, 0.6, 0.0},
    DEFEND = {0.4, 0.7, 1.0},
    RESET  = {0.7, 0.7, 0.7},
}

-- v2.5.0: high-contrast palette for the accessibility skin. Pure
-- primary channels at maximum saturation so the label punches through
-- visual noise on small screens / under glare / for users with reduced
-- colour sensitivity. The default palette above is tuned for visual
-- coherence; this one trades coherence for legibility. Opt-in via
-- /acc highcontrast on.
local modeColorsHighContrast = {
    OPEN   = {1.0, 1.0, 0.0},   -- pure yellow
    KILL   = {1.0, 0.0, 0.0},   -- pure red
    SWAP   = {1.0, 0.5, 0.0},   -- pure orange
    DEFEND = {0.0, 0.7, 1.0},   -- saturated cyan-blue
    RESET  = {1.0, 1.0, 1.0},   -- white instead of grey
}

local arcadeCueByMode = {
    OPEN   = "UI_ARCADE_READY",
    KILL   = "UI_ARCADE_ATTACK",
    SWAP   = "UI_ARCADE_SWITCH",
    DEFEND = "UI_ARCADE_DANGER",
    RESET  = "UI_ARCADE_RECOVER",
}

local arcadeCueByCallout = {
    CALL_OUTNUMBERED_DISENGAGE = "UI_ARCADE_PINCH",
    CALL_BURST_BLOCK_INCOMING  = "UI_ARCADE_HOLD",
    CALL_FLAG_CARRIER_LOW      = "UI_ARCADE_PUSH",
    CALL_BG_DEFEND             = "UI_ARCADE_DANGER",
    CALL_BASE_UNDER_ATTACK     = "UI_ARCADE_DANGER",
    CALL_PATTERN_RMP_CHEAP_BLIND = "UI_ARCADE_DANGER",
    CALL_PATTERN_SHATTER_NOVA_SHEEP = "UI_ARCADE_DANGER",
    CALL_PATTERN_FEAR_INTO_POLY = "UI_ARCADE_DANGER",
    CALL_PATTERN_HUNTER_TRAP_SCATTER = "UI_ARCADE_DANGER",
    CALL_PATTERN_HOJ_INTO_INTERCEPT = "UI_ARCADE_DANGER",
}

local function hasCallout(recommendation, key)
    if not recommendation or not recommendation.callouts then return false end
    for _, callout in ipairs(recommendation.callouts) do
        if callout == key then return true end
    end
    return false
end

local function arcadeCueKey(recommendation, mode)
    if recommendation and (recommendation.burstAllowed or hasCallout(recommendation, "BURST_NOW")) then
        return "UI_ARCADE_BURST"
    end
    if recommendation and recommendation.callouts then
        for _, callout in ipairs(recommendation.callouts) do
            local key = arcadeCueByCallout[callout]
            if key then return key end
        end
    end
    if recommendation and recommendation.priority == "URGENT" then
        return "UI_ARCADE_DANGER"
    end
    return arcadeCueByMode[mode] or "UI_ARCADE_READY"
end

local function arcadeCueText(recommendation, mode)
    return string.format("!! %s !!", L(arcadeCueKey(recommendation, mode)))
end

-- v2.7.0: each callout key maps to a representative spell whose in-game
-- icon best illustrates the action. The HUD renders the icon inline via
-- WoW's |T<texture>:<size>|t escape so the user sees the *spell* to use,
-- not just the words. Mapping intentionally picks the spell the engine
-- expects the role to cast (HoJ for the paladin's incoming stun, Tremor
-- Totem for the shaman's fear cleanse, Bloodlust for the burst window).
-- When `GetSpellTexture` returns nil (very first call on an unknown
-- spell ID), the row degrades gracefully to "▸ <text>" without the icon.
UI.calloutIcons = {
    CALL_HOJ_KILL              = 10308,   -- Hammer of Justice
    CALL_TREMOR_FEAR           = 8143,    -- Tremor Totem
    CALL_SAVE_TREMOR_HOJ       = 8143,    -- Tremor Totem
    CALL_GROUND_POLY           = 8177,    -- Grounding Totem
    CALL_PURGE                 = 370,     -- Purge
    CALL_DISP_FROST            = 988,     -- Dispel Magic
    CALL_PAIN_SUP_READY        = 33206,   -- Pain Suppression
    CALL_BOP_READY             = 10278,   -- Blessing of Protection
    CALL_PEEL_DRUID            = 33786,   -- Cyclone
    CALL_PEEL_PRIEST           = 10890,   -- Psychic Scream
    CALL_LOW_MANA_PUSH         = 10876,   -- Mana Burn
    CALL_BURST_BLOCK_INCOMING  = 27619,   -- Ice Block (warn icon)
    CALL_FAKE_KICK_2           = 27090,   -- Counterspell
    CALL_FLAG_CARRIER_LOW      = 23335,   -- Warsong Flag (warning)
    CALL_INCOMING_PLAYERS      = 22751,   -- Generic PvP warning
    CALL_BASE_UNDER_ATTACK     = 22751,
    CALL_BG_DEFEND             = 642,     -- Divine Shield
    CALL_BG_RES_TIMER          = 22751,
    CALL_HEALER_CC             = 605,     -- Mind Control
    CALL_CYCLONE_OFF           = 33786,   -- Cyclone
    CALL_FEAR_KILL             = 10890,   -- Psychic Scream
    CALL_MANA_BURN             = 10876,   -- Mana Burn
    BURST_NOW                  = 2825,    -- Bloodlust / Heroism
    -- v2.7.1: outnumbered warning. Aspect of the Cheetah icon (5118)
    -- reads as "run away" — a natural disengage signal.
    CALL_OUTNUMBERED_DISENGAGE = 5118,
}

-- v2.7.0: render an inline icon for a callout key. Falls back to the
-- bullet sigil when the texture isn't resolvable (headless tests or
-- unknown spell IDs).
local function calloutIcon(key, size)
    size = size or 16
    local spellID = UI.calloutIcons and UI.calloutIcons[key]
    if not spellID then return "▸" end
    if type(GetSpellTexture) ~= "function" then return "▸" end
    local tex = GetSpellTexture(spellID)
    if not tex or tex == "" then return "▸" end
    return string.format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t", tex, size, size)
end

local calloutText

local function formatPlayerActions(actions, scaffold)
    if not actions or #actions == 0 then
        return scaffold and waitingAssignmentText() or ""
    end
    local lines = { "|cffc8a86b" .. L("UI_ACTIONS_HEADER") .. "|r" }
    local verbose = (ArenaCoachTBCDB and ArenaCoachTBCDB.frame
                     and ArenaCoachTBCDB.frame.verbose) or false
    local maxLines = verbose and VERBOSE_ACTION_LINES or DEFAULT_ACTION_LINES
    for i = 1, math.min(#actions, maxLines) do
        local a = actions[i]
        local who = a.name or a.unit or a.class or "?"
        local text = a.text or (a.actionKey and L(a.actionKey)) or a.actionKey or "?"
        local target = a.targetName or a.targetClass
        if target and target ~= "" then
            text = text .. " -> " .. target
        end
        table.insert(lines, string.format("%s: %s", who, text))
    end
    return table.concat(lines, "\n")
end

local function pct(value)
    if not value then return nil end
    local n = tonumber(value)
    if not n then return nil end
    if n <= 1 then n = n * 100 end
    return math.floor(n + 0.5)
end

local function lowestFriendly(state)
    local best
    for _, friendly in pairs((state and state.friendlies) or {}) do
        if friendly and friendly.alive ~= false then
            local hp = pct(friendly.healthPct or friendly.hpPct)
            if hp and (not best or hp < best.hp) then
                best = {
                    hp = hp,
                    name = friendly.name or friendly.unit or friendly.class or "?",
                }
            end
        end
    end
    return best
end

local function formatUnitStrip(recommendation, scaffold)
    if not recommendation then return scaffold and waitingUnitText() or "" end
    local lines = {}
    local mode = recommendation.mode or "RESET"
    local showTarget = (mode == "OPEN" or mode == "KILL" or mode == "SWAP")
    local target = recommendation.primaryTargetName
                or recommendation.primaryTargetClass
                or nil
    local targetLine
    if showTarget and target and target ~= "" then
        local hp = pct(recommendation.primaryTargetHp)
        local suffix = hp and string.format(" %d%%", hp) or ""
        targetLine = string.format("%s: %s%s", L(mode), target, suffix)
    end
    local secondary = recommendation.secondaryTargetName
                   or recommendation.secondaryTargetClass
                   or nil
    local secondaryLine
    if secondary and secondary ~= "" and secondary ~= target then
        secondaryLine = string.format("%s: %s", L("SWAP"), secondary)
    end
    local low = lowestFriendly(ns.Core and ns.Core.state)
    local teamLine
    if low then
        teamLine = string.format("%s: %s %d%%", L("UI_MODULE_TEAM"), low.name, low.hp)
    end
    if scaffold then
        table.insert(lines, targetLine or waitingLine("UI_MODULE_TARGET"))
        table.insert(lines, secondaryLine or waitingLine("UI_MODULE_SWAP"))
        table.insert(lines, teamLine or waitingLine("UI_MODULE_TEAM"))
    else
        if targetLine then table.insert(lines, targetLine) end
        if secondaryLine then table.insert(lines, secondaryLine) end
        if teamLine then table.insert(lines, teamLine) end
    end
    if #lines == 0 then return "" end
    table.insert(lines, 1, moduleHeader("UI_MODULE_FOCUS"))
    return table.concat(lines, "\n")
end

local function formatCueRail(recommendation, scaffold)
    if not recommendation then return scaffold and waitingCueText() or "" end
    local lines = {}
    if recommendation.burstAllowed and recommendation.mode == "KILL" then
        table.insert(lines, "★ " .. L("UI_BURST_READY"))
    end
    local verbose = (ArenaCoachTBCDB and ArenaCoachTBCDB.frame
                     and ArenaCoachTBCDB.frame.verbose) or false
    local maxLines = verbose and VERBOSE_ACTION_LINES or DEFAULT_ACTION_LINES
    if recommendation.callouts then
        for i = 1, math.min(#recommendation.callouts, maxLines) do
            local key = recommendation.callouts[i]
            table.insert(lines,
                string.format("%s  %s", calloutIcon(key, 14), calloutText(key, recommendation)))
        end
    end
    if #lines == 0 then
        return scaffold and waitingCueText() or ""
    end
    table.insert(lines, 1, moduleHeader("UI_MODULE_CUES"))
    return table.concat(lines, "\n")
end

local function setModuleText(frame, fieldName, text, shownFlag)
    if not frame then return end
    local fs = frame[fieldName or "text"]
    if fs then fs:SetText(text or "") end
    frame[shownFlag or "_hasContent"] = (text and text ~= "") or false
    if text and text ~= "" then
        if not frame:IsShown() then frame:Show() end
    else
        frame:Hide()
    end
end

local function setFontStringText(fs, text)
    if fs then fs:SetText(text or "") end
end

local function detachedModulesEnabled()
    return ArenaCoachTBCDB and ArenaCoachTBCDB.frame
       and ArenaCoachTBCDB.frame.detachedModules == true
end

function UI:_SetFrameAlpha(alpha)
    local frames = { self.frame, self.unitFrame, self.railFrame, self.assignFrame }
    for i = 1, 4 do
        local f = frames[i]
        if f then
            f._accAlpha = alpha
            if f.SetAlpha then f:SetAlpha(alpha) end
        end
    end
end

function UI:_ShouldStaleFade(recommendation, mode)
    local phase = ns.Core and ns.Core.state and ns.Core.state.combatPhase
    if mode == "OPEN" and phase == "PRE" and not recommendation._forceShow then
        return false
    end
    return true
end

function UI:_ResetStaleFade(active)
    self._staleElapsed = 0
    self._staleFadeActive = (active ~= false)
    self:_SetFrameAlpha(1)
end

function UI:_HideStaleFrame()
    if self.frame then
        self:_SetFrameAlpha(0)
        self.frame:Hide()
    end
    if self.unitFrame then self.unitFrame:Hide() end
    if self.railFrame then self.railFrame:Hide() end
    if self.assignFrame then self.assignFrame:Hide() end
    self._staleFadeActive = false
    if ns.ScreenEdgeGlow then ns.ScreenEdgeGlow:Hide() end
    if ns.Nameplate then ns.Nameplate:ClearAll() end
end

function UI:_UpdateStaleFade(dt)
    if not (self.frame and self._staleFadeActive and self.frame:IsShown()) then return end
    self._staleElapsed = (self._staleElapsed or 0) + (dt or 0)
    local age = self._staleElapsed
    if age <= STALE_FADE_START then return end

    local t = (age - STALE_FADE_START) / STALE_FADE_SECONDS
    if t >= 1 then
        self:_HideStaleFrame()
        return
    end
    self:_SetFrameAlpha(1 - t)
end

function calloutText(key, recommendation)
    local text = L(key)
    if key == "CALL_PURGE" then
        local target = recommendation
            and (recommendation.primaryTargetName or recommendation.primaryTargetClass)
            or nil
        target = target or L("UI_TARGET_FALLBACK")
        local ok, formatted = pcall(string.format, text, target)
        if ok then return formatted end
    end
    return (text:gsub("%%s", L("UI_TARGET_FALLBACK")))
end

function UI:Show()
    if self.frame then self.frame:Show() end
    if self.unitFrame and self.unitFrame._hasUnits then self.unitFrame:Show() end
    if self.railFrame and self.railFrame._hasCues then self.railFrame:Show() end
    if self.assignFrame and self.assignFrame._hasAssignments then self.assignFrame:Show() end
end
function UI:Hide()
    if self.frame then self.frame:Hide() end
    if self.unitFrame then self.unitFrame:Hide() end
    if self.railFrame then self.railFrame:Hide() end
    if self.assignFrame then self.assignFrame:Hide() end
end
function UI:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function UI:Apply(recommendation)
    local f = self.frame; if not f or not recommendation then return end

    -- v2.2.5: hide the frame + visual layers when explicitly idle
    -- (in cities / quest hubs the engine was painting a stale rec and
    -- the nameplate handler was thrashing on every nameplate change).
    -- We hide only on the *explicit* idle contexts — `none` (no PvP
    -- relevance at all) and `world_idle` (PvP-flagged but no hostile
    -- contact). When context is nil (early-load before Core publishes
    -- state, or headless test) we let the rec through, which keeps
    -- tests + the bootstrap path working.
    local ctx = ns.Core and ns.Core.state and ns.Core.state.pvpContext
    local forceShow = recommendation._forceShow   -- set by /acc test demo
    if (ctx == "none" or ctx == "world_idle") and not forceShow then
        f:Hide()
        if self.unitFrame then self.unitFrame:Hide() end
        if self.railFrame then self.railFrame:Hide() end
        if self.assignFrame then self.assignFrame:Hide() end
        if ns.ScreenEdgeGlow then ns.ScreenEdgeGlow:Hide() end
        if ns.Nameplate then ns.Nameplate:ClearAll() end
        return
    end
    if not f:IsShown() then f:Show() end
    if not self.unitFrame and self.CreateUnitStripFrame then self:CreateUnitStripFrame() end
    if not self.railFrame and self.CreateCueRailFrame then self:CreateCueRailFrame() end
    if not self.assignFrame and self.CreateAssignmentsFrame then self:CreateAssignmentsFrame() end

    local mode = recommendation.mode or "RESET"
    self:_ResetStaleFade(self:_ShouldStaleFade(recommendation, mode))
    -- v2.5.0: high-contrast skin. The default modeColors palette is
    -- tuned for visual coherence (slightly desaturated, easy on the
    -- eyes); the high-contrast palette pushes every channel to the
    -- extreme so the label is readable through glare,
    -- and small-screen / poor-eyesight setups. Toggle via
    -- `/acc highcontrast on|off` (db.frame.highContrast).
    local highContrast = (ArenaCoachTBCDB and ArenaCoachTBCDB.frame
                          and ArenaCoachTBCDB.frame.highContrast) or false
    local palette = highContrast and modeColorsHighContrast or modeColors
    local color = palette[mode] or {1, 1, 1}
    local label = L(mode)
    local target = recommendation.primaryTargetName
                or recommendation.primaryTargetClass
                or ""

    if f.arcadeText then
        f.arcadeText:SetTextColor(color[1], color[2], color[3])
        f.arcadeText:SetText(arcadeCueText(recommendation, mode))
    end

    f.bigText:SetTextColor(color[1], color[2], color[3])
    -- v2.1.3: DEFEND and RESET are not target-attached modes. Showing
    -- "DEFEND: SomeEnemy" reads as "defend against SomeEnemy" which is
    -- the opposite of the intent (defensive abilities on YOUR team).
    -- Only OPEN / KILL / SWAP get the "<mode>: <name>" form.
    local showTarget = (mode == "OPEN" or mode == "KILL" or mode == "SWAP")
    if showTarget and target and target ~= "" then
        f.bigText:SetText(string.format("%s: %s", label, target))
    else
        f.bigText:SetText(label)
    end

    -- v2.1.6: target stats row. We surface what the engine knows about
    -- the primary kill target so a glance at the HUD tells the player
    -- "how close is he to dead".
    --
    -- v2.6.0: each segment is now colour-coded inline via WoW colour
    -- escapes so the eye picks out the action-relevant value (high HP
    -- = green/yellow/red kill prob, BURST READY = gold). Pre-v2.6 the
    -- whole line was one yellow-ish blob that ran together.
    if f.statsText then
        local parts = {}
        local function tag(hex, body)
            return string.format("|cff%s%s|r", hex, body)
        end
        if showTarget and recommendation.primaryTargetHp then
            local hp = math.floor((recommendation.primaryTargetHp * 100) + 0.5)
            -- HP rendered in pure white — the neutral reference value
            -- the player calibrates the others against.
            table.insert(parts, tag("ffffff",
                string.format("%s %d%%", L("UI_HP_LABEL"), hp)))
        end
        if showTarget and recommendation.killProb then
            local kp = math.floor((recommendation.killProb * 100) + 0.5)
            -- Graded green / yellow / red so kill prob's "is this worth
            -- committing?" answer is pre-parsed for the eye.
            local hex
            if kp >= 60 then hex = "66ff66"       -- bright green
            elseif kp >= 30 then hex = "ffd166"   -- amber
            else hex = "ff6464" end                -- red
            table.insert(parts, tag(hex,
                string.format("%s %d%%", L("UI_KILL_PROB_LABEL"), kp)))
        end
        if recommendation.burstAllowed and mode == "KILL" then
            -- Gold + a leading sigil so BURST READY pops as the most
            -- attention-grabbing element on the line. (Pre-v2.6 it was
            -- the same color as the surrounding text.)
            table.insert(parts, tag("ffd24a", "★ " .. L("UI_BURST_READY")))
        end
        -- Wider " · " separator + leading/trailing space so segments
        -- breathe instead of running together.
        f.statsText:SetText(table.concat(parts, "  ·  "))
    end

    local subParts = {}
    local verbose = (ArenaCoachTBCDB and ArenaCoachTBCDB.frame
                     and ArenaCoachTBCDB.frame.verbose) or false

    -- v2.1.3: prefer the localized reasonKey when set (DEFEND / RESET
    -- modes have stable reason codes).
    if recommendation.reasonKey then
        table.insert(subParts, L(recommendation.reasonKey))
    end

    -- v2.4.0 Quiet HUD: show ONLY the top callout in non-verbose mode.
    -- Pre-v2.4 we concatenated every callout with " | " separators,
    -- producing 3-callout strings the user couldn't parse at a glance
    -- mid-fight. The remaining callouts are still on the recommendation
    -- object — power users see them via `/acc trace dump` or the
    -- WeakAura bridge. Verbose mode (set via `/acc verbose on`) keeps
    -- the full list for diagnostic reviews.
    if recommendation.callouts and #recommendation.callouts > 0 then
        -- v2.5.0: per-callout cooldown. If the same callout key was shown
        -- inside the last 3 s, suppress it. Stops the "same text every
        -- 0.5 s" pattern when engine state oscillates around a threshold
        -- (e.g. enemy HP bouncing across the 50% line). Sound cues are
        -- already mode-gated; this gate applies to the on-screen text.
        local nowTs = (type(GetTime) == "function") and GetTime() or 0
        self._calloutLastShown = self._calloutLastShown or {}
        local function recentlyShown(key)
            local t = self._calloutLastShown[key]
            return t and (nowTs - t) < 3
        end

        if verbose then
            -- v2.7.0: each callout renders as `<icon>  <text>` on its
            -- own line, so the verbose mode reads as an action list
            -- instead of a pipe-separated text blob.
            for _, key in ipairs(recommendation.callouts) do
                if not recentlyShown(key) then
                    table.insert(subParts,
                        string.format("%s  %s", calloutIcon(key, 18), calloutText(key, recommendation)))
                    self._calloutLastShown[key] = nowTs
                end
            end
        else
            -- Default: just the top one with its icon prefix. BURST_NOW
            -- (v2.4.0 locale fix) is properly translated; v2.7.0 also
            -- shows the Bloodlust icon next to it.
            local top = recommendation.callouts[1]
            if not recentlyShown(top) then
                table.insert(subParts,
                    string.format("%s  %s", calloutIcon(top, 18), calloutText(top, recommendation)))
                self._calloutLastShown[top] = nowTs
            end
        end
    end

    -- v2.4.0: comp badge only in verbose mode. The big colour-coded
    -- mode label + target name + arcade cue + nameplate already tell the
    -- user what's happening; the comp identity is post-match analysis.
    if verbose and recommendation.comp then
        local badgeKey = recommendation.compSpecConfirmed
            and "COMP_BADGE_SPEC_CONFIRMED"
            or "COMP_BADGE_CLASS_GUESSED"
        local label = recommendation.compLabel
        if not label or label == "" then label = "?" end
        table.insert(subParts, string.format("%s (%s)", label, L(badgeKey)))
    end

    -- v2.4.0: chain narration to chat fires only once per chain change.
    -- That was correct pre-v2.4 and stays. The narration is useful
    -- regardless of verbose mode — it lands in chat, not on the HUD.
    if recommendation.chain and recommendation.chain.id ~= self._lastChainId then
        self._lastChainId = recommendation.chain.id
        local ch = recommendation.chain
        local title = (ch.labelKey and L(ch.labelKey)) or ch.label or ch.id or ""
        print(string.format("[ACC] %s: %s (%d%%)",
            L("CHAIN_PICKED_PREFIX"), title,
            math.floor(((ch.expectedProb or 0) * 100) + 0.5)))
    end

    -- v2.4.0: chain title + steps render on the HUD only in verbose
    -- mode. Default-mode users see the chain via the chat narration
    -- above (fires once per change) and don't get a wall of step lines
    -- cluttering the frame mid-fight.
    if verbose and recommendation.chain then
        local ch = recommendation.chain
        local title = (ch.labelKey and L(ch.labelKey)) or ch.label or ch.id or ""
        local pct = math.floor(((ch.expectedProb or 0) * 100) + 0.5)
        table.insert(subParts,
            string.format("%s: %s (%d%%)", L("CHAIN_PICKED_PREFIX"), title, pct))
        if ch.links then
            for i, link in ipairs(ch.links) do
                local spellName
                if type(GetSpellInfo) == "function" then
                    spellName = GetSpellInfo(link.spellID)
                end
                local label = spellName or tostring(link.category or "?")
                local stepText = string.format("  %s %d. %s",
                    L("CHAIN_STEP_PREFIX"), i, label)
                table.insert(subParts, stepText)
            end
        end
    end
    f.subText:SetText(table.concat(subParts, "\n"))
    local scaffold = layoutScaffoldActive(recommendation)
    local integratedUnitText = formatUnitStrip(recommendation, true)
    local integratedRailText = formatCueRail(recommendation, true)
    local integratedAssignText = formatPlayerActions(recommendation.playerActions, true)
    setFontStringText(f.unitText, integratedUnitText)
    setFontStringText(f.railText, integratedRailText)
    setFontStringText(f.assignText, integratedAssignText)

    if detachedModulesEnabled() then
        setModuleText(self.unitFrame, "text", formatUnitStrip(recommendation, scaffold), "_hasUnits")
        setModuleText(self.railFrame, "text", formatCueRail(recommendation, scaffold), "_hasCues")
        setModuleText(self.assignFrame, "actionText", formatPlayerActions(recommendation.playerActions, scaffold), "_hasAssignments")
    else
        setModuleText(self.unitFrame, "text", "", "_hasUnits")
        setModuleText(self.railFrame, "text", "", "_hasCues")
        setModuleText(self.assignFrame, "actionText", "", "_hasAssignments")
    end

    -- v2.0.2 / v2.1: PvP-context gate. The aggressive alerts (screen
    -- flash, voice cue) should only fire in actual arena. Outside
    -- arena (BG, world PvP, idle) the engine may still emit DEFEND-
    -- like recommendations (legitimate in BG when a healer is being
    -- focused), but the intrusive feedback should not.
    --
    -- v2.1: prefer the unified Core.state.pvpContext when available;
    -- fall back to IsActiveBattlefieldArena for the early-load path
    -- before Core has populated state. Missing both APIs → headless
    -- test → permissive (true).
    local ctx = ns.Core and ns.Core.state and ns.Core.state.pvpContext
    local inArena
    if ctx then
        inArena = (ctx == "arena")
    else
        inArena = (type(IsActiveBattlefieldArena) ~= "function")
                  or IsActiveBattlefieldArena()
    end

    -- v2.7.5: no automatic full-screen flash. The frame, sound cue,
    -- nameplate highlight, and optional thin edge cue carry urgency without
    -- strobing over the playfield during a real arena run. `_Flash`
    -- remains below as an isolated helper for legacy/debug coverage, but
    -- recommendations no longer call it.

    -- M12 #77: voice callouts. Fire one sound per *new* top callout.
    -- Arena-gated for the same reason — BG combat noise produces
    -- repeated cues that aren't actionable.
    if inArena and ns.Sounds and recommendation.callouts and #recommendation.callouts > 0
       and ArenaCoachTBCDB and ArenaCoachTBCDB.alerts
       and ArenaCoachTBCDB.alerts.sound then
        local top = recommendation.callouts[1]
        if top ~= self._lastVoiceCallout then
            ns.Sounds:Play(top)
            self._lastVoiceCallout = top
        end
    end

    -- v2.1.6: mode-transition cue. Plays a distinct sound when the
    -- recommended mode flips (KILL/SWAP/DEFEND/OPEN) so the user gets
    -- an auditory ping even if they aren't looking at the frame. Same
    -- alerts.sound gate as the per-callout cues; arena-gated for the
    -- same noise-floor reason. Unlike callout cues, this is keyed on
    -- the mode itself so it fires once per transition, not on every
    -- evaluation.
    if inArena and ns.Sounds and ns.Sounds.PlayMode
       and ArenaCoachTBCDB and ArenaCoachTBCDB.alerts
       and ArenaCoachTBCDB.alerts.sound
       and mode ~= self._lastModeForSound then
        ns.Sounds:PlayMode(mode)
        self._lastModeForSound = mode
    end

    -- v2.2.0: peripheral-vision visual layers. Both gate on PvP
    -- context — outside actual combat (idle world) the constant glow /
    -- nameplate paint would be distracting noise.
    --
    -- v2.3.0: `forceShow` also bypasses the inPvP gate so /acc test
    -- can demo the prototype-A modules (text + glow + nameplate) without being
    -- in arena/BG/world. Pre-v2.3.0 the demo only painted the text.
    --
    -- edgeGlow: optional thin static mode-coloured cue around the edges.
    -- nameplate: paint the kill / swap target's nameplate border so
    -- the player can identify them in a fight with multiple enemies.
    local alerts = ArenaCoachTBCDB and ArenaCoachTBCDB.alerts or nil
    local inPvP  = inArena or (ctx == "bg") or (ctx == "world")
    local showVisualLayers = inPvP or forceShow
    if ns.ScreenEdgeGlow then
        if showVisualLayers and alerts and alerts.edgeGlow then
            ns.ScreenEdgeGlow:SetMode(mode)
        else
            ns.ScreenEdgeGlow:Hide()
        end
    end
    if ns.Nameplate then
        if showVisualLayers and alerts and alerts.nameplate then
            ns.Nameplate:Apply(recommendation)
        else
            ns.Nameplate:ClearAll()
        end
    end
end

-- Subtle screen-edge flash: an overlay frame that fades out
function UI:_Flash()
    if type(CreateFrame) ~= "function" then return end
    local fr = self._flash
    if not fr then
        fr = CreateFrame("Frame", nil, UIParent)
        fr:SetAllPoints(UIParent)
        fr:EnableMouse(false)
        fr.tex = fr:CreateTexture(nil, "BACKGROUND")
        fr.tex:SetAllPoints(true)
        fr.tex:SetColorTexture(1, 0.2, 0.2, 0.3)
        self._flash = fr
    end
    fr:SetAlpha(0.6)
    fr:Show()
    if fr.SetScript then
        fr.elapsed = 0
        fr:SetScript("OnUpdate", function(self, e)
            self.elapsed = (self.elapsed or 0) + e
            local a = math.max(0, 0.6 - self.elapsed * 2)
            self:SetAlpha(a)
            if a <= 0 then self:Hide(); self:SetScript("OnUpdate", nil) end
        end)
    end
end

-- v2.2.1: UpdateIcons + friendlyIconMap / enemyIconMap removed. The icon
-- rows had been displayed since v1 but no production code ever called
-- UpdateIcons, so the icons sat at their initial 0.4 alpha forever and
-- communicated nothing. Stripped along with the underlying frame rows.
