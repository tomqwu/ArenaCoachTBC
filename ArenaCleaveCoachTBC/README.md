# ArenaCleaveCoachTBC

A strategy coach addon for **TBC Classic / TBC Anniversary** 5v5 arena. It
watches your arena, scores enemies in real time, and tells you who to
open on, who to swap to, when to burst, and when to defend.

The addon is built for the comp:

- Arms Warrior
- Enhancement Shaman
- Retribution Paladin
- Restoration Druid
- Discipline Priest

> ⚠️ **This addon never automates gameplay.** It does not cast spells, does
> not target enemies for you, does not click protected buttons, and does
> not edit secure macros in combat. Everything it does is visual / audio
> / text suggestions.

---

## Installation

1. Copy the `ArenaCleaveCoachTBC` folder into:
   ```
   <WoW>/_classic_/Interface/AddOns/
   ```
   (or whatever your TBC Classic / TBC Anniversary client uses)
2. Restart the client or `/reload`.
3. If the addon shows as "Out of Date", enable "Load out of date AddOns"
   in the character select AddOns dialog. Adjust the `## Interface:`
   number in `ArenaCleaveCoachTBC.toc` to match your client to silence
   the warning permanently.

The addon creates a single `SavedVariables` table:
`ArenaCleaveCoachTBCDB`.

## Slash Commands

| Command                                  | Effect                                  |
| ---------------------------------------- | --------------------------------------- |
| `/acc` or `/arenacleavecoach`            | alias root                              |
| `/acc help`                              | print all commands                      |
| `/acc toggle`                            | show / hide the recommendation frame    |
| `/acc lock` / `/acc unlock`              | lock or unlock the frame for dragging   |
| `/acc test`                              | simulate 5 sample enemy comps           |
| `/acc enemy war mage priest druid pala`  | simulate a custom enemy comp            |
| `/acc debug`                             | toggle debug logging                    |
| `/acc reset`                             | wipe SavedVariables (requires `/reload`)|
| `/acc strategy safe`                     | be conservative on burst/swap calls     |
| `/acc strategy balanced`                 | default                                 |
| `/acc strategy greedy`                   | call more swaps/bursts                  |

## How it Works

`StrategyEngine:Evaluate(state)` scores every alive enemy with a weighted
sum (defined in `StrategyEngine.lua > SE.weights`) and returns:

```lua
{
  mode            = "OPEN"|"KILL"|"SWAP"|"DEFEND"|"RESET",
  primaryTarget   = "guid-...",   -- top score
  secondaryTarget = "guid-...",   -- next best (swap candidate)
  confidence      = 0.0 .. 1.0,
  reason          = "PRIEST [role_healer(25), trinket_down(20), no_immunity(10)]",
  callouts        = { "CALL_HOJ_KILL", "CALL_PURGE", "CALL_TREMOR_FEAR" },
  priority        = "LOW"|"MEDIUM"|"HIGH"|"URGENT",
  burstAllowed    = true|false,
  burstBlockedBy  = "no_ms" | "no_windfury" | "target_immune" | nil,
}
```

The scoring weights are deliberately exposed as a flat table so you can
tune them without touching the engine:

```lua
-- StrategyEngine.lua
SE.weights = {
    role_healer          =  25,
    role_cloth_dps       =  15,
    role_melee_overext   =  10,
    health_below_50      =  30,
    trinket_down         =  20,
    major_defensive_down =  15,
    no_immunity          =  10,
    purgeable_defensive  =  10,
    ms_active            =  25,
    our_hoj_ready        =  15,
    our_bloodlust        =  15,
    windfury_active      =  10,
    priest_can_dispel    =  10,
    off_healer_cc        =  15,
    target_immune        = -100,
    target_unreachable   =  -30,
    target_los_blocked   =  -20,
    melee_locked_down    =  -20,
    our_healer_cc        =  -25,
    our_team_low_hp      =  -30,
}
```

## Wiring a WeakAura to the Addon

The addon publishes its current recommendation to a single global:

```lua
_G.ArenaCleaveCoachTBC = {
    GetRecommendation = function() ... end,
    GetPrimaryTarget  = function() ... end,
    GetCallouts       = function() ... end,
    GetDebugState     = function() ... end,
}
```

### Sample WeakAura — Custom Trigger

Create a *Custom* trigger, *Event*, type "Status", check "Check On…" =
"Every Frame" and use this function:

```lua
function()
    return _G.ArenaCleaveCoachTBC
       and _G.ArenaCleaveCoachTBC.GetRecommendation
       and _G.ArenaCleaveCoachTBC.GetRecommendation() ~= nil
end
```

### Sample WeakAura — Custom Text

```lua
function()
    local api = _G.ArenaCleaveCoachTBC
    if not api or not api.GetRecommendation then return "" end
    local r = api.GetRecommendation()
    if not r then return "" end
    return string.format(
        "%s: %s\n%s",
        r.mode or "",
        r.primaryTargetName or r.primaryTargetClass or "",
        r.reason or ""
    )
end
```

