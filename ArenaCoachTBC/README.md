# ArenaCoachTBC

A strategy coach addon for **TBC Classic / TBC Anniversary** arena. It
watches your arena, detects both your own team capabilities and the enemy
composition, scores enemies in real time, and tells you who to open on,
who to swap to, when to burst, and when to defend.

Originally built for the 5v5 WAR/ENH/RET/RDRU/DISC melee cleave, it now
**adapts dynamically to any team comp** by inferring capabilities
(Mortal Strike? Bloodlust? Mass Dispel? Freedom? Cleanse?) from your
party and selecting an archetype-aware strategy.

> ⚠️ **This addon never automates gameplay.** It does not cast spells,
> does not target enemies for you, does not click protected buttons,
> and does not edit secure macros in combat. Everything it does is
> visual / audio / text suggestions.

---

## Installation

1. Copy the `ArenaCoachTBC` folder into:
   ```
   <WoW>/_classic_/Interface/AddOns/
   ```
2. Restart the client or `/reload`.
3. If "Out of Date" appears at character select, enable
   "Load out of date AddOns". Edit `## Interface: 20504` in
   `ArenaCoachTBC.toc` to match your client to silence the warning.

The addon stores SavedVariables in `ArenaCoachTBCDB`.

## Slash Commands

| Command                                  | Effect                                  |
| ---------------------------------------- | --------------------------------------- |
| `/acc` or `/arenacoach`                  | alias root                              |
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

### Dynamic team detection

`OwnComps:Infer(friendlies)` walks your party and returns a capability
table — booleans like `hasMortalStrike`, `hasBloodlust`, `hasFreedom`,
`hasMassDispel`, `hasCyclone`, `hasMainHealer`, etc. The engine reads
capabilities instead of hardcoded class assumptions, so a Hunter/Lock/Druid
group gets different advice than a WAR/ENH/RET cleave even against the
same RMP.

`OwnComps:Identify(friendlies, caps)` then picks an **archetype**:
`MELEE_CLEAVE`, `CASTER_CLEAVE`, `DRAIN`, `JUNGLE`, `DOUBLE_HEALER`.

### Enemy comp database

`Strategies.comps` contains an expanded catalog of enemy comp
signatures including:

```
RMP, WMS, WLD (Warlock+Druid), WLS, WLP (Warlock+Pally drain),
HUNTER_COMP, BEAST_CLEAVE, TSG (Warrior+Pally), RLS, MIRROR_MELEE,
TRIPLE_CASTER, DOUBLE_HEALER, TRIPLE_DPS
```

Each entry may carry an `ownVariants` table so the same enemy comp
gives different advice to different own teams:

```lua
{ id = "RMP",
  openTarget = "PRIEST",
  ownVariants = {
      MELEE_CLEAVE = { openTarget = "PRIEST", swapTarget = "MAGE" },
      DRAIN        = { openTarget = nil,     note = "drain mage mana" },
      JUNGLE       = { openTarget = "MAGE",  note = "scatter+fear chain" },
  },
}
```

Entries can also carry an optional `specs = { CLASS = "SPEC" }` map. A
spec-keyed comp matches only when every required spec is explicitly
observed via spec inference (`enemy.specGuess`); unknown or mismatched
specs disqualify the spec-keyed entry and the engine falls through to
the class-only sibling. This lets the catalog separate e.g.
`RMP_DISC_3V3` (disc priest, kill-the-priest plan) from `SMR_3V3`
(shadow priest, no-healer pressure) once the priest's spec has been
observed in combat.

### Scoring engine

`StrategyEngine:Evaluate(state)` scores every alive enemy with a weighted
sum (defined in `StrategyEngine.lua > SE.weights`) and returns:

```lua
{
  mode                = "OPEN"|"KILL"|"SWAP"|"DEFEND"|"RESET",
  primaryTarget       = "guid-...",
  primaryTargetName   = "Holyman",
  primaryTargetClass  = "PRIEST",
  secondaryTarget     = "guid-...",
  confidence          = 0.0 .. 1.0,
  reason              = "PRIEST [role_healer(25), trinket_down(20), ...]",
  callouts            = { "CALL_HOJ_KILL", "CALL_PURGE", "BURST_NOW" },
  priority            = "LOW"|"MEDIUM"|"HIGH"|"URGENT",
  comp                = "RMP",
  compLabel           = "Rogue / Mage / Priest",
  ownArchetype        = "MELEE_CLEAVE",
  ownArchetypeLabel   = "Melee cleave",
  ownCapabilities     = { hasMortalStrike=true, hasBloodlust=true, ... },
  burstAllowed        = true,
  burstBlockedBy      = nil,
}
```

Scoring weights are exposed as a flat table:

