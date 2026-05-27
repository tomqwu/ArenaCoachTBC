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

local ADDON_VERSION = "2.8.29"
local STALE_FADE_START = 2.5
local STALE_FADE_SECONDS = 1.5
local COMPACT_WIDTH = 540
local COMPACT_HEIGHT = 212
local MIN_COMPACT_WIDTH = 500
local MIN_COMPACT_HEIGHT = 196
local MAX_COMPACT_WIDTH = 820
local MAX_COMPACT_HEIGHT = 360
local GRID_PADDING = 8
local PANEL_GUTTER = 8
local BOARD_BOTTOM_PADDING = 8
local HEADER_HEIGHT = 24
local GRID_TOP_Y = -32
local ASSIGN_PANEL_HEIGHT = 52
local RESIZE_GRIP_SIZE = 16
local UNIT_WIDTH = 150
local UNIT_HEIGHT = 96
local RAIL_WIDTH = 150
local RAIL_HEIGHT = 118
local ASSIGN_WIDTH = 300
local ASSIGN_HEIGHT = 76
local DEFAULT_ACTION_LINES = 3
local VERBOSE_ACTION_LINES = 5
local OBSIDIAN_R, OBSIDIAN_G, OBSIDIAN_B = 0.018, 0.015, 0.011
local OBSIDIAN_WARM_R, OBSIDIAN_WARM_G, OBSIDIAN_WARM_B = 0.070, 0.052, 0.030
local BRASS_R, BRASS_G, BRASS_B = 0.78, 0.62, 0.34
local BRASS_DIM_R, BRASS_DIM_G, BRASS_DIM_B = 0.45, 0.35, 0.18
local CYAN_R, CYAN_G, CYAN_B = 0.34, 0.78, 0.86
local BONE_R, BONE_G, BONE_B = 0.86, 0.82, 0.70
local CRIMSON_R, CRIMSON_G, CRIMSON_B = 0.86, 0.20, 0.23

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
    frame:SetBackdropColor(OBSIDIAN_R, OBSIDIAN_G, OBSIDIAN_B, alpha or 0.30)
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

local function height(region, h)
    if region and region.SetHeight then pcall(region.SetHeight, region, h) end
end

local function clamp(value, minValue, maxValue)
    local n = tonumber(value) or minValue
    if n < minValue then return minValue end
    if n > maxValue then return maxValue end
    return n
end

local function rounded(value)
    return math.floor((tonumber(value) or 0) + 0.5)
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
    colorTexture(frame._accBg, OBSIDIAN_R, OBSIDIAN_G, OBSIDIAN_B, alpha or 0.44)

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
        colorTexture(tex, BRASS_R, BRASS_G, BRASS_B, border)
    end
end

local function improveTextContrast(fs, alpha, x, y)
    if not fs then return end
    if fs.SetShadowColor then pcall(fs.SetShadowColor, fs, 0, 0, 0, alpha or 0.95) end
    if fs.SetShadowOffset then pcall(fs.SetShadowOffset, fs, x or 1, y or -1) end
end

local function solidTexture(parent, key, layer, r, g, b, a)
    if not (parent and parent.CreateTexture) then return nil end
    local tex = parent[key] or parent:CreateTexture(nil, layer or "BACKGROUND")
    parent[key] = tex
    colorTexture(tex, r, g, b, a)
    return tex
end

local function placeLine(parent, key, w, h, x, y, alpha)
    local tex = solidTexture(parent, key, "ARTWORK", BRASS_R, BRASS_G, BRASS_B, alpha or 0.68)
    if not tex then return nil end
    clearPoints(tex)
    size(tex, w, h)
    point(tex, "TOPLEFT", parent, "TOPLEFT", x, y)
    return tex
end

local function placeSlot(parent, key, w, h, x, y, alpha)
    local tex = solidTexture(parent, key, "BACKGROUND", OBSIDIAN_WARM_R, OBSIDIAN_WARM_G, OBSIDIAN_WARM_B, alpha or 0.16)
    if not tex then return nil end
    clearPoints(tex)
    size(tex, w, h)
    point(tex, "TOPLEFT", parent, "TOPLEFT", x, y)
    return tex
end

local function layoutPanelSlots(panel, prefix, rows, topOffset)
    if not (panel and panel.GetWidth and panel.GetHeight) then return end
    local w = math.max(20, (panel:GetWidth() or 0) - 12)
    local h = math.max(20, (panel:GetHeight() or 0) - (topOffset or 24) - 8)
    local rowH = math.max(12, math.floor(h / rows))
    local y = -(topOffset or 24)
    for i = 1, rows do
        placeSlot(panel, prefix .. "Slot" .. i, w, math.max(10, rowH - 2), 6, y, 0.13)
        y = y - rowH
    end
end

local function layoutAssignmentSlots(frame, slots)
    if not (frame and frame.assignPanel and frame.assignPanel.GetWidth and frame.assignPanel.GetHeight) then return end
    local panel = frame.assignPanel
    slots = clamp(slots or 3, 1, VERBOSE_ACTION_LINES)
    if slots == 4 then slots = 5 end

    local w = panel:GetWidth() or 0
    local h = panel:GetHeight() or 0
    local headerH = 18
    local gap = 4
    local innerX = 6
    local innerW = math.max(20, w - (innerX * 2))
    local cardH = math.max(20, h - headerH - 9)
    local cardY = -(headerH + 4)
    local cardW = math.max(20, math.floor((innerW - (gap * (slots - 1))) / slots))

    frame._accAssignSlots = slots
    for i = 1, VERBOSE_ACTION_LINES do
        local bg = panel["assignCard" .. i] or panel:CreateTexture(nil, "BACKGROUND")
        panel["assignCard" .. i] = bg
        local text = frame.assignSlotTexts and frame.assignSlotTexts[i]
        if i <= slots then
            local x = innerX + ((i - 1) * (cardW + gap))
            clearPoints(bg)
            size(bg, cardW, cardH)
            point(bg, "TOPLEFT", panel, "TOPLEFT", x, cardY)
            colorTexture(bg, OBSIDIAN_WARM_R, OBSIDIAN_WARM_G, OBSIDIAN_WARM_B, 0.42)
            if bg.Show then bg:Show() end
            if text then
                clearPoints(text)
                point(text, "TOPLEFT", panel, "TOPLEFT", x + 4, cardY - 4)
                if text.SetWidth then pcall(text.SetWidth, text, math.max(20, cardW - 8)) end
                if text.SetHeight then pcall(text.SetHeight, text, math.max(10, cardH - 6)) end
                if text.Show then text:Show() end
            end
        else
            if bg.Hide then bg:Hide() end
            if text and text.Hide then text:Hide() end
        end
    end
