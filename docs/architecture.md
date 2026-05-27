# ArenaCoachTBC architecture (v2.2) / 架构 (v2.2)

This document explains the engine modules introduced across the M7–M12 milestones (v2.0) plus the visual + lifecycle additions in v2.1 (BG / world / duel support) and v2.2 (peripheral-vision visual layers, auto-hide gate, master switch).

本文档说明 M7–M12 各里程碑（v2.0）引入的引擎模块，以及 v2.1（战场 / 户外 / 决斗支持）与 v2.2（视觉外圈层、自动隐藏门禁、主开关）的新增。

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
                         Sounds.lua  (UI side)
                         ScreenEdgeGlow.lua  (UI side, v2.2.0)
                         Nameplate.lua       (UI side, v2.2.0)
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

`SE:BurstDecision(state, target, chain) -> { allowed, blockedBy, gates }` is the single source of truth for `BURST_NOW`. It includes target/setup prerequisite gates (`target_vulnerable`, `ms_active`, `windfury`, `melee_uptime`), the calibrated `kill_prob` gate (threshold scales with aggression: greedy 0.35, balanced 0.45, safe 0.55), `chain_ready`, `incoming_pressure`, and `rating_aware`. `chain_ready` is advisory by default so BG/world fights and sparse arena catalog entries can still recommend a clean burst window; set `db.strategy.requireChainForBurst = true` to make a positive chain mandatory. Engine populates `rec.burstDecision` and mirrors the first failing gate into `rec.burstBlockedBy` (`target_immune`, `no_ms`, `no_windfury`, `melee_root`, `kill_prob`, `chain_ready`, etc.).

爆发判断现在统一在 `BurstDecision` 内完成：目标是否免疫、MS 是否在目标上、风怒是否就位、近战是否能贴住、击杀概率、控制链、敌方压力与分数侵略性都会进入同一个 `gates` 表。默认情况下 `chain_ready` 只做审计提示；只有 `db.strategy.requireChainForBurst = true` 时才会阻止爆发。

### Rating-aware aggression (M11 — Core / 分数感知侵略性)

`db.strategy.ratingAggression = "auto"` reads bracket rating via `GetPersonalRatedInfo()` and derives `state.aggression`:

`db.strategy.ratingAggression = "auto"` 通过 `GetPersonalRatedInfo()` 读取战场分数并派生 `state.aggression`：

- `< 1800` → greedy / 激进
- `1800–2200` → balanced / 平衡
- `> 2200` → safe / 保守

Three thresholds shift on this axis: SWAP score-gap (0/10/20), defensive HP gate (30/40/50%), and LOW_MANA_PUSH (30/25/20).

此轴上有 3 个阈值会变化：SWAP 分差阈（0/10/20）、防御血量门禁（30/40/50%）、低蓝压上阈（30/25/20）。

### Sounds.lua (M12, audio fix v2.1.6)

Maps callout keys + mode names to numeric SoundKit IDs that ship with the WoW client itself (RaidWarning 8959, RaidBossEmote 8458, PvPVictory 12867, queue ding 8454). `UI:Apply` fires a one-shot cue per new top callout AND per mode transition (gated by `db.alerts.sound`, arena-only).

Pre-v2.1.6 this module referenced `Sound/Voice/*.ogg` paths that were never bundled in the addon zip, so every `PlaySoundFile` invocation silently failed and audio cues did not work in any earlier release.

将提示键和模式名映射到 WoW 客户端内置的数字 SoundKit ID。`UI:Apply` 在新顶层提示和模式切换时触发一次性音效（受 `db.alerts.sound` 控制，仅竞技场触发）。v2.1.6 前引用的 `Sound/Voice/*.ogg` 路径并未打包进插件，所以历史版本的音效从未真正发出。

### UI.lua (integrated prototype-A board, v2.8.26)

