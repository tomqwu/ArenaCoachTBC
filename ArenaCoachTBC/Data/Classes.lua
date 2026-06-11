-- ArenaCoachTBC - Class/spec/role classification data
-- These tables map class -> default role assumptions used by the
-- strategy engine. Spec guesses are best-effort because TBC has no
-- direct API for inspecting opposing arena specs without inspecting.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.Classes = ns.Classes or {}

local C = ns.Classes

-- Role constants
C.ROLE_HEALER  = "HEALER"
C.ROLE_CASTER  = "CASTER"
C.ROLE_MELEE   = "MELEE"
C.ROLE_RANGED  = "RANGED"
C.ROLE_HYBRID  = "HYBRID"

-- Armor (used by purge / cloth-dps detection)
C.ARMOR_CLOTH   = "CLOTH"
C.ARMOR_LEATHER = "LEATHER"
C.ARMOR_MAIL    = "MAIL"
C.ARMOR_PLATE   = "PLATE"

-- Class info table
-- defaultRole is what we assume when we don't yet know the spec.
-- possibleRoles lists what an enemy of this class can be (used by analysis).
C.info = {
    WARRIOR = {
        armor          = C.ARMOR_PLATE,
        defaultRole    = C.ROLE_MELEE,
        possibleRoles  = { C.ROLE_MELEE },
        canDispel      = false,
        canPurge       = false,
        possibleSpecs  = { "ARMS", "FURY", "PROTECTION" },
    },
    SHAMAN = {
        armor          = C.ARMOR_MAIL,
        defaultRole    = C.ROLE_HYBRID,
        possibleRoles  = { C.ROLE_MELEE, C.ROLE_CASTER, C.ROLE_HEALER },
        canDispel      = true,   -- via Cleanse Spirit / Purge
        canPurge       = true,
        possibleSpecs  = { "ELEMENTAL", "ENHANCEMENT", "RESTORATION" },
    },
    PALADIN = {
        armor          = C.ARMOR_PLATE,
        defaultRole    = C.ROLE_HYBRID,
        possibleRoles  = { C.ROLE_MELEE, C.ROLE_HEALER },
        canDispel      = true,
        canPurge       = false,
        possibleSpecs  = { "HOLY", "PROTECTION", "RETRIBUTION" },
    },
    DRUID = {
        armor          = C.ARMOR_LEATHER,
        defaultRole    = C.ROLE_HEALER,  -- in TBC arena, druids are mostly resto
        possibleRoles  = { C.ROLE_MELEE, C.ROLE_CASTER, C.ROLE_HEALER },
        canDispel      = false,
        canPurge       = false,
        possibleSpecs  = { "BALANCE", "FERAL", "RESTORATION" },
    },
    PRIEST = {
        armor          = C.ARMOR_CLOTH,
        defaultRole    = C.ROLE_HEALER,
        possibleRoles  = { C.ROLE_HEALER, C.ROLE_CASTER },
        canDispel      = true,
        canPurge       = false,
        possibleSpecs  = { "DISCIPLINE", "HOLY", "SHADOW" },
    },
    MAGE = {
        armor          = C.ARMOR_CLOTH,
        defaultRole    = C.ROLE_CASTER,
        possibleRoles  = { C.ROLE_CASTER },
        canDispel      = false,
        canPurge       = false,
        possibleSpecs  = { "ARCANE", "FIRE", "FROST" },
    },
    WARLOCK = {
        armor          = C.ARMOR_CLOTH,
        defaultRole    = C.ROLE_CASTER,
        possibleRoles  = { C.ROLE_CASTER },
        canDispel      = false,
        canPurge       = false,
        possibleSpecs  = { "AFFLICTION", "DEMONOLOGY", "DESTRUCTION" },
    },
    ROGUE = {
        armor          = C.ARMOR_LEATHER,
        defaultRole    = C.ROLE_MELEE,
        possibleRoles  = { C.ROLE_MELEE },
        canDispel      = false,
        canPurge       = false,
        possibleSpecs  = { "ASSASSINATION", "COMBAT", "SUBTLETY" },
    },
    HUNTER = {
        armor          = C.ARMOR_MAIL,
        defaultRole    = C.ROLE_RANGED,
        possibleRoles  = { C.ROLE_RANGED },
        canDispel      = false,
        canPurge       = false,
        possibleSpecs  = { "BEAST_MASTERY", "MARKSMANSHIP", "SURVIVAL" },
    },
}

