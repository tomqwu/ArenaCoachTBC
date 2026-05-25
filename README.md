# ArenaCoachTBC

A real-time arena strategy coach for **World of Warcraft TBC Classic / TBC Anniversary**. Watches the fight, identifies the enemy comp (including spec), picks a kill target, plans CC chains, and emits a recommendation: `OPEN | KILL | SWAP | DEFEND | RESET`.

> **v2.0 ships the engine-depth roadmap.** Your coach now learns your opponents. A team you've played 20 times that always trinkets Fear stops getting the generic "tremor for fear" callout — Tremor gets saved for HoJ instead. A mage that consistently Ice Blocks at 30% causes the burst gate to hold. None of this is hardcoded — it learns per-team from observed combat, no character names persisted.

> ⚠️ **Advice only.** The addon never casts spells, never targets enemies, never clicks protected buttons, never modifies secure macros. It emits visual + audio + text recommendations. That's it.

---

## Works with any team composition

Earlier versions documented a specific comp (WAR/ENH/RET/RDRU/DISC melee cleave) as the "tuned-for" team. **v2 doesn't have a tuned-for comp.** `OwnComps:Infer` walks your party and returns a capability table — `hasMortalStrike`, `hasBloodlust`, `hasFreedom`, `hasMassDispel`, `hasMainHealer`, etc. — then `OwnComps:Identify` picks an archetype:

| Archetype | When it fires | What it changes |
|---|---|---|
| `MELEE_CLEAVE` | ≥2 melee + a healer | Aggressive kill-pressure callouts; prefer healer opens |
| `CASTER_CLEAVE` | ≥2 casters + a healer | Ground/dispel-heavy callouts; off-healer CC priority |
| `DRAIN` | Affli/SP-style sustain | Mana-burn / outlast callouts; no aggressive opens |
| `JUNGLE` | Hunter + Feral + healer | Trap + scatter setup callouts |
| `DOUBLE_HEALER` | 2+ healers | Mana drain plan |

The 100+ enemy comp catalog in `Data/Strategies.lua` carries `ownVariants` so the same enemy team gets different advice depending on your archetype. There's no hardcoded "if class is X" anywhere in the engine — everything goes through capability inference. **Run any comp; the engine adapts.**

---

## Installation (one-time, ~2 minutes)

1. **Download or clone this repo** to your local machine.
2. **Copy the `ArenaCoachTBC/` folder** (the inner one, the one with `ArenaCoachTBC.toc`) into your WoW addons directory:
   - **TBC Classic / Anniversary**: `<WoW install>/_classic_/Interface/AddOns/`
   - **Wrath Classic**: `<WoW install>/_classic_/Interface/AddOns/` (it'll work — Wrath isn't a primary target but the engine is)
   - **macOS path**: typically `/Applications/World of Warcraft/_classic_/Interface/AddOns/`
   - **Windows path**: typically `C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\`
3. **Restart the client** (or `/reload` if already in). Your AddOns list should now have `ArenaCoachTBC` enabled.
4. If you see "Out of Date" at the character-select screen, enable **Load out of date AddOns** at the bottom of the addon list. (Or bump `## Interface: 20504` in `ArenaCoachTBC.toc` to match your current client.)

---

## First-run checklist (~3 minutes the first time you log in)

```
/acc help              -- show all slash commands
/acc test              -- run sample comps so you see the frame appear
/acc unlock            -- enable dragging
                          (drag the frame to where you want it)
/acc lock              -- freeze it
/acc selftest verbose  -- run the in-client validation suite
```

After `/acc test` you should see a 360px frame in the centre of the screen cycling through five mock enemy comps. **If you see this, the addon is loaded and working.** Move it to a corner you'll actually look at during a match.

---

## Daily usage (during arena)

You don't run anything during an arena match. The addon auto-engages on `PLAYER_ENTERING_WORLD` when bracket detection (`UPDATE_BATTLEFIELD_STATUS`) confirms you're in a rated/skirmish arena. The frame stays hidden outside arena (unless `/acc toggle` forced it on).

**What you'll see during a match:**

1. **Pre-combat (arena gates closed)**: Mode = `OPEN`, target = the comp's default open target. Plan your opener.
2. **Active**: Mode flips to `KILL` (or `SWAP` / `DEFEND`). The big-text line tells you who to attack. The callouts row tells you what utility to use. The chain block tells you the canonical CC sequence to set up. The comp badge tells you whether the engine is confident about the enemy specs.
3. **Burst window**: When `BURST_NOW` appears (red pulsing badge), every burst gate has passed — kill probability ≥ threshold, chain ready, no incoming pressure.
4. **Defensive**: When your healer is being trained or enemy lust pops, mode flips to `DEFEND` (blue). Callouts shift to Pain Sup / BoP / peel reminders.

