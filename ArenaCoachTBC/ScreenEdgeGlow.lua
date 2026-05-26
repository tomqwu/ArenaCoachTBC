-- ArenaCoachTBC - ScreenEdgeGlow (v2.2.0)
--
-- Renders a thin mode-coloured cue around the four edges of the screen.
-- The colour follows the current recommendation mode (red KILL, orange
-- SWAP, blue DEFEND, yellow OPEN). v2.8.2 deliberately removed the big
-- pulsing band: this should be peripheral information, not a flashing
-- viewport effect.
--
-- Headless-safe: every CreateFrame / texture call is guarded; tests run
-- with stub CreateFrame and exercise the state machine, not the
-- rendering. Arena/BG/world-gated by the caller (UI:Apply).

local ADDON_NAME, ns = ...
ns = ns or {}
ns.ScreenEdgeGlow = ns.ScreenEdgeGlow or {}

local Glow = ns.ScreenEdgeGlow
Glow._frame = nil
Glow._currentMode = nil

-- Mode → {r,g,b} matching UI's bigText colours so the cue is unambiguous.
Glow.colors = {
    OPEN   = {1.0, 1.0, 0.4},
    KILL   = {1.0, 0.3, 0.3},
    SWAP   = {1.0, 0.6, 0.0},
    DEFEND = {0.4, 0.7, 1.0},
    RESET  = nil,  -- explicit: no glow on RESET; fight isn't active
}

local EDGE_THICKNESS = 18       -- px; intentionally subtle, not a big band
local EDGE_ALPHA     = 0.14     -- static alpha; no pulse / no flashing

local function paintEdges(f, color)
    if not f or not color then return end
    for _, tex in ipairs({ f.top, f.bottom, f.left, f.right }) do
        if tex and tex.SetColorTexture then
            tex:SetColorTexture(color[1], color[2], color[3], EDGE_ALPHA)
        end
    end
end

local function ensureFrame()
    if Glow._frame then return Glow._frame end
    if type(CreateFrame) ~= "function" then return nil end
    local f = CreateFrame("Frame", "ArenaCoachTBCEdgeGlow", UIParent)
    f:SetAllPoints(UIParent)
    f:EnableMouse(false)
    f:Hide()

    local function edge(point1, point2, w, h)
        local tex = f:CreateTexture(nil, "BACKGROUND")
        if point1 then tex:SetPoint(point1, f, point1, 0, 0) end
        if point2 then tex:SetPoint(point2, f, point2, 0, 0) end
        if w then tex:SetWidth(w) end
        if h then tex:SetHeight(h) end
        return tex
    end

    -- Four very thin band textures hugging each screen edge. We
    -- intentionally use plain rectangles instead of vertex-gradient
    -- textures because TBC client texture APIs are inconsistent and a
    -- flat low-alpha line is reliable across every install.
    f.top    = edge("TOPLEFT",    "TOPRIGHT",    nil, EDGE_THICKNESS)
    f.bottom = edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, EDGE_THICKNESS)
    f.left   = edge("TOPLEFT",    "BOTTOMLEFT",  EDGE_THICKNESS, nil)
    f.right  = edge("TOPRIGHT",   "BOTTOMRIGHT", EDGE_THICKNESS, nil)

    f:SetScript("OnUpdate", function(self, dt)
        paintEdges(self, self._color or {1, 1, 1})
    end)

    Glow._frame = f
    return f
end

-- Show the glow in the colour for the given mode. Modes without a
-- colour (RESET, nil) hide the glow.
function Glow:SetMode(mode)
    local color = self.colors[mode]
    local f = ensureFrame()
    if not f then return end
    if not color then
        self._currentMode = nil
        f:Hide()
        return
    end
    self._currentMode = mode
    f._color = color
    paintEdges(f, color)
    f:Show()
end

function Glow:Hide()
    if self._frame then self._frame:Hide() end
    self._currentMode = nil
end

function Glow:CurrentMode()
    return self._currentMode
end

-- For tests: expose colour-resolution without needing a frame.
function Glow:ColorFor(mode)
    return self.colors[mode]
end

function Glow:VisualProfile()
    return {
        edgeThickness = EDGE_THICKNESS,
        alpha = EDGE_ALPHA,
        pulse = false,
    }
end
