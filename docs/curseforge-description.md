# CurseForge Project Description

Paste the blocks below into the CurseForge project dashboard for project `1552792`.

---

## Project Name

```text
ArenaCoachTBC - Real-time PvP Strategy Coach
```

---

## Summary

```text
Real-time PvP strategy HUD for TBC Anniversary. Shows arena, battleground, duel, and world-PvP advice: opener, kill target, swap, defensive warning, burst gate, nameplate highlight, and per-player assignments. Advice only; never casts or targets.
```

---

## Categories

- Class -> PvP
- Combat -> Arena
- Combat -> Battlegrounds

---

## Tags

```text
arena, pvp, tbc, anniversary, coach, strategy, battleground, world-pvp, duel, cooldown-tracker, dr-tracker, weakauras
```

---

## Game Versions

- TBC Anniversary / TBC Classic 2.5.5 (`Interface: 20505`)
- TBC Classic 2.5.4 compatible if your client allows loading older-interface addons

---

## Description

````markdown
# ArenaCoachTBC

ArenaCoachTBC is a real-time PvP strategy HUD for **World of Warcraft TBC Anniversary / TBC Classic**. It watches the current fight, builds a live picture of enemies and teammates, and turns that state into short tactical advice:

> **OPEN** - plan the opener before gates open
> **KILL** - stay on the current kill target
> **SWAP** - switch to a better target
> **DEFEND** - peel, use defensives, or save a teammate
> **RESET** - no clean kill window; line, stabilize, or drink

It is built for players who want DBM-style PvP reminders without automation and without a flashing screen. The addon does not play the game for you. It gives readable visual, audio, and text cues so you can make faster decisions.

## What You Experience In Game

### Before Arena Gates Open

The HUD shows an **OPEN** call with the recommended opener target. For example, into Rogue / Mage / Priest it may show the priest as the opener target and prepare your team for Tremor, Grounding, dispel, or CC setup reminders.

### During The Match

The central HUD updates as the fight changes:

- **KILL: Priest** with target HP and estimated kill chance
- **SWAP: Mage** when the mage becomes a better target than the current one
- **DEFEND** when your healer is low, crowd-controlled, or under repeated pressure
- **BURST READY** only when the burst gates pass
- **Assignments** showing your own compact action first with a bright YOU marker, then teammate jobs such as Warrior MS, Shaman purge, Paladin HoJ, Priest dispel, or Druid Cyclone

The text fades out if the fight state stops refreshing, so stale instructions do not sit on the screen after the situation has moved on. Empty RESET beats with no target stay hidden instead of repeatedly popping and fading. The default live display is a compact DBM-style alert; the optional Obsidian board can stay visible with waiting placeholders before gates open when you want the larger review/tuning layout.

### In Battlegrounds

The engine switches to battleground behavior. It uses nearby hostile players and nameplates instead of arena unit IDs, boosts Warsong flag carriers, favors low-HP stragglers when appropriate, and uses BG-specific defensive callouts.

### In World PvP And Duels

The addon simplifies the advice. It focuses on the current enemy, avoids noisy swap calls, and can still show DEFEND when you are low or being pressured. Ordinary PvE mob combat does not wake the HUD while you are only PvP-flagged; the world fallback requires hostile player evidence.

### In Cities Or Idle Areas

The HUD hides itself. It does not keep painting stale PvP text while you are standing around in a city, quest hub, or idle world-PvP state.

## Core Features

### Live PvP Recommendations

ArenaCoachTBC evaluates the current fight and returns one clear mode: **OPEN**, **KILL**, **SWAP**, **DEFEND**, or **RESET**. The mode determines HUD color, optional sound, nameplate behavior, and the top callout.

### Kill Target And Swap Target Advice

Enemies are scored with transparent PvP signals: role, class armor type, health, mana, trinket state, active immunities, purgeable defensives, Mortal Strike, HoJ readiness, Windfury, crowd-control pressure, and battleground objectives.

### Spec-Aware Composition Matching

The catalog contains named enemy strategy entries across 2v2, 3v3, 5v5, and dynamic matchups. Spec inference uses a curated set of spec-defining spell hints — for example, a priest can start as an unknown Priest and later become Disc, Holy, or Shadow after the addon observes defining spells.

### Facts HUD (v2.9)

A separate movable panel shows one row per living enemy with the **observed facts** serious arena players run a dedicated cooldown tracker for:

