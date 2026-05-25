# Manual smoke checklist

Run this before tagging a release. Tests cover what they can; in-game
behaviour is what tests can't see.

## Install + load

- [ ] Fresh client: copy `ArenaCoachTBC/` into `WoW/_classic_/Interface/AddOns/` (or `_classic_era_` for Anniversary)
- [ ] At login screen, addon listed and enabled, no "Out of date" warning
- [ ] Login: no Lua errors in BugSack / `/console scriptErrors 1`

## Slash commands

- [ ] `/acc` prints help text
- [ ] `/acc help` same
- [ ] `/acc toggle` hides and shows the frame
- [ ] `/acc lock` toggles drag-lock; frame can be repositioned when unlocked
- [ ] `/acc reset` wipes SavedVariables; `/reload` restores defaults
- [ ] `/acc debug` toggles debug printing
- [ ] `/acc test` walks through a series of sample comps; UI updates each step
- [ ] `/acc enemy war mage priest druid pala` populates manual enemy list and engine emits a recommendation

## Visual

- [ ] Frame visible after login + in-arena
- [ ] OPEN / KILL / SWAP / DEFEND / RESET modes each render with a distinct colour
- [ ] Callouts list scrolls (or truncates) cleanly when > 4 items
- [ ] URGENT callouts flash the screen briefly (configurable)

## In-arena

- [ ] Join 2v2 / 3v3 / 5v5 skirmish or rated arena
- [ ] Engine identifies the comp via the frame, WeakAura bridge, or `/acc trace dump` within 5 seconds of gates opening
- [ ] At least one swap target callout fires during the match
- [ ] Trinket tracker correctly flips `enemy.hasTrinket` after a known trinket cast
- [ ] DR tracker registers Fear / HoJ / Cyclone properly

## Integration

- [ ] WeakAuras sample (from `docs/weakaura-pack.md` once available) displays the recommendation correctly
- [ ] No conflict with: Gladius / sArena / OmniCC / OmniBar (test with each individually)

## After arena

- [ ] No accumulated Lua errors
- [ ] `/acc trace dump` (if enabled) shows a coherent decision log
- [ ] SavedVariables file is still valid Lua (open in editor, check syntax)

## Sign-off

Tester: __________________
Date: __________________
Client build: __________________
Result: PASS / FAIL (attach screenshots if FAIL)
