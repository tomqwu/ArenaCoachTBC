# ArenaCoachTBC — Roadmap v2 (Engine Depth, 12-month vision)

> The 1.0 ROADMAP shipped a polished addon: distribution, capability inference,
> bracket support, named comps, observability, and the safety rails (99%
> coverage, no automation, opt-in everything). What it did not do is make the
> *engine itself* meaningfully smarter than a well-tuned rule-based system.
>
> Roadmap v2 fixes that. The thesis: arena is a partially-observable
> sequential game where the players who win are the ones who anticipate
> opponent behaviour, plan multi-step CC chains, and calibrate aggression to
> the match's risk. A coach that scores the current tick with a weighted sum
> can only ever match a careful rule book. To be *better*, the engine has to
> reason over time and over opponents.
>
> Six milestones, ~3 months apart, building toward a v2.0 release. Each is
> shippable on its own and each milestone makes the engine measurably smarter
> on a benchmark we'll define in M7.

---

## M7 — Spec-aware comp matching  *(target: month 2)*

Today comps match on **class** presence. A Priest can be Disc, Holy, or
Shadow — three radically different threat profiles. The spec inference v1
shipped in M1 (`SpellSpecHints.lua`) tells us the spec, but `Strategies`
still keys off classes. M7 closes the gap.

### Themes

**Spec-keyed comp catalog.** Comps grow an optional `specs = { PRIEST="DISCIPLINE", DRUID="RESTORATION" }` field. A comp matches only when every required spec matches; falls back to class-only when spec is unknown. Adds ~30 spec-specific entries (e.g. *AffliPriest* vs *DestroPriest* in 2v2, *ShadowPlay* vs *DiscPlay* in 3v3).

**Confidence scoring.** Each match returns `(comp, confidence)` where confidence reflects how many of the comp's specs were observed (vs guessed). Engine consumers (UI, WeakAura bridge) can render uncertainty.

**Spec inference v2.** Expand `Data/SpellSpecHints.lua` from 12 to ~40 entries. Add aura-based hints (Shadowform implies SHADOW even before Mind Flay). Add cooldown-based hints (Cold Snap observed → FROST mage). Add talent inference from observed effects (Improved Counterspell silence → ARCANE).

**Tests.** Match each named comp's spec variant from a synthetic CLEU sequence. Asserts that spec mismatch downgrades confidence and that wrong spec doesn't trigger a different comp's variant.

### Deliverable
`Strategies:Identify(list, enemies, bracket)` returns `comp, confidence` instead of `comp`. UI badge: `RMP (spec-confirmed)` vs `RMP (class-guessed)`.

---

## M8 — CC-chain planning  *(target: month 4)*

The current engine emits CC callouts one at a time (`CALL_HOJ_KILL`,
`CALL_CYCLONE_OFF`). M8 plans **chains**.

### Themes

