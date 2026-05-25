-- ArenaCoachTBC - UI layer
-- One movable frame that shows the current recommendation, callouts, and
-- two icon rows (friendly reminders + enemy cooldowns). All updates are
-- event-driven; the only OnUpdate is a very low-frequency icon refresh
-- (1Hz, guarded by elapsed accumulator). No protected actions are ever
-- bound to any visible button.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.UI = ns.UI or {}

local UI = ns.UI
UI.frame = nil

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

-- Helper: create a small icon button with a texture by spell ID
local function makeIcon(parent, size)
    if type(CreateFrame) ~= "function" then return nil end
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(size, size)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints(true)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("BOTTOM", b, "BOTTOM", 0, -10)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        -- v2.0.1: prefer the localized spell tooltip from the WoW client
        -- so mouse-over follows GetLocale() instead of our hardcoded
        -- English fallback labels. SetSpellByID renders the canonical
        -- icon + localized name + flavor text just like the spellbook.
        if self.spellID and type(GameTooltip.SetSpellByID) == "function" then
            local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)
            if ok then GameTooltip:Show(); return end
        end
        -- Fallback: localized name via GetSpellInfo, then our context label.
        local fallback = self.tooltip
        if self.spellID and type(GetSpellInfo) == "function" then
            local name = GetSpellInfo(self.spellID)
            if name and name ~= "" then fallback = name end
        end
        if fallback then
            GameTooltip:SetText(fallback)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return b
end

-- spell ID -> texture path via WoW API. Defensive on missing API.
local function spellIcon(spellID)
    if type(GetSpellTexture) == "function" then
        return GetSpellTexture(spellID)
    end
    return nil
end

-- ============================================================
-- Build the main frame
-- ============================================================
function UI:CreateFrame()
    if self.frame then return self.frame end
    if type(CreateFrame) ~= "function" then return nil end

    local db = ArenaCoachTBCDB or {}
    local fcfg = db.frame or { point = "CENTER", x = 0, y = 120, scale = 1.0 }

    local f = CreateFrame("Frame", "ArenaCoachTBCFrame", UIParent)
    f:SetSize(360, 170)
    f:SetPoint(fcfg.point or "CENTER", UIParent, fcfg.point or "CENTER",
               fcfg.x or 0, fcfg.y or 120)
    f:SetScale(fcfg.scale or 1.0)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)

    -- Backdrop (TBC client uses Backdrop trait built-in for Frame)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropColor(0, 0, 0, 0.6)
    end

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", f, "TOP", 0, -8)
    f.title:SetText(L("UI_TITLE"))

    -- Big recommendation line ("KILL: Warlock"). v2.1.6: enlarged from
    -- GameFontNormalHuge (~22pt) to a custom 32pt outlined font so the
    -- mode label is readable at a glance from across the screen.
    f.bigText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    f.bigText:SetPoint("TOP", f.title, "BOTTOM", 0, -8)
    if f.bigText.SetFont then
        local fontPath = (f.bigText.GetFont and select(1, f.bigText:GetFont()))
            or "Fonts\\FRIZQT__.TTF"
        pcall(f.bigText.SetFont, f.bigText, fontPath, 32, "OUTLINE")
    end
    f.bigText:SetText(L("REASON_DEFAULT"))

    -- v2.1.6: target stats row (HP% + kill prob%) under the mode line.
    -- Renders only when the rec has a primary target with measurable
    -- health / kill probability; hidden otherwise so it doesn't clutter
    -- DEFEND / RESET states.
    f.statsText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.statsText:SetPoint("TOP", f.bigText, "BOTTOM", 0, -2)
    f.statsText:SetJustifyH("CENTER")
    f.statsText:SetWidth(340)
    f.statsText:SetText("")

    -- Reason / callout text
    f.subText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.subText:SetPoint("TOP", f.statsText, "BOTTOM", 0, -4)
    f.subText:SetJustifyH("CENTER")
    f.subText:SetWidth(340)
    f.subText:SetText("")

    -- Friendly cooldown icons row
    f.friendlyRow = CreateFrame("Frame", nil, f)
    f.friendlyRow:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 38)
    f.friendlyRow:SetSize(340, 24)

    -- Enemy cooldown icons row
    f.enemyRow = CreateFrame("Frame", nil, f)
    f.enemyRow:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
    f.enemyRow:SetSize(340, 24)

    -- Drag handlers (respect db.locked)
    f:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not (ArenaCoachTBCDB and ArenaCoachTBCDB.locked) then
            self:StartMoving()
        end
    end)
    f:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        if ArenaCoachTBCDB and ArenaCoachTBCDB.frame then
            ArenaCoachTBCDB.frame.point = point
            ArenaCoachTBCDB.frame.x = x
            ArenaCoachTBCDB.frame.y = y
        end
    end)

    self.frame = f
    self:_PopulateIconRows()
    return f
