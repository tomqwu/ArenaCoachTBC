# Manual smoke checklist

Run this before tagging a release. Tests cover what they can; in-game
behaviour is what tests can't see.

## Install + load

- [ ] `lua5.1 tools/check_package_shape.lua` passes before tagging; the TOC, `.pkgmeta`, release workflow, CurseForge project ID, BCC game-version upload flag, and version constants are in sync.
- [ ] The GitHub release zip lists `ArenaCoachTBC/ArenaCoachTBC.toc`, contains more than 20 non-empty addon files, and does not include `ArenaCoachTBC/Tests/` or `.pkgmeta`.
- [ ] After pushing a stable `vX.Y.Z` tag, the GitHub `Release` workflow's BigWigs packager step succeeds and CurseForge shows the uploaded file. If CurseForge upload fails or remains under review, the release is not considered complete.
- [ ] Fresh client: copy `ArenaCoachTBC/` into `WoW/_anniversary_/Interface/AddOns/` for TBC Anniversary, or `WoW/_classic_/Interface/AddOns/` for older Classic installs
- [ ] At login screen, addon listed and enabled, no "Out of date" warning
- [ ] Login: no Lua errors in BugSack / `/console scriptErrors 1`

## Slash commands

- [ ] `/acc` prints help text
- [ ] `/acc help` same
- [ ] `/acc toggle` hides and shows the frame
- [ ] `/acc hud alert|board|both` switches between the default DBM-style alert, the full review board, and both surfaces. Switching to `alert` immediately hides the board; switching to `board` immediately hides the alert.
- [ ] `/acc lock` / `/acc unlock` toggles drag-lock; frame can be repositioned and resized from the lower-right grip when unlocked
- [ ] `/acc off` (alias `/acc disable`) hides the frame + thin edge cue + nameplate paint and short-circuits the engine; persists across `/reload`
- [ ] While `/acc off` is active, `/acc toggle` and any remaining `/acc test` timer beat do not reopen the HUD
- [ ] Turning off the AddOns options-panel "Enabled" checkbox hides the same visual layers as `/acc off`
- [ ] `/acc on` (alias `/acc enable`) re-enables; the frame returns once you enter a PvP context
- [ ] `/acc glow on|off` toggles the optional thin edge cue independently of the master switch
- [ ] `/acc nameplate on|off` toggles nameplate highlighting (KILL = red border, SWAP = orange) independently
- [ ] `/acc reset` wipes SavedVariables; `/reload` restores defaults
- [ ] `/acc debug` toggles debug printing
- [ ] `/acc test` runs the readable ~1-minute realistic 3v3 arena replay through the engine: starts OPEN before gates, shows defensive pressure when the healer is CCed/trained, returns to an offensive kill/swap call, then resets without rapid flicker.
- [ ] With `/acc off` active, `/acc test` prints an enabled-for-test line and the HUD still advances instead of staying on the initial waiting text.
- [ ] `/acc test` timed events repaint the active HUD display as chat timestamps advance; the center action should not remain `!! READY !! / waiting for opener` after the 5s and 10s scenario lines.
- [ ] `/acc test hud` runs the visual demo through the current display mode. Use `/acc hud alert` for the live DBM alert check, `/acc hud board` for the integrated board check, or `/acc hud both` when comparing both surfaces.
- [ ] `/acc test bg` runs the battleground walk-through (flag carrier priority, low-HP straggler, CALL_BG_DEFEND)
- [ ] `/acc test world` runs the world-PvP walk-through (single-target focus)
- [ ] `/acc enemy war mage priest druid pala` populates manual enemy list and the engine emits a recommendation

## Visual

