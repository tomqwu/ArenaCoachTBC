-- ArenaCoachTBC - Composition signature -> recommended openers and callouts
-- The intent is to keep "what to do vs this comp" data-driven so it can be
-- expanded without touching the engine.
--
-- Signatures are *unordered* class sets. We sort and join classes to derive
-- a deterministic key, e.g.:
--   { MAGE, PRIEST, ROGUE } -> "MAGE_PRIEST_ROGUE"
-- Partial matches (3 of 5) are allowed via the "core" field. The engine
-- iterates compositions in declaration order; the first whose `core` set is
-- a subset of the enemy team wins.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.Strategies = ns.Strategies or {}

local ST = ns.Strategies

-- Canonical comp catalog. Each entry can specify:
--   id          : short name
--   label       : friendly description
--   core        : minimal set of classes that defines this comp
--   specs       : optional { CLASS = "SPEC" } map of *required* enemy specs.
--                 A spec-keyed entry matches only when every required spec is
--                 explicitly observed on an alive enemy of that class (via
--                 e.specGuess from SpellSpecHints). Unknown or mismatched
--                 specs disqualify the entry, so a class-only sibling
--                 declared later catches it as a fallback. Spec-keyed entries
--                 should therefore be declared BEFORE their class-only
--                 counterpart so they win when specs are confirmed.
--   bracket     : optional 2|3|5. Only matches when state.bracket equals this
--                 value; nil means bracket-agnostic (matches anywhere).
--                 Bracket-specific entries win over agnostic ones.
--   openTarget  : class to suggest opening on (if alive)
--   swapTarget  : class to consider swapping to
--   threats     : { class -> top danger note }
--   callouts    : ordered list of callout keys (resolved via locale)
--   defensiveTriggers : optional list of trigger names that force DEFEND
--   ownVariants : optional { ownArchetype -> overrides } so a single enemy
--                 entry can give different advice to different own teams.
--   chains      : optional list of canonical CC setups this comp tends to
--                 run, used by the M8 chain planner. Each entry is
--                 { id, label, links = { {spellID,category,byClass,targetRole}, ... } }.
--                 byClass references a class in `core`; targetRole is one
--                 of "primary" / "off-healer" / "any" and is resolved
--                 against the live state at evaluation time.
local S = ns.Spells