end

-- Friendly/enemy icon definitions. Each entry: { spellID, tooltip }.
-- These are *reminder* icons (visual only); we don't bind any actions to them.
UI.friendlyIcons = {
    {id=30330, key="MORTAL_STRIKE",       tip="Warrior Mortal Strike"},
    {id=8512,  key="WINDFURY_TOTEM",      tip="Shaman Windfury Totem"},
    {id=2825,  key="BLOODLUST",           tip="Shaman Bloodlust/Heroism"},
    {id=8177,  key="GROUNDING_TOTEM",     tip="Shaman Grounding Totem"},
    {id=8143,  key="TREMOR_TOTEM",        tip="Shaman Tremor Totem"},
    {id=1044,  key="BLESSING_FREEDOM",    tip="Paladin Blessing of Freedom"},
    {id=10308, key="HAMMER_OF_JUSTICE",   tip="Paladin Hammer of Justice"},
    {id=10278, key="BLESSING_PROTECTION", tip="Paladin Blessing of Protection"},
    {id=33786, key="CYCLONE",             tip="Druid Cyclone"},
    {id=17116, key="NATURES_SWIFTNESS",   tip="Druid Nature's Swiftness"},
    {id=33206, key="PAIN_SUPPRESSION",    tip="Priest Pain Suppression"},
    {id=10890, key="PSYCHIC_SCREAM",      tip="Priest Psychic Scream"},
    {id=988,   key="DISPEL_MAGIC",        tip="Priest Dispel Magic"},
    {id=10876, key="MANA_BURN",           tip="Priest Mana Burn"},
}

UI.enemyIcons = {
    {id=42292, key="PVP_TRINKET",       tip="PvP Trinket"},
    {id=27619, key="ICE_BLOCK",         tip="Ice Block"},
    {id=642,   key="DIVINE_SHIELD",     tip="Divine Shield"},
    {id=10278, key="E_BOP",             tip="Blessing of Protection"},
    {id=33206, key="E_PAIN_SUP",        tip="Pain Suppression"},
    {id=17116, key="E_NS",              tip="Nature's Swiftness"},
    {id=29166, key="INNERVATE",         tip="Innervate"},
    {id=27223, key="DEATH_COIL",        tip="Death Coil"},
    {id=27090, key="COUNTERSPELL",      tip="Counterspell / Spell Lock"},
}

function UI:_PopulateIconRows()
    local f = self.frame; if not f then return end
    local ICON_SIZE = 22
    local SPACING = 2

    local function place(parent, defs)
        local x = 0
        local icons = {}
        for i, d in ipairs(defs) do
            local btn = makeIcon(parent, ICON_SIZE)
            if btn then
                btn:SetPoint("LEFT", parent, "LEFT", x, 0)
                local tex = spellIcon(d.id)
                if tex then btn.tex:SetTexture(tex) end
                btn.spellID = d.id   -- v2.0.1: feeds GameTooltip:SetSpellByID for locale-correct tooltip
                btn.tooltip = d.tip  -- english fallback when no WoW API
                btn:SetAlpha(0.4)   -- start dim
                icons[d.key] = btn
                x = x + ICON_SIZE + SPACING
            end
        end
        return icons
    end

    f.friendlyIconMap = place(f.friendlyRow, self.friendlyIcons)
    f.enemyIconMap    = place(f.enemyRow, self.enemyIcons)
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

function UI:Show()
    if self.frame then self.frame:Show() end
end
function UI:Hide()
    if self.frame then self.frame:Hide() end
end
function UI:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end

