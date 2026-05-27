-- ArenaCoachTBC - Built-in simulator scenarios
--
-- Each scenario seeds an enemy team and a sequence of timed events the
-- simulator replays against the engine. Indices in `by`/`on`/`unit` are
-- 1-based and refer to `enemies[i]` -> arena<i>.

local ADDON_NAME, ns = ...
ns = ns or {}
local SIM = ns.Simulator
local S   = ns.Spells
if not (SIM and S) then return end

-- Engine-driven smoke scenario for `/acc test`.
-- Unlike the older forced HUD demo, this seeds a 3v3 arena state and lets
-- Core:Evaluate drive the recommendation after each event. It includes the
-- things that tend to break real matches: PRE -> ACTIVE timing, delayed spec
-- discovery, healer CC, burst damage pressure, trinket state, defensive auras,
-- and a final reset.
SIM:Register("real-arena", {
    label       = "Realistic 3v3 arena: RMP opener into peel/swap",
    context     = "arena",
    bracket     = 3,
    combatPhase = "PRE",
    friendlies  = {
        { unit = "player", name = "You",       class = "WARRIOR", spec = "ARMS",        healthPct = 100 },
        { unit = "party1", name = "Totemkin",  class = "SHAMAN",  spec = "ENHANCEMENT", healthPct = 100 },
        { unit = "party2", name = "Leaves",    class = "DRUID",   spec = "RESTORATION", roleGuess = "HEALER", healthPct = 100 },
    },
    enemies = {
        { class = "ROGUE",  name = "Sneakstab" },
        { class = "MAGE",   name = "Frostbiter" },
        { class = "PRIEST", name = "Holyman" },
    },
    observations = {
        windfuryActive = true,
        hojReady = false,
        priestCanDispel = false,
    },
    events = {
        { t = 0.0,  type = "phase", phase = "PRE",    label = "Arena doors closed: opponents visible, opener only" },
        { t = 5.0,  type = "phase", phase = "ACTIVE", label = "Gates open: combat starts" },
        { t = 9.0,  type = "cast", by = 2, spell = S.ICY_VEINS, noEvaluate = true, label = "Mage pops Icy Veins" },
        { t = 10.0, type = "aura", on = 2, spell = S.ICY_VEINS,         label = "Icy Veins aura active" },
        { t = 14.0, type = "friendly_debuff", unit = "party2", spell = S.POLYMORPH_SHEEP, label = "Our druid is polymorphed" },
        { t = 18.0, type = "cast", by = 1, spell = S.KIDNEY_SHOT, noEvaluate = true, label = "Rogue kidneys the healer" },
        { t = 19.0, type = "damage", on = "party2", hits = 3, pct = 54, label = "Three burst hits land on our healer" },
        { t = 23.0, type = "friendly_health", unit = "party2", pct = 36, label = "Healer drops into defensive range" },
        { t = 28.0, type = "cast", by = 3, spell = S.PAIN_SUPPRESSION, noEvaluate = true, label = "Priest reveals Discipline with Pain Suppression" },
        { t = 29.0, type = "aura", on = 3, spell = S.PAIN_SUPPRESSION,  label = "Pain Suppression blocks the priest kill" },
        { t = 34.0, type = "trinket", unit = 3,                         label = "Priest trinkets the crowd-control chain" },
        { t = 38.0, type = "friendly_debuff_off", unit = "party2", spell = S.POLYMORPH_SHEEP, noEvaluate = true, label = "Druid is free again" },
        { t = 39.0, type = "friendly_health", unit = "party2", pct = 72, noEvaluate = true, label = "Healer recovers" },
        { t = 40.0, type = "clear_pressure",                            label = "Train pressure clears" },
        { t = 44.0, type = "health", unit = 2, pct = 38,                 label = "Mage is caught at 38%" },
        { t = 45.0, type = "trinket", unit = 2, noEvaluate = true,       label = "Mage trinket is down" },
        { t = 46.0, type = "debuff", unit = 2, spell = S.MORTAL_STRIKE,  label = "Mortal Strike is active on mage" },
        { t = 51.0, type = "aura_off", on = 3, spell = S.PAIN_SUPPRESSION, label = "Pain Suppression fades" },
        { t = 55.0, type = "health", unit = 2, pct = 19,                 label = "Mage is killable" },
        { t = 60.0, type = "kill", unit = 2,                             label = "Mage dies" },
        { t = 66.0, type = "reset",                                      label = "Arena round ends and the HUD resets" },
    },
})