ST.comps = {
    -- ============================================================
    -- "RMP" family (rogue + mage + priest), the canonical TBC comp.
    -- ============================================================
    {
        id    = "RMP",
        label = "Rogue / Mage / Priest",
        core  = { MAGE = true, PRIEST = true, ROGUE = true },
        openTarget = "PRIEST",
        swapTarget = "MAGE",
        threats = {
            MAGE   = "Polymorph + burst",
            ROGUE  = "Cheap Shot opener / Blind",
            PRIEST = "Fear chain",
        },
        callouts = {
            "CALL_TREMOR_FEAR",
            "CALL_GROUND_POLY",
            "CALL_FREEDOM_WAR",
            "CALL_DISP_POLY",
        },
        ownVariants = {
            MELEE_CLEAVE = { openTarget = "PRIEST", swapTarget = "MAGE" },
            DRAIN        = { openTarget = nil,     swapTarget = "PRIEST", note = "drain mage mana, force defensives" },
            JUNGLE       = { openTarget = "MAGE",  swapTarget = "PRIEST", note = "scatter+fear chain on mage" },
        },
        chains = {
            { id = "rmp_sap_into_kidney", labelKey = "CHAIN_RMP_SAP_INTO_KIDNEY",
              label = "Sap off-healer, kidney the kill target",
              links = {
                  { spellID = S.SAP,          category = "INCAPACITATE", byClass = "ROGUE", targetRole = "off-healer" },
                  { spellID = S.POLYMORPH,    category = "INCAPACITATE", byClass = "MAGE",  targetRole = "off-healer-2" },
                  { spellID = S.KIDNEY_SHOT,  category = "STUN",         byClass = "ROGUE", targetRole = "primary" },
              } },
            { id = "rmp_fear_into_burst", labelKey = "CHAIN_RMP_FEAR_INTO_BURST",
              label = "Psychic scream lockdown into mage burst",
              links = {
                  { spellID = S.PSYCHIC_SCREAM, category = "FEAR",         byClass = "PRIEST", targetRole = "any" },
                  { spellID = S.POLYMORPH,      category = "INCAPACITATE", byClass = "MAGE",   targetRole = "off-healer" },
              } },
        },
    },
    -- WMS = Warrior / Mage / Shaman ("Battlecleave")
    {
        id    = "WMS",
        label = "Warrior / Mage / Shaman (Battlecleave)",
        core  = { WARRIOR = true, MAGE = true, SHAMAN = true },
        openTarget = "MAGE",
        swapTarget = "SHAMAN",
        callouts = { "CALL_PURGE", "CALL_TREMOR_FEAR", "CALL_FREEDOM_WAR" },
        chains = {
            { id = "wms_sheep_into_train", labelKey = "CHAIN_WMS_SHEEP_INTO_TRAIN",
              label = "Sheep healer, MS train the kill target",
              links = {
                  { spellID = S.POLYMORPH,        category = "INCAPACITATE", byClass = "MAGE",    targetRole = "off-healer" },
                  { spellID = S.INTIMIDATING_SHOUT, category = "FEAR",        byClass = "WARRIOR", targetRole = "any" },
              } },
        },
    },
    -- Warlock/Druid/X
    {
        id    = "WLD",
        label = "Warlock / Druid / X",
        core  = { WARLOCK = true, DRUID = true },
        openTarget = "WARLOCK",
        swapTarget = "DRUID",
        threats = {
            WARLOCK = "Fear / Death Coil / Unstable Affliction",
            DRUID   = "Cyclone / kite",
        },
        callouts = {
            "CALL_TREMOR_FEAR",
            "CALL_GROUND_DC",
            "CALL_PURGE",
            "CALL_HOJ_KILL",
        },
        ownVariants = {
            MELEE_CLEAVE = { openTarget = "WARLOCK", swapTarget = "DRUID" },
            DRAIN        = { openTarget = nil, note = "outlast, mana burn druid" },
        },
        chains = {
            { id = "wld_fear_into_cyclone", labelKey = "CHAIN_WLD_FEAR_INTO_CYCLONE",
              label = "Lock fear chain into druid cyclone peel",
              links = {
                  { spellID = S.HOWL_OF_TERROR, category = "FEAR",    byClass = "WARLOCK", targetRole = "any" },
                  { spellID = S.CYCLONE,        category = "CYCLONE", byClass = "DRUID",   targetRole = "off-healer" },
              } },
        },
    },
    -- Warlock / Shaman cleave
    {
        id    = "WLS",
        label = "Warlock / Shaman",
        core  = { WARLOCK = true, SHAMAN = true },
        openTarget = "SHAMAN",
        swapTarget = "WARLOCK",
        callouts = { "CALL_PURGE", "CALL_TREMOR_FEAR" },
    },
    -- Warlock / Paladin "drain"
    {
        id    = "WLP",
        label = "Warlock / Paladin (Drain)",
        core  = { WARLOCK = true, PALADIN = true },
        openTarget = "PALADIN",
        swapTarget = "WARLOCK",
        callouts = { "CALL_PURGE", "CALL_MANA_BURN_PLAN" },
        chains = {
            { id = "wlp_fear_into_hoj", labelKey = "CHAIN_WLP_FEAR_INTO_HOJ",
              label = "Fear chain into Hammer of Justice on the paladin",
              links = {
                  { spellID = S.FEAR_LOCK,         category = "FEAR", byClass = "WARLOCK", targetRole = "any" },
                  { spellID = S.HAMMER_OF_JUSTICE, category = "STUN", byClass = "PALADIN", targetRole = "primary" },
              } },
        },
    },
    -- ============================================================
    -- Hunter comps
    -- ============================================================
    {
        id    = "HUNTER_COMP",
        label = "Hunter / Druid / X",
        core  = { HUNTER = true, DRUID = true },
        openTarget = "HUNTER",
        swapTarget = "DRUID",
        threats = {
            HUNTER = "Mana drain / kite",
            DRUID  = "Roots / cyclone / HoT race",
        },
        callouts = {
            "CALL_FREEDOM_WAR",
            "CALL_CLEANSE_ROOTS",
            "CALL_AVOID_OVERCHASE",
        },
        chains = {
            { id = "jungle_trap_into_cyclone", labelKey = "CHAIN_JUNGLE_TRAP_INTO_CYCLONE",
              label = "Trap healer, cyclone off-target",
              links = {
                  { spellID = S.FREEZING_TRAP, category = "INCAPACITATE", byClass = "HUNTER", targetRole = "off-healer" },
                  { spellID = S.CYCLONE,       category = "CYCLONE",      byClass = "DRUID",  targetRole = "primary" },
              } },
        },
    },
    {
        id    = "BEAST_CLEAVE",
        label = "Hunter / Warrior",
        core  = { HUNTER = true, WARRIOR = true },
        openTarget = "HUNTER",
        swapTarget = "WARRIOR",
        callouts = { "CALL_FREEDOM_WAR", "CALL_AVOID_OVERCHASE" },
        chains = {
            { id = "beast_trap_into_intercept", labelKey = "CHAIN_BEAST_TRAP_INTO_INTERCEPT",
              label = "Trap kill target, warrior intercepts on land",
              links = {
                  { spellID = S.FREEZING_TRAP, category = "INCAPACITATE", byClass = "HUNTER",  targetRole = "primary" },
                  { spellID = S.SCATTER_SHOT,  category = "DISORIENT",    byClass = "HUNTER",  targetRole = "off-healer" },
                  { spellID = S.INTERCEPT,     category = "STUN",         byClass = "WARRIOR", targetRole = "primary" },
              } },
        },
    },
    -- ============================================================
    -- Paladin / Warrior / X "TSG"
    -- ============================================================
    {
        id    = "TSG",
        label = "Warrior / DK-style melee (TSG analog)",
        core  = { WARRIOR = true, PALADIN = true },
        openTarget = "PALADIN",
        swapTarget = "WARRIOR",
        callouts = { "CALL_PURGE", "CALL_HOJ_KILL" },
        chains = {
            { id = "tsg_hoj_into_intercept", labelKey = "CHAIN_TSG_HOJ_INTO_INTERCEPT",
              label = "HoJ on the priority target, intercept follow-up",
              links = {
                  { spellID = S.HAMMER_OF_JUSTICE, category = "STUN", byClass = "PALADIN", targetRole = "primary" },
                  { spellID = S.INTERCEPT,         category = "STUN", byClass = "WARRIOR", targetRole = "primary" },
              } },
        },
    },
    -- ============================================================
    -- Rogue + Druid "RLS"-style (Rogue/Lock-or-Mage/Shaman) approximations
    -- ============================================================
    {
        id    = "RLS",
        label = "Rogue / Caster / Shaman",
        core  = { ROGUE = true, SHAMAN = true },
        openTarget = "SHAMAN",
        swapTarget = "ROGUE",
        callouts = { "CALL_PURGE", "CALL_TREMOR_FEAR" },
    },
    -- ============================================================
    -- Mirror melee cleave
    -- ============================================================
    {
        id    = "MIRROR_MELEE",
        label = "Mirror melee cleave",
        core  = { WARRIOR = true, SHAMAN = true, PALADIN = true, DRUID = true, PRIEST = true },
        openTarget = "PRIEST",
        swapTarget = "DRUID",
        threats = {
            PRIEST = "Mana Burn / PainSup",
            DRUID  = "Cyclone / NS",
        },
        callouts = {
            "CALL_PURGE",
            "CALL_CYCLONE_OFF",
            "CALL_EARTHSHOCK_HEAL",
        },
    },
    -- ============================================================
    -- Caster cleave / triple caster
    -- ============================================================
    {
        id    = "TRIPLE_CASTER",
        label = "Triple caster",
        core  = { MAGE = true, WARLOCK = true, PRIEST = true },
        openTarget = "WARLOCK",
        swapTarget = "MAGE",
        callouts = { "CALL_GROUND_POLY", "CALL_PURGE", "CALL_TREMOR_FEAR" },
        chains = {
            { id = "triple_caster_overlap", labelKey = "CHAIN_TRIPLE_CASTER_OVERLAP",
              label = "Stacked fear+sheep CC chain on the kill target",
              links = {
                  { spellID = S.FEAR_LOCK,       category = "FEAR",         byClass = "WARLOCK", targetRole = "primary" },
                  { spellID = S.POLYMORPH,       category = "INCAPACITATE", byClass = "MAGE",    targetRole = "off-healer" },
                  { spellID = S.PSYCHIC_SCREAM,  category = "FEAR",         byClass = "PRIEST",  targetRole = "any" },
              } },
        },
    },
    -- ============================================================
    -- Dynamic comps (resolved on healer-count, not class set)
    -- ============================================================
    {
        id    = "DOUBLE_HEALER",
        label = "Double healer",
        core  = {},
        dynamic = "DOUBLE_HEALER",
        openTarget = nil,
        callouts = {
            "CALL_MANA_BURN_PLAN",
            "CALL_CYCLONE_OFF",
            "CALL_PURGE",
        },
    },
    {
        id    = "TRIPLE_DPS",
        label = "Triple DPS / no healer",
        core  = {},
        dynamic = "TRIPLE_DPS",
        defaultMode = "DEFEND",
        callouts = {
            "CALL_PAIN_SUP_READY",
            "CALL_BOP_READY",
            "CALL_PEEL_PRIEST",
            "CALL_PEEL_DRUID",
        },
    },

    -- ============================================================
    -- 2v2 catalog (bracket = 2). Two-character comps where the
    -- entire game plan is shaped by the missing third slot: peel
    -- limited, swap window narrow, mana wars decisive.
    -- ============================================================
    {
        id = "RP_2V2", bracket = 2,
        label = "Rogue / Disc Priest - burst-and-fade",
        core  = { ROGUE = true, PRIEST = true },
        openTarget = "PRIEST", swapTarget = "ROGUE",
        threats = { ROGUE = "Cheap > Kidney burst window" },
        callouts = { "CALL_TREMOR_FEAR", "CALL_MANA_BURN_PLAN" },
        chains = {
            { id = "rp_kidney_into_blind", labelKey = "CHAIN_RP_KIDNEY_INTO_BLIND",
              label = "Kidney burst into blind reset",
              links = {
                  { spellID = S.KIDNEY_SHOT,    category = "STUN",      byClass = "ROGUE",  targetRole = "primary" },
                  { spellID = S.BLIND,          category = "DISORIENT", byClass = "ROGUE",  targetRole = "off-healer" },
                  { spellID = S.PSYCHIC_SCREAM, category = "FEAR",      byClass = "PRIEST", targetRole = "any" },
              } },
        },
    },
    {
        id = "RD_2V2", bracket = 2,
        label = "Rogue / Resto Druid - DoT + sustained",
        core  = { ROGUE = true, DRUID = true },
        openTarget = "DRUID", swapTarget = "ROGUE",
        threats = { DRUID = "HoTs + cyclone" },
        callouts = { "CALL_CYCLONE_OFF", "CALL_PURGE" },
        chains = {
            { id = "rd_kidney_into_cyclone", labelKey = "CHAIN_RD_KIDNEY_INTO_CYCLONE",
              label = "Rogue stun + druid cyclone lockdown",
              links = {
                  { spellID = S.KIDNEY_SHOT, category = "STUN",    byClass = "ROGUE", targetRole = "primary" },
                  { spellID = S.CYCLONE,     category = "CYCLONE", byClass = "DRUID", targetRole = "off-healer" },
              } },
        },
    },
    {
        id = "DRAIN_2V2", bracket = 2,
        label = "Drainteam - Affliction + Disc Priest",
        core  = { WARLOCK = true, PRIEST = true },
        openTarget = "PRIEST", swapTarget = "WARLOCK",
        threats = { WARLOCK = "UA + fear chain", PRIEST = "Mana Burn" },
        callouts = { "CALL_TREMOR_FEAR", "CALL_GROUND_DC", "CALL_MANA_BURN_PLAN" },
    },
    {
        id = "SHATTER_FROST_2V2", bracket = 2,
        label = "Shatter (confirmed Frost) - Frost Mage + Disc Priest",
        core  = { MAGE = true, PRIEST = true },
        specs = { MAGE = "FROST", PRIEST = "DISCIPLINE" },
        openTarget = "MAGE", swapTarget = "PRIEST",
        threats = { MAGE = "Nova > Sheep > Frostbolt shatter" },
        callouts = { "CALL_DISP_FROST", "CALL_GROUND_POLY", "CALL_TREMOR_FEAR" },
    },
    {
        id = "SHATTER_2V2", bracket = 2,
        label = "Shatter - Frost Mage + Disc Priest",
        core  = { MAGE = true, PRIEST = true },
        openTarget = "MAGE", swapTarget = "PRIEST",
        threats = { MAGE = "Nova > Sheep > Frostbolt shatter" },
        callouts = { "CALL_DISP_FROST", "CALL_GROUND_POLY", "CALL_TREMOR_FEAR" },
        chains = {
            { id = "shatter_nova_into_sheep", labelKey = "CHAIN_SHATTER_NOVA_INTO_SHEEP",
              label = "Frost nova root into sheep on off-target",
              links = {
                  { spellID = S.FROST_NOVA,     category = "ROOT",         byClass = "MAGE",   targetRole = "primary" },
                  { spellID = S.POLYMORPH,      category = "INCAPACITATE", byClass = "MAGE",   targetRole = "off-healer" },
                  { spellID = S.PSYCHIC_SCREAM, category = "FEAR",         byClass = "PRIEST", targetRole = "any" },
              } },
        },
    },
    {
        id = "ENH_PRIEST_2V2", bracket = 2,
        label = "Enhancement Shaman + Disc Priest",
        core  = { SHAMAN = true, PRIEST = true },
        openTarget = "PRIEST", swapTarget = "SHAMAN",
        threats = { SHAMAN = "Windfury procs + purge our buffs" },
        callouts = { "CALL_PURGE", "CALL_TREMOR_FEAR", "CALL_MANA_BURN_PLAN" },
    },
    {
        id = "HUNTER_PRIEST_BM_2V2", bracket = 2,
        label = "BM Hunter (confirmed) + Disc Priest",
        core  = { HUNTER = true, PRIEST = true },
        specs = { HUNTER = "BEAST_MASTERY", PRIEST = "DISCIPLINE" },
        openTarget = "HUNTER", swapTarget = "PRIEST",
        threats = { HUNTER = "Pet pressure + BW window" },
        callouts = { "CALL_FREEDOM_WAR", "CALL_AVOID_OVERCHASE", "CALL_MANA_BURN_PLAN" },
    },
    {
        id = "HUNTER_PRIEST_2V2", bracket = 2,
        label = "BM Hunter + Disc Priest",
        core  = { HUNTER = true, PRIEST = true },
        openTarget = "PRIEST", swapTarget = "HUNTER",
        threats = { HUNTER = "Trap juggle + sustained ranged" },
        callouts = { "CALL_MANA_BURN_PLAN", "CALL_AVOID_OVERCHASE" },
    },
    {
        id = "WAR_DRUID_2V2", bracket = 2,
        label = "Warrior + Resto Druid",
        core  = { WARRIOR = true, DRUID = true },
        openTarget = "DRUID", swapTarget = "WARRIOR",
        threats = { WARRIOR = "MS pressure into HoT", DRUID = "Cyclone peel" },
        callouts = { "CALL_FREEDOM_WAR", "CALL_CYCLONE_OFF" },
    },
    {
        id = "WAR_HOLY_2V2", bracket = 2,
        label = "Warrior + Holy Paladin",
        core  = { WARRIOR = true, PALADIN = true },
        openTarget = "PALADIN", swapTarget = "WARRIOR",
        threats = { PALADIN = "BoP + Freedom save", WARRIOR = "MS chain" },
        callouts = { "CALL_PURGE", "CALL_HOJ_KILL", "CALL_BOP_READY" },
    },
    {
        id = "SP_PALA_2V2", bracket = 2,
        label = "Shadow Priest + Holy Paladin",
        core  = { PRIEST = true, PALADIN = true },
        openTarget = "PALADIN", swapTarget = "PRIEST",
        threats = { PRIEST = "Mana Burn + Shadow pressure" },
        callouts = { "CALL_PURGE", "CALL_HOJ_KILL", "CALL_MANA_BURN_PLAN" },
    },

    -- ============================================================
    -- 3v3 catalog (bracket = 3). Adds bracket-tagged variants of
    -- comps where 3v3 play differs sharply from 5v5 (smaller
    -- enemy pool, swap windows narrower, single-target focus).
    -- ============================================================
    {
        id = "SMR_3V3", bracket = 3,
        label = "SMR (Shadow Priest / Mage / Rogue)",
        core  = { ROGUE = true, MAGE = true, PRIEST = true },
        specs = { PRIEST = "SHADOW" },
        openTarget = "MAGE", swapTarget = "PRIEST",
        threats = { PRIEST = "Mind Blast + VT pressure (no healer)", MAGE = "Sheep follow-up", ROGUE = "Cheap > Kidney" },
        callouts = { "CALL_DISP_FROST", "CALL_TREMOR_FEAR", "CALL_PURGE" },
    },
    {
        id = "RMP_DISC_3V3", bracket = 3,
        label = "RMP (confirmed Disc Priest)",
        core  = { ROGUE = true, MAGE = true, PRIEST = true },
        specs = { PRIEST = "DISCIPLINE" },
        openTarget = "PRIEST", swapTarget = "MAGE",
        threats = { MAGE = "Sheep > Nova kill train", PRIEST = "Pain Sup save", ROGUE = "Kidney follow-up" },
        callouts = { "CALL_GROUND_POLY", "CALL_TREMOR_FEAR", "CALL_DISP_FROST", "CALL_PURGE", "CALL_PAIN_SUP_READY" },
    },
    {
        id = "RMP_3V3", bracket = 3,
        label = "RMP (Rogue / Mage / Priest)",
        core  = { ROGUE = true, MAGE = true, PRIEST = true },
        openTarget = "PRIEST", swapTarget = "MAGE",
        threats = { MAGE = "Sheep > Nova kill train", PRIEST = "Pain Sup save", ROGUE = "Kidney follow-up" },
        callouts = { "CALL_GROUND_POLY", "CALL_TREMOR_FEAR", "CALL_DISP_FROST", "CALL_PURGE" },
    },
    {
        id = "WLD_FERAL_3V3", bracket = 3,
        label = "Warrior / Lock / Feral Druid (no healer)",
        core  = { WARRIOR = true, WARLOCK = true, DRUID = true },
        specs = { DRUID = "FERAL" },
        defaultMode = "DEFEND",
        openTarget = "WARLOCK", swapTarget = "DRUID",
        threats = { DRUID = "Bleed + Cyclone peel", WARLOCK = "Fear chain into UA", WARRIOR = "MS into bleed" },
        callouts = { "CALL_TREMOR_FEAR", "CALL_FREEDOM_WAR", "CALL_PEEL_DRUID" },
    },
    {
        id = "WLD_RESTO_3V3", bracket = 3,
        label = "WLD (confirmed Resto Druid)",
        core  = { WARRIOR = true, WARLOCK = true, DRUID = true },
        specs = { DRUID = "RESTORATION" },
        openTarget = "DRUID", swapTarget = "WARLOCK",
        threats = { WARLOCK = "Howl into UA pressure", WARRIOR = "MS into fear", DRUID = "HoT race" },
        callouts = { "CALL_FREEDOM_WAR", "CALL_TREMOR_FEAR", "CALL_CYCLONE_OFF", "CALL_MANA_BURN_PLAN" },
    },
    {
        id = "WLD_3V3", bracket = 3,
        label = "WLD (Warrior / Lock / Druid)",
        core  = { WARRIOR = true, WARLOCK = true, DRUID = true },
        openTarget = "DRUID", swapTarget = "WARLOCK",
        threats = { WARLOCK = "Howl into UA pressure", WARRIOR = "MS into fear" },
        callouts = { "CALL_FREEDOM_WAR", "CALL_TREMOR_FEAR", "CALL_CYCLONE_OFF" },
    },
    {
        id = "JUNGLE_3V3", bracket = 3,
        label = "Jungle (Hunter / Feral / Healer)",
        core  = { HUNTER = true, DRUID = true, PRIEST = true },
        openTarget = "PRIEST", swapTarget = "HUNTER",
        threats = { HUNTER = "Trap juggle", DRUID = "Cyclone-into-bleed pressure" },
        callouts = { "CALL_TREMOR_FEAR", "CALL_MANA_BURN_PLAN" },
    },
    {
        id = "SHATTERPLAY_SHADOW_3V3", bracket = 3,
        label = "Shatterplay (confirmed Shadow Priest + Resto Druid)",
        core  = { MAGE = true, PRIEST = true, DRUID = true },
        specs = { MAGE = "FROST", PRIEST = "SHADOW", DRUID = "RESTORATION" },
        openTarget = "DRUID", swapTarget = "PRIEST",
        threats = { MAGE = "Shatter combo into Sheep", PRIEST = "Mind Blast + VT pressure", DRUID = "Cyclone peel" },
        callouts = { "CALL_PURGE", "CALL_CYCLONE_OFF", "CALL_GROUND_POLY", "CALL_DISP_FROST", "CALL_MANA_BURN_PLAN" },
    },
    {
        id = "SHATTERPLAY_3V3", bracket = 3,
        label = "Shatterplay (Mage / SPriest / Resto Druid)",
        core  = { MAGE = true, PRIEST = true, DRUID = true },
        openTarget = "DRUID", swapTarget = "MAGE",
        threats = { MAGE = "Shatter combo", PRIEST = "Shadow pressure + mana burn" },
        callouts = { "CALL_PURGE", "CALL_CYCLONE_OFF", "CALL_GROUND_POLY" },
    },
    {
        id = "LSD_3V3", bracket = 3,
        label = "LSD (Lock / Shaman / Druid)",
        core  = { WARLOCK = true, SHAMAN = true, DRUID = true },
        openTarget = "DRUID", swapTarget = "WARLOCK",
        threats = { SHAMAN = "Purge + Earth Shock", WARLOCK = "UA + drains" },
        callouts = { "CALL_PURGE", "CALL_TREMOR_FEAR", "CALL_GROUND_DC" },
    },
    {
        id = "RPH_3V3", bracket = 3,
        label = "RPH (Rogue / Ret / Healer)",
        core  = { ROGUE = true, PALADIN = true, PRIEST = true },
        openTarget = "PRIEST", swapTarget = "ROGUE",
        threats = { ROGUE = "Kidney burst", PALADIN = "Cleanse + HoJ" },
        callouts = { "CALL_PURGE", "CALL_HOJ_KILL", "CALL_TREMOR_FEAR" },
    },
    {
        id = "WMH_3V3", bracket = 3,
        label = "Thunder cleave (Warrior / Mage / Healer)",
        core  = { WARRIOR = true, MAGE = true, PRIEST = true },
        openTarget = "PRIEST", swapTarget = "MAGE",
        threats = { MAGE = "Sheep into shatter", WARRIOR = "MS chain" },
        callouts = { "CALL_FREEDOM_WAR", "CALL_DISP_FROST", "CALL_PURGE" },
    },
    {
        id = "PALA_CLEAVE_3V3", bracket = 3,
        label = "Pala cleave (Warrior / Ret / Healer)",
        core  = { WARRIOR = true, PALADIN = true, DRUID = true },
        openTarget = "DRUID", swapTarget = "PALADIN",
        threats = { WARRIOR = "MS into peel chain" },
        callouts = { "CALL_FREEDOM_WAR", "CALL_PURGE", "CALL_CYCLONE_OFF" },
    },
    {
        id = "ELE_SHAMAN_3V3", bracket = 3,
        label = "Ele Shaman + Mage + Healer",
        core  = { SHAMAN = true, MAGE = true, PRIEST = true },
        openTarget = "PRIEST", swapTarget = "SHAMAN",
        threats = { SHAMAN = "LB + shock burst", MAGE = "Sheep + nova" },
        callouts = { "CALL_PURGE", "CALL_GROUND_POLY", "CALL_TREMOR_FEAR" },
    },
    {
        id = "HUNTER_LOCK_PRIEST_3V3", bracket = 3,
        label = "Hunter / Lock / Priest",
        core  = { HUNTER = true, WARLOCK = true, PRIEST = true },
        openTarget = "PRIEST", swapTarget = "WARLOCK",
        threats = { HUNTER = "Trap juggle", WARLOCK = "Fear chain + UA" },
        callouts = { "CALL_TREMOR_FEAR", "CALL_GROUND_DC", "CALL_MANA_BURN_PLAN" },
    },
}

