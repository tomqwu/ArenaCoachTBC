# Changelog

All notable changes to **ArenaCoachTBC** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Live arena observations now scan unit auras for Mortal Strike, Windfury, Bloodlust/Heroism, and enemy burst buffs before each evaluation, so burst gating is driven by observed state instead of permanently missing `msActiveOn` / `windfuryActive` flags.
- Train detection now counts damage events only when they land on friendly healers, preventing ordinary melee damage on DPS teammates from forcing DEFEND mode.
- Arena unit refresh now clears stale class/GUID/spec data when an `arenaN` or party unit disappears, preventing old rosters from polluting later comp identification.
- EventBus handler failures are captured by `ErrorReporter`, so `/acc bugreport` includes real in-addon handler errors instead of only manually captured failures.
- Cold Snap and Icy Veins now use distinct spell IDs and cooldown durations.
- Dev prerelease tags (`vX.Y.Z-dev.N`) are skipped by the release workflow's tag-trigger path so they cannot be republished as stable releases.

### Changed
- Strategy scoring now applies `openTarget` / `swapTarget` hints from the comp catalog, exposes `secondaryTargetClass`, and makes `strategy.aggression` affect the SWAP threshold.
- CI now runs the standalone `StrategyEngine_spec.lua` smoke spec in addition to the coverage suite.

