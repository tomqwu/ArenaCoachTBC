# ArenaCoachTBC architecture (v2.0) / 架构 (v2.0)

This document explains the engine modules introduced across the M7–M12 milestones and how data flows through them at evaluation time.

本文档说明 M7–M12 各里程碑引入的引擎模块，以及评估时数据如何在它们之间流转。

---

## High level / 总体结构

The addon is split along a **WoW-coupled vs. pure** axis. WoW events arrive at `Core.lua`; pure modules in the engine boundary take a plain `state` table and return a `recommendation` table. Headless tests drive every pure module without touching a WoW API.

插件沿 **WoW 耦合 vs. 纯净** 一轴划分。WoW 事件进入 `Core.lua`；引擎边界内的纯净模块接收 `state` 表并返回 `recommendation` 表。无头测试驱动每个纯净模块，不触及任何 WoW API。

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

---

## Modules added in v2 / v2 新增模块

### Chain.lua (M8)

A `Chain` is an ordered list of CC links / `Chain` 是有序的 CC 链表：

```lua
{ spellID, target, category, by, castTimeS? }
```

- `Chain:Build(links)` — wraps a list. / 包装链表。
- `Chain:Validate(chain) -> (ok, reason)` — rejects on `DR_immune` / `cd_pending` / `empty`. Within-chain DR accumulation is tracked so three STUNs on the same target correctly walks `1.0 → 0.5 → 0.25`. / 在 `DR_immune` / `cd_pending` / `empty` 时拒绝。链内 DR 累积被追踪，同一目标的三次 STUN 会正确按 `1.0 → 0.5 → 0.25` 衰减。
- `Chain:ExpectedProb(chain) -> [0..1]` — product of effective DR multipliers. / 有效 DR 系数的乘积。
- `Chain:ScoreAll(chains, opts)` — ranks chains by `ExpectedProb` descending; `opts.topK` clips the output. / 按 `ExpectedProb` 降序排序；`opts.topK` 限制输出数。

`Strategies:InstantiateChains(comp, primaryGUID, secondaryGUID, enemies)` resolves the comp catalog's chain templates (with `byClass` / `targetRole` placeholders) into concrete chains with real GUIDs.

`Strategies:InstantiateChains` 将阵容目录中的链模板（带 `byClass` / `targetRole` 占位符）解析为带真实 GUID 的具体链。

### OpponentProfile.lua (M9 — the keystone / 关键模块)

Per-opponent-team behavioural profiles keyed by team signature / 按队伍签名索引的对手行为档案：

```
<sorted_classes>#<djb2_hash_of_sorted_names>
```

Names are **never** persisted — only the hash. Each profile tracks four binary tendencies as `Beta(α, β)` priors:

玩家姓名**永不**持久化——只存哈希。每个档案以 `Beta(α, β)` 先验追踪四个二元习惯：

- `trinketsFear` — trinket on Fear / 被恐惧时使用饰品
- `iceBlockBelow30` — Ice Block at HP <30% / 30% 血量冰块
- `kicksFirstHeal` — kicks the first heal / 打断第一个治疗
- `sapsPriest` — saps the priest / 闷棍牧师

API:
- `OP:Signature(enemies)`
- `OP:Get(sig, db)`, `OP:Update(sig, event, db)`, `OP:Forget(sig, db)`
- `OP:UpdateBinary(profile, key, observed)`
- `OP:Estimate(profile, key) -> {mean, low, high, n}` (Beta 95% CI / 95% 置信区间)
- `OP:EstimateOrDefault(profile, key, compDefault)` — falls back to `compDefault` below `MIN_SAMPLES_FOR_OPINION` (5) / 样本数低于 5 时退回阵容默认值

### Lookahead.lua (M10)

Re-ranks the top-K chains from `Chain:ScoreAll` by *expected value* over opponent responses (drawn from `OpponentProfile` when present, otherwise 50/50). Bounded branching: top-3 × top-3 × 3 plies = 81 leaves max default. Per-call response-distribution cache keeps the inner loop cheap (single call to `EnumerateResponses` reused across candidate chains).

