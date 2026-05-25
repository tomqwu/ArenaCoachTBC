-- ArenaCoachTBC - Centralized spell ID database
-- Spell IDs are sourced from TBC 2.4.3 / TBC Classic 2.5.x.
-- They may need adjustment for TBC Anniversary; update here only.
-- All IDs intentionally kept as data so we can refresh via GetSpellInfo(id)
-- when running inside WoW.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.Spells = ns.Spells or {}

local S = ns.Spells

-- ============================================================
-- Friendly spells (own comp)
-- ============================================================

-- Warrior (Arms)
S.MORTAL_STRIKE      = 30330  -- Mortal Strike rank 6
S.HAMSTRING          = 25212
S.INTERCEPT          = 27577
S.PUMMEL             = 6554
S.SPELL_REFLECTION   = 23920
S.DEATH_WISH         = 12328
S.INTIMIDATING_SHOUT = 5246
S.OVERPOWER          = 11585

-- Shaman (Enhancement)
S.WINDFURY_TOTEM     = 8512
S.BLOODLUST          = 2825
S.HEROISM            = 32182  -- Alliance side
S.STORMSTRIKE        = 17364
S.EARTH_SHOCK        = 25454
S.PURGE              = 27626
S.GROUNDING_TOTEM    = 8177
S.TREMOR_TOTEM       = 8143
S.SHAMANISTIC_RAGE   = 30823

-- Paladin (Retribution)
S.BLESSING_FREEDOM   = 1044
S.BLESSING_PROTECT   = 10278
S.HAMMER_OF_JUSTICE  = 10308
S.REPENTANCE         = 20066
S.CLEANSE            = 4987
S.CRUSADER_STRIKE    = 35395
S.JUDGEMENT          = 20271
S.DIVINE_SHIELD      = 642
S.AVENGING_WRATH     = 31884

-- Druid (Restoration)
S.CYCLONE            = 33786
S.ENTANGLING_ROOTS   = 26989
S.NATURES_SWIFTNESS  = 17116
S.SWIFTMEND          = 18562
S.BARKSKIN           = 22812
S.INNERVATE          = 29166
S.LIFEBLOOM          = 33763
S.REJUVENATION       = 26982
S.REGROWTH           = 26980

-- Priest (Discipline)
S.DISPEL_MAGIC       = 988
S.MASS_DISPEL        = 32375
S.PAIN_SUPPRESSION   = 33206
S.PSYCHIC_SCREAM     = 10890
S.MANA_BURN          = 10876
S.POWER_WORD_SHIELD  = 25218
S.PRAYER_OF_MENDING  = 33076
S.SHADOW_WORD_DEATH  = 32996

-- ============================================================
-- Enemy / general important spells & cooldowns
-- ============================================================

-- Universal
S.PVP_TRINKET_EFFECT   = 42292  -- Shared aura applied by Medallion / Insignia of the Horde or Alliance,
                                -- Stormpike's / Defiler's Insignia, and other PvP-trinket items.
                                -- 2-minute cooldown, breaks stun + fear + movement impairing.

-- Racial CC-breaks. In TBC, these are NOT on the same cooldown as the PvP trinket,
-- so the engine tracks them as separate cooldowns. Every Man for Himself doesn't exist
-- in TBC (WotLK introduced it).
S.WILL_OF_THE_FORSAKEN = 7744   -- Undead racial - 5s immunity to fear/sleep/charm, 2m CD.
                                -- Source: https://www.wowhead.com/tbc/spell=7744

-- Mage
S.ICE_BLOCK          = 27619
S.COLD_SNAP          = 11958
S.COUNTERSPELL       = 27090
S.POLYMORPH          = 28272  -- Pig version, rank 4 area
S.POLYMORPH_SHEEP    = 12826
S.FROST_NOVA         = 27088
S.ICY_VEINS          = 12472

-- Rogue
S.CLOAK_OF_SHADOWS   = 31224
S.EVASION            = 26669
S.VANISH             = 26889
S.BLIND              = 2094
S.KIDNEY_SHOT        = 8643
S.KICK               = 1766
S.PREMEDITATION      = 14183
S.SAP                = 11297