### Added
- **CC chain primitive (#59, opens M8).** New `Chain.lua` module. A chain is an ordered list of CC links `{ spellID?, target, category, by, castTimeS? }`. `Chain:Build(links)` constructs one; `Chain:Validate(chain)` returns `(ok, reason)` after walking links and rejecting on DR-immune (`reason="DR_immune"`), pending caster CD (`reason="cd_pending"`), or empty input (`reason="empty"`). `Chain:ExpectedProb(chain)` returns the product of effective DR multipliers across links (0 if any CD is pending or DR has already hit immune). Within-chain DR accumulation is tracked so a chain of three STUNs on the same target correctly returns expected probability `1.0 * 0.5 * 0.25 = 0.125`. Pure module; reads observation state from `DRTracker` / `CooldownTracker` without touching any WoW API directly. Foundation for #60 (per-comp built-in chains), #61 (chain scoring + lookahead), and #62 (CALL_CHAIN callout renderer).

### Quality
- **End-to-end spec-match test suite (#58).** `Tests/SpecMatchE2E_spec.lua` drives spec attribution through the real `SpellSpecHints:Apply` path (concrete spell IDs from `Data/Spells.lua`) and asserts `Strategies:Identify` picks the right spec-keyed variant. 15 cases covering each spec-keyed comp variant (RMP_DISC, SMR, WLD_RESTO, WLD_FERAL, SHATTERPLAY_SHADOW, SHATTER_FROST_2V2, HUNTER_PRIEST_BM_2V2), confidence calibration (1/3 vs 2/3 vs 1.0), wrong-spec disqualification (Holy priest → class-only RMP, not RMP_DISC), bracket isolation (a 2v2 shadow-priest setup never matches a 3v3 spec-keyed comp), and a catalog invariant that every spec-keyed comp's required spec is reachable from at least one `SpellSpecHints` entry.

### Added
- **Comp-match confidence scoring (#56).** `Strategies:Identify` now returns `(comp, confidence)` where confidence is in `[0..1]`. Spec-keyed matches return `1.0` by construction; dynamic role-count comps (`TRIPLE_DPS`, `DOUBLE_HEALER`) return `1.0`; class-only matches return the ratio of core-class enemies whose `specGuess` has been observed; legacy class-list-only callers (no enemies map) return `0.0`. The recommendation gains two new fields — `compConfidence` and `compSpecConfirmed` — and the reason text appends a `<COMP_ID> spec-confirmed|class-guessed (NN.NN)` tag so `/acc trace` and `/acc bugreport` payloads show the confidence inline. UI subText renders a localized badge: `<compLabel> (spec-confirmed|class-guessed)`. Two new locale keys — `COMP_BADGE_SPEC_CONFIRMED` and `COMP_BADGE_CLASS_GUESSED` — added in `enUS` and `zhCN`. `WeakAuraBridge` exposes `GetCompConfidence()` and `GetCompSpecConfirmed()`. Two-value return is backward-compatible — single-assignment callers silently drop the new value.
- **Spec-keyed comp catalog (#55).** `Data/Strategies.lua` comps gain an optional `specs = { CLASS = "SPEC" }` field. `Strategies:Identify` matches spec-keyed entries only when every required spec is explicitly observed via `enemy.specGuess` from spec inference; mismatched or unknown specs disqualify the spec-keyed entry so a class-only sibling declared later catches the fallback. Seven new spec-keyed variants seeded: `SHATTER_FROST_2V2`, `HUNTER_PRIEST_BM_2V2`, `SMR_3V3` (Shadow Priest variant of RMP), `RMP_DISC_3V3`, `WLD_FERAL_3V3` (no-healer variant, defaults to DEFEND), `WLD_RESTO_3V3`, `SHATTERPLAY_SHADOW_3V3`. Callers using the legacy class-list-only signature never match a spec-keyed comp because spec data only flows via the enemies map — so backward compatibility is preserved.
- **Spec inference v2 (#57).** `Data/SpellSpecHints.lua` expanded from 12 to 57 hints covering all 9 classes × 3 specs. Aura-applied hints (Shadowform, Vampiric Embrace, Spirit of Redemption, Moonkin Form, Tree of Life, Soul Link) and talent-implying casts (Vampiric Touch, Pain Suppression, Power Infusion, Holy Shield, Avenger's Shield, Repentance, Mana Tide, Tidal Force, Elemental Mastery, Shamanistic Rage, Shield Slam, Last Stand, Swiftmend, Mangle Bear, Siphon Life, Conflagrate, Shadowburn, Shadowfury, Arcane Power, Slow, Presence of Mind, Pyroblast, Combustion, Dragon's Breath, Icy Veins, Summon Water Elemental, Mutilate, Cold Blood, Blade Flurry, Adrenaline Rush, Premeditation, Shadowstep, Hemorrhage, Bestial Wrath, Intimidation, Silencing Shot, Readiness, Wyvern Sting) all carry definitive spec attribution. `Core.onCLEU` now routes `SPELL_AURA_APPLIED` / `SPELL_AURA_REFRESH` (not just `SPELL_CAST_SUCCESS`) through `SpellSpecHints:Apply`, so auras already in effect at the start of a match still teach the engine.
- **WeakAura template pack** (`docs/weakaura-pack.md`) — five copy-paste trigger templates (mode badge, burst gate, defensive alert, callout list, comp readout) that consume the `_G.ArenaCoachTBC` bridge. `WeakAuraBridge.L(key)` exposed so templates can resolve callout keys to the user's active locale without re-implementing the fallback chain.
- **`/acc record` CLEU recording + `tools/replay.lua`.** When `record` is on (default off), every CLEU event passed through `Core.onCLEU` is appended to `ArenaCoachTBCDB.record.events` (ring buffer, default cap 1000). `tools/replay.lua <SavedVariables.lua>` re-runs the captured log through the StrategyEngine offline and prints periodic recommendation snapshots, so a maintainer can second-guess specific calls without recreating the arena. `/acc record on/off/status/dump/clear`. enUS + zhCN `HELP_RECORD` strings.
- **`/acc bugreport` error reporter.** `ErrorReporter.lua` module with `Capture(err, ctx)`, `Recent(n)`, `Reset()`, `Format(maxErrors)`, `Sanitize(text)`, `SetKnownNames({...})`. Ring buffer caps at 20 captured errors. Sanitisation strips `Player-XXX-XXX` GUIDs, bare `guid-...` tokens, `Name-Realm` patterns, and any character names registered via `SetKnownNames`. `/acc bugreport` prints a markdown payload (addon version + client build + last 5 sanitised errors) ready to paste into a GitHub issue. enUS + zhCN `HELP_BUGREPORT` / `BUGREPORT_HEADER` strings.

### Quality
- **Locale parity gate** added to CI (`tools/check_locales.lua`). Runs before the Lua test suite. Diffs every locale file's key set against `enUS` and exits non-zero with an explicit `<locale> missing N key(s):` listing. The existing `Locales_spec.lua` parity test stays in place as a second layer.
- **Performance budget enforced as tests.** `Tests/Performance_spec.lua` asserts `StrategyEngine:Evaluate` averages <5ms per call on a 5v5 state (target <1ms; the 5x CI margin tolerates noisy GH runners) and that 100 back-to-back simulated arenas stay within a 200kb GC delta (issue's 100kb target plus 2x slack for the spec framework). Catches scoring-loop regressions and enemy/cooldown table leaks before they ship.

### Added
- **Decision-trace logging.** `/acc trace on` records every `Evaluate` recommendation (mode, target, reason, comp, bracket, callouts) into a ring buffer in SavedVariables. Defaults: disabled, cap 200 entries. `/acc trace off`, `/acc trace status`, `/acc trace dump`, `/acc trace clear`. Lets users (or me) post-mortem why the engine called a swap by inspecting the persistent log between sessions.
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
