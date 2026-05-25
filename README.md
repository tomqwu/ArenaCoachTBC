# ArenaCoachTBC

A real-time arena strategy coach for **World of Warcraft TBC Classic / TBC Anniversary**. Watches the fight, identifies the enemy comp (including spec), picks a kill target, plans CC chains, and emits a recommendation: `OPEN | KILL | SWAP | DEFEND | RESET`.

**魔兽世界 TBC 怀旧服 / TBC 周年服**的实时竞技场战术教练。监视战斗、识别敌方阵容（包含天赋）、选定击杀目标、规划控制链，并实时输出建议：`OPEN | KILL | SWAP | DEFEND | RESET`。

> **v2.0 ships the engine-depth roadmap.** Your coach now learns your opponents. A team you've played 20 times that always trinkets Fear stops getting the generic "tremor for fear" callout — Tremor gets saved for HoJ instead. A mage that consistently Ice Blocks at 30% causes the burst gate to hold. None of this is hardcoded — it learns per-team from observed combat, no character names persisted.
>
> **v2.0 引擎深度路线图已发布。** 你的教练现在能学习对手。打过 20 次的某支队伍，如果他们总是用饰品解除恐惧，则不再收到通用的"陷阱图腾解恐惧"提示——陷阱图腾会留给制裁之锤。如果某个法师习惯在 30% 血量冰块，爆发提示会被自动暂停。这些都不是写死的逻辑——它通过观察战斗按队伍学习，不会持久化任何玩家姓名。

> ⚠️ **Advice only.** The addon never casts spells, never targets enemies, never clicks protected buttons, never modifies secure macros. It emits visual + audio + text recommendations. That's it.
>
> ⚠️ **仅提供建议。** 此插件不会自动施法、不会切换目标、不会点击受保护按钮、不会修改安全宏。它只输出视觉、音频、文字提示，仅此而已。

---

## Works in every PvP context / 适用于所有 PvP 场景

