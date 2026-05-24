# ArenaCoachTBC — Roadmap

> Target: a polished public release on CurseForge & Wago, with steady
> iteration over the next 6-12 months. Each milestone is sized so it
> can ship independently.

Three permanent swim-lanes run through every milestone:

- **Ship** — packaging, releases, distribution
- **Capability** — strategy intelligence, comps, brackets, inference
- **Quality** — testing, docs, community, performance

---

## M1 — 1.0 Public Release  (2-3 weeks)

The goal: a binary on CurseForge that any TBC arena player can install
and trust on day one.

**Ship**
- [ ] Real in-WoW spell-ID verification pass (every ID in `Data/Spells.lua` confirmed against 2.5.x client)
- [ ] CurseForge packaging via `.pkgmeta` + `packager-action` workflow
- [ ] Wago packaging
- [ ] App icon + 3 screenshots + 1 short demo gif
- [ ] CHANGELOG.md (KeepAChangelog format)
- [ ] Semver discipline: tag releases as `v1.0.0` etc., GitHub Release notes auto-generated
- [ ] LICENSE file (MIT)
- [ ] Interface-version matrix: 20502, 20503, 20504, 20507 (Anniversary)

**Capability**
- [ ] Per-class PvP trinket IDs (Will of the Forsaken, Every Man for Himself, racials) — currently only shared `42292` is tracked
- [ ] Spec inference v1: observed-cast → spec table (Mind Blast → Shadow, Cyclone → Resto, Stormstrike → Enh)
- [ ] Role override updates `enemy.roleGuess` live during the match
- [ ] Default-friendlies fallback when in-game inspect fails

**Quality**
- [ ] In-game manual smoke checklist (markdown in `docs/`)
- [ ] CONTRIBUTING.md
- [ ] Issue templates (bug, feature, comp request)
- [ ] PR template with test plan section
- [ ] `/acc selftest` command that runs a built-in headless validation in-client
- [ ] Localization completeness check in CI

---

## M2 — 2v2 / 3v3 brackets  (3-4 weeks)

Currently the addon is implicitly 5v5. Brackets shift the meta sharply.

**Capability**
- [ ] Arena bracket detection via `GetBattlefieldStatus()` / `IsActiveBattlefieldArena()`
- [ ] Bracket-specific comp catalogs:
  - 2v2: drainteam, double healer, RP, RD, SP+Pally, etc.
  - 3v3: TSG, RMP, Jungle, Shatterplay, LSD, WLD, etc.
- [ ] Bracket-aware scoring weights (e.g. `role_healer` worth less in 2v2)
- [ ] Bracket-aware callouts (2v2 callouts much more "mana drain" centric)

**Ship**
- [ ] Per-bracket UI mode (single-target focus in 2v2; multi-row in 5v5)

**Quality**
- [ ] Bracket-specific test specs
- [ ] Replay corpus: 10 real matches per bracket, run engine, eyeball outputs

---

## M3 — Smarter inference  (4-6 weeks)

Make the engine *see* more, so callouts feel earned instead of generic.

**Capability**
- [ ] Cooldown availability prediction baked into score (`Ice Block ready in 47s` lowers Mage's swap-target weight)
- [ ] DR-window awareness: don't suggest a CC chain that will hit immunity
- [ ] Mana-bar tracking on enemies → "drain Mage to OOM" trigger
- [ ] Healer line-of-sight detection (best-effort: did healer cast in the last 3s on the focus target?)
- [ ] Positioning hints: enemy team grouped vs spread (from arena unit health-delta correlation)
- [ ] Pet detection for hunters/locks → call out pet stun availability
- [ ] Auto-detect "we are being trained" mode (multiple incoming damage events on our healer in N seconds → DEFEND)

**Quality**
- [ ] Inference confidence score exposed via WA bridge
- [ ] Decision-trace logging mode: write each Evaluate's full scoring breakdown to SavedVariables for offline review

---

## M4 — UX + Audio  (4-6 weeks)

Information density is good but voice + visual hierarchy beat tables
in a live arena.

**Ship**
- [ ] Voice callouts: pre-recorded short clips for "PURGE", "TREMOR", "SWAP", "DEFEND", "FREEDOM"
- [ ] Configurable color schemes per archetype
- [ ] Compact mode (single line, ~120px wide) for stream-friendly overlays
- [ ] Mini frame for low-info mode
- [ ] Prepackaged WeakAura export string in `docs/weakaura-pack.md`
- [ ] In-game options panel rewrite (current panel is text-only)

**Capability**
- [ ] User-configurable callout priorities (mute specific callouts globally)
- [ ] User-specific role overrides ("I am the healer, prioritize peel callouts")

**Quality**
- [ ] Accessibility pass: high-contrast skin, dyslexia-friendly font option
- [ ] Per-callout cooldown so the same text doesn't spam every 0.5s

---

## M5 — Telemetry + Community  (6-8 weeks)

Public addons need a feedback loop, multilingual content, and a low-
friction way to report bugs.

**Ship**
- [ ] Opt-in anonymous usage stats: which enemy comps were faced, win rate, comp identification accuracy. POST to a Cloudflare Worker. Disabled by default.
- [ ] Error reporter: pcall every public function, capture stack trace, store in SavedVariables, prompt user to attach to bug report
- [ ] Discord link + wiki link in options panel

**Quality**
- [ ] Locale flow rewrite: CrowdIn integration
- [ ] Locales added: deDE, frFR, esES, ruRU, koKR, zhTW
- [ ] Locale CI gate: every commit fails if a locale key is added to enUS without parallel entries (or marked TODO)
- [ ] Public wiki on GitHub with strategy primers per comp

---

## M6 — Hardening + LTS  (ongoing, after M5)

Once shipped, the addon needs to stay fast and not regress.

**Quality**
- [ ] Performance budget: CPU per Evaluate < 1ms on a 5y-old laptop
- [ ] Profile per-event handler with `debugprofilestop()`; assert in tests
- [ ] Memory leak fuzz: 100 arenas back-to-back, assert memory delta < N kb
- [ ] CI matrix: Lua 5.1, LuaJIT 2.0, LuaJIT 2.1
- [ ] Replay/log mode: dump all CLEU + state changes to SavedVariables; replay tool reproduces a full match outside game

**Capability**
- [ ] 2.0 architecture: split engine into its own Lua module that can be embedded in companion tools (combat log replays, web visualizer)
- [ ] Headless evaluation server (Lua + a tiny HTTP shim) for community to upload a log and get an engine analysis

---

## Operating principles

These survive across milestones; if a planned feature violates one, it gets cut.

1. **No automation, ever.** Visual/audio/text only. Any feature that crosses into protected actions is rejected.
2. **Engine stays pure Lua + testable outside WoW.** UI is the only WoW-coupled layer.
3. **99% test coverage is the floor, not the goal.** Coverage gate stays in CI.
4. **Capability-first.** New advice belongs in `Data/OwnComps.lua` capabilities or `Data/Strategies.lua` comps. Hardcoding classes into the engine is a regression.
5. **No telemetry without opt-in.** Default off, prompt-to-enable, no PII, easy to wipe.
6. **Backwards-compatible SavedVariables.** Each release runs a migration if the schema changes; old user configs always load.

---

## Tracking

Each milestone has a corresponding GitHub milestone; each checkbox above
maps to an issue. See **[ArenaCoachTBC milestones]** for live status.

Major dependencies between lanes:

```
M1 -> M2 -> M3 -> M5
       \-> M4 /
              \-> M6 (perma)
```
