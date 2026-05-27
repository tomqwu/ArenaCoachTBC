# Changelog

All notable changes to **ArenaCoachTBC** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.8.6] - 2026-05-26

### Fixed
- **Real-fight damage pressure detection.** Classic combat logs can report melee/contact hits as `SWING_DAMAGE_LANDED` and shield/contact damage as `DAMAGE_SHIELD`; those now count as damage pressure for BG/world enemy stubs and healer-train detection.

### Docs
- Added a real-fight capture checklist covering `/acc trace`, `/acc record`, `/combatlog`, SavedVariables, and replay comparison.

## [2.8.5] - 2026-05-26

### Fixed
- **Rated-arena decision quality pass.** Corrected 2v2 pre-gate double-DPS/hybrid opener handling, strengthened low-HP 2v2 kill-window priority, added data-driven active kill targets for matchups such as WLP drain, restored target HP display from `healthPct`, formatted target-aware HUD callouts without raw `%s`, and gated `BURST_NOW` on the full `BurstDecision`.

### Tests
- Added rated-arena regression coverage for the known benchmark misses and raised the benchmark floor to 85%.

### Notes
- Merged on top of v2.8.4, preserving player assignments, stale HUD fade, arcade cues, subtle edge visuals, and distribution-copy updates.
- Tests 660/660 passing. Locale parity green at 145 keys per locale. Local luacov total coverage: 99.32%. Rated-arena benchmark agreement: 21/21.

## [2.8.4] - 2026-05-26

### Changed
- **CurseForge project description rewritten for approval clarity.** The dashboard copy now explicitly explains the features offered, what players experience in arena/BG/world PvP/duels, safety limits, privacy behavior, slash commands, localization, and current validation numbers.

### Notes
- Docs-only distribution polish. Package version bumped so GitHub release notes and downloadable addon metadata stay aligned.

## [2.8.3] - 2026-05-26

### Added
- **Stale HUD fade-out.** Fresh recommendations restore the HUD to full opacity, but if the fight state stops refreshing for several seconds the central text fades away and hides instead of leaving an out-of-sync call on screen.

### Fixed
- **Stale visual layers clear with the fade.** When the HUD fades out, optional edge cues and nameplate highlights are also cleared so target-specific advice cannot linger after the situation has moved on.

### Notes
- Tests 636 -> 639. Locale parity green at 144 keys per locale. Local luacov total coverage: 99.10%.

## [2.8.2] - 2026-05-26

### Changed
- **Removed the big flashing screen-edge feel.** The optional edge visual is no longer a 96px pulsing band around the screen. Even if an older SavedVariables file has `alerts.edgeGlow = true`, it now renders as a thin 18px, low-alpha, static edge cue.
- **HUD + docs now treat the arcade plate/nameplate as the primary visual warning.** `/acc glow on|off` remains for users who want a subtle peripheral cue, but the default and documented experience avoids big screen-border motion.

### Notes
- Added regression coverage that locks the edge cue to thin, low-alpha, and non-pulsing.
- Tests 635 -> 636. Locale parity green at 144 keys per locale. Local luacov total coverage: 99.10%.

## [2.8.1] - 2026-05-26

### Added
- **Arcade warning plate.** The HUD now renders a large passive warning cue above the tactical line, using high-impact arcade words such as `READY`, `ATTACK`, `SWITCH`, `DANGER`, `BURST`, and `PINCH` so urgent arena/BG/world PvP states are easier to parse at a glance without returning to fullscreen flashing.

### Fixed
- **Burst and outnumbered warnings are visually louder but still non-intrusive.** `BURST_NOW` and outnumbered disengage states now promote to the arcade cue line while continuing to avoid screen flashes, protected actions, or chat automation.

### Notes
- Tests 633 -> 635. Locale parity green at 144 keys per locale. Local luacov total coverage: 99.04%.

## [2.8.0] - 2026-05-26

### Added
- **DBM-style per-player assignments.** `StrategyEngine:Evaluate` now publishes `rec.playerActions`, one compact action per living friendly, with unit/name/class/action/target fields. The built-in HUD renders the assignment block under the main recommendation so a 3v3/5v5 team can see who should MS, purge, HoJ, peel, dispel, or reset.
- **WeakAura bridge support for assignments.** Added `GetPlayerActions()`, `GetPlayerAction()`, and `GetActionForUnit(unit)` so custom WeakAuras can render each player's assignment or only the local player's action.

### Fixed
- **Demo and locale text no longer mention DEFEND flashing.** The no-flash behavior remains intact from v2.7.5.

### Notes
- Tests 627 -> 633. Locale parity green at 135 keys per locale. Local luacov total coverage: 99.03%.

## [2.7.6] - 2026-05-26

### Fixed
- **CI parity follow-up for the real-arena test suite.** Preserved nil holes in the mocked `CombatLogGetCurrentEventInfo()` varargs so LuaJIT sees the same CLEU payload shape as Lua 5.1 and the WoW client.
- **Coverage-aware performance gate.** The raw `StrategyEngine:Evaluate` timing budget remains 5 ms, while the luacov-instrumented CI run now uses a 15 ms ceiling so coverage hooks do not masquerade as engine latency.
- **Slash-command coverage for live visual toggles.** Added regression coverage for `/acc highcontrast`, `/acc verbose`, `/acc on|off`, `/acc glow`, and `/acc nameplate`.

### Notes
- Tests 626 -> 627. Local luacov total coverage: 99.12%.

## [2.7.5] - 2026-05-26

### Fixed
- **Removed automatic full-screen flashing from live recommendations and `/acc test`.** `UI:Apply` no longer calls the red `_Flash()` overlay for URGENT/DEFEND, even if an older SavedVariables file still has `alerts.screenFlash = true`. The quieter cues remain: HUD colour, nameplate highlight, optional edge glow, and arena-gated sound.
- **Healer-train damage now re-evaluates through the real CLEU path once the peel threshold is reached.** Repeated damage on a healer in arena now publishes `DEFEND` immediately instead of waiting for the next spellcast/aura event.

### Added
- **Realistic arena lifecycle regressions.** Added event-driven tests that go through `PLAYER_ENTERING_WORLD`, `ARENA_OPPONENT_UPDATE`, `PLAYER_REGEN_DISABLED`, live `arenaN` unit stubs, CLEU healer damage, `UI:Apply`, and `WeakAuraBridge` publication. These cover the gates-closed `OPEN` state, active-combat `KILL`, healer-train `DEFEND`, and the no-flash behavior in a shape much closer to an actual arena run.

### Notes
- Tests 624 → 626 (+2 real-arena lifecycle regressions). Locale parity green at 112 keys per locale. Full syntax check green.

## [2.7.4] - 2026-05-26

### Fixed
- **Strategy logic pass for real PvP contexts.** `BurstDecision` is now the single source of truth for `BURST_NOW`: target immunity, configured MS, Windfury, melee uptime, kill probability, chain readiness, and incoming pressure all land in the auditable gate table. The old separate burst prerequisite path was removed so HUD callouts and bridge API cannot disagree. Chain readiness is advisory by default and can be made strict with `strategy.requireChainForBurst = true`.
- **DEFEND now works for support-capable teams and solo world PvP.** Low Paladin/Shaman support friendlies count as defensive anchors, healer CC checks use healer/support capability instead of Priest/Druid-only checks, and solo world PvP falls back to the lowest alive friendly so a dying non-healer player can still get `DEFEND`.
- **Non-arena enemy discovery is less noisy and less brittle.** BG/world nameplate scanning no longer stops at a missing `nameplate1`, and CLEU fallback stubs are only created when a hostile source damages the player or a known friendly.
- **Target and comp edge cases are safer.** Immune/unreachable-only targets now produce `RESET` instead of a bad KILL call, `primaryTargetHp` publishes correctly from `healthPct`, low-mana healer kill probability works without `roleGuess`, and `TRIPLE_DPS` no longer matches 2-player double-DPS states.
- **Profile contribution traces no longer duplicate `trinketsFear`.**

### Changed
- Updated the strategy/architecture docs to describe arena, BG, world PvP, burst gates, non-arena discovery, and the narrower dynamic `TRIPLE_DPS` fallback.

### Notes
- Tests 614 → 624 (+10 focused regressions). Locale parity green at 112 keys per locale. Full syntax check green.
- Coverage was not run locally because `luacov` is not installed in this WSL environment; the CI coverage gate remains unchanged.

## [2.7.3] - 2026-05-26

### Fixed
- **v2.7.1 outnumbered override was too aggressive — suppressed DEFEND in salvageable 2v3 / 1v2 emergencies.** Found by a Codex adversarial review run against `v2.6.0..HEAD`: in a 3v3 down to 2v3 with the healer at 20% HP and pressure detected, the engine returned `KILL` + the `CALL_OUTNUMBERED_DISENGAGE` callout instead of `DEFEND`. The 1.5x ratio caught every state where you'd lost one friendly, not just the unrecoverable 2v4 case the override was designed for. Defensive cooldowns CAN save a 2v3; suppressing DEFEND there is a regression.

  Fix has two parts:

  1. **Restructured `shouldDefend` so real-emergency signals check FIRST.** `low_healer` (any healer below the HP threshold), `healer_cc` (healer mid-CC), `enemy_lust` (Bloodlust active), and `multi_burst` now short-circuit before the outnumbered override runs. These signals indicate that defensives are *exactly* what saves the team, regardless of numbers.
  2. **Narrowed the outnumbered threshold** from `nEnemy >= nFriendly * 1.5` to `nEnemy >= 4 AND (nEnemy - nFriendly) >= 2`. Catches the original 2v4 / 2v5 / 1v3+ cases; no longer fires on 2v3 / 1v2 where defensives still work. `isOutnumbered` (the callout helper) follows the same threshold so the override + callout stay in sync.

### Notes
- Tests 612 → 614 (+2 Codex-suggested regressions: arena 2v3 with low healer must still DEFEND; 2v4 with low healer alive at 15% must still DEFEND via `low_healer` taking precedence over `outnumbered`). Locale parity green.
- The original v2.7.1 user case (arena 2v4 with `healerUnderPressure` but no specific defensive signal) still works correctly: `low_healer` doesn't fire (nobody's low), `enemy_lust` doesn't fire, so we fall through to the outnumbered branch which suppresses DEFEND and adds the `CALL_OUTNUMBERED_DISENGAGE` callout.

## [2.7.2] - 2026-05-26

Two stacked lifecycle bugs both rooted in stale state.

### Fixed
- **Engine recommended KILL before arena gates opened.** User report: *"it suggest to kill even before the game."* Root cause: `onArenaOpponentUpdate` set `combatPhase = "ACTIVE"` the moment any opposing player became visible to the client — which fires while you're still in the prep room before gates open. The legitimate `PRE → ACTIVE` transition is `PLAYER_REGEN_DISABLED` (combat starts); that already handles it. Removed the spurious assignment so the pre-gates window correctly stays in OPEN mode.
- **Stale phantom enemies from the previous match leaked into the next.** User report: *"always 15% showing, sometime a player name doesn't even exist."* The 15% was the engine's baseline kill-probability fallback when no fresh data exists; the phantom name was a dead enemy from a prior arena that `state.enemies` never cleared. Now `onPlayerEnteringWorld` explicitly resets `state.enemies`, `state.enemyClassList`, `state.lastPrimaryGUID`, and `state.combatPhase = "PRE"` on every zone transition. CLEU + UnitAura subscriptions rebuild the state within one evaluation tick once combat starts, so the reload-mid-fight case recovers cleanly.

### Notes
- Tests 611 → 612 (+2 regressions: ARENA_OPPONENT_UPDATE must NOT flip combatPhase to ACTIVE; PEW must reset per-match state including phantom enemy entries). Locale parity green.
- Engine, bridge API, storage shape unchanged. Pure lifecycle correctness fix.

## [2.7.1] - 2026-05-26

