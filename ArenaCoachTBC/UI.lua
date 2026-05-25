-- ArenaCoachTBC - UI layer
-- One movable frame that shows the current recommendation (mode, target,
-- HP%, kill prob, callouts). Driven event-by-event from Core; no polling.
-- v2.2.0 added two peripheral visual layers wired in here: a pulsing
-- mode-coloured screen-edge glow (ScreenEdgeGlow.lua) and a coloured
-- border on the kill / swap target's nameplate (Nameplate.lua). No
-- protected actions are ever bound to any visible button.

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

-- ============================================================
-- Build the main frame
-- ============================================================
function UI:CreateFrame()
    if self.frame then return self.frame end
    if type(CreateFrame) ~= "function" then return nil end

    local db = ArenaCoachTBCDB or {}
    local fcfg = db.frame or { point = "CENTER", x = 0, y = 120, scale = 1.0 }

    local f = CreateFrame("Frame", "ArenaCoachTBCFrame", UIParent)
    -- v2.2.1: dropped the icon rows + 60px of vertical space.
    f:SetSize(360, 110)
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
    return f
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
        if ns.ScreenEdgeGlow then ns.ScreenEdgeGlow:Hide() end
        if ns.Nameplate then ns.Nameplate:ClearAll() end
        return
    end
    if not f:IsShown() then f:Show() end

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
    end
    -- v2.3.1: do NOT render recommendation.reason for KILL/SWAP/OPEN. The
    -- raw field is dev-only — it carries internal score-contributor
    -- identifiers ("PRIEST [role_healer(25), trinket_down(20), ...] |
    -- RMP_DISC_3V3 spec-confirmed (1.00)") meant for /acc trace dump.
    -- The mode label, target name, target stats row, callouts list, comp
    -- badge, and chain block together already say everything the user
    -- needs. Pre-v2.3.1 the user saw these underscore identifiers in
    -- the frame and read them as untranslated gibberish.
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
        -- Prefer the human-readable compLabel ("RMP (confirmed Disc Priest)")
        -- over the raw comp id ("RMP_DISC_3V3") that pre-v2.3.1 sometimes
        -- leaked here when the engine forgot to set compLabel.
        local label = recommendation.compLabel
        if not label or label == "" then label = "?" end
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
                -- v2.3.1: drop the redundant "(CATEGORY)" suffix when the
                -- spell name is available. Pre-v2.3.1 every line rendered
                -- as "Step 1. Sap (INCAPACITATE)" — the category was
                -- already implicit in the chain title and just added
                -- noise. When GetSpellInfo returns nil (very first call
                -- on an unknown spell) we still fall back to the
                -- category enum so the line is never blank.
                local label = spellName or tostring(link.category or "?")
                local stepText = string.format("  %s %d. %s",
                    L("CHAIN_STEP_PREFIX"), i, label)
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
    -- v2.3.0: `forceShow` also bypasses the inPvP gate so /acc test
    -- can demo the full HUD (text + glow + nameplate) without being
    -- in arena/BG/world. Pre-v2.3.0 the demo only painted the text.
    --
    -- edgeGlow: pulsing mode-colored band around the screen edges.
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
