return {
    {
        id = "war_enh_rdruid_vs_rmp",
        label = "Warrior / Enhancement / Restoration Druid vs RMP",
        pvpContext = "arena",
        bracket = 3,
        friendlies = {
            { unit = "player", guid = "friendly-warrior", name = "You", class = "WARRIOR", spec = "ARMS", roleGuess = "MELEE", healthPct = 100 },
            { unit = "party1", guid = "friendly-shaman", name = "Sweetshammy", class = "SHAMAN", spec = "ENHANCEMENT", roleGuess = "MELEE", healthPct = 100 },
            { unit = "party2", guid = "friendly-druid", name = "Leaves", class = "DRUID", spec = "RESTORATION", roleGuess = "HEALER", healthPct = 100 },
        },
        enemies = {
            { unit = "arena1", guid = "enemy-rogue", name = "Sneakstab", class = "ROGUE", roleGuess = "MELEE", healthPct = 100, hasTrinket = true },
            { unit = "arena2", guid = "enemy-mage", name = "Frostbiter", class = "MAGE", specGuess = "FROST", roleGuess = "CASTER", healthPct = 100, hasTrinket = true },
            { unit = "arena3", guid = "enemy-priest", name = "Holyman", class = "PRIEST", specGuess = "DISCIPLINE", roleGuess = "HEALER", healthPct = 100, hasTrinket = true },
        },
        steps = {
            {
                id = "opener",
                observations = { windfuryActive = true, hojReady = true },
                expect = {
                    mode = "KILL",
                    targetClass = "PRIEST",
                    player = { actionKey = "ACTION_WARRIOR_KILL", targetName = "Holyman" },
                    actions = {
                        party1 = { actionKey = "ACTION_SHAMAN_PURGE", targetName = "Holyman" },
                        party2 = { actionKey = "ACTION_DRUID_HEAL_CC", targetName = "Frostbiter" },
                    },
                    forbiddenCallouts = { "CALL_PURGE" },
                },
            },
            {
                id = "healer_train",
                observations = {
                    windfuryActive = true,
                    healerUnderPressure = true,
                    healerPressure = {
                        targetGuid = "@party2",
                        targetUnit = "party2",
                        targetName = "Leaves",
                        targetRole = "HEALER",
                        events = 4,
                        window = 5,
                    },
                },
                expect = {
                    mode = "DEFEND",
                    targetClass = "PRIEST",
                    player = { actionKey = "ACTION_DPS_PEEL", targetName = "Leaves", targetType = "friendly" },
                    actions = {
                        party1 = { actionKey = "ACTION_SHAMAN_DEFEND", targetName = "Leaves", targetType = "friendly" },
                        party2 = { actionKey = "ACTION_DRUID_DEFEND", targetName = "Leaves", targetType = "friendly" },
                    },
                    forbiddenCallouts = { "CALL_BOP_READY", "CALL_PURGE" },
                },
            },
            {
                id = "kill_swap_mage",
                observations = { windfuryActive = true, hojReady = true, msActiveOn = "@arena2" },
                enemies = {
                    arena2 = { healthPct = 20, hasTrinket = false },
                    arena3 = { healthPct = 100 },
                },
                expect = {
                    mode = "KILL",
                    targetClass = "MAGE",
                    callouts = { "BURST_NOW" },
                    player = { actionKey = "ACTION_WARRIOR_KILL", targetName = "Frostbiter" },
                    actions = {
                        party1 = { actionKey = "ACTION_SHAMAN_BLOODLUST", targetName = nil },
                        party2 = { actionKey = "ACTION_DRUID_HEAL_CC", targetName = "Holyman" },
                    },
                    forbiddenCallouts = { "CALL_PURGE" },
                },
            },
        },
    },
    {
        id = "no_shaman_vs_rmp",
        label = "No-shaman roster vs RMP",
        pvpContext = "arena",
        bracket = 3,
        friendlies = {
            { unit = "player", guid = "friendly-warrior", name = "You", class = "WARRIOR", spec = "ARMS", roleGuess = "MELEE", healthPct = 100 },
            { unit = "party1", guid = "friendly-rogue", name = "Cutlery", class = "ROGUE", spec = "SUBTLETY", roleGuess = "MELEE", healthPct = 100 },
            { unit = "party2", guid = "friendly-druid", name = "Leaves", class = "DRUID", spec = "RESTORATION", roleGuess = "HEALER", healthPct = 100 },
        },
        enemies = {
            { unit = "arena1", guid = "enemy-rogue", name = "Sneakstab", class = "ROGUE", roleGuess = "MELEE", healthPct = 100, hasTrinket = true },
            { unit = "arena2", guid = "enemy-mage", name = "Frostbiter", class = "MAGE", specGuess = "FROST", roleGuess = "CASTER", healthPct = 100, hasTrinket = true },
            { unit = "arena3", guid = "enemy-priest", name = "Holyman", class = "PRIEST", specGuess = "DISCIPLINE", roleGuess = "HEALER", healthPct = 100, hasTrinket = true },
        },
        steps = {
            {
                id = "opener_without_shaman",
                observations = { windfuryActive = false, hojReady = true },
                expect = {
                    mode = "KILL",
                    targetClass = "PRIEST",
                    player = { actionKey = "ACTION_WARRIOR_KILL", targetName = "Holyman" },
                    actions = {
                        party1 = { actionKey = "ACTION_ROGUE_KILL", targetName = "Holyman" },
                        party2 = { actionKey = "ACTION_DRUID_HEAL_CC", targetName = "Frostbiter" },
                    },
                    forbiddenCallouts = { "CALL_TREMOR_FEAR", "CALL_GROUND_POLY", "CALL_PURGE", "CALL_EARTHSHOCK_HEAL", "BURST_NOW" },
                    forbiddenActions = { "ACTION_SHAMAN_TREMOR_REFRESH", "ACTION_SHAMAN_PURGE", "ACTION_SHAMAN_BLOODLUST" },
                    rejectedCallouts = {
                        CALL_TREMOR_FEAR = "missing_hasTremor",
                        CALL_GROUND_POLY = "missing_hasGrounding",
                        CALL_PURGE = "missing_hasPurge",
                    },
                },
            },
        },
    },
    {
        id = "sweetshammy_enhancement_not_healer",
        label = "Enhancement shaman remains shaman utility, not healer/magic dispel",
        pvpContext = "arena",
        bracket = 3,
        friendlies = {
            { unit = "player", guid = "friendly-warrior", name = "You", class = "WARRIOR", spec = "ARMS", roleGuess = "MELEE", healthPct = 100 },
            { unit = "party1", guid = "friendly-shaman", name = "Sweetshammy", class = "SHAMAN", spec = "ENHANCEMENT", roleGuess = "MELEE", healthPct = 20 },
            { unit = "party2", guid = "friendly-druid", name = "Leaves", class = "DRUID", spec = "RESTORATION", roleGuess = "HEALER", healthPct = 88 },
        },
        enemies = {
            { unit = "arena1", guid = "enemy-rogue", name = "Sneakstab", class = "ROGUE", roleGuess = "MELEE", healthPct = 100, hasTrinket = true },
            { unit = "arena2", guid = "enemy-mage", name = "Frostbiter", class = "MAGE", specGuess = "FROST", roleGuess = "CASTER", healthPct = 100, hasTrinket = true },
            { unit = "arena3", guid = "enemy-priest", name = "Holyman", class = "PRIEST", specGuess = "DISCIPLINE", roleGuess = "HEALER", healthPct = 100, hasTrinket = true },
        },
        steps = {
            {
                id = "low_enhancement_shaman_does_not_force_defend",
                observations = { windfuryActive = true, hojReady = true },
                expect = {
                    mode = "KILL",
                    targetClass = "PRIEST",
                    player = { actionKey = "ACTION_WARRIOR_KILL", targetName = "Holyman" },
                    actions = {
                        party1 = { actionKey = "ACTION_SHAMAN_PURGE", targetName = "Holyman" },
                    },
                    forbiddenCallouts = { "CALL_DISP_FROST", "CALL_PURGE" },
                    forbiddenActions = { "ACTION_SHAMAN_DEFEND", "ACTION_HEALER_RESET" },
                    rejectedCallouts = {
                        CALL_DISP_FROST = "missing_any_cap",
                    },
                },
            },
        },
    },
    {
        id = "twos_double_dps",
        label = "2v2 double DPS",
        pvpContext = "arena",
        bracket = 2,
        friendlies = {
            { unit = "player", guid = "friendly-warrior", name = "You", class = "WARRIOR", spec = "ARMS", roleGuess = "MELEE", healthPct = 100 },
            { unit = "party1", guid = "friendly-rogue", name = "Cutlery", class = "ROGUE", spec = "SUBTLETY", roleGuess = "MELEE", healthPct = 100 },
        },
        enemies = {
            { unit = "arena1", guid = "enemy-mage", name = "Frostbiter", class = "MAGE", specGuess = "FROST", roleGuess = "CASTER", healthPct = 100, hasTrinket = true },
            { unit = "arena2", guid = "enemy-rogue", name = "Sneakstab", class = "ROGUE", roleGuess = "MELEE", healthPct = 100, hasTrinket = true },
        },
        steps = {
            {
                id = "open_on_mage",
                observations = { windfuryActive = false, hojReady = false },
                expect = {
                    mode = "KILL",
                    targetClass = "MAGE",
                    player = { actionKey = "ACTION_WARRIOR_KILL", targetName = "Frostbiter" },
                    actions = {
                        party1 = { actionKey = "ACTION_ROGUE_KILL", targetName = "Frostbiter" },
                    },
                    forbiddenCallouts = { "CALL_TREMOR_FEAR", "CALL_GROUND_POLY" },
                    forbiddenActions = { "ACTION_SHAMAN_BLOODLUST", "ACTION_SHAMAN_PURGE" },
                },
            },
        },
    },
    {
        id = "twos_healer_dps",
        label = "2v2 healer / DPS",
        pvpContext = "arena",
        bracket = 2,
        friendlies = {
            { unit = "player", guid = "friendly-warrior", name = "You", class = "WARRIOR", spec = "ARMS", roleGuess = "MELEE", healthPct = 100 },
            { unit = "party1", guid = "friendly-druid", name = "Leaves", class = "DRUID", spec = "RESTORATION", roleGuess = "HEALER", healthPct = 100 },
        },
        enemies = {
            { unit = "arena1", guid = "enemy-warrior", name = "Mortalman", class = "WARRIOR", roleGuess = "MELEE", healthPct = 100, hasTrinket = true },
            { unit = "arena2", guid = "enemy-druid", name = "Barkskin", class = "DRUID", specGuess = "RESTORATION", roleGuess = "HEALER", healthPct = 100, hasTrinket = true },
        },
        steps = {
            {
                id = "train_healer",
                observations = { windfuryActive = false, hojReady = false },
                expect = {
                    mode = "KILL",
                    targetClass = "DRUID",
                    player = { actionKey = "ACTION_WARRIOR_KILL", targetName = "Barkskin" },
                    actions = {
                        party1 = { actionKey = "ACTION_DRUID_HEAL_CC", targetName = "Mortalman" },
                    },
                    forbiddenCallouts = { "CALL_TREMOR_FEAR", "CALL_GROUND_POLY", "CALL_PURGE" },
                    forbiddenActions = { "ACTION_SHAMAN_BLOODLUST", "ACTION_SHAMAN_PURGE" },
                },
            },
        },
    },
    {
        id = "bg_and_world_guardrails",
        label = "BG/world PvP guard rails",
        friendlies = {
            { unit = "player", guid = "friendly-warrior", name = "You", class = "WARRIOR", spec = "ARMS", roleGuess = "MELEE", healthPct = 100 },
            { unit = "party1", guid = "friendly-paladin", name = "Freedombot", class = "PALADIN", spec = "RETRIBUTION", roleGuess = "MELEE", healthPct = 100 },
            { unit = "party2", guid = "friendly-druid", name = "Leaves", class = "DRUID", spec = "RESTORATION", roleGuess = "HEALER", healthPct = 100 },
        },
        steps = {
            {
                id = "bg_flag_carrier",
                pvpContext = "bg",
                bracket = 10,
                enemies = {
                    arena1 = { unit = "arena1", guid = "enemy-warrior", name = "Flagman", class = "WARRIOR", roleGuess = "MELEE", healthPct = 35, hasTrinket = true, importantBuffs = { [23333] = true } },
                    arena2 = { unit = "arena2", guid = "enemy-mage", name = "Frostbiter", class = "MAGE", roleGuess = "CASTER", healthPct = 100, hasTrinket = true },
                    arena3 = { unit = "arena3", guid = "enemy-priest", name = "Holyman", class = "PRIEST", roleGuess = "HEALER", healthPct = 100, hasTrinket = true },
                },
                observations = { windfuryActive = false, hojReady = true },
                expect = {
                    mode = "KILL",
                    noComp = true,
                    targetClass = "WARRIOR",
                    callouts = { "CALL_FLAG_CARRIER_LOW" },
                    player = { actionKey = "ACTION_WARRIOR_KILL", targetName = "Flagman" },
                    forbiddenCallouts = { "CALL_TREMOR_FEAR", "CALL_GROUND_POLY" },
                },
            },
            {
                id = "world_single_target",
                pvpContext = "world",
                bracket = nil,
                enemies = {
                    arena1 = { unit = "nameplate1", guid = "world-mage", name = "Openworld", class = "MAGE", roleGuess = "CASTER", healthPct = 100, hasTrinket = true },
                },
                observations = { windfuryActive = false, hojReady = true },
                expect = {
                    mode = "KILL",
                    noComp = true,
                    targetClass = "MAGE",
                    player = { actionKey = "ACTION_WARRIOR_KILL", targetName = "Openworld" },
                    forbiddenCallouts = { "CALL_TREMOR_FEAR", "CALL_GROUND_POLY", "CALL_PURGE" },
                },
            },
        },
    },
}
