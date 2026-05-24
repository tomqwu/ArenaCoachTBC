# Changelog

All notable changes to **ArenaCoachTBC** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- M1 foundations: LICENSE (MIT), CONTRIBUTING guide, issue templates, PR template, manual smoke checklist.

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
