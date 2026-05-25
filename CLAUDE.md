# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

**ArenaCoachTBC** is a World of Warcraft addon for TBC Classic / TBC Anniversary arena. It watches arena state via WoW events, infers both your team's capabilities and the enemy comp, and emits a real-time recommendation (`OPEN | KILL | SWAP | DEFEND | RESET`) with a target, callouts, and a burst-go/no-go flag.

**Hard constraint — advice only, never automation.** The addon does not cast spells, target enemies, click protected buttons, send chat as a combat trigger, or modify secure macros. Any change that crosses into protected actions or simulated input is rejected. This is not a code-style preference — it is the product.

## Commands

```bash
# Full test suite with coverage (193 tests, must stay >= 99% line coverage)
lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua
luacov && tail -n 20 luacov.report.out

# Run a single spec file directly (no coverage)
lua5.1 ArenaCoachTBC/Tests/StrategyEngine_spec.lua

# Locale parity gate — every enUS key must exist in every other locale
lua5.1 tools/check_locales.lua

# Replay a recorded SavedVariables CLEU log through the engine
lua5.1 tools/replay.lua <path/to/ArenaCoachTBC.lua>

# Syntax-check every Lua file (CI does this first)
cd ArenaCoachTBC && for f in $(find . -name '*.lua'); do luac5.1 -p "$f" || echo "FAIL: $f"; done
```

There is no npm / make build. To smoke-test in-client, copy `ArenaCoachTBC/` into `<WoW>/_classic_/Interface/AddOns/` and use `/acc help` or `/acc test`. The slash-command surface and manual smoke checklist live in `ArenaCoachTBC/README.md` and `docs/manual-smoke.md`.

CI (`.github/workflows/test.yml`) runs syntax check → locale parity → test suite → 99% coverage gate on every push/PR. Releases are driven by `.github/workflows/release.yml`: every push to `main` auto-publishes a `v{base}-dev.{run}` prerelease zip, and pushing a `vX.Y.Z` tag publishes a stable release plus CurseForge / Wago uploads.

## Architecture

The addon is split along a **WoW-coupled vs. pure** axis. This split is what lets 99% of the logic be tested outside the game.

### The engine boundary

- `StrategyEngine.lua` is **pure** — no `CastSpellByName`, no `UnitGUID`, no `CreateFrame`. It takes a `state` table and returns a recommendation table. Tests call `SE:Evaluate(state)` directly with a hand-built state. **Do not introduce WoW API calls into this file** — that breaks the headless test harness and is treated as a regression.
- `Core.lua` is the WoW-coupled side. It subscribes to events through `EventBus`, maintains live `enemies` / `friendlies` state tables, calls `StrategyEngine:Evaluate()`, and pushes the result into `UI.lua` and `WeakAuraBridge.lua`. All `CombatLogGetCurrentEventInfo`, `UnitAura`, `GetTime`, etc. live here or in the tracker modules.
- `UI.lua`, `Options.lua`, `CooldownTracker.lua`, `DRTracker.lua`, `ErrorReporter.lua`, `Simulator.lua`, `SelfTest.lua` are WoW-coupled. Tests stub `CreateFrame` and friends in `Tests/test_helpers.lua`.

### Capability-first design

The engine never says "if class == PRIEST then dispel." Instead:

1. `Data/OwnComps.lua` — `OwnComps:Infer(friendlies)` returns a **capability table** (`hasMortalStrike`, `hasBloodlust`, `hasMassDispel`, `hasFreedom`, `hasMainHealer`, ...). Then `OwnComps:Identify` picks an **archetype** (`MELEE_CLEAVE`, `CASTER_CLEAVE`, `DRAIN`, `JUNGLE`, `DOUBLE_HEALER`).
2. `Data/Strategies.lua` — `Strategies.comps` is a catalog of enemy comp signatures (RMP, WMS, WLD, WLP, RLS, ...). Each entry can carry an `ownVariants` table so the same enemy comp gives different advice to different own archetypes.
3. `StrategyEngine.lua` reads capabilities and the matched comp variant — not class assumptions. **Adding "if class is X" to the engine is a regression.** New advice goes into `Data/OwnComps.lua` (a new capability) or `Data/Strategies.lua` (a new comp / variant).

### Scoring is a transparent weighted sum

`SE.weights` (a flat table near the top of `StrategyEngine.lua`) is the single source of tuning. Each alive enemy gets `score = role + vulnerability + teamSynergy − danger`. The highest-scoring enemy becomes `primaryTarget`, the second becomes `secondaryTarget` (swap candidate). Per-bracket overrides live in `SE.bracketWeights`; callers must use `SE:GetWeights(bracket)` rather than reading `SE.weights` directly so future bracket tuning lands without touching call sites.

### Data is the source of truth

| Concern | File |
|---|---|
| Spell IDs (every category — interrupt, defensive, dispel, CD, immunity) | `Data/Spells.lua` |
| Class → role / armor / specs | `Data/Classes.lua` |
| Capability inference + archetype detection | `Data/OwnComps.lua` |
| Enemy comp catalog + per-archetype `ownVariants` | `Data/Strategies.lua` |
| Spell → likely spec hints | `Data/SpellSpecHints.lua` |
| `/acc test` simulator scenarios | `Data/SimScenarios.lua` |