end

local function layoutCornerReticles(frame, width, height)
    if not frame then return end
    local len = 12
    local inset = 5
    local rightX = math.max(inset, width - inset - len)
    local bottomY = -math.max(inset, height - inset)
    local bottomVY = -math.max(inset, height - inset - len)
    placeLine(frame, "reticleTLH", len, 1, inset, -inset, 0.78)
    placeLine(frame, "reticleTLV", 1, len, inset, -inset, 0.78)
    placeLine(frame, "reticleTRH", len, 1, rightX, -inset, 0.78)
    placeLine(frame, "reticleTRV", 1, len, width - inset, -inset, 0.78)
    placeLine(frame, "reticleBLH", len, 1, inset, bottomY, 0.78)
    placeLine(frame, "reticleBLV", 1, len, inset, bottomVY, 0.78)
    placeLine(frame, "reticleBRH", len, 1, rightX, bottomY, 0.78)
    placeLine(frame, "reticleBRV", 1, len, width - inset, bottomVY, 0.78)
end

local function layoutRulers(frame, width, height)
    if not frame then return end
    local count = 14
    local usable = math.max(80, width - (GRID_PADDING * 2))
    local step = usable / (count + 1)
    for i = 1, count do
        local x = GRID_PADDING + math.floor(step * i)
        local h = (i % 3 == 0) and 8 or 4
        placeLine(frame, "topTick" .. i, 1, h, x, -HEADER_HEIGHT - 4, 0.58)
        placeLine(frame, "bottomTick" .. i, 1, h, x, -(height - 9), 0.50)
    end
end

local function consoleHeader(titleKey, subtitle, index)
    local idx = index and ("  |cff5f5131// " .. index .. "|r") or ""
    return string.format("|cffddd2ad%s|r  |cff9b7a3d%s|r%s", L(titleKey), subtitle or "", idx)
end

local function consoleTag(label, hex)
    return string.format("|cff%s[%s]|r", hex or "c8a86b", label or "?")
end

local function createChildPanel(parent, key, width, height, pointA, relativePoint, x, y, alpha)
    if not (parent and type(CreateFrame) == "function") then return nil end
    local panel = parent[key] or CreateFrame("Frame", nil, parent)
    parent[key] = panel
    panel:SetSize(width, height)
    panel:ClearAllPoints()
    panel:SetPoint(pointA, parent, relativePoint or pointA, x or 0, y or 0)
    if panel.EnableMouse then panel:EnableMouse(false) end
    skinPanel(panel, alpha or 0.36, 0.54)
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

local function addonEnabled()
    return not (ArenaCoachTBCDB and ArenaCoachTBCDB.enabled == false)
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
    if key == "frame" and frame.GetWidth and frame.GetHeight then
        local width = frame:GetWidth()
        local height = frame:GetHeight()
        if width and height then
            ArenaCoachTBCDB[key].width = clamp(rounded(width), MIN_COMPACT_WIDTH, MAX_COMPACT_WIDTH)
            ArenaCoachTBCDB[key].height = clamp(rounded(height), MIN_COMPACT_HEIGHT, MAX_COMPACT_HEIGHT)
        end
    end
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

local function boardMetrics(frame)
    local width = clamp((frame and frame.GetWidth and frame:GetWidth()) or COMPACT_WIDTH,
        MIN_COMPACT_WIDTH, MAX_COMPACT_WIDTH)
    local height = clamp((frame and frame.GetHeight and frame:GetHeight()) or COMPACT_HEIGHT,
        MIN_COMPACT_HEIGHT, MAX_COMPACT_HEIGHT)
    local contentW = math.max(0, width - (GRID_PADDING * 2))
    local bodyY = GRID_TOP_Y
    local bodyH = math.max(112, height - math.abs(bodyY) - BOARD_BOTTOM_PADDING)
    local leftW = clamp(math.floor(contentW * 0.25), 120, 176)
    local rightW = clamp(math.floor(contentW * 0.22), 104, 160)
    local centerW = contentW - leftW - rightW - (PANEL_GUTTER * 2)
    if centerW < 178 then
        centerW = 178
        local remaining = math.max(0, contentW - centerW - (PANEL_GUTTER * 2))
        leftW = clamp(math.floor(remaining * 0.55), 112, 160)
        rightW = math.max(96, remaining - leftW)
    end

    local leftX = GRID_PADDING
    local centerX = leftX + leftW + PANEL_GUTTER
    local rightX = centerX + centerW + PANEL_GUTTER
    local assignH = clamp(math.floor(bodyH * 0.36), ASSIGN_PANEL_HEIGHT, 92)
    local actionH = math.max(70, bodyH - assignH - PANEL_GUTTER)
    local assignY = bodyY - actionH - PANEL_GUTTER
    local centerSubLines = (actionH >= 118 and 3) or (actionH >= 94 and 2) or 1
    local cueLines = clamp(math.floor((bodyH - 22) / 14), 2, VERBOSE_ACTION_LINES)
    local assignLines = clamp(math.floor((assignH - 15) / 11), 2, VERBOSE_ACTION_LINES)

    return {
        width = width,
        height = height,
        contentW = contentW,
        topY = bodyY,
        bodyY = bodyY,
        bodyH = bodyH,
        leftX = leftX,
        centerX = centerX,
        rightX = rightX,
        assignY = assignY,
        topH = actionH,
        actionH = actionH,
        leftW = leftW,
        rightW = rightW,
        centerW = centerW,
        assignH = assignH,
        centerSubLines = centerSubLines,
        cueLines = cueLines,
        assignLines = assignLines,
    }
