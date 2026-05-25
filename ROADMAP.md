# ArenaCoachTBC — Roadmap (v1, retrospective)

> **Status (as of v2.3.0, May 2026):** M1-M5 substantially shipped. M6 hardening deferred. See **ROADMAP-v2.md** for the engine-depth roadmap (M7-M12) and the "What shipped after M12" section there for everything that landed beyond.

Three permanent swim-lanes run through every milestone:

- **Ship** — packaging, releases, distribution
- **Capability** — strategy intelligence, comps, brackets, inference
- **Quality** — testing, docs, community, performance

---

## M1 — 1.0 Public Release · SHIPPED v1.0 / v2.0

**Ship**
- [x] CurseForge packaging via `.pkgmeta` + BigWigs packager workflow (`.github/workflows/release.yml`)
- [x] Wago packaging — addon zip published, but Wago project ID still missing in TOC (see `project_publishing_pipeline` memory; CF_API_KEY + WAGO_API_TOKEN set as secrets)
- [x] CHANGELOG.md (KeepAChangelog format)
- [x] Semver discipline: tags `v1.x.y`, `v2.x.y`; GitHub Releases auto-published by workflow
- [x] LICENSE (MIT)
- [x] Interface-version targeting: v2.1.4 bumped to `Interface: 20505` for TBC Anniversary (game v2.5.5)

**Capability**
- [x] Per-class PvP trinket IDs in `Data/Spells.lua`
- [x] Spec inference v1 (extended to 57 hints in M7)
- [x] Role-override updates `enemy.roleGuess` live
- [x] Default-friendlies fallback when inspect fails

**Quality**
- [x] `docs/manual-smoke.md` checklist
- [x] CONTRIBUTING.md + issue / PR templates
- [x] `/acc selftest` in-client validation
- [x] Locale parity gate (`tools/check_locales.lua`) in CI

**Deferred / never started**
- "App icon + 3 screenshots + 1 short demo gif" — never produced. Optional CF polish, not blocking.
- "Real in-WoW spell-ID verification pass" — partially done as bugs surfaced. No systematic pass.

---

## M2 — 2v2 / 3v3 brackets · SHIPPED v2.0

**Capability**
- [x] Arena bracket detection via `IsActiveBattlefieldArena()` + `GetBattlefieldStatus()`
- [x] Bracket-specific comp catalogs in `Data/Strategies.lua` (RMP, WMS, WLD, WLP, TSG, Jungle, LSD, …)
- [x] Bracket-aware scoring weights (`SE.bracketWeights`, accessed via `SE:GetWeights(bracket)`)
- [x] Bracket-aware callouts (drain-heavy in 2v2)

**Ship**
- [x] Per-bracket UI mode subsumed by the generic auto-resizing frame

**Quality**
- [x] Bracket-specific tests in `Tests/` (BGModeE2E, Lookahead, …)

**Deferred**
- "Replay corpus: 10 real matches per bracket" — `/acc record` + `tools/replay.lua` shipped (v2.0); corpus collection never formalised.

---

## M3 — Smarter inference · SHIPPED v2.0

**Capability**
- [x] Cooldown availability tracking (`CooldownTracker.lua`)
- [x] DR-window awareness (`DRTracker.lua` + chain-aware validation)
- [x] Mana-bar tracking on enemies
- [x] Auto-detect "we are being trained" — sliding window of incoming damage on the healer, flips mode to DEFEND
- [x] Pet detection deferred (turned out lower-priority than M7-M12 work)
- [x] Healer LoS detection — partial via cast-observation in M9 OpponentProfile

**Quality**
- [x] Decision-trace logging (`/acc trace dump`, v2.0)
- [x] Inference confidence on the bridge (`GetConfidence` / `GetCompConfidence`)

**Deferred**
- Positioning hints — not shipped (would need group health-delta correlation).

---

## M4 — UX + Audio · SHIPPED v2.1.6 / v2.2.0 (with revisions)