Locales are similar — `Locales/enUS.lua` is canonical, every callout / UI string is a **locale key** that the engine returns and the UI/text layer resolves. The engine never returns user-facing English.

### Public API contract

`WeakAuraBridge.lua` exposes `_G.ArenaCoachTBC` (getters only — `GetRecommendation`, `GetMode`, `IsBurstAllowed`, `HasCapability`, ...) and fires `WeakAuras.ScanEvents("ACC_RECOMMENDATION", rec)` on every evaluation. **This is a stable contract** — third-party WeakAuras consume it. Add getters; do not rename or remove them. The version constant is `## Version:` in `ArenaCoachTBC/ArenaCoachTBC.toc` and is returned by `GetVersion()`.

## Code conventions

- **Lua 5.1 only** — the Anniversary client uses 5.1. No LuaJIT-specific features, no `goto`, no integer division, no bitops without `bit.*`.
- **Four-space indent**, module-table style. Each file starts with `local ADDON_NAME, ns = ...` and writes into `ns.<Module>`.
- **Defensive nil checks everywhere** — arena unit IDs become invalid often. `if u and UnitExists(u) then` is normal.
- **Module-local aliases at the top** — `local S = ns.Data.Spells`.
- **No `print()` in production paths.** Use `Core.DebugPrint(msg)` (gated by `db.debug`).
- **Backwards-compatible SavedVariables.** `Core.lua > DEFAULTS` is merged into existing `ArenaCoachTBCDB` on login; never break old user configs.
- **Spell IDs need a source comment** — Wowhead URL or in-game tooltip reference — when added to `Data/Spells.lua`.

## Tests

- Specs live in `ArenaCoachTBC/Tests/` named `*_spec.lua` and are all run in one Lua process by `Tests/run_all.lua` (so luacov captures a single stats file).
- `Tests/test_helpers.lua` mocks `CreateFrame`, `C_Timer`, `UnitAura`, etc., and exposes a `H.run()` harness.
- Spec order in `run_all.lua` matters — data files load before the engine, engine before UI, Core last.
- Update or add specs with every behavior change, especially when editing data tables, scoring weights, cooldowns, DR categories, locales, or SavedVariables shape. Locale additions must update **every** locale file (the parity gate fails CI otherwise).

## Where to add things (quick map)

| Adding... | Goes in... |
|---|---|
| A tracked spell | `Data/Spells.lua` (ID + category) + a `Spells_spec.lua` assertion |
| A new enemy comp | `Data/Strategies.lua` entry with `ownVariants` block |
| A new capability (e.g. `hasInterrupt`) | `Data/OwnComps.lua > capabilities` table |
| A new callout / UI string | `Locales/enUS.lua` **and every other locale file** |
| New surface for WeakAuras | `WeakAuraBridge.lua` — getter only, never setter |
| New WoW event handling | `Core.lua` (subscribe via `EventBus`), keep logic in the engine |
| New scoring factor | `SE.weights` constant + the call site that emits it, plus a spec |

## PR conventions

- Short imperative commit summaries, often milestone-prefixed: `M5 quality: locale parity gate as a CI step`, `M6 capability: /acc record CLEU log`.
- Update `CHANGELOG.md` under `[Unreleased]` (use `[skip-changelog]` in the PR title for chore-only changes).
- Tests added or updated; total coverage stays >= 99%.

## Workflow — every feature or fix follows this order

Do not skip steps or reorder them. Each stage must finish before the next starts.

1. **Code** — implement the new feature or bug fix. Engine changes go through capabilities / comp variants, not class hardcoding (see Architecture).
2. **Docs** — update the surfaces that document the change *before* asking for review:
   - `ArenaCoachTBC/README.md` (slash commands, public `_G.ArenaCoachTBC` API, scoring weights table)
   - `CHANGELOG.md` under `[Unreleased]`
   - Inline comments only where the *why* is non-obvious
   - `docs/manual-smoke.md` if there's a new in-client check to run
3. **Review with `/codex:review`** — run the `codex:review` subagent over the diff (the Codex-rescue MVP agent inside this CLI; invoke via the Skill tool or `/codex:review`). Treat its findings as blocking until addressed or explicitly justified. Do this *before* writing tests — fixing design issues after the test suite is wired is twice the work.
4. **Tests** — add or update `*_spec.lua` in `ArenaCoachTBC/Tests/`. Cover the new behavior *and* the regression direction (what would have broken before the fix). Locale additions must touch every locale file. Run locally:
   ```bash
   lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua && luacov && tail -n 20 luacov.report.out
   lua5.1 tools/check_locales.lua
   ```
   Total coverage must stay >= 99%.
5. **CI** — push the branch, open the PR, and wait for `.github/workflows/test.yml` to go green (syntax check → locale parity → tests → 99% coverage gate). Do not request merge or proceed to release while CI is red or pending.
6. **Release tag** — once merged to `main`, a dev prerelease (`v{base}-dev.{run}`) auto-publishes. For a stable cut: run `docs/manual-smoke.md`, move `[Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD` in `CHANGELOG.md`, bump `## Version:` in `ArenaCoachTBC.toc`, then `git tag vX.Y.Z && git push origin vX.Y.Z`. The release workflow does the rest (GitHub release + CurseForge + Wago).