function UI:Apply(recommendation)
    local f = self.frame; if not f or not recommendation then return end

    -- M12 #77: compact mode. When toggled in SavedVariables, the frame
    -- hides the friendly + enemy icon rows so the recommendation block
    -- alone occupies the smallest possible footprint. Toggles update
    -- on next Apply so the user just sees the change after re-evaluation.
    local compact = (ArenaCoachTBCDB and ArenaCoachTBCDB.frame
        and ArenaCoachTBCDB.frame.compactMode) or false
    if f.friendlyRow then
        if compact then f.friendlyRow:Hide() else f.friendlyRow:Show() end
    end
    if f.enemyRow then
        if compact then f.enemyRow:Hide() else f.enemyRow:Show() end
    end

    local mode = recommendation.mode or "RESET"
    local color = modeColors[mode] or {1, 1, 1}
    local label = L(mode)
    local target = recommendation.primaryTargetName
                or recommendation.primaryTargetClass
                or ""

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
    -- "how close is he to dead". Hidden on DEFEND / RESET (no target)
    -- and when health / kill-prob data are unavailable.
    if f.statsText then
        local parts = {}
        if showTarget and recommendation.primaryTargetHp then
            local hp = math.floor((recommendation.primaryTargetHp * 100) + 0.5)
            table.insert(parts, string.format("%s %d%%", L("UI_HP_LABEL"), hp))
        end
        if showTarget and recommendation.killProb then
            local kp = math.floor((recommendation.killProb * 100) + 0.5)
            table.insert(parts, string.format("%s %d%%", L("UI_KILL_PROB_LABEL"), kp))
        end
        if recommendation.burstAllowed and mode == "KILL" then
            table.insert(parts, L("UI_BURST_READY"))
        end
        f.statsText:SetText(table.concat(parts, "   "))
    end

    local subParts = {}
    -- v2.1.3: prefer the localized reasonKey when set (DEFEND / RESET
    -- modes have stable reason codes). Falls back to the English
    -- debug `reason` string for KILL / SWAP / OPEN where the reason
    -- carries variable score-contributor data.
    if recommendation.reasonKey then
        table.insert(subParts, L(recommendation.reasonKey))
    elseif recommendation.reason then
        table.insert(subParts, recommendation.reason)
    end
    if recommendation.callouts and #recommendation.callouts > 0 then
        local labels = {}
        for _, key in ipairs(recommendation.callouts) do
            table.insert(labels, L(key))
        end
        table.insert(subParts, table.concat(labels, " | "))
    end
    if recommendation.comp then
        local badgeKey = recommendation.compSpecConfirmed
            and "COMP_BADGE_SPEC_CONFIRMED"
            or "COMP_BADGE_CLASS_GUESSED"
        local label = recommendation.compLabel or recommendation.comp
        table.insert(subParts, string.format("%s (%s)", label, L(badgeKey)))
    end
    -- M8 #62: render the picked chain as a localized title + numbered
    -- per-link summary, and narrate to chat once when the picked chain
    -- id changes (placeholder until M4 voice ships). Step text uses
    -- byClass + category tokens directly (spell-name localization
    -- comes from GetSpellInfo in-client; headless testing falls back
    -- to the token).
    if recommendation.chain and recommendation.chain.id ~= self._lastChainId then
        self._lastChainId = recommendation.chain.id
        local ch = recommendation.chain
        local title = (ch.labelKey and L(ch.labelKey)) or ch.label or ch.id or ""
        print(string.format("[ACC] %s: %s (%d%%)",
            L("CHAIN_PICKED_PREFIX"), title,
            math.floor(((ch.expectedProb or 0) * 100) + 0.5)))
    end
    if recommendation.chain then
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
                local stepText = string.format("  %s %d. %s (%s)",
                    L("CHAIN_STEP_PREFIX"), i,
                    spellName or tostring(link.category or "?"),
                    tostring(link.category or "?"))
                table.insert(subParts, stepText)
            end
        end
    end
    f.subText:SetText(table.concat(subParts, "\n"))

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

    -- Screen flash for URGENT (defensive) — arena only
    if inArena and recommendation.priority == "URGENT" and ArenaCoachTBCDB
       and ArenaCoachTBCDB.alerts and ArenaCoachTBCDB.alerts.screenFlash then
        self:_Flash()
    end

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
    -- edgeGlow: pulsing mode-colored band around the screen edges.
    -- nameplate: paint the kill / swap target's nameplate border so
    -- the player can identify them in a fight with multiple enemies.
    local alerts = ArenaCoachTBCDB and ArenaCoachTBCDB.alerts or nil
    local inPvP  = inArena or (ctx == "bg") or (ctx == "world")
    if ns.ScreenEdgeGlow then
        if inPvP and alerts and alerts.edgeGlow then
            ns.ScreenEdgeGlow:SetMode(mode)
        else
            ns.ScreenEdgeGlow:Hide()
        end
    end
    if ns.Nameplate then
        if inPvP and alerts and alerts.nameplate then
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

-- Brighten / dim icons depending on a "ready set" passed in
-- readyFriendly / readyEnemy : map keyed by the same `key` used in icon defs
function UI:UpdateIcons(readyFriendly, readyEnemy)
    local f = self.frame; if not f then return end
    if f.friendlyIconMap then
        for k, btn in pairs(f.friendlyIconMap) do
            btn:SetAlpha(readyFriendly and readyFriendly[k] and 1.0 or 0.4)
        end
    end
    if f.enemyIconMap then
        for k, btn in pairs(f.enemyIconMap) do
            -- For enemy icons, "ready" actually means "available to enemy"
            -- (i.e. NOT on cooldown). Highlight = enemy can use this.
            btn:SetAlpha(readyEnemy and readyEnemy[k] and 1.0 or 0.4)
        end
    end
end