---

## Slash commands (full list)

| Command | What it does |
|---|---|
| `/acc help` | Print the command list |
| `/acc toggle` | Show / hide the recommendation frame |
| `/acc lock` / `/acc unlock` | Freeze or release the frame for dragging |
| `/acc test` | Cycle through 5 sample enemy comps so you can preview recommendations |
| `/acc enemy <c1> <c2> ...` | Simulate a custom enemy comp (e.g. `/acc enemy rogue mage priest`) |
| `/acc reset` | Wipe SavedVariables and `/reload` (resets all settings, profiles, recordings) |
| `/acc strategy safe\|balanced\|greedy` | Manual aggression override (or leave on `auto` for rating-aware) |
| `/acc debug` | Toggle debug print to chat |
| `/acc selftest [verbose]` | Run in-client validation |
| `/acc simulate [key\|stop]` | Replay a scripted scenario through the engine (`rmp`, `tsg-mirror`, `drain`, `chain-vs-chain`) |
| `/acc trace [on\|off\|dump\|clear\|status]` | Decision-trace log — records every `Evaluate` to inspect after the match |
| `/acc record [on\|off\|dump\|clear\|status]` | CLEU recording — captures every combat log event for offline `tools/replay.lua` analysis |
| `/acc whatif [skip <i>\|summary\|help]` | Counterfactual replay of the current `/acc record` log with one event removed |
| `/acc bugreport` | Print sanitised error report (last 5 captured errors with GUIDs stripped) — paste into a GitHub issue |

---

## Configuration

All settings persist in `ArenaCoachTBCDB` (SavedVariables). They're forward-compatible — v1 saved-variables load on v2 without resetting your tuning.

**Key knobs** (all editable via the in-game Options panel: `Interface → AddOns → ArenaCoachTBC`):

- **`strategy.ratingAggression`** = `"auto"` (default), or `"greedy"` / `"balanced"` / `"safe"`, or a number like `2200`. `auto` reads `GetPersonalRatedInfo()` and tunes thresholds.
- **`strategy.callBurstOnlyWhenMSActive`** (default `true`) — won't fire `BURST_NOW` unless Mortal Strike debuff is actively on the kill target.
- **`strategy.requireWindfuryNearby`** (default `true`) — require Windfury Totem before burst.
- **`strategy.peelTriggerWindow`** / **`peelTriggerDamage`** — train detection sensitivity (default 3 damage events in 5s force DEFEND).
- **`strategy.lookaheadEnabled`** (default `true`) — engages the M10 expectimax. Set false to fall back to greedy chain pick.
- **`frame.compactMode`** (default `false`) — hides the friendly/enemy cooldown icon rows; keeps the recommendation block.
- **`alerts.sound`** / **`alerts.screenFlash`** — voice cue + URGENT-mode screen flash toggles.

---

## Spell names and localisation

