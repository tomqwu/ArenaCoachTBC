# Contributing to ArenaCoachTBC

Thanks for considering a contribution. ArenaCoachTBC is a TBC Classic arena
strategy coach — **visual / audio / text suggestions only, no automation,
ever**. Any change that crosses into protected actions or simulates input
will be rejected.

## Quick start

```bash
git clone https://github.com/tomqwu/wow_tbc_arena_pvp_strategy.git
cd wow_tbc_arena_pvp_strategy

# Run the test suite (requires Lua 5.1 + luacov)
sudo apt-get install lua5.1 luarocks
sudo luarocks --lua-version=5.1 install luacov
lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua
luacov && tail -n 20 luacov.report.out
```

Tests must pass and **total coverage must stay >= 99%**. CI enforces this.

## Project layout

| Path | Purpose |
|---|---|
| `ArenaCoachTBC/Core.lua` | Event wiring, state, CLEU dispatch. Coupled to WoW API. |
| `ArenaCoachTBC/StrategyEngine.lua` | Pure scoring + mode selection. No WoW API allowed here. |
| `ArenaCoachTBC/Data/Spells.lua` | Spell IDs + categorisations. Source of truth for the trackers. |
| `ArenaCoachTBC/Data/OwnComps.lua` | Capability inference from own team composition. |
| `ArenaCoachTBC/Data/Strategies.lua` | Named enemy comps + per-archetype variants. |
| `ArenaCoachTBC/UI.lua` | Frame layout. WoW API allowed. |
| `ArenaCoachTBC/WeakAuraBridge.lua` | `_G.ArenaCoachTBC` getter surface. Stable contract. |
| `ArenaCoachTBC/Tests/` | All headless tests. Run outside WoW via stub helpers. |

## Where to add things

| You want to... | Add to... |
|---|---|
| Track a new spell | `Data/Spells.lua` (ID + category + tests) |
| Recognise a new enemy comp | `Data/Strategies.lua` with `ownVariants` block |
| Add a capability (e.g. "has_dispel") | `Data/OwnComps.lua > capabilities` table |
| Add a new callout key | `Locales/enUS.lua` + every other locale |
| Surface state to WeakAuras | `WeakAuraBridge.lua` — getter only, never setter |

## Code style

- Lua 5.1, no LuaJIT-only constructs. Anniversary client uses 5.1.
- Defensive nil checks (`if foo and foo.bar then`). The arena unit IDs become invalid often.
- Module-local references at the top: `local S = ArenaCoachTBC.Data.Spells`.
- Prefer pure functions in `StrategyEngine`. Side effects only in `Core` / `UI`.
- No `print()` in production paths — use `_dbg(...)` (gated by `db.debug`).

## PR checklist

The PR template will remind you, but in short:

- [ ] Tests added or updated; total coverage still >= 99%.
- [ ] `CHANGELOG.md` updated under `[Unreleased]` (use `[skip-changelog]` for chore-only PRs).
- [ ] No automation introduced (no `CastSpellByName`, no `RunMacroText`, no `SendChatMessage` for combat triggers).
- [ ] If new spell IDs added, source noted in a comment (Wowhead URL or in-game tooltip screenshot).
- [ ] If new locale keys added, every locale file updated (or marked TODO).

## Filing bugs

Use the **Bug report** issue template and include:

1. Client version (`/run print(GetBuildInfo())`).
2. Addon version (`/run print(GetAddOnMetadata("ArenaCoachTBC","Version"))`).
3. Comp faced (your team + enemy team).
4. Expected behaviour vs actual.
5. Any chat-frame errors (BugSack output if installed).

## Requesting a new comp

Use the **Comp request** issue template. Include the class+spec list for the
enemy team, characteristic openers / win conditions, and (if you have one) a
sample log of a match.

## Release flow

Two kinds of releases ship from a single workflow (`.github/workflows/release.yml`):

### Rolling dev pre-releases (automatic)

**Every push to `main`** triggers the workflow, which:

1. Reads the version base from `ArenaCoachTBC.toc` (e.g. `1.1.0`)
2. Auto-tags the commit `v{base}-dev.{run_number}` (e.g. `v1.1.0-dev.42`)
3. Extracts the `## [Unreleased]` block from `CHANGELOG.md` as release notes
4. Builds the zip via [`BigWigsMods/packager`](https://github.com/BigWigsMods/packager)
5. Publishes a GitHub **Pre-release** with the zip and notes attached

Testers can always grab the latest build from the [Releases page](https://github.com/tomqwu/wow_tbc_arena_pvp_strategy/releases) without any maintainer action.

### Stable releases (manual tag)

1. Run the `docs/manual-smoke.md` checklist against a live client.
2. Update `CHANGELOG.md`: move `[Unreleased]` items into a new dated `## [X.Y.Z] - YYYY-MM-DD` section and refresh the comparison links.
3. Bump `## Version:` in `ArenaCoachTBC/ArenaCoachTBC.toc`.
4. `git tag vX.Y.Z && git push origin vX.Y.Z`.
5. The workflow extracts the `## [X.Y.Z]` block as notes and publishes a non-prerelease, plus uploads to CurseForge / Wago when those secrets are set.

### Required repository secrets

| Secret | Purpose | Get it from |
|---|---|---|
| `CF_API_KEY` | CurseForge upload token (stable releases only) | https://www.curseforge.com/account/api-tokens |
| `WAGO_API_TOKEN` | Wago.io upload token (stable releases only) | https://addons.wago.io/account/apikeys |
| `GITHUB_TOKEN` | Auto-provisioned by Actions, used for GitHub Release publish | (no action needed) |

Set the first two under **Settings → Secrets and variables → Actions**. Dev pre-releases work even without these — they just won't go to CurseForge / Wago.

## Operating principles

These are non-negotiable. If your contribution conflicts with one, it gets
declined regardless of how nice the code is.

1. **No automation, ever.** Visual/audio/text only.
2. **Engine stays testable outside WoW.** UI is the only WoW-coupled layer.
3. **99% test coverage is the floor.**
4. **Capability-first.** New advice goes in `Data/OwnComps.lua` capabilities or `Data/Strategies.lua` comps. Hardcoding classes into the engine is a regression.
5. **No telemetry without opt-in.**
6. **Backwards-compatible SavedVariables.** Old user configs always load.