-- Warlock
S.DEATH_COIL         = 27223
S.FEAR_LOCK          = 6215    -- Fear (warlock)
S.HOWL_OF_TERROR     = 17928
S.SPELL_LOCK         = 24259   -- Felhunter spell lock
S.FEL_DOMINATION     = 18708
S.UNSTABLE_AFFLICTION= 30108
S.CURSE_OF_TONGUES   = 11719

-- Paladin enemy (mirror)
S.E_DIVINE_SHIELD    = 642
S.E_BLESSING_PROTECT = 10278
S.E_BLESSING_FREEDOM = 1044
S.E_HAMMER_OF_JUST   = 10308

-- Druid enemy (mirror)
S.E_NATURES_SWIFT    = 17116
S.E_INNERVATE        = 29166
S.E_CYCLONE          = 33786
S.E_BARKSKIN         = 22812
S.E_HIBERNATE        = 2637

-- Priest enemy (mirror)
S.E_PAIN_SUPPRESSION = 33206
S.E_PSYCHIC_SCREAM   = 10890
S.E_DISPEL_MAGIC     = 988

-- Hunter
S.WYVERN_STING       = 27068
S.SCATTER_SHOT       = 19503
S.FREEZING_TRAP      = 14310
S.VIPER_STING        = 27018
S.DETERRENCE         = 19263
S.READINESS          = 23989

-- Shaman enemy
S.E_GROUNDING_TOTEM  = 8177
S.E_TREMOR_TOTEM     = 8143

-- Warrior enemy
S.E_INTERCEPT        = 27577
S.E_INTIMIDATING     = 5246
S.E_SPELL_REFLECT    = 23920

-- ============================================================
-- Spec-defining casts (used by SpellSpecHints inference)
-- Max-rank TBC 2.4.3 IDs unless noted. Issue #2 will audit live.
-- ============================================================
S.SHADOWFORM         = 15473   -- Priest shadowform aura - SHADOW
S.MIND_FLAY          = 25387   -- Rank 7 - SHADOW
S.HOLY_SHOCK         = 33072   -- Rank 5 - HOLY paladin
S.EARTH_SHIELD       = 32594   -- Rank 3 (TBC max) - RESTORATION shaman
S.BLOODTHIRST        = 30335   -- Rank 6 - FURY warrior
S.MANGLE_CAT         = 33983   -- Rank 3 - FERAL druid (cat form)

-- ============================================================
-- Categorised lookups
-- ============================================================

-- Spell -> category mapping (used by DRTracker and threat analysis)
S.CATEGORIES = {
    -- Stuns
    [S.HAMMER_OF_JUSTICE] = "STUN",
    [S.E_HAMMER_OF_JUST]  = "STUN",
    [S.KIDNEY_SHOT]       = "STUN",
    [S.INTERCEPT]         = "STUN",
    [S.E_INTERCEPT]       = "STUN",
    [S.STORMSTRIKE]       = nil,  -- not a stun

    -- Fears
    [S.PSYCHIC_SCREAM]    = "FEAR",
    [S.E_PSYCHIC_SCREAM]  = "FEAR",
    [S.FEAR_LOCK]         = "FEAR",
    [S.HOWL_OF_TERROR]    = "FEAR",
    [S.DEATH_COIL]        = "FEAR",
    [S.INTIMIDATING_SHOUT]= "FEAR",
    [S.E_INTIMIDATING]    = "FEAR",

    -- Disorients (Blind, Scatter)
    [S.BLIND]             = "DISORIENT",
    [S.SCATTER_SHOT]      = "DISORIENT",

    -- Incapacitates (Polymorph, Repentance, Sap, Wyvern, Freezing Trap, Hibernate)
    [S.POLYMORPH]         = "INCAPACITATE",
    [S.POLYMORPH_SHEEP]   = "INCAPACITATE",
    [S.REPENTANCE]        = "INCAPACITATE",
    [S.SAP]               = "INCAPACITATE",
    [S.WYVERN_STING]      = "INCAPACITATE",
    [S.FREEZING_TRAP]     = "INCAPACITATE",
    [S.E_HIBERNATE]       = "INCAPACITATE",

    -- Roots
    [S.FROST_NOVA]        = "ROOT",
    [S.ENTANGLING_ROOTS]  = "ROOT",

    -- Cyclone is its own DR
    [S.CYCLONE]           = "CYCLONE",
    [S.E_CYCLONE]         = "CYCLONE",
}