-- Returns class info or a safe empty table
function C:Info(class)
    if not class then return {} end
    return self.info[class:upper()] or {}
end

-- Returns the default role assumption for an unknown-spec enemy
function C:DefaultRole(class)
    return (self:Info(class)).defaultRole or C.ROLE_MELEE
end

-- Returns true if the class is a cloth caster (squishy)
function C:IsCloth(class)
    return (self:Info(class)).armor == C.ARMOR_CLOTH
end

function C:IsHealer(class, spec)
    if not class then return false end
    spec = spec and spec:upper() or nil
    if class == "PRIEST" then
        return spec == "DISCIPLINE" or spec == "HOLY" or spec == "DISC" or spec == nil
    elseif class == "DRUID" then
        return spec == "RESTORATION" or spec == "RESTO" or spec == nil
    elseif class == "PALADIN" then
        return spec == "HOLY"
    elseif class == "SHAMAN" then
        return spec == "RESTORATION" or spec == "RESTO"
    end
    return false
end

-- Normalize a short token to a full class name (used by /acc enemy commands)
C.tokens = {
    -- English short
    WAR    = "WARRIOR", WARRIOR = "WARRIOR",
    ENH    = "SHAMAN",  SHA = "SHAMAN", SHAMAN = "SHAMAN",
    RET    = "PALADIN", PAL = "PALADIN", PALADIN = "PALADIN",
    DRUID  = "DRUID",   FD  = "DRUID",   DR = "DRUID",
    PRIEST = "PRIEST",  PR  = "PRIEST",
    MAGE   = "MAGE",    MG  = "MAGE",
    LOCK   = "WARLOCK", WARLOCK = "WARLOCK", WL = "WARLOCK",
    ROGUE  = "ROGUE",   RG  = "ROGUE",
    HUNT   = "HUNTER",  HUNTER = "HUNTER", HT = "HUNTER",
}

function C:TokenToClass(token)
    if not token then return nil end
    return self.tokens[token:upper()]
end

-- ============================================================
-- Class colours (v2.10 — shared by UI alerts, FactsHUD, nameplates)
-- ============================================================
-- Stable RGB defaults match the TBC client's RAID_CLASS_COLORS table.
-- :Color() prefers the client's table when available so addon-driven
-- recolour mods (e.g. !ClassColors) propagate everywhere we render.
C.classColors = {
    WARRIOR = { 0.78, 0.61, 0.43 },  -- brown
    PALADIN = { 0.96, 0.55, 0.73 },  -- pink
    HUNTER  = { 0.67, 0.83, 0.45 },  -- green
    ROGUE   = { 1.00, 0.96, 0.41 },  -- yellow
    PRIEST  = { 1.00, 1.00, 1.00 },  -- white
    SHAMAN  = { 0.00, 0.44, 0.87 },  -- blue (Horde)
    MAGE    = { 0.41, 0.80, 0.94 },  -- light blue
    WARLOCK = { 0.58, 0.51, 0.79 },  -- purple
    DRUID   = { 1.00, 0.49, 0.04 },  -- orange
}

function C:Color(class)
    if not class then return 1, 1, 1 end
    local up = class:upper()
    local cc = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[up]
    if cc and cc.r then return cc.r, cc.g, cc.b end
    local c = self.classColors[up] or { 1, 1, 1 }
    return c[1], c[2], c[3]
end

-- |cffRRGGBB|r escape for inline-coloured text. Used by alert kickers
-- and chat output where SetTextColor isn't available per-character.
function C:ColorHex(class)
    local r, g, b = self:Color(class)
    return string.format("ff%02x%02x%02x",
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5))
end

-- Localised class display name. Falls back to the class token title-cased.
-- The WoW client's LOCALIZED_CLASS_NAMES_MALE is the standard surface;
-- accept either that or our own locale override (CLASS_<TOKEN>).
function C:DisplayName(class)
    if not class then return "" end
    local up = class:upper()
    local nm = _G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[up]
    if nm and nm ~= "" then return nm end
    -- Locale-managed override, when the addon ships a class label.
    if ns.Core and ns.Core.L then
        local key = "CLASS_" .. up
        local s = ns.Core.L(key)
        if s and s ~= key then return s end
    end
    return up:sub(1, 1) .. up:sub(2):lower()
end
