# WeakAura templates for ArenaCoachTBC

ArenaCoachTBC publishes its current recommendation through the global `_G.ArenaCoachTBC` API (the `WeakAuraBridge` module). WeakAuras consume that surface directly.

> **Why no paste-ready import strings anymore?** v2.0–v2.2.5 shipped a `tools/export_weakauras.mjs` exporter that generated `!WA:2!...` paste strings. Removed in v2.2.6 after the underlying `node-weakauras-parser` library was confirmed to produce strings that decode correctly but fail WeakAuras' import-validator byte check — the import preview dialog never even shows the Import button. After 6 patch versions chasing schema gaps (internalVersion, version=3, semver, config/information shape) we concluded the parser is the wrong tool. See the v2.2.6 CHANGELOG entry for the full diagnostic. The trigger snippets below are the supported route — paste them into a hand-built WeakAura via the in-game UI.

## Triggers + custom text — paste into a hand-built WA

What follows is the *trigger code* you paste into a manually-created WA. Use this to combine a template with your own custom display, or because you'd rather hand-build the WA in the UI than wrestle with a paste string.

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

A steady defensive badge only when mode is `DEFEND`. The engine flips DEFEND
on several signals (low healer HP, healer CC'd, enemy lust, train detection),
so this catches them all without strobing over the arena.

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

Pair with a glow border if you want extra visibility.

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
