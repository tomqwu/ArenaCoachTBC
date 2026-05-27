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
- [ ] `/acc off` (alias `/acc disable`) hides the frame + thin edge cue + nameplate paint and short-circuits the engine; persists across `/reload`
- [ ] `/acc on` (alias `/acc enable`) re-enables; the frame returns once you enter a PvP context
- [ ] `/acc glow on|off` toggles the optional thin edge cue independently of the master switch
- [ ] `/acc nameplate on|off` toggles nameplate highlighting (KILL = red border, SWAP = orange) independently
- [ ] `/acc reset` wipes SavedVariables; `/reload` restores defaults
- [ ] `/acc debug` toggles debug printing
- [ ] `/acc test` runs the readable ~1-minute realistic 3v3 arena replay through the engine: starts OPEN before gates, shows defensive pressure when the healer is CCed/trained, returns to an offensive kill/swap call, then resets without rapid flicker.
- [ ] With `/acc off` active, `/acc test` prints an enabled-for-test line and the HUD still advances instead of staying on the initial waiting text.
- [ ] `/acc test hud` runs the visual-only prototype-A HUD demo: integrated board with left focus panel, center action, right cue panel, lower assignments, nameplate border on any visible enemy, and the thin edge cue only if `/acc glow on` is enabled. The first/waiting beat already shows all four zones with placeholders.
- [ ] `/acc test bg` runs the battleground walk-through (flag carrier priority, low-HP straggler, CALL_BG_DEFEND)
- [ ] `/acc test world` runs the world-PvP walk-through (single-target focus)
- [ ] `/acc enemy war mage priest druid pala` populates manual enemy list and the engine emits a recommendation

## Visual

- [ ] Frame visible in arena / BG / world PvP / duel; **hidden in cities and quest hubs** (auto-hide gate, v2.2.5)
- [ ] OPEN / KILL / SWAP / DEFEND / RESET modes each render with a distinct colour (yellow / red / orange / blue / grey)
- [ ] HUD top-right version marker matches the installed addon release
- [ ] Main HUD board stays compact (roughly 460x168 before user scaling) and does not cover party frames, arena frames, action bars, cast bars, nameplates, DBM bars, WeakAura clusters, chat, or damage meters
- [ ] Prototype-A zones are present inside one visible board: left focus, center action, right cue/icon rail, and lower assignments, including waiting/pre-gate placeholders before live target data arrives
- [ ] `/acc unlock` lets the integrated board drag; `/acc lock` prevents it from moving
- [ ] Arcade warning plate renders passive cues (`!! READY !!`, `!! BURST !!`, `!! DANGER !!`, `!! PINCH !!`) inside the compact toast without covering the playfield
- [ ] Target stats row shows `HP <n>%   kill <n>%   BURST READY` when there's a primary target; hidden on DEFEND / RESET
- [ ] Assignment module shows one compact action per living friendly in 3v3; in 5v5 normal mode it caps at three lines, while `/acc verbose on` shows all five
- [ ] Left focus strip shows current primary target and a pressured friendly when known
- [ ] Right cue rail shows callout icons/text for burst, purge, HoJ, peel, dispel, or other top cues
- [ ] If no fresh evaluation arrives for a few seconds, the HUD text fades away and clears stale nameplate/edge cues
- [ ] Optional edge cue is thin, static, low-alpha, and dark on RESET; it must not pulse or flash around the screen
- [ ] DEFEND/URGENT does not create a full-screen red flash; use HUD colour, nameplate, arcade cue, and sound cues instead
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

## Real-fight capture

- [ ] Before queueing, run `/acc on`, `/acc trace on`, `/acc record on`, and `/combatlog`
- [ ] Play one real arena, battleground, or world-PvP fight where the advice feels wrong, late, or absent
- [ ] After the fight, run `/acc trace dump` and `/acc record status`; then `/reload` or logout so SavedVariables are written
- [ ] Keep the matching `Logs/WoWCombatLog*.txt` file and `WTF/Account/<account>/SavedVariables/ArenaCoachTBC.lua`
- [ ] Replay the addon recording with `lua5.1 tools/replay.lua <path/to/ArenaCoachTBC.lua>` and compare the last recommendations with the screenshot or clip

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
