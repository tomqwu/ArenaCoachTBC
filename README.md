# ArenaCoachTBC

A real-time arena strategy coach for **World of Warcraft TBC Classic / TBC Anniversary**. Watches the fight, identifies the enemy comp (including spec), picks a kill target, plans CC chains, and emits a recommendation: `OPEN | KILL | SWAP | DEFEND | RESET`.

> **v2.0 ships the engine-depth roadmap.** Your coach now learns your opponents. A team you've played 20 times that always trinkets Fear stops getting the generic "tremor for fear" callout — Tremor gets saved for HoJ instead. A mage that consistently Ice Blocks at 30% causes the burst gate to hold. None of this is hardcoded — it learns per-team from observed combat, no character names persisted.

> ⚠️ **Advice only.** The addon never casts spells, never targets enemies, never clicks protected buttons, never modifies secure macros. It emits visual + audio + text recommendations. That's it.

---

## Works in every PvP context

| Context | Behaviour |
|---|---|
| **Arena 2v2 / 3v3 / 5v5** | Full engine: comp ID, spec inference, chain planning, opponent profiles, lookahead, burst gating, all visual + audio alerts. |
| **Battlegrounds** (WSG/AB/AV/EotS) | Engine adapts: sparse nameplate enemy discovery, hostile-damage CLEU fallback, flag-carrier priority (+200), low-HP straggler boost, BG-specific callouts (`CALL_FLAG_CARRIER_LOW`, `CALL_BG_DEFEND`). Class-prior tier kicks in when the team-signature profile lacks samples (PUG'd rosters). |
| **World PvP / duels** | Engine simplifies: single-target focus, no SWAP thrash, no comp matching. Low player HP can still trigger `DEFEND`, even solo on a non-healer. `DUEL_REQUESTED` auto-engages. |
| **Arena-only alerts** stay gated to arena | Voice cues only fire when `IsActiveBattlefieldArena()` is true. No full-screen flash or spurious red flash in WSG. |

---

## Works with any team composition

Earlier versions documented a specific comp (WAR/ENH/RET/RDRU/DISC melee cleave) as the "tuned-for" team. **v2 doesn't have a tuned-for comp.** `OwnComps:Infer` walks your party and returns a capability table — `hasMortalStrike`, `hasBloodlust`, `hasFreedom`, `hasMassDispel`, `hasMainHealer`, etc. — then `OwnComps:Identify` picks an archetype:

| Archetype | When it fires | What it changes |
|---|---|---|
| `MELEE_CLEAVE` | ≥2 melee + a healer | Aggressive kill-pressure callouts; prefer healer opens |
| `CASTER_CLEAVE` | ≥2 casters + a healer | Ground/dispel-heavy callouts; off-healer CC priority |
| `DRAIN` | Affli/SP-style sustain | Mana-burn / outlast callouts; no aggressive opens |
| `JUNGLE` | Hunter + Feral + healer | Trap + scatter setup callouts |
| `DOUBLE_HEALER` | 2+ healers | Mana drain plan |

The 100+ enemy comp catalog in `Data/Strategies.lua` carries `ownVariants` so the same enemy team gets different advice depending on your archetype. There's no hardcoded "if class is X" anywhere in the engine — everything goes through capability inference. **Run any comp; the engine adapts.**

---

## Installation (one-time setup, ~2 min)

1. **Download** the latest zip from the [Releases page](https://github.com/tomqwu/ArenaCoachTBC/releases) — or use the [CurseForge listing](https://www.curseforge.com/wow/addons/arenacoachtbc).
2. **Extract the `ArenaCoachTBC/` folder** (the inner one containing `ArenaCoachTBC.toc`) into your WoW addons directory:
   - **TBC Classic / Anniversary**: `<WoW install>/_classic_/Interface/AddOns/`
   - **macOS**: typically `/Applications/World of Warcraft/_classic_/Interface/AddOns/`
   - **Windows**: typically `C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\`
3. **Restart the client** (or `/reload` if already in). Your AddOns list should now have `ArenaCoachTBC` enabled.
4. If you see "Out of Date" at character-select, enable **Load out of date AddOns**. Or bump `## Interface: 20505` in `ArenaCoachTBC.toc` to match your client.

---

## First-run checklist (~3 min)

```
/acc help              -- show all slash commands
/acc test              -- realistic arena replay through the engine
/acc unlock            -- enable dragging
                          (drag the frame)
/acc lock              -- freeze position
/acc selftest verbose  -- in-client validation
```

After `/acc test` the addon replays a realistic 3v3 RMP arena over about a minute through the same engine scorer used in a match: gates closed (`OPEN`), combat start, enemy burst, healer CC, healer pressure (`DEFEND`), Disc Priest reveal, Pain Suppression/trinket state, a swap/kill window, then reset. The timed replay force-shows the HUD because it runs outside a real arena instance, and each scheduled beat repaints the board from a fresh `StrategyEngine:Evaluate` result. **If you see this replay, the addon is loaded and the decision pipeline is working.** Use `/acc unlock` to move the integrated prototype-A board — left status stack, center action, center player-info/assignments, and right cue rail — to a spot you can glance at without covering arena frames, cast bars, or your WeakAuras. Drag the lower-right grip to resize the board; width and height persist just like the position. The board has a light translucent shell, top drag strip, grip marker, internal dividers, mode-coloured center accent, and shadowed/highlighted text so the draggable area is visible without darkening the fight. Compact boards cap center detail and assignment lines so sections do not overlap; make the board taller/wider when you want full verbose five-player review detail. Use `/acc test hud` for the visual-only HUD tour; the waiting/pre-gate beats now show all four zones with placeholders so the layout is visible before combat data exists.

If `/acc off` was used earlier, `/acc test` and `/acc simulate <scenario>` turn the addon back on before replaying so chat events cannot advance while the HUD remains stuck on the first waiting state.

---

## Daily usage during arena

You don't run anything during a match. The addon auto-engages on `PLAYER_ENTERING_WORLD` when `UPDATE_BATTLEFIELD_STATUS` confirms you're in a rated/skirmish arena. The frame stays hidden outside arena (unless `/acc toggle` forced it on).

**What you'll see during a match:**

1. **Pre-combat (arena gates closed)**: Mode = `OPEN` (yellow), target = the comp's default open target. Plan your opener.
2. **Active**: Mode flips to `KILL` (red) / `SWAP` (orange) / `DEFEND` (blue). The integrated board shows a punchy center cue like `!! BURST !!`, `!! DANGER !!`, or `!! PINCH !!`; the left status stack shows current targets and friendly pressure; the right rail shows callout icons/text; the player-info panel under the action call gives up to three DBM-style actions in normal mode. `/acc verbose on` adds five-player assignments, chain steps, and comp/spec badges for review, with visible lines capped by the board size so the sections stay separated. Resize the board taller/wider for the full review layout. If the recommendation stops refreshing, the HUD fades out instead of leaving stale text on screen.
3. **Burst window**: `BURST READY` pill in the stats row — every burst gate has passed (target vulnerable, configured MS/Windfury requirements met, melee can connect, kill probability ≥ threshold, no incoming pressure). Chain readiness is shown in the gate breakdown and only blocks burst when `strategy.requireChainForBurst` is enabled.
4. **Defensive**: When your healer is being trained or enemy lust pops, mode flips to `DEFEND` (blue). The HUD plate and nameplate cues carry the warning without a big screen-edge flash; callouts shift to Pain Sup / BoP / peel reminders.

---

## Slash commands

| Command | Description |
|---|---|
| `/acc help` | Print the command list |
| `/acc toggle` | Show / hide the recommendation frame |
| `/acc lock` / `/acc unlock` | Freeze / release the frame for dragging and resizing |
| `/acc test` | Realistic 3v3 arena replay through the engine (OPEN → pressure/DEFEND → kill/reset) |
| `/acc test hud` | DBM-style visual HUD demo (mode flips, BURST_NOW, DEFEND cue) |
| `/acc test bg` | BG-mode walk-through (flag carrier + low-HP straggler + CALL_BG_DEFEND) |
| `/acc test world` | World PvP walk-through (single-target focus) |
| `/acc test print` | Legacy chat-only summary |
| `/acc enemy <c1> <c2> ...` | Simulate a custom enemy comp |
| `/acc reset` | Wipe SavedVariables + `/reload` |
| `/acc strategy safe\|balanced\|greedy` | Manual aggression override |
| `/acc glow [on\|off]` | Toggle the optional thin mode-coloured edge cue |
| `/acc nameplate [on\|off]` | Toggle nameplate highlights for KILL / SWAP targets (v2.2+) |
| `/acc debug` | Toggle debug print |
| `/acc selftest [verbose]` | In-client validation suite |
| `/acc simulate [key\|stop]` | Replay a scripted scenario |
| `/acc trace [on\|off\|dump\|clear\|status]` | Decision-trace ring buffer |
| `/acc record [on\|off\|dump\|clear\|status]` | CLEU recording for offline replay |
| `/acc whatif skip <i>` | Counterfactual replay (skip event #i) |
| `/acc bugreport` | Sanitised error report for issues |

---

## Configuration

All settings persist in `ArenaCoachTBCDB` (SavedVariables). They're forward-compatible — v1 saved-variables load on v2 without resetting your tuning.

**Key knobs** (editable via `Interface → AddOns → ArenaCoachTBC`):

| Key | Default | Description |
|---|---|---|
| `strategy.ratingAggression` | `"auto"` | `"auto"` reads `GetPersonalRatedInfo()` and tunes thresholds. Or pin: `"greedy"` / `"balanced"` / `"safe"` / a number. |
| `strategy.callBurstOnlyWhenMSActive` | `true` | Require Mortal Strike debuff on the target before `BURST_NOW`. |
| `strategy.requireWindfuryNearby` | `true` | Require Windfury Totem before burst. |
| `strategy.requireChainForBurst` | `false` | Treat a positive CC chain as mandatory for `BURST_NOW`; off by default so BG/world and sparse catalog entries can still call obvious burst windows. |
| `strategy.peelTriggerWindow` / `peelTriggerDamage` | `5` / `3` | Train detection sensitivity (damage events × window → DEFEND). |
| `strategy.lookaheadEnabled` | `true` | Engage the M10 expectimax over chain × opponent response. |
| `frame.compactMode` | `false` | Hides the friendly/enemy cooldown icon rows. |
| `alerts.sound` / `alerts.screenFlash` | `true` / `false` | Voice cue toggle; `screenFlash` is retained for SavedVariables compatibility but no longer triggers full-screen flashing. |
| `alerts.edgeGlow` / `alerts.nameplate` | `false` / `true` | Optional thin edge cue + default-on nameplate highlight. |

---

## Spell names and localisation

Spell IDs in `Data/Spells.lua` are **universal** — a single integer that's the same across every WoW locale. The names shown in the UI come from the **WoW client's locale** via `GetSpellInfo(spellID)` — so if you run a Chinese client you'll see Chinese spell names (e.g. *闷棍*), and an English client shows *Sap*. **The addon doesn't hard-code spell text anywhere.**

Same for **mouse-over tooltips on the icon rows** — they call `GameTooltip:SetSpellByID(spellID)` so the tooltip is the canonical Blizzard popup in your client's locale (icon + name + flavor text).

User-facing **callout and assignment strings** (e.g. "Tremor for fear", "Warrior: MS target") are addon-locale-keyed: `Locales/enUS.lua` is canonical and `Locales/zhCN.lua` stays in parity. The addon picks the locale from `GetLocale()` automatically; override with `db.language` if needed.

---

## Customising the display with WeakAuras

The built-in HUD (arcade cue, mode label, target stats, nameplate highlight, audio, and optional thin edge cue) covers what most users want — no WeakAura needed. If you want to drive your own custom HUD on top, the addon exposes its full live state through `_G.ArenaCoachTBC`.

> **About paste-ready import strings**: v2.0–v2.2.5 tried to ship pre-built WA import strings in this README. The `node-weakauras-parser` library we used to generate them produces strings that decode correctly but fail WA's import-validator byte check (the import dialog never shows the Import button). After 6 patches chasing it we concluded the parser is the wrong tool. If you want to use the templates, the source for each (mode badge, burst gate, defensive alert, callout stream, comp readout) is in `docs/weakaura-pack.md` — paste the trigger Lua into a Custom-trigger WeakAura you build in-game, no import-string round-trip needed.

**Bridge API highlights:**

```lua
_G.ArenaCoachTBC.GetMode()             -- "KILL" / "SWAP" / "DEFEND" / "OPEN" / "RESET"
_G.ArenaCoachTBC.GetPrimaryTarget()    -- enemy GUID
_G.ArenaCoachTBC.GetPrimaryTargetName()
_G.ArenaCoachTBC.IsBurstAllowed()      -- bool: burst gate passed
_G.ArenaCoachTBC.GetBurstDecision()    -- multi-gate breakdown
_G.ArenaCoachTBC.GetChain()            -- {id, label, expectedProb, steps, links}
_G.ArenaCoachTBC.GetPlayerActions()    -- per-friendly DBM-style assignments
_G.ArenaCoachTBC.GetPlayerAction()     -- assignment for unit "player"
_G.ArenaCoachTBC.GetActionForUnit("party1")
_G.ArenaCoachTBC.GetKillProb(guid)     -- 0..1
_G.ArenaCoachTBC.GetCompConfidence()   -- 0..1
_G.ArenaCoachTBC.GetCompSpecConfirmed()
_G.ArenaCoachTBC.GetOpponentProfile()  -- read-only Beta priors
_G.ArenaCoachTBC.GetTendencyMean("trinketsFear")
```

The addon also fires `WeakAuras.ScanEvents("ACC_RECOMMENDATION", rec)` on every evaluation — wire a Custom Event trigger to react on each new rec instead of polling.

---

## How it learns (the M9 keystone)

The first time you fight any team, the engine has no opponent data — it falls back to comp defaults. Turn on `/acc record on` and play. The addon writes per-team behavioural profiles into `ArenaCoachTBCDB.profiles`, keyed by a hash of class composition + a djb2 hash of player names. **Names are never stored** — only the hash is.

Four binary tendencies tracked as Beta(α, β) priors:

- `trinketsFear` — when feared, do they trinket?
- `iceBlockBelow30` — mage: Ice Block at HP <30%?
- `kicksFirstHeal` — do they kick the first big heal?
- `sapsPriest` — when sapping, do they pick the priest?

After ~5 observations the profile becomes opinionated; after ~20 the posterior mean is reliable.

**To inspect:**
- `/acc trace dump` — shows last N decisions with profile contribution
- `/acc record dump` — raw CLEU event count
- `/acc whatif skip <i>` — replay log with event #i removed
- `tools/replay.lua <SavedVars>` — offline shell replay

---

## Running the tests

The engine is pure Lua and headless-testable. The suite stubs every WoW API needed.

```bash
# Full suite with coverage
lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua && luacov && tail -n 20 luacov.report.out

# Single standalone spec
lua5.1 ArenaCoachTBC/Tests/StrategyEngine_spec.lua

# Locale parity (every enUS key must exist in every other locale)
lua5.1 tools/check_locales.lua

# Replay a recorded SavedVariables log
lua5.1 tools/replay.lua <path/to/ArenaCoachTBC.lua>
```

CI runs syntax check → locale parity → tests → 99% coverage gate on every push and PR. The current headless suite has **673 tests** and the benchmark suite tracks agreement against hand-labelled scenarios.

---

## License

MIT.

---

# 中文 / Chinese

**魔兽世界 TBC 怀旧服 / TBC 周年服**的实时竞技场战术教练。监视战斗、识别敌方阵容（包含天赋）、选定击杀目标、规划控制链，并实时输出建议：`OPEN | KILL | SWAP | DEFEND | RESET`。

> **v2.0 引擎深度路线图已发布。** 你的教练现在能学习对手。打过 20 次的某支队伍，如果他们总是用饰品解除恐惧，则不再收到通用的"陷阱图腾解恐惧"提示——陷阱图腾会留给制裁之锤。如果某个法师习惯在 30% 血量冰块，爆发提示会被自动暂停。这些都不是写死的逻辑——它通过观察战斗按队伍学习，不会持久化任何玩家姓名。

> ⚠️ **仅提供建议。** 此插件不会自动施法、不会切换目标、不会点击受保护按钮、不会修改安全宏。它只输出视觉、音频、文字提示，仅此而已。

---

## 适用于所有 PvP 场景

| 场景 | 行为 |
|---|---|
| **竞技场 2v2 / 3v3 / 5v5** | 完整引擎：阵容识别、天赋推断、连锁规划、对手档案、lookahead、爆发判断、全部视觉与音频警报。 |
| **战场**（WSG/AB/AV/EotS） | 引擎自适应：稀疏铭牌探测敌人、受击 CLEU 兜底、夺旗者优先级（+200）、低血单位提升、战场专属提示（`CALL_FLAG_CARRIER_LOW`、`CALL_BG_DEFEND`）。队伍特征档案样本不足时（如临时组队）自动启用职业级先验。 |
| **户外 PvP / 决斗** | 引擎简化：单目标聚焦、不会左右横跳、不做阵容匹配。低血量也会触发 `DEFEND`，即使你是单人非治疗职业。`DUEL_REQUESTED` 自动启动。 |
| **竞技场专属警报**仅在竞技场触发 | 屏幕闪烁与语音提示只在 `IsActiveBattlefieldArena()` 为真时触发。战场中不会出现错误的红色闪屏。 |

---

## 适用于任何队伍组合

之前的版本曾标榜专门为某特定阵容调优（WAR/ENH/RET/RDRU/DISC 近战劈砍）。**v2 不再有"专属调优"队伍。** `OwnComps:Infer` 扫描你的队伍并返回一个能力表——`hasMortalStrike`、`hasBloodlust`、`hasFreedom`、`hasMassDispel`、`hasMainHealer` 等——然后 `OwnComps:Identify` 从中识别原型：

| 原型 | 触发条件 | 影响 |
|---|---|---|
| `MELEE_CLEAVE` | ≥2 近战 + 治疗 | 激进击杀压力提示；优先开打治疗 |
| `CASTER_CLEAVE` | ≥2 法系 + 治疗 | 落雷/驱散重点；优先控副治 |
| `DRAIN` | 痛术 / 暗牧持续型 | 蓝量压制 / 拖延，不主动起手 |
| `JUNGLE` | 猎人 + 野德 + 治疗 | 陷阱 + 驱散组合 |
| `DOUBLE_HEALER` | ≥2 治疗 | 蓝量消耗 |

`Data/Strategies.lua` 中的 100+ 敌方阵容目录都附带 `ownVariants`，所以同一支敌方队伍会根据你的原型给出不同建议。引擎内没有任何"如果职业是 X"这样的硬编码——一切都通过能力推理。**任意阵容皆可，引擎自适应。**

---

## 安装（一次性配置，约 2 分钟）

1. 从 [Releases 页面](https://github.com/tomqwu/ArenaCoachTBC/releases) **下载最新 zip**，或使用 [CurseForge 列表](https://www.curseforge.com/wow/addons/arenacoachtbc)。
2. **解压并复制 `ArenaCoachTBC/` 文件夹**（含 `ArenaCoachTBC.toc` 的那个）到魔兽世界插件目录：
   - **TBC Classic / 周年服**：`<WoW install>/_classic_/Interface/AddOns/`
   - **macOS**：通常为 `/Applications/World of Warcraft/_classic_/Interface/AddOns/`
   - **Windows**：通常为 `C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\`
3. **重启客户端**（如已在游戏内，`/reload`）。插件列表中应出现已启用的 `ArenaCoachTBC`。
4. 若角色选择界面提示 "Out of Date"，启用底部的"**载入过期插件**"。或在 `ArenaCoachTBC.toc` 中将 `## Interface: 20505` 改为与你客户端匹配的版本号。

---

## 首次启动检查（约 3 分钟）

```
/acc help              -- 查看所有命令
/acc test              -- 真实竞技场引擎回放
/acc unlock            -- 解锁拖动/缩放
                          （拖到合适位置，右下角可缩放）
/acc lock              -- 锁定位置
/acc selftest verbose  -- 客户端内自检
```

执行 `/acc test` 后，插件会用约 1 分钟通过真实决策引擎回放一局 3v3 RMP：铁门未开（`OPEN`）、开战、敌方爆发、治疗被控、治疗承压（`DEFEND`）、戒律牧确认、痛苦压制/徽章状态、换火击杀窗口，最后重置。**看到这个回放，说明插件已加载且决策链路可运行。** 把框拖到你比赛中实际会看的位置；右下角拖拽可缩放，位置和大小都会保存。`/acc test hud` 保留旧的纯视觉 HUD 演示。

---

## 比赛中的日常使用

比赛中无需主动操作。当 `PLAYER_ENTERING_WORLD` 触发且 `UPDATE_BATTLEFIELD_STATUS` 确认进入了竞技场（排位或练习），插件自动启动。竞技场之外提示框自动隐藏（除非 `/acc toggle` 强制开启）。

**比赛中你会看到：**

1. **战前（铁门未开）**：模式 = `OPEN`（黄色），目标 = 阵容默认起手目标。规划开场。
2. **战斗中**：模式切换为 `KILL`（红）/ `SWAP`（橙）/ `DEFEND`（蓝）。大字显示击杀目标；信息行显示目标血量百分比和击杀概率；提示行显示功能性提示；连锁块显示标准 CC 序列；阵容徽章显示天赋是否已确认。
3. **爆发窗口**：信息行出现 `BURST READY` 标签——目标可被击杀、配置要求的 MS / 风怒已满足、近战能贴住、击杀概率 ≥ 阈值且没有敌方反压。连锁就绪会显示在门禁明细中，只有启用 `strategy.requireChainForBurst` 时才会硬性阻止爆发。
4. **防御**：当你的治疗被集火或敌方爆发激活，模式切换为 `DEFEND`（蓝色）。屏幕边缘光晕转蓝；提示切换为痛苦压制 / 保护祝福 / 剥离。

---

## 命令一览

| 命令 | 说明 |
|---|---|
| `/acc help` | 显示命令列表 |
| `/acc toggle` | 显示 / 隐藏提示框 |
| `/acc lock` / `/acc unlock` | 锁定 / 解锁框体拖动 |
| `/acc test` | 真实 3v3 竞技场引擎回放（开局 → 承压/防御 → 击杀/重置） |
| `/acc test hud` | DBM 风格视觉 HUD 演示（模式切换、爆发、防御警报） |
| `/acc test bg` | 战场模式演示（夺旗者 + 低血单位 + 战场防御提示） |
| `/acc test world` | 户外 PvP 演示（单目标聚焦） |
| `/acc test print` | 仅文字版本（旧行为） |
| `/acc enemy <c1> <c2> ...` | 模拟自定义敌方阵容 |
| `/acc reset` | 清空存档并 `/reload` |
| `/acc strategy safe\|balanced\|greedy` | 手动调整侵略性 |
| `/acc glow [on\|off]` | 切换可选的细边缘提示 |
| `/acc nameplate [on\|off]` | 切换击杀/换火目标的铭牌高亮（v2.2+） |
| `/acc debug` | 切换调试输出 |
| `/acc selftest [verbose]` | 客户端内自检 |
| `/acc simulate [key\|stop]` | 重放脚本化场景 |
| `/acc trace [on\|off\|dump\|clear\|status]` | 决策追踪环缓冲 |
| `/acc record [on\|off\|dump\|clear\|status]` | CLEU 录制（用于离线重放） |
| `/acc whatif skip <i>` | 反事实重放（跳过事件 #i） |
| `/acc bugreport` | 已脱敏的错误报告（贴到 GitHub） |

---

## 配置

所有设置持久化在 `ArenaCoachTBCDB`（SavedVariables）中。向后兼容——v1 存档在 v2 中无须重置即可加载。

**主要配置项**（通过游戏内 `界面 → 插件 → ArenaCoachTBC` 编辑）：

| 配置项 | 默认 | 说明 |
|---|---|---|
| `strategy.ratingAggression` | `"auto"` | `"auto"` 自动读取战场分数。也可锁定为 `"greedy"` / `"balanced"` / `"safe"` 或具体分数。 |
| `strategy.callBurstOnlyWhenMSActive` | `true` | 必须 MS 减疗已挂在目标上才允许爆发。 |
| `strategy.requireWindfuryNearby` | `true` | 必须风怒图腾就位才允许爆发。 |
| `strategy.requireChainForBurst` | `false` | 将正收益控制链设为 `BURST_NOW` 的硬性条件；默认关闭，以便战场、户外和缺少链模板的阵容仍能提示明显爆发窗口。 |
| `strategy.peelTriggerWindow` / `peelTriggerDamage` | `5` / `3` | 集火检测灵敏度（伤害事件 × 时间窗 → DEFEND）。 |
| `strategy.lookaheadEnabled` | `true` | 启用 M10 lookahead（连锁 × 对手反应期望值最大化）。 |
| `frame.compactMode` | `false` | 隐藏己方/敌方冷却图标行。 |
| `alerts.sound` / `alerts.screenFlash` | `true` / `false` | 语音提示开关；`screenFlash` 为存档兼容保留，但不会再触发全屏闪烁。 |
| `alerts.edgeGlow` / `alerts.nameplate` | `false` / `true` | 可选细边缘提示 + 默认开启的铭牌高亮。 |

---

## 法术名称与本地化

`Data/Spells.lua` 中的法术 ID 是**通用的**——同一个整数对应所有语言客户端。UI 中显示的法术名称通过 `GetSpellInfo(spellID)` 从**魔兽客户端当前语言**获取——所以中文客户端会显示 *闷棍*，英文客户端显示 *Sap*。**插件不在任何地方硬编码法术名称。**

**图标行的鼠标悬停提示**也是如此——它们调用 `GameTooltip:SetSpellByID(spellID)`，所以提示就是暴雪标准的本地化弹窗（图标 + 名称 + 描述）。

面向用户的**提示文案**（如 "陷阱图腾解恐惧"、"集火牧师"）通过插件本地化键管理：`Locales/enUS.lua` 为基准，含 112 个键；`Locales/zhCN.lua` 严格对齐。插件通过 `GetLocale()` 自动选择语言，可通过 `db.language` 覆盖。

---

## 用 WeakAuras 自定义显示

内建 HUD（模式标签、目标信息行、屏幕边缘光晕、铭牌高亮、音效）已经涵盖绝大多数场景——不需要额外配置 WeakAura。如果你想在此之上自定义 HUD，插件通过 `_G.ArenaCoachTBC` 全局发布完整的实时状态。

> **关于"可粘贴导入字符串"**：v2.0–v2.2.5 曾尝试在 README 中直接附带 WA 导入字符串。我们使用的 `node-weakauras-parser` 库生成的字符串可以正常解码，但通过不了 WA 导入校验的字节比对——粘贴后不会弹出 Import 按钮。连续 6 次补丁追查后确认该库不适用。如需使用这些模板，请在 `docs/weakaura-pack.md` 中查看每个（模式徽章、爆发开关、防御警报、提示流、阵容信息）的触发器源码——把 Lua 代码粘到你在游戏内自建的 Custom 触发器里即可，无需经过导入字符串环节。

**主要 API：**

```lua
_G.ArenaCoachTBC.GetMode()             -- "KILL" / "SWAP" / "DEFEND" / "OPEN" / "RESET"
_G.ArenaCoachTBC.GetPrimaryTarget()    -- 敌方 GUID
_G.ArenaCoachTBC.GetPrimaryTargetName()
_G.ArenaCoachTBC.IsBurstAllowed()      -- 爆发门禁是否通过
_G.ArenaCoachTBC.GetBurstDecision()    -- 多门禁细分
_G.ArenaCoachTBC.GetChain()            -- {id, label, expectedProb, steps, links}
_G.ArenaCoachTBC.GetKillProb(guid)     -- 0..1
_G.ArenaCoachTBC.GetCompConfidence()   -- 0..1
_G.ArenaCoachTBC.GetCompSpecConfirmed()
_G.ArenaCoachTBC.GetOpponentProfile()  -- 只读 Beta 先验
_G.ArenaCoachTBC.GetTendencyMean("trinketsFear")
```

插件每次评估后还会触发 `WeakAuras.ScanEvents("ACC_RECOMMENDATION", rec)`——连接 Custom Event 触发器即可基于事件响应，无需轮询。

---

## 学习机制（M9 关键模块）

首次对战任意队伍时，引擎没有对手数据——退回到阵容默认值。`/acc record on` 后开始游玩。插件按队伍写入行为档案到 `ArenaCoachTBCDB.profiles`，键为职业组合的哈希 + 玩家名的 djb2 哈希。**玩家姓名永远不存储**——只存哈希。

四个二元习惯，按 Beta(α, β) 先验追踪：

- `trinketsFear` — 被恐惧时是否使用饰品？
- `iceBlockBelow30` — 法师 30% 血量是否冰块？
- `kicksFirstHeal` — 是否打断第一个大治疗？
- `sapsPriest` — 闷棍时是否选牧师？

约 5 次观察后档案开始有"意见"；约 20 次后后验均值可靠。

**查看方式：**
- `/acc trace dump` — 显示最近 N 次决策及档案贡献
- `/acc record dump` — CLEU 事件原始数量
- `/acc whatif skip <i>` — 重放并跳过事件 #i
- `tools/replay.lua <SavedVars>` — 终端离线重放

---

## 运行测试

引擎是纯 Lua，可无头测试。测试套件已 stub 所需的所有 WoW API。

```bash
# 完整套件 + 覆盖率
lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua && luacov && tail -n 20 luacov.report.out

# 独立 spec
lua5.1 ArenaCoachTBC/Tests/StrategyEngine_spec.lua

# 本地化对齐（每个 enUS 键必须存在于其他语言）
lua5.1 tools/check_locales.lua

# 重放 SavedVariables 录像
lua5.1 tools/replay.lua <path/to/ArenaCoachTBC.lua>
```

CI 在每次推送和 PR 上运行：语法检查 → 本地化对齐 → 测试 → 99% 覆盖率门禁。v2.2.0 共 **613 个测试**、**99%+ 覆盖率**、对人工标注基准场景的 **81% 一致率**。

---

## 许可证

MIT。