end

local function layoutMainBoard(f)
    if not f then return end
    local m = boardMetrics(f)

    if f.dragBar then
        clearPoints(f.dragBar)
        point(f.dragBar, "TOPLEFT", f, "TOPLEFT", 2, -2)
        point(f.dragBar, "TOPRIGHT", f, "TOPRIGHT", -2, -2)
        if f.dragBar.SetHeight then pcall(f.dragBar.SetHeight, f.dragBar, HEADER_HEIGHT) end
    end
    if f.versionText and f.versionText.SetWidth then
        pcall(f.versionText.SetWidth, f.versionText, math.max(58, math.min(86, m.width - 240)))
    end
    if f.title and f.title.SetWidth then
        pcall(f.title.SetWidth, f.title, math.max(120, m.width - 190))
    end
    if f.metaText and f.metaText.SetWidth then
        pcall(f.metaText.SetWidth, f.metaText, math.max(120, m.width - 260))
    end
    layoutRulers(f, m.width, m.height)
    layoutCornerReticles(f, m.width, m.height)

    if f.leftPanel then
        clearPoints(f.leftPanel)
        size(f.leftPanel, m.leftW, m.actionH)
        point(f.leftPanel, "TOPLEFT", f, "TOPLEFT", m.leftX, m.topY)
        layoutPanelSlots(f.leftPanel, "left", 4, 26)
    end
    if f.centerPanel then
        clearPoints(f.centerPanel)
        size(f.centerPanel, m.centerW, m.actionH)
        point(f.centerPanel, "TOPLEFT", f, "TOPLEFT", m.centerX, m.topY)
    end
    if f.rightPanel then
        clearPoints(f.rightPanel)
        size(f.rightPanel, m.rightW, m.actionH)
        point(f.rightPanel, "TOPLEFT", f, "TOPLEFT", m.rightX, m.topY)
        layoutPanelSlots(f.rightPanel, "right", 4, 26)
    end
    if f.assignPanel then
        clearPoints(f.assignPanel)
        size(f.assignPanel, m.contentW, m.assignH)
        point(f.assignPanel, "TOPLEFT", f, "TOPLEFT", m.leftX, m.assignY)
        local activeSlots = rawget(f, "_accAssignSlots")
        if type(activeSlots) ~= "number" then activeSlots = 3 end
        layoutAssignmentSlots(f, activeSlots)
    end

    placeLine(f, "leftDivider", 1, m.actionH, m.centerX - math.floor(PANEL_GUTTER / 2), m.bodyY, 0.42)
    placeLine(f, "rightDivider", 1, m.actionH, m.rightX - math.floor(PANEL_GUTTER / 2), m.bodyY, 0.42)
    placeLine(f, "assignDivider", m.contentW, 1, m.leftX, m.assignY + 1, 0.58)

    if f.modeAccent then
        clearPoints(f.modeAccent)
        size(f.modeAccent, m.centerW - 8, 2)
        point(f.modeAccent, "TOP", f.centerPanel or f, "TOP", 0, -1)
    end
    if f.healthBarBg then
        clearPoints(f.healthBarBg)
        size(f.healthBarBg, math.max(80, m.centerW - 24), 8)
        point(f.healthBarBg, "BOTTOM", f.centerPanel or f, "BOTTOM", 0, 14)
        f._accHealthBarWidth = math.max(80, m.centerW - 24)
    end
    if f.healthBarFill then
        clearPoints(f.healthBarFill)
        size(f.healthBarFill, f._accHealthBarFillWidth or 1, 8)
        point(f.healthBarFill, "LEFT", f.healthBarBg or (f.centerPanel or f), "LEFT", 0, 0)
    end
    if f.healthLabel then
        clearPoints(f.healthLabel)
        point(f.healthLabel, "BOTTOM", f.healthBarBg or (f.centerPanel or f), "TOP", 0, 3)
        if f.healthLabel.SetWidth then pcall(f.healthLabel.SetWidth, f.healthLabel, math.max(80, m.centerW - 24)) end
    end

    local centerTextW = math.max(100, m.centerW - 10)
    if f.arcadeText then
        clearPoints(f.arcadeText)
        point(f.arcadeText, "TOP", f.centerPanel or f, "TOP", 0, -8)
        if f.arcadeText.SetWidth then pcall(f.arcadeText.SetWidth, f.arcadeText, centerTextW) end
        height(f.arcadeText, 14)
    end
    if f.bigText then
        clearPoints(f.bigText)
        point(f.bigText, "TOP", f.arcadeText or (f.centerPanel or f), f.arcadeText and "BOTTOM" or "TOP", 0, -6)
        if f.bigText.SetWidth then pcall(f.bigText.SetWidth, f.bigText, centerTextW) end
        height(f.bigText, 22)
    end
    if f.statsText then
        clearPoints(f.statsText)
        point(f.statsText, "TOP", f.bigText or (f.centerPanel or f), f.bigText and "BOTTOM" or "TOP", 0, -2)
        if f.statsText.SetWidth then pcall(f.statsText.SetWidth, f.statsText, centerTextW) end
        height(f.statsText, 14)
    end
    if f.subText then
        clearPoints(f.subText)
        point(f.subText, "TOP", f.statsText or (f.centerPanel or f), f.statsText and "BOTTOM" or "TOP", 0, -2)
        if f.subText.SetWidth then pcall(f.subText.SetWidth, f.subText, centerTextW) end
        height(f.subText, math.max(14, m.actionH - 88))
    end
    if f.unitText and f.unitText.SetWidth then pcall(f.unitText.SetWidth, f.unitText, math.max(76, m.leftW - 16)) end
    if f.railText and f.railText.SetWidth then pcall(f.railText.SetWidth, f.railText, math.max(76, m.rightW - 16)) end
    if f.assignText and f.assignText.SetWidth then pcall(f.assignText.SetWidth, f.assignText, math.max(120, m.contentW - 20)) end
    if f.assignHeader and f.assignHeader.SetWidth then pcall(f.assignHeader.SetWidth, f.assignHeader, math.max(120, m.contentW - 20)) end
    height(f.unitText, math.max(20, m.actionH - 12))
    height(f.railText, math.max(20, m.actionH - 12))
    height(f.assignText, math.max(20, m.assignH - 12))
    f._accCenterSubLines = m.centerSubLines
    f._accCueLines = m.cueLines
    f._accAssignLines = m.assignLines

    if f.resizeGrip then
        clearPoints(f.resizeGrip)
        size(f.resizeGrip, RESIZE_GRIP_SIZE, RESIZE_GRIP_SIZE)
        point(f.resizeGrip, "BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
        for i = 1, 3 do
            local line = f.resizeGrip["_line" .. i]
            if line then
                clearPoints(line)
                size(line, 4 + (i * 3), 1)
                point(line, "BOTTOMRIGHT", f.resizeGrip, "BOTTOMRIGHT", -3, 2 + (i * 4))
                colorTexture(line, BRASS_R, BRASS_G, BRASS_B, 0.80)
            end
        end
    end
end

function UI:_LayoutMainBoard(frame)
    layoutMainBoard(frame or self.frame)
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
    -- v2.8.24: prototype-A is now closer to the original cockpit sketch:
    -- a persistent left status stack, a center action/player-info column,
    -- and a right cue rail inside one movable shell. Earlier
    -- releases used separate satellite frames; if the user moved the
    -- center frame, those satellites could sit elsewhere and the HUD
    -- still looked like plain floating text. The board keeps the agreed
    -- left/action/right/player-info structure together.
    local savedWidth = clamp(fcfg.width or COMPACT_WIDTH, MIN_COMPACT_WIDTH, MAX_COMPACT_WIDTH)
    local savedHeight = clamp(fcfg.height or COMPACT_HEIGHT, MIN_COMPACT_HEIGHT, MAX_COMPACT_HEIGHT)
    f:SetSize(savedWidth, savedHeight)
    f:SetPoint(fcfg.point or "CENTER", UIParent, fcfg.point or "CENTER",
               fcfg.x or 0, fcfg.y or 120)
    f:SetScale(fcfg.scale or 1.0)
    f:SetMovable(true)
    if f.SetResizable then pcall(f.SetResizable, f, true) end
    if f.SetResizeBounds then
        pcall(f.SetResizeBounds, f, MIN_COMPACT_WIDTH, MIN_COMPACT_HEIGHT, MAX_COMPACT_WIDTH, MAX_COMPACT_HEIGHT)
    else
        if f.SetMinResize then pcall(f.SetMinResize, f, MIN_COMPACT_WIDTH, MIN_COMPACT_HEIGHT) end
        if f.SetMaxResize then pcall(f.SetMaxResize, f, MAX_COMPACT_WIDTH, MAX_COMPACT_HEIGHT) end
    end
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    if f.SetFrameStrata then pcall(f.SetFrameStrata, f, "HIGH") end
    if f.SetFrameLevel then pcall(f.SetFrameLevel, f, 20) end

    -- Backdrop (TBC client uses Backdrop trait built-in for Frame)
    setBackdrop(f, 0.22, 12)
    skinPanel(f, 0.40, 0.78)

    -- Title: small identity marker, not a full header row.
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -6)
    f.title:SetJustifyH("LEFT")
    f.title:SetWidth(190)
    f.title:SetTextColor(BRASS_R, BRASS_G, BRASS_B)
    f.title:SetText(L("UI_TITLE"))
    improveTextContrast(f.title, 1.0)

    f.metaText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.metaText:SetPoint("TOP", f, "TOP", 0, -7)
    f.metaText:SetJustifyH("CENTER")
    f.metaText:SetWidth(220)
    f.metaText:SetTextColor(BRASS_DIM_R, BRASS_DIM_G, BRASS_DIM_B)
    f.metaText:SetText("O B S I D I A N  /  S I G N A L  /  L I V E")
    improveTextContrast(f.metaText, 0.85)

    local dragBar = solidTexture(f, "dragBar", "BACKGROUND", OBSIDIAN_WARM_R, OBSIDIAN_WARM_G, OBSIDIAN_WARM_B, 0.56)
    if dragBar then
        clearPoints(dragBar)
        point(dragBar, "TOPLEFT", f, "TOPLEFT", 2, -2)
        point(dragBar, "TOPRIGHT", f, "TOPRIGHT", -2, -2)
        if dragBar.SetHeight then pcall(dragBar.SetHeight, dragBar, HEADER_HEIGHT) end
    end

    local m = boardMetrics(f)

    local leftPanel = createChildPanel(f, "leftPanel", m.leftW, m.actionH,
        "TOPLEFT", "TOPLEFT", m.leftX, m.bodyY, 0.34)
    local centerPanel = createChildPanel(f, "centerPanel", m.centerW, m.actionH,
        "TOPLEFT", "TOPLEFT", m.centerX, m.bodyY, 0.36)
    local rightPanel = createChildPanel(f, "rightPanel", m.rightW, m.actionH,
        "TOPLEFT", "TOPLEFT", m.rightX, m.bodyY, 0.34)
    local assignPanel = createChildPanel(f, "assignPanel", m.contentW, m.assignH,
        "TOPLEFT", "TOPLEFT", m.leftX, m.assignY, 0.34)

    placeLine(f, "leftDivider", 1, m.actionH, m.centerX - math.floor(PANEL_GUTTER / 2), m.bodyY, 0.42)
    placeLine(f, "rightDivider", 1, m.actionH, m.rightX - math.floor(PANEL_GUTTER / 2), m.bodyY, 0.42)
    placeLine(f, "assignDivider", m.contentW, 1, m.leftX, m.assignY + 1, 0.58)
    if centerPanel and centerPanel.CreateTexture then
        f.modeAccent = centerPanel:CreateTexture(nil, "ARTWORK")
        colorTexture(f.modeAccent, BRASS_R, BRASS_G, BRASS_B, 0.72)
        f.healthBarBg = centerPanel:CreateTexture(nil, "BORDER")
        colorTexture(f.healthBarBg, OBSIDIAN_WARM_R, OBSIDIAN_WARM_G, OBSIDIAN_WARM_B, 0.86)
        f.healthBarFill = centerPanel:CreateTexture(nil, "ARTWORK")
        colorTexture(f.healthBarFill, CYAN_R, CYAN_G, CYAN_B, 0.92)
    end
    f.healthLabel = centerPanel and centerPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall") or nil
    if f.healthLabel then
        f.healthLabel:SetJustifyH("CENTER")
        f.healthLabel:SetTextColor(BRASS_R, BRASS_G, BRASS_B)
        f.healthLabel:SetText("H E A L T H  ·  P O O L")
        improveTextContrast(f.healthLabel, 0.9)
    end

    -- Small build marker for rapid local-copy/release verification.
    f.versionText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.versionText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
    f.versionText:SetJustifyH("RIGHT")
    f.versionText:SetWidth(70)
    f.versionText:SetTextColor(BONE_R, BONE_G, BONE_B)
    f.versionText:SetText("v" .. addonVersion())

    f.dragGrip = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.dragGrip:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
    f.dragGrip:SetJustifyH("LEFT")
    f.dragGrip:SetWidth(16)
    f.dragGrip:SetTextColor(BRASS_R, BRASS_G, BRASS_B)
    f.dragGrip:SetText("||")
    improveTextContrast(f.dragGrip, 1.0)

    f.resizeGrip = CreateFrame("Frame", nil, f)
    f.resizeGrip:SetSize(RESIZE_GRIP_SIZE, RESIZE_GRIP_SIZE)
    f.resizeGrip:EnableMouse(true)
    if type(f.resizeGrip.SetFrameLevel) == "function" and type(f.GetFrameLevel) == "function" then
        local ok, level = pcall(f.GetFrameLevel, f)
        if ok and type(level) == "number" then pcall(f.resizeGrip.SetFrameLevel, f.resizeGrip, level + 2) end
    end
    for i = 1, 3 do
        f.resizeGrip["_line" .. i] = f.resizeGrip:CreateTexture(nil, "OVERLAY")
    end
    f.resizeGrip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and not (ArenaCoachTBCDB and ArenaCoachTBCDB.locked) and f.StartSizing then
            f:StartSizing("BOTTOMRIGHT")
        end
    end)
    f.resizeGrip:SetScript("OnMouseUp", function()
        if f.StopMovingOrSizing then f:StopMovingOrSizing() end
        layoutMainBoard(f)
        saveFramePosition("frame", f)
    end)

    -- v2.8.1: Japanese-arcade-style warning plate. This is just a big,
    -- passive text cue inside the HUD, never a fullscreen flash.
    local actionParent = centerPanel or f
    f.arcadeText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    f.arcadeText:SetPoint("TOP", actionParent, "TOP", 0, -5)
    if f.arcadeText.SetFont then
        local fontPath = (f.arcadeText.GetFont and select(1, f.arcadeText:GetFont()))
            or "Fonts\\FRIZQT__.TTF"
        pcall(f.arcadeText.SetFont, f.arcadeText, fontPath, 11, "OUTLINE")
    end
    f.arcadeText:SetJustifyH("CENTER")
    f.arcadeText:SetWidth(m.centerW - 10)
    f.arcadeText:SetText(string.format("!! %s !!", L("UI_ARCADE_READY")))
    improveTextContrast(f.arcadeText, 1.0, 1, -1)

    -- Main recommendation line ("KILL: Warlock"). This remains the
    -- largest element, but no longer consumes a raid-warning sized band.
    f.bigText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    f.bigText:SetPoint("TOP", f.arcadeText, "BOTTOM", 0, -1)
    if f.bigText.SetFont then
        local fontPath = (f.bigText.GetFont and select(1, f.bigText:GetFont()))
            or "Fonts\\FRIZQT__.TTF"
        pcall(f.bigText.SetFont, f.bigText, fontPath, 22, "THICKOUTLINE")
    end
    f.bigText:SetJustifyH("CENTER")
    f.bigText:SetWidth(m.centerW - 10)
    f.bigText:SetText(L("REASON_DEFAULT"))
    improveTextContrast(f.bigText, 1.0, 1, -1)

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
    f.statsText:SetWidth(m.centerW - 10)
    f.statsText:SetText("")
    improveTextContrast(f.statsText, 0.95, 1, -1)

    -- Reason / top callout text. Default mode shows one line; verbose
    -- mode can still expand for debugging.
    f.subText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.subText:SetPoint("TOP", f.statsText, "BOTTOM", 0, -3)
    if f.subText.SetSpacing then pcall(f.subText.SetSpacing, f.subText, 2) end
    f.subText:SetJustifyH("CENTER")
    f.subText:SetWidth(m.centerW - 10)
    f.subText:SetText("")
    improveTextContrast(f.subText, 0.95, 1, -1)

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
        f.unitText:SetWidth(m.leftW - 16)
        f.unitText:SetText(waitingUnitText())
        improveTextContrast(f.unitText, 0.95, 1, -1)
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
        f.railText:SetWidth(m.rightW - 16)
        f.railText:SetText(waitingCueText())
        improveTextContrast(f.railText, 0.95, 1, -1)
    end

    if assignPanel then
        f.assignHeader = assignPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.assignHeader:SetPoint("TOPLEFT", assignPanel, "TOPLEFT", 10, -5)
        if f.assignHeader.SetFont then
            local fontPath = (f.assignHeader.GetFont and select(1, f.assignHeader:GetFont()))
                or "Fonts\\FRIZQT__.TTF"
            pcall(f.assignHeader.SetFont, f.assignHeader, fontPath, 10, "OUTLINE")
        end
        f.assignHeader:SetJustifyH("LEFT")
        f.assignHeader:SetWidth(m.contentW - 20)
        f.assignHeader:SetText(consoleHeader("UI_ACTIONS_HEADER", "R O L E · S L O T S", "03"))
        improveTextContrast(f.assignHeader, 0.95, 1, -1)

        f.assignText = assignPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.assignText:SetPoint("TOPLEFT", assignPanel, "TOPLEFT", 10, -7)
        if f.assignText.SetFont then
            local fontPath = (f.assignText.GetFont and select(1, f.assignText:GetFont()))
                or "Fonts\\FRIZQT__.TTF"
            pcall(f.assignText.SetFont, f.assignText, fontPath, 10, "OUTLINE")
        end
        if f.assignText.SetSpacing then pcall(f.assignText.SetSpacing, f.assignText, 1) end
        f.assignText:SetJustifyH("LEFT")
        f.assignText:SetWidth(m.contentW - 20)
        f.assignText:SetText(waitingAssignmentText())
        if f.assignText.Hide then f.assignText:Hide() end
        improveTextContrast(f.assignText, 0.95, 1, -1)

        f.assignSlotTexts = {}
        for i = 1, VERBOSE_ACTION_LINES do
            local slot = assignPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            if slot.SetFont then
                local fontPath = (slot.GetFont and select(1, slot:GetFont()))
                    or "Fonts\\FRIZQT__.TTF"
                pcall(slot.SetFont, slot, fontPath, 9, "OUTLINE")
            end
            if slot.SetSpacing then pcall(slot.SetSpacing, slot, 1) end
            slot:SetJustifyH("LEFT")
            slot:SetJustifyV("TOP")
            slot:SetText("")
            improveTextContrast(slot, 0.95, 1, -1)
            f.assignSlotTexts[i] = slot
        end
    end

    installDrag(f, "frame")
    f:SetScript("OnSizeChanged", function(self)
        layoutMainBoard(self)
    end)
    f:SetScript("OnUpdate", function(_, dt)
        if UI and UI._UpdateStaleFade then UI:_UpdateStaleFade(dt) end
    end)

    self.frame = f
    layoutMainBoard(f)
    self:CreateUnitStripFrame()
    self:CreateCueRailFrame()
    self:CreateAssignmentsFrame()
    if not addonEnabled() then self:Hide() end
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
    improveTextContrast(uf.text, 0.95, 1, -1)

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
    improveTextContrast(rf.text, 0.95, 1, -1)

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
    improveTextContrast(af.actionText, 0.95, 1, -1)

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
    OPEN   = {BRASS_R, BRASS_G, BRASS_B},
    KILL   = {CRIMSON_R, CRIMSON_G, CRIMSON_B},
    SWAP   = {0.94, 0.56, 0.18},
    DEFEND = {CYAN_R, CYAN_G, CYAN_B},
    RESET  = {BONE_R, BONE_G, BONE_B},
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
    return string.format("S I G N A L  ·  %s  ·  L I V E", L(arcadeCueKey(recommendation, mode)))
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