**Ship**
- [x] Voice callouts (v2.1.6 audio fix) — uses numeric WoW SoundKit IDs (`Sounds.lua`). Pre-v2.1.6 the .ogg paths were broken; v2.1.6 fixed by switching to built-in client sounds.
- [x] Mode-coloured screen edge glow (v2.2.0, `ScreenEdgeGlow.lua`)
- [x] Nameplate highlight for KILL / SWAP targets (v2.2.0, `Nameplate.lua`)
- [x] Bigger 32pt mode label + target stats row (HP %, kill prob %, BURST READY) (v2.1.6)
- [x] In-game options panel (`Options.lua`)
- [x] ~~Compact mode~~ shipped in v1, **removed in v2.2.1** along with the bottom icon rows (they were never wired to live data, so the toggle had nothing to hide). See v2.2.1 CHANGELOG.
- [x] ~~Prepackaged WeakAura export string~~ shipped in v2.0, **removed in v2.2.6**. The `node-weakauras-parser` library produces strings that decode correctly but fail WeakAuras' import-validator byte check — the import preview dialog never even shows the Import button. After 6 patches chasing schema gaps we concluded the parser is fundamentally the wrong tool. `docs/weakaura-pack.md` now ships only the trigger Lua snippets users paste into a hand-built WeakAura. See v2.2.6 CHANGELOG.

**Capability**
- [x] User-configurable callout priorities — via `db.alerts.*` toggles + per-feature slash commands (`/acc glow`, `/acc nameplate`)
- [x] `/acc off` / `/acc on` master switch (v2.2.5)
- [ ] Per-callout cooldown — partially via mode-transition gating in `UI:Apply` (one cue per mode flip, not per evaluation)

**Deferred**
- Accessibility pass (high-contrast skin, dyslexia-friendly font) — not shipped.

---

## M5 — Telemetry + Community · PARTIALLY SHIPPED v2.0

**Ship**
- [x] Error reporter (`/acc bugreport`, v2.0) — pcall-wraps public surface, sanitises stack traces, formats a payload
- [x] Discord / wiki links — listed in addon README
- [ ] **Telemetry deferred indefinitely.** Opt-in anonymous usage stats (POST to a Cloudflare Worker) was the original plan; never implemented. `/acc record` provides local-only CLEU replay instead — see operating principle #5.

**Quality**
- [x] Locale flow rewrite (`Locales/{enUS,zhCN}.lua`, 110 keys per locale, parity gate in CI)
- [ ] Additional locales (deDE, frFR, esES, ruRU, koKR, zhTW) — deferred until contributor volunteers
- [x] Locale CI gate (`tools/check_locales.lua`)
- [ ] Public wiki — README sections cover the surface; no separate wiki

---

## M6 — Deferred · future hardening

These items were planned post-1.0 but moved beyond the v2 cycle. Reopen if a perf regression or compatibility issue makes them load-bearing.

- [ ] Performance budget: per-Evaluate CPU < 1 ms with `debugprofilestop()` assertions in tests. (`Tests/Performance_spec.lua` exercises a 40-enemy AV-scale Evaluate under 50 ms today; the per-evaluation budget is not enforced.)
- [ ] Memory-leak fuzz: 100 arenas back-to-back, assert memory delta < N kb. (Hooked partially in `Performance_spec.lua`.)
- [ ] CI matrix: Lua 5.1, LuaJIT 2.0, LuaJIT 2.1. (Currently 5.1 only.)
- [ ] Headless replay tool — `tools/replay.lua` ships a single-pass replay; no interactive replay UI.
- [ ] Headless evaluation server (HTTP shim) — never attempted.
- [ ] Embedded-engine companion (web visualizer that reuses the pure modules outside WoW) — never attempted.

---

## Operating principles

These survive across milestones; if a planned feature violates one, it gets cut.

1. **No automation, ever.** Visual / audio / text only. Any feature that crosses into protected actions is rejected.
2. **Engine stays pure Lua + testable outside WoW.** UI is the only WoW-coupled layer.
3. **99% test coverage is the floor, not the goal.** Coverage gate stays in CI. (608 tests as of v2.3.0.)
4. **Capability-first.** New advice belongs in `Data/OwnComps.lua` capabilities or `Data/Strategies.lua` comps. Hardcoding classes into the engine is a regression.
5. **No telemetry without opt-in.** Default off, easy to wipe. Local-only `/acc record` shipped; cloud telemetry deferred indefinitely.
6. **Backwards-compatible SavedVariables.** `Core.lua > DEFAULTS` is merged into existing `ArenaCoachTBCDB` on login; old user configs always load.

---

## Where the action is now

This v1 roadmap is mostly retrospective at this point. For the engine-depth work (M7-M12) and everything that landed after see **[ROADMAP-v2.md](ROADMAP-v2.md)**.
