# Repository Guidelines

## Project Structure & Module Organization

`ArenaCoachTBC/` is the addon folder intended for `Interface/AddOns/`. `Core.lua` wires WoW events and slash commands, `StrategyEngine.lua` contains testable scoring logic, and `UI.lua`, `Options.lua`, and tracker modules handle client-facing behavior. Data tables live in `ArenaCoachTBC/Data/`, locale files in `ArenaCoachTBC/Locales/`, and headless specs in `ArenaCoachTBC/Tests/`. Helper scripts live in `tools/`; docs and release notes stay at the repository root and under `docs/`.

## Build, Test, and Development Commands

- `lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua` runs the full Lua test suite with coverage.
- `luacov && tail -n 20 luacov.report.out` generates and summarizes coverage; keep total coverage at or above 99%.
- `lua5.1 ArenaCoachTBC/Tests/StrategyEngine_spec.lua` runs the standalone strategy smoke spec used by CI.
- `lua5.1 tools/check_locales.lua` checks that every `enUS` locale key exists in other locale files.
- `lua5.1 tools/replay.lua <path/to/ArenaCoachTBC.lua>` replays recorded SavedVariables combat logs against the engine.

There is no npm or make build. Manual test by copying `ArenaCoachTBC/` into the WoW Classic addon directory and using `/acc help` or `/acc test`.

## Change Workflow

For every new feature or fix, work in this order: code, docs, tests, CI, then release-tag workflow. Do not tag a release from local changes unless explicitly asked.

## Coding Style & Naming Conventions

Use Lua 5.1 only; avoid LuaJIT-specific features. Match the existing four-space indentation and module-table style. Keep `StrategyEngine.lua` pure and free of WoW API calls; put client-coupled work in `Core.lua`, `UI.lua`, or tracker modules. Prefer defensive nil checks because arena units disappear often. Use module-local aliases near the top, for example `local S = ns.Spells`. Do not use `print()` in production paths; use the gated debug helper pattern already in the codebase.

## Testing Guidelines

Place tests in `ArenaCoachTBC/Tests/` using the `*_spec.lua` naming pattern. Update or add specs with every behavior change, especially when editing data tables, recommendations, cooldowns, DR, locales, or SavedVariables compatibility. Locale additions must update every locale file or intentionally document placeholders.

## Commit & Pull Request Guidelines

History uses short imperative summaries, often with milestone prefixes such as `M5 quality: locale parity gate as a CI step`. Keep PRs focused, list test commands run, and update `CHANGELOG.md` under `[Unreleased]` unless chore-only.

## Safety & Configuration Notes

ArenaCoachTBC provides visual, audio, and text advice only. Never add protected-action automation, simulated input, combat chat triggers, or non-opt-in telemetry. New spell IDs should include a source comment such as Wowhead or an in-game tooltip reference.
