-- ArenaCleaveCoachTBC - Options
-- Slash-command-driven configuration. We keep a thin InterfaceOptionsPanel
-- shell so the addon shows up in the Blizzard options panel and links the
-- user to /acc help.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.Options = ns.Options or {}

local OPT = ns.Options

-- Pull localized string (delegated to Core)
local function L(key, ...)
    if ns.Core and ns.Core.L then
        local s = ns.Core.L(key)
        if select("#", ...) > 0 then return string.format(s, ...) end
        return s
    end
    return key
end

function OPT:BuildPanel()
    if type(CreateFrame) ~= "function" then return nil end

    local panel = CreateFrame("Frame", "ArenaCleaveCoachTBCOptionsPanel", UIParent)
    panel.name = "ArenaCleaveCoachTBC"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("ArenaCleaveCoachTBC")

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetText(
        "Strategy coach for TBC 5v5 melee cleave.\n" ..
        "Use /acc help in chat for full command list.\n\n" ..
        "Commands: /acc toggle | /acc lock | /acc unlock | /acc test | /acc debug |\n" ..
        "/acc reset | /acc strategy safe|balanced|greedy | /acc enemy <c1>..<c5> | /acc help"
    )

    -- Enable checkbox
    local enabled = CreateFrame("CheckButton", "ACCEnabledCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    enabled:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -24)
    enabled.Text:SetText("Enabled")
    enabled:SetScript("OnClick", function(self)
        if ArenaCleaveCoachTBCDB then
            ArenaCleaveCoachTBCDB.enabled = self:GetChecked() and true or false
        end
    end)

    -- Lock frame checkbox
    local lockcb = CreateFrame("CheckButton", "ACCLockCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    lockcb:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -4)
    lockcb.Text:SetText("Lock frame")
    lockcb:SetScript("OnClick", function(self)
        if ArenaCleaveCoachTBCDB then
            ArenaCleaveCoachTBCDB.locked = self:GetChecked() and true or false
        end
    end)

    -- Sound
    local sound = CreateFrame("CheckButton", "ACCSoundCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    sound:SetPoint("TOPLEFT", lockcb, "BOTTOMLEFT", 0, -4)
    sound.Text:SetText("Play sound on urgent callout")
    sound:SetScript("OnClick", function(self)
        if ArenaCleaveCoachTBCDB then
            ArenaCleaveCoachTBCDB.alerts.sound = self:GetChecked() and true or false
        end
    end)

    -- Debug
    local debug = CreateFrame("CheckButton", "ACCDebugCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    debug:SetPoint("TOPLEFT", sound, "BOTTOMLEFT", 0, -4)
    debug.Text:SetText("Debug logging")
    debug:SetScript("OnClick", function(self)
        if ArenaCleaveCoachTBCDB then
            ArenaCleaveCoachTBCDB.debug = self:GetChecked() and true or false
        end
    end)

    -- Party chat callouts
    local pchat = CreateFrame("CheckButton", "ACCPartyChatCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    pchat:SetPoint("TOPLEFT", debug, "BOTTOMLEFT", 0, -4)
    pchat.Text:SetText("Print callouts to party chat")
    pchat:SetScript("OnClick", function(self)
        if ArenaCleaveCoachTBCDB then
            ArenaCleaveCoachTBCDB.alerts.partyChat = self:GetChecked() and true or false
        end
    end)

    -- Aggression label
    local aggLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    aggLabel:SetPoint("TOPLEFT", pchat, "BOTTOMLEFT", 0, -16)
    aggLabel:SetText("Aggression: type /acc strategy safe|balanced|greedy")

    -- Refresh widgets from DB when panel is shown
    panel:SetScript("OnShow", function()
        local db = ArenaCleaveCoachTBCDB or {}
        enabled:SetChecked(db.enabled ~= false)
        lockcb:SetChecked(db.locked == true)
        sound:SetChecked(db.alerts and db.alerts.sound ~= false)
        debug:SetChecked(db.debug == true)
        pchat:SetChecked(db.alerts and db.alerts.partyChat == true)
    end)

    -- Register with the Blizzard options system. Two APIs exist across
    -- Classic versions; try the modern one first.
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    end

    self.panel = panel
    return panel
end

function OPT:Apply(db)
    -- Hooks for any future computed-side-effects. The widgets already
    -- write straight to ArenaCleaveCoachTBCDB, so nothing else to do here yet.
end