**Chain primitives.** A `Chain` is `{ {target, category, by}, ... }` — a sequence of CC links with the unit casting each. Chains are evaluated against current DR + cooldowns + cast-time gates (a 1.5s cast can't follow a stunned target).

**Built-in chains per comp.** Each comp gets a `chains = { ... }` field with 1-3 canonical setups. Examples:
- RMP kill chain: `{rogue Cheap Shot} → {mage Polymorph off-healer} → {rogue Kidney Shot} → {priest Mana Burn off-healer}`
- TSG opener: `{warrior Intercept} → {DK Strangulate} → {paladin HoJ}` (replace DK with the TBC variant)

**Chain scoring.** Engine picks the chain with the highest expected kill probability given current state (CDs, DR, immunities, mana, positioning). Multi-tick lookahead (2-3 ticks) under bounded branching.

**Chain callouts.** Instead of `CALL_HOJ_KILL`, emit `CALL_CHAIN("hoj_into_ms")` and the UI/audio layer renders the full sequence step-by-step. The simulator (M1 #43) replays chains in real time so you can validate them.

**Tests.** Each chain validated against synthetic DR + CD state. Engine asserted to pick the highest-probability chain when given multiple options.

### Deliverable
`StrategyEngine:Evaluate` returns a `chain` field. Callouts render as
ordered steps. The simulator gets a new "watch the engine choose between
two chains" scenario.

---

## M9 — Opponent modeling  *(target: month 6)*

The same RMP team plays differently across matches. M9 learns each opponent
team's *tendencies* and uses them to predict next moves.

### Themes

**Per-team behaviour profile.** Keyed by `team_signature` (sorted classes + names). Records: trinket-priority (which CC do they break — Fear, HoJ, Sheep?), Ice Block threshold (% HP at which they typically pop), kick patterns (do they kick first heal or save for burst?), CC-target tendencies (do they sap the priest or the druid?).

**Bayesian-light update.** After each observed event, update the team's profile (Beta priors over each binary tendency). After ~20 matches against the same team, the profile is opinionated; before that, it falls back to comp defaults.

**Profile-driven callouts.** Engine consults the profile before standard recommendations: "this team trinkets Fear, save Tremor for HoJ"; "this mage usually Ice Blocks at 25% — burst now"; "this priest kicks the third heal — fake your second".

**Persistent across sessions.** Stored in SavedVariables; survives `/reload` and client restart. Sanitisation: profiles keyed by team signature, not character names, so no personally-identifying data persists.

**Tests.** Bayesian update logic verified with synthetic event streams. Profile-driven callout suppression verified end-to-end.

### Deliverable
New `OpponentProfile.lua` module. After a meaningful sample size, the
engine's recommendations against a familiar team noticeably diverge from
its first-encounter recommendations. The trace log (M3 #50) shows the
profile contribution to each decision.

---

## M10 — Multi-step planning + counterfactual analysis  *(target: month 8)*

### Themes

**N-tick lookahead.** Replace the greedy single-tick scoring with a 3-tick
expectimax search. At each ply, the engine considers its top-K candidate
actions (kill priority shift, peel call, CC chain start) and the
opponent's most likely response (based on M9 profiles). Picks the action
maximising expected kill-window value.

**Bounded branching.** Top-3 actions × top-3 opponent responses × 3 plies
= 81 leaves max per Evaluate. Profiled against the M6 performance budget;
the budget is raised to 3ms average and 10ms 99p with caching.

**Counterfactual review.** A new `/acc whatif` slash command takes the
last `/acc record` log and replays it with one variable changed ("what if
we'd swapped to the mage at t=12 instead of staying on the priest"). Prints
the predicted outcome divergence. Powered by the same engine, just driven
backward from the recording.

**Pattern primitives.** Engine recognises recurring kill setups
(*"RMP cheap-blind chain detected, 90% probability they're going for our
mage in next 4s — call peel"*) using simple sequence-matching against
the M9 profile + the live CLEU stream.

**Tests.** Lookahead asserted to pick the better action on hand-crafted
state. Counterfactual command produces a coherent divergence report.

### Deliverable
The engine reads the future, not just the present. Visible in trace logs:
each `Evaluate` records its considered alternatives and why it chose the
top one.

---

## M11 — Risk gating + rating awareness  *(target: month 10)*

Currently the engine plays the same way at 1500 rating as at 2400.
Real arena requires risk gating: in a 2700 game you don't waste Bloodlust on
a 30% kill chance; in a 1400 game you can be greedy.

### Themes

**Rating-aware aggression.** New SavedVar `db.strategy.ratingAggression`
defaulting to `"auto"`. When auto, the engine reads
`GetPersonalRatedInfo()` (or equivalent in TBC API) and tunes:

- Risk gates for burst (won't recommend Bloodlust below 50% kill probability when rated > 2200)
- Conservative defensive triggers (DEFEND at higher healer HP threshold when rating high)
- Mana conservation (drop low_mana_healer threshold from 25% to 15% in high-rated)

**Kill-probability model.** Each kill target gets a `killProb` estimate
based on HP, defensive availability, our burst window, healer mana, and DR
state. Calibrated against the M9 opponent profile.

**Burst gate.** `IsBurstAllowed()` already exists (from M1). M11 expands
it: it now requires `killProb > threshold(rating)` AND chain availability
AND no incoming DEFEND-level pressure. Multiple gates with explicit
reason codes ("burst blocked: kill probability 28% < 50% threshold for
2350 rating").

**Tests.** Same state evaluated at low/high rating produces meaningfully
different recommendations. Kill probability calibrated against M9 profiles
in synthetic match logs.

### Deliverable
At low rating the engine is greedy and learns aggressively; at high
rating it conserves and waits. The recommendation reason explicitly
references rating in its risk-gate decisions.

---

## M12 — Calibration, benchmark, v2.0 release  *(target: month 12)*

The final milestone is honesty: measure what we built.

### Themes

**Benchmark suite.** `Tests/Benchmark_spec.lua` defines ~20 canonical
match scenarios (replayable via M6 #53). For each, hand-labels the
"correct" recommendation per tick. The benchmark reports the engine's
agreement rate with the labels. Lands in CI as a non-gating report.

**Calibration audit.** The engine's `confidence` field gets calibrated:
when we say "70% confidence", is that empirically a 70% kill rate? A new
Tests/Calibration_spec.lua compares predicted vs realised across 100
synthetic matches generated from the M9 profiles. Bias correction applied
to the engine's confidence emit.

**Release polish.** The deferred 1.0 UI work (compact mode, options panel
rewrite, voice callouts, app icon) lands together with v2.0. Each was
deferred from M4 because UI shape needed live eyeballs; now bundled into
a coherent v2.0 design pass.

**Tagged stable.** `v2.0.0` pushed. CurseForge / Wago descriptions
updated. README rewritten around the new "your coach learns your
opponents" pitch.

### Deliverable
v2.0 ships with a measurable claim: "agrees with hand-labelled correct
calls on ~85% of ticks in our benchmark suite, vs ~60% for v1.x".

---

## Operating principles (v2 additions to the v1 set)

The v1 principles still hold (no automation, capability-first, 99% test
floor, opt-in telemetry, backward-compatible SavedVariables). v2 adds:

7. **Models must be auditable.** Every recommendation includes a
   human-readable trace of which signals contributed (extending the M3 #50
   trace log). No black-box outputs.

8. **Calibration over confidence.** When the engine reports a probability,
   it should be empirically accurate (within 10%) on the benchmark suite.
   Better to report "I don't know" than overconfident.

9. **Learn locally, not globally.** Opponent modelling is per-user; no
   federated learning, no central model. M5 #29 telemetry, if enabled, is
   for aggregate meta dashboards only, never for training individual users'
   profiles.

10. **Backward compatibility for SavedVars stays inviolable.** Opponent
    profiles from v2.0 must still load on v2.5; bias corrections to
    confidence calibration must not throw away old profiles.

---

## What we are *not* doing (explicit non-goals)

- **No automated casting / targeting**, ever. Same as v1.
- **No machine learning models shipped with the addon.** The opponent
  modelling in M9 uses transparent Bayesian updates, not weights from a
  black-box training run. Anyone reading the SavedVariables can see why
  the engine thinks what it thinks.
- **No multi-game support in v2.** Wrath / RBG / world PvP stay deferred.
  v2 is about being *better* at TBC arena, not broader.
- **No telemetry without explicit opt-in.** Per-user profiles are local-only
  by default.

---

## Tracking + lane structure

Each milestone gets a GitHub milestone; each theme becomes a tracker
issue with the bullet-point checklist as task lists. Labels stay the same
shape as v1 (`milestone:M7..M12`, `area:capability|quality|ship`).

```
M7 spec-aware comp     -> M8 chain planning   -> M10 lookahead   -> M12 calibration
                       \-> M9 opponent profile-+                 /
                                            M11 risk gating  ----/
```

M9 (opponent modelling) is the keystone — M10 lookahead and M11 risk
gating both lean on the profile data it produces. If M9 slips, downstream
milestones slip with it.

---

## What shipped after M12

This v2 roadmap scoped M7-M12 as v2.0. The full set landed in v2.0.0 (May 2026). Everything below was unscheduled at the time the roadmap was written — added in response to user feedback during the v2.1-v2.3 patch cycle. Tagged with version + CHANGELOG anchor for cross-reference.

### v2.1 — Wild PvP (BG / world / duels) · M13-M16

Engine was effectively dormant outside arena (`Core:RefreshArenaEnemies` hardcoded to `arenaN` unit IDs). v2.1 extended it.

- **v2.1.0**: `Core:DetectPvPContext()` returns `arena|bg|world|world_idle|none`; non-arena enemy discovery via nameplate iteration + CLEU stubs; BG-specific scoring branch (flag-carrier priority +200, low-HP straggler boost, class-prior tier for PUG'd rosters); world-PvP single-target focus; `DUEL_REQUESTED` auto-engages.
- **v2.1.1**: `/acc test bg` + `/acc test world` walkthroughs; AV-scale 40-enemy perf test.
- **v2.1.2**: nameplate event subscription so BG enemies populate even when no combat events fire.
- **v2.1.3**: DEFEND / RESET no longer show a target name; reasonKey localisation.

### v2.1.4-v2.1.6 — Publishing pipeline + audio + HUD

- **v2.1.4**: TBC Anniversary support (`Interface: 20505`). BigWigs packager pipeline fix (.git symlink + `-t ArenaCoachTBC`).
- **v2.1.5**: CurseForge auto-upload wired (`X-Curse-Project-ID: 1552792`).
- **v2.1.6**: bigger 32pt mode label, target stats row (HP%, kill prob %, BURST READY), **audio cues fix** — pre-v2.1.6 the `Sound/Voice/*.ogg` paths were never bundled, so every audio call silently failed; v2.1.6 switched to numeric SoundKit IDs that ship with the client. Engine emits `primaryTargetHp` + `killProb` on the rec.

### v2.2 — Eyes Up (visual layers + lifecycle)

- **v2.2.0**: `ScreenEdgeGlow.lua` (mode-coloured pulsing band around the screen edges) + `Nameplate.lua` (red border on KILL target, orange on SWAP). Both PvP-context-gated, toggleable via `/acc glow` / `/acc nameplate`.
- **v2.2.1**: removed the two cooldown icon rows at the bottom of the frame — they had been displayed since v1 but `UI:UpdateIcons` was only ever called from tests, never production. Dead UI. Frame height shrank 170 → 110 px. `db.frame.compactMode` toggle dropped (it gated the now-removed icon rows).
- **v2.2.5**: **city-lag fix** — `onNameplateChange` was re-evaluating the engine on every nameplate change while PvP-flagged in `world_idle`. In Stormwind that's hundreds of events per second with nothing useful to recommend. Gate now only triggers Evaluate when context is `bg` or `world`. Frame auto-hides outside PvP contexts. `/acc off` / `/acc on` master switch (aliases `/acc disable` / `/acc enable`) flips `db.enabled` and persists across `/reload`.
- **v2.2.6**: removed the WeakAura paste-string export pipeline. After 6 patches chasing why our generated `!WA:2!...` strings failed to import, root cause confirmed: the `node-weakauras-parser` library produces strings that decode correctly but fail WeakAuras' import-validator byte check (even when re-encoding a known-working Wago WA byte-identical). `docs/weakaura-pack.md` retains the trigger Lua snippets users paste into a hand-built WeakAura; bridge API (`_G.ArenaCoachTBC` + `WeakAuras.ScanEvents("ACC_RECOMMENDATION", rec)`) unchanged.

### v2.3.0 — Quality release

- Bug fix: `/acc test` was only painting text, not the v2.2.0 visual layers — `_forceShow` bypassed the v2.2.5 auto-hide gate but the visual-layer gate still required `inPvP`. Now `_forceShow` short-circuits both.
- Dead code: deleted `makeIcon()` + `spellIcon()` from `UI.lua` (38 lines orphaned since v2.2.1).
- Docs + roadmap refresh (this commit).

### Themes implicit across v2.1-v2.3

- **Calibration over confidence** held — every "the engine should learn X" feature added since M12 went through the same Beta-prior + per-team profile machinery rather than a new modelling layer.
- **No automation** held — no new code can set raid markers, target enemies, or send chat.
- **Local-only learning** held — `db.profiles` and `db.classPriors` never leave the SavedVariables file. No cloud telemetry shipped.
- **99% coverage** held — 608 tests as of v2.3.0 (up from 538 at v2.0).