local function normalizedAssignmentSlots(count)
    count = tonumber(count) or 0
    if count <= 1 then return 1 end
    if count == 2 then return 2 end
    if count <= 3 then return 3 end
    return 5
end

local function bracketSlots()
    local bracket = ns.Core and ns.Core.state and ns.Core.state.bracket
    if type(bracket) == "number" then return normalizedAssignmentSlots(bracket) end
    if type(bracket) == "string" then
        if bracket:find("5") then return 5 end
        if bracket:find("3") then return 3 end
        if bracket:find("2") then return 2 end
        if bracket:find("1") then return 1 end
    end
    return nil
end

local function friendlySlots()
    local friendlies = ns.Core and ns.Core.state and ns.Core.state.friendlies
    if type(friendlies) ~= "table" then return nil end
    local count = 0
    for _, friendly in pairs(friendlies) do
        if friendly and friendly.alive ~= false then count = count + 1 end
    end
    if count > 0 then return normalizedAssignmentSlots(count) end
    return nil
end

local function assignmentSlotCount(actions)
    if actions and #actions > 0 then return normalizedAssignmentSlots(#actions) end
    return friendlySlots() or bracketSlots() or DEFAULT_ACTION_LINES
end

local function isSelfAction(action)
    if not action then return false end
    if action.unit == "player" then return true end
    if type(UnitGUID) == "function" and action.guid then
        local ok, playerGUID = pcall(UnitGUID, "player")
        if ok and playerGUID and action.guid == playerGUID then return true end
    end
    local name = action.name
    return name == "You" or name == L("UI_SELF_TAG")
