# CurseForge project description — paste these into the dashboard

Open [the CurseForge dashboard for this project](https://authors.curseforge.com/#/projects/1552792) and paste each block into the matching field.

---

## Project Name (top of page)

```
ArenaCoachTBC — Real-time PvP Strategy Coach
```

---

## Summary (one-line, ~250 char limit)

```
Real-time PvP strategy coach for TBC Anniversary. Identifies enemy comps with spec inference, picks kill targets, plans CC chains, calls swaps and defensives. Works in arena, battlegrounds, world PvP, and duels. Advice only — never automates.
```

---

## Categories (left sidebar)

- **Class** → PvP
- **Combat** → Combat → Arena
- **Combat** → Combat → Battlegrounds

---

## Tags

```
arena, pvp, coach, strategy, battleground, world-pvp, comp-tracker,
cooldown-tracker, dr-tracker, chain-planner, opponent-profile, weakauras
```

---

## Game Versions

- **TBC Classic 2.5.5** (current Anniversary client — `Interface: 20505`)
- **TBC Classic 2.5.4** (compatible — older Anniversary builds)

---

## Description (rich text body — paste into the description editor)

````markdown
# ArenaCoachTBC

A real-time PvP strategy coach for **World of Warcraft TBC Anniversary / TBC Classic**. Watches your fight, identifies the enemy comp (including specs), picks a kill target, plans CC chains, and surfaces a live recommendation:

> **OPEN** · **KILL** · **SWAP** · **DEFEND** · **RESET**

The addon shows the current call as a big mode-coloured label on the screen, with the target name, HP %, kill probability, top callouts, and the matched comp directly below. A pulsing screen-edge glow follows the mode colour (red KILL, orange SWAP, blue DEFEND, yellow OPEN) so your peripheral vision keeps up too. Enemy nameplates of the kill and swap targets get coloured borders so you can pick them out in a crowded fight.

> ⚠️ **Advice only.** ArenaCoachTBC never casts spells, never targets enemies, never clicks protected buttons, never modifies secure macros. It only renders visual, audio, and text recommendations. Anything that crosses into protected actions is rejected by design.

---

## What you get

| Feature | Notes |
|---|---|
| **Spec-aware comp matching** | 100+ enemy comps in the catalog; matches confirm spec (Disc Priest vs Shadow Priest) once it sees specific casts and tailors advice accordingly |
| **CC chain planner** | Reads the comp + DR state to pick the highest-expected-value chain (e.g. *Sap into Kidney* vs *Fear into Burst*) and narrates it |
| **Opponent profiles (Bayesian)** | Per-team behaviour priors that learn from your repeat opponents (e.g. *this priest always trinkets Fear → save Tremor for HoJ*). Local-only, no cloud |
| **Lookahead / expectimax** | Scores chains × likely opponent responses to pick the highest-EV opener |
| **Burst gate** | Holds the BURST callout until every gate passes (MS active, no incoming pressure, Bloodlust not blocking, etc.) — and tells you which gate fired when it doesn't |
| **Rating-aware aggression** | `auto` mode reads `GetPersonalRatedInfo` and tunes swap-threshold + burst aggression by bracket rating |
| **Screen edge glow** | Mode-coloured pulsing band on the four screen edges — peripheral-vision cue, never blocks the action |
| **Nameplate highlight** | Red border on the kill target's nameplate, orange on the swap candidate. Coexists with Plater / KuiNameplates / TidyPlates |
| **Audio cues** | One-shot WoW sound on every mode transition + on key callouts (HoJ landed, Tremor, etc.). Arena-only by default |
| **City auto-hide** | Frame stays hidden in cities / quest hubs. No FPS hit while flagged in Stormwind |
| **`/acc off` master switch** | One command to fully dormant the addon. Persists across `/reload` |
| **Bilingual** | English + Simplified Chinese, parity-gated in CI. Spell names follow the client's `GetLocale()` |

---

## Works in every PvP context

| Context | What the engine does |
|---|---|
| **Arena 2v2 / 3v3 / 5v5** | Full engine: comp ID, spec inference, chain planning, opponent profiles, lookahead, burst gating, all visual + audio alerts |
| **Battlegrounds** (WSG / AB / AV / EotS) | Engine adapts: nameplate-based enemy discovery, flag-carrier priority, low-HP straggler boost, BG-specific callouts. PUG'd rosters fall back to per-class behavioural priors |
| **World PvP / duels** | Engine simplifies: single-target focus, no swap thrash, no comp matching. `DUEL_REQUESTED` auto-engages |
| **Cities / questing** | Frame hides automatically. Engine short-circuits. No background CPU cost |

---

## Works with any team composition

There's no "tuned-for" team. `OwnComps:Infer` walks your party and returns a capability table — `hasMortalStrike`, `hasBloodlust`, `hasFreedom`, `hasMassDispel`, `hasMainHealer`, etc. — then picks an archetype:

- **MELEE_CLEAVE** — ≥2 melee + healer. Aggressive kill-pressure callouts.
- **CASTER_CLEAVE** — ≥2 casters + healer. Ground / dispel callouts.
- **DRAIN** — Affli / Shadow Priest sustain. Mana-burn callouts.
- **JUNGLE** — Hunter + Feral + healer. Trap + scatter setup.
- **DOUBLE_HEALER** — 2+ healers. Mana drain plan.

The 100+ enemy comps in the catalog carry `ownVariants`, so the same enemy team gives different advice depending on your archetype. No hardcoded class assumptions in the engine.

---

## Installation

1. **Download** the latest zip from this page, or via the CurseForge app.
2. **Extract the `ArenaCoachTBC/` folder** into `<WoW>/_classic_/Interface/AddOns/`
3. **Restart the client** (or `/reload` if already in-game). ArenaCoachTBC should appear in the AddOns list, enabled.
4. If "Out of Date" appears at character-select, enable **Load out of date AddOns**.

---

## First-run checklist (~3 min)

```
/acc help              -- show all slash commands
/acc test              -- 14s scripted UI demo (paints the full HUD)
/acc unlock            -- enable dragging the frame
/acc lock              -- freeze position
/acc selftest verbose  -- in-client validation
```

After `/acc test` the recommendation frame walks through 7 beats over 14 seconds. **If you see the demo, the addon is loaded and working.** Move the frame to a corner you'll actually look at during a match.

---

## Slash commands

| Command | What it does |
|---|---|
| `/acc help` | Print the command list |
| `/acc toggle` | Show / hide the recommendation frame |
| `/acc lock` / `/acc unlock` | Lock / unlock the frame for dragging |
| `/acc off` / `/acc on` | **Master switch.** Stops the engine + hides every visual layer. Persists across `/reload`. Aliases: `/acc disable`, `/acc enable` |
| `/acc glow [on\|off]` | Toggle the screen-edge glow |
| `/acc nameplate [on\|off]` | Toggle nameplate highlights for KILL / SWAP targets |
| `/acc test` | Arena 7-beat UI demo (full HUD) |
| `/acc test bg` | Battleground walk-through |
| `/acc test world` | World PvP walk-through |
| `/acc enemy <c1> <c2> ...` | Simulate a custom enemy comp |
| `/acc strategy safe \| balanced \| greedy` | Manual aggression override |
| `/acc selftest [verbose]` | In-client validation |
| `/acc trace [on\|off\|dump\|clear]` | Decision-trace ring buffer |
| `/acc record [on\|off\|dump\|clear]` | CLEU recording for offline replay |
| `/acc whatif skip <i>` | Counterfactual replay (skip event #i) |
| `/acc bugreport` | Sanitised error report for GitHub issues |
| `/acc reset` | Wipe SavedVariables + `/reload` |

---

## Privacy & safety

- **No automation, ever.** No spells cast, no targets switched, no protected buttons clicked, no secure macros modified.
- **Local-only learning.** Per-opponent profiles (`db.profiles`) and per-class priors (`db.classPriors`) live entirely in SavedVariables. They never leave your machine. No telemetry, no analytics, no cloud sync.
- **Player names never stored.** Profile keys hash class composition + a djb2 hash of player names. The names themselves are discarded; only the hash persists.
- **`/acc reset`** wipes every stored profile and CLEU recording instantly.

---

## Customising the display with WeakAuras

The built-in HUD covers what most users want — no WeakAura needed. For power users who want a custom display, the addon publishes its full recommendation through `_G.ArenaCoachTBC` and fires `WeakAuras.ScanEvents("ACC_RECOMMENDATION", rec)` on every evaluation.

The GitHub repo includes `docs/weakaura-pack.md` with trigger Lua snippets for 5 ready-made templates (mode badge, burst gate, defensive alert, callout stream, comp readout) you can paste into a hand-built WeakAura.

> Note: the previous "paste-ready import strings" path was removed in v2.2.6. The `node-weakauras-parser` library used to generate them produces strings that decode correctly but fail WeakAuras' import-validator byte check. The trigger-code path is the supported route.

---

## Localization

- **English** (enUS, canonical) — 110 callout / UI keys
- **Simplified Chinese** (zhCN) — parity-gated in CI
- **Spell names** follow the WoW client's locale via `GetSpellInfo(spellID)` — no hardcoded English

Want another locale? Open an issue on GitHub and add `Locales/<locale>.lua` with the same key set.

---

## Compatibility

- **Game version**: TBC Anniversary 2.5.5 (`Interface: 20505`). Also loads on TBC Classic 2.5.4 if your client doesn't enforce strict version match.
- **No conflicts** with Gladius, sArena, OmniCC, OmniBar, Plater, KuiNameplates, TidyPlates (we never modify protected nameplate elements).
- **`/acc bugreport`** generates a sanitised error report for filing on GitHub.

---

## Links

- 🐛 **Report bugs / request features**: [GitHub Issues](https://github.com/tomqwu/ArenaCoachTBC/issues)
- 📝 **Changelog**: [CHANGELOG.md](https://github.com/tomqwu/ArenaCoachTBC/blob/main/CHANGELOG.md)
- 📦 **Source code**: [GitHub repo](https://github.com/tomqwu/ArenaCoachTBC)
- 🧪 **608 tests, 99%+ coverage**, locale parity gate, CI on every push

---

## License

MIT. Free to use, fork, modify, redistribute.
````

---

## Screenshots needed (optional but recommended for CF visibility)

CurseForge lets you upload up to 10 screenshots. Suggested set:

1. **HUD in action** — `/acc test` showing mode label + target stats + edge glow + nameplate border
2. **BG mode** — frame in WSG showing flag-carrier priority
3. **DEFEND alert** — blue mode with steady defensive cue
4. **Comp badge** — `RMP (confirmed Disc Priest)` after spec inference
5. **Bridge API** — chat showing `/acc trace dump` output (proves the depth)
6. **Slash command help** — `/acc help` output

If you don't have these handy, ship without screenshots — the description is the primary signal.

---

## After pasting

CF descriptions render with their own light Markdown subset. Some tweaks may be needed in the editor preview:

- Triple-backtick code blocks render fine
- Tables render fine
- Quote blocks (`>`) render as a tinted box
- Emoji renders fine on the modern CurseForge layout
- Heading hierarchy: CF treats the project title as h1, so start your description at h1 (which becomes the first big banner heading)
