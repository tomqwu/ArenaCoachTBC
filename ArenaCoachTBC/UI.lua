-- ArenaCoachTBC - UI layer
-- One movable frame that shows the current recommendation (mode, target,
-- HP%, kill prob, callouts). Driven event-by-event from Core; no polling.
-- v2.2.0 added two peripheral visual layers wired in here: a pulsing
-- mode-coloured thin edge cue (ScreenEdgeGlow.lua) and a coloured
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
    f:SetSize(400, 218)
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

    -- v2.8.1: Japanese-arcade-style warning plate. This is just a big,
    -- passive text cue inside the HUD, never a fullscreen flash.
    f.arcadeText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    f.arcadeText:SetPoint("TOP", f.title, "BOTTOM", 0, -4)
    if f.arcadeText.SetFont then
        local fontPath = (f.arcadeText.GetFont and select(1, f.arcadeText:GetFont()))
            or "Fonts\\FRIZQT__.TTF"
        pcall(f.arcadeText.SetFont, f.arcadeText, fontPath, 28, "THICKOUTLINE")
    end
    f.arcadeText:SetJustifyH("CENTER")
    f.arcadeText:SetWidth(370)
    f.arcadeText:SetText("")

    -- Big recommendation line ("KILL: Warlock"). v2.1.6: enlarged from
    -- GameFontNormalHuge (~22pt) to a custom 32pt outlined font so the
    -- mode label is readable at a glance from across the screen.
    f.bigText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    f.bigText:SetPoint("TOP", f.arcadeText, "BOTTOM", 0, -6)
    if f.bigText.SetFont then
        local fontPath = (f.bigText.GetFont and select(1, f.bigText:GetFont()))
            or "Fonts\\FRIZQT__.TTF"
        pcall(f.bigText.SetFont, f.bigText, fontPath, 32, "OUTLINE")
    end
    f.bigText:SetText(L("REASON_DEFAULT"))

    -- v2.1.6: target stats row (HP% + kill prob%) under the mode line.
    -- v2.6.0: bumped from GameFontHighlight (~12pt) to 18pt outlined +
    -- wider vertical spacing so the stats line is readable at a glance,
    -- not just under careful inspection. UI:Apply colour-codes the
    -- segments inline (HP white, kill prob graded, BURST READY gold).
    f.statsText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.statsText:SetPoint("TOP", f.bigText, "BOTTOM", 0, -8)
    if f.statsText.SetFont then
        local fontPath = (f.statsText.GetFont and select(1, f.statsText:GetFont()))
            or "Fonts\\FRIZQT__.TTF"
        pcall(f.statsText.SetFont, f.statsText, fontPath, 18, "OUTLINE")
    end
    f.statsText:SetJustifyH("CENTER")
    f.statsText:SetWidth(340)
    f.statsText:SetText("")

    -- Reason / callout text.
    -- v2.6.0: wider line spacing + a touch larger so the subText doesn't
    -- crowd the stats line above. SetSpacing adds vertical gap between
    -- wrapped lines / explicit \n breaks.
    f.subText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.subText:SetPoint("TOP", f.statsText, "BOTTOM", 0, -8)
    if f.subText.SetSpacing then pcall(f.subText.SetSpacing, f.subText, 3) end
    f.subText:SetJustifyH("CENTER")
    f.subText:SetWidth(340)
    f.subText:SetText("")

    -- DBM-style per-player assignments. These are plain advice lines from
    -- StrategyEngine, never clickable or protected-action buttons.
    f.actionText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.actionText:SetPoint("TOP", f.subText, "BOTTOM", 0, -8)
    if f.actionText.SetSpacing then pcall(f.actionText.SetSpacing, f.actionText, 2) end
    f.actionText:SetJustifyH("LEFT")
    f.actionText:SetWidth(370)
    f.actionText:SetText("")

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

local function formatPlayerActions(actions)
    if not actions or #actions == 0 then return "" end
    local lines = { "|cffc8a86b" .. L("UI_ACTIONS_HEADER") .. "|r" }
    for i = 1, math.min(#actions, 5) do
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
                        string.format("%s  %s", calloutIcon(key, 18), L(key)))
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
                    string.format("%s  %s", calloutIcon(top, 18), L(top)))
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
    if f.actionText then
        f.actionText:SetText(formatPlayerActions(recommendation.playerActions))
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
    -- can demo the full HUD (text + glow + nameplate) without being
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