### Optional: WeakAuras.ScanEvents Trigger

The addon also fires `ACC_RECOMMENDATION` through
`WeakAuras.ScanEvents` whenever it publishes a new recommendation, so
advanced WAs can use:

- Trigger type: **Custom** → **Event**
- Event type: **WA_***-like custom event
- Event(s): `ACC_RECOMMENDATION`
- Custom trigger:
  ```lua
  function(event, rec)
      return event == "ACC_RECOMMENDATION" and rec and rec.priority == "URGENT"
  end
  ```

## Running the Tests

The `StrategyEngine` is engine-only Lua and runs outside WoW.

```bash
cd ArenaCleaveCoachTBC
lua5.1 Tests/StrategyEngine_spec.lua
```

Expected:

```
PASS healer exposed should be primary target
PASS immunity active suppresses kill target
PASS MS active increases target score
PASS trinket down increases target score
PASS friendly healer low HP triggers DEFEND
PASS enemy triple DPS triggers defensive recommendation in PRE
PASS Bloodlust burst recommendation requires MS if config says so
PASS target swap recommended when Mage has no Ice Block and low HP
PASS test-mode comps each produce a recommendation
PASS WeakAuraBridge exposes API after evaluate

Results: 10 passed, 0 failed
```

## Limitations & Assumptions

- **Enemy specs are guessed** from class alone (or from observed casts).
  We default Druids and Priests to *healer*, Mages/Warlocks to *caster*,
  etc. If an enemy reveals their spec via known casts (e.g. Mind Blast
  → Shadow Priest), `enemy.specGuess` is updated.
- **Cooldown durations** are conservative TBC 2.4.3 values. If your
  realm uses different talents / glyphs (TBC Anniversary), edit
  `CooldownTracker.lua > CT.defaults`. When unsure, we mark a CD as
  *ready* rather than block recommendations on an unknown.
- **DR window** defaults to 17s; tune `DRTracker.lua > DR.resetWindow`
  if your client uses a different recovery time.
- **PvP trinket detection** is based on aura `42292` (the shared
  Medallion buff). Class-specific trinkets (Will of the Forsaken,
  Every Man for Himself) may need their own IDs added to
  `Spells.lua > CooldownTracker.defaults`.
- **No automation**. We deliberately don't expose any function that
  would let a WeakAura or another addon click a protected button.

## Adding / Adjusting Spell IDs

All spell IDs live in `Data/Spells.lua`. Each ID is just a number, and
each category table is just a `{ [id] = "label" }` map. To add a new
enemy CD that affects scoring, add an entry to the relevant category:

```lua
-- Data/Spells.lua
S.SOME_NEW_DEFENSIVE = 12345
S.MAJOR_DEFENSIVES[S.SOME_NEW_DEFENSIVE] = "New Defensive"
```

To track its cooldown, add a duration to `CooldownTracker.lua`:

```lua
-- CooldownTracker.lua
CT.defaults[12345] = 180  -- 3 minutes
```

To start tracking it from combat log, no other code change is needed:
`CooldownTracker:OnCombatLogEvent` already records anything that has a
default duration on `SPELL_CAST_SUCCESS`.

## Adding New Strategy Rules

Strategy lives in two places, by design:

1. **`Data/Strategies.lua`** — comp signatures, default callouts, swap
   targets, danger notes. Pure data, no logic.
2. **`StrategyEngine.lua`** — scoring weights and mode-decision
   heuristics. Logic, but parameterized via the `SE.weights` table.

To add a new comp:

```lua
-- Data/Strategies.lua
table.insert(ST.comps, {
    id    = "BEAST_CLEAVE",
    label = "Hunter / Warrior / X",
    core  = { HUNTER = true, WARRIOR = true },
    openTarget = "HUNTER",
    swapTarget = "WARRIOR",
    callouts = { "CALL_FREEDOM_WAR", "CALL_AVOID_OVERCHASE" },
})
```

To add a new callout, add the locale string in `Locales/enUS.lua`
(and optionally `Locales/zhCN.lua`).

## File Layout

```
ArenaCleaveCoachTBC/
├── ArenaCleaveCoachTBC.toc
├── Core.lua                 -- event wiring + slash commands + state mgmt
├── EventBus.lua             -- tiny pub/sub over a single WoW frame
├── Data/
│   ├── Spells.lua           -- centralized spell ID database
│   ├── Classes.lua          -- class -> role / armor / specs
│   └── Strategies.lua       -- comp signatures and default callouts
├── StrategyEngine.lua       -- scoring + recommendation builder (tested)
├── CooldownTracker.lua      -- observe combat log -> enemy CDs
├── DRTracker.lua            -- diminishing return categories
├── UI.lua                   -- movable frame, icon rows, recommendation text
├── Options.lua              -- Blizzard interface panel
├── WeakAuraBridge.lua       -- exposes _G.ArenaCleaveCoachTBC API
├── Locales/
│   ├── enUS.lua
│   └── zhCN.lua
├── Tests/
│   └── StrategyEngine_spec.lua
└── README.md
```

## License

MIT.
