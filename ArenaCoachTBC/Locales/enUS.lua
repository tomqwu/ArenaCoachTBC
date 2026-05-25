-- ArenaCoachTBC - English (en-US) locale
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
    HELP_HEADER   = "ArenaCoachTBC commands:",
    HELP_TOGGLE   = "/acc toggle           - show/hide frame",
    HELP_LOCK     = "/acc lock / unlock    - lock or unlock the frame",
    HELP_TEST     = "/acc test [print]     - 14s scripted UI demo (or 'print' for chat-only)",
    HELP_DEBUG    = "/acc debug            - toggle debug logging",
    HELP_RESET    = "/acc reset            - reset SavedVariables",
    HELP_STRAT    = "/acc strategy safe|balanced|greedy - set aggression",
    HELP_ENEMY    = "/acc enemy <c1> ... <c5> - simulate enemy comp",
    HELP_SELFTEST = "/acc selftest [verbose] - run in-client validation",
    HELP_SIMULATE = "/acc simulate [key|stop] - replay a scripted scenario",
    HELP_TRACE    = "/acc trace [on|off|dump|clear|status] - decision-trace log",
    HELP_RECORD   = "/acc record [on|off|dump|clear|status] - record CLEU log for offline replay",
    HELP_BUGREPORT = "/acc bugreport       - print sanitised payload for GitHub issues",
    HELP_WHATIF   = "/acc whatif <sub>   - counterfactual replay of the current recording",
    TEST_DEMO_START = "|cffc8a86b[ACC]|r demo starting - 14s RMP 3v3 walk-through (mode flips, BURST_NOW pulse, DEFEND flash, profile callout).",
    TEST_DEMO_END   = "|cffc8a86b[ACC]|r demo complete. /acc test print for the chat-only smoke version.",
    TEST_DEMO_NO_UI = "|cffc8a86b[ACC]|r demo needs a live UI (in-game only).",

    -- M14 (v2.1): BG-mode callouts
    CALL_FLAG_CARRIER_LOW    = "Flag carrier low HP - push",
    CALL_INCOMING_PLAYERS    = "Incoming enemy players",
    CALL_BASE_UNDER_ATTACK   = "Base under attack - rotate",
    CALL_BG_DEFEND           = "Heal up - train detected",
    CALL_BG_RES_TIMER        = "Rez timer running",
    BUGREPORT_HEADER = "Bug report payload:",
    HELP_HELP     = "/acc help             - show this help",

    -- SelfTest
    SELFTEST_HEADER = "ArenaCoachTBC self-test:",

    -- Simulator
    SIMULATE_HEADER  = "Available scenarios (/acc simulate <key>):",
    SIMULATE_STOPPED = "simulation stopped",

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
    CALL_LOW_MANA_PUSH   = "Healer low mana - push now",

    -- UI labels
    UI_TITLE             = "Arena Coach",
    UI_NO_ARENA          = "Out of arena",
    UI_FRIENDLY_CDS      = "Friendly cooldowns",
    UI_ENEMY_CDS         = "Enemy cooldowns",

    -- Comp-match confidence badges
    COMP_BADGE_SPEC_CONFIRMED = "spec-confirmed",
    COMP_BADGE_CLASS_GUESSED  = "class-guessed",

    -- Chain callouts (M8 #62) — one localized label per built-in chain
    CHAIN_RMP_SAP_INTO_KIDNEY     = "Sap off-healer, kidney the target",
    CHAIN_RMP_FEAR_INTO_BURST     = "Scream lockdown into mage burst",
    CHAIN_WMS_SHEEP_INTO_TRAIN    = "Sheep healer, MS train kill target",
    CHAIN_WLD_FEAR_INTO_CYCLONE   = "Fear chain into druid cyclone peel",
    CHAIN_WLP_FEAR_INTO_HOJ       = "Fear into HoJ on the paladin",
    CHAIN_JUNGLE_TRAP_INTO_CYCLONE = "Trap healer, cyclone off-target",
    CHAIN_BEAST_TRAP_INTO_INTERCEPT = "Trap + scatter into warrior intercept",
    CHAIN_TSG_HOJ_INTO_INTERCEPT  = "HoJ into intercept on the priority",
    CHAIN_TRIPLE_CASTER_OVERLAP   = "Stacked fear + sheep on kill target",
    CHAIN_RP_KIDNEY_INTO_BLIND    = "Kidney burst into blind reset",
    CHAIN_RD_KIDNEY_INTO_CYCLONE  = "Rogue stun + druid cyclone lockdown",
    CHAIN_SHATTER_NOVA_INTO_SHEEP = "Nova root into sheep on off-target",
    CHAIN_STEP_PREFIX             = "Step",
    CHAIN_PICKED_PREFIX           = "Chain",

    -- M9 #65: profile-driven callouts
    CALL_FAKE_KICK_2          = "They kick the first heal - fake your second",
    CALL_SAVE_TREMOR_HOJ      = "They trinket Fear - save Tremor for HoJ",
    CALL_BURST_BLOCK_INCOMING = "Ice Block expected - hold burst",

    -- M10 #69: pattern recognition callouts (recurring kill setups)
    CALL_PATTERN_RMP_CHEAP_BLIND     = "Kidney+Blind chain detected - peel and trinket",
    CALL_PATTERN_SHATTER_NOVA_SHEEP  = "Shatter setup detected - trinket the nova",
    CALL_PATTERN_FEAR_INTO_POLY      = "Fear+Sheep chain incoming - tremor / fear ward up",
    CALL_PATTERN_HUNTER_TRAP_SCATTER = "Trap+Scatter chain detected - mass dispel ready",
    CALL_PATTERN_HOJ_INTO_INTERCEPT  = "HoJ+Intercept on the priority - swap defensive",

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
