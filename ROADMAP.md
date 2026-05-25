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
- [x] Per-callout cooldown (v2.5.0) — `UI:Apply` tracks last-shown-time per callout key, suppresses same callout for 3 s

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
- [x] Public wiki (v2.6.0) — `docs/strategies/` hosts per-comp strategy primers; starter RMP primer landed, structure documented so contributors can add more

---

## M6 — Mostly shipped · remaining deferred

Performance hardening landed across v2.0-v2.5 in pieces, not as a discrete M6 milestone. Where each item stands as of v2.5.0:

### Shipped
- [x] **Per-Evaluate budget**: `Tests/Performance_spec.lua` asserts `<5 ms` per call (target `<1 ms`) on a 5v5 state, `<3 ms mean / <10 ms p99` with lookahead enabled, and `<50 ms` on a 40-enemy AV-scale state. Tightened in v2.5.0 to also cover the full event-driven cycle (Evaluate → UI:Apply → WAB:Publish) `<15 ms mean`.
- [x] **Memory-leak fuzz**: 100 simulated arenas back-to-back assert a memory delta `<200 kb` post-GC (`Performance_spec.lua` line 133+).
- [x] **City-lag regression**: the v2.2.5 fix (`onNameplateChange` no longer fires Evaluate in `world_idle`) is covered by the new v2.5.0 cycle-budget test — a regression would blow the 15 ms cap immediately.

### Deferred — external dependencies / out of scope

The items below are deferred not because of priority but because they require resources outside this repo (alternate Lua runtimes, native-speaker contributors, design assets, hosting infra). Re-open when one becomes available.

- [x] **CI matrix: LuaJIT 2.1** (v2.6.0) — `.github/workflows/test.yml` gained a parallel `luajit-tests` job that runs the full suite under LuaJIT 2.1. Set `continue-on-error: true` so it informs rather than blocks; Lua 5.1 remains the contractual primary (TBC client). LuaJIT 2.0 not added — apt-get only ships one LuaJIT version per Ubuntu LTS, currently 2.1.
- [ ] **`debugprofilestop()` assertions**. The in-client profiler — only meaningful inside the WoW client, not headless tests. Substituted with `os.clock` in `Performance_spec.lua` (same intent, headless-compatible).
- [ ] **Headless evaluation server (HTTP shim)** + **embedded-engine companion**. Web visualiser that consumes the pure engine modules outside WoW. Substantial separate project (Express/Fastify + a Lua-WASM build of the engine); never started.
- [ ] **Interactive replay UI**. `tools/replay.lua` is single-pass and chat-output only; an interactive stepper would need its own front-end.

### Confirmed permanently out of scope

- [ ] **Opt-in cloud telemetry** (M5 Ship line). Violates operating principle #5 (no telemetry without opt-in, no PII). Local-only `/acc record` already covers offline analysis. Will not ship without a clear consent flow + EU-compliant data handling, which is out of scope.
- [ ] **Additional locales** (deDE, frFR, esES, ruRU, koKR, zhTW). Needs native-speaker review per locale — single-developer pseudo-translation would land worse than the current "english fallback via Core.L" path. Open an issue + PR with a `Locales/<locale>.lua` file matching the enUS shape and we'll land it.
- [ ] **Accessibility — dyslexia-friendly font**. The v2.5.0 high-contrast skin (`/acc highcontrast`) covers one accessibility axis; alternate fonts require licensing for OpenDyslexic / similar and a font-loading code path that would only run on retail-grade clients.
- [ ] **App icon + screenshots + demo gif** (M1 Ship line). CurseForge polish — requires the project owner to upload via the dashboard. `docs/curseforge-description.md` lists the suggested set.

### What's actually next

The v2.x line is feature-complete with v2.5.0. No new code milestones are scheduled. Future work, if any, would be:

- Bug fixes from user reports → patch releases (v2.5.x)
- New comp catalog entries → patch releases (`Data/Strategies.lua`)
- Major engine work (new lookahead depth, new modelling layer) → v3.0+ — would warrant a new ROADMAP-v3.md

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