Spell IDs in `Data/Spells.lua` are **universal** (a single integer that's the same across every WoW locale). The names shown in the UI come from the **WoW client's locale** via `GetSpellInfo(spellID)` — so if you run a Chinese client you'll see Chinese spell names (e.g. *闷棍*), and an English client shows the English name (*Sap*). The addon doesn't hard-code spell text anywhere.

User-facing **callout strings** (e.g. "Tremor for fear", "They trinket Fear — save Tremor for HoJ") are addon-locale-keyed: `Locales/enUS.lua` is canonical with 95 keys, `Locales/zhCN.lua` is in parity. The addon picks the locale from `GetLocale()` automatically; override with `db.language` if you want a non-default.

---

## Customising the display with WeakAuras

The addon publishes its full recommendation through `_G.ArenaCoachTBC`. Build your own HUD by consuming the getters — see **`docs/weakaura-pack.md`** for 5 copy-paste templates (mode badge, burst gate, defensive alert, callout list, comp readout). Each is a 10-line paste into `/wa` Custom trigger.

Highlights of the bridge API:

```lua
_G.ArenaCoachTBC.GetMode()             -- "KILL" / "SWAP" / "DEFEND" / "OPEN" / "RESET"
_G.ArenaCoachTBC.GetPrimaryTarget()    -- enemy GUID
_G.ArenaCoachTBC.GetPrimaryTargetName()
_G.ArenaCoachTBC.IsBurstAllowed()
_G.ArenaCoachTBC.GetBurstDecision()    -- multi-gate breakdown
_G.ArenaCoachTBC.GetChain()            -- {id, label, expectedProb, steps, links}
_G.ArenaCoachTBC.GetKillProb(guid)
_G.ArenaCoachTBC.GetCompConfidence()
_G.ArenaCoachTBC.GetCompSpecConfirmed()
_G.ArenaCoachTBC.GetOpponentProfile()  -- read-only; the live opponent's Beta priors
_G.ArenaCoachTBC.GetTendencyMean("trinketsFear")
```

The addon also fires `WeakAuras.ScanEvents("ACC_RECOMMENDATION", rec)` on every evaluation if WeakAuras is loaded — wire a Custom Event trigger to react on each new rec instead of polling.

---

## How it learns (the M9 keystone)

The first time you fight any team, the engine has no opponent data — it falls back to comp defaults. Turn on `/acc record on` and play. The addon writes per-team behavioural profiles into `ArenaCoachTBCDB.profiles`, keyed by a hash of class composition + a djb2 hash of player names. **Names are never stored** — only the hash is.

Four binary tendencies tracked as Beta(α, β) priors:

- `trinketsFear` — when feared, do they trinket?
- `iceBlockBelow30` — mage: Ice Block at HP < 30%?
- `kicksFirstHeal` — do they kick the first big heal cast?
- `sapsPriest` — when sapping, do they pick the priest?

After ~5 observations (`MIN_SAMPLES_FOR_OPINION`) the profile becomes opinionated and starts driving callouts. After ~20 observations the posterior mean is reliable.

**To inspect what the engine knows**:
- `/acc trace on` records every `Evaluate` recommendation. `/acc trace dump` shows the last N decisions with profile contribution.
- `/acc record on` then `/acc record dump` shows the raw CLEU event count.
- `/acc whatif skip <i>` replays the recorded log with event #i removed and prints how many decisions diverged.
- `tools/replay.lua <ArenaCoachTBC.lua>` reads the SavedVariables file from another shell and reruns the engine offline — useful for post-match second-guessing.

---

## Repository layout

```
ArenaCoachTBC/        <- the addon folder (drop in Interface/AddOns/)
├── ArenaCoachTBC.toc
├── Core.lua                 -- event wiring + slash commands + state
├── EventBus.lua             -- tiny pub/sub over one WoW frame
├── StrategyEngine.lua       -- pure scoring + recommendation (tested headless)
├── Chain.lua                -- CC chain primitive (DR + CD aware)
├── OpponentProfile.lua      -- per-team Bayesian tendency profiles
├── Lookahead.lua            -- expectimax over chain × opponent response
├── Patterns.lua             -- sequence-of-cast recognition
├── Sounds.lua               -- voice callout dispatch
├── CooldownTracker.lua / DRTracker.lua  -- combat-log observers
├── UI.lua / Options.lua / WeakAuraBridge.lua / SelfTest.lua
├── Simulator.lua / ErrorReporter.lua
├── Data/
│   ├── Spells.lua           -- centralized spell ID database
│   ├── Classes.lua          -- class → role / armor / specs
│   ├── OwnComps.lua         -- capability inference + archetype detection
│   ├── Strategies.lua       -- enemy comp catalog + chains + ownVariants
│   ├── SpellSpecHints.lua   -- spell → spec inference (57 hints)
│   └── SimScenarios.lua     -- built-in /acc simulate scenarios
├── Locales/{enUS,zhCN}.lua  -- 95 keys per locale
├── Tests/*_spec.lua         -- 533 headless tests
└── README.md                -- in-addon README

docs/
├── architecture.md          -- v2 module map and recommendation shape
├── weakaura-pack.md         -- 5 copy-paste WA templates
└── manual-smoke.md          -- in-client smoke checklist

tools/
├── replay.lua               -- offline /acc record replayer
└── check_locales.lua        -- locale parity gate

_design/                     -- visual design showcase (HTML)
```

---

## Running the tests

The engine is pure Lua and headless-testable. The suite stubs every WoW API needed:

```bash
# Full suite with coverage
lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua && luacov && tail -n 20 luacov.report.out

# Single standalone spec
lua5.1 ArenaCoachTBC/Tests/StrategyEngine_spec.lua

# Locale parity (every enUS key must exist in every other locale)
lua5.1 tools/check_locales.lua

# Replay a recorded SavedVariables log through the engine
lua5.1 tools/replay.lua <path/to/ArenaCoachTBC.lua>
```

CI runs syntax check → locale parity → tests → 99% coverage gate on every push and PR. v2.0 ships with **533 tests** and an **81% baseline** agreement against hand-labelled benchmark scenarios.

---

## License

MIT.
