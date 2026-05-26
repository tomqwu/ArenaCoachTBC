# Arena Decision Quality Pass Design

Date: 2026-05-26

## Goal

Improve ArenaCoachTBC's rated-arena recommendations so the top HUD call feels like advice from a competent arena teammate across 2v2, 3v3, and 5v5.

The pass focuses on trust and clarity. It should fix obvious player-facing misses, tighten benchmark expectations, and keep the existing pure-engine architecture intact. Battleground, world PvP, and duel behavior must remain working, but they are not the tuning target for this pass.

## Current Findings

The addon already has the right high-level flow:

1. `Core.lua` builds live state from WoW events.
2. `StrategyEngine.lua` scores targets, chooses mode, builds callouts, and selects chains.
3. `UI.lua` renders mode, target, stats, and the top callout.
4. `WeakAuraBridge.lua` and trace/record tools expose the same recommendation for power users and debugging.

The current suite passes, but the benchmark reports `17 / 21 = 81%` agreement and has player-meaningful misses:

- `TSG pre-combat -> OPEN paladin` currently returns `DEFEND`.
- `BEAST_CLEAVE pre -> OPEN hunter` currently returns `DEFEND`.
- `SHATTER 2v2 KILL mage low HP` currently chooses `PRIEST` instead of the low mage.
- `WLP drain 2v2 -> KILL paladin` currently chooses `WARLOCK`.

Two concrete comprehension issues also reduce player trust:

- The engine uses `healthPct`, but `rec.primaryTargetHp` only reads `hpPct` or `hp/hpMax`, so the HUD can omit the promised HP segment.
- `CALL_PURGE` localizes to strings containing `%s`, but the UI renders callout keys without arguments, so players can see placeholders instead of clean action text.

## Scope

In scope:

- Rated arena decisions across 2v2, 3v3, and 5v5.
- Target scoring and mode selection where current behavior conflicts with believable arena advice.
- Bracket-specific tuning for opener, kill, swap, defend, reset, and burst decisions.
- Minimal UI fixes needed for the player to understand the recommendation.
- Benchmark and regression tests that lock the improved behavior.
- Documentation and changelog updates for behavior changes.

Out of scope:

- Broad HUD redesign.
- New visual layers or major WeakAura work.
- New protected actions, targeting automation, macro changes, chat-trigger automation, or telemetry.
- Rewriting the engine or replacing the current data-driven strategy catalog.
- Optimizing BG/world PvP advice beyond preserving existing behavior.

## Design Principles

- Prefer a trustworthy top call over more information.
- Preserve existing module boundaries.
- Keep `StrategyEngine.lua` pure and headless-testable.
- Use bracket-aware rules where one generic rule produces bad advice.
- Treat benchmark misses as product bugs when they represent bad arena calls.
- Make every player-facing change regression-tested.

## Architecture

### Core State

`Core.lua` remains responsible for WoW APIs, event lifecycle, and state refresh. Existing lifecycle fixes should be preserved:

- Arena pre-gates stay `combatPhase = "PRE"`.
- `PLAYER_REGEN_DISABLED` is the real transition to active combat.
- Zone transitions clear stale enemy state, class lists, and last primary target.
- PvP context gates continue to suppress idle city/world churn.

This pass should avoid broad event-model changes. Core changes are limited to exposing cleaner arena state if tests show the engine lacks a required signal.

### Strategy Engine

`StrategyEngine.lua` is the main decision surface. The pass should make the engine distinguish these concepts more clearly:

- Target vulnerability: HP, trinket, defensives, immunity, mana, reachability, line of sight.
- Strategic value: healer role, comp opener, comp swap target, own-comp variant, bracket plan.
- Team danger: low healer, healer CC, enemy Bloodlust, multiple bursts, train pressure, outnumbered state.
- Bracket behavior: 2v2 has fewer targets and sharper kill windows, 3v3 rewards coordinated setups, 5v5 needs stronger anti-noise behavior.

The implementation should prefer small, test-backed scoring and mode changes over large refactors.

### Strategy Data

`Data/Strategies.lua` remains the matchup catalog. Benchmark misses can be fixed either by engine tuning or by targeted data corrections, depending on which explanation is more defensible:

- If the comp plan is wrong, adjust the comp entry.
- If the comp plan is right but scoring overrides it incorrectly, adjust scoring or bracket weighting.
- If unknown-spec default roles create false defensive states, adjust role inference or dynamic-comp gating.

### UI

`UI.lua` should only receive comprehension fixes for this pass:

- The HP segment should appear when the recommendation has target health from `healthPct`.
- Callouts with format placeholders must render cleanly without raw `%s`.
- Default HUD remains quiet: mode, target, stats, and one top callout.
- Verbose mode remains the place for comp badge, full callout list, chains, and diagnostics.

