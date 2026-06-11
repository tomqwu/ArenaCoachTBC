-- ArenaCoachTBC - Facts HUD (v2.9)
--
-- Per-enemy *observed facts* display — the layer serious arena players
-- run cooldown trackers for:
--
--   Name HP%   trinket-CD   downed-defensive-CD   downed-interrupt-CD   DR badges
--
-- Everything here is already tracked by modules that watch the combat
-- log; until v2.9 none of it was visible:
--   - CooldownTracker : observed enemy cooldowns (trinket, Ice Block, Kick...)
--   - DRTracker       : diminishing-return state per CC category
--   - Core.state      : per-enemy class / health / alive
--
-- Design: BuildRowModel / BuildModel / FormatRow are pure (no frame
-- access) so the display logic is unit-testable headless. The frame
-- layer below only paints models. Countdown text repaints on a 0.5s
-- OnUpdate accumulator so numbers tick between combat events.
--
-- Advice stays in UI.lua. This module renders only observed facts and
-- has no dependency on StrategyEngine. It shows in every display mode
-- (alert / board / both) because facts are useful regardless of how the
-- user consumes advice. Toggle: /acc facts off (db.factsHud.enabled).

local ADDON_NAME, ns = ...
ns = ns or {}
ns.FactsHUD = ns.FactsHUD or {}

local FH = ns.FactsHUD
FH.frame = nil
FH.MAX_ROWS = 5
FH.REFRESH_INTERVAL = 0.5  -- seconds between countdown repaints

local function now()
    if type(GetTime) == "function" then return GetTime() end
    return os.time()
end

-- Resolve a user-facing label through the addon locale layer; falls
-- back to the key's tail so headless tests stay readable.
local function L(key, fallback)
    local Core = ns.Core
    if Core and Core.L then
        local s = Core.L(key)
        if s and s ~= key then return s end
    end
    return fallback
end

-- DR category -> single-glyph badge. Glyphs, not words, so no locale
-- key is needed and the badge column stays narrow.
FH.DR_GLYPHS = {
    STUN         = "S",
    FEAR         = "F",
    DISORIENT    = "D",
    INCAPACITATE = "P",   -- "P" for poly/sap family
    ROOT         = "R",
    CYCLONE      = "C",
}

local function multGlyph(mult)
    if mult == 0.5 then return "1/2" end
    if mult == 0.25 then return "1/4" end
    if mult == 0.0 then return "IMM" end
    return nil  -- full DR -> no badge
end

local function fmtSecs(s)
    if not s or s <= 0 then return nil end
    if s >= 60 then return string.format("%dm", math.ceil(s / 60)) end
    return string.format("%d", math.ceil(s))
end

-- ============================================================
-- Pure model builders
-- ============================================================