-- Predefined enemy comps for /acc test
ST.testComps = {
    {
        label   = "RMP + Druid + Paladin",
        classes = { "ROGUE", "MAGE", "PRIEST", "DRUID", "PALADIN" },
    },
    {
        label   = "Warlock / Druid / Warrior / Priest / Shaman",
        classes = { "WARLOCK", "DRUID", "WARRIOR", "PRIEST", "SHAMAN" },
    },
    {
        label   = "Hunter / Druid / Priest / Mage / Rogue",
        classes = { "HUNTER", "DRUID", "PRIEST", "MAGE", "ROGUE" },
    },
    {
        label   = "Mirror: WAR/ENH/RET/RDRU/DISC",
        classes = { "WARRIOR", "SHAMAN", "PALADIN", "DRUID", "PRIEST" },
    },
    {
        label   = "Triple DPS: Rogue / Mage / Warlock / Priest / Shaman",
        classes = { "ROGUE", "MAGE", "WARLOCK", "PRIEST", "SHAMAN" },
    },
}

-- Instantiate a comp's chains against the live state. Returns an array
-- of concrete chains (each in the shape Chain:Build expects):
--   { id, label, links = { {spellID, category, target, by}, ... } }
--
-- byClass templates are resolved by walking `enemies` for an alive enemy
-- of that class; targetRole templates resolve via:
--   "primary"        -> primaryGUID
--   "off-healer"     -> secondaryGUID (best-effort; falls back to primary)
--   "off-healer-2"   -> third pick (any alive enemy that isn't primary
--                       or secondary); falls back to secondary then primary
--   "any" / unknown  -> primaryGUID
--
-- A link whose byClass has no live enemy is *dropped* (the link cannot
-- be cast); a chain with zero remaining links is omitted from the
-- output. This lets the engine score only chains that have a chance.
function ST:InstantiateChains(comp, primaryGUID, secondaryGUID, enemies)
    if not comp or not comp.chains then return {} end
    local out = {}

    -- Pre-index alive enemies by class for O(1) byClass lookup.
    local byClass = {}
    local extras = {}
    for _, e in pairs(enemies or {}) do
        if e.alive ~= false and e.class and e.guid then
            byClass[e.class] = byClass[e.class] or e.guid
            if e.guid ~= primaryGUID and e.guid ~= secondaryGUID then
                table.insert(extras, e.guid)
            end
        end
    end

    local function resolveTarget(role)
        if role == "primary" then return primaryGUID end
        if role == "off-healer" then return secondaryGUID or primaryGUID end
        if role == "off-healer-2" then
            return extras[1] or secondaryGUID or primaryGUID
        end
        -- "any" or anything unrecognised falls back to primary
        return primaryGUID
    end

    for _, template in ipairs(comp.chains) do
        local links = {}
        for _, link in ipairs(template.links or {}) do
            local caster = byClass[link.byClass]
            if caster then
                table.insert(links, {
                    spellID   = link.spellID,
                    category  = link.category,
                    by        = caster,
                    target    = resolveTarget(link.targetRole),
                    castTimeS = link.castTimeS,
                })
            end
        end
        if #links > 0 then
            table.insert(out, {
                id       = template.id,
                label    = template.label,
                labelKey = template.labelKey,
                links    = links,
            })
        end
    end

    return out