## End-to-End Behavior

### Pre-Gates

Before gates open, the recommendation should be `OPEN` when there is a known enemy target. It should not flip to `KILL` before combat starts. The target should come from the bracket-aware matchup plan, adjusted by own-comp archetype where existing data supports it.

Pre-gate callouts should be setup-oriented, such as HoJ, Tremor, Grounding, Cleanse, or avoid-overchase advice. They should not imply that burst should already be committed.

### Active Combat

During active combat, `KILL` should mean the selected target is the best current kill target, not simply the highest generic role weight. Low HP, trinket down, defensive availability, immunity, and comp plan should combine into a bracket-specific call.

Healer bias should help when the healer is the correct plan. It should not override obvious kill windows such as a low-HP mage in a shatter 2v2 unless a tested strategic reason exists.

### Swap

`SWAP` should fire only when the new target is materially better than the current target. Thresholds remain bracket-aware:

- 2v2 can swap earlier when a decisive kill window appears.
- 3v3 uses moderate thresholds to support coordinated target swaps.
- 5v5 uses stronger anti-noise thresholds because more units and events increase score churn.

### Defend

`DEFEND` should be reserved for saveable emergencies:

- Friendly healer low HP.
- Friendly healer CC.
- Enemy Bloodlust or multiple burst cooldowns.
- Real train pressure on the healer.
- Pre-gate no-healer enemy comps only when the bracket and role inference make that conclusion credible.

Unsaveable outnumbered states should continue to produce an explicit outnumbered callout and steer toward disengage or counter-kill instead of wasting defensive cooldowns.

### Burst

`BURST READY` should require both legacy hard gates and `BurstDecision` gates to agree:

- Target is not immune.
- Required Mortal Strike and Windfury gates pass when configured.
- Melee are not locked down without Freedom coverage.
- Kill probability passes the active aggression threshold.
- A chain is ready when chain gating is enabled.
- Incoming pressure does not demand defensives instead.

Blocked burst reasons should remain available through trace and bridge APIs. The default HUD does not need to show every gate.

## Testing Strategy

Development should be test-first for each player-facing problem:

1. Add or tighten a failing spec for the behavior.
2. Make the smallest engine, data, or UI change that fixes it.
3. Run the focused spec.
4. Run the full suite and locale parity before completion.

Required regression coverage:

- `TSG pre-combat -> OPEN paladin`, not fake `DEFEND`.
- `BEAST_CLEAVE pre -> OPEN hunter`, not fake `DEFEND`.
- `SHATTER 2v2 low mage -> KILL mage`, not priest.
- `WLP drain 2v2 -> KILL paladin`, not warlock.
- `rec.primaryTargetHp` is populated when target state uses `healthPct`.
- `CALL_PURGE` and other formatted callouts render without raw placeholders.
- Burst-ready display requires `BurstDecision.allowed`, not only legacy hard gates.

Bracket scenario coverage should include 2v2, 3v3, and 5v5 examples for:

- Opener.
- Active kill.
- Swap.
- Defend.
- Reset.
- Burst blocked.
- Burst ready.
- Stale-state reset.

Verification commands:

```bash
lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua
luacov && tail -n 20 luacov.report.out
lua5.1 tools/check_locales.lua
lua5.1 ArenaCoachTBC/Tests/StrategyEngine_spec.lua
```

## Acceptance Criteria

- Full Lua suite passes.
- Coverage remains at or above the repository requirement.
- Locale parity remains green.
- Benchmark hard floor is raised from `50%` to at least `85%` for rated-arena scenarios.
- The known benchmark misses listed in this spec pass as explicit regression tests.
- The HUD shows HP, kill probability, and a clean top action for kill/open/swap recommendations with a known target.
- No BG/world/duel tests regress.
- No protected-action automation or non-opt-in telemetry is added.

## Risks

- Raising benchmark expectations before adding enough scenarios could create false confidence. The benchmark should grow with representative rated-arena cases.
- Over-tuning generic healer bias could hurt comps where healer pressure is correct. Fixes should be bracket- and scenario-backed.
- Dynamic `TRIPLE_DPS` and `DOUBLE_HEALER` detection can misfire when unknown specs default to healer or hybrid roles. Tests should cover unknown-spec pre-gate states.
- UI callout formatting must stay locale-safe, especially for zhCN parity.

## Delivery Shape

This should ship as a focused quality release:

- Engine/data/UI fixes scoped to rated-arena trust.
- Tests for every behavior change.
- `CHANGELOG.md` entry under `[Unreleased]`.
- Documentation updates only where user-facing behavior or command output changes.

