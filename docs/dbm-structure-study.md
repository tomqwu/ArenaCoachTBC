# DBM source-structure study

This note captures structural lessons from
[`DeadlyBossMods/DeadlyBossMods`](https://github.com/DeadlyBossMods/DeadlyBossMods)
for ArenaCoachTBC. It is a reference for future refactors, not a plan to copy
DBM code.

## What DBM does structurally

- Uses one repository to ship multiple addon folders: `DBM-Core`, `DBM-GUI`,
  `DBM-StatusBarTimers`, content/plugin packages, and `DBM-Test`.
- Keeps the heavy options GUI as a separate load-on-demand addon that depends on
  core.
- Keeps timer bars in a separate core dependency addon, so alert logic and bar
  rendering are not tangled.
- Discovers content packages from TOC metadata such as `X-DBM-Mod`,
  `X-DBM-Mod-MapID`, `X-DBM-Mod-Type`, and `X-DBM-Mod-MinCoreRevision`.
- Uses explicit object/module registries instead of free-floating globals:
  `private:GetPrototype(...)`, `private:NewModule(...)`, and `DBM:NewMod(...)`.
- Loads localizations before core behavior, then pre-core utilities, then main
  core, then feature modules, then object types.
- Uses a central scheduler rather than scattering ad hoc `OnUpdate` work.
- Treats test replay as a real product surface. `DBM-Test` replays recorded
  combat logs, captures warnings/timers/actions, and compares against golden
  reports.
- Uses BigWigs packager metadata to pull externals, ignore dev-only files, and
  move multiple source folders into final addon folders.

## Lessons worth adopting

- Split by responsibility before splitting by package. For ArenaCoachTBC, the
  first practical boundary is runtime coach vs options vs replay/test tooling.
- Make simulation replay event-driven and report-driven. `/acc test` should
  become a scenario runner that emits a deterministic recommendation timeline,
  not a fast visual slideshow.
- Keep the visible HUD small, but let the data model be rich. DBM separates
  warning objects, timer objects, callbacks, nameplate hooks, and test traces;
  we can do the same with recommendation, assignment, cue, and scenario objects.
- Prefer metadata-driven discovery for future optional modules. If we ever add
  separate packages, the TOC should describe bracket/context/module type instead
  of hardcoding every package in core.
- Keep options load-on-demand if the UI grows. The in-combat runtime should not
  pay for config-panel code.
- Build callbacks/events as a public integration surface. DBM exposes callbacks
  for WeakAuras and companion modules; ArenaCoachTBC already has
  `ACC_RECOMMENDATION`, and future UI styles should consume that same payload.
- Use golden replay output for real-life arena tests: input event log, expected
  recommendation timeline, expected player assignments, and expected stale-hide
  behavior.

## Lessons to avoid copying directly

- DBM is raid/boss-timer-first; ArenaCoachTBC is PvP state-estimation-first.
  Boss-mod `NewMod` objects are not the right primary abstraction for us.
- DBM allows attention-grabbing flashes by user preference. Our design direction
  stays low-flash: compact HUD, fading stale text, optional thin edge cues.
- DBM's multi-package layout is useful at scale, but premature for a single
  PvP coach. Start with internal boundaries and only split addon folders when
  install/update behavior benefits.

## Suggested ArenaCoachTBC structure path

1. Keep `ArenaCoachTBC/` as the only required addon folder for now.
2. Extract replay/scenario tooling into a clearer internal namespace:
   `ScenarioRunner`, `ScenarioReport`, and `ScenarioGoldens`.
3. Move large options/config UI toward load-on-demand style if it grows beyond
   slash-command configuration.
4. Introduce a small scheduler facade for delayed HUD fade, scenario ticks, and
   periodic cleanup so timers do not sprawl across `Core.lua` and `UI.lua`.
5. Treat UI styles as consumers of one recommendation payload: built-in Obsidian
   HUD, WeakAura bridge, and any future bar/icon view should all render the same
   data instead of re-evaluating strategy.
6. Add TOC/package gates that preserve release shape but let CurseForge own the
   actual package build when tags are pushed.

## Practical next feature from this study

The highest-value DBM-inspired feature is a realistic arena replay harness:

- record a real match or curated scenario as timestamped WoW events;
- replay it through the same state-builder path used live;
- emit a compact report of mode, target, reason, assignments, and HUD visibility;
- compare the report to a golden file in tests;
- use `/acc test rmp` in-game to run the same scenario at readable speed.

That would directly address the current biggest risk: the addon can look good in
static HUD tests while failing in real arena timing.
