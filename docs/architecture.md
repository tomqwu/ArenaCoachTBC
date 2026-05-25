# ArenaCoachTBC architecture (v2.0)

This document explains the engine modules introduced across the M7-M12
milestones and how data flows through them at evaluation time.

## High level

The addon is split along a **WoW-coupled vs. pure** axis. WoW events
arrive at `Core.lua`; pure modules in the engine boundary take a
plain `state` table and return a `recommendation` table. Headless
tests drive every pure module without touching a WoW API.

```
        +--------------------+
WoW --> | Core.lua (CLEU)    | -- builds state --> StrategyEngine:Evaluate(state)
        | Trackers           |
        +--------------------+
              |
              v
        +--------------------+        rec.chain / rec.burstDecision /
        |  Pure engine       | -----> rec.profileContrib /
        |  StrategyEngine    |        rec.compConfidence / ...
        +--------------------+
              |       \
              v        \
        Chain.lua       OpponentProfile.lua
        Patterns.lua    Lookahead.lua
                         Sounds.lua (UI side)
```

## Modules added in v2

### Chain.lua (M8)
A `Chain` is an ordered list of CC links:

```lua
{ spellID, target, category, by, castTimeS? }
```

- `Chain:Build(links)` — wraps a list.
- `Chain:Validate(chain) -> (ok, reason)` — rejects on `DR_immune` /
  `cd_pending` / `empty`. Within-chain DR accumulation is tracked so
  three STUNs on the same target correctly walks `1.0 -> 0.5 -> 0.25`.
- `Chain:ExpectedProb(chain) -> [0..1]` — product of effective DR
  multipliers.
- `Chain:ScoreAll(chains, opts)` — ranks chains by `ExpectedProb`
  descending; `opts.topK` clips the output.

`Strategies:InstantiateChains(comp, primaryGUID, secondaryGUID, enemies)`
resolves the comp catalog's chain templates (with `byClass` /
`targetRole` placeholders) into concrete chains with real GUIDs.

### OpponentProfile.lua (M9 — the keystone)
Per-opponent-team behavioural profiles keyed by team signature:

```
<sorted_classes>#<djb2_hash_of_sorted_names>
```

Names are **never** persisted — only the hash. Each profile tracks
four binary tendencies as `Beta(α, β)` priors:

- `trinketsFear`
- `iceBlockBelow30`
- `kicksFirstHeal`
- `sapsPriest`

API:
- `OP:Signature(enemies)`
- `OP:Get(sig, db)`, `OP:Update(sig, event, db)`, `OP:Forget(sig, db)`
- `OP:UpdateBinary(profile, key, observed)`
- `OP:Estimate(profile, key) -> {mean, low, high, n}` (Beta 95% CI)
- `OP:EstimateOrDefault(profile, key, compDefault)` — comp default
  below `MIN_SAMPLES_FOR_OPINION` (5)

### Lookahead.lua (M10)
Re-ranks the top-K chains from `Chain:ScoreAll` by *expected value*
over opponent responses (drawn from `OpponentProfile` when present,
otherwise 50/50). Bounded branching: top-3 × top-3 × 3 plies = 81
leaves max default. Per-call response-distribution cache keeps the
inner loop cheap (single call to `EnumerateResponses` reused across
candidate chains).

### Patterns.lua (M10)
Sequence-of-cast detector for canonical kill setups. Five seeded
patterns (`RMP_CHEAP_BLIND`, `SHATTER_NOVA_SHEEP`, `FEAR_INTO_POLY`,
`HUNTER_TRAP_SCATTER`, `HOJ_INTO_INTERCEPT`). `Core.onCLEU` feeds
`Patterns:Observe(spellID, ts)` on `SPELL_CAST_SUCCESS`. Engine
consumes via `Patterns:GetMatches(threshold)` and emits
`CALL_PATTERN_<id>` for each match. Half-matches expire after a TTL.

### KillProb (M11 — lives inside StrategyEngine.lua)
`SE:KillProb(target, state) -> { prob, components }`. Components:

- `hp` (1 − hp/100, weight 1.0)
- `defensiveDown` (+0.10 if trinket used)
- `immunityAbsent` (+0.10 if no Ice Block / Divine Shield / BoP)
- `burstReady` (+0.05 if HoJ up)
- `healerLowMana` (+0.10 if their healer <30% mana)
- `drClean` (+0.05 if STUN DR fresh)