```lua
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

## Using ArenaCoachTBC from a WeakAura

The addon publishes its current recommendation and full state through
the global `_G.ArenaCoachTBC`. **The complete API:**

| Getter                            | Returns                                 |
| --------------------------------- | --------------------------------------- |
| `GetRecommendation()`             | full table                              |
| `GetMode()`                       | `"KILL" / "SWAP" / ...`                 |
| `GetPriority()`                   | `"URGENT" / "HIGH" / ...`               |
| `GetReason()`                     | human-readable reason                   |
| `GetConfidence()`                 | 0 .. 1                                  |
| `GetPrimaryTarget()`              | enemy GUID                              |
| `GetPrimaryTargetName()`          | unit name                               |
| `GetPrimaryTargetClass()`         | "PRIEST"                                |
| `GetSecondaryTarget()`            | swap-candidate GUID                     |
| `GetCallouts()`                   | array of locale keys                    |
| `IsBurstAllowed()`                | true / false                            |
| `GetBurstBlocker()`               | "no_ms" / "target_immune" / nil         |
| `GetEnemyComp()`                  | "RMP" / "WLD" / ...                     |
| `GetEnemyCompLabel()`             | friendly label                          |
| `GetOwnComp()`                    | "MELEE_CLEAVE" / "DRAIN" / ...          |
| `GetOwnCompLabel()`               | friendly label                          |
| `GetCapabilities()`               | full capability table                   |
| `HasCapability("hasMortalStrike")`| true / false                            |
| `GetEnemies()`                    | full enemies map                        |
| `GetFriendlies()`                 | full friendlies map                     |
| `GetEnemyByGUID(guid)`            | one enemy                               |
| `GetCombatPhase()`                | "PRE" / "ACTIVE" / "POST"               |
| `GetVersion()`                    | "1.1.0"                                 |

### Sample custom trigger

```lua
function()
    return _G.ArenaCoachTBC
       and _G.ArenaCoachTBC.GetRecommendation
       and _G.ArenaCoachTBC.GetRecommendation() ~= nil
end
```

### Sample custom text

```lua
function()
    local api = _G.ArenaCoachTBC
    if not api or not api.GetRecommendation then return "" end
    local r = api.GetRecommendation()
    if not r then return "" end
    return string.format(
        "%s: %s\n%s\nComp: %s vs %s",
        r.mode or "",
        r.primaryTargetName or r.primaryTargetClass or "",
        r.reason or "",
        r.ownArchetypeLabel or "?", r.compLabel or "?"
    )
end
```

### Capability-driven aura example

Only show a "BURST NOW" warning if our team has both MS *and* WF:

```lua
function()
    local api = _G.ArenaCoachTBC
    if not api then return false end
    return api.IsBurstAllowed()
       and api.HasCapability("hasMortalStrike")
       and api.HasCapability("hasWindfury")
end
```

### Event-driven trigger

The addon emits `ACC_RECOMMENDATION` via `WeakAuras.ScanEvents` on
every evaluation, so:

```lua
-- Trigger: Custom -> Event
-- Event: ACC_RECOMMENDATION
function(event, rec)
    return event == "ACC_RECOMMENDATION" and rec and rec.priority == "URGENT"
end
```

## Running the Tests

The headless suite runs outside WoW with stubbed APIs and enforces at least
99% line coverage over production modules.

```bash
lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua && luacov
lua5.1 ArenaCoachTBC/Tests/StrategyEngine_spec.lua
```

`run_all.lua` is the main coverage suite. `StrategyEngine_spec.lua` is a
standalone smoke spec and is run separately in CI.

CI (`.github/workflows/test.yml`) runs this on every PR and enforces a
99% minimum.

## Limitations & Assumptions

- **Enemy specs are guessed** from class alone unless observed casts
  reveal otherwise.
- **Burst gates depend on observed auras.** Mortal Strike and Windfury are
  read from live unit auras when the client exposes them; missing aura data
  keeps burst calls conservative.
- **Cooldown durations** are conservative TBC 2.4.3 values; edit
  `CooldownTracker.lua > CT.defaults` for TBC Anniversary tweaks.
  When unsure, we mark a CD ready rather than block on unknowns.
- **DR window** defaults to 17s; tune `DRTracker.lua > DR.resetWindow`.
- **PvP trinket** uses the shared aura `42292`. Class-specific
  trinkets need their own IDs.
- **No automation** — by design.

## Adding / Adjusting

- **Spell IDs**: `Data/Spells.lua` is the single source of truth.
- **Enemy comps**: `Data/Strategies.lua` — add a table entry.
- **Own archetypes / capabilities**: `Data/OwnComps.lua`.
- **Locales**: `Locales/enUS.lua` and `Locales/zhCN.lua`.

## File Layout

```
ArenaCoachTBC/
├── ArenaCoachTBC.toc
├── Core.lua                 -- event wiring + slash commands + state
├── EventBus.lua             -- tiny pub/sub
├── Data/
│   ├── Spells.lua           -- spell ID database
│   ├── Classes.lua          -- class -> role / armor / specs
│   ├── OwnComps.lua         -- capability inference + archetype detection
│   └── Strategies.lua       -- enemy comp catalog + ownVariants
├── StrategyEngine.lua       -- scoring + recommendation
├── CooldownTracker.lua
├── DRTracker.lua
├── UI.lua
├── Options.lua
├── WeakAuraBridge.lua       -- _G.ArenaCoachTBC API
├── Locales/{enUS,zhCN}.lua
├── Tests/
│   ├── test_helpers.lua       (mocks + harness)
│   ├── run_all.lua            (runs every spec in one process)
│   └── *_spec.lua             (headless specs plus standalone smoke tests)
└── README.md
```

## License

MIT.
