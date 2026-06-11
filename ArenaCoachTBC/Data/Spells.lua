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
S.AIMED_SHOT         = 27065  -- Aimed Shot rank 7, TBC Classic/Wowhead spell=27065
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
-- Mix of: direct casts, applied auras (Shadowform, Moonkin, Tree of
-- Life, Soul Link), and talent-only spells (Vampiric Touch, Mutilate,
-- Conflagrate, etc.) — see SpellSpecHints.byID for the spec mapping.
-- ============================================================

-- Priest
S.SHADOWFORM         = 15473   -- aura - SHADOW
S.MIND_FLAY          = 25387   -- rank 7 - SHADOW
S.VAMPIRIC_TOUCH     = 34917   -- rank 3 - SHADOW talent
S.VAMPIRIC_EMBRACE   = 15286   -- aura - SHADOW talent
S.SILENCE_PRIEST     = 15487   -- 41-pt SHADOW talent
S.CIRCLE_OF_HEALING  = 34866   -- rank 5 - HOLY talent
S.SPIRIT_OF_REDEMPTION = 27827 -- aura - HOLY talent
S.POWER_INFUSION     = 10060   -- DISC talent

-- Paladin
S.HOLY_SHOCK         = 33072   -- rank 5 - HOLY
S.DIVINE_FAVOR       = 20216   -- HOLY talent
S.HOLY_SHIELD        = 27179   -- rank 5 - PROTECTION talent
S.AVENGERS_SHIELD    = 32699   -- rank 3 - PROTECTION talent

-- Shaman
S.EARTH_SHIELD       = 32594   -- rank 3 - RESTORATION
S.ELEMENTAL_MASTERY  = 16166   -- ELEMENTAL talent
S.MANA_TIDE_TOTEM    = 16190   -- RESTORATION talent
S.TIDAL_FORCE        = 17359   -- RESTORATION talent

-- Warrior
S.BLOODTHIRST        = 30335   -- rank 6 - FURY
S.SHIELD_SLAM        = 30356   -- rank 6 - PROTECTION talent
S.LAST_STAND         = 12975   -- PROTECTION talent

-- Druid
S.MANGLE_CAT         = 33983   -- rank 3 - FERAL (cat form)
S.MANGLE_BEAR        = 33878   -- rank 3 - FERAL (bear form)
S.MOONKIN_FORM       = 24858   -- aura - BALANCE talent
S.TREE_OF_LIFE       = 33891   -- aura - RESTORATION talent

-- Warlock
S.SIPHON_LIFE        = 30911   -- rank 6 - AFFLICTION talent
S.SOUL_LINK          = 19028   -- aura - DEMONOLOGY talent
S.CONFLAGRATE        = 27266   -- rank 6 - DESTRUCTION talent
S.SHADOWBURN         = 30546   -- rank 8 - DESTRUCTION talent
S.SHADOWFURY         = 30414   -- rank 3 - DESTRUCTION talent

-- Mage (treat ICY_VEINS above as FROST hint too)
S.ARCANE_POWER       = 12042   -- ARCANE talent
S.SLOW               = 31589   -- ARCANE talent
S.PRESENCE_OF_MIND   = 12043   -- ARCANE talent
S.PYROBLAST          = 33938   -- rank 10 - FIRE talent
S.COMBUSTION         = 11129   -- FIRE talent
S.DRAGONS_BREATH     = 33043   -- rank 4 - FIRE talent
S.SUMMON_WATER_ELEM  = 31687   -- FROST talent

-- Rogue
S.MUTILATE           = 34412   -- ASSASSINATION talent
S.COLD_BLOOD         = 14177   -- ASSASSINATION talent
S.BLADE_FLURRY       = 13877   -- COMBAT talent
S.ADRENALINE_RUSH    = 13750   -- COMBAT talent
S.SHADOWSTEP         = 36554   -- SUBTLETY talent
S.HEMORRHAGE         = 26864   -- rank 4 - SUBTLETY talent