SIM:Register("rmp", {
    label   = "RMP opener (Rogue / Mage / Priest)",
    enemies = { "ROGUE", "MAGE", "PRIEST" },
    events  = {
        { t = 0,  type = "cast", by = 2, spell = S.POLYMORPH_SHEEP, label = "Mage polymorphs off-healer" },
        { t = 2,  type = "cast", by = 1, spell = S.SAP,             label = "Rogue saps focus" },
        { t = 4,  type = "cast", by = 1, spell = S.KIDNEY_SHOT,     label = "Rogue kidney shots" },
        { t = 6,  type = "cast", by = 2, spell = S.COUNTERSPELL,    label = "Mage counterspells" },
        { t = 8,  type = "cast", by = 3, spell = S.PSYCHIC_SCREAM,  label = "Priest fears" },
        { t = 9,  type = "trinket", unit = 3,                        label = "Priest trinkets the fear" },
        { t = 12, type = "cast", by = 1, spell = S.BLIND,            label = "Rogue blinds our healer" },
    },
})

SIM:Register("tsg-mirror", {
    label   = "Melee cleave training our healer (War / Rogue / Pala)",
    enemies = { "WARRIOR", "ROGUE", "PALADIN" },
    events  = {
        { t = 0,  type = "cast", by = 1, spell = S.INTERCEPT,        label = "Warrior intercepts our priest" },
        { t = 1,  type = "cast", by = 1, spell = S.MORTAL_STRIKE,    label = "Mortal Strike lands" },
        { t = 2,  type = "cast", by = 2, spell = S.KIDNEY_SHOT,      label = "Rogue kidneys priest" },
        { t = 5,  type = "health", unit = 1, pct = 40,               label = "Warrior at 40% from peel" },
        { t = 7,  type = "cast", by = 3, spell = S.HAMMER_OF_JUSTICE, label = "Paladin HoJs druid" },
        { t = 9,  type = "trinket", unit = 1,                         label = "Warrior trinkets HoJ" },
        { t = 12, type = "cast", by = 1, spell = S.MORTAL_STRIKE,     label = "MS chain continues" },
    },
})

-- M8 #62: chain-vs-chain decision scenario. Sets up an RMP team and
-- replays a sequence that progressively narrows which of RMP's two
-- canonical chains (sap_into_kidney vs fear_into_burst) is highest-EV.
-- The first cast applies FEAR DR (via PSYCHIC_SCREAM hitting the
-- sim-victim sentinel), which the catalog's fear-chain would have to
-- punch through next. By t=8 the priest has trinketed and the chain
-- selector reconsiders. Useful for inspecting /acc trace dump and
-- comparing the engine's pick across ticks.
SIM:Register("chain-vs-chain", {
    label   = "Chain selector: RMP fear chain vs sap chain",
    enemies = { "ROGUE", "MAGE", "PRIEST" },
    events  = {
        { t = 0,  type = "cast", by = 3, spell = S.PSYCHIC_SCREAM, label = "Enemy priest opens with scream (bumps FEAR DR)" },
        { t = 2,  type = "cast", by = 1, spell = S.SAP,            label = "Enemy rogue saps focus (INCAP DR bump)" },
        { t = 5,  type = "cast", by = 2, spell = S.POLYMORPH,      label = "Enemy mage sheeps (INCAP DR continues)" },
        { t = 8,  type = "trinket", unit = 3,                       label = "Priest trinkets, FEAR window opens again" },
        { t = 10, type = "cast", by = 1, spell = S.KIDNEY_SHOT,    label = "Enemy rogue kidneys (STUN DR bump)" },
        { t = 13, type = "health", unit = 3, pct = 40,              label = "Priest at 40% from incidental damage" },
    },
})

SIM:Register("drain", {
    label   = "Drainteam 2v2 (Affliction / Disc Priest)",
    enemies = { "WARLOCK", "PRIEST" },
    events  = {
        { t = 0,  type = "cast", by = 1, spell = S.UNSTABLE_AFFLICTION, label = "UA pressure begins" },
        { t = 2,  type = "cast", by = 2, spell = S.MANA_BURN,           label = "Priest mana burns our healer" },
        { t = 5,  type = "cast", by = 1, spell = S.FEAR_LOCK,           label = "Warlock fears" },
        { t = 8,  type = "cast", by = 1, spell = S.DEATH_COIL,          label = "Death Coil for self-heal" },
        { t = 10, type = "cast", by = 2, spell = S.PSYCHIC_SCREAM,      label = "Priest scream" },
        { t = 12, type = "cast", by = 1, spell = S.HOWL_OF_TERROR,      label = "Lock howls" },
    },
})