Sum clamped to `[0..1]`. Weights exposed via `SE.KILL_PROB_WEIGHTS`.
`WeakAuraBridge.GetKillProb(guid)` / `GetKillProbBreakdown(guid)`.

### BurstDecision (M11 — lives inside StrategyEngine.lua)
`SE:BurstDecision(state, target, chain) -> { allowed, blockedBy, gates }`
with four named gates: `kill_prob` (threshold scales with
aggression — greedy 0.35, balanced 0.45, safe 0.55), `chain_ready`,
`incoming_pressure`, `rating_aware`. Engine populates
`rec.burstDecision` on KILL recommendations.

### Rating-aware aggression (M11 — Core)
`db.strategy.ratingAggression = "auto"` reads bracket rating via
`GetPersonalRatedInfo()` and derives `state.aggression`:
- `< 1800` → greedy
- `1800–2200` → balanced
- `> 2200` → safe

Three thresholds shift on this axis: SWAP score-gap (0/10/20),
defensive HP gate (30/40/50%), and LOW_MANA_PUSH (30/25/20).

### Sounds.lua (M12)
Maps callout keys to PlaySoundFile paths. UI:Apply fires a one-shot
cue per new top callout (gated by `db.alerts.sound`).

## Recommendation shape (v2.0)

The engine's `Evaluate` returns roughly this:

```lua
{
  mode               = "OPEN|KILL|SWAP|DEFEND|RESET",
  primaryTarget      = guid,
  primaryTargetClass = "PRIEST",
  secondaryTarget    = guid,
  confidence         = 0..1,   -- target-score-spread confidence
  reason             = "PRIEST [role_healer(25), ...] | RMP class-guessed (0.33)",
  callouts           = { "CALL_HOJ_KILL", "CALL_PATTERN_RMP_CHEAP_BLIND", ... },
  priority           = "URGENT|HIGH|MEDIUM|LOW",
  comp               = "RMP_DISC_3V3",
  compLabel          = "RMP (confirmed Disc Priest)",
  compConfidence     = 0..1,   -- comp-match confidence
  compSpecConfirmed  = bool,
  ownArchetype       = "MELEE_CLEAVE",
  burstAllowed       = bool,
  burstDecision      = { allowed, blockedBy, gates = {kill_prob, chain_ready, ...} },
  chain              = { id, label, labelKey, steps, links, expectedProb, expectedValue },
  profileContrib     = "trinketsFear=0.82,kicksFirstHeal=0.71",
  opponentSignature  = "<class_set>#<hash>",
  aggression         = "greedy|balanced|safe",
  rating             = number,
}
```

## Where to add things (v2 quick map)

| Adding... | Goes in... |
|---|---|
| A new tendency | `OpponentProfile.TENDENCIES` + a callout gate in `buildCallouts` |
| A new chain template | `Strategies.comps[i].chains` + a `CHAIN_<id>` locale key |
| A new pattern | `Patterns.defs` + a `CALL_PATTERN_<id>` locale key |
| A new burst gate | `StrategyEngine:BurstDecision`'s gate table |
| A new killProb component | `SE.KILL_PROB_WEIGHTS` + the corresponding contribution in `SE:KillProb` |
| A new aggression threshold | Look up via `state.aggression` in the engine; greedy / balanced / safe values |

## Testing discipline

- Pure modules drive headlessly. No WoW API calls inside the engine
  boundary or its supporting pure modules (Chain, Patterns,
  OpponentProfile, Lookahead).
- Trace inspection: `/acc trace dump` shows mode, comp, callouts,
  `profileContrib`, etc. per evaluation. Use this to debug live
  decisions.
- Counterfactual replay: `/acc whatif skip <i>` replays the current
  `/acc record` log with one event removed and reports divergence.
- Benchmark: `Tests/Benchmark_spec.lua` runs 21 canonical scenarios
  and prints `[BENCHMARK]` agreement per scenario. Soft 50% floor;
  current baseline 81%.
- Calibration: `Tests/Calibration_spec.lua` runs 100 deterministic
  synthetic states and prints per-decile predicted-vs-truth gap.
  Max per-bin error 0.10 today (budget 0.20).
