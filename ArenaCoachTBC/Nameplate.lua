-- ArenaCoachTBC - Nameplate highlight (v2.2.0)
--
-- Decorates the nameplates of the engine's kill / swap targets so the
-- player can pick them out at a glance in a crowded fight. We add a
-- coloured texture overlay anchored to the nameplate's existing frame —
-- we do NOT touch the existing health bar / cast bar / name text, so
-- we coexist cleanly with other nameplate addons (Plater, KuiNameplates,
-- TidyPlates, etc.).
--
-- Decisions:
--  * Hook NAME_PLATE_UNIT_ADDED / REMOVED (driven by Core's event bus)
--    rather than poking nameplate1..nameplate40 every Evaluate. The
--    plate frames come and go as enemies enter/leave LOS so the event
--    is the canonical signal.
--  * Use a separate child Frame on the nameplate ("ACC_HighlightOverlay")
--    so cleanup is idempotent — just delete the child on every refresh
--    and re-create where needed.
--  * Colour palette matches Glow / bigText so the user immediately maps
--    plate colour to mode (red = current KILL, orange = SWAP swap-to).
--  * Off-by-default via db.alerts.nameplate; toggle with /acc nameplate.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.Nameplate = ns.Nameplate or {}

local NP = ns.Nameplate
NP._overlays = {}   -- nameplate frame ref → child overlay frame

NP.colors = {
    KILL = {1.0, 0.2, 0.2, 0.75},   -- red border on the primary target
    SWAP = {1.0, 0.6, 0.0, 0.65},   -- orange border on the swap candidate
}

local BORDER_THICKNESS = 3

-- Resolve the on-screen nameplate frame for a unit token (nameplate1..40).
-- TBC Classic provides C_NamePlate.GetNamePlateForUnit; fall back to the
-- direct _G[unit] frame name if the API is missing (older builds).
local function getNameplateFrame(unit)
    if type(C_NamePlate) == "table" and type(C_NamePlate.GetNamePlateForUnit) == "function" then
        local ok, np = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok and np then return np end
    end
    if type(unit) == "string" and _G and _G[unit] then return _G[unit] end
    return nil
end

local function ensureOverlay(plate)
    if not plate or type(CreateFrame) ~= "function" then return nil end
    local ov = NP._overlays[plate]
    if ov then return ov end
    ov = CreateFrame("Frame", nil, plate)
    if ov.SetAllPoints then ov:SetAllPoints(plate) end
    ov:EnableMouse(false)

    local function band(point1, point2, w, h)
        local tex = ov:CreateTexture(nil, "OVERLAY")
        if point1 then tex:SetPoint(point1, ov, point1, 0, 0) end
        if point2 then tex:SetPoint(point2, ov, point2, 0, 0) end
        if w then tex:SetWidth(w) end
        if h then tex:SetHeight(h) end
        return tex
    end

    ov.top    = band("TOPLEFT",    "TOPRIGHT",    nil, BORDER_THICKNESS)
    ov.bottom = band("BOTTOMLEFT", "BOTTOMRIGHT", nil, BORDER_THICKNESS)
    ov.left   = band("TOPLEFT",    "BOTTOMLEFT",  BORDER_THICKNESS, nil)
    ov.right  = band("TOPRIGHT",   "BOTTOMRIGHT", BORDER_THICKNESS, nil)
    ov:Hide()
    NP._overlays[plate] = ov
    return ov
end

local function applyColor(ov, color)
    if not ov then return end
    for _, tex in ipairs({ ov.top, ov.bottom, ov.left, ov.right }) do
        if tex and tex.SetColorTexture then
            tex:SetColorTexture(color[1], color[2], color[3], color[4])
        end
    end
    ov:Show()
end

local function hideOverlay(plate)
    local ov = NP._overlays[plate]
    if ov and ov.Hide then ov:Hide() end
end

-- Find which nameplate unit (if any) currently points at a given GUID.
-- We don't cache because the unit IDs reshuffle as plates enter / leave.
local function unitForGUID(guid)
    if not guid or type(UnitGUID) ~= "function" then return nil end
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists and UnitExists(unit) and UnitGUID(unit) == guid then
            return unit
        end
    end
end

-- Public: paint a kill-target border on the plate for `guid`. Pass nil
-- to clear that role. `role` is "KILL" or "SWAP".
function NP:Highlight(role, guid)
    local color = self.colors[role]
    if not color or not guid then return end
    local unit = unitForGUID(guid)
    if not unit then return end
    local plate = getNameplateFrame(unit)
    if not plate then return end
    applyColor(ensureOverlay(plate), color)
end

-- Clear all overlays. Called when nameplates feature toggles off or
-- between fights.
function NP:ClearAll()
    for plate, _ in pairs(self._overlays) do hideOverlay(plate) end
end

-- Apply a recommendation: highlight primary as KILL, secondary as SWAP,
-- clear any plates that aren't in those two roles.
function NP:Apply(rec)
    if not rec then self:ClearAll(); return end
    self:ClearAll()
    if rec.primaryTarget then self:Highlight("KILL", rec.primaryTarget) end
    if rec.secondaryTarget and rec.mode == "SWAP" then
        self:Highlight("SWAP", rec.secondaryTarget)
    end
end

-- Called on NAME_PLATE_UNIT_REMOVED so we don't accumulate dead overlay
-- refs over a long session.
function NP:OnPlateRemoved(unit)
    local plate = getNameplateFrame(unit)
    if plate then
        hideOverlay(plate)
        self._overlays[plate] = nil
    end
end
