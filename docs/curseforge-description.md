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
- **Assignments** showing one compact action per teammate, such as Warrior MS, Shaman purge, Paladin HoJ, Priest dispel, or Druid Cyclone

The text fades out if the fight state stops refreshing, so stale instructions do not sit on the screen after the situation has moved on.

### In Battlegrounds

The engine switches to battleground behavior. It uses nearby hostile players and nameplates instead of arena unit IDs, boosts Warsong flag carriers, favors low-HP stragglers when appropriate, and uses BG-specific defensive callouts.

### In World PvP And Duels

The addon simplifies the advice. It focuses on the current enemy, avoids noisy swap calls, and can still show DEFEND when you are low or being pressured.

### In Cities Or Idle Areas

The HUD hides itself. It does not keep painting stale PvP text while you are standing around in a city, quest hub, or idle world-PvP state.

## Core Features

### Live PvP Recommendations

ArenaCoachTBC evaluates the current fight and returns one clear mode: **OPEN**, **KILL**, **SWAP**, **DEFEND**, or **RESET**. The mode determines HUD color, optional sound, nameplate behavior, and the top callout.

### Kill Target And Swap Target Advice

Enemies are scored with transparent PvP signals: role, class armor type, health, mana, trinket state, active immunities, purgeable defensives, Mortal Strike, HoJ readiness, Windfury, crowd-control pressure, and battleground objectives.

### Spec-Aware Composition Matching

The catalog currently contains **40 enemy strategy entries** across 2v2, 3v3, 5v5, and dynamic matchups. Spec inference uses **57 spell/spec hints**. For example, a priest can start as an unknown Priest and later become Disc, Holy, or Shadow after the addon observes defining spells.

### Burst Gate

The addon does not simply yell "burst" whenever a target is low. It checks multiple gates first:

- target is not immune
- configured Mortal Strike requirement is satisfied
- configured Windfury requirement is satisfied
- melee can connect
- kill probability is high enough for your aggression setting
- incoming pressure is not forcing DEFEND
- optional chain readiness, if enabled

If burst is blocked, the decision records the blocker for trace and WeakAura displays.

### DBM-Style Player Assignments

Each recommendation can include per-friendly assignments. The built-in HUD shows up to five compact lines, one per player. Examples:

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
| `/acc test` | Run a 14-second arena HUD demo |
| `/acc test bg` | Run a battleground demo |
| `/acc test world` | Run a world-PvP demo |
| `/acc toggle` | Show or hide the HUD |
| `/acc lock` / `/acc unlock` | Lock or drag the HUD |
| `/acc off` / `/acc on` | Master disable or enable |
| `/acc glow on/off` | Toggle the optional thin edge cue |
| `/acc nameplate on/off` | Toggle nameplate highlights |
| `/acc strategy safe/balanced/greedy` | Set aggression manually |
| `/acc selftest verbose` | Run in-client validation |
| `/acc trace on/dump/clear` | Inspect decisions |
| `/acc record on/dump/clear` | Manage local CLEU recording |
| `/acc bugreport` | Print sanitized diagnostic text |
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
5. Run `/acc test` to verify the HUD appears.

## Localization

ArenaCoachTBC currently ships:

- English (`enUS`)
- Simplified Chinese (`zhCN`)

Both locales are parity-checked in CI. Current locale parity is **145 keys per locale**. Spell names are resolved by the WoW client through spell IDs, so they follow the language of your client where Blizzard provides localized spell data.

## Project Quality

The addon is developed as a pure Lua 5.1 project with headless tests for the strategy engine and WoW API stubs for UI/core behavior. Current local release validation:

- **660 tests passing**
- **99%+ coverage**
- Locale parity check
- Lua syntax check
- GitHub Actions on push and release tags

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

1. `/acc test` showing the central HUD, arcade warning word, target stats, assignments, and nameplate border.
2. A DEFEND state with the blue HUD and defensive assignments.
3. A battleground demo showing flag-carrier or low-HP target priority.
4. `/acc trace dump` showing the decision trace.
5. The options/slash-command help output.

---

## Notes For The CurseForge Editor

- CurseForge supports headings, lists, tables, links, and code blocks.
- If a table renders poorly in preview, convert it to bullet points.
- Keep the safety/privacy section visible; it answers the most common moderation concern for PvP addons.
