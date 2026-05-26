# ArenaCoachTBC

A strategy coach addon for **TBC Classic / TBC Anniversary** arena. Watches your arena, detects both your own team capabilities and the enemy composition, scores enemies in real time, and tells you who to open on, who to swap to, when to burst, and when to defend.

**TBC 怀旧服 / TBC 周年服**竞技场战术教练插件。监视战斗、推断己方能力和敌方阵容、实时打分敌方目标，并告知你开打谁、何时切换、何时爆发、何时防御。

**Adapts dynamically to any team comp and PvP context** — capability inference (Mortal Strike? Bloodlust? Mass Dispel? Freedom? Cleanse?) drives the strategy, not class hardcodes. Arena uses full comp/chain/profile logic; BG and world PvP use opportunistic nameplate plus hostile-damage discovery, skip brittle comp matching, and keep defensive calls available when the player or a healer-capable friendly is low.

**自适应任意队伍组合与 PvP 场景**——通过能力推理驱动战术（致死打击？嗜血？群驱散？自由祝福？驱散？），而非职业硬编码。竞技场启用完整阵容/控制链/对手档案逻辑；战场与户外 PvP 使用铭牌与受击事件探测敌人，跳过不稳定的阵容匹配，并在玩家或可治疗队友低血量时保留防御建议。

> ⚠️ **This addon never automates gameplay.** It does not cast spells, does not target enemies for you, does not click protected buttons, and does not edit secure macros in combat. Everything it does is visual / audio / text suggestions.
>
> ⚠️ **此插件绝不自动化操作。** 不施法、不切换目标、不点击受保护按钮、不修改安全宏。只提供视觉、音频、文字建议。

---

## Installation / 安装

1. Copy the `ArenaCoachTBC` folder into / 复制 `ArenaCoachTBC` 文件夹到：
   ```
   <WoW>/_classic_/Interface/AddOns/
   ```
2. Restart the client or `/reload`.
   重启客户端或在游戏内执行 `/reload`。
3. If "Out of Date" appears at character select, enable "Load out of date AddOns". Edit `## Interface: 20505` in `ArenaCoachTBC.toc` to match your client to silence the warning.
   若角色选择界面显示 "Out of Date"，启用底部的"载入过期插件"。或编辑 `ArenaCoachTBC.toc` 中的 `## Interface: 20505` 以匹配客户端版本。

The addon stores SavedVariables in `ArenaCoachTBCDB`.
存档变量保存在 `ArenaCoachTBCDB`。

---

## Slash Commands / 命令

