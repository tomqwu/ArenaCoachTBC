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
- [ ] `/acc lock` / `/acc unlock` toggles drag-lock; frame can be repositioned when unlocked
- [ ] `/acc off` (alias `/acc disable`) hides the frame + edge glow + nameplate paint and short-circuits the engine; persists across `/reload`
- [ ] `/acc on` (alias `/acc enable`) re-enables; the frame returns once you enter a PvP context
- [ ] `/acc glow on|off` toggles the screen-edge glow independently of the master switch
- [ ] `/acc nameplate on|off` toggles nameplate highlighting (KILL = red border, SWAP = orange) independently
- [ ] `/acc reset` wipes SavedVariables; `/reload` restores defaults
- [ ] `/acc debug` toggles debug printing
- [ ] `/acc test` runs the arena demo: mode label, target stats row (HP %, kill prob %, BURST READY), pulsing edge glow, nameplate border on any visible enemy. **All four visual layers should paint, not just the text** (regression-tested in v2.3.0)
- [ ] `/acc test bg` runs the battleground walk-through (flag carrier priority, low-HP straggler, CALL_BG_DEFEND)
- [ ] `/acc test world` runs the world-PvP walk-through (single-target focus)
- [ ] `/acc enemy war mage priest druid pala` populates manual enemy list and the engine emits a recommendation

## Visual

- [ ] Frame visible in arena / BG / world PvP / duel; **hidden in cities and quest hubs** (auto-hide gate, v2.2.5)
- [ ] OPEN / KILL / SWAP / DEFEND / RESET modes each render with a distinct colour (yellow / red / orange / blue / grey)
- [ ] Target stats row shows `HP <n>%   kill <n>%   BURST READY` when there's a primary target; hidden on DEFEND / RESET
- [ ] Screen-edge glow pulses (1.6 s cycle, alpha 0.18-0.42) in the mode colour; dark on RESET
- [ ] DEFEND/URGENT does not create a full-screen red flash; use HUD colour, nameplate, optional edge glow, and sound cues instead
- [ ] Nameplate of the kill target gets a red border; swap target gets orange (when in SWAP mode)
- [ ] Audio cue fires on mode flip (KILL/SWAP/DEFEND/OPEN play distinct WoW SoundKit IDs); arena-only
- [ ] URGENT callouts stay readable without a full-screen flash, even if an old SavedVariables file has `alerts.screenFlash = true`
- [ ] Standing in Stormwind / Orgrimmar for 30 s: no frame-rate drop (city-lag fix, v2.2.5)

## In-arena

- [ ] Join 2v2 / 3v3 / 5v5 skirmish or rated arena
- [ ] Engine identifies the comp via the frame, WeakAura bridge, or `/acc trace dump` within 5 seconds of gates opening
- [ ] At least one swap target callout fires during the match
- [ ] Trinket tracker correctly flips `enemy.hasTrinket` after a known trinket cast
- [ ] DR tracker registers Fear / HoJ / Cyclone properly

## Integration

- [ ] WeakAuras trigger code from `docs/weakaura-pack.md` pasted into a hand-built WA reads the recommendation correctly via `_G.ArenaCoachTBC`. (Paste-ready import strings removed in v2.2.6 — see that CHANGELOG entry.)
- [ ] No conflict with: Gladius / sArena / OmniCC / OmniBar / Plater / KuiNameplates / TidyPlates (test with each individually)

## After arena

- [ ] No accumulated Lua errors
- [ ] `/acc trace dump` (if enabled) shows a coherent decision log
- [ ] SavedVariables file is still valid Lua (open in editor, check syntax)

## Sign-off

Tester: __________________
Date: __________________
Client build: __________________
Result: PASS / FAIL (attach screenshots if FAIL)