- [ ] Default alert visible in arena / BG / world PvP / duel; **hidden in cities and quest hubs** (auto-hide gate, v2.2.5)
- [ ] OPEN / KILL / SWAP / DEFEND / RESET modes each render with a distinct colour (yellow / red / orange / blue / grey)
- [ ] Alert version marker matches the installed addon release; `/acc hud board` still shows the board top-right version marker
- [ ] Default alert is compact, centered, movable, low-background, and does not cover party frames, arena frames, action bars, cast bars, nameplates, DBM bars, WeakAura clusters, chat, or damage meters
- [ ] Default alert main line reads like a DBM boss warning with the mechanic/action first: `Purge Holyman`, `Tremor down - shaman refresh`, `BURST NOW`, `Kill Holyman`, or `Swap Mage`; abstract mode words such as `KILL`, `DEFEND`, `攻`, or `守` are not the big center text when a specific action exists
- [ ] `/acc hud board` shows the optional Obsidian board zones inside one visible frame: left status stack, center action, center player-info/assignments, and right cue/icon rail, including waiting/pre-gate placeholders before live target data arrives
- [ ] Optional board reads as Obsidian Signal: warm obsidian translucent shell, brass rules/reticles, cyan information accents, bone-white data text, restrained crimson signal colour, top drag strip/grip, signal/ruler accents, lower-right resize grip, internal dividers, slot backgrounds, target health bar, and mode-coloured center accent
- [ ] Board metadata strip shows `OBSIDIAN / SIGNAL / <mode>` while still keeping the top-right version marker visible
- [ ] Focus and cue headers do not wrap or split words on the optional compact board
- [ ] DEFEND and RESET hide the inactive target-health bar/label so defensive advice has a clean center panel
- [ ] Dragging the alert moves only the alert; dragging the board lower-right grip resizes the integrated board when `/acc hud board` is active
- [ ] On the optional compact board, the center action/detail text stays inside the center action section and never crosses into the player-info/assignment section
- [ ] Bottom assignment strip divides into 1, 2, 3, or 5 small cards based on current player actions/bracket; unused cells are hidden in 2v2, and 5v5 uses five stable cells
- [ ] Bottom assignment strip highlights the player's own card first with `YOU` / `你`, a stronger plate, and a readable action line before teammate cards
- [ ] On a taller/wider resized board with `/acc verbose on`, the player-info cards remain inside the bottom strip without colliding with the center action or right cue rail
- [ ] `/acc unlock` lets the alert move and the integrated board drag/resize; `/acc lock` prevents movement/resizing
- [ ] Signal strip stays passive (`SIGNAL · LIVE`) while the big center line carries the actual DBM-style action
- [ ] Target stats row shows `HP <n>%   kill <n>%   BURST READY` when there's a primary target; hidden on DEFEND / RESET
- [ ] Player-info module shows one compact action card per advised friendly in 3v3; in 5v5 it fills five small cards instead of a paragraph block, with the player's own card visually dominant
- [ ] Left status stack shows current primary target, swap target, and a pressured friendly when known
- [ ] Right cue rail shows callout icons/text for burst, purge, HoJ, peel, dispel, or other top cues
- [ ] If no fresh evaluation arrives for a few seconds, the alert or board fades away and clears stale nameplate/edge cues
- [ ] Empty `RESET` beats with no primary/swap target stay hidden instead of repeatedly popping and fading
- [ ] Optional edge cue is thin, static, low-alpha, and dark on RESET; it must not pulse or flash around the screen
- [ ] DEFEND/URGENT does not create a full-screen red flash; use HUD colour, nameplate, arcade cue, and sound cues instead
- [ ] Nameplate of the kill target gets a red border; swap target gets orange (when in SWAP mode)
- [ ] Audio cue fires on KILL and DEFEND mode flips only (v2.9: SWAP/OPEN flips are intentionally silent); arena-only
- [ ] URGENT callouts stay readable without a full-screen flash, even if an old SavedVariables file has `alerts.screenFlash = true`
- [ ] Standing in Stormwind / Orgrimmar for 30 s: no frame-rate drop (city-lag fix, v2.2.5)
- [ ] While PvP-flagged outside instances, hitting or being hit by an ordinary creature does not show the HUD; a real hostile player or duel still does

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
- [ ] Replay the addon recording with `lua5.1 tools/replay.lua <path/to/ArenaCoachTBC.lua>` and compare the redacted timeline with the screenshot or clip
- [ ] For a committed fixture, run `lua5.1 tools/replay.lua --golden ArenaCoachTBC/Tests/Fixtures/<name>.golden.txt ArenaCoachTBC/Tests/Fixtures/<name>.lua`; use `--update-golden` only when the changed advice is intentional
- [ ] Convert repeatable wrong-advice cases into `docs/arena-fixtures.md` acceptance snapshots or golden replays

## Facts HUD (v2.9)

- [ ] In a skirmish / duel near the arena vendor, the facts panel appears with one row per enemy (class-coloured name + HP%)
- [ ] Enemy trinket use flips `T+` (green) to `T-2m` (red) and the countdown ticks down every second; the loud chord cue fires once (not twice for the cast+aura pair)
- [ ] Enemy Ice Block / Divine Shield / BoP / CloS shows in the defensive column with a countdown; the short ding cue fires
- [ ] After a stun chain, the DR column shows `S:1/2` then `S:1/4` then `S:IMM`, clearing ~17s after the last application
- [ ] `/acc facts off` hides the panel immediately and persists across `/reload`; `/acc facts on` restores it
- [ ] The header strip (`Name / Trinket / Defensive / Interrupt / DR`) is visible above the rows; the DR legend is visible at the bottom and wraps to at most 2 lines
- [ ] Long player names (12+ chars) and Chinese spell names truncate inside their column instead of wrapping into the next cell or under the next row
- [ ] `/acc facts legend off` + `/reload` removes the legend and shrinks the panel; `/acc facts legend on` + `/reload` restores it
- [ ] Dragging the panel persists its position across `/reload`; `/acc lock` prevents dragging
- [ ] Panel hides in cities (context `none`) and shows again on arena entry

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