### Fixed
- **Engine recommended DEFEND in a 2v4 arena.** User report: *"we got 2v4 situation, you ask me to defend."* Root cause: `shouldDefend()` returned `true` via the "healer being trained" branch whenever multiple damage events landed on the healer in a 5-second window — which fires by definition in a 2v4 because 4 enemies attacking 2 players means multi-source damage. But defensive cooldowns can't save a 2v4: you spend them in one global and everyone dies. The actionable advice in that state is "disengage or counter-burst the lowest-HP enemy", not "burn Pain Sup".

  Added an outnumbered override at the top of `shouldDefend(state)`: when `alive enemies ≥ alive friendlies × 1.5` in arena context, suppress DEFEND and let `decideMode` fall through to KILL. A new `CALL_OUTNUMBERED_DISENGAGE` callout is added at the top of the callout list (so it gets the prominent icon + text slot in the HUD), localised in both locales: *"Outnumbered — disengage or burst lowest-HP"* / *"敌众我寡 - 脱离或集火残血"*. Wired to the Aspect of the Cheetah icon (spell 5118) so the visual cue reads as "run away".

### Notes
- **Arena-only.** The override does NOT apply in BG / world context. In BG the engine's "alive enemies" comes from nameplate scans and includes everyone in range, not just active combatants — a 3v10 nameplate count isn't a real outnumbered state. Arena's `arenaN` unit IDs are exactly the opposing team, so the ratio is meaningful there.
- 609 → 611 tests (+2 regression: arena 2v4 suppresses DEFEND + adds the callout; BG 3v10 still allows DEFEND).
- Locale parity green: 112 keys per locale (was 111; added `CALL_OUTNUMBERED_DISENGAGE`).
- Engine, bridge API, storage shape all unchanged. UI HUD adds the icon automatically via the v2.7.0 callout-icon map.

## [2.7.0] - 2026-05-25

**Visual hierarchy pass driven by user feedback.** *"Whole-screen glow doesn't help, you should add which role does what in the HUD, can you add some ICONs?"* Two changes:

### Changed
- **Edge glow flipped from default-on to default-off.** The full-screen pulsing band was more distraction than information per real-use feedback. Still available via `/acc glow on` if you want it back. Nameplate highlight stays default-on — that one's anchored to the actual kill / swap target so it carries role information, not just mode colour.
- **Callouts now show their spell icon inline.** Pre-v2.7 every callout rendered as `▸ HoJ kill target` — text only, leaving you to translate "HoJ" → "the paladin's Hammer of Justice" → "which icon is that on my bars" in your head mid-fight. Now: `|TInterface/Icons/Spell_Holy_HammerOfJustice|t  HoJ kill target` — the spell's actual in-game icon renders inline as a 18px texture, so you see the action visually. Mapping covers all current callouts (HoJ, Tremor, Grounding Totem, Purge, Dispel Magic, Pain Suppression, BoP, Cyclone, Psychic Scream, Mana Burn, Ice Block warning, Counterspell, BG flag carrier, Divine Shield, Bloodlust for BURST NOW, …). When `GetSpellTexture` returns nil (very first call on an unknown spell ID), the row degrades gracefully to the previous `▸ <text>` bullet.

### Notes
- This makes verbose mode (`/acc verbose on`) much more useful too — each callout in the list now reads as a stacked action menu with icons + text, not a pipe-separated text blob.
- Existing `db.alerts.edgeGlow` setting respected: users who explicitly turned it ON (or never edited it pre-v2.7) keep their current state. Only fresh installs see edge glow off.
- 609 tests still passing. Locale parity 111/111. Bridge API unchanged.

## [2.6.0] - 2026-05-25

**True closure of the v1 roadmap, plus user-feedback polish.** Picks up the last 3 deferred-but-doable items (per-callout cooldown already shipped in v2.5.0, public wiki, LuaJIT CI matrix) plus two new user reports from v2.5.0 testing (demo too fast to read, HUD still feels cluttered).

### Added
- **LuaJIT 2.1 CI matrix** (M6). `.github/workflows/test.yml` gained a parallel `luajit-tests` job that runs the full suite under LuaJIT 2.1. Lua 5.1 stays the contractual primary (TBC client uses 5.1 exclusively). The LuaJIT job is `continue-on-error: true` so it reports without blocking PRs — its purpose is regression-catching, not gating. LuaJIT 2.0 not added; apt-get on Ubuntu LTS only ships 2.1.
- **Per-comp strategy primer wiki** (M5). New `docs/strategies/` directory with `README.md` (structure + framework) and `rmp.md` (the starter primer — full game plan, kill conditions, per-archetype variations, callout list, common mistakes). Other primers (WMS / TSG / Jungle / RLS / DRAIN / BG cleave) are stubs ready for contributor PRs.
- **Demo slowdown.** `/acc test` beats now space at 3 s instead of 2 s (1.5x multiplier; total demo 14 s → 21 s) so each beat is readable before the next replaces it. New `/acc test slow` keyword bumps to 2.5x (35 s total) for screen-share / streaming demos. End-of-demo restore delay also scales.

### Changed
- **HUD visual hierarchy polish.**
  - `f.statsText` font bumped from `GameFontHighlight` (~12pt) to 18pt OUTLINE — readable at a glance, not just under careful inspection.
  - Stats segments now colour-coded inline: **HP white** (neutral reference value), **kill prob green / amber / red** (≥60 / 30-59 / <30), **★ BURST READY in gold with a leading sigil** so the burst signal pops as the most attention-grabbing element on the line.
  - Wider segment separator (`  ·  ` instead of `   `) and a leading sigil so segments breathe.
  - Vertical spacing between mode label / stats / sub-text widened from -2px / -4px to -8px / -8px so the sections read as distinct rows.
  - `f.subText:SetSpacing(3)` so multi-line text (verbose mode chain steps) doesn't crowd together.

### Roadmap
- Marked these items DONE on `ROADMAP.md`:
  - Per-callout cooldown (was already shipped in v2.5.0, just unchecked)
  - Public wiki (`docs/strategies/` covers this — README + starter primer; contributors add more)
  - CI matrix LuaJIT 2.1 (added; 2.0 not available via apt)
- The remaining unchecked items are the genuinely external-only ones: additional locales (need native speakers), cloud telemetry (principle conflict), dyslexia font (licensing), app icon/screenshots (design assets), web visualiser (separate project). These won't ship without external resources.

### Notes
- Tests 609 still passing. Locale parity 111/111. Bridge API + engine surface unchanged.
- The v1 ROADMAP is now genuinely closed. The v2.x line is feature-complete pending external-resource items.

## [2.5.0] - 2026-05-25

**Polish release — closes out the v2.x line.** Picks up the last three actionable items from the v1 roadmap that hadn't shipped yet: per-callout cooldown (M4), high-contrast accessibility skin (M4), and a tightened performance budget assertion (M6). ROADMAP.md updated to mark the remaining items as either shipped, deferred with explicit reasons (external dependencies — alternate Lua runtimes, native-speaker contributors, design assets, hosting infra), or permanently out of scope (cloud telemetry conflicts with operating principle #5).

### Added
- **Per-callout cooldown** (M4). `UI:Apply` now tracks last-shown-time per callout key and suppresses the same callout for 3 seconds. Stops the "same text every 0.5 s" pattern that could surface if engine state oscillates around a threshold (enemy HP bouncing across the 50% gate, for example). Applies in both Quiet HUD and verbose modes.
- **High-contrast HUD skin** (M4 accessibility). New `/acc highcontrast on|off` (alias `/acc hc`) flips between the default visually-coherent palette and a fully-saturated primary palette (pure red KILL, pure yellow OPEN, pure orange SWAP, saturated cyan-blue DEFEND, white RESET). Persists in `db.frame.highContrast`. Useful on small screens, under glare, or for users with reduced colour sensitivity. The mode label colour swap is immediately repainted via a synthetic Evaluate when the toggle is flipped.
- **Full-cycle perf budget assertion** (M6). `Tests/Performance_spec.lua` gains a new test that exercises the full hot path — `SE:Evaluate` → `UI:Apply` → `WeakAuraBridge:Publish` — and asserts `<15 ms` mean over 100 iterations. The v2.2.5 city-lag bug came from `onNameplateChange` running this exact path on every nameplate event in `world_idle`; this budget cap means any future regression of that pattern will fail CI immediately.

### Changed
- **ROADMAP.md** — M6 section restructured to distinguish (a) what shipped (per-Evaluate budget, lookahead+patterns budget, AV-scale 40-enemy budget, 100-arena memory fuzz, full-cycle budget), (b) what's deferred due to external dependencies (LuaJIT CI matrix, web visualiser, interactive replay UI), and (c) what's permanently out of scope (cloud telemetry, single-developer pseudo-locales, alternate fonts). The v1 ROADMAP is now a retrospective in steady state.

### Notes
- 608 → 609 tests (one new full-cycle perf assertion). Locale parity green (still 111 keys per locale; no new locale work).
- Bridge API, engine, and storage shape all unchanged. No SavedVariables migration needed; `db.frame.highContrast` and `db.frame.verbose` (v2.4.0) auto-merge on next login.
- This release closes out the v1 ROADMAP and (along with v2.0.0 closing ROADMAP-v2) leaves the project in a feature-complete steady state. Future work, if any, falls into patch releases (bug fixes, new comp catalog entries) or a v3.0+ engine evolution.

## [2.4.0] - 2026-05-25

**Quiet HUD.** Information density on the recommendation frame had grown to 5-6 lines of text per evaluation — too dense to parse mid-fight. User screenshots showed the wall-of-text problem in zhCN clients (where some keys still rendered as raw identifiers). v2.4 cuts the default HUD to two lines + the mode badge + the target stats row, moves the rest behind a `/acc verbose` toggle, and patches the last untranslated callout.

