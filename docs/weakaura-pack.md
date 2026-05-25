# WeakAura templates for ArenaCoachTBC / WeakAura 模板

ArenaCoachTBC publishes its current recommendation through the global `_G.ArenaCoachTBC` API (the `WeakAuraBridge` module). WeakAuras consume that surface directly. **Two paths**, pick whichever fits your workflow:

ArenaCoachTBC 通过全局 `_G.ArenaCoachTBC` API（`WeakAuraBridge` 模块）发布当前推荐。WeakAuras 直接消费这个表面。**两种方式**，按你的工作流挑选：

## Path 1 · Paste-ready import strings (recommended) / 路径 1 · 直接导入字符串（推荐）

Open **[`weakaura-imports.md`](weakaura-imports.md)** for 5 generated `!WA:2!...` strings. Open WeakAuras, click **Import**, paste, done.

打开 **[`weakaura-imports.md`](weakaura-imports.md)** 获取 5 个生成好的 `!WA:2!...` 字符串。打开 WeakAuras，点击 **Import**，粘贴即可。

Strings are produced by `tools/export_weakauras.mjs` (node-weakauras-parser + LibSerialize + LibDeflate) so you can regenerate them after editing the source templates:

字符串由 `tools/export_weakauras.mjs` 生成（node-weakauras-parser + LibSerialize + LibDeflate），所以修改源模板后可重新生成：

```bash
cd tools && npm install        # one time / 一次性
node export_weakauras.mjs      # writes docs/weakaura-imports.md / 写入 docs/weakaura-imports.md
```

## Path 2 · Trigger-code snippets (DIY) / 路径 2 · 触发器代码片段（手动）

What follows is the *trigger code* you paste into a manually-created WA — the same lookup logic the auto-generated strings install. Use this when you want to combine a template with your own custom display, or when you'd rather hand-build the WA in the UI.

下面是你手动创建 WA 时需要粘贴的*触发器代码*——与自动生成字符串安装的逻辑相同。当你想把模板与自己的自定义显示结合，或者偏好在 UI 内手动构建 WA 时使用此方式。

## Installation (one-time) / 安装（一次性）

1. `/wa` to open WeakAuras / 打开 WeakAuras
2. New → Icon (or Text, or Progress Bar — depending on the template below) / 新建 → Icon（或 Text / Progress Bar，按模板需要）
3. Trigger → Custom → **Type: Status** for per-tick polling templates, or **Type: Event** for change-only templates / 触发器 → Custom → **Status** 型（轮询）或 **Event** 型（变更触发）
4. Paste the **Trigger** function. Paste **Untrigger** if listed / 粘贴 **Trigger** 函数；如有 **Untrigger** 也一并粘贴
5. (For Text displays) paste the **Custom Text** function / （文字类型）粘贴 **Custom Text** 函数
6. Set **Check On** = `Every Frame` for Status, or list the events for Event / Status 设为 `Every Frame`；Event 列出事件

The public bridge API (also in `ArenaCoachTBC/WeakAuraBridge.lua`) / 公开桥接 API（同时也在 `ArenaCoachTBC/WeakAuraBridge.lua` 中）：

| Getter | Returns |
|---|---|
| `_G.ArenaCoachTBC.GetMode()` | `"OPEN"` / `"KILL"` / `"SWAP"` / `"DEFEND"` / `"RESET"` |
| `_G.ArenaCoachTBC.GetPriority()` | `"LOW"` / `"MEDIUM"` / `"HIGH"` / `"URGENT"` |
| `_G.ArenaCoachTBC.GetPrimaryTargetClass()` | `"WARRIOR"`, etc. |
| `_G.ArenaCoachTBC.GetPrimaryTargetName()` | string |
| `_G.ArenaCoachTBC.GetSecondaryTargetClass()` | string |
| `_G.ArenaCoachTBC.GetReason()` | short string |
| `_G.ArenaCoachTBC.GetCallouts()` | array of locale keys |
| `_G.ArenaCoachTBC.GetEnemyComp()` | comp id, e.g. `"RMP_3V3"` |
| `_G.ArenaCoachTBC.GetOwnComp()` | archetype, e.g. `"MELEE_CLEAVE"` |
| `_G.ArenaCoachTBC.GetBracket()` | `2` / `3` / `5` |
| `_G.ArenaCoachTBC.GetCombatPhase()` | `"PRE"` / `"ACTIVE"` / `"POST"` |
| `_G.ArenaCoachTBC.IsBurstAllowed()` | bool |
| `_G.ArenaCoachTBC.GetVersion()` | semver string |

---