-- Hunter
S.BESTIAL_WRATH      = 19574   -- BEAST_MASTERY talent
S.INTIMIDATION       = 19577   -- BEAST_MASTERY talent
S.SILENCING_SHOT     = 34490   -- MARKSMANSHIP talent

-- ============================================================
-- Categorised lookups
-- ============================================================

-- Healing-reduction debuffs that create a real kill window on the target.
-- Mortal Strike and Aimed Shot use the max-rank TBC Classic spell IDs above;
-- Wound Poison uses the harmful target aura IDs observed in TBC Classic data
-- (Wowhead spell=43461, plus legacy rank aura spell=13224 for private/era
-- combat logs that report rank-specific poison auras).
S.HEALING_REDUCTION_DEBUFFS = {
    [S.MORTAL_STRIKE] = "Mortal Strike",
    [S.AIMED_SHOT]    = "Aimed Shot",
    [43461]           = "Wound Poison",
    [13224]           = "Wound Poison",
}

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

-- ============================================================
-- Ranked spell IDs (v2.9)
-- CLEU carries the spell ID of the rank actually cast, and
-- CooldownTracker matches IDs exactly — so multi-rank spells need every
-- rank listed or a level-70 cast is invisible to the trackers.
-- ============================================================

-- Kick ranks 2-5. Rank 1 is S.KICK = 1766.
-- Source: https://www.wowhead.com/tbc/spell=38768 (rank 5, TBC)
S.KICK_R2            = 1767
S.KICK_R3            = 1768
S.KICK_R4            = 1769
S.KICK_R5            = 38768  -- the rank every level-70 rogue casts

-- Pummel rank 1. Rank 2 is S.PUMMEL = 6554.
-- Source: https://www.wowhead.com/tbc/spell=6552
S.PUMMEL_R1          = 6552

-- Earth Shock ranks 1-7. Rank 8 is S.EARTH_SHOCK = 25454. Interrupt
-- shamans deliberately downrank to rank 1 (8042) for mana efficiency.
-- Source: https://www.wowhead.com/tbc/spell=8042
S.EARTH_SHOCK_R1     = 8042
S.EARTH_SHOCK_R2     = 8044
S.EARTH_SHOCK_R3     = 8045
S.EARTH_SHOCK_R4     = 8046
S.EARTH_SHOCK_R5     = 10412
S.EARTH_SHOCK_R6     = 10413
S.EARTH_SHOCK_R7     = 10414

-- Counterspell cast ID. S.COUNTERSPELL = 27090 is the silenced-debuff
-- variant; the cast event carries 2139 (single rank in TBC).
-- Source: https://www.wowhead.com/tbc/spell=2139
S.COUNTERSPELL_CAST  = 2139

-- Divine Shield rank 2. Rank 1 is S.DIVINE_SHIELD = 642 — a level-70
-- paladin bubbles with 1020, so cue + tracker must know both.
-- Source: https://www.wowhead.com/tbc/spell=1020
S.DIVINE_SHIELD_R2   = 1020

-- Blessing of Protection ranks 1-2. Rank 3 is S.BLESSING_PROTECT = 10278.
-- Source: https://www.wowhead.com/tbc/spell=1022
S.BLESSING_PROTECT_R1 = 1022
S.BLESSING_PROTECT_R2 = 5599

-- Evasion rank 1. Rank 2 is S.EVASION = 26669.
-- Source: https://www.wowhead.com/tbc/spell=5277
S.EVASION_R1         = 5277

-- Vanish ranks 1-2. Rank 3 is S.VANISH = 26889.
-- Source: https://www.wowhead.com/tbc/spell=1856
S.VANISH_R1          = 1856
S.VANISH_R2          = 1857

-- Ice Block alternate ID seen on TBC-era clients alongside 27619.
-- Source: https://www.wowhead.com/tbc/spell=45438
S.ICE_BLOCK_ALT      = 45438