end

-- Apply the variant overrides for a given own archetype on top of a comp
-- entry. Returns a shallow-merged copy. Safe to call with `nil` ownArchetype.
function ST:ApplyOwnVariant(comp, ownArchetypeId)
    if not comp then return comp end
    if not ownArchetypeId or not comp.ownVariants then return comp end
    local v = comp.ownVariants[ownArchetypeId]
    if not v then return comp end
    local out = {}
    for k, val in pairs(comp) do out[k] = val end
    for k, val in pairs(v) do out[k] = val end
    out._variantApplied = ownArchetypeId
    return out
end

-- Look up the best-fit comp for a given enemy class array.
-- Optionally accepts the enemies map so per-enemy roleGuess overrides take
-- effect (used by the live engine; tests rely on this too).
-- Returns the matching entry, or nil if none.
-- Identify the enemy comp.
--   enemyClassList : array of CLASS strings (legacy callers)
--   enemies        : optional map of unit -> enemy table (preferred; lets us
--                    consume e.roleGuess + e.specGuess from spec inference)
--   bracket        : optional 2/3/5. When set, comps with a different `bracket`
--                    field are skipped. Comps with no bracket field are
--                    bracket-agnostic and always considered.
--
-- Spec-keyed comps (comp.specs = { CLASS = "SPEC" }) match only when the
-- required specs are confirmed via observed e.specGuess. Without an enemies
-- map, or while specs remain unknown, spec-keyed comps never match and the
-- engine falls back to the class-only sibling.
--
-- Returns (comp, confidence) where confidence is in [0..1]:
--   * 1.0 for a spec-keyed match (every required spec confirmed by construction).
--   * 1.0 for dynamic role-count comps (TRIPLE_DPS, DOUBLE_HEALER) — role counts
--     are unambiguous, not spec-derived.
--   * For a class-only match, confidence = (count of alive core-class enemies
--     whose specGuess is known) / (count of core classes the comp requires).
--   * 0.0 when called via the legacy class-list-only signature (no enemies map),
--     because spec data only flows via the enemies map.
--   * 0.0 when no comp matches (comp is nil).
function ST:Identify(enemyClassList, enemies, bracket)
    if not enemyClassList or #enemyClassList == 0 then return nil, 0.0 end

    local Classes = ns.Classes
    local presence = {}
    local healers, dps = 0, 0

    local function bracketMatches(comp)
        if comp.bracket == nil then return true end
        if bracket == nil then return true end  -- caller didn't filter
        return comp.bracket == bracket
    end

    -- A spec-keyed comp matches only when every required spec is *explicitly
    -- observed* on an alive enemy of that class. Unknown or mismatched
    -- specGuess disqualifies the spec-keyed entry so a class-only sibling
    -- declared later in the catalog catches the fallback.
    local function specsMatch(comp)
        if not comp.specs then return true end
        if not enemies then return false end  -- spec data only flows via enemies map
        for cls, requiredSpec in pairs(comp.specs) do
            local confirmed = false
            for _, e in pairs(enemies) do
                if e.class == cls and e.alive ~= false and e.specGuess == requiredSpec then
                    confirmed = true
                    break
                end
            end
            if not confirmed then return false end
        end
        return true
    end

    -- Prefer the enemies table when available so roleGuess overrides win.
    if enemies and next(enemies) then
        for _, e in pairs(enemies) do
            if e.alive ~= false and e.class then
                presence[e.class] = true
                local role = e.roleGuess
                if not role and Classes then role = Classes:DefaultRole(e.class) end
                if role == "HEALER" then healers = healers + 1
                else dps = dps + 1 end
            end
        end
    else
        for _, cls in ipairs(enemyClassList) do
            presence[cls] = true
            local def = Classes and Classes:DefaultRole(cls) or nil
            if def == "HEALER" then
                healers = healers + 1
            else
                dps = dps + 1
            end
        end
    end

    -- Dynamic role-count comps win when they fire because the role mix
    -- changes the entire game plan (3+ DPS with no healer = defensive,
    -- double-healer = mana drain), regardless of which specific dps classes
    -- are on the field.
    -- Confidence is 1.0 — role counts are unambiguous, not spec-derived.
    if healers == 0 and dps >= 3 then
        for _, comp in ipairs(self.comps) do
            if comp.dynamic == "TRIPLE_DPS" and bracketMatches(comp) then return comp, 1.0 end
        end
    end
    if healers >= 2 then
        for _, comp in ipairs(self.comps) do
            if comp.dynamic == "DOUBLE_HEALER" and bracketMatches(comp) then return comp, 1.0 end
        end
    end

    -- Compute the confidence score for a matched comp.
    --   Spec-keyed match: 1.0 by construction.
    --   Class-only match: ratio of core-class enemies with known specGuess.
    --   Without an enemies map: 0.0 (no spec data channel).
    local function confidenceFor(comp)
        if comp.specs then return 1.0 end
        if not enemies then return 0.0 end
        local total, known = 0, 0
        for cls, _ in pairs(comp.core) do
            total = total + 1
            for _, e in pairs(enemies) do
                if e.class == cls and e.alive ~= false and e.specGuess ~= nil then
                    known = known + 1
                    break
                end
            end
        end
        if total == 0 then return 0.0 end
        return known / total
    end

    -- Static signature match (need all `core` classes present).
    -- Bracket-specific comps win over bracket-agnostic ones when both match,
    -- so we walk twice: first only comps with the requested bracket, then
    -- the bracket-agnostic fallbacks.
    local function tryMatch(filterFn)
        for _, comp in ipairs(self.comps) do
            if not comp.dynamic and filterFn(comp) then
                local ok = true
                local coreCount = 0
                for cls, _ in pairs(comp.core) do
                    coreCount = coreCount + 1
                    if not presence[cls] then ok = false; break end
                end
                if ok and coreCount > 0 and specsMatch(comp) then
                    return comp, confidenceFor(comp)
                end
            end
        end
        return nil, 0.0
    end

    if bracket then
        local m, conf = tryMatch(function(c) return c.bracket == bracket end)
        if m then return m, conf end
    end
    return tryMatch(function(c) return c.bracket == nil end)
end
