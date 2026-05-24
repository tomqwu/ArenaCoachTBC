# Changelog

All notable changes to **ArenaCoachTBC** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Quality
- **Performance budget enforced as tests.** `Tests/Performance_spec.lua` asserts `StrategyEngine:Evaluate` averages <5ms per call on a 5v5 state (target <1ms; the 5x CI margin tolerates noisy GH runners) and that 100 back-to-back simulated arenas stay within a 200kb GC delta (issue's 100kb target plus 2x slack for the spec framework). Catches scoring-loop regressions and enemy/cooldown table leaks before they ship.

### Added
- **Train detection.** Core tracks damage events landing on our friendlies in a sliding window. When `peelTriggerDamage` (default 3) events arrive within `peelTriggerWindow` (default 5s), `state.observations.healerUnderPressure = true` and the engine forces DEFEND mode with reason `trained`. Both thresholds are configurable via `db.strategy.peelTriggerWindow` / `peelTriggerDamage`. `Core._friendlyGUIDs` is updated by every `RefreshFriendlies` so CLEU damage matching is fast.
- **DR-aware callouts.** `buildCallouts` consults `DRTracker:NextMultiplier` before emitting CC-related callouts. `CALL_HOJ_KILL` is suppressed when the kill target's STUN DR is in immune territory; `CALL_CYCLONE_OFF` is suppressed when the off-healer's CYCLONE DR is immune. No history = full multiplier = callout allowed (so the first cast still fires).
- **Cooldown-aware scoring.** `SE.weights.kill_defensive_soon = -10` penalises kill targets whose major defensive (Ice Block / Divine Shield / BoP) comes off cooldown within ~15s. Catches the "we're about to waste burst into Ice Block" case. Uses observed casts from `CooldownTracker`; no history = no penalty.
- **Mana-bar tracking on enemy healers.** When an enemy healer drops below 25% mana, the engine adds the `low_mana_healer = +20` weight to their score and emits the `CALL_LOW_MANA_PUSH` callout ("Healer low mana - push now" / "治疗蓝量低 - 压上"). `enemy.manaPct` was already populated by `RefreshArenaEnemies`; this wires it into scoring + callouts.
- **M2 catalog data.** 9 named 2v2 comps (RP / RD / Drainteam / Shatter / Enh+Priest / Hunter+Priest / War+Druid / War+Holy / SP+Pala) and 10 named 3v3 comps (RMP / WLD / Jungle / Shatterplay / LSD / RPH / Thunder cleave / Pala cleave / Ele Sham / Hunter+Lock+Priest) all tagged `bracket = 2|3`. Bracket-tagged comps win over agnostic ones when both match, so `/acc enemy rogue priest` in a 2v2 picks the `RP_2V2` entry instead of falling back to the generic catalog.
- **M2 bracket infrastructure.** `Core:UpdateBracket()` reads `GetBattlefieldStatus` and sets `state.bracket` (2, 3, or 5). Hooked to `UPDATE_BATTLEFIELD_STATUS`, `PLAYER_ENTERING_WORLD`, and `ARENA_OPPONENT_UPDATE` so the bracket is fresh whenever the engine evaluates.
- `Strategies:Identify(list, enemies, bracket)` now accepts an optional bracket arg. Comps can declare `bracket = 2|3|5` to opt into bracket-specific matching; bracket-tagged comps win over agnostic ones when both match.
- `SE:GetWeights(bracket)` returns the default scoring weights merged with any per-bracket overrides from `SE.bracketWeights`. 2v2 boosts `role_healer` to 40 (single-target healer kills win games); 3v3 raises it to 30. 5v5 uses defaults.
- `WeakAuraBridge.GetBracket()` exposes the current bracket to WeakAuras consumers.

### Added
- M1 foundations: LICENSE (MIT), CONTRIBUTING guide, issue templates, PR template, manual smoke checklist.
- Release pipeline: `.pkgmeta` + `.github/workflows/release.yml`.
  - **Every push to `main` auto-tags `v{base}-dev.{run_number}` and publishes a GitHub Pre-release** with the addon zip attached and notes extracted from the `[Unreleased]` section of `CHANGELOG.md`. Pick up the latest testable build from the [Releases page](https://github.com/tomqwu/wow_tbc_arena_pvp_strategy/releases).
  - **Pushing a stable tag `v1.2.3`** publishes a full release with notes from the matching `## [1.2.3]` CHANGELOG section. Stable releases also upload to CurseForge / Wago when `CF_API_KEY` / `WAGO_API_TOKEN` are configured.
- `## Interface-BCC: 20504` directive in `ArenaCoachTBC.toc` so the packager builds a BCC-flavoured zip without a duplicate TOC.
- `CooldownTracker` now tracks **Will of the Forsaken** (7744, Undead racial) as a separate 120s cooldown. Surfaces via the existing `CT:IsReady(guid, 7744)` / `CT:GetRemaining(guid, 7744)` API. Aura-applied events are also caught, so WotF use is recorded even if the cast event is missed.
- `Spells.CC_BREAK_RACIALS` exposes the set of racials that act as fear/CC-breaks (currently just WotF). Engine consumers can iterate this when reasoning about "any CC-break ready" without hardcoding race-specific IDs.
- `/acc selftest [verbose]` — runs ~10 fast in-client assertions covering Spells data, CooldownTracker round-trip, DRTracker, StrategyEngine, Strategies/OwnComps identification, locale resolution, EventBus emission, and the WeakAura bridge. Reports `SelfTest: N passed, M failed`. Useful when a client patch or another addon clobbers state.
- `SelfTest.lua` module with `Register` / `Reset` / `Run(verbose, printer)` / `RegisterDefaults`. Composable so future modules can register their own checks.
- **Spec inference v1.** `Data/SpellSpecHints.lua` maps spec-defining casts to `{spec, role}` (Mind Flay → Shadow priest, Holy Shock → Holy paladin, Earth Shield → Resto shaman, Mortal Strike → Arms warrior, Bloodthirst → Fury, Crusader Strike → Ret, Mangle → Feral, Stormstrike → Enhancement, Lifebloom → Resto druid, Unstable Affliction → Affliction, Shadowform → Shadow priest). On every `SPELL_CAST_SUCCESS` for an enemy GUID, `Core` calls `SpellSpecHints:Apply(enemy, spellID)` to overwrite the default class-based role with observed evidence.
- 6 new max-rank TBC spell IDs in `Data/Spells.lua` to support the hint table (SHADOWFORM, MIND_FLAY, HOLY_SHOCK, EARTH_SHIELD, BLOODTHIRST, MANGLE_CAT). All sourced as TBC 2.4.3.
- **`/acc simulate <key>`** — scripted scenario runner. Sets up a fake enemy team, schedules events on `C_Timer.After`, and drives the live UI through a full fight without an arena. Three baked scenarios: `rmp` (Rogue/Mage/Priest opener with sap → poly → kidney → CS → fear → trinket), `tsg-mirror` (melee cleave training the priest), `drain` (Affliction lock + Disc priest 2v2 pressure). `/acc simulate` with no args lists scenarios; `/acc simulate stop` cancels a run in progress.
- `Simulator.lua` + `Data/SimScenarios.lua` modules. The simulator falls back to synchronous dispatch when no `C_Timer` is available, which is what unit tests rely on.

### Changed
- Renamed `S.PVP_TRINKET` (which was incorrectly set to 7744 / Will of the Forsaken) to `S.WILL_OF_THE_FORSAKEN`. The actual PvP trinket effect remains `S.PVP_TRINKET_EFFECT = 42292`. No callers were affected — the old symbol was unreferenced outside the data file.

### Notes
- An Anniversary-flavour TOC is deferred until the interface version for that client is confirmed (tracked in #8).
- Engine scoring (`trinket_down = +20`) still keys off the 42292 aura only. Wiring a separate `cc_break_down` weight for WotF is left to a follow-up — see #9 follow-up note.
- Spec-inference hints are conservative: only spec-defining casts are listed. Spells castable by every spec of a class (e.g. Mind Blast — any priest, Frostbolt — any mage) are deliberately NOT mapped because they would mislabel an enemy. `Strategies:Identify` already consumes `enemy.roleGuess`, so the next call after a relevant cast naturally picks up the new role.

## [1.1.0] - 2026-05-24

### Added
- Dynamic own-team capability inference (`Data/OwnComps.lua`) with 5 archetypes (BURST_CLEAVE, SUSTAINED_CLEAVE, CASTER_CLEAVE, DRAIN_TEAM, BALANCED).
- 13-entry enemy comp database (`Data/Strategies.lua`) with per-archetype `ownVariants`: RMP, WMS, WLD, WLS, WLP, HUNTER_COMP, BEAST_CLEAVE, TSG, RLS, MIRROR_MELEE, TRIPLE_CASTER, DOUBLE_HEALER, TRIPLE_DPS.
- 25-getter WeakAura bridge exposed via `_G.ArenaCoachTBC`.
- CI workflow that runs all tests, computes coverage with luacov, and fails the build below 99%.

### Changed
- Renamed addon from `ArenaCleaveCoachTBC` to `ArenaCoachTBC`. The name no longer implies cleave is the only archetype supported.
- Engine reads capabilities, not class names — adding a new class will not regress existing strategies.

### Test
- 193 tests, 99.46% line coverage.

## [1.0.0] - 2026-05-23

### Added
- Initial check-in: Core, StrategyEngine, CooldownTracker, DRTracker, EventBus, UI, Options, WeakAuraBridge.
- enUS + zhCN locales.

[Unreleased]: https://github.com/tomqwu/wow_tbc_arena_pvp_strategy/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/tomqwu/wow_tbc_arena_pvp_strategy/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/tomqwu/wow_tbc_arena_pvp_strategy/releases/tag/v1.0.0
