-- ArenaCoachTBC - Spell -> spec/role inference hints
--
-- Pure data module. Loaded after Data/Spells.lua so it can reference S.*
-- by symbolic name. Each entry maps a spell ID observed in the combat log
-- (cast or applied aura) to a {spec, role} pair the engine treats as
-- "high-confidence" evidence about the caster.
--
-- Hints are conservative: only spec-defining casts, talent-only spells,
-- and spec-defining auras (Shadowform, Moonkin, Tree of Life, Soul Link)
-- are listed. Spells castable by every spec (e.g. Mind Blast - any
-- priest, Frostbolt - any mage) are NOT here, because they would
-- mislabel an enemy.
--
-- When the engine observes a cast or aura applied that resolves to a
-- hint, it updates enemy.specGuess and enemy.roleGuess. The default
-- Classes:DefaultRole(...) is only used until the first informative
-- observation.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.SpellSpecHints = ns.SpellSpecHints or {}

local H = ns.SpellSpecHints
local S = ns.Spells

H.byID = {
    -- ============================================================
    -- Priest
    -- ============================================================
    [S.SHADOWFORM]           = { spec = "SHADOW",       role = "CASTER" },
    [S.MIND_FLAY]            = { spec = "SHADOW",       role = "CASTER" },
    [S.VAMPIRIC_TOUCH]       = { spec = "SHADOW",       role = "CASTER" },
    [S.VAMPIRIC_EMBRACE]     = { spec = "SHADOW",       role = "CASTER" },
    [S.SILENCE_PRIEST]       = { spec = "SHADOW",       role = "CASTER" },
    [S.CIRCLE_OF_HEALING]    = { spec = "HOLY",         role = "HEALER" },
    [S.SPIRIT_OF_REDEMPTION] = { spec = "HOLY",         role = "HEALER" },
    [S.PAIN_SUPPRESSION]     = { spec = "DISCIPLINE",   role = "HEALER" },
    [S.POWER_INFUSION]       = { spec = "DISCIPLINE",   role = "HEALER" },

    -- ============================================================
    -- Paladin
    -- ============================================================
    [S.HOLY_SHOCK]           = { spec = "HOLY",         role = "HEALER" },
    [S.DIVINE_FAVOR]         = { spec = "HOLY",         role = "HEALER" },
    [S.HOLY_SHIELD]          = { spec = "PROTECTION",   role = "MELEE"  },
    [S.AVENGERS_SHIELD]      = { spec = "PROTECTION",   role = "MELEE"  },
    [S.CRUSADER_STRIKE]      = { spec = "RETRIBUTION",  role = "MELEE"  },
    [S.REPENTANCE]           = { spec = "RETRIBUTION",  role = "MELEE"  },

    -- ============================================================
    -- Shaman
    -- ============================================================
    [S.EARTH_SHIELD]         = { spec = "RESTORATION",  role = "HEALER" },
    [S.MANA_TIDE_TOTEM]      = { spec = "RESTORATION",  role = "HEALER" },
    [S.TIDAL_FORCE]          = { spec = "RESTORATION",  role = "HEALER" },
    [S.STORMSTRIKE]          = { spec = "ENHANCEMENT",  role = "MELEE"  },
    [S.SHAMANISTIC_RAGE]     = { spec = "ENHANCEMENT",  role = "MELEE"  },
    [S.ELEMENTAL_MASTERY]    = { spec = "ELEMENTAL",    role = "CASTER" },

    -- ============================================================
    -- Warrior
    -- ============================================================
    [S.MORTAL_STRIKE]        = { spec = "ARMS",         role = "MELEE"  },
    [S.BLOODTHIRST]          = { spec = "FURY",         role = "MELEE"  },
    [S.SHIELD_SLAM]          = { spec = "PROTECTION",   role = "MELEE"  },
    [S.LAST_STAND]           = { spec = "PROTECTION",   role = "MELEE"  },

    -- ============================================================
    -- Druid
    -- ============================================================
    [S.LIFEBLOOM]            = { spec = "RESTORATION",  role = "HEALER" },
    [S.SWIFTMEND]            = { spec = "RESTORATION",  role = "HEALER" },
    [S.TREE_OF_LIFE]         = { spec = "RESTORATION",  role = "HEALER" },
    [S.MANGLE_CAT]           = { spec = "FERAL",        role = "MELEE"  },
    [S.MANGLE_BEAR]          = { spec = "FERAL",        role = "MELEE"  },
    [S.MOONKIN_FORM]         = { spec = "BALANCE",      role = "CASTER" },

    -- ============================================================
    -- Warlock
    -- ============================================================
    [S.UNSTABLE_AFFLICTION]  = { spec = "AFFLICTION",   role = "CASTER" },
    [S.SIPHON_LIFE]          = { spec = "AFFLICTION",   role = "CASTER" },
    [S.SOUL_LINK]            = { spec = "DEMONOLOGY",   role = "CASTER" },
    [S.CONFLAGRATE]          = { spec = "DESTRUCTION",  role = "CASTER" },
    [S.SHADOWBURN]           = { spec = "DESTRUCTION",  role = "CASTER" },
    [S.SHADOWFURY]           = { spec = "DESTRUCTION",  role = "CASTER" },

    -- ============================================================
    -- Mage
    -- ============================================================
    [S.ARCANE_POWER]         = { spec = "ARCANE",       role = "CASTER" },
    [S.SLOW]                 = { spec = "ARCANE",       role = "CASTER" },
    [S.PRESENCE_OF_MIND]     = { spec = "ARCANE",       role = "CASTER" },
    [S.PYROBLAST]            = { spec = "FIRE",         role = "CASTER" },
    [S.COMBUSTION]           = { spec = "FIRE",         role = "CASTER" },
    [S.DRAGONS_BREATH]       = { spec = "FIRE",         role = "CASTER" },
    [S.ICY_VEINS]            = { spec = "FROST",        role = "CASTER" },
    [S.SUMMON_WATER_ELEM]    = { spec = "FROST",        role = "CASTER" },

    -- ============================================================
    -- Rogue
    -- ============================================================
    [S.MUTILATE]             = { spec = "ASSASSINATION",role = "MELEE"  },
    [S.COLD_BLOOD]           = { spec = "ASSASSINATION",role = "MELEE"  },
    [S.BLADE_FLURRY]         = { spec = "COMBAT",       role = "MELEE"  },
    [S.ADRENALINE_RUSH]      = { spec = "COMBAT",       role = "MELEE"  },
    [S.PREMEDITATION]        = { spec = "SUBTLETY",     role = "MELEE"  },
    [S.SHADOWSTEP]           = { spec = "SUBTLETY",     role = "MELEE"  },
    [S.HEMORRHAGE]           = { spec = "SUBTLETY",     role = "MELEE"  },

    -- ============================================================
    -- Hunter
    -- ============================================================
    [S.BESTIAL_WRATH]        = { spec = "BEAST_MASTERY",role = "RANGED" },
    [S.INTIMIDATION]         = { spec = "BEAST_MASTERY",role = "RANGED" },
    [S.SILENCING_SHOT]       = { spec = "MARKSMANSHIP", role = "RANGED" },
    [S.READINESS]            = { spec = "MARKSMANSHIP", role = "RANGED" },
    [S.WYVERN_STING]         = { spec = "SURVIVAL",     role = "RANGED" },
}

function H:Lookup(spellID)
    if not spellID then return nil end
    return self.byID[spellID]
end

-- Apply a hint to an enemy model in-place. Returns true if the model changed,
-- so the caller can drive comp re-identification.
function H:Apply(enemy, spellID)
    if not enemy or not spellID then return false end
    local hint = self.byID[spellID]
    if not hint then return false end
    local changed = false
    if enemy.specGuess ~= hint.spec then enemy.specGuess = hint.spec; changed = true end
    if enemy.roleGuess ~= hint.role then enemy.roleGuess = hint.role; changed = true end
    return changed
end