-- Trinket cell: "can this target break CC right now". The medallion
-- (42292) and WotF (7744) are INDEPENDENT CC-breaks in TBC:
--   - medallion unobserved or expired -> T+ (a WotF-only use does not
--     consume the medallion — same semantics as Core's hasTrinket)
--   - medallion down but WotF observed back up -> T+ (undead with a
--     ready racial break)
--   - otherwise -> red countdown to the FIRST CC-break coming back
local function trinketModel(guid)
    local CT = ns.CooldownTracker
    local S  = ns.Spells
    if not CT or not S or not guid then return { ready = true } end
    local medRem  = CT:GetRemaining(guid, S.PVP_TRINKET_EFFECT)
    local wotfRem = CT:GetRemaining(guid, S.WILL_OF_THE_FORSAKEN)
    if not medRem or medRem <= 0 then return { ready = true } end
    if wotfRem and wotfRem <= 0 then return { ready = true } end
    local soonest = medRem
    if wotfRem and wotfRem > 0 and wotfRem < soonest then soonest = wotfRem end
    return { ready = false, remaining = soonest }
end

-- Downed-cooldown cell: among this unit's OBSERVED cooldowns that
-- belong to the given display list, return the one with the SHORTEST
-- remaining (the one coming back first is the one the player must plan
-- around). nil when nothing observed on cooldown — the cell stays empty
-- rather than guessing "ready".
--
-- Iterates CT:ForUnit (typically 0-2 observed entries) instead of the
-- full display catalog, so cost is O(observed), not O(catalog), on the
-- repaint path.
local setCache = {}
local function setFor(ids)
    local cached = setCache[ids]
    if cached then return cached end
    local s = {}
    for _, id in ipairs(ids) do s[id] = true end
    setCache[ids] = s
    return s
end

local function downedModel(guid, ids, nowTs)
    local CT = ns.CooldownTracker
    if not CT or not guid or not ids then return nil end
    local set = setFor(ids)
    local best = nil
    for spellID, rec in pairs(CT:ForUnit(guid)) do
        if set[spellID] and rec.ready then
            local rem = rec.ready - nowTs
            if rem > 0 and (not best or rem < best.remaining) then
                best = { spellID = spellID, remaining = rem }
            end
        end
    end
    return best
end

-- DR badges: one entry per category with active diminishing returns.
local function drModel(guid)
    local DR = ns.DRTracker
    if not DR or not guid then return {} end
    local out = {}
    for _, cat in ipairs(DR.categories or {}) do
        local mult = DR:NextMultiplier(guid, cat)
        local glyph = multGlyph(mult)
        if glyph then
            table.insert(out, {
                category = cat,
                glyph    = (FH.DR_GLYPHS[cat] or "?") .. ":" .. glyph,
                mult     = mult,
            })
        end
    end
    return out
end

function FH:BuildRowModel(enemy, nowTs)
    if not enemy or enemy.alive == false or not enemy.class then return nil end
    nowTs = nowTs or now()
    return {
        unit      = enemy.unit,
        guid      = enemy.guid,
        name      = enemy.name or enemy.class,
        class     = enemy.class,
        healthPct = enemy.healthPct or 100,
        trinket   = trinketModel(enemy.guid),
        defensive = downedModel(enemy.guid, ns.Spells and ns.Spells.FACTS_DEFENSIVES, nowTs),
        interrupt = downedModel(enemy.guid, ns.Spells and ns.Spells.FACTS_INTERRUPTS, nowTs),
        dr        = drModel(enemy.guid),
    }
end

-- Stable ordering: arena1..arena5 first (slot order matches the
-- Blizzard arena frames), then any GUID-keyed BG/world entries sorted
-- by name.
function FH:BuildModel(state)
    local rows = {}
    if not state or not state.enemies then return rows end
    local nowTs = now()
    for i = 1, self.MAX_ROWS do
        local e = state.enemies["arena" .. i]
        local m = e and self:BuildRowModel(e, nowTs)
        if m then table.insert(rows, m) end
    end
    if #rows == 0 then
        local extras = {}
        for key, e in pairs(state.enemies) do
            if type(key) == "string" and not key:find("^arena") then
                local m = self:BuildRowModel(e, nowTs)
                if m then table.insert(extras, m) end
            end
        end
        table.sort(extras, function(a, b) return (a.name or "") < (b.name or "") end)
        for i = 1, math.min(#extras, self.MAX_ROWS) do
            table.insert(rows, extras[i])
        end
    end
    return rows
end

-- Render a model to display strings. Pure; the frame layer just copies
-- these into FontStrings. Exposed for tests.
function FH:FormatRow(m)
    local trinketText
    if m.trinket.ready then
        trinketText = "T+"           -- trinket up: the target can break CC
    else
        trinketText = "T-" .. (fmtSecs(m.trinket.remaining) or "")
    end
    local defText = ""
    if m.defensive then
        local name
        if type(GetSpellInfo) == "function" then name = GetSpellInfo(m.defensive.spellID) end
        defText = (name or L("FACTS_DEF_LABEL", "DEF")) .. " "
            .. (fmtSecs(m.defensive.remaining) or "")
    end
    local intText = ""
    if m.interrupt then
        intText = L("FACTS_KICK_LABEL", "KICK") .. " "
            .. (fmtSecs(m.interrupt.remaining) or "")
    end
    local drText = ""
    if #m.dr > 0 then
        local parts = {}
        for _, d in ipairs(m.dr) do table.insert(parts, d.glyph) end
        drText = table.concat(parts, " ")
    end
    return {
        nameText    = string.format("%s %d%%", m.name or "?", m.healthPct or 100),
        trinketText = trinketText,
        defText     = defText,
        intText     = intText,
        drText      = drText,
    }
end

-- ============================================================
-- Frame layer
-- ============================================================
local CLASS_COLORS = {
    WARRIOR = {0.78, 0.61, 0.43}, PALADIN = {0.96, 0.55, 0.73},
    HUNTER  = {0.67, 0.83, 0.45}, ROGUE   = {1.00, 0.96, 0.41},
    PRIEST  = {1.00, 1.00, 1.00}, SHAMAN  = {0.00, 0.44, 0.87},
    MAGE    = {0.41, 0.80, 0.94}, WARLOCK = {0.58, 0.51, 0.79},
    DRUID   = {1.00, 0.49, 0.04},
}

local ROW_HEIGHT = 18
local FRAME_WIDTH = 360

local function makeRow(parent, index)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(FRAME_WIDTH - 20, ROW_HEIGHT)
    r:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -(6 + (index - 1) * ROW_HEIGHT))
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.name:SetWidth(110); r.name:SetJustifyH("LEFT")
    r.trinket = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.trinket:SetPoint("LEFT", r, "LEFT", 112, 0)
    r.trinket:SetWidth(42); r.trinket:SetJustifyH("LEFT")
    r.def = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.def:SetPoint("LEFT", r, "LEFT", 156, 0)
    r.def:SetWidth(94); r.def:SetJustifyH("LEFT")
    r.int = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.int:SetPoint("LEFT", r, "LEFT", 252, 0)
    r.int:SetWidth(44); r.int:SetJustifyH("LEFT")
    r.dr = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.dr:SetPoint("LEFT", r, "LEFT", 298, 0)
    r.dr:SetWidth(42); r.dr:SetJustifyH("LEFT")
    return r
end

function FH:CreateFrame()
    if self.frame then return self.frame end
    if type(CreateFrame) ~= "function" then return nil end
    local db = _G.ArenaCoachTBCDB or {}
    local fcfg = db.factsFrame or { point = "CENTER", x = 0, y = -40, scale = 1.0 }

    -- BackdropTemplate is required on the modern (2.5.x+) client or the
    -- frame has no SetBackdrop and renders as floating text over an
    -- invisible mouse-blocking region. Older clients don't know the
    -- template; pass it only when the mixin exists.
    local template = (type(BackdropTemplateMixin) == "table") and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", "ArenaCoachTBCFactsHUD", UIParent, template)
    f:SetSize(FRAME_WIDTH, 12 + self.MAX_ROWS * ROW_HEIGHT)
    f:SetPoint(fcfg.point or "CENTER", UIParent, fcfg.point or "CENTER",
               fcfg.x or 0, fcfg.y or -40)
    f:SetScale(fcfg.scale or 1.0)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropColor(0, 0, 0, 0.45)
    end

    -- Same drag contract as the other movable frames: respects
    -- db.locked, persists position under its own SavedVars key.
    f:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not (_G.ArenaCoachTBCDB and _G.ArenaCoachTBCDB.locked) then
            self:StartMoving()
        end
    end)
    f:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        local sdb = _G.ArenaCoachTBCDB
        if sdb then
            sdb.factsFrame = sdb.factsFrame or {}
            sdb.factsFrame.point = point
            sdb.factsFrame.x = x
            sdb.factsFrame.y = y
        end
    end)

    f.rows = {}
    for i = 1, self.MAX_ROWS do f.rows[i] = makeRow(f, i) end
    -- Low-frequency countdown repaint. Numbers must tick between combat
    -- events or a "T-45" reads as stale the moment it's painted.
    f._accum = 0
    f:SetScript("OnUpdate", function(frame, elapsed)
        frame._accum = (frame._accum or 0) + (elapsed or 0)
        if frame._accum >= FH.REFRESH_INTERVAL then
            frame._accum = 0
            FH:Repaint()
        end
    end)
    self.frame = f
    return f
