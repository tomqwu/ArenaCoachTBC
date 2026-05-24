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