基于对手反应的*期望值*重新排序 `Chain:ScoreAll` 的前 K 个链（有 `OpponentProfile` 时取之，否则 50/50）。有界分支：默认 top-3 × top-3 × 3 层 = 最多 81 个叶。单次调用的响应分布缓存让内层循环开销低（`EnumerateResponses` 单次调用在所有候选链间复用）。

### Patterns.lua (M10)

Sequence-of-cast detector for canonical kill setups. Five seeded patterns: `RMP_CHEAP_BLIND`, `SHATTER_NOVA_SHEEP`, `FEAR_INTO_POLY`, `HUNTER_TRAP_SCATTER`, `HOJ_INTO_INTERCEPT`. `Core.onCLEU` feeds `Patterns:Observe(spellID, ts)` on `SPELL_CAST_SUCCESS`. Engine consumes via `Patterns:GetMatches(threshold)` and emits `CALL_PATTERN_<id>` for each match. Half-matches expire after a TTL.

针对标准击杀套路的序列识别。5 个内置模式：`RMP_CHEAP_BLIND`、`SHATTER_NOVA_SHEEP`、`FEAR_INTO_POLY`、`HUNTER_TRAP_SCATTER`、`HOJ_INTO_INTERCEPT`。`Core.onCLEU` 在 `SPELL_CAST_SUCCESS` 时调用 `Patterns:Observe(spellID, ts)` 喂入。引擎通过 `Patterns:GetMatches(threshold)` 消费并为每个匹配发出 `CALL_PATTERN_<id>`。半匹配在 TTL 后过期。

### KillProb (M11 — lives inside StrategyEngine.lua / 在 StrategyEngine.lua 内)

`SE:KillProb(target, state) -> { prob, components }`. Components / 组成项:

- `hp` (1 − hp/100, weight 1.0)
- `defensiveDown` (+0.10 if trinket used / 饰品已使用)
- `immunityAbsent` (+0.10 if no Ice Block / Divine Shield / BoP)
- `burstReady` (+0.05 if HoJ up / 制裁就绪)
- `healerLowMana` (+0.10 if their healer <30% mana / 治疗蓝量 <30%)
- `drClean` (+0.05 if STUN DR fresh / 眩晕 DR 干净)

Sum clamped to `[0..1]`. Weights exposed via `SE.KILL_PROB_WEIGHTS`. WeakAuraBridge exposes `GetKillProb(guid)` / `GetKillProbBreakdown(guid)`.

求和并夹紧到 `[0..1]`。权重通过 `SE.KILL_PROB_WEIGHTS` 暴露。WeakAuraBridge 通过 `GetKillProb(guid)` / `GetKillProbBreakdown(guid)` 暴露。

### BurstDecision (M11)

`SE:BurstDecision(state, target, chain) -> { allowed, blockedBy, gates }` with four named gates: `kill_prob` (threshold scales with aggression — greedy 0.35, balanced 0.45, safe 0.55), `chain_ready`, `incoming_pressure`, `rating_aware`. Engine populates `rec.burstDecision` on KILL recommendations.

四个命名门禁：`kill_prob`（阈值随侵略性变化——greedy 0.35、balanced 0.45、safe 0.55）、`chain_ready`、`incoming_pressure`、`rating_aware`。引擎在 KILL 建议上填充 `rec.burstDecision`。

### Rating-aware aggression (M11 — Core / 分数感知侵略性)

`db.strategy.ratingAggression = "auto"` reads bracket rating via `GetPersonalRatedInfo()` and derives `state.aggression`:

`db.strategy.ratingAggression = "auto"` 通过 `GetPersonalRatedInfo()` 读取战场分数并派生 `state.aggression`：

- `< 1800` → greedy / 激进
- `1800–2200` → balanced / 平衡
- `> 2200` → safe / 保守

Three thresholds shift on this axis: SWAP score-gap (0/10/20), defensive HP gate (30/40/50%), and LOW_MANA_PUSH (30/25/20).