The built-in HUD follows the agreed prototype-A layout as one compact texture-backed board. The board defaults to 540x212, clamps no smaller than 500x196, and keeps the left status stack, center action panel, bottom player-info/assignment strip, and right cue rail together when dragged or resized.

v2.8.26 adopts the **Obsidian Signal** visual language: warmed obsidian fields, burnished brass rules, bone-white primary data, cyan intelligence accents, and crimson reserved for committed/urgent signal. The metadata strip now carries `OBSIDIAN / SIGNAL`, and the shell adds compact surveyor-style corner reticles so the board reads as one machined tactical instrument rather than loose game text.

v2.8.25 turns the bottom assignment row into fixed 1/2/3/5 cards, chosen from current player actions, alive friendlies, or the bracket. This keeps 2v2, 3v3, and 5v5 jobs in stable small compartments instead of rendering a paragraph inside the board.

v2.8.24 takes the tactical-console reference seriously without making the addon a full-screen dashboard: it adds a top signal strip, small ruler ticks, console-style section headers, subtle slot backgrounds, and a target health-pool bar in the center instrument. The center action panel also has a slim mode-coloured accent bar so KILL/SWAP/DEFEND state is visible without screen flashing.

v2.8.23 reshaped the board toward the original cockpit sketch: the left and right rails span the board height, the center column carries the large action call, and the player assignments sit directly under that action call instead of becoming a full-width table. Focus, cue, and assignment rows now use compact tags and target-coloured text so they read as scan rows instead of plain paragraph labels.

v2.8.22 added the text safety rules that still apply: visible detail is capped by the current board height so center copy, cue lines, and assignment lines cannot collide. Resizing the board taller/wider allows the full five-player review layout without overlap. Waiting/pre-gate states render structural placeholders in all zones so the HUD does not collapse back into floating text before live combat data exists. `/acc unlock` drags and resizes the integrated board; `/acc lock` locks it.

内置 HUD 现在按 A 方案做成一个紧凑的贴图背景面板。左侧状态栈、中央行动区、底部分工条、右侧提示轨会一起移动/缩放；默认 540x212，最小 500x196。v2.8.26 采用 Obsidian Signal 视觉语言：暖黑曜石底色、黄铜细线、骨白数据、青色信息强调，以及克制使用的深红信号色；元信息条显示 `OBSIDIAN / SIGNAL`，外框增加测绘式角标，让整体像一个战术仪表。v2.8.25 的底部分工条会按当前动作、存活友方或竞技场人数切成 1/2/3/5 个固定小格，2v2、3v3、5v5 都有稳定位置。v2.8.24 加入顶部信号条、标尺刻度、控制台式分区标题、行背景，以及中央目标血量条，让它更像战术仪表盘而不是普通表格。文字仍会按当前面板高度裁剪，避免互相覆盖；需要完整五人复盘时可把面板拉高/拉宽。`/acc unlock` 拖动并缩放整块面板，`/acc lock` 锁定。

### ScreenEdgeGlow.lua (v2.2.0, softened in v2.8.2)

A full-screen frame with four very thin edge lines (top / bottom / left / right). Each line's color follows the current recommendation mode (KILL=red, SWAP=orange, DEFEND=blue, OPEN=yellow). v2.8.2 removed the old pulsing 96px band; the cue is now 18px, low-alpha, and static so it does not flash around the screen. `RESET` and `nil` mode hide the frame so between-fight downtime is dark. Toggle via `db.alerts.edgeGlow` / `/acc glow on|off`. Driven from `UI:Apply` after the recommendation is rendered.

全屏框、四条很细的边缘线（上/下/左/右）。每条线颜色随当前模式（KILL 红、SWAP 橙、DEFEND 蓝、OPEN 黄）。v2.8.2 移除了旧的 96px 脉冲边带；现在是 18px、低透明度、静态显示，不会在屏幕周围闪烁。`RESET` 和 `nil` 隐藏。通过 `db.alerts.edgeGlow` / `/acc glow on|off` 控制。

### Nameplate.lua (v2.2.0)

