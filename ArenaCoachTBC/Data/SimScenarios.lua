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