-- Racials that act as fear/CC breaks. Distinct from S.PVP_TRINKET_EFFECT.
-- Engine consumers should check both when reasoning about "can this enemy break a fear right now".
S.CC_BREAK_RACIALS = {
    [S.WILL_OF_THE_FORSAKEN] = "Will of the Forsaken",
}

-- Spells that grant total immunity to physical/magic damage
-- (used to suppress kill recommendation)
S.IMMUNITY_BUFFS = {
    [S.ICE_BLOCK]         = "Ice Block",
    [S.DIVINE_SHIELD]     = "Divine Shield",
    [S.E_DIVINE_SHIELD]   = "Divine Shield",
    [S.BLESSING_PROTECT]  = "Blessing of Protection",
    [S.E_BLESSING_PROTECT]= "Blessing of Protection",
    [S.CLOAK_OF_SHADOWS]  = "Cloak of Shadows",
}

-- Major defensives (not full immunity, but should slow kill)
S.MAJOR_DEFENSIVES = {
    [S.PAIN_SUPPRESSION]  = "Pain Suppression",
    [S.E_PAIN_SUPPRESSION]= "Pain Suppression",
    [S.BARKSKIN]          = "Barkskin",
    [S.E_BARKSKIN]        = "Barkskin",
    [S.EVASION]           = "Evasion",
    [S.SHAMANISTIC_RAGE]  = "Shamanistic Rage",
    [S.DETERRENCE]        = "Deterrence",
}

-- Spells that are purgeable buffs of high value to dispel from enemies
S.PURGEABLE = {
    [S.BLESSING_FREEDOM]  = "Blessing of Freedom",
    [S.E_BLESSING_FREEDOM]= "Blessing of Freedom",
    [S.NATURES_SWIFTNESS] = "Nature's Swiftness",
    [S.E_NATURES_SWIFT]   = "Nature's Swiftness",
    [S.ICY_VEINS]         = "Icy Veins",
}

-- Spells we want our Priest to dispel from friendlies (magic debuffs)
S.MAGIC_CC_TO_DISPEL = {
    [S.POLYMORPH]         = true,
    [S.POLYMORPH_SHEEP]   = true,
    [S.FEAR_LOCK]         = true,
    [S.HOWL_OF_TERROR]    = true,
    [S.PSYCHIC_SCREAM]    = false, -- self priest cannot dispel
    [S.E_PSYCHIC_SCREAM]  = true,
    [S.FROST_NOVA]        = true,
    [S.ENTANGLING_ROOTS]  = false, -- nature, not magic; cleanse instead
}

-- Spells our Paladin (Cleanse) can remove from friendlies (magic / poison / disease)
S.CLEANSEABLE = {
    [S.ENTANGLING_ROOTS]  = true,  -- nature root, cleanse removes magic only;
                                   -- listed for reminder text, not actual removal
    [S.HAMSTRING]         = false, -- physical
    [S.FROST_NOVA]        = true,
}

-- ============================================================
-- Helper: refresh names from WoW client when available
-- ============================================================

S.names = S.names or {}

function S:RefreshNames()
    if type(GetSpellInfo) ~= "function" then return end
    for k, v in pairs(self) do
        if type(v) == "number" and v > 0 then
            local n = GetSpellInfo(v)
            if n then self.names[v] = n end
        end
    end
end

function S:Name(spellID)
    if not spellID then return nil end
    if self.names[spellID] then return self.names[spellID] end
    if type(GetSpellInfo) == "function" then
        local n = GetSpellInfo(spellID)
        if n then self.names[spellID] = n end
        return n
    end
    return tostring(spellID)
end

-- Reverse lookup: name -> id (best-effort, used for combat log fallbacks)
function S:IdByName(name)
    if not name then return nil end
    for k, v in pairs(self) do
        if type(v) == "number" then
            if self:Name(v) == name then
                return v
            end
        end
    end
    return nil
end