| Context / 场景 | Behaviour / 行为 |
|---|---|
| **Arena 2v2 / 3v3 / 5v5** | Full engine: comp ID, spec inference, chain planning, opponent profiles, lookahead, burst gating, all visual + audio alerts. |
| **Battlegrounds** (WSG/AB/AV/EotS) | Engine adapts: nameplate-based enemy discovery, flag-carrier priority (+200), low-HP straggler boost, BG-specific callouts (`CALL_FLAG_CARRIER_LOW`, `CALL_BG_DEFEND`). Class-prior tier kicks in when the team-signature profile lacks samples (PUG'd rosters). |
| **World PvP / duels** | Engine simplifies: single-target focus, no SWAP thrash, no comp matching. DUEL_REQUESTED auto-engages. |
| **Arena-only alerts** stay gated to arena | Screen flash + voice cues only fire when `IsActiveBattlefieldArena()` is true. No spurious red flash in WSG. |

竞技场内运行完整引擎（阵容识别、天赋推断、连锁规划、对手档案、lookahead、爆发判断）；战场内引擎自适应（铭牌探测敌人、夺旗者优先级、战场提示、职业级先验）；户外 PvP / 决斗自动简化为单目标聚焦。爆发警报和语音提示仅在竞技场内触发——战场不会有错误闪屏。

---

## Works with any team composition / 适用于任何队伍组合

Earlier versions documented a specific comp (WAR/ENH/RET/RDRU/DISC melee cleave) as the "tuned-for" team. **v2 doesn't have a tuned-for comp.** `OwnComps:Infer` walks your party and returns a capability table — `hasMortalStrike`, `hasBloodlust`, `hasFreedom`, `hasMassDispel`, `hasMainHealer`, etc. — then `OwnComps:Identify` picks an archetype:

之前的版本曾标榜专门为某特定阵容调优（WAR/ENH/RET/RDRU/DISC 近战劈砍）。**v2 不再有"专属调优"队伍。** `OwnComps:Infer` 扫描你的队伍并返回一个能力表——`hasMortalStrike`、`hasBloodlust`、`hasFreedom`、`hasMassDispel`、`hasMainHealer` 等——然后 `OwnComps:Identify` 从中识别原型：

| Archetype / 原型 | When it fires / 触发条件 | What it changes / 影响 |
|---|---|---|
| `MELEE_CLEAVE` | ≥2 melee + a healer / ≥2 近战 + 治疗 | Aggressive kill-pressure callouts; prefer healer opens / 激进击杀压力提示；优先开打治疗 |
| `CASTER_CLEAVE` | ≥2 casters + a healer / ≥2 法系 + 治疗 | Ground/dispel-heavy callouts; off-healer CC priority / 落雷/驱散重点；优先控副治 |
| `DRAIN` | Affli/SP-style sustain / 痛术 / 暗牧持续型 | Mana-burn / outlast callouts; no aggressive opens / 蓝量压制 / 拖延，不主动起手 |
| `JUNGLE` | Hunter + Feral + healer / 猎人 + 野德 + 治疗 | Trap + scatter setup callouts / 陷阱 + 驱散组合 |
| `DOUBLE_HEALER` | 2+ healers / ≥2 治疗 | Mana drain plan / 蓝量消耗 |

The 100+ enemy comp catalog in `Data/Strategies.lua` carries `ownVariants` so the same enemy team gets different advice depending on your archetype. There's no hardcoded "if class is X" anywhere in the engine — everything goes through capability inference. **Run any comp; the engine adapts.**

`Data/Strategies.lua` 中的 100+ 敌方阵容目录都附带 `ownVariants`，所以同一支敌方队伍会根据你的原型给出不同建议。引擎内没有任何"如果职业是 X"这样的硬编码——一切都通过能力推理。**任意阵容皆可，引擎自适应。**

---

## Installation / 安装（一次性配置，约 2 分钟）

1. **Download or clone this repo** to your local machine.
   **下载或克隆本仓库**到本地。
2. **Copy the `ArenaCoachTBC/` folder** (the inner one with `ArenaCoachTBC.toc`) into your WoW addons directory:
   **复制 `ArenaCoachTBC/` 文件夹**（含 `ArenaCoachTBC.toc` 的那个）到魔兽世界插件目录：
   - **TBC Classic / Anniversary**: `<WoW install>/_classic_/Interface/AddOns/`
   - **macOS**: typically / 通常为 `/Applications/World of Warcraft/_classic_/Interface/AddOns/`
   - **Windows**: typically / 通常为 `C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\`
3. **Restart the client** (or `/reload` if already in). Your AddOns list should now have `ArenaCoachTBC` enabled.
   **重启客户端**（如已在游戏内，`/reload`）。插件列表中应出现已启用的 `ArenaCoachTBC`。
4. If you see "Out of Date" at character-select, enable **Load out of date AddOns**. Or bump `## Interface: 20504` in `ArenaCoachTBC.toc` to match your client.
   若角色选择界面提示 "Out of Date"，启用底部的"**载入过期插件**"。或在 `ArenaCoachTBC.toc` 中将 `## Interface: 20504` 改为与你客户端匹配的版本号。

---

## First-run checklist / 首次启动检查（约 3 分钟）

```
/acc help              -- show all slash commands  / 查看所有命令
/acc test              -- 14s scripted UI demo     / 14 秒 UI 演示
/acc unlock            -- enable dragging          / 解锁拖动
                          (drag the frame)         / （拖到合适位置）
/acc lock              -- freeze position          / 锁定位置
/acc selftest verbose  -- in-client validation     / 客户端内自检
```

After `/acc test` the recommendation frame appears center-screen and walks through 7 beats over 14 seconds (mode flips, BURST_NOW pulse, DEFEND screen flash, profile callout) — you'll see every kind of UI transition the addon emits. **If you see this demo, the addon is loaded and working.** Move the frame to a corner you'll actually look at during a match.

执行 `/acc test` 后，提示框会出现在屏幕中央，并在 14 秒内走完 7 个节拍（模式切换、爆发提示、防御警报、对手习惯提示）——你会看到插件能输出的所有 UI 变化。**看到这个演示，说明插件已正确加载。** 把框拖到你比赛中实际会看的位置。

---

## Daily usage during arena / 比赛中的日常使用

You don't run anything during a match. The addon auto-engages on `PLAYER_ENTERING_WORLD` when `UPDATE_BATTLEFIELD_STATUS` confirms you're in a rated/skirmish arena. The frame stays hidden outside arena (unless `/acc toggle` forced it on).

比赛中无需主动操作。当 `PLAYER_ENTERING_WORLD` 触发且 `UPDATE_BATTLEFIELD_STATUS` 确认进入了竞技场（排位或练习），插件自动启动。竞技场之外提示框自动隐藏（除非 `/acc toggle` 强制开启）。

**What you'll see during a match / 比赛中你会看到：**

1. **Pre-combat (arena gates closed)**: Mode = `OPEN` (yellow), target = the comp's default open target. Plan your opener.
   **战前（铁门未开）**：模式 = `OPEN`（黄色），目标 = 阵容默认起手目标。规划开场。
2. **Active**: Mode flips to `KILL` (red) / `SWAP` (orange) / `DEFEND` (blue). The big text shows who to attack; callouts row shows utility cues; chain block shows the canonical CC sequence; comp badge shows whether the engine has confirmed enemy specs.
   **战斗中**：模式切换为 `KILL`（红）/ `SWAP`（橙）/ `DEFEND`（蓝）。大字显示击杀目标；提示行显示功能性提示；连锁块显示标准 CC 序列；阵容徽章显示天赋是否已确认。
3. **Burst window**: `BURST_NOW` red pulsing badge — every burst gate has passed (kill probability ≥ threshold, chain ready, no incoming pressure).
   **爆发窗口**：`BURST_NOW` 红色脉动徽章——所有爆发门禁通过（击杀概率 ≥ 阈值、连锁就绪、无即将到来的压力）。
4. **Defensive**: When your healer is being trained or enemy lust pops, mode flips to `DEFEND` (blue). Callouts shift to Pain Sup / BoP / peel reminders.
   **防御**：当你的治疗被集火或敌方爆发激活，模式切换为 `DEFEND`（蓝色）。提示切换为痛苦压制 / 保护祝福 / 剥离。

---

## Slash commands / 命令一览

| Command | English | 中文 |
|---|---|---|
| `/acc help` | Print the command list | 显示命令列表 |
| `/acc toggle` | Show / hide the recommendation frame | 显示 / 隐藏提示框 |
| `/acc lock` / `/acc unlock` | Freeze / release the frame for dragging | 锁定 / 解锁框体拖动 |
| `/acc test` | **14s DBM-style UI demo** (mode flips, BURST_NOW, DEFEND flash) | **14 秒 DBM 风格 UI 演示**（模式切换、爆发、防御警报） |
| `/acc test bg` | BG-mode walk-through (flag carrier + low-HP straggler + CALL_BG_DEFEND) | 战场模式演示（夺旗者 + 低血单位 + 战场防御提示） |
| `/acc test world` | World PvP walk-through (single-target focus) | 户外 PvP 演示（单目标聚焦） |
| `/acc test print` | Legacy chat-only summary | 仅文字版本（旧行为） |
| `/acc enemy <c1> <c2> ...` | Simulate a custom enemy comp | 模拟自定义敌方阵容 |
| `/acc reset` | Wipe SavedVariables + `/reload` | 清空存档并 `/reload` |
| `/acc strategy safe\|balanced\|greedy` | Manual aggression override | 手动调整侵略性 |
| `/acc debug` | Toggle debug print | 切换调试输出 |
| `/acc selftest [verbose]` | In-client validation suite | 客户端内自检 |
| `/acc simulate [key\|stop]` | Replay a scripted scenario | 重放脚本化场景 |
| `/acc trace [on\|off\|dump\|clear\|status]` | Decision-trace ring buffer | 决策追踪环缓冲 |
| `/acc record [on\|off\|dump\|clear\|status]` | CLEU recording for offline replay | CLEU 录制（用于离线重放） |
| `/acc whatif skip <i>` | Counterfactual replay (skip event #i) | 反事实重放（跳过事件 #i） |
| `/acc bugreport` | Sanitised error report for issues | 已脱敏的错误报告（贴到 GitHub） |

---

## Configuration / 配置

All settings persist in `ArenaCoachTBCDB` (SavedVariables). They're forward-compatible — v1 saved-variables load on v2 without resetting your tuning.

所有设置持久化在 `ArenaCoachTBCDB`（SavedVariables）中。向后兼容——v1 存档在 v2 中无须重置即可加载。

**Key knobs / 主要配置项** (editable via `Interface → AddOns → ArenaCoachTBC` / 通过游戏内 `界面 → 插件 → ArenaCoachTBC` 编辑):

| Key / 配置项 | Default | Description / 说明 |
|---|---|---|
| `strategy.ratingAggression` | `"auto"` | `"auto"` reads `GetPersonalRatedInfo()` and tunes thresholds. Or pin: `"greedy"` / `"balanced"` / `"safe"` / a number. / `"auto"` 自动读取战场分数。也可锁定为 `"greedy"` / `"balanced"` / `"safe"` 或具体分数。 |
| `strategy.callBurstOnlyWhenMSActive` | `true` | Require Mortal Strike debuff on the target before `BURST_NOW`. / 必须 MS 减疗已挂在目标上才允许爆发。 |
| `strategy.requireWindfuryNearby` | `true` | Require Windfury Totem before burst. / 必须风怒图腾就位才允许爆发。 |
| `strategy.peelTriggerWindow` / `peelTriggerDamage` | `5` / `3` | Train detection sensitivity (damage events × window → DEFEND). / 集火检测灵敏度（伤害事件 × 时间窗 → DEFEND）。 |
| `strategy.lookaheadEnabled` | `true` | Engage the M10 expectimax over chain × opponent response. / 启用 M10 lookahead（连锁 × 对手反应期望值最大化）。 |
| `frame.compactMode` | `false` | Hides the friendly/enemy cooldown icon rows. / 隐藏己方/敌方冷却图标行。 |
| `alerts.sound` / `alerts.screenFlash` | `true` / `true` | Voice cue + URGENT-mode screen flash. / 语音提示 + 紧急模式屏幕闪烁。 |

---

## Spell names and localisation / 法术名称与本地化

Spell IDs in `Data/Spells.lua` are **universal** — a single integer that's the same across every WoW locale. The names shown in the UI come from the **WoW client's locale** via `GetSpellInfo(spellID)` — so if you run a Chinese client you'll see Chinese spell names (e.g. *闷棍*), and an English client shows *Sap*. **The addon doesn't hard-code spell text anywhere.**

`Data/Spells.lua` 中的法术 ID 是**通用的**——同一个整数对应所有语言客户端。UI 中显示的法术名称通过 `GetSpellInfo(spellID)` 从**魔兽客户端当前语言**获取——所以中文客户端会显示 *闷棍*，英文客户端显示 *Sap*。**插件不在任何地方硬编码法术名称。**

Same for **mouse-over tooltips on the icon rows** — they call `GameTooltip:SetSpellByID(spellID)` so the tooltip is the canonical Blizzard popup in your client's locale (icon + name + flavor text).

**图标行的鼠标悬停提示**也是如此——它们调用 `GameTooltip:SetSpellByID(spellID)`，所以提示就是暴雪标准的本地化弹窗（图标 + 名称 + 描述）。

User-facing **callout strings** (e.g. "Tremor for fear" / "陷阱图腾解恐惧") are addon-locale-keyed: `Locales/enUS.lua` is canonical with 98 keys, `Locales/zhCN.lua` is in parity. The addon picks the locale from `GetLocale()` automatically; override with `db.language` if needed.

面向用户的**提示文案**（如 "Tremor for fear" / "陷阱图腾解恐惧"）通过插件本地化键管理：`Locales/enUS.lua` 为基准，含 98 个键；`Locales/zhCN.lua` 严格对齐。插件通过 `GetLocale()` 自动选择语言，可通过 `db.language` 覆盖。

---

## Customising the display with WeakAuras / 用 WeakAuras 自定义显示

The addon publishes its full recommendation through `_G.ArenaCoachTBC`. Build your own HUD by consuming the getters.

插件通过 `_G.ArenaCoachTBC` 全局发布完整的推荐数据。你可以基于这些 getter 构建自己的 HUD。

**Two paths / 两种方式:**

1. **Paste-ready import strings (recommended)** — `docs/weakaura-imports.md` ships 5 generated `!WA:2!...` strings. Open `/wa`, click **Import**, paste, done.
   **直接粘贴导入串（推荐）**——`docs/weakaura-imports.md` 提供 5 个生成好的 `!WA:2!...` 字符串。打开 `/wa`，点击 **Import**，粘贴即可。
2. **Hand-built triggers** — `docs/weakaura-pack.md` documents the trigger code for 5 templates (mode badge, burst gate, defensive alert, callout list, comp readout). Paste into a Custom trigger you build yourself.
   **手动构建触发器**——`docs/weakaura-pack.md` 提供了 5 个模板的触发器代码（模式徽章、爆发开关、防御警报、提示列表、阵容信息）。粘贴到你自行创建的 Custom 触发器里。

**Highlights of the bridge API / 主要 API:**

```lua
_G.ArenaCoachTBC.GetMode()             -- "KILL" / "SWAP" / "DEFEND" / "OPEN" / "RESET"
_G.ArenaCoachTBC.GetPrimaryTarget()    -- enemy GUID / 敌方 GUID
_G.ArenaCoachTBC.GetPrimaryTargetName()
_G.ArenaCoachTBC.IsBurstAllowed()      -- bool: burst gate passed / 爆发门禁是否通过
_G.ArenaCoachTBC.GetBurstDecision()    -- multi-gate breakdown / 多门禁细分
_G.ArenaCoachTBC.GetChain()            -- {id, label, expectedProb, steps, links}
_G.ArenaCoachTBC.GetKillProb(guid)     -- 0..1
_G.ArenaCoachTBC.GetCompConfidence()   -- 0..1
_G.ArenaCoachTBC.GetCompSpecConfirmed()
_G.ArenaCoachTBC.GetOpponentProfile()  -- read-only Beta priors / 只读 Beta 先验
_G.ArenaCoachTBC.GetTendencyMean("trinketsFear")
```

The addon also fires `WeakAuras.ScanEvents("ACC_RECOMMENDATION", rec)` on every evaluation — wire a Custom Event trigger to react on each new rec instead of polling.

插件每次评估后还会触发 `WeakAuras.ScanEvents("ACC_RECOMMENDATION", rec)`——连接 Custom Event 触发器即可基于事件响应，无需轮询。

---

## How it learns (the M9 keystone) / 学习机制（M9 关键模块）

The first time you fight any team, the engine has no opponent data — it falls back to comp defaults. Turn on `/acc record on` and play. The addon writes per-team behavioural profiles into `ArenaCoachTBCDB.profiles`, keyed by a hash of class composition + a djb2 hash of player names. **Names are never stored** — only the hash is.

首次对战任意队伍时，引擎没有对手数据——退回到阵容默认值。`/acc record on` 后开始游玩。插件按队伍写入行为档案到 `ArenaCoachTBCDB.profiles`，键为职业组合的哈希 + 玩家名的 djb2 哈希。**玩家姓名永远不存储**——只存哈希。

Four binary tendencies tracked as Beta(α, β) priors / 四个二元习惯，按 Beta(α, β) 先验追踪:

- `trinketsFear` — when feared, do they trinket? / 被恐惧时是否使用饰品？
- `iceBlockBelow30` — mage: Ice Block at HP <30%? / 法师 30% 血量是否冰块？
- `kicksFirstHeal` — do they kick the first big heal? / 是否打断第一个大治疗？
- `sapsPriest` — when sapping, do they pick the priest? / 闷棍时是否选牧师？

After ~5 observations the profile becomes opinionated; after ~20 the posterior mean is reliable.

约 5 次观察后档案开始有"意见"；约 20 次后后验均值可靠。

**To inspect / 查看方式:**
- `/acc trace dump` — shows last N decisions with profile contribution / 显示最近 N 次决策及档案贡献
- `/acc record dump` — raw CLEU event count / CLEU 事件原始数量
- `/acc whatif skip <i>` — replay log with event #i removed / 重放并跳过事件 #i
- `tools/replay.lua <SavedVars>` — offline shell replay / 终端离线重放

---

## Running the tests / 运行测试

The engine is pure Lua and headless-testable. The suite stubs every WoW API needed.

引擎是纯 Lua，可无头测试。测试套件已 stub 所需的所有 WoW API。

```bash
# Full suite with coverage / 完整套件 + 覆盖率
lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua && luacov && tail -n 20 luacov.report.out

# Single standalone spec / 独立 spec
lua5.1 ArenaCoachTBC/Tests/StrategyEngine_spec.lua

# Locale parity (every enUS key must exist in every other locale)
# 本地化对齐（每个 enUS 键必须存在于其他语言）
lua5.1 tools/check_locales.lua

# Replay a recorded SavedVariables log / 重放 SavedVariables 录像
lua5.1 tools/replay.lua <path/to/ArenaCoachTBC.lua>
```

CI runs syntax check → locale parity → tests → 99% coverage gate on every push and PR. v2.0.1 ships with **536 tests**, **99%+ coverage**, and an **81% baseline** agreement against hand-labelled benchmark scenarios.

CI 在每次推送和 PR 上运行：语法检查 → 本地化对齐 → 测试 → 99% 覆盖率门禁。v2.0.1 共 **536 个测试**、**99%+ 覆盖率**、对人工标注基准场景的 **81% 一致率**。

---

## License / 许可证

MIT.