Iterates `nameplate1..nameplate40` to resolve the current frame for a given enemy GUID, then attaches a child overlay frame with four colored bands forming a border. The kill target gets a red border (`KILL` color); the swap candidate gets an orange one (`SWAP`). Overlays are cleared and re-painted on every `UI:Apply` so target changes update cleanly. We never modify the native nameplate's health bar / cast bar / name text, so Plater / KuiNameplates / TidyPlates coexist cleanly. Toggle via `db.alerts.nameplate` / `/acc nameplate on|off`.

遍历 `nameplate1..nameplate40` 找到指定敌方 GUID 对应的当前铭牌，挂上一个含四条彩带的子覆盖框。击杀目标得红色边框，换火候选得橙色。`UI:Apply` 每次都清空重绘。从不修改铭牌原生的血条/施法条/姓名，与 Plater/KuiNameplates/TidyPlates 共存。

### Non-arena discovery (Unreleased)

BG/world enemy state is intentionally opportunistic. `Core:RefreshEnemiesNonArena()` scans all `nameplate1..nameplate40` slots without stopping at the first gap because nameplate unit IDs can be sparse. CLEU fallback stubs are only created when a hostile source damages the player or a known friendly, which avoids phantom enemies from unrelated world combat nearby. World PvP defensive mode uses healer-capable friendlies when present and falls back to the lowest alive friendly in solo play, so a low-HP non-healer player still gets `DEFEND` instead of a forced `KILL`.

### Auto-hide gate + master switch (v2.2.5)

`UI:Apply` checks `Core.state.pvpContext` and hides the frame + thin edge cue + nameplate overlays when the context is explicitly `"none"` or `"world_idle"`. This stops the engine from drawing a stale rec on screen between fights and stops `onNameplateChange` from re-evaluating in cities (where the firehose of nameplate add/remove events was a major frame-rate hit before v2.2.5).

v2.8.3 adds a stale-recommendation fade timer on the HUD frame; v2.8.11 tightens it. Each fresh `UI:Apply` resets opacity to 1.0. If no fresh recommendation refreshes the frame after 2.5 seconds, opacity fades over 1.5 seconds; at the end the frame hides and clears nameplate / edge cues. This handles the "situation out of sync" case without flashing or forcing the user to manually toggle the frame.

`/acc off` and `/acc on` (aliases `/acc disable` / `/acc enable`) toggle `db.enabled`. When off, `Core:Evaluate` short-circuits at the top — no event handlers, no engine work, all visual layers hidden. Persists across `/reload`. The default `/acc test` path runs the simulator with `state.simulatorActive` and `pvpContext="arena"` so the engine scorer can be exercised outside a queue. Its timed `C_Timer.After` callbacks use a simulator-owned tick that calls `StrategyEngine:Evaluate`, sets `_forceShow`, applies the HUD, and publishes the WeakAura payload; this keeps the out-of-arena replay visible even though the normal live context gate would hide non-PvP UI. The visual-only `/acc test hud` demo bypasses both gates via a per-beat `recommendation._forceShow` flag so the walk-through paints the prototype-A modules outside arena.

`UI:Apply` 检查 `Core.state.pvpContext`，当上下文为 `"none"` 或 `"world_idle"` 时隐藏所有视觉层。`/acc off` / `/acc on` 切换 `db.enabled`，全局开关。默认 `/acc test` 使用 `state.simulatorActive` 与 `pvpContext="arena"` 在不排队的情况下跑真实引擎/UI 链路；`/acc test hud` 视觉演示则通过 `_forceShow` 标志绕过这些门禁。

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
  burstDecision      = { allowed, blockedBy, gates = {target_vulnerable, ms_active, windfury, melee_uptime, kill_prob, chain_ready, ...} },
  chain              = { id, label, labelKey, steps, links, expectedProb, expectedValue },
  primaryTargetHp    = 0..1,
  killProb           = 0..1,
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