## Template 1 — Mode badge (Text)

A single text element that displays the current mode in a colour-coded
overlay. Shows nothing outside arena.

**Trigger (Status):**
```lua
function()
    if not _G.ArenaCoachTBC then return false end
    local mode = _G.ArenaCoachTBC.GetMode()
    return mode ~= nil and mode ~= "RESET"
end
```

**Custom Text (`%1`):**
```lua
function()
    if not _G.ArenaCoachTBC then return "" end
    local mode = _G.ArenaCoachTBC.GetMode() or "?"
    local cls  = _G.ArenaCoachTBC.GetPrimaryTargetClass() or ""
    return mode .. (cls ~= "" and (" → " .. cls) or "")
end
```

**Color (Custom Function in conditions):**
```lua
function()
    local p = _G.ArenaCoachTBC and _G.ArenaCoachTBC.GetPriority()
    if p == "URGENT" then return 1, 0.2, 0.2, 1 end  -- red
    if p == "HIGH"   then return 1, 0.6, 0.0, 1 end  -- orange
    if p == "MEDIUM" then return 1, 1.0, 0.4, 1 end  -- yellow
    return 0.9, 0.9, 0.9, 1                           -- white
end
```

---

## Template 2 — Burst gate (Icon)

Shows a spell-icon glow only when the engine says it's safe to burst.
Useful to overlay onto Bloodlust / Avenging Wrath / Death Wish.

**Trigger (Status):**
```lua
function()
    return _G.ArenaCoachTBC and _G.ArenaCoachTBC.IsBurstAllowed() == true
end
```

**Untrigger:**
```lua
function() return true end
```

Set **Display → Icon** to your burst spell ID and add a Glow animation on
trigger.

---

## Template 3 — Defensive alert (Group)

A flashing overlay only when mode is `DEFEND`. The engine flips DEFEND on
several signals (low healer HP, healer CC'd, enemy lust, train detection),
so this catches them all.

**Trigger (Status):**
```lua
function()
    return _G.ArenaCoachTBC and _G.ArenaCoachTBC.GetMode() == "DEFEND"
end
```

**Custom Text:**
```lua
function()
    if not _G.ArenaCoachTBC then return "" end
    return "DEFEND: " .. (_G.ArenaCoachTBC.GetReason() or "")
end
```

Pair with an Animation → Pulse on trigger.

---

## Template 4 — Callout list (Text Area)

Renders the current callout array as a stacked list.

**Trigger (Status):**
```lua
function()
    if not _G.ArenaCoachTBC then return false end
    local list = _G.ArenaCoachTBC.GetCallouts() or {}
    return #list > 0
end
```

**Custom Text:**
```lua
function()
    if not _G.ArenaCoachTBC then return "" end
    local list = _G.ArenaCoachTBC.GetCallouts() or {}
    -- Translate via the addon's own locale resolver if you want zh strings:
    local L = _G.ArenaCoachTBC.L or function(k) return k end
    local out = {}
    for i = 1, math.min(#list, 4) do table.insert(out, "- " .. L(list[i])) end
    return table.concat(out, "\n")
end
```

---

## Template 5 — Comp readout (Text)

Single line showing the identified enemy + own comp. Stable across the
match; flips when spec inference reclassifies an enemy.

**Trigger (Status):**
```lua
function()
    return _G.ArenaCoachTBC and _G.ArenaCoachTBC.GetEnemyComp() ~= nil
end
```

**Custom Text:**
```lua
function()
    if not _G.ArenaCoachTBC then return "" end
    return string.format("%s vs %s (%dv%d)",
        _G.ArenaCoachTBC.GetOwnComp() or "?",
        _G.ArenaCoachTBC.GetEnemyComp() or "?",
        _G.ArenaCoachTBC.GetBracket() or 5,
        _G.ArenaCoachTBC.GetBracket() or 5)
end
```

---

## Notes

- **Polling vs events.** The bridge is updated every time `Core:Evaluate()`
  runs, which is roughly on every CLEU event of interest. Polling via WA's
  Status trigger every frame is cheap because each getter is a single
  table lookup.
- **Localisation.** Callouts come back as locale keys (`CALL_HOJ_KILL` etc).
  Use `_G.ArenaCoachTBC.L(key)` to resolve to the active locale.
- **Versioning.** `_G.ArenaCoachTBC.GetVersion()` returns the running addon
  version. If you're shipping a WA pack publicly, gate on this to avoid
  rendering on incompatible builds.

If you build a WA you'd like included in the official pack, open a PR
attaching the import string (a `!WA:2!...` snippet) and a screenshot.