-- Racials that act as fear/CC breaks. Distinct from S.PVP_TRINKET_EFFECT.
-- Engine consumers should check both when reasoning about "can this enemy break a fear right now".
S.CC_BREAK_RACIALS = {
    [S.WILL_OF_THE_FORSAKEN] = "Will of the Forsaken",
}

-- Spells that grant total immunity to physical/magic damage
-- (used to suppress kill recommendation)
S.IMMUNITY_BUFFS = {
    [S.ICE_BLOCK]         = "Ice Block",
    [S.ICE_BLOCK_ALT]     = "Ice Block",
    [S.DIVINE_SHIELD]     = "Divine Shield",
    [S.E_DIVINE_SHIELD]   = "Divine Shield",
    [S.DIVINE_SHIELD_R2]  = "Divine Shield",
    [S.BLESSING_PROTECT]  = "Blessing of Protection",
    [S.E_BLESSING_PROTECT]= "Blessing of Protection",
    [S.BLESSING_PROTECT_R1] = "Blessing of Protection",
    [S.BLESSING_PROTECT_R2] = "Blessing of Protection",
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

-- ============================================================
-- Facts HUD display lists (v2.9)
-- Ordered arrays consumed by FactsHUD. Every ID here must also have a
-- duration in CooldownTracker.defaults or the countdown cell stays empty.
-- ============================================================

-- Defensive cell: the big "can we kill them right now" cooldowns.
-- Order = display priority when several are down at once (the model
-- picks the one with the shortest remaining, so order only breaks ties).
S.FACTS_DEFENSIVES = {
    S.ICE_BLOCK,           -- mage, 5m
    S.ICE_BLOCK_ALT,
    S.E_DIVINE_SHIELD,     -- paladin, 5m
    S.DIVINE_SHIELD_R2,
    S.E_BLESSING_PROTECT,  -- paladin, 5m
    S.BLESSING_PROTECT_R1,
    S.BLESSING_PROTECT_R2,
    S.CLOAK_OF_SHADOWS,    -- rogue, 2m
    S.EVASION,             -- rogue
    S.EVASION_R1,
    S.VANISH,              -- rogue
    S.VANISH_R1,
    S.VANISH_R2,
    S.DETERRENCE,          -- hunter, 5m
    S.E_PAIN_SUPPRESSION,  -- priest, 2m
    S.E_NATURES_SWIFT,     -- druid, 3m
    S.E_BARKSKIN,          -- druid, 1m
    S.SHAMANISTIC_RAGE,    -- shaman, 2m
}

-- Interrupt cell: when the enemy kick is down, every second of the
-- countdown is a free-cast window for our healer / casters.
S.FACTS_INTERRUPTS = {
    S.KICK,              -- rogue, 10s (+ ranks below)
    S.KICK_R2, S.KICK_R3, S.KICK_R4, S.KICK_R5,
    S.COUNTERSPELL,      -- mage silenced-debuff variant
    S.COUNTERSPELL_CAST, -- mage cast event, 24s
    S.SPELL_LOCK,        -- felhunter, 24s
    S.PUMMEL,            -- warrior, 10s
    S.PUMMEL_R1,
    S.EARTH_SHOCK,       -- shaman, 6s (cheapest interrupt in TBC)
    S.EARTH_SHOCK_R1, S.EARTH_SHOCK_R2, S.EARTH_SHOCK_R3,
    S.EARTH_SHOCK_R4, S.EARTH_SHOCK_R5, S.EARTH_SHOCK_R6,
    S.EARTH_SHOCK_R7,
}

-- The target's OWN full-damage immunity per class — the cooldown whose
-- absence actually opens a kill window. BoP is excluded: it is castable
-- on others, and the aura lands on the protected teammate's GUID, so a
-- BoP observation says nothing about the paladin's own escape.
S.CLASS_SELF_IMMUNITY = {
    MAGE    = { S.ICE_BLOCK, S.ICE_BLOCK_ALT },
    PALADIN = { S.E_DIVINE_SHIELD, S.DIVINE_SHIELD_R2 },
    ROGUE   = { S.CLOAK_OF_SHADOWS },
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