end

local function displayActions(actions)
    if not actions or #actions == 0 then return actions end
    local out, selfAction = {}, nil
    for i = 1, #actions do
        local action = actions[i]
        if action and isSelfAction(action) and not selfAction then
            selfAction = action
        else
            table.insert(out, action)
        end
    end
    if not selfAction then return actions end
    table.insert(out, 1, selfAction)
    return out
end

local function assignmentCardText(action, index)
    if not action then
        return string.format("|cff8f7b49P·%02d|r\n%s", index, waitingValue())
    end
    local who = action.name or action.unit or action.class or "?"
    local role = action.class or action.role or action.unit or ""
    local text = action.text or (action.actionKey and L(action.actionKey)) or action.actionKey or "?"
    local target = action.targetName or action.targetClass
    local targetLine = target and target ~= ""
        and ("|cffff6464" .. target .. "|r")
        or "|cff7a715dREADY|r"
    if isSelfAction(action) then
        return string.format("|cffffd24a%s|r |cff8f7b49P·%02d|r |cff5bc4d8%s|r\n|cffffffff%s|r\n|cff8f7b49->|r %s",
            L("UI_SELF_TAG"), index, role ~= "" and string.upper(role) or "ROLE", text, targetLine)
    end
    return string.format("|cff8f7b49P·%02d|r |cffffffff%s|r |cff5bc4d8%s|r\n|cffddd2ad%s|r\n|cff8f7b49->|r %s",
        index, who, role ~= "" and string.upper(role) or "ROLE", text, targetLine)
