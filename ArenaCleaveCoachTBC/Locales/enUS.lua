-- ArenaCleaveCoachTBC - English (en-US) locale
local ADDON_NAME, ns = ...
ns = ns or {}
ns.locales = ns.locales or {}

ns.locales.enUS = {
    -- Modes
    OPEN          = "OPEN",
    KILL          = "KILL",
    SWAP          = "SWAP",
    DEFEND        = "DEFEND",
    RESET         = "RESET",

    -- Priorities
    PRIO_LOW      = "LOW",
    PRIO_MEDIUM   = "MEDIUM",
    PRIO_HIGH     = "HIGH",
    PRIO_URGENT   = "URGENT",

    -- Slash/help
    HELP_HEADER   = "ArenaCleaveCoachTBC commands:",
    HELP_TOGGLE   = "/acc toggle           - show/hide frame",
    HELP_LOCK     = "/acc lock / unlock    - lock or unlock the frame",
    HELP_TEST     = "/acc test             - run sample enemy comps",
    HELP_DEBUG    = "/acc debug            - toggle debug logging",
    HELP_RESET    = "/acc reset            - reset SavedVariables",
    HELP_STRAT    = "/acc strategy safe|balanced|greedy - set aggression",
    HELP_ENEMY    = "/acc enemy <c1> ... <c5> - simulate enemy comp",
    HELP_HELP     = "/acc help             - show this help",

    -- Recommendation reasons / callouts
    REASON_DEFAULT       = "Awaiting opener...",
    REASON_OPEN_HEALER   = "Open on enemy healer",
    REASON_OPEN_TARGET   = "Open on %s",
    REASON_KILL_TARGET   = "Pressure %s",
    REASON_SWAP_TARGET   = "Swap to %s",
    REASON_DEFEND        = "Defensive mode - heal up",
    REASON_RESET         = "Reset - LoS / mana drink",
    REASON_IMMUNITY      = "Target immune (%s)",
    REASON_LOW_HEALTH    = "Healer below %d%%",
    REASON_TRINKET_DOWN  = "Trinket down",
    REASON_MS_ACTIVE     = "Mortal Strike active",
    REASON_BURST_READY   = "Burst cooldowns ready",

    -- Callout strings
    CALL_FREEDOM_WAR     = "Freedom Warrior",
    CALL_FREEDOM_ENH     = "Freedom Shaman",
    CALL_PURGE           = "Purge %s",
    CALL_HOJ_KILL        = "HoJ kill target",
    CALL_CYCLONE_OFF     = "Cyclone off-healer",
    CALL_EARTHSHOCK_HEAL = "Earth Shock next heal",
    CALL_TREMOR_FEAR     = "Tremor vs Fear",
    CALL_GROUND_POLY     = "Grounding next Polymorph",
    CALL_GROUND_DC       = "Grounding next Death Coil",
    CALL_DISP_POLY       = "Dispel Polymorph",
    CALL_DISP_FROST      = "Dispel Frost Nova",
    CALL_CLEANSE_ROOTS   = "Cleanse roots",
    CALL_MANA_BURN_PLAN  = "Mana Burn plan",
    CALL_PAIN_SUP_READY  = "Pain Suppression ready",
    CALL_BOP_READY       = "BoP ready",
    CALL_AVOID_OVERCHASE = "Avoid overchase",
    CALL_PEEL_PRIEST     = "Peel for Priest",
    CALL_PEEL_DRUID      = "Peel for Druid",

    -- UI labels
    UI_TITLE             = "Arena Cleave Coach",
    UI_NO_ARENA          = "Out of arena",
    UI_FRIENDLY_CDS      = "Friendly cooldowns",
    UI_ENEMY_CDS         = "Enemy cooldowns",

    -- Debug
    DEBUG_PREFIX         = "[ACC]",
    DEBUG_ENABLED        = "debug enabled",
    DEBUG_DISABLED       = "debug disabled",
    DEBUG_RESET_DONE     = "SavedVariables reset; /reload to take effect",
    DEBUG_STRAT_SET      = "strategy aggression set to: %s",
    DEBUG_UNKNOWN_CMD    = "unknown command. Try /acc help",

    -- Test mode comps
    TEST_HEADER          = "Running test comps:",
    TEST_COMP_LABEL      = "Comp #%d: %s",
}