此轴上有 3 个阈值会变化：SWAP 分差阈（0/10/20）、防御血量门禁（30/40/50%）、低蓝压上阈（30/25/20）。

### Sounds.lua (M12)

Maps callout keys to PlaySoundFile paths. `UI:Apply` fires a one-shot cue per new top callout (gated by `db.alerts.sound`).

将提示键映射到 PlaySoundFile 路径。`UI:Apply` 在新的顶层提示出现时触发一次性音效（受 `db.alerts.sound` 控制）。

---

## Recommendation shape (v2.0) / 推荐数据结构

The engine's `Evaluate` returns roughly this / 引擎 `Evaluate` 返回大致结构：

```lua
{
  mode               = "OPEN|KILL|SWAP|DEFEND|RESET",
  primaryTarget      = guid,
  primaryTargetClass = "PRIEST",
  secondaryTarget    = guid,
  confidence         = 0..1,   -- target-score-spread confidence
                               -- 目标分差置信度
  reason             = "PRIEST [role_healer(25), ...] | RMP class-guessed (0.33)",
  callouts           = { "CALL_HOJ_KILL", "CALL_PATTERN_RMP_CHEAP_BLIND", ... },
  priority           = "URGENT|HIGH|MEDIUM|LOW",
  comp               = "RMP_DISC_3V3",
  compLabel          = "RMP (confirmed Disc Priest)",
  compConfidence     = 0..1,   -- comp-match confidence / 阵容匹配置信度
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

---

## Where to add things (v2 quick map) / 扩展点速查

| Adding... / 想添加... | Goes in... / 写到... |
|---|---|
| A new tendency / 新习惯 | `OpponentProfile.TENDENCIES` + a callout gate in `buildCallouts` |
| A new chain template / 新链模板 | `Strategies.comps[i].chains` + a `CHAIN_<id>` locale key |
| A new pattern / 新序列模式 | `Patterns.defs` + a `CALL_PATTERN_<id>` locale key |
| A new burst gate / 新爆发门禁 | `StrategyEngine:BurstDecision`'s gate table |
| A new killProb component / 新击杀概率分量 | `SE.KILL_PROB_WEIGHTS` + the contribution in `SE:KillProb` |
| A new aggression threshold / 新侵略性阈值 | Look up via `state.aggression`; greedy / balanced / safe values |

---

## Testing discipline / 测试纪律

- Pure modules drive headlessly. No WoW API calls inside the engine boundary or its supporting pure modules (Chain, Patterns, OpponentProfile, Lookahead).
  纯净模块无头驱动。引擎边界内或其支持的纯净模块（Chain、Patterns、OpponentProfile、Lookahead）禁止调用 WoW API。
- Trace inspection: `/acc trace dump` shows mode, comp, callouts, `profileContrib`, etc. per evaluation. Use this to debug live decisions.
  跟踪查看：`/acc trace dump` 显示每次评估的模式、阵容、提示、`profileContrib` 等。用于调试实时决策。
- Counterfactual replay: `/acc whatif skip <i>` replays the current `/acc record` log with one event removed and reports divergence.
  反事实重放：`/acc whatif skip <i>` 重放当前 `/acc record` 日志并去掉第 i 个事件，报告差异。
- Benchmark: `Tests/Benchmark_spec.lua` runs 21 canonical scenarios and prints `[BENCHMARK]` agreement per scenario. Soft 50% floor; current baseline 81%.
  基准：`Tests/Benchmark_spec.lua` 跑 21 个标准场景，按场景打印 `[BENCHMARK]` 一致率。软 50% 下限；当前基线 81%。
- Calibration: `Tests/Calibration_spec.lua` runs 100 deterministic synthetic states and prints per-decile predicted-vs-truth gap. Max per-bin error 0.10 today (budget 0.20).
  校准：`Tests/Calibration_spec.lua` 跑 100 个确定性合成状态并按分位打印预测与真值差距。当前最大单桶误差 0.10（预算 0.20）。