end

local function formatPlayerActions(actions, scaffold)
    if not actions or #actions == 0 then
        return scaffold and waitingAssignmentText() or ""
    end
    local lines = { consoleHeader("UI_ACTIONS_HEADER", "R O L E · A S S I G N M E N T", "03") }
    actions = displayActions(actions)
    local verbose = (ArenaCoachTBCDB and ArenaCoachTBCDB.frame
                     and ArenaCoachTBCDB.frame.verbose) or false
    local panelCap = (UI.frame and UI.frame._accAssignLines) or DEFAULT_ACTION_LINES
    local maxLines = verbose and math.min(VERBOSE_ACTION_LINES, panelCap)
        or math.min(DEFAULT_ACTION_LINES, panelCap)
    for i = 1, math.min(#actions, maxLines) do
        local a = actions[i]
        local who = a.name or a.unit or a.class or "?"
        local role = a.class or a.role or a.unit or ""
        local text = a.text or (a.actionKey and L(a.actionKey)) or a.actionKey or "?"
        local target = a.targetName or a.targetClass
        if target and target ~= "" then
            text = text .. "  |cff8f7b49->|r  |cffff6464" .. target .. "|r"
        end
        if isSelfAction(a) then
            table.insert(lines, string.format("|cffffd24a%s|r |cff8f7b49P·%02d|r |cffffffff%s:|r |cff5bc4d8%s|r  |cffffffff%s|r",
                L("UI_SELF_TAG"), i, who, role ~= "" and string.upper(role) or "", text))
        else
            table.insert(lines, string.format("|cff8f7b49P·%02d|r |cffffffff%s:|r |cff5bc4d8%s|r  %s",
                i, who, role ~= "" and string.upper(role) or "", text))
        end
    end
    return table.concat(lines, "\n")
end

local function setAssignmentSlots(frame, actions, scaffold)
    if not frame then return end
    actions = displayActions(actions)
    local slots = assignmentSlotCount(actions)
    frame._accAssignSlots = slots
    frame._accSelfAssignmentIndex = nil
    layoutAssignmentSlots(frame, slots)
    for i = 1, VERBOSE_ACTION_LINES do
        local fs = frame.assignSlotTexts and frame.assignSlotTexts[i]
        local action = actions and actions[i]
        local selfSlot = isSelfAction(action)
        if fs then
            if i <= slots then
                fs._accIsSelf = selfSlot
                fs:SetText(assignmentCardText(action, i))
                if fs.Show then fs:Show() end
            else
                fs._accIsSelf = false
                fs:SetText("")
                if fs.Hide then fs:Hide() end
            end
        end
        local bg = frame.assignPanel and frame.assignPanel["assignCard" .. i]
        if bg then
            bg._accIsSelf = selfSlot
            if selfSlot then
                frame._accSelfAssignmentIndex = i
                colorTexture(bg, 0.18, 0.12, 0.035, 0.70)
            elseif i <= slots then
                colorTexture(bg, OBSIDIAN_WARM_R, OBSIDIAN_WARM_G, OBSIDIAN_WARM_B, 0.42)
            end
        end
    end
    if (not actions or #actions == 0) and not scaffold then
        for i = 1, VERBOSE_ACTION_LINES do
            local fs = frame.assignSlotTexts and frame.assignSlotTexts[i]
            if fs then
                fs._accIsSelf = false
                fs:SetText("")
                if fs.Hide then fs:Hide() end
            end
            local bg = frame.assignPanel and frame.assignPanel["assignCard" .. i]
            if bg then bg._accIsSelf = false end
        end
    end
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
        targetLine = string.format("%s |cffffffff%s|r |cffddd2ad%s|r",
            consoleTag(L(mode), mode == "SWAP" and "52c7df" or "e15b5b"), target, suffix)
    end
    local secondary = recommendation.secondaryTargetName
                   or recommendation.secondaryTargetClass
                   or nil
    local secondaryLine
    if secondary and secondary ~= "" and secondary ~= target then
        secondaryLine = string.format("%s |cffffffff%s|r", consoleTag(L("SWAP"), "52c7df"), secondary)
    end
    local low = lowestFriendly(ns.Core and ns.Core.state)
    local teamLine
    if low then
        teamLine = string.format("%s |cffffffff%s|r |cffddd2ad%d%%|r",
            consoleTag(L("UI_MODULE_TEAM"), "c8a86b"), low.name, low.hp)
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
    table.insert(lines, 1, consoleHeader("UI_MODULE_FOCUS", "T A R G E T S", "01"))
    return table.concat(lines, "\n")
end

local function formatCueRail(recommendation, scaffold)
    if not recommendation then return scaffold and waitingCueText() or "" end
    local lines = {}
    if recommendation.burstAllowed and recommendation.mode == "KILL" then
        table.insert(lines, "|cffffd24a●|r " .. L("UI_BURST_READY") .. " |cffffd24aHI|r")
    end
    local verbose = (ArenaCoachTBCDB and ArenaCoachTBCDB.frame
                     and ArenaCoachTBCDB.frame.verbose) or false
    local panelCap = (UI.frame and UI.frame._accCueLines) or DEFAULT_ACTION_LINES
    local maxLines = verbose and math.min(VERBOSE_ACTION_LINES, panelCap)
        or math.min(DEFAULT_ACTION_LINES, panelCap)
    if recommendation.callouts then
        for i = 1, math.min(#recommendation.callouts, maxLines) do
            local key = recommendation.callouts[i]
            table.insert(lines,
                string.format("%s  |cffffffff%s|r", calloutIcon(key, 14), calloutText(key, recommendation)))
        end
    end
    if #lines == 0 then
        return scaffold and waitingCueText() or ""
    end
    table.insert(lines, 1, consoleHeader("UI_MODULE_CUES", "B R I E F", "02"))
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

local function capLines(lines, maxLines)
    maxLines = tonumber(maxLines) or #lines
    while #lines > maxLines do table.remove(lines) end
    return lines
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
    if not addonEnabled() then
        self:Hide()
        return
    end
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
    if not addonEnabled() then
        self:Hide()
        return
    end
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function UI:Apply(recommendation)
    local f = self.frame; if not f or not recommendation then return end
    if not addonEnabled() then
        self:Hide()
        if ns.ScreenEdgeGlow then ns.ScreenEdgeGlow:Hide() end
        if ns.Nameplate then ns.Nameplate:ClearAll() end
        return
    end

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
    if f.metaText then
        local bracket = (ns.Core and ns.Core.state and ns.Core.state.bracket) or "PvP"
        f.metaText:SetText(string.format("O B S I D I A N  /  %s  /  %s", tostring(bracket), mode))
    end
    if f.modeAccent then
        colorTexture(f.modeAccent, color[1], color[2], color[3], 0.78)
    end

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
    -- v2.6.0: each segment is colour-coded inline via WoW colour
    -- escapes so the eye picks out the action-relevant value. v2.8.26
    -- retuned this into the Obsidian Signal cyan/brass/crimson palette.
    if f.statsText then
        local parts = {}
        local function tag(hex, body)
            return string.format("|cff%s%s|r", hex, body)
        end
        if showTarget and recommendation.primaryTargetHp then
            local hp = math.floor((recommendation.primaryTargetHp * 100) + 0.5)
            -- HP rendered in bone-white — the neutral reference value
            -- the player calibrates the others against.
            table.insert(parts, tag("ddd2ad",
                string.format("%s %d%%", L("UI_HP_LABEL"), hp)))
        end
        if showTarget and recommendation.killProb then
            local kp = math.floor((recommendation.killProb * 100) + 0.5)
            -- Obsidian Signal grading: cool watch state, brass setup,
            -- crimson commitment when the kill is actually plausible.
            local hex
            if kp >= 60 then hex = "dc333a"       -- crimson signal
            elseif kp >= 30 then hex = "c89e56"   -- brass amber
            else hex = "57c7db" end                -- cool watch state
            table.insert(parts, tag(hex,
                string.format("%s %d%%", L("UI_KILL_PROB_LABEL"), kp)))
        end
        if recommendation.burstAllowed and mode == "KILL" then
            -- Brass + a leading sigil so BURST READY reads as a deliberate
            -- instrument cue rather than another loud alarm.
            table.insert(parts, tag("c89e56", "★ " .. L("UI_BURST_READY")))
        end
        -- Wider " · " separator + leading/trailing space so segments
        -- breathe instead of running together.
        f.statsText:SetText(table.concat(parts, "  ·  "))
    end

    if f.healthBarFill then
        local hp = showTarget and recommendation.primaryTargetHp or nil
        if hp then
            local frac = tonumber(hp) or 0
            if frac > 1 then frac = frac / 100 end
            frac = clamp(frac, 0, 1)
            local barW = f._accHealthBarWidth or 100
            f._accHealthBarFillWidth = math.max(1, math.floor(barW * frac))
            size(f.healthBarFill, f._accHealthBarFillWidth, 8)
            if frac <= 0.35 then
                colorTexture(f.healthBarFill, CRIMSON_R, CRIMSON_G, CRIMSON_B, 0.94)
            elseif frac <= 0.65 then
                colorTexture(f.healthBarFill, 0.95, 0.56, 0.18, 0.92)
            else
                colorTexture(f.healthBarFill, CYAN_R, CYAN_G, CYAN_B, 0.92)
            end
            if f.healthBarBg and f.healthBarBg.Show then f.healthBarBg:Show() end
            if f.healthBarFill.Show then f.healthBarFill:Show() end
        else
            f._accHealthBarFillWidth = 1
            size(f.healthBarFill, 1, 8)
            if f.healthBarFill.Hide then f.healthBarFill:Hide() end
            if f.healthBarBg and f.healthBarBg.Hide then f.healthBarBg:Hide() end
        end
    end
    if f.healthLabel then
        local hp = showTarget and pct(recommendation.primaryTargetHp) or nil
        if hp then
            f.healthLabel:SetText(string.format("H E A L T H  ·  P O O L       C U R R E N T  %d%%", hp))
            if f.healthLabel.Show then f.healthLabel:Show() end
        else
            f.healthLabel:SetText("")
            if f.healthLabel.Hide then f.healthLabel:Hide() end
        end
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
    capLines(subParts, f._accCenterSubLines or 1)
    f.subText:SetText(table.concat(subParts, "\n"))
    local scaffold = layoutScaffoldActive(recommendation)
    local integratedUnitText = formatUnitStrip(recommendation, true)
    local integratedRailText = formatCueRail(recommendation, true)
    local integratedAssignText = formatPlayerActions(recommendation.playerActions, true)
    setFontStringText(f.unitText, integratedUnitText)
    setFontStringText(f.railText, integratedRailText)
    setFontStringText(f.assignText, integratedAssignText)
    setAssignmentSlots(f, recommendation.playerActions, scaffold)
    if f.assignText and f.assignText.Hide then f.assignText:Hide() end

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