### Fixed
- **`BURST_NOW` callout rendered as the raw key in non-English clients** ("BURST_NOW | 无敌锤上焦点" in the user's zh screenshot). Added the key to both `Locales/enUS.lua` ("BURST NOW") and `Locales/zhCN.lua` ("立即爆发"). Both locales now at 111 keys, parity green.

### Changed
- **HUD subText cut to one callout line in default mode.** Pre-v2.4 every evaluation rendered: `[reasonKey] | [callout1 | callout2 | callout3] | [comp badge] | [chain title (62%)] | [step 1] | [step 2] | [step 3]` — six to seven lines mid-fight. v2.4 default shows just `▸ [top callout]` (plus the localised reasonKey for DEFEND/RESET). The big mode label + target name + target stats row (HP%/kill prob/BURST READY) + edge glow + nameplate borders already convey everything actionable.
- **Demo chat spam silenced.** `/acc test` (and `/acc test bg`, `/acc test world`) previously printed the beat-by-beat note to chat — 7 lines for the arena demo. Now only the start + end banners fire by default. The per-beat notes still print when verbose mode is on.

### Added
- **`/acc verbose [on|off]`** — new slash command that toggles `db.frame.verbose`. When **on**, the HUD reverts to the v2.3.1 information density (full callout list, comp badge, chain title + step lines) and the demo chat spam returns. When **off** (default), you get the Quiet HUD. Persists across `/reload`. Aliases: none (it's an additive toggle, not a master switch).
- New `db.frame.verbose` SavedVariable key (defaults to `false`). Existing installs auto-merge it on next login via the standard `DEFAULTS` merger; no migration needed.

### Notes
- This is a UI-render-only change. The engine still emits the full callout list, comp identification, and chain data on every evaluation — `/acc trace dump`, the bridge API (`_G.ArenaCoachTBC.GetCallouts()`, `GetChain()`, `GetEnemyCompLabel()`), and WeakAura consumers see everything unchanged.
- Tests: 608 still passing. Updated three demo specs in `Tests/Core_spec.lua` to set `db.frame.verbose = true` before running so the per-beat chat assertions still hold.

## [2.3.1] - 2026-05-25

### Fixed
- **Recommendation frame leaked internal score-contributor identifiers as text** ("PRIEST [role_healer(25), trinket_down(20), health_below_50(30)] | RMP_DISC_3V3 spec-confirmed (1.00)"). User report: *"there are random words like lkjasfsa_lajfda, seems like not properly translated or mapped to proper spells."* Root cause: `UI:Apply` was rendering `recommendation.reason` verbatim for KILL/SWAP/OPEN modes — but that field is dev-only, meant for `/acc trace dump`, never user-facing. The mode label + target name + target stats row (HP / kill prob / BURST READY) + callouts list + comp badge + chain block already carry everything the user needs. Now `UI:Apply` renders `reason` *only* via the localised `reasonKey` path (DEFEND / RESET) and drops the raw debug text otherwise.
- **Chain step lines were redundantly tagged with their category** ("Step 1. Sap (INCAPACITATE)", "Step 2. Polymorph (INCAPACITATE)", "Step 3. Kidney Shot (STUN)"). The category is already implicit in the chain title; the parenthetical was visual noise. Dropped — now just "Step 1. Sap", "Step 2. Polymorph", "Step 3. Kidney Shot".

### Notes
- The `recommendation.reason` field is unchanged — `/acc trace dump`, the bug report, and any WeakAura consumer that reads `_G.ArenaCoachTBC.GetReason()` still get the full debug breakdown. This is a UI-render-only change.
- Tests still at 608 passing, locale parity at 110/110.

## [2.3.0] - 2026-05-25

**Quality release.** One real bug fix on top of v2.2.6, plus a sweep of dead code and stale docs that had piled up across the v2.1-v2.2 patch cycle.

### Fixed
- **`/acc test` (and any non-arena trigger of `UI:Apply`) only painted the text frame — no screen edge glow, no nameplate highlight.** User report: *"I do not see any HUD in the latest release, only text."* Root cause: `UI:Apply`'s v2.2.0 visual-layer block gated on `inPvP = (arena|bg|world)` and ignored the `_forceShow` flag the demo sets to bypass the v2.2.5 auto-hide. Result: the early hide gate let the rec through, but the later edge-glow + nameplate gate still required real PvP context and so nothing painted on the periphery. Fixed with a 3-line change: `local showVisualLayers = inPvP or forceShow`. Regression-tested in `Tests/UI_spec.lua` (test #607 / #608).

### Removed
- **`UI.lua` dead code** (38 lines): `makeIcon(parent, size)` (lines 27-59) and `spellIcon(spellID)` (lines 62-67) — orphaned since v2.2.1 removed the icon rows that called them. Module header line about "two icon rows" updated to reflect the v2.2.0 visual-layer architecture.

### Changed
- **Docs refresh** — first comprehensive sweep since v2.0 shipped 9 patches ago:
  - `docs/weakaura-pack.md`: removed the Path 1 paste-string section that directed users to a tool we deleted in v2.2.6. Added a deprecation note explaining the parser-library limitation. Path 2 (trigger-code snippets for hand-built WAs) unchanged.
  - `docs/architecture.md`: title bump v2.0 → v2.2; new sections for `ScreenEdgeGlow.lua`, `Nameplate.lua`, the v2.2.5 auto-hide gate + `/acc off` master switch; `Sounds.lua` description corrected (numeric SoundKit IDs, not the broken `.ogg` paths from before v2.1.6).
  - `docs/manual-smoke.md`: slash-command checklist extended with `/acc off`, `/acc on`, `/acc glow`, `/acc nameplate`; new HUD smoke step that asserts the full visual stack paints during `/acc test`; new city-lag smoke step; added Plater / KuiNameplates / TidyPlates to the addon-conflict matrix.
  - `ArenaCoachTBC/README.md`: stale `Interface: 20504` reference bumped to `20505`; slash-command table expanded with the v2.2 commands.
- **Roadmap refresh** — first sweep since v2.0:
  - `ROADMAP.md` (v1): marked the items shipped through v2.2.6 as done with their actual shipping vehicle. Crossed-out the "Prepackaged WeakAura export string" item with a link to the v2.2.6 abandonment note. Moved M6 hardening items (`debugprofilestop` assertions, memory fuzz, multi-Lua CI matrix, headless replay tool, evaluation server) into a "Deferred — future hardening" section. Marked the M5 cloud-telemetry item as deferred indefinitely.
  - `ROADMAP-v2.md`: added a "What shipped after M12" section that one-line-summarises every v2.1, v2.2, v2.3 release with a CHANGELOG anchor, so future readers understand why v2.0's "complete" still got 9 patches stacked on top.

### Notes
- Test count 606 → 608 (+2 regression tests for the HUD-demo bug; the v2.1.3 tests that briefly broke during development now pass cleanly).
- Locale parity green: still 110 keys per locale (enUS, zhCN). No new locale work in this release.
- No behaviour changes outside the bug fix. No new slash commands, no new SavedVariables keys, no schema migrations.

## [2.2.6] - 2026-05-25

### Removed
- **WeakAura paste-string export pipeline.** v2.0–v2.2.5 shipped pre-built `!WA:2!` import strings in `docs/weakaura-imports.md` + `README.md`, generated by `tools/export_weakauras.mjs` via the `node-weakauras-parser` npm package. After 6 patches chasing import failures (parser format, internalVersion, version=3, semver, config/information shape) the root cause turned out to be the parser itself: even re-encoding a known-working Wago WA byte-for-byte produces a string that decodes correctly but fails WA's import-validator byte check (no Import button shown). Removed the whole pipeline:
  - `tools/export_weakauras.mjs` (the broken generator)
  - `tools/package.json`, `tools/package-lock.json`, `tools/node_modules/` (npm deps)
  - `docs/weakaura-imports.md` (auto-generated output)
  - `docs/wa-hello-test.md` + `tools/test_hello_wa.mjs` (diagnostics from the chase)
  - The "Paste-ready import strings" section in `README.md` (replaced with a note explaining the limitation + pointing at `docs/weakaura-pack.md` for trigger source code users can hand-build a WA from)
- The `_G.ArenaCoachTBC` bridge API and `WeakAuras.ScanEvents("ACC_RECOMMENDATION", rec)` event remain unchanged — power users who want custom auras still have everything they need.

### Why
The addon's built-in HUD (v2.1.6 + v2.2.0) already renders the mode badge, target stats, screen edge glow, nameplate highlight, and audio cues. WA paste-strings were redundant convenience for users who wanted the same display in their own UI framework — not worth shipping a broken pipeline to chase.

## [2.2.5] - 2026-05-25

### Fixed
- **Major frame-rate drop in cities on PvP-flagged characters.** User report: addon caused lag in main city. Root cause: `onNameplateChange` re-ran `Evaluate()` whenever the player was PvP-flagged (`world_idle` context) and any nameplate appeared / disappeared — which in Stormwind is hundreds of events per second. Engine had nothing to recommend (no hostile contact), so the work was pure waste. Gate now only triggers Evaluate when `pvpContext == "bg"` or `"world"` (an actual fight). `world_idle` (flagged + no enemies) no longer drives evaluation.
- **Frame stayed visible with stale rec outside PvP.** Previously after `/acc test` or after leaving an arena, the recommendation frame would linger center-screen showing the last computed rec. Now `UI:Apply` checks `Core.state.pvpContext` and hides the frame + edge glow + nameplate paint when the context is explicitly `"none"` (no PvP relevance) or `"world_idle"`. The `/acc test` demo bypasses this via a per-beat `_forceShow` flag so the walk-through still renders end-to-end.

### Added
- **`/acc off` / `/acc on` master switch** (aliases: `/acc disable` / `/acc enable`). Sets `db.enabled` and immediately hides every visual layer. Persists across `/reload` and login sessions. Same `enabled` flag the engine already short-circuits on, so no Evaluate work happens while off.

## [2.2.4] - 2026-05-25

### Fixed
- **WeakAura imports still failed in v2.2.3 — the real root cause.** Field-by-field deep-diff against a known-working Wago WA revealed that `d.config` and `d.information` were declared as empty objects (`{}`) in the exporter but the working Wago WA had them as empty arrays (`[]`). The parser encodes the two shapes differently — `{}` becomes a Lua hashmap, `[]` becomes a Lua sequence — and modern WA's import validator rejects the hashmap shape so hard that the import preview dialog never even surfaces (user report: "no Import button appears after pasting"). Changed both to `[]` in `tools/export_weakauras.mjs`. Verified post-regeneration: the only remaining schema differences against the Wago reference are field ordering (which doesn't matter for Lua tables) plus the expected per-aura fields (`uid`, `url`, `semver`, `wagoID`).

## [2.2.3] - 2026-05-25

### Fixed
- **WeakAura import dialog never showed the Import button.** Decoded a known-working Wago WA (`v1TwWSgUh` — a user-uploaded copy of our Mode badge) side-by-side with our generated string. Three schema gaps emerged:
  - `d.version` was `1` — modern WA expects `3`. Version 1 is so old that newer WA builds silently drop the import without surfacing the dialog (no Import button shown).
  - `d.semver` was undefined — required for version-3 imports as a user-visible release tag.
  - `d.internalVersion` (fixed in v2.2.2) was already set to 90, so that part was correct.

  Set `version: 3` and `semver: '2.2.3'` in the exporter `COMMON` block. All 5 templates regenerated in `docs/weakaura-imports.md` and the inline copies in `README.md`. Now matches the schema of the proven-working Wago WA byte-for-byte (modulo the per-aura `uid`).

## [2.2.2] - 2026-05-25

### Fixed
- **WeakAura imports showed "this aura was created with a very old version" warning.** Our generated `d` object had `internalVersion` undefined, which WA-Classic reads as "ancient" and triggers schema-migration warnings (or outright rejects on stricter builds). Set `internalVersion: 90` in the exporter `COMMON` block — matches current upstream WeakAuras (latest `WeakAuras/WeakAuras.lua` on `main` defines `local internalVersion = 90`). All 5 templates regenerated in `docs/weakaura-imports.md` + the inline copies in `README.md`. Imports cleanly without the version warning.
- Also corrected the WA `url` field from the old `wow_tbc_arena_pvp_strategy` repo slug to the renamed `ArenaCoachTBC` slug, so the "Source" link on the WA matches the current GitHub URL.

## [2.2.1] - 2026-05-25

### Fixed
- **WeakAura import strings rejected by WA-Classic.** v2.1.6 switched the exporter to FormatVersion 1 (`!`-prefixed Deflate) on a wrong hunch — actual round-trip verification through Wago showed WA-Classic accepts the FormatVersion 2 (`!WA:2!` binary-serialized) format that the exporter had always used. Reverted `tools/export_weakauras.mjs` to FormatVersion 2 and regenerated all 5 templates in `docs/weakaura-imports.md` + the inline copies in `README.md`. The strings now import cleanly.
- **Dead icon rows at the bottom of the recommendation frame.** Since v1 the frame rendered 14 friendly + 9 enemy cooldown reminder icons across two rows at the bottom, but `UI:UpdateIcons` was only ever called from tests — no production code fed it a "ready set", so every icon sat at its initial 0.4 alpha forever and communicated nothing. Stripped the icon rows, the populate function, the unused `UpdateIcons` method, and the `frame.compactMode` toggle that gated their visibility. Frame height drops from 170px to 110px so the HUD is more compact. `UI_FRIENDLY_CDS` / `UI_ENEMY_CDS` locale keys removed from both locales (110 keys each, parity green).

### Removed
- `UI.friendlyIcons`, `UI.enemyIcons`, `UI:_PopulateIconRows`, `UI:UpdateIcons` — dead UI code.
- `db.frame.compactMode` SavedVariable — there's nothing to toggle now that the icon rows are gone. Existing installs that have this set in SavedVariables will see it simply ignored on next login (no migration needed).
- 7 tests that exercised the removed surface (Apply compactMode show/hide, UpdateIcons happy/nil paths, icon button spellID, icon tooltip OnEnter/OnLeave, _PopulateIconRows fallback). Test count 613 → 606.

## [2.2.0] - 2026-05-25

**Eyes Up.** Two new peripheral-vision layers on top of the v2.1.6 HUD, so the engine's call reaches you even when your eyes are on the action — not on the frame.

### Added
- **Mode-coloured screen edge glow.** A pulsing band hugs the four screen edges, coloured to match the active recommendation (red KILL, orange SWAP, blue DEFEND, yellow OPEN). Pulse period 1.6s, alpha breathes between 0.18 and 0.42 so it stays visible but never dominates the viewport. RESET intentionally has no colour — between fights the glow goes dark instead of strobing for nothing. New `ArenaCoachTBC/ScreenEdgeGlow.lua` module. Toggle: `/acc glow on|off` (default on). Gated by PvP context — only renders in arena / BG / world PvP, never in idle world.
- **Nameplate highlight for kill / swap targets.** The engine's primary target gets a red border on its nameplate; the swap candidate (when in SWAP mode) gets an orange border. Adds a child overlay frame to each affected nameplate so we coexist cleanly with Plater / KuiNameplates / TidyPlates (we never modify the native health bar / cast bar / name text). New `ArenaCoachTBC/Nameplate.lua` module. Toggle: `/acc nameplate on|off` (default on). Hook driven by the existing `NAME_PLATE_UNIT_ADDED` / `REMOVED` subscriptions; per-Apply ClearAll + reapply keeps state coherent through plate cycling.
- **Two new slash commands**: `/acc glow [on|off]` and `/acc nameplate [on|off]`, with bare-toggle behaviour when no argument is passed.
- **`db.alerts.edgeGlow`** and **`db.alerts.nameplate`** SavedVariable keys, both default `true`. Existing installs auto-merge on next login via the standard `DEFAULTS` merger.
- **12 new tests** (`ScreenEdgeGlow_spec.lua`: 6 cases for colour table + SetMode/Hide round-trip; `Nameplate_spec.lua`: 6 cases for Apply / Highlight / ClearAll idempotence + overlay lifecycle). Test count 601 → 613.

### Notes
- Both new visual layers are arena/BG/world-gated — in idle world (no hostile context) the glow + nameplate paint are skipped to avoid being a constant visual distraction.
- The base frame's `bigText` (v2.1.6) + audio cues (v2.1.6) + edge glow (v2.2.0) + nameplate (v2.2.0) together form the "Eyes Up" feature pack. Each layer is independently toggleable so users can pick the subset that doesn't conflict with their existing UI.

## [2.1.6] - 2026-05-25

### Fixed
- **Audio cues were silently broken since v1.0.** `Sounds.lua` referenced `Sound/Voice/*.ogg` paths that were never bundled in the addon zip, so every `PlaySoundFile` invocation failed and "audio callouts" did nothing in any release. v2.1.6 rewires `Sounds:Play` and the new `Sounds:PlayMode` to numeric TBC Classic SoundKit IDs (RaidWarning chime, RaidBossEmote alert, PvPVictory chord, queue ding, quest pop) that ship with the WoW client itself. No new assets needed; cues fire reliably on every install. The `db.alerts.sound` toggle works as advertised.
- **Mode-transition audio.** Pre-v2.1.6 the only audio cue was the per-callout sound, which fired on `CALL_HOJ_KILL` / `CALL_TREMOR_FEAR` / `BURST_NOW` events. v2.1.6 adds `Sounds:PlayMode(mode)` driven from `UI:Apply` that plays a distinct ding when the recommended mode flips (KILL / SWAP / DEFEND / OPEN), so even with your eyes off the frame you hear the engine's call. Same `alerts.sound` gate; arena-only for the same noise-floor reason.

### Added
- **Bigger, more readable mode label.** `f.bigText` upgraded from `GameFontNormalHuge` (~22pt) to a custom 32pt outlined font. The mode + target line is now legible from across a battleground screen, not buried in the corner.
- **Target stats row.** A new `f.statsText` line below the mode label renders `HP <n>%   kill <n>%   BURST READY` when the rec carries a primary target. Hidden on DEFEND / RESET (no target). Engine now emits `primaryTargetHp` (0..1) and `killProb` (0..1) on the recommendation table so the HUD has the data it needs without reaching into state.
- 3 new locale keys (109 → 112 per locale, parity green): `UI_HP_LABEL`, `UI_KILL_PROB_LABEL`, `UI_BURST_READY`.

### Notes
- This is the first half of v2.2 "Eyes Up" (visual + audio overhaul). The remaining items — mode-coloured screen edge glow, nameplate highlight for the kill / swap targets — will land as v2.2.0 once the HUD changes have been validated in real combat.

## [2.1.5] - 2026-05-25

### Added
- **CurseForge auto-upload wired up.** Added `## X-Curse-Project-ID: 1552792` to the TOC. The release workflow's BigWigs packager step (already fixed in v2.1.4) now has both the API token (`CF_API_KEY` GitHub secret) and the project ID needed to publish each tagged release straight to the CurseForge ArenaCoachTBC project page. Tagged releases (`vX.Y.Z`) auto-push the addon zip to CurseForge; dev prereleases (`vX.Y.Z-dev.N` from `main` pushes) still only publish to GitHub.

### Notes
- Wago upload still pending — `WAGO_API_TOKEN` secret is set but no `## X-Wago-ID:` in the TOC yet. Add the Wago slug to the TOC + cut another patch to enable Wago uploads.

## [2.1.4] - 2026-05-25

### Added
- **TBC Anniversary client support.** `## Interface:` bumped from `20504` (BCC 2.5.4) to `20505` (Anniversary 2.5.5). Same `Interface-BCC` line keeps Burning Crusade Classic clients working — addon now loads cleanly on both the closed BCC era and the live Anniversary realms without an "out of date" warning. Title / Notes updated to advertise "Anniversary / Classic PvP — arena, BG, world" instead of the older "TBC Classic arena" framing.

### Fixed
- **Release workflow's BigWigs packager step no longer fails with `Could not find an addon TOC file`.** Cause: the addon TOC lives at `ArenaCoachTBC/ArenaCoachTBC.toc` but the packager defaults to looking for the TOC at the repo root. Passing `args: -t ArenaCoachTBC` to the action's `release.sh` sets the project topdir to the addon subdir, so the packager finds the TOC, reads the in-addon `.pkgmeta` (`ArenaCoachTBC/.pkgmeta`, new), and produces a clean zip. This unblocks CurseForge + Wago uploads once project IDs are wired up.
- New `ArenaCoachTBC/.pkgmeta` declares `package-as: ArenaCoachTBC`, `enable-nolib-creation: no`, and ignores `Tests/` + `.luacheckrc`. The root `.pkgmeta` is now dead code (left in place to avoid breaking external tooling; will be removed in a later cut).

### Notes
- The CurseForge + Wago API tokens are configured as GitHub secrets (`CF_API_KEY`, `WAGO_API_TOKEN`), but **project IDs are still required** in the TOC (`## X-Curse-Project-ID:` / `## X-Wago-ID:`) before uploads can succeed. Create the CurseForge + Wago projects for ArenaCoachTBC and add the IDs to `ArenaCoachTBC.toc` to complete the publishing chain. Without IDs the packager will skip the upload step (the GitHub Release will still publish).

## [2.1.3] - 2026-05-25

### Fixed
- **DEFEND / RESET modes no longer show a target name.** Reported via a WSG screenshot: the frame displayed *"DEFEND: lhealyoupeel"* (in Chinese: *"守: lhealyoupeel"*). Reading that as "defend against lhealyoupeel" is the opposite of the intent — DEFEND is about *your* team's defensive cooldowns, not a target to attack. `UI:Apply` now restricts the `"<mode>: <name>"` form to OPEN / KILL / SWAP only; DEFEND and RESET render mode alone.
- **DEFEND reason text now follows the WoW client locale.** Same screenshot showed *"defensive: trained"* in English next to Chinese callouts. Engine now emits `rec.reasonKey` (e.g. `REASON_DEFEND_TRAINED`) for the six known DEFEND reasons + the RESET case; UI prefers `reasonKey` through `L()` over the raw debug `reason` string. Chinese client now sees *"防御 - 治疗被集火"*. KILL / SWAP / OPEN reasons stay as the raw English contributor-list text (they carry variable per-evaluation data, not a stable key).
- 7 new locale keys (109 per locale, parity green): `REASON_DEFEND_TRAINED`, `REASON_DEFEND_LOW_HEALER`, `REASON_DEFEND_ENEMY_LUST`, `REASON_DEFEND_MULTI_BURST`, `REASON_DEFEND_HEALER_CC`, `REASON_DEFEND_TRIPLE_DPS`, `REASON_RESET`.
- 8 new tests (3 in `UI_spec` for the target-suppression cases + reasonKey rendering, 4 in `StrategyEngine_extra_spec` for the `reasonKey` field on DEFEND / RESET / KILL).
- Mock harness `mockMethods:SetText/GetText` added so UI specs can assert on rendered text.

## [2.1.2] - 2026-05-25

### Fixed
- **Frame stayed at "Awaiting opener..." in WSG / BGs / world PvP when no combat was happening.** Reported: "doesn't work in WSG". Root cause: `Core:Evaluate` runs the non-arena enemy refresh (`RefreshEnemiesNonArena`), but `Evaluate` itself only fired on arena events / CLEU / aura events. While running across a BG map with no combat, no event ticked, so the engine never re-scanned nameplates and never saw enemies become visible. v2.1.2 subscribes to `NAME_PLATE_UNIT_ADDED` / `NAME_PLATE_UNIT_REMOVED` and re-evaluates whenever the player's nameplate set changes — only when `pvpContext == "bg" / "world" / "world_idle"` (arena keeps the original event-driven flow). Headless tests cover BG context evaluation, non-PvP context ignoring nameplate events, and the world-context re-evaluation path.

**You do not need a WeakAura to make ArenaCoachTBC work in BG.** The addon's own frame should populate naturally as you run past enemies. The WA bridge (including `_G.ArenaCoachTBC.GetPvPContext()` from v2.1.1) is still there if you want a custom HUD on top, but the default frame is the supported path.

## [2.1.1] - 2026-05-25

Polish + visibility on top of v2.1. Same engine; surface and docs upgraded.

### Added
- **`/acc test bg`** — 5-beat BG walk-through (engaged → flag carrier picks up → flag carrier low HP → CALL_BG_DEFEND on train → reset). Walks the BG scoring branches the same way `/acc test` walks arena.
- **`/acc test world`** — 4-beat world PvP walk-through (engaged → push burst → DEFEND on low HP → reset). Demonstrates the single-target focus / no-SWAP-thrash behaviour.
- **`WeakAuraBridge.GetPvPContext()`** exposes `state.pvpContext` to WeakAuras so consumers can render different displays per context (e.g., hide the comp badge in BG, show flag-carrier-specific text in world).
- **AV-scale perf test** (`Tests/Performance_spec.lua`) — 40-enemy state, asserts `SE:Evaluate` stays under 50ms CI budget. Confirms the v2.1 engine scales to AV without code changes.

### Changed
- **README** "Works in every PvP context" matrix added at the top — bilingual, summarises arena / BG / world / duel behaviour at a glance.
- **README** slash-command table now lists `/acc test bg` and `/acc test world` (bilingual).
- **`Core:_RunTestDemoMode(beats, label)`** refactored to accept the beat list + label as arguments (was hard-coded to the arena RMP beats); `/acc test` dispatches into one of three beat sets.

### Tests
586 → 590 (+4). New tests: `/acc test bg` runs and prints the BG walk-through banner; `/acc test world` does the same for world; `WAB:GetPvPContext` round-trips state; AV 40-enemy Evaluate stays within perf budget.

## [2.1.0] - 2026-05-25

**Wild PvP** — battlegrounds + world PvP + duels. The addon used to be effectively disabled outside arena because enemy discovery was hardcoded to `arena1..arena5` unit IDs and bracket-aware scoring assumed 2/3/5 teams. v2.1 extends the engine to BG (WSG / AB / AV / EotS) and open-world PvP without breaking the arena flows that already work.

User-facing pitch: open the addon in a Warsong Gulch queue and you'll see a recommendation frame with sensible kill targets (the flag carrier at low HP dominates), low-HP straggler swaps, and BG-flavoured callouts. Toggle nameplates and enemies appear / disappear as they come into LOS. Duels light up the frame with your opponent. None of this required new modules — same engine, just made context-aware.

12 new locale keys (103 → 115). 50+ new tests (538 → 586+). CI 99% coverage gate still green.

### Added — M16 (v2.1 quality + ship)
- **End-to-end BG simulation.** `Tests/BGModeE2E_spec.lua` synthesises a 10-player BG roster and verifies: flag-carrier dominates kill priority, low-HP straggler swap, `CALL_FLAG_CARRIER_LOW` + `CALL_BG_DEFEND` emission, no comp identification, no SWAP thrash on small score gaps, perf within budget (10 enemies × Evaluate stays under 30ms CI), arena-only callouts don't fire spuriously. 8 cases.
- **Per-source pattern progress (bug fix).** `Patterns:Observe(spellID, ts, sourceGUID)` now keys progress by `<patternId>|<sourceGUID>` so two enemy priests casting Psychic Scream don't collide / false-complete each other's chains. Legacy 2-arg signature `(spellID, ts)` still works (sourceGUID defaults to a sentinel). `Probability` accepts an optional `sourceGUID` for per-caster lookup; without it, returns MAX progress across tracked sources. 4 new tests.
- Version bump: 2.0.2 → **2.1.0** (minor — new feature surface).

### Added — M15 (v2.1 world PvP + duels)
- **World PvP engine branch.** When `state.pvpContext == "world"`:
  - `decideMode` skips OPEN (no arena planning phase) and skips SWAP (single-target focus, no team coordination)
  - `Strategies:Identify` is bypassed (matched comp would be coincidence in a fixed-roster-less context)
  - `shouldDefend`'s comp-based `triple_dps_pre` check is bypassed for the same reason
  - DEFEND still fires when the player's HP drops below the aggression-tuned threshold (via existing `lowestHealer` path — in world the "lowest friendly healer" is just the player themselves)
- **BG mode also skips OPEN** (same reasoning — no pre-combat planning in BG).
- **Duel detection.** New event handlers in Core:
  - `DUEL_REQUESTED` → forces `pvpContext = "world"`, stamps `Core._lastWorldHostileTs`, seeds an enemy entry from the current target via `_NonArenaCLEUStub` + `refreshUnit`. Triggers an immediate `Evaluate` so the frame populates as soon as the duel countdown starts.
  - `DUEL_FINISHED` → clears the recent-hostile timestamp and re-runs `DetectPvPContext` to drop back to whatever context the player is in.
- 8 new tests (6 in `StrategyEngine_extra_spec`, 2 in `Core_spec`): world PRE → no OPEN, world SWAP suppression, world skips comp ID, arena comp ID regression, world DEFEND on low HP, BG PRE → no OPEN, duel start populates target, duel end clears + re-detects.

### Added — M14 (v2.1 BG mode)
- **BG scoring boosts.** Three new `SE.weights` entries active when `state.pvpContext == "bg"`:
  - `bg_flag_carrier = 200` — WSG flag aura (23333 Alliance / 23335 Horde) eclipses every other priority
  - `bg_low_hp_straggler = 30` — bonus for any enemy <30% HP (BG produces lots of swap windows)
  - `bg_healer_boost = 10` — small bump on top of `role_healer` (healer death decides BG fights)
- **BG SWAP threshold tightened** to 30 (vs default 10) to prevent thrash in messy BG combat where LOS and target reshuffle.
- **BG callouts.** `buildCallouts` emits when `pvpContext == "bg"`:
  - `CALL_FLAG_CARRIER_LOW` when the kill target has a flag aura + <50% HP
  - `CALL_BG_DEFEND` on DEFEND mode (cleaner cue than the arena-flavoured Pain Sup / BoP set)
- **5 new locale keys**, parity green at 103 each: `CALL_FLAG_CARRIER_LOW`, `CALL_INCOMING_PLAYERS`, `CALL_BASE_UNDER_ATTACK`, `CALL_BG_DEFEND`, `CALL_BG_RES_TIMER`. (Three are wired in this PR; two are reserved for future BG-objective work in v2.2.)
- **Class-prior tier in OpponentProfile.** PUG'd BGs reset team-signature profiles every match. New `OP:GetClassPrior(class, db)` / `OP:UpdateClass(class, key, observed, db)` track tendencies across all observations of a class regardless of team. `OP:EstimateWithClassPrior(profile, key, class, default, db)` prefers the team profile when it has ≥5 samples, falls back to the class prior, falls back to the default. Stored under `db.classPriors[CLASS][tendency]` — does NOT mix with arena's `db.profiles`.
- 13 new tests (6 in `StrategyEngine_extra_spec`, 7 in `OpponentProfile_spec`).

### Added — M13 (v2.1 foundation)
- **PvP context detection.** New `Core:DetectPvPContext()` returns one of `"arena" / "bg" / "world" / "world_idle" / "none"`. Reads `IsActiveBattlefieldArena()`, `GetInstanceInfo()`, `UnitIsPVP("player")`. Cached on `state.pvpContext`. Refreshed by `PLAYER_ENTERING_WORLD`, `ARENA_OPPONENT_UPDATE`, and the new `ZONE_CHANGED_NEW_AREA` subscription. Headless-permissive — when WoW APIs are absent, the cached fixture value survives.
- **Non-arena enemy discovery.** New `Core:RefreshEnemiesNonArena()` walks `nameplate1..nameplate40`, keeps hostile players, keys by GUID (not unit ID, since nameplate units reshuffle on LOS). `Core:_NonArenaCLEUStub(guid, name)` creates a stub entry from CLEU events when the nameplate isn't visible yet. 30-second TTL prunes entries we haven't re-observed. Arena entries (keyed by `arenaN`) are left alone — `RefreshArenaEnemies` retains ownership.
- **`Core:Evaluate` routes** between `RefreshArenaEnemies` (arena context) and `RefreshEnemiesNonArena` (bg/world). No-op outside PvP.
- **`UI:Apply` gate updated** — prefers `state.pvpContext == "arena"` over the v2.0.2 `IsActiveBattlefieldArena()` direct call; falls back to the API if Core hasn't populated state yet (early-load).
- **`Core:UpdateRating` early-returns** when `pvpContext ≠ "arena"`. Avoids the WoW API roundtrip in BG/world and prevents `bracket=10` (WSG team size) from accidentally indexing into the rated-info table.

15 new tests in `Core_spec` covering each context, nameplate discovery, CLEU stub creation, stub non-overwrite, TTL prune, arena-key preservation, rating-API gate. 553/553 green.

## [2.0.2] - 2026-05-25

Bilingual docs + WSG/BG flash gate.

### Fixed
- **Screen flash + voice cues no longer fire outside arena.** Reported: "it kept blinking redness when I am doing WSG". The URGENT-mode screen flash + voice callout dispatch were unconditional once `db.alerts.screenFlash` / `db.alerts.sound` were on. In BG (and world PvP / outside-PvP) the engine's DEFEND-trigger heuristics fire spuriously and pulsed red flash every few seconds. `UI:Apply` now gates both the screen flash and the voice cue on `IsActiveBattlefieldArena()` — the recommendation frame itself stays available (so you can read the data in BG), but the intrusive alerts only fire in actual arena instances. Headless tests pass the gate via the missing-API permissive branch. +2 new tests in `UI_spec`.
- **Tooltip locale carry-over fix from v2.0.1** continues to work (`SetSpellByID` + `GetSpellInfo` fallback chain).

### Changed
- **All user-facing docs are now bilingual (English + 中文) inline.** No separate language files. The root `README.md`, `ArenaCoachTBC/README.md`, `docs/architecture.md`, `docs/weakaura-pack.md`, and `docs/weakaura-imports.md` now interleave English and Chinese content at the section level. Section headings carry both languages (`Installation / 安装`); prose paragraphs appear in both languages back-to-back. Code blocks, slash commands, API names, and config keys are kept English (those are universal artifacts). `tools/export_weakauras.mjs` updated to emit bilingual headers + descriptions, so future regenerations keep both languages.

### Documented
- **BG support is partial in v2.0.2.** The recommendation frame can be shown in BG via `/acc toggle`, and the engine continues to evaluate (so WeakAuras and the trace log still receive data), but the per-comp catalog and chain definitions are tuned for arena 2v2/3v3/5v5. Proper BG support (large-team mode, BG-specific kill priority, BG-specific chains) is a v2.1 roadmap item.

## [2.0.1] - 2026-05-25

Documentation + UX polish on top of v2.0. No engine changes — 536 tests, 99%+ coverage, 81% benchmark baseline.

### Fixed
- **Mouse-over tooltips on icon-row buttons now follow the WoW client locale** instead of showing hardcoded English. `makeIcon`'s `OnEnter` calls `GameTooltip:SetSpellByID(spellID)` (canonical localized tooltip with icon + name + flavor text) when available, with `GetSpellInfo(spellID)` as a localized fallback. The English string label is kept only as the last resort when both WoW APIs are absent (headless tests). Icon buttons now carry `spellID` directly for this path.

### Changed
- **`/acc test` is now a DBM-style scripted UI walk-through** instead of a tight chat-only loop. Force-shows the frame, then steps through 7 beats over ~14 seconds via `C_Timer.After`: `OPEN` → `KILL` → `BURST_NOW` pulse → `SWAP` → `DEFEND` (with screen flash if `db.alerts.screenFlash` is on) → profile-driven callout (`CALL_SAVE_TREMOR_HOJ`) → `RESET`. Each beat re-uses the real `UI:Apply` + `WeakAuraBridge:Publish` path so voice cues, chain block, comp badge, and burst pulse fire exactly as they would in a real arena. Frame visibility is saved + restored. Legacy chat-only summary kept under `/acc test print` (still walks `Strategies.testComps`).

### Added
- **Programmatic WeakAura import strings.** `tools/export_weakauras.mjs` (node-weakauras-parser) generates 5 paste-ready `!WA:2!...` strings to `docs/weakaura-imports.md`. Round-trip validated — each string decodes back to a valid WA config table. Templates: Mode badge, Burst gate, Defensive alert, Callout stream, Comp readout. Re-runnable: `cd tools && npm install && node export_weakauras.mjs`.
- **`docs/weakaura-imports.md`** — the generated paste-ready strings, ready for `/wa` → Import.
- **`_design/ArenaCoachTBC Design Showcase.html`** — 9-scene scrollable HTML mood board documenting the v2.0 user experience: hero, anatomy of the frame, in-arena KILL / DEFEND scenes, chain anatomy close-up, opponent profile in action, settings panel, WeakAura bridge integration, compact vs full mode comparison. Dark tactical-HUD aesthetic; mode colours pulled verbatim from `UI.lua > modeColors`; no Blizzard IP.

### Docs
- **README rewrite** — full step-by-step installation (per-OS paths), first-run checklist, daily-usage walkthrough during arena, complete slash-command reference table, configuration knob reference, localisation note clarifying that spell IDs are universal and names come from `GetSpellInfo(spellID)` in the WoW client's locale.
- Removed the stale "tuned for 5v5 melee cleave" framing. v2 adapts to any composition — `OwnComps:Infer` + 5 archetypes (`MELEE_CLEAVE`, `CASTER_CLEAVE`, `DRAIN`, `JUNGLE`, `DOUBLE_HEALER`), explained inline.
- `docs/weakaura-pack.md` restructured around two paths: paste-ready import strings (Path 1, recommended) vs hand-built trigger code (Path 2, DIY).
- `ArenaCoachTBC/README.md` slash-command table updated to reflect new `/acc test` behaviour.

### Locale
- `TEST_DEMO_START`, `TEST_DEMO_END`, `TEST_DEMO_NO_UI` added to `enUS` + `zhCN` (98 keys per locale, parity gate green).

### Tests
- Three new tests in `Core_spec.lua`: `RunTestMode` (default) emits start + per-beat + end lines (≥8); `RunTestMode "print"` triggers the legacy summary; demo restores hidden frame state when it started hidden. 533 → 535 total.

## [2.0.0] - 2026-05-25

v2.0 ships the **engine-depth** roadmap: spec-aware comp matching, multi-link CC chain planning, per-opponent Bayesian profiles, multi-step lookahead with bounded branching, pattern recognition for recurring kill setups, rating-aware risk gating, and a calibrated kill-probability model. 195 new tests (350 → 545), 89 → 95 locale keys per locale, 5 new pure modules (Chain, OpponentProfile, Lookahead, Patterns, Sounds), and a benchmark suite reporting 81% baseline agreement against hand-labelled scenarios.

The user-visible pitch: **your coach now learns your opponents**. A team that always trinkets Fear stops getting the "tremor for fear" callout — Tremor gets saved for HoJ instead. A mage that consistently Ice Blocks at 30% HP causes burst to be held. None of this is hardcoded — it learns from `/acc record` logs, per-team, no names persisted.

### Fixed
- Live arena observations now scan unit auras for Mortal Strike, Windfury, Bloodlust/Heroism, and enemy burst buffs before each evaluation, so burst gating is driven by observed state instead of permanently missing `msActiveOn` / `windfuryActive` flags.
- Train detection now counts damage events only when they land on friendly healers, preventing ordinary melee damage on DPS teammates from forcing DEFEND mode.
- Arena unit refresh now clears stale class/GUID/spec data when an `arenaN` or party unit disappears, preventing old rosters from polluting later comp identification.
- EventBus handler failures are captured by `ErrorReporter`, so `/acc bugreport` includes real in-addon handler errors instead of only manually captured failures.
- Cold Snap and Icy Veins now use distinct spell IDs and cooldown durations.
- Dev prerelease tags (`vX.Y.Z-dev.N`) are skipped by the release workflow's tag-trigger path so they cannot be republished as stable releases.

### Changed
- Strategy scoring now applies `openTarget` / `swapTarget` hints from the comp catalog, exposes `secondaryTargetClass`, and makes `strategy.aggression` affect the SWAP threshold.
- CI now runs the standalone `StrategyEngine_spec.lua` smoke spec in addition to the coverage suite.

### Added
- **Profile-driven callouts (#65).** `buildCallouts` consults `OpponentProfile:EstimateOrDefault` for three binary tendencies and emits the matching callout when the posterior mean ≥ 0.7 and the sample is opinionated (n ≥ 5): `CALL_FAKE_KICK_2` ("they kick the first heal — fake your second") gated on `kicksFirstHeal`; `CALL_SAVE_TREMOR_HOJ` ("they trinket Fear — save Tremor for HoJ") gated on `trinketsFear`; `CALL_BURST_BLOCK_INCOMING` ("Ice Block expected — hold burst") gated on `iceBlockBelow30`. `Core.PrepareAndEvaluate` resolves the opponent profile via `OpponentProfile:Signature(state.enemies)` and attaches it to `state.opponentProfile` (+ `state.opponentSignature`) before calling `StrategyEngine.Evaluate` — the engine itself remains pure. New `rec.profileContrib` field captures the comma-joined `<tendency>=<mean>` pairs that contributed; the `/acc trace` snapshot extends with a `profileContrib` field for post-mortem inspection. `rec.opponentSignature` exposed via WAB pipeline. 6 new tests cover each tendency gate, the threshold suppression at n<5, no-profile suppression, and the signature pass-through. Three new locale keys per locale (89 each).
- **Bayesian update variants + `Estimate` with CI + fallback (#64).** `OP:UpdateBinary(profile, key, observed)` mirrors `OP:Update` but operates on an already-resolved profile reference (no signature/db lookup). `OP:Estimate(profile, key)` returns `{ mean, low, high, n }` with a normal-approximation 95% confidence interval on the Beta(α, β) prior. `OP:EstimateOrDefault(profile, key, compDefault)` returns `compDefault` when `n < OP.MIN_SAMPLES_FOR_OPINION` (default 5), else the posterior mean — the gating primitive #65's profile-driven callouts will use. Tests verify convergence (20 positive observations → mean > 0.85), CI shrinks with sample size, and the fallback gate engages below threshold.
- **OpponentProfile module (#63, opens M9 — the keystone).** New `OpponentProfile.lua` stores per-opponent-team behavioural profiles keyed by team signature (`<sorted_classes>#<djb2_hash_of_sorted_names>`). Four binary tendencies tracked as `Beta(α, β)` priors: `trinketsFear`, `iceBlockBelow30`, `kicksFirstHeal`, `sapsPriest`. API: `Signature(enemies)`, `Get(sig, db)`, `Update(sig, event, db)`, `Forget(sig, db)`, `Mean(profile, tendency)`, `SampleCount(profile, tendency)`. `Update({tendency, observed})` bumps `α` (observed=true) or `β` (observed=false). `Get` backfills any newly-added tendency in the canonical list onto older persisted profiles. **Names are NEVER stored** — the djb2 hash is the only identifier that survives to SavedVariables (per the v2 "no personally-identifying data persists" rule). New SavedVar `db.profiles = {}`. Pure module: never touches a WoW API; reads / writes a passed-in db. `WeakAuraBridge` exposes `GetOpponentProfile()`, `GetOpponentSignature()`, and `GetTendencyMean(tendency)` for WeakAuras to read the current opponent's profile without re-implementing the signature logic. 23 new tests (21 in `OpponentProfile_spec`, 2 in `WAB_spec`) covering signature determinism, class-set + name sensitivity, name non-leakage in stored shape, Beta update math, mean / sample-count, backward-compat backfill, forget, and the WAB plumbing. **M10 lookahead and M11 risk gating both consume this.**
- **Chain callout renderer + `chain-vs-chain` simulator scenario (#62, closes M8).** Each chain template in `Data/Strategies.lua` now carries a `labelKey = "CHAIN_<id>"` field. 12 new locale keys (`CHAIN_RMP_SAP_INTO_KIDNEY`, `CHAIN_RMP_FEAR_INTO_BURST`, `CHAIN_WMS_SHEEP_INTO_TRAIN`, `CHAIN_WLD_FEAR_INTO_CYCLONE`, `CHAIN_WLP_FEAR_INTO_HOJ`, `CHAIN_JUNGLE_TRAP_INTO_CYCLONE`, `CHAIN_BEAST_TRAP_INTO_INTERCEPT`, `CHAIN_TSG_HOJ_INTO_INTERCEPT`, `CHAIN_TRIPLE_CASTER_OVERLAP`, `CHAIN_RP_KIDNEY_INTO_BLIND`, `CHAIN_RD_KIDNEY_INTO_CYCLONE`, `CHAIN_SHATTER_NOVA_INTO_SHEEP`) plus `CHAIN_PICKED_PREFIX` and `CHAIN_STEP_PREFIX` for the renderer, populated in both `enUS` and `zhCN` (86 keys per locale, parity gate green). `StrategyEngine.Evaluate` propagates `labelKey` and `steps` onto `rec.chain` and exposes the resolved link array via `rec.chain.links`. `UI:Apply` renders a chain block under the existing reason/callout subText: a localized title line with percentage + step count, then one indented line per step (`GetSpellInfo(spellID)` → spell name in-client, falls back to the category token in headless tests). UI prints the localized chain title to chat once per chain-id change — the placeholder per-step audio cue until M4 voice ships. New simulator scenario `chain-vs-chain` registered in `Data/SimScenarios.lua` (RMP enemy with DR-bumping cast sequence). Six new test cases verify catalog labelKey invariants, engine plumbing, UI narrate-once-on-change behaviour, and the simulator scenario runs without error.
- **Chain scoring + engine integration (#61).** `Chain:ScoreAll(chains, opts)` ranks a list of already-instantiated chains by `ExpectedProb` descending; `opts.topK` clips the output. `Strategies:InstantiateChains(comp, primaryGUID, secondaryGUID, enemies)` resolves a comp's `chains` templates into concrete chains by mapping `byClass` to an alive enemy of that class and `targetRole` (`"primary"` / `"off-healer"` / `"off-healer-2"` / `"any"`) to a target GUID, dropping links whose caster class isn't on the field. `StrategyEngine.Evaluate` now picks the top-scoring chain and emits `rec.chain = { id, label, expectedProb }`. Configurable via `db.strategy.chainK` (default 3, parameter for future M10 opponent-response branching). `WeakAuraBridge.GetChain()` / `GetChainId()` / `GetChainExpectedProb()` exposed. The engine's reason text is unchanged — chain selection is a separate field so callouts in #62 can render it on its own UI line. Tests cover `ScoreAll` ordering + clipping, `InstantiateChains` byClass/targetRole resolution + link dropping + empty-result omission, and engine integration (rec.chain present + DR pre-bump degrades chain prob).
- **Built-in chains per named comp (#60).** Eleven comps in `Data/Strategies.lua` now carry a `chains = { ... }` field describing their canonical CC kill chains: `RMP` (sap-into-kidney, scream-into-burst), `WMS` (sheep-into-train), `WLD` (fear-into-cyclone), `WLP` (fear-into-HoJ), `HUNTER_COMP` (trap-into-cyclone), `BEAST_CLEAVE` (trap-into-intercept with scatter), `TSG` (HoJ-into-intercept), `TRIPLE_CASTER` (stacked fear+sheep), `RP_2V2` (kidney-into-blind), `RD_2V2` (kidney-into-cyclone), `SHATTER_2V2` (nova-into-sheep). Each link is `{ spellID, category, byClass, targetRole }` where `byClass` references a class in the comp's `core` and `targetRole` is a string ID (`"primary"` / `"off-healer"` / `"any"`) resolved against the live state by future M8 wiring. 5 new tests in `Strategies_spec` assert the catalog invariants (>=10 chains, every link has a spell ID, byClass is in core, every chain validates against a fresh `Chain` state, every chain is well-formed). Hooks for #61 chain scoring + #62 callout renderer.
- **CC chain primitive (#59, opens M8).** New `Chain.lua` module. A chain is an ordered list of CC links `{ spellID?, target, category, by, castTimeS? }`. `Chain:Build(links)` constructs one; `Chain:Validate(chain)` returns `(ok, reason)` after walking links and rejecting on DR-immune (`reason="DR_immune"`), pending caster CD (`reason="cd_pending"`), or empty input (`reason="empty"`). `Chain:ExpectedProb(chain)` returns the product of effective DR multipliers across links (0 if any CD is pending or DR has already hit immune). Within-chain DR accumulation is tracked so a chain of three STUNs on the same target correctly returns expected probability `1.0 * 0.5 * 0.25 = 0.125`. Pure module; reads observation state from `DRTracker` / `CooldownTracker` without touching any WoW API directly. Foundation for #60 (per-comp built-in chains), #61 (chain scoring + lookahead), and #62 (CALL_CHAIN callout renderer).

### Added
- **Multi-reason burst gate (#73).** `StrategyEngine:BurstDecision(state, target, chain)` returns `{ allowed, blockedBy, gates }` with four named gates: `kill_prob` (passes when `KillProb >= SE.BURST_KILL_PROB_THRESHOLD[aggression]` — greedy 0.35, balanced 0.45, safe 0.55), `chain_ready` (passes when a chain with `expectedProb > 0` is in play), `incoming_pressure` (passes when no DEFEND-level pressure: not `healerUnderPressure`, not `enemyBloodlustActive`, not `multipleBurstsDetected`), `rating_aware` (audit trail of the aggression label + numeric rating that influenced thresholds — always passes). `blockedBy` names the first failing gate in `{kill_prob, chain_ready, incoming_pressure}` order. Engine populates `rec.burstDecision` on KILL recommendations. `WeakAuraBridge` adds `API.GetBurstDecision()`. 7 new tests cover gate enumeration, kill_prob blocking on high-HP targets, threshold scaling with aggression, incoming_pressure blocking on under-pressure healer, all-gates-pass case, Evaluate population on KILL, and the WAB getter.

### Added
- **Kill-probability model with auditable breakdown (#72).** `StrategyEngine:KillProb(target, state)` returns `{ prob, components }`. Components: `hp` (1 − hp/100), `defensiveDown` (+0.10 when target's trinket has been used), `immunityAbsent` (+0.10 when no Ice Block / Divine Shield / BoP active), `burstReady` (+0.05 when our HoJ is up), `healerLowMana` (+0.10 when their healer is < 30% mana), `drClean` (+0.05 when target's STUN DR is fresh). Sum clamped to `[0..1]`. Weights exposed via `SE.KILL_PROB_WEIGHTS` for tuning. `WeakAuraBridge` adds `API.GetKillProb(guid)` and `API.GetKillProbBreakdown(guid)` so WeakAuras can render the probability per enemy. 6 new tests cover nil-target safety, monotonic-with-HP (100→50→10 strictly increases), component contributions (trinket-down, low-mana-healer, burst-ready), clamping to ≤1.0, and the two new WAB getters.

### Added
- **Rating-aware aggression (#71, opens M11).** New `db.strategy.ratingAggression` config knob, default `"auto"`. When `"auto"` and `state.rating` is known, derives aggression from bracket rating: `<1800` → `greedy`, `1800–2200` → `balanced`, `>2200` → `safe`. Explicit `"greedy"`/`"balanced"`/`"safe"` override; a number is treated as a rating override (handy for tests). `Core:UpdateRating()` queries `GetPersonalRatedInfo()` against the current bracket (returns `nil` headless). `Core:CurrentAggression(state)` resolves the active label; `Core.PrepareAndEvaluate` writes it to `state.aggression` before calling `Evaluate`. Three thresholds shift on the rating axis: SWAP score-gap threshold (greedy 0 → safe 20), defensive HP gate (greedy 30% → safe 50%), and the LOW_MANA_PUSH callout threshold (greedy 30 → safe 20). Recommendation gains `rec.aggression` and `rec.rating` for trace inspection. 9 new tests (4 in `StrategyEngine_extra_spec`, 5 in `Core_spec`) cover `CurrentAggression` resolution, `UpdateRating` no-API safety, defensive threshold flip on aggression, and low-vs-high swap behaviour at the same state.

### Added
- **UI polish bundle (#77).** Compact mode: new `db.frame.compactMode` boolean default `false`. When toggled, `UI:Apply` hides the friendly + enemy icon rows so the recommendation block alone occupies the smallest possible footprint. Voice callouts: new `Sounds.lua` module maps callout keys to `PlaySoundFile`-compatible paths (`Sound/Voice/<name>.ogg`) and dispatches a one-shot cue per *new* top callout via the `db.alerts.sound` toggle. Headless-safe: when `PlaySoundFile` is unavailable, `Play` returns `false` without erroring. Audio assets ship as placeholder paths — the artist drop populates the binaries alongside the addon zip. 5 new tests (4 in `Sounds_spec`, 1 in `UI_spec` for compactMode).

### Quality
- **Confidence calibration audit (#76).** New `Tests/Calibration_spec.lua` runs 100 deterministic synthetic states across HP / trinket / mana / DR axes, bins predictions into 10 deciles, and reports `[CALIB]` per-bin (predicted, ground-truth, error) lines for inspection. Headline metric: **max per-bin error 0.10** for the v2.0 engine, well within the 0.20 budget. Engine adds `SE:CalibrateConfidence(rawConf)` — identity for v2.0; the hook is in place so future versions can ship measured bias corrections without touching callers.

### Quality
- **Benchmark suite (#75, opens M12).** New `Tests/Benchmark_spec.lua` defines 21 canonical match scenarios spanning every major comp family (RMP / WLD / WMS / TSG / SHATTER / DRAIN / mirror / triple-caster / hunter-cleaves), plus mode-triggering edge cases (healer-trained DEFEND, enemy bloodlust DEFEND, multiple bursts, no enemies RESET, swap threshold, priest-dead-mid-match). Each scenario seeds a synthetic state and labels the expected `mode` (and optionally `primaryTargetClass`). Runner reports `[BENCHMARK]` agreement per scenario + overall rate to stdout for CI artifact capture. Soft floor of 50% so this is informational, not a hard CI gate. Current baseline: **81% (17 / 21)** on the v2.0 engine.

### Quality
- **Rating-aware end-to-end test (#74, closes M11).** New `Tests/RatingAwareE2E_spec.lua` runs the same synthetic state at rating 1400 (greedy) vs 2400 (safe). 4 cases: BurstDecision kill_prob threshold differs (low rating → lower threshold); defensive HP gate flips mode (greedy holds at 45 HP healer, safe goes DEFEND); ≥2 of {burst threshold, defensive HP, low-mana threshold} differ between low and high rating; blocked burst decisions cite the failing gate by name. Closes M11 — combined with #71 (rating-aware aggression), #72 (KillProb), #73 (BurstDecision gates), the engine now plays differently at different ratings, with every choice explainable via the audit trail. 524/524 green.

### Quality
- **Lookahead performance budget tests (#70, closes M10).** `Tests/Performance_spec.lua` extended with a lookahead-on case asserting mean < 10ms / 99p < 30ms over 200 evaluations on a 5v5 / 3v3 state (target 3ms mean / 10ms 99p, with a 3x CI margin for noisy GH runners). `Lookahead.lua` gained a per-call response-distribution cache: `EnumerateResponses` is invoked once per `Score` call and reused across the K candidate chains (the distribution depends only on the profile). `Lookahead:CacheStats()` returns `{hits, misses, total, rate}` so consumers can inspect the hit rate; `Lookahead:ResetCacheStats()` zeroes the counters between measurement windows.

### Added
- **Pattern recognition for recurring kill setups (#69).** New `Patterns.lua` module with five seeded patterns: `RMP_CHEAP_BLIND`, `SHATTER_NOVA_SHEEP`, `FEAR_INTO_POLY`, `HUNTER_TRAP_SCATTER`, `HOJ_INTO_INTERCEPT`. Each is an ordered list of `{ spellID, withinSeconds }` steps. `Patterns:Observe(spellID, ts)` fed from `Core.onCLEU` on `SPELL_CAST_SUCCESS`; `Patterns:Probability(id)` returns completed-steps / total; `Patterns:GetMatches(threshold)` returns matched patterns (default threshold 0.7). Half-matches expire after `STATE_TTL_SECONDS` (12s default). Engine `buildCallouts` pushes `CALL_PATTERN_<id>` for every match. 5 new locale keys per locale (95 each, parity green). 12 tests cover catalog invariants, full sequence match, fractional probability, out-of-order rejection, window enforcement, TTL expiry, threshold gating, Clear, nil safety, each pattern's positive case, and unrelated-cast-in-the-middle resilience.
- **`/acc whatif` counterfactual replay (#68).** New slash subcommand: `/acc whatif help`, `/acc whatif summary`, `/acc whatif skip <i>`. Replays the current `db.record.events` through the engine with a single event removed (or other modifier) and prints how many recommendations diverged from baseline, with up to 5 sample diffs. Backed by two new exported helpers: `Core:ReplayRecord(events, modifier)` builds a synthetic state, runs the engine for each event, and returns a sequence of `{mode, comp, chainId}` snapshots — pure (snapshots + restores live CooldownTracker / DRTracker so it does not pollute in-game state); `Core:DiffReplays(a, b)` returns `(count, samples)`. Two new locale keys `HELP_WHATIF` in `enUS` + `zhCN` (90 keys each, parity gate green). 6 new tests cover `ReplayRecord` non-leakage, `DiffReplays` identity / divergence with samples, `/acc whatif` with no record, help output, and `skip` output.
- **Lookahead expectimax (#67, opens M10).** New `Lookahead.lua` module. Re-ranks the top-K chains from M8 #61 by *expected value* over opponent responses (read from the M9 OpponentProfile when present, otherwise a 50/50 split). Bounded branching: defaults top-3 actions × top-3 responses × 3 plies = 81 leaves max per evaluation, configurable via `db.strategy.lookaheadTopActions` / `lookaheadTopResponses` / `lookaheadEnabled`. Engine integration: `rec.chain` gains an `expectedValue` field that reflects the post-lookahead score (vs the existing `expectedProb` which is the raw chain prob); `expectedValue <= expectedProb` by construction. `lookaheadEnabled = false` reverts to the greedy chain pick — useful for debugging / benchmarking. 9 new tests (7 in `Lookahead_spec`, 2 in `StrategyEngine_extra_spec`) cover EV computation, top-K clipping, profile-driven re-weighting (high trinket-prob lowers EV; low trinket-prob raises it), response probabilities summing to 1, and the disable toggle.

### Quality
- **End-to-end opponent-modelling test (#66, closes M9).** New `Tests/OpponentModellingE2E_spec.lua` drives the full M9 pipeline (Signature → Update → Get → Estimate → buildCallouts) against synthetic teams. 4 cases: (a) `CALL_SAVE_TREMOR_HOJ` appears after 20 trinket-fear openings; (b) trained team A fires the callout while untrained team B does not, even with identical comp; (c) profile sanitisation — renaming the players produces a different signature, two independent profiles in `db.profiles`, but the same callout converges (the comp + observed behaviour determines the recommendation, not the names; no raw name strings ever appear in the persistent shape); (d) match-by-match: the callout first appears at observation ≥ 5 (the `MIN_SAMPLES_FOR_OPINION` gate). 471/471 green; locale parity green at 89 keys.
- **End-to-end spec-match test suite (#58).** `Tests/SpecMatchE2E_spec.lua` drives spec attribution through the real `SpellSpecHints:Apply` path (concrete spell IDs from `Data/Spells.lua`) and asserts `Strategies:Identify` picks the right spec-keyed variant. 15 cases covering each spec-keyed comp variant (RMP_DISC, SMR, WLD_RESTO, WLD_FERAL, SHATTERPLAY_SHADOW, SHATTER_FROST_2V2, HUNTER_PRIEST_BM_2V2), confidence calibration (1/3 vs 2/3 vs 1.0), wrong-spec disqualification (Holy priest → class-only RMP, not RMP_DISC), bracket isolation (a 2v2 shadow-priest setup never matches a 3v3 spec-keyed comp), and a catalog invariant that every spec-keyed comp's required spec is reachable from at least one `SpellSpecHints` entry.

### Added
- **Comp-match confidence scoring (#56).** `Strategies:Identify` now returns `(comp, confidence)` where confidence is in `[0..1]`. Spec-keyed matches return `1.0` by construction; dynamic role-count comps (`TRIPLE_DPS`, `DOUBLE_HEALER`) return `1.0`; class-only matches return the ratio of core-class enemies whose `specGuess` has been observed; legacy class-list-only callers (no enemies map) return `0.0`. The recommendation gains two new fields — `compConfidence` and `compSpecConfirmed` — and the reason text appends a `<COMP_ID> spec-confirmed|class-guessed (NN.NN)` tag so `/acc trace` and `/acc bugreport` payloads show the confidence inline. UI subText renders a localized badge: `<compLabel> (spec-confirmed|class-guessed)`. Two new locale keys — `COMP_BADGE_SPEC_CONFIRMED` and `COMP_BADGE_CLASS_GUESSED` — added in `enUS` and `zhCN`. `WeakAuraBridge` exposes `GetCompConfidence()` and `GetCompSpecConfirmed()`. Two-value return is backward-compatible — single-assignment callers silently drop the new value.
- **Spec-keyed comp catalog (#55).** `Data/Strategies.lua` comps gain an optional `specs = { CLASS = "SPEC" }` field. `Strategies:Identify` matches spec-keyed entries only when every required spec is explicitly observed via `enemy.specGuess` from spec inference; mismatched or unknown specs disqualify the spec-keyed entry so a class-only sibling declared later catches the fallback. Seven new spec-keyed variants seeded: `SHATTER_FROST_2V2`, `HUNTER_PRIEST_BM_2V2`, `SMR_3V3` (Shadow Priest variant of RMP), `RMP_DISC_3V3`, `WLD_FERAL_3V3` (no-healer variant, defaults to DEFEND), `WLD_RESTO_3V3`, `SHATTERPLAY_SHADOW_3V3`. Callers using the legacy class-list-only signature never match a spec-keyed comp because spec data only flows via the enemies map — so backward compatibility is preserved.
- **Spec inference v2 (#57).** `Data/SpellSpecHints.lua` expanded from 12 to 57 hints covering all 9 classes × 3 specs. Aura-applied hints (Shadowform, Vampiric Embrace, Spirit of Redemption, Moonkin Form, Tree of Life, Soul Link) and talent-implying casts (Vampiric Touch, Pain Suppression, Power Infusion, Holy Shield, Avenger's Shield, Repentance, Mana Tide, Tidal Force, Elemental Mastery, Shamanistic Rage, Shield Slam, Last Stand, Swiftmend, Mangle Bear, Siphon Life, Conflagrate, Shadowburn, Shadowfury, Arcane Power, Slow, Presence of Mind, Pyroblast, Combustion, Dragon's Breath, Icy Veins, Summon Water Elemental, Mutilate, Cold Blood, Blade Flurry, Adrenaline Rush, Premeditation, Shadowstep, Hemorrhage, Bestial Wrath, Intimidation, Silencing Shot, Readiness, Wyvern Sting) all carry definitive spec attribution. `Core.onCLEU` now routes `SPELL_AURA_APPLIED` / `SPELL_AURA_REFRESH` (not just `SPELL_CAST_SUCCESS`) through `SpellSpecHints:Apply`, so auras already in effect at the start of a match still teach the engine.
- **WeakAura template pack** (`docs/weakaura-pack.md`) — five copy-paste trigger templates (mode badge, burst gate, defensive alert, callout list, comp readout) that consume the `_G.ArenaCoachTBC` bridge. `WeakAuraBridge.L(key)` exposed so templates can resolve callout keys to the user's active locale without re-implementing the fallback chain.
- **`/acc record` CLEU recording + `tools/replay.lua`.** When `record` is on (default off), every CLEU event passed through `Core.onCLEU` is appended to `ArenaCoachTBCDB.record.events` (ring buffer, default cap 1000). `tools/replay.lua <SavedVariables.lua>` re-runs the captured log through the StrategyEngine offline and prints periodic recommendation snapshots, so a maintainer can second-guess specific calls without recreating the arena. `/acc record on/off/status/dump/clear`. enUS + zhCN `HELP_RECORD` strings.
- **`/acc bugreport` error reporter.** `ErrorReporter.lua` module with `Capture(err, ctx)`, `Recent(n)`, `Reset()`, `Format(maxErrors)`, `Sanitize(text)`, `SetKnownNames({...})`. Ring buffer caps at 20 captured errors. Sanitisation strips `Player-XXX-XXX` GUIDs, bare `guid-...` tokens, `Name-Realm` patterns, and any character names registered via `SetKnownNames`. `/acc bugreport` prints a markdown payload (addon version + client build + last 5 sanitised errors) ready to paste into a GitHub issue. enUS + zhCN `HELP_BUGREPORT` / `BUGREPORT_HEADER` strings.

### Quality
- **Locale parity gate** added to CI (`tools/check_locales.lua`). Runs before the Lua test suite. Diffs every locale file's key set against `enUS` and exits non-zero with an explicit `<locale> missing N key(s):` listing. The existing `Locales_spec.lua` parity test stays in place as a second layer.
- **Performance budget enforced as tests.** `Tests/Performance_spec.lua` asserts `StrategyEngine:Evaluate` averages <5ms per call on a 5v5 state (target <1ms; the 5x CI margin tolerates noisy GH runners) and that 100 back-to-back simulated arenas stay within a 200kb GC delta (issue's 100kb target plus 2x slack for the spec framework). Catches scoring-loop regressions and enemy/cooldown table leaks before they ship.

### Added
- **Decision-trace logging.** `/acc trace on` records every `Evaluate` recommendation (mode, target, reason, comp, bracket, callouts) into a ring buffer in SavedVariables. Defaults: disabled, cap 200 entries. `/acc trace off`, `/acc trace status`, `/acc trace dump`, `/acc trace clear`. Lets users (or me) post-mortem why the engine called a swap by inspecting the persistent log between sessions.
- **Train detection.** Core tracks damage events landing on our friendlies in a sliding window. When `peelTriggerDamage` (default 3) events arrive within `peelTriggerWindow` (default 5s), `state.observations.healerUnderPressure = true` and the engine forces DEFEND mode with reason `trained`. Both thresholds are configurable via `db.strategy.peelTriggerWindow` / `peelTriggerDamage`. `Core._friendlyGUIDs` is updated by every `RefreshFriendlies` so CLEU damage matching is fast.
- **DR-aware callouts.** `buildCallouts` consults `DRTracker:NextMultiplier` before emitting CC-related callouts. `CALL_HOJ_KILL` is suppressed when the kill target's STUN DR is in immune territory; `CALL_CYCLONE_OFF` is suppressed when the off-healer's CYCLONE DR is immune. No history = full multiplier = callout allowed (so the first cast still fires).
- **Cooldown-aware scoring.** `SE.weights.kill_defensive_soon = -10` penalises kill targets whose major defensive (Ice Block / Divine Shield / BoP) comes off cooldown within ~15s. Catches the "we're about to waste burst into Ice Block" case. Uses observed casts from `CooldownTracker`; no history = no penalty.
- **Mana-bar tracking on enemy healers.** When an enemy healer drops below 25% mana, the engine adds the `low_mana_healer = +20` weight to their score and emits the `CALL_LOW_MANA_PUSH` callout ("Healer low mana - push now" / "治疗蓝量低 - 压上"). `enemy.manaPct` was already populated by `RefreshArenaEnemies`; this wires it into scoring + callouts.
- **M2 catalog data.** 9 named 2v2 comps (RP / RD / Drainteam / Shatter / Enh+Priest / Hunter+Priest / War+Druid / War+Holy / SP+Pala) and 10 named 3v3 comps (RMP / WLD / Jungle / Shatterplay / LSD / RPH / Thunder cleave / Pala cleave / Ele Sham / Hunter+Lock+Priest) all tagged `bracket = 2|3`. Bracket-tagged comps win over agnostic ones when both match, so `/acc enemy rogue priest` in a 2v2 picks the `RP_2V2` entry instead of falling back to the generic catalog.
- **M2 bracket infrastructure.** `Core:UpdateBracket()` reads `GetBattlefieldStatus` and sets `state.bracket` (2, 3, or 5). Hooked to `UPDATE_BATTLEFIELD_STATUS`, `PLAYER_ENTERING_WORLD`, and `ARENA_OPPONENT_UPDATE` so the bracket is fresh whenever the engine evaluates.
- `Strategies:Identify(list, enemies, bracket)` now accepts an optional bracket arg. Comps can declare `bracket = 2|3|5` to opt into bracket-specific matching; bracket-tagged comps win over agnostic ones when both match.
- `SE:GetWeights(bracket)` returns the default scoring weights merged with any per-bracket overrides from `SE.bracketWeights`. 2v2 boosts `role_healer` to 40 (single-target healer kills win games); 3v3 raises it to 30. 5v5 uses defaults.
- `WeakAuraBridge.GetBracket()` exposes the current bracket to WeakAuras consumers.

### Added
- M1 foundations: LICENSE (MIT), CONTRIBUTING guide, issue templates, PR template, manual smoke checklist.
- Release pipeline: `.pkgmeta` + `.github/workflows/release.yml`.
  - **Every push to `main` auto-tags `v{base}-dev.{run_number}` and publishes a GitHub Pre-release** with the addon zip attached and notes extracted from the `[Unreleased]` section of `CHANGELOG.md`. Pick up the latest testable build from the [Releases page](https://github.com/tomqwu/wow_tbc_arena_pvp_strategy/releases).
  - **Pushing a stable tag `v1.2.3`** publishes a full release with notes from the matching `## [1.2.3]` CHANGELOG section. Stable releases also upload to CurseForge / Wago when `CF_API_KEY` / `WAGO_API_TOKEN` are configured.
- `## Interface-BCC: 20504` directive in `ArenaCoachTBC.toc` so the packager builds a BCC-flavoured zip without a duplicate TOC.
- `CooldownTracker` now tracks **Will of the Forsaken** (7744, Undead racial) as a separate 120s cooldown. Surfaces via the existing `CT:IsReady(guid, 7744)` / `CT:GetRemaining(guid, 7744)` API. Aura-applied events are also caught, so WotF use is recorded even if the cast event is missed.
- `Spells.CC_BREAK_RACIALS` exposes the set of racials that act as fear/CC-breaks (currently just WotF). Engine consumers can iterate this when reasoning about "any CC-break ready" without hardcoding race-specific IDs.
- `/acc selftest [verbose]` — runs ~10 fast in-client assertions covering Spells data, CooldownTracker round-trip, DRTracker, StrategyEngine, Strategies/OwnComps identification, locale resolution, EventBus emission, and the WeakAura bridge. Reports `SelfTest: N passed, M failed`. Useful when a client patch or another addon clobbers state.
- `SelfTest.lua` module with `Register` / `Reset` / `Run(verbose, printer)` / `RegisterDefaults`. Composable so future modules can register their own checks.
- **Spec inference v1.** `Data/SpellSpecHints.lua` maps spec-defining casts to `{spec, role}` (Mind Flay → Shadow priest, Holy Shock → Holy paladin, Earth Shield → Resto shaman, Mortal Strike → Arms warrior, Bloodthirst → Fury, Crusader Strike → Ret, Mangle → Feral, Stormstrike → Enhancement, Lifebloom → Resto druid, Unstable Affliction → Affliction, Shadowform → Shadow priest). On every `SPELL_CAST_SUCCESS` for an enemy GUID, `Core` calls `SpellSpecHints:Apply(enemy, spellID)` to overwrite the default class-based role with observed evidence.
- 6 new max-rank TBC spell IDs in `Data/Spells.lua` to support the hint table (SHADOWFORM, MIND_FLAY, HOLY_SHOCK, EARTH_SHIELD, BLOODTHIRST, MANGLE_CAT). All sourced as TBC 2.4.3.
- **`/acc simulate <key>`** — scripted scenario runner. Sets up a fake enemy team, schedules events on `C_Timer.After`, and drives the live UI through a full fight without an arena. Three baked scenarios: `rmp` (Rogue/Mage/Priest opener with sap → poly → kidney → CS → fear → trinket), `tsg-mirror` (melee cleave training the priest), `drain` (Affliction lock + Disc priest 2v2 pressure). `/acc simulate` with no args lists scenarios; `/acc simulate stop` cancels a run in progress.
- `Simulator.lua` + `Data/SimScenarios.lua` modules. The simulator falls back to synchronous dispatch when no `C_Timer` is available, which is what unit tests rely on.

### Changed
- Renamed `S.PVP_TRINKET` (which was incorrectly set to 7744 / Will of the Forsaken) to `S.WILL_OF_THE_FORSAKEN`. The actual PvP trinket effect remains `S.PVP_TRINKET_EFFECT = 42292`. No callers were affected — the old symbol was unreferenced outside the data file.

### Notes
- An Anniversary-flavour TOC is deferred until the interface version for that client is confirmed (tracked in #8).
- Engine scoring (`trinket_down = +20`) still keys off the 42292 aura only. Wiring a separate `cc_break_down` weight for WotF is left to a follow-up — see #9 follow-up note.
- Spec-inference hints are conservative: only spec-defining casts are listed. Spells castable by every spec of a class (e.g. Mind Blast — any priest, Frostbolt — any mage) are deliberately NOT mapped because they would mislabel an enemy. `Strategies:Identify` already consumes `enemy.roleGuess`, so the next call after a relevant cast naturally picks up the new role.

## [1.1.0] - 2026-05-24

### Added
- Dynamic own-team capability inference (`Data/OwnComps.lua`) with 5 archetypes (BURST_CLEAVE, SUSTAINED_CLEAVE, CASTER_CLEAVE, DRAIN_TEAM, BALANCED).
- 13-entry enemy comp database (`Data/Strategies.lua`) with per-archetype `ownVariants`: RMP, WMS, WLD, WLS, WLP, HUNTER_COMP, BEAST_CLEAVE, TSG, RLS, MIRROR_MELEE, TRIPLE_CASTER, DOUBLE_HEALER, TRIPLE_DPS.
- 25-getter WeakAura bridge exposed via `_G.ArenaCoachTBC`.
- CI workflow that runs all tests, computes coverage with luacov, and fails the build below 99%.

### Changed
- Renamed addon from `ArenaCleaveCoachTBC` to `ArenaCoachTBC`. The name no longer implies cleave is the only archetype supported.
- Engine reads capabilities, not class names — adding a new class will not regress existing strategies.

### Test
- 193 tests, 99.46% line coverage.

## [1.0.0] - 2026-05-23

### Added
- Initial check-in: Core, StrategyEngine, CooldownTracker, DRTracker, EventBus, UI, Options, WeakAuraBridge.
- enUS + zhCN locales.

[Unreleased]: https://github.com/tomqwu/wow_tbc_arena_pvp_strategy/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/tomqwu/wow_tbc_arena_pvp_strategy/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/tomqwu/wow_tbc_arena_pvp_strategy/releases/tag/v1.0.0
