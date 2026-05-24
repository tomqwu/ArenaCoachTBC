-- ArenaCoachTBC - Spell -> spec/role inference hints
--
-- Pure data module. Loaded after Data/Spells.lua so it can reference S.*
-- by symbolic name. Each entry maps a spell ID observed in the combat log
-- to a {spec, role} pair the engine treats as "high-confidence" evidence
-- about the caster.
--
-- Hints are conservative: only spec-defining casts are listed. Spells
-- castable by every spec (e.g. Mind Blast - any priest, Frostbolt - any
-- mage) are NOT here, because they would mislabel an enemy.
--
-- When the engine observes a cast that resolves to a hint, it updates
-- enemy.specGuess and enemy.roleGuess. The default Classes:DefaultRole(...)
-- is only used until the first informative cast.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.SpellSpecHints = ns.SpellSpecHints or {}

local H = ns.SpellSpecHints
local S = ns.Spells

H.byID = {
    -- Priest
    [S.SHADOWFORM]         = { spec = "SHADOW",       role = "CASTER" },
    [S.MIND_FLAY]          = { spec = "SHADOW",       role = "CASTER" },

    -- Paladin
    [S.HOLY_SHOCK]         = { spec = "HOLY",         role = "HEALER" },
    [S.CRUSADER_STRIKE]    = { spec = "RETRIBUTION",  role = "MELEE"  },

    -- Shaman
    [S.EARTH_SHIELD]       = { spec = "RESTORATION",  role = "HEALER" },
    [S.STORMSTRIKE]        = { spec = "ENHANCEMENT",  role = "MELEE"  },

    -- Warrior
    [S.MORTAL_STRIKE]      = { spec = "ARMS",         role = "MELEE"  },
    [S.BLOODTHIRST]        = { spec = "FURY",         role = "MELEE"  },

    -- Druid
    [S.LIFEBLOOM]          = { spec = "RESTORATION",  role = "HEALER" },
    [S.MANGLE_CAT]         = { spec = "FERAL",        role = "MELEE"  },

    -- Warlock
    [S.UNSTABLE_AFFLICTION]= { spec = "AFFLICTION",   role = "CASTER" },
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
