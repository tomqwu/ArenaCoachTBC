# Changelog

All notable changes to **ArenaCoachTBC** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