| Command | English | 中文 |
|---|---|---|
| `/acc` or `/arenacoach` | alias root | 命令根 |
| `/acc help` | print all commands | 显示所有命令 |
| `/acc toggle` | show / hide the recommendation frame | 显示 / 隐藏提示框 |
| `/acc lock` / `/acc unlock` | lock or unlock the frame for dragging | 锁定 / 解锁框体 |
| `/acc off` / `/acc on` (aliases `/acc disable` / `/acc enable`) | **master switch.** Stops the engine + hides every visual layer. Persists across `/reload`. | **主开关**。停止引擎并隐藏所有视觉层，`/reload` 后保持。 |
| `/acc glow on\|off` | toggle the mode-coloured screen-edge glow (v2.2.0) | 切换屏幕边缘模式着色光晕（v2.2.0） |
| `/acc nameplate on\|off` | toggle the KILL / SWAP target nameplate highlights (v2.2.0) | 切换击杀/换火目标的铭牌高亮（v2.2.0） |
| `/acc test` | arena 7-beat UI demo — paints the full HUD (mode label, target stats, edge glow, nameplate, audio cues) | 竞技场 7 节拍 UI 演示——完整 HUD（模式、信息行、边缘光晕、铭牌、音效） |
| `/acc test bg` | battleground walk-through (flag carrier + low-HP straggler) | 战场演示（夺旗者 + 低血单位） |
| `/acc test world` | world PvP walk-through (single-target focus) | 户外 PvP 演示（单目标聚焦） |
| `/acc test print` | legacy chat-only summary of 5 sample comps | 仅文字摘要（旧行为） |
| `/acc enemy war mage priest druid pala` | simulate a custom enemy comp | 模拟自定义敌方阵容 |
| `/acc debug` | toggle debug logging | 切换调试输出 |
| `/acc reset` | wipe SavedVariables (requires `/reload`) | 清空存档（需 `/reload`） |
| `/acc strategy safe \| balanced \| greedy` | conservative / default / aggressive burst+swap calls | 保守 / 默认 / 激进 模式 |
| `/acc selftest [verbose]` | in-client validation suite | 客户端内自检 |
| `/acc trace [on\|off\|dump\|clear\|status]` | decision-trace ring buffer | 决策追踪环缓冲 |
| `/acc record [on\|off\|dump\|clear\|status]` | CLEU recording for offline replay | CLEU 录制（用于离线重放） |
| `/acc whatif skip <i>` | counterfactual replay (skip event #i) | 反事实重放（跳过事件 #i） |
| `/acc bugreport` | sanitised error report for GitHub issues | 已脱敏的错误报告 |

---

## How it Works / 工作原理

### Dynamic team detection / 动态队伍识别

`OwnComps:Infer(friendlies)` walks your party and returns a capability table — booleans like `hasMortalStrike`, `hasBloodlust`, `hasFreedom`, `hasMassDispel`, `hasCyclone`, `hasMainHealer`, etc. The engine reads capabilities instead of hardcoded class assumptions, so a Hunter/Lock/Druid group gets different advice than a WAR/ENH/RET cleave even against the same RMP.

`OwnComps:Infer(friendlies)` 扫描你的队伍并返回能力布尔表 —— `hasMortalStrike`、`hasBloodlust`、`hasFreedom`、`hasMassDispel`、`hasCyclone`、`hasMainHealer` 等。引擎基于能力而非职业硬编码做判断，所以猎人/术士/德鲁伊队伍面对相同的 RMP 也能收到与 WAR/ENH/RET 不同的建议。

`OwnComps:Identify(friendlies, caps)` then picks an **archetype**: `MELEE_CLEAVE`, `CASTER_CLEAVE`, `DRAIN`, `JUNGLE`, `DOUBLE_HEALER`.

`OwnComps:Identify(friendlies, caps)` 然后选定**原型**：`MELEE_CLEAVE`、`CASTER_CLEAVE`、`DRAIN`、`JUNGLE`、`DOUBLE_HEALER`。

### Enemy comp database / 敌方阵容数据库

`Strategies.comps` contains an expanded catalog of enemy comp signatures.
`Strategies.comps` 包含扩展的敌方阵容特征目录。

```
RMP, WMS, WLD (Warlock+Druid), WLS, WLP (Warlock+Pally drain),
HUNTER_COMP, BEAST_CLEAVE, TSG (Warrior+Pally), RLS, MIRROR_MELEE,
TRIPLE_CASTER, DOUBLE_HEALER, TRIPLE_DPS
```

Each entry may carry an `ownVariants` table so the same enemy comp gives different advice to different own teams:

每个条目可能携带 `ownVariants` 表，使同一敌方阵容对不同的己方队伍给出不同建议：

```lua
{ id = "RMP",
  openTarget = "PRIEST",
  ownVariants = {
      MELEE_CLEAVE = { openTarget = "PRIEST", swapTarget = "MAGE" },
      DRAIN        = { openTarget = nil,     note = "drain mage mana" },
      JUNGLE       = { openTarget = "MAGE",  note = "scatter+fear chain" },
  },
}
```

Entries can also carry an optional `specs = { CLASS = "SPEC" }` map. A spec-keyed comp matches only when every required spec is explicitly observed via spec inference (`enemy.specGuess`). Unknown or mismatched specs disqualify the spec-keyed entry; the engine falls through to the class-only sibling. This lets the catalog separate `RMP_DISC_3V3` (kill-the-disc-priest plan) from `SMR_3V3` (shadow-priest, no-healer pressure) once the priest's spec has been observed.

条目还可附带可选的 `specs = { 职业 = "天赋" }` 字段。天赋特化阵容只有在所有必要天赋通过天赋推理（`enemy.specGuess`）明确观测到才匹配。天赋未知或不符时该条目失效，引擎退回到仅职业匹配的条目。这让目录可区分 `RMP_DISC_3V3`（戒律牧的击杀计划）和 `SMR_3V3`（暗牧无治疗压力）。

### Scoring engine / 打分引擎

`StrategyEngine:Evaluate(state)` scores every alive enemy with a weighted sum (defined in `StrategyEngine.lua > SE.weights`) and returns:

`StrategyEngine:Evaluate(state)` 用加权和（定义在 `StrategyEngine.lua > SE.weights`）为每个存活敌方打分，返回：

```lua
{
  mode                = "OPEN"|"KILL"|"SWAP"|"DEFEND"|"RESET",
  primaryTarget       = "guid-...",
  primaryTargetName   = "Holyman",
  primaryTargetClass  = "PRIEST",
  secondaryTarget     = "guid-...",
  confidence          = 0.0 .. 1.0,
  reason              = "PRIEST [role_healer(25), trinket_down(20), ...]",
  callouts            = { "CALL_HOJ_KILL", "CALL_PURGE", "BURST_NOW" },
  priority            = "LOW"|"MEDIUM"|"HIGH"|"URGENT",
  comp                = "RMP",
  compLabel           = "Rogue / Mage / Priest",
  ownArchetype        = "MELEE_CLEAVE",
  ownArchetypeLabel   = "Melee cleave",
  ownCapabilities     = { hasMortalStrike=true, hasBloodlust=true, ... },
  burstAllowed        = true,
  burstBlockedBy      = nil,
  burstDecision       = { allowed=true, gates={ target_vulnerable={}, ms_active={}, windfury={}, melee_uptime={}, kill_prob={}, chain_ready={} } },
  primaryTargetHp     = 0.37,
  killProb            = 0.82,
}
```

Scoring weights are exposed as a flat table / 打分权重以扁平表暴露：

```lua
SE.weights = {
    role_healer          =  25,
    role_cloth_dps       =  15,
    role_melee_overext   =  10,
    health_below_50      =  30,
    trinket_down         =  20,
    major_defensive_down =  15,
    no_immunity          =  10,
    purgeable_defensive  =  10,
    ms_active            =  25,
    our_hoj_ready        =  15,
    our_bloodlust        =  15,
    windfury_active      =  10,
    priest_can_dispel    =  10,
    off_healer_cc        =  15,
    target_immune        = -100,
    target_unreachable   =  -30,
    target_los_blocked   =  -20,
    melee_locked_down    =  -20,
    our_healer_cc        =  -25,
    our_team_low_hp      =  -30,
}
```

---

## Using ArenaCoachTBC from a WeakAura / 在 WeakAura 中使用

The addon publishes its current recommendation and full state through the global `_G.ArenaCoachTBC`. **The complete API:**

插件通过全局 `_G.ArenaCoachTBC` 发布当前推荐和完整状态。**完整 API：**

| Getter | Returns / 返回 |
|---|---|
| `GetRecommendation()` | full table / 完整推荐表 |
| `GetMode()` | `"KILL" / "SWAP" / ...` |
| `GetPriority()` | `"URGENT" / "HIGH" / ...` |
| `GetReason()` | human-readable reason / 可读理由 |
| `GetConfidence()` | 0 .. 1 |
| `GetPrimaryTarget()` | enemy GUID / 敌方 GUID |
| `GetPrimaryTargetName()` | unit name / 单位名 |
| `GetPrimaryTargetClass()` | "PRIEST" |
| `GetSecondaryTarget()` | swap-candidate GUID / 切换备选 GUID |
| `GetCallouts()` | array of locale keys / 本地化键数组 |
| `IsBurstAllowed()` | true / false |
| `GetBurstBlocker()` | "no_ms" / "target_immune" / nil |
| `GetEnemyComp()` | "RMP" / "WLD" / ... |
| `GetEnemyCompLabel()` | friendly label / 友好标签 |
| `GetCompConfidence()` | 0 .. 1 comp match confidence / 阵容匹配置信度 |
| `GetCompSpecConfirmed()` | true if a spec-keyed comp matched / 是否匹配到天赋特化阵容 |
| `GetOwnComp()` | "MELEE_CLEAVE" / "DRAIN" / ... |
| `GetOwnCompLabel()` | friendly label / 友好标签 |
| `GetCapabilities()` | full capability table / 完整能力表 |
| `HasCapability("hasMortalStrike")` | true / false |
| `GetEnemies()` | full enemies map / 完整敌方表 |
| `GetFriendlies()` | full friendlies map / 完整己方表 |
| `GetEnemyByGUID(guid)` | one enemy / 单个敌方 |
| `GetCombatPhase()` | "PRE" / "ACTIVE" / "POST" |
| `GetVersion()` | "2.7.6" |

### Sample custom trigger / 自定义触发器示例

```lua
function()
    return _G.ArenaCoachTBC
       and _G.ArenaCoachTBC.GetRecommendation
       and _G.ArenaCoachTBC.GetRecommendation() ~= nil
end
```

### Sample custom text / 自定义文本示例

```lua
function()
    local api = _G.ArenaCoachTBC
    if not api or not api.GetRecommendation then return "" end
    local r = api.GetRecommendation()
    if not r then return "" end
    return string.format(
        "%s: %s\n%s\nComp: %s vs %s",
        r.mode or "",
        r.primaryTargetName or r.primaryTargetClass or "",
        r.reason or "",
        r.ownArchetypeLabel or "?", r.compLabel or "?"
    )
end
```

### Capability-driven aura example / 基于能力的光环示例

Only show a "BURST NOW" warning if our team has both MS *and* WF:
仅当我方同时具备 MS 和 WF 时显示 "BURST NOW" 警告：

```lua
function()
    local api = _G.ArenaCoachTBC
    if not api then return false end
    return api.IsBurstAllowed()
       and api.HasCapability("hasMortalStrike")
       and api.HasCapability("hasWindfury")
end
```

### Event-driven trigger / 事件驱动触发器

The addon emits `ACC_RECOMMENDATION` via `WeakAuras.ScanEvents` on every evaluation:

插件每次评估后通过 `WeakAuras.ScanEvents` 发出 `ACC_RECOMMENDATION` 事件：

```lua
-- Trigger: Custom -> Event
-- Event: ACC_RECOMMENDATION
function(event, rec)
    return event == "ACC_RECOMMENDATION" and rec and rec.priority == "URGENT"
end
```

---

## Running the Tests / 运行测试

The headless suite runs outside WoW with stubbed APIs and enforces at least 99% line coverage over production modules.

无头测试套件在 WoW 外运行（已 stub 所需 API），强制要求生产模块行覆盖率不低于 99%。

```bash
lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua && luacov
lua5.1 ArenaCoachTBC/Tests/StrategyEngine_spec.lua
```

`run_all.lua` is the main coverage suite. `StrategyEngine_spec.lua` is a standalone smoke spec and is run separately in CI.

`run_all.lua` 是主覆盖率套件。`StrategyEngine_spec.lua` 是独立冒烟测试，CI 中单独运行。

CI (`.github/workflows/test.yml`) runs this on every PR and enforces a 99% minimum.

CI（`.github/workflows/test.yml`）在每个 PR 上运行此套件并强制 99% 最低覆盖率。

---

## Limitations & Assumptions / 限制与假设

- **Enemy specs are guessed** from class alone unless observed casts reveal otherwise.
  **敌方天赋按职业默认推测**，除非观测到的施法明确揭示。
- **Burst gates depend on observed auras.** Mortal Strike and Windfury are read from live unit auras when the client exposes them; missing aura data keeps burst calls conservative.
  **爆发门禁依赖观测到的光环。** 致死打击和风怒图腾从单位光环读取；光环数据缺失时爆发判断会更保守。
- **Cooldown durations** are conservative TBC 2.4.3 values; edit `CooldownTracker.lua > CT.defaults` for TBC Anniversary tweaks. When unsure, we mark a CD ready rather than block on unknowns.
  **冷却时间**采用 TBC 2.4.3 保守数值；调整 TBC 周年服值时编辑 `CooldownTracker.lua > CT.defaults`。未知情况下默认认为 CD 就绪。
- **DR window** defaults to 17s; tune `DRTracker.lua > DR.resetWindow`.
  **DR 时间窗**默认 17 秒；调整在 `DRTracker.lua > DR.resetWindow`。
- **PvP trinket** uses the shared aura `42292`. Class-specific trinkets need their own IDs.
  **PvP 饰品**使用通用光环 `42292`。职业专属饰品需要单独的 ID。
- **No automation** — by design.
  **无自动化**——刻意为之。

---

## Adding / Adjusting / 扩展 / 调整

- **Spell IDs**: `Data/Spells.lua` is the single source of truth. / **法术 ID**：`Data/Spells.lua` 是唯一权威来源。
- **Enemy comps**: `Data/Strategies.lua` — add a table entry. / **敌方阵容**：`Data/Strategies.lua`——添加表条目。
- **Own archetypes / capabilities**: `Data/OwnComps.lua`. / **己方原型 / 能力**：`Data/OwnComps.lua`。
- **Locales**: `Locales/enUS.lua` and `Locales/zhCN.lua`. / **本地化**：`Locales/enUS.lua` 和 `Locales/zhCN.lua`。

---

## File Layout / 文件结构

```
ArenaCoachTBC/
├── ArenaCoachTBC.toc
├── Core.lua                 -- event wiring + slash commands + state
│                               事件桥接 + 命令 + 状态
├── EventBus.lua             -- tiny pub/sub / 微型发布订阅
├── Data/
│   ├── Spells.lua           -- spell ID database / 法术 ID 数据库
│   ├── Classes.lua          -- class -> role / armor / specs
│   ├── OwnComps.lua         -- capability inference + archetype detection
│   │                           能力推理 + 原型识别
│   └── Strategies.lua       -- enemy comp catalog + ownVariants
│                               敌方阵容目录 + ownVariants
├── StrategyEngine.lua       -- scoring + recommendation / 打分 + 推荐
├── Chain.lua                -- CC chain primitive (DR + CD aware)
│                               控制链基元（DR + CD 感知）
├── CooldownTracker.lua
├── DRTracker.lua
├── UI.lua
├── Options.lua
├── WeakAuraBridge.lua       -- _G.ArenaCoachTBC API
├── Locales/{enUS,zhCN}.lua
├── Tests/
│   ├── test_helpers.lua       (mocks + harness)
│   ├── run_all.lua            (runs every spec in one process)
│   └── *_spec.lua             (headless specs)
└── README.md
```

---

## License / 许可证

MIT.