- Trinket status (`T+` up / red countdown after a medallion or WotF use)
- The downed major defensive coming back soonest (Ice Block, Divine Shield, BoP, Cloak of Shadows, Pain Suppression, Nature's Swiftness, Barkskin, Evasion, Vanish, Deterrence, Shamanistic Rage) — v2.10 shows a small spell icon next to the countdown
- Downed interrupts (Kick, Counterspell, Spell Lock, Pummel, Earth Shock) — a visible free-cast window for your healer
- Diminishing-returns badges per CC category (`S:1/2`, `F:IMM`)

Cells stay empty until a use is observed — the HUD never guesses. Toggle via `/acc facts on|off`. Companion audio cues fire only on observed enemy actions: a loud chord when an enemy burns their CC-break, a short ding when they burn an immunity. Arena-only, deduped per guid+spell in a 3s window.

### Class-Keyed Middle Alert (v2.10)

The big middle line on the DBM-style alert always reads `Class: Name` ("Mage: Sam", "Priest: Holyman", ...) coloured to the target class — mage blue, priest white, warrior brown, druid orange, paladin pink, hunter green, rogue yellow, shaman blue, warlock purple. Mode urgency stays legible via the kicker text and the mode-colour accent strip; concrete actions and personal jobs move down to the sub-line.

### Always-On Opponent Profile Learning (v2.10)

Every match accumulates a Bayesian opponent profile from the live combat log — no `/acc record on` step required. Currently learned tendencies:

- `trinketsFear` — does this opponent break fears with their PvP trinket?
- `iceBlockBelow30` — does this opponent's mage Ice Block panic at < 30% HP?

After ~5 observations against the same team signature, the profile becomes opinionated and the engine begins using it. After every arena, a `Learned this match:` summary prints. `/acc learned` exposes the same dump on demand.

### Burst Gate

The addon does not simply yell "burst" whenever a target is low. It checks multiple gates first:

- target is not immune
- active major defensives are not covering the target
- Mortal Strike, Aimed Shot, or Wound Poison is on the actual target when your roster can provide healing reduction
- your team has a relevant control, interrupt, purge, or dispel answer for the window
- configured Windfury requirement is satisfied
- melee can connect
- kill probability is high enough for your aggression setting
- incoming pressure is not forcing DEFEND
- optional chain readiness, if enabled

If burst is blocked, the decision records every failed gate for trace and WeakAura displays. If it passes, the addon exposes a timed kill window so DBM-style bars can count down the moment to commit burst or Bloodlust.

### DBM-Style Player Assignments

Each recommendation can include per-friendly assignments. The default live HUD is a compact DBM-style alert/action stack: it puts the player's own job first, keeps the strategic target/context nearby, and uses slow bar-style decay so the last useful instruction remains readable without becoming a fixed dashboard. The optional Obsidian board remains available for review, tuning, screenshots, and users who prefer a cockpit layout. That board uses a left status stack for current targets/pressure, a center action and target-health instrument, a bottom player-first assignment strip, and a right cue rail for icon/text reminders. It follows the Obsidian Signal visual language: warm translucent obsidian reading plates, burnished brass rules and surveyor reticles, cyan intelligence accents, bone-white data, and restrained crimson for committed/urgent signal. The board has a top drag strip, grip marker, signal/ruler accents, lower-right resize grip, internal dividers, subtle slot backgrounds, a target health bar, a mode-coloured center accent, and shadowed/highlighted text so users can see where to drag/resize it and where each module belongs without covering the fight with a dark panel. The bottom strip divides into 1, 2, 3, or 5 small fixed cards based on current player actions, alive friendlies, or bracket, so 2v2/3v3/5v5 jobs keep stable positions instead of becoming a paragraph block. Examples:

- Warrior: MS / Hamstring -> kill target
- Shaman: Purge / shock -> kill target
- Paladin: HoJ kill target -> priest
- Priest: Dispel / Mana Burn -> target
- Druid: HoTs / Cyclone -> teammate or off-target

These are passive advice lines only. They are never clickable action buttons.

### Nameplate Target Highlight

The kill target gets a red nameplate border. The swap candidate gets an orange border. This helps you find the correct target in busy arena, battleground, and world-PvP fights. The addon does not replace or modify native nameplate bars, so it can coexist with Plater, KuiNameplates, TidyPlates, Gladius, and sArena.

### Non-Flashing Visual Warning Style

ArenaCoachTBC uses a central arcade-style warning word such as **READY**, **ATTACK**, **SWITCH**, **DANGER**, **BURST**, **HOLD**, **PUSH**, or **PINCH**. Optional edge cues are thin, static, low-alpha lines. The live recommendation path does not trigger a full-screen flashing overlay.

### Audio Cues

Arena-only sound cues can play on mode changes and important callouts. The sounds use built-in WoW SoundKit IDs, so there are no bundled audio files to install.

### WeakAura Bridge

Power users can build their own displays using the public `_G.ArenaCoachTBC` API. The bridge exposes the current recommendation, mode, priority, target, callouts, player assignments, burst decision, comp confidence, kill probability, PvP context, and version. It also fires:

```lua
WeakAuras.ScanEvents("ACC_RECOMMENDATION", rec)
```

The repository includes `docs/weakaura-pack.md` with trigger snippets for hand-built WeakAuras.

### Local Trace, Replay, And Self-Test Tools

Useful commands are built in:

- `/acc selftest verbose` validates the addon in-game
- `/acc test` runs a timed arena replay and repaints the HUD from engine recommendations on every beat
- `/acc trace dump` shows recent decisions and why they happened
- `/acc record on` records local combat-log events for offline replay
- `/acc whatif skip <i>` replays a local recording with one event skipped
- `/acc bugreport` prints a sanitized report for GitHub issues

## Safety And Privacy

ArenaCoachTBC is advice-only:

- It never casts spells
- It never changes targets
- It never clicks protected buttons
- It never modifies secure macros
- It never sends combat chat commands
- It does not include default-on telemetry

Learning and recordings are local SavedVariables only. `/acc reset` clears saved addon data.

## Slash Commands

| Command | What It Does |
|---|---|
| `/acc help` | Show all commands |
| `/acc test` | Run a readable ~1-minute realistic 3v3 arena replay through the engine |
| `/acc test hud` | Run the visual-only arena HUD demo (current display mode) |
| `/acc test bg` | Run a battleground demo |
| `/acc test world` | Run a world-PvP demo |
| `/acc test print` | Legacy chat-only summary of sample comps |
| `/acc enemy <classes>` | Simulate a custom enemy comp (e.g. `/acc enemy war mage priest`) |
| `/acc toggle` | Show or hide the HUD |
| `/acc lock` / `/acc unlock` | Lock or drag/resize the HUD |
| `/acc off` / `/acc on` | Master disable or enable |
| `/acc hud alert\|board\|both` | Choose live DBM alert, full board, or both |
| `/acc verbose on\|off` | Toggle multi-callout HUD (default: only the top callout) |
| `/acc highcontrast on\|off` (alias `/acc hc`) | High-contrast skin |
| `/acc glow on\|off` | Toggle the optional thin edge cue |
| `/acc nameplate on\|off` | Toggle nameplate highlights |
| `/acc facts on\|off` | Toggle the per-enemy Facts HUD (v2.9) |
| `/acc learned` | Print Bayesian tendencies learned about the current opponent (v2.10) |
| `/acc strategy safe\|balanced\|greedy` | Set aggression manually |
| `/acc selftest verbose` | Run in-client validation |
| `/acc trace on\|off\|dump\|clear\|status` | Inspect engine decisions (default-on in v2.10) |
| `/acc record on\|off\|dump\|clear\|status` | Manage local CLEU recording (default-on in v2.10) |
| `/acc whatif skip <i>` | Counterfactual replay of the current recording |
| `/acc simulate <key>` | Run a named scripted scenario through the engine |
| `/acc bugreport` | Print sanitized diagnostic text |
| `/acc debug` | Toggle debug logging |
| `/acc reset` | Wipe SavedVariables and reload |

## Installation

1. Download the latest `ArenaCoachTBC-vX.Y.Z.zip`.
2. Extract the inner `ArenaCoachTBC` folder into:

```text
World of Warcraft/_anniversary_/Interface/AddOns/
```

or your client-specific Classic addon folder.

3. Restart the game or run `/reload`.
4. Enable "Load out of date AddOns" if your client reports an interface mismatch.
5. Run `/acc test` to verify the engine-driven arena replay and HUD appear.

## Localization

ArenaCoachTBC currently ships:

- English (`enUS`)
- Simplified Chinese (`zhCN`)

Both locales are parity-checked in CI; the per-locale key count is published in `CHANGELOG.md` alongside each release. Spell names are resolved by the WoW client through spell IDs, so they follow the language of your client where Blizzard provides localized spell data.

## Project Quality

The addon is developed as a pure Lua 5.1 project with headless tests for the strategy engine and WoW API stubs for UI/core behavior. Current release validation (test count + coverage percentage refresh with each release — see `CHANGELOG.md`):

- ≥ 99% line coverage gate (build fails below)
- Locale parity check
- Lua syntax check across every `.lua` in the addon
- Golden replay regression
- Package shape verification (TOC, release zip layout, no Tests/ in the zip)
- GitHub Actions on push and release tags
- BigWigs packager → CurseForge + Wago upload on stable tags

## Links

- Source: https://github.com/tomqwu/ArenaCoachTBC
- Issues: https://github.com/tomqwu/ArenaCoachTBC/issues
- Changelog: https://github.com/tomqwu/ArenaCoachTBC/blob/main/CHANGELOG.md

## License

MIT. Free to use, fork, modify, and redistribute.
````

---

## Screenshot Suggestions

CurseForge approval does not require all of these, but they make the page clearer:

1. `/acc test` showing the realistic arena replay with OPEN, DEFEND, kill/swap, and reset advice.
2. `/acc test hud` showing the central HUD, arcade warning word, target stats, assignments, and nameplate border.
3. A DEFEND state with the blue HUD and defensive assignments.
4. A battleground demo showing flag-carrier or low-HP target priority.
5. `/acc trace dump` showing the decision trace.

---

## Notes For The CurseForge Editor

- CurseForge supports headings, lists, tables, links, and code blocks.
- If a table renders poorly in preview, convert it to bullet points.
- Keep the safety/privacy section visible; it answers the most common moderation concern for PvP addons.