end

-- Prefer the client's RAID_CLASS_COLORS (tracks class-color addons and
-- client updates); the local table covers headless tests and odd clients.
local function classColor(class)
    local cc = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class]
    if cc and cc.r then return cc.r, cc.g, cc.b end
    local c = CLASS_COLORS[class] or {1, 1, 1}
    return c[1], c[2], c[3]
end

local function paintRow(row, m)
    local txt = FH:FormatRow(m)
    local r, g, b = classColor(m.class)
    row.name:SetText(txt.nameText)
    row.name:SetTextColor(r, g, b)
    row.trinket:SetText(txt.trinketText)
    if m.trinket.ready then row.trinket:SetTextColor(0.4, 1.0, 0.4)
    else row.trinket:SetTextColor(1.0, 0.35, 0.35) end
    row.def:SetText(txt.defText)
    row.def:SetTextColor(1.0, 0.55, 0.25)
    row.int:SetText(txt.intText)
    row.int:SetTextColor(0.55, 0.85, 1.0)
    row.dr:SetText(txt.drText)
    row.dr:SetTextColor(0.9, 0.75, 1.0)
    row:Show()
end

-- Repaint from the last state snapshot (used by the ticker so countdown
-- numbers move without waiting for the next combat event).
function FH:Repaint()
    local f = self.frame
    if not f or not self._lastState then return end
    -- Never paint while hidden: the only legal entry points are Update
    -- (which Shows first) and the ticker (which doesn't run hidden in
    -- the real client). Guards stale paints from any other caller.
    if f.IsShown and not f:IsShown() then return end
    self._lastPaint = now()
    local rows = self:BuildModel(self._lastState)
    for i = 1, self.MAX_ROWS do
        local row = f.rows[i]
        local m = rows[i]
        if m then paintRow(row, m) else row:Hide() end
    end
end

-- Entry point, called from Core:Evaluate after each evaluation.
function FH:Update(state)
    local db = _G.ArenaCoachTBCDB
    if db and db.factsHud and db.factsHud.enabled == false then
        if self.frame then self.frame:Hide() end
        return
    end
    self._lastState = state
    local f = self:CreateFrame()
    if not f then return end
    -- Same visibility gate as the advice frames: nothing outside PvP.
    local ctx = state and state.pvpContext
    if ctx == "none" or ctx == "world_idle" then f:Hide(); return end
    f:Show()
    -- Core:Evaluate fires per impactful CLEU line (dozens/sec in a burst
    -- window). Repainting that often defeats the 0.5s ticker design and
    -- generates garbage in a client where per-frame cost matters — the
    -- v2.2.5 city-lag shape. Rate-limit: the ticker owns the cadence;
    -- Update only paints when the panel is overdue (first show, or the
    -- ticker hasn't run yet).
    if (now() - (self._lastPaint or 0)) >= self.REFRESH_INTERVAL then
        self:Repaint()
    end
end

function FH:Hide()
    if self.frame then self.frame:Hide() end
end
