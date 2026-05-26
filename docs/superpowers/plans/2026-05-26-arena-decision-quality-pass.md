# Arena Decision Quality Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve rated-arena recommendation trust across 2v2, 3v3, and 5v5 by fixing known decision misses, HUD comprehension gaps, and burst-ready gating.

**Architecture:** Keep the existing boundary: `Core.lua` gathers WoW state, `StrategyEngine.lua` makes pure decisions, `Data/Strategies.lua` holds matchup data, and `UI.lua` renders the recommendation. Changes are small and test-backed: adjust dynamic comp detection, bracket scoring, data-driven active targets, recommendation fields, callout formatting, and burst gating.

**Tech Stack:** Lua 5.1 WoW addon code, headless Lua specs in `ArenaCoachTBC/Tests/`, locale parity tooling in `tools/check_locales.lua`, luacov coverage.

---

## File Structure

- Modify: `ArenaCoachTBC/StrategyEngine.lua`
  - Owns target scoring, mode selection, burst callout decision, recommendation shape, and `BuildTestState`.
- Modify: `ArenaCoachTBC/Data/Strategies.lua`
  - Owns comp identification and data-driven matchup targets.
- Modify: `ArenaCoachTBC/UI.lua`
  - Owns top callout rendering and target stats display.
- Modify: `ArenaCoachTBC/Locales/enUS.lua`
  - Adds one UI fallback string used by formatted callout rendering.
- Modify: `ArenaCoachTBC/Locales/zhCN.lua`
  - Adds the zhCN counterpart for locale parity.
- Modify: `ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua`
  - Adds engine-level regression tests for arena decisions and burst gating.
- Modify: `ArenaCoachTBC/Tests/UI_spec.lua`
  - Adds HUD callout formatting regression tests.
- Modify: `ArenaCoachTBC/Tests/Benchmark_spec.lua`
  - Raises the arena benchmark floor after known misses are fixed.
- Modify: `CHANGELOG.md`
  - Documents the quality pass under `[Unreleased]`.

## Task 1: Stop 2v2 Double-DPS And Hybrid Openers From Becoming Fake `DEFEND`

**Files:**
- Modify: `ArenaCoachTBC/Data/Strategies.lua`
- Modify: `ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua`

- [ ] **Step 1: Add failing regression tests**

Append these tests near the existing StrategyEngine arena regression tests in `ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua`:

```lua
H.it(g, "arena quality: 2v2 Warrior/Paladin pre-gates opens paladin instead of fake DEFEND", function()
    local state = SE:BuildTestState({ "WARRIOR", "PALADIN" })
    state.combatPhase = "PRE"
    state.bracket = 2
    state.pvpContext = "arena"

    local rec = SE:Evaluate(state)

    H.assertEq(rec.mode, "OPEN", "2v2 warrior/paladin should produce opener guidance")
    H.assertEq(rec.primaryTargetClass, "PALADIN", "paladin is the planned opener target")
end)

H.it(g, "arena quality: 2v2 Hunter/Warrior pre-gates opens hunter instead of fake DEFEND", function()
    local state = SE:BuildTestState({ "HUNTER", "WARRIOR" })
    state.combatPhase = "PRE"
    state.bracket = 2
    state.pvpContext = "arena"

    local rec = SE:Evaluate(state)

    H.assertEq(rec.mode, "OPEN", "2v2 hunter/warrior should produce opener guidance")
    H.assertEq(rec.primaryTargetClass, "HUNTER", "hunter is the planned opener target")
end)
```

- [ ] **Step 2: Run the focused spec and verify it fails**

Run:

```bash
lua5.1 -e 'local H=dofile("ArenaCoachTBC/Tests/test_helpers.lua"); H.ADDON_DIR="ArenaCoachTBC"; H.installStubs(); _G.__ACC_TEST_HELPERS=H; dofile("ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua"); local ok=H.run(); os.exit(ok and 0 or 1)'
```

Expected: FAIL. The first new test should report `expected OPEN, got DEFEND`; the second should also report `expected OPEN, got DEFEND`.

- [ ] **Step 3: Narrow dynamic `TRIPLE_DPS` detection to actual 3+ DPS teams**

In `ArenaCoachTBC/Data/Strategies.lua`, replace the dynamic role-count block:

```lua
    if healers == 0 then
        for _, comp in ipairs(self.comps) do
            if comp.dynamic == "TRIPLE_DPS" and bracketMatches(comp) then return comp, 1.0 end
        end
    end
```

with:

```lua
    if healers == 0 and dps >= 3 then
        for _, comp in ipairs(self.comps) do
            if comp.dynamic == "TRIPLE_DPS" and bracketMatches(comp) then return comp, 1.0 end
        end
    end
```

- [ ] **Step 4: Run the focused spec and verify it passes**

Run:

```bash
lua5.1 -e 'local H=dofile("ArenaCoachTBC/Tests/test_helpers.lua"); H.ADDON_DIR="ArenaCoachTBC"; H.installStubs(); _G.__ACC_TEST_HELPERS=H; dofile("ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua"); local ok=H.run(); os.exit(ok and 0 or 1)'
```

Expected: PASS for the two new tests and the existing StrategyEngine extra tests.

- [ ] **Step 5: Commit**

```bash
git add ArenaCoachTBC/Data/Strategies.lua ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua
git commit -m "fix: stop double-dps openers becoming defend calls"
```

## Task 2: Make 2v2 Low-HP Kill Windows Beat Generic Healer Bias

**Files:**
- Modify: `ArenaCoachTBC/StrategyEngine.lua`
- Modify: `ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua`

- [ ] **Step 1: Add the failing shatter 2v2 regression test**

Append this test in `ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua` near other bracket scoring tests:

```lua
H.it(g, "arena quality: 2v2 shatter kills the low mage over generic priest bias", function()
    local state = SE:BuildTestState({ "MAGE", "PRIEST" })
    state.combatPhase = "ACTIVE"
    state.bracket = 2
    state.pvpContext = "arena"

    for _, enemy in pairs(state.enemies) do
        if enemy.class == "MAGE" then
            enemy.healthPct = 25
        end
    end

    local rec = SE:Evaluate(state)

    H.assertEq(rec.mode, "KILL")
    H.assertEq(rec.primaryTargetClass, "MAGE", "low mage should be the kill window")
end)
```

- [ ] **Step 2: Run the focused spec and verify it fails**

Run:

```bash
lua5.1 -e 'local H=dofile("ArenaCoachTBC/Tests/test_helpers.lua"); H.ADDON_DIR="ArenaCoachTBC"; H.installStubs(); _G.__ACC_TEST_HELPERS=H; dofile("ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua"); local ok=H.run(); os.exit(ok and 0 or 1)'
```

Expected: FAIL with `expected MAGE, got PRIEST`.

- [ ] **Step 3: Increase 2v2 low-HP vulnerability weighting**

In `ArenaCoachTBC/StrategyEngine.lua`, change the 2v2 bracket override:

```lua
    [2] = { role_healer = 40, role_cloth_dps = 18 },
```

to:

```lua
    [2] = { role_healer = 40, role_cloth_dps = 18, health_below_50 = 40 },
```

- [ ] **Step 4: Run the focused spec and verify it passes**

Run:

```bash
lua5.1 -e 'local H=dofile("ArenaCoachTBC/Tests/test_helpers.lua"); H.ADDON_DIR="ArenaCoachTBC"; H.installStubs(); _G.__ACC_TEST_HELPERS=H; dofile("ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua"); local ok=H.run(); os.exit(ok and 0 or 1)'
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ArenaCoachTBC/StrategyEngine.lua ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua
git commit -m "fix: prioritize 2v2 low-health kill windows"
```

## Task 3: Add Data-Driven Active Kill Targets For Matchups That Need Them

**Files:**
- Modify: `ArenaCoachTBC/Data/Strategies.lua`
- Modify: `ArenaCoachTBC/StrategyEngine.lua`
- Modify: `ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua`

- [ ] **Step 1: Add the failing WLP drain 2v2 regression test**

Append this test in `ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua`:

```lua
H.it(g, "arena quality: WLP drain 2v2 kills paladin as the active matchup plan", function()
    local state = SE:BuildTestState({ "WARLOCK", "PALADIN" })
    state.combatPhase = "ACTIVE"
    state.bracket = 2
    state.pvpContext = "arena"

    local rec = SE:Evaluate(state)

    H.assertEq(rec.mode, "KILL")
    H.assertEq(rec.primaryTargetClass, "PALADIN", "drain matchup plan should target paladin")
end)
```

- [ ] **Step 2: Run the focused spec and verify it fails**

Run:

```bash
lua5.1 -e 'local H=dofile("ArenaCoachTBC/Tests/test_helpers.lua"); H.ADDON_DIR="ArenaCoachTBC"; H.installStubs(); _G.__ACC_TEST_HELPERS=H; dofile("ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua"); local ok=H.run(); os.exit(ok and 0 or 1)'
```

Expected: FAIL with `expected PALADIN, got WARLOCK`.

- [ ] **Step 3: Document the new strategy field**

In the comment block at the top of `ArenaCoachTBC/Data/Strategies.lua`, after the `swapTarget` description, add this line:

```lua
--   killTarget  : class to bias as the active KILL target when the matchup
--                 plan differs from generic role/armor scoring
```

- [ ] **Step 4: Add `killTarget` to the WLP comp**

In `ArenaCoachTBC/Data/Strategies.lua`, update the `WLP` entry from:

```lua
        openTarget = "PALADIN",
        swapTarget = "WARLOCK",
```

to:

```lua
        openTarget = "PALADIN",
        swapTarget = "WARLOCK",
        killTarget = "PALADIN",
```

- [ ] **Step 5: Add a scoring weight for active kill targets**

In `ArenaCoachTBC/StrategyEngine.lua`, add this weight next to the existing comp target weights:

```lua
    comp_kill_target     =  35,
```

The surrounding block should read:

```lua
    off_healer_cc        =  15,
    comp_open_target     =  20,
    comp_swap_target     =  10,
    comp_kill_target     =  35,
```

- [ ] **Step 6: Score `killTarget` during active phases**

In `ArenaCoachTBC/StrategyEngine.lua`, after the existing `comp_swap_target` scoring block:

```lua
    if comp and comp.swapTarget and phase ~= "PRE" and cfg.allowDpsSwap ~= false
       and enemy.class == comp.swapTarget then
        add(w.comp_swap_target, "comp_swap_target")
    end
```

add:

```lua
    if comp and comp.killTarget and phase ~= "PRE" and enemy.class == comp.killTarget then
        add(w.comp_kill_target, "comp_kill_target")
    end
```

- [ ] **Step 7: Run the focused spec and verify it passes**

Run:

```bash
lua5.1 -e 'local H=dofile("ArenaCoachTBC/Tests/test_helpers.lua"); H.ADDON_DIR="ArenaCoachTBC"; H.installStubs(); _G.__ACC_TEST_HELPERS=H; dofile("ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua"); local ok=H.run(); os.exit(ok and 0 or 1)'
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add ArenaCoachTBC/Data/Strategies.lua ArenaCoachTBC/StrategyEngine.lua ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua
git commit -m "fix: honor active matchup kill targets"
```

## Task 4: Populate `primaryTargetHp` From `healthPct`

**Files:**
- Modify: `ArenaCoachTBC/StrategyEngine.lua`
- Modify: `ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua`

- [ ] **Step 1: Add the failing HP propagation test**

Append this test in `ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua`:

```lua
H.it(g, "arena quality: recommendation primaryTargetHp is populated from healthPct", function()
    local state = SE:BuildTestState({ "ROGUE", "MAGE", "PRIEST" })
    state.combatPhase = "ACTIVE"
    state.bracket = 3
    state.pvpContext = "arena"

    for _, enemy in pairs(state.enemies) do
        if enemy.class == "PRIEST" then
            enemy.healthPct = 10
        end
    end

    local rec = SE:Evaluate(state)

    H.assertEq(rec.primaryTargetClass, "PRIEST")
    H.assertEq(rec.primaryTargetHp, 0.10, "healthPct=10 should become 0.10 for the HUD")
end)
```

- [ ] **Step 2: Run the focused spec and verify it fails**

Run:

```bash
lua5.1 -e 'local H=dofile("ArenaCoachTBC/Tests/test_helpers.lua"); H.ADDON_DIR="ArenaCoachTBC"; H.installStubs(); _G.__ACC_TEST_HELPERS=H; dofile("ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua"); local ok=H.run(); os.exit(ok and 0 or 1)'
```

Expected: FAIL with `expected 0.1, got nil`.

- [ ] **Step 3: Read `healthPct` when building the recommendation**

In `ArenaCoachTBC/StrategyEngine.lua`, replace:

```lua
    if topTarget then
        if topTarget.hpPct then
            primaryTargetHp = topTarget.hpPct
        elseif topTarget.hp and topTarget.hpMax and topTarget.hpMax > 0 then
            primaryTargetHp = topTarget.hp / topTarget.hpMax
        end
    end
```

with:

```lua
    if topTarget then
        if type(topTarget.hpPct) == "number" then
            primaryTargetHp = topTarget.hpPct
        elseif type(topTarget.healthPct) == "number" then
            primaryTargetHp = math.max(0, math.min(1, topTarget.healthPct / 100))
        elseif topTarget.hp and topTarget.hpMax and topTarget.hpMax > 0 then
            primaryTargetHp = math.max(0, math.min(1, topTarget.hp / topTarget.hpMax))
        end
    end
```

- [ ] **Step 4: Run the focused spec and verify it passes**

Run:

```bash
lua5.1 -e 'local H=dofile("ArenaCoachTBC/Tests/test_helpers.lua"); H.ADDON_DIR="ArenaCoachTBC"; H.installStubs(); _G.__ACC_TEST_HELPERS=H; dofile("ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua"); local ok=H.run(); os.exit(ok and 0 or 1)'
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ArenaCoachTBC/StrategyEngine.lua ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua
git commit -m "fix: expose target health percentage to HUD"
```

## Task 5: Render Formatted Callouts Without Raw `%s`

**Files:**
- Modify: `ArenaCoachTBC/UI.lua`
- Modify: `ArenaCoachTBC/Locales/enUS.lua`
- Modify: `ArenaCoachTBC/Locales/zhCN.lua`
- Modify: `ArenaCoachTBC/Tests/UI_spec.lua`

- [ ] **Step 1: Add a failing UI regression test**

Append this test in `ArenaCoachTBC/Tests/UI_spec.lua` near the other `Apply` tests:

```lua
H.it(g, "arena quality: formatted top callout renders with target name instead of raw percent-s", function()
    _G.ArenaCoachTBCDB = {
        enabled = true, locked = false, language = "auto",
        frame = { point = "CENTER", x = 0, y = 120, scale = 1.0, verbose = false },
        alerts = { sound = false, screenFlash = false, edgeGlow = false, nameplate = false },
        strategy = {}, debug = false,
    }
    UI:CreateFrame()
    UI._calloutLastShown = {}
    H.advanceTime(5)

    UI:Apply({
        mode = "KILL",
        primaryTargetName = "Holyman",
        primaryTargetClass = "PRIEST",
        callouts = { "CALL_PURGE" },
        priority = "HIGH",
        _forceShow = true,
    })

    local text = UI.frame.subText:GetText()
    H.assertTrue(text:find("Holyman", 1, true) ~= nil, "formatted callout should include target name")
    H.assertTrue(text:find("%%s") == nil, "formatted callout must not leak raw %s")
end)
```

- [ ] **Step 2: Run the focused UI spec and verify it fails**

Run:

```bash
lua5.1 -e 'local H=dofile("ArenaCoachTBC/Tests/test_helpers.lua"); H.ADDON_DIR="ArenaCoachTBC"; H.installStubs(); _G.__ACC_TEST_HELPERS=H; H.load("Locales/enUS.lua"); H.load("Data/Spells.lua"); H.load("Data/Classes.lua"); H.load("Core.lua"); dofile("ArenaCoachTBC/Tests/UI_spec.lua"); local ok=H.run(); os.exit(ok and 0 or 1)'
```

Expected: FAIL because `CALL_PURGE` renders as `Purge %s`.

- [ ] **Step 3: Add a localized target fallback key**

In `ArenaCoachTBC/Locales/enUS.lua`, add this key near the existing `UI_*` keys:

```lua
    UI_TARGET_FALLBACK   = "target",
```

In `ArenaCoachTBC/Locales/zhCN.lua`, add the same key in the corresponding `UI_*` section:

```lua
    UI_TARGET_FALLBACK   = "目标",
```

- [ ] **Step 4: Add a callout text formatter**

In `ArenaCoachTBC/UI.lua`, after `calloutIcon`, add:

```lua
local function calloutText(key, recommendation)
    local text = L(key)
    if key == "CALL_PURGE" then
        local target = recommendation
            and (recommendation.primaryTargetName or recommendation.primaryTargetClass)
            or nil
        target = target or L("UI_TARGET_FALLBACK")
        local ok, formatted = pcall(string.format, text, target)
        if ok then return formatted end
    end
    return (text:gsub("%%s", L("UI_TARGET_FALLBACK")))
end
```

- [ ] **Step 5: Use `calloutText` in quiet and verbose callout rendering**

In `ArenaCoachTBC/UI.lua`, replace both instances of:

```lua
L(key)
```

inside the verbose callout formatting block with:

```lua
calloutText(key, recommendation)
```

and replace this quiet-mode callout line:

```lua
                    string.format("%s  %s", calloutIcon(top, 18), L(top)))
```

with:

```lua
                    string.format("%s  %s", calloutIcon(top, 18), calloutText(top, recommendation)))
```

The verbose block should contain:

```lua
                    table.insert(subParts,
                        string.format("%s  %s", calloutIcon(key, 18), calloutText(key, recommendation)))
```

- [ ] **Step 6: Run UI and locale checks**

Run:

```bash
lua5.1 -e 'local H=dofile("ArenaCoachTBC/Tests/test_helpers.lua"); H.ADDON_DIR="ArenaCoachTBC"; H.installStubs(); _G.__ACC_TEST_HELPERS=H; H.load("Locales/enUS.lua"); H.load("Data/Spells.lua"); H.load("Data/Classes.lua"); H.load("Core.lua"); dofile("ArenaCoachTBC/Tests/UI_spec.lua"); local ok=H.run(); os.exit(ok and 0 or 1)'
lua5.1 tools/check_locales.lua
```

Expected: both commands PASS.

- [ ] **Step 7: Commit**

```bash
git add ArenaCoachTBC/UI.lua ArenaCoachTBC/Locales/enUS.lua ArenaCoachTBC/Locales/zhCN.lua ArenaCoachTBC/Tests/UI_spec.lua
git commit -m "fix: format HUD callouts with target context"
```

## Task 6: Require `BurstDecision.allowed` Before Showing `BURST_NOW`

**Files:**
- Modify: `ArenaCoachTBC/StrategyEngine.lua`
- Modify: `ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua`

- [ ] **Step 1: Add the failing burst-gate regression test**

Append this test in `ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua` near the existing `BurstDecision` tests:

```lua
H.it(g, "arena quality: BURST_NOW is suppressed when BurstDecision blocks kill probability", function()
    local state = SE:BuildTestState({ "ROGUE", "MAGE", "PRIEST" }, {
        observations = { hojReady = true, windfuryActive = true },
        config = { strategy = { callBurstOnlyWhenMSActive = false, requireWindfuryNearby = true } },
    })
    state.combatPhase = "ACTIVE"
    state.bracket = 3
    state.pvpContext = "arena"

    for _, enemy in pairs(state.enemies) do
        enemy.healthPct = 100
        enemy.hasTrinket = true
        enemy.importantBuffs = {}
    end

    local rec = SE:Evaluate(state)

    H.assertEq(rec.mode, "KILL")
    H.assertEq(rec.burstDecision.blockedBy, "kill_prob")
    H.assertFalse(rec.burstAllowed, "legacy hard gates are not enough for burst-ready display")
    for _, callout in ipairs(rec.callouts or {}) do
        H.assertNotEq(callout, "BURST_NOW", "BURST_NOW should not appear when BurstDecision blocks")
    end
end)
```

- [ ] **Step 2: Run the focused spec and verify it fails**

Run:

```bash
lua5.1 -e 'local H=dofile("ArenaCoachTBC/Tests/test_helpers.lua"); H.ADDON_DIR="ArenaCoachTBC"; H.installStubs(); _G.__ACC_TEST_HELPERS=H; dofile("ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua"); local ok=H.run(); os.exit(ok and 0 or 1)'
```

Expected: FAIL because `rec.burstAllowed` is true and `BURST_NOW` is present even though `BurstDecision.blockedBy == "kill_prob"`.

- [ ] **Step 3: Move chain selection before burst callout insertion**

In `ArenaCoachTBC/StrategyEngine.lua`, move the full `-- M8 #61: chain scoring` block so it appears before the `-- Burst guidance` block.

The local variable declaration must remain:

```lua
    local pickedChain = nil
```

and after the moved block, the burst guidance section must be able to read `pickedChain`.

- [ ] **Step 4: Replace burst guidance with combined legacy and BurstDecision gating**

In `ArenaCoachTBC/StrategyEngine.lua`, replace:

```lua
    -- Burst guidance
    local burstOK, burstWhy = burstAllowed(state, topTarget)
    if mode == "KILL" and burstOK then
        table.insert(callouts, "BURST_NOW")
    end
```

with:

```lua
    -- Burst guidance. Legacy hard gates catch immediate "do not press"
    -- states; BurstDecision adds kill-probability, chain, pressure, and
    -- aggression-aware gates. The HUD should show BURST_NOW only when
    -- both layers agree.
    local legacyBurstOK, burstWhy = burstAllowed(state, topTarget)
    local burstDecision = (mode == "KILL") and self:BurstDecision(state, topTarget, pickedChain) or nil
    local burstOK = legacyBurstOK and ((not burstDecision) or burstDecision.allowed)
    if mode == "KILL" and burstOK then
        table.insert(callouts, "BURST_NOW")
    end
```

- [ ] **Step 5: Return the precomputed burst decision**

In the recommendation table in `ArenaCoachTBC/StrategyEngine.lua`, replace:

```lua
        burstDecision   = (mode == "KILL") and self:BurstDecision(state, topTarget, pickedChain) or nil,
```

with:

```lua
        burstDecision   = burstDecision,
```

Keep:

```lua
        burstAllowed    = burstOK,
        burstBlockedBy  = (not burstOK) and burstWhy or nil,
```

- [ ] **Step 6: Run the focused spec and verify it passes**

Run:

```bash
lua5.1 -e 'local H=dofile("ArenaCoachTBC/Tests/test_helpers.lua"); H.ADDON_DIR="ArenaCoachTBC"; H.installStubs(); _G.__ACC_TEST_HELPERS=H; dofile("ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua"); local ok=H.run(); os.exit(ok and 0 or 1)'
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add ArenaCoachTBC/StrategyEngine.lua ArenaCoachTBC/Tests/StrategyEngine_extra_spec.lua
git commit -m "fix: gate burst callouts on burst decision"
```

## Task 7: Raise The Rated-Arena Benchmark Floor

**Files:**
- Modify: `ArenaCoachTBC/Tests/Benchmark_spec.lua`

- [ ] **Step 1: Confirm the benchmark now reports at least 85%**

Run:

```bash
lua5.1 -e 'local H=dofile("ArenaCoachTBC/Tests/test_helpers.lua"); H.ADDON_DIR="ArenaCoachTBC"; H.installStubs(); _G.__ACC_TEST_HELPERS=H; dofile("ArenaCoachTBC/Tests/Benchmark_spec.lua"); local ok=H.run(); os.exit(ok and 0 or 1)'
```

Expected: PASS with `[BENCHMARK] agreement:` at or above `85%`.

- [ ] **Step 2: Raise the floor in the benchmark assertion**

In `ArenaCoachTBC/Tests/Benchmark_spec.lua`, replace:

```lua
    -- Soft floor: 50% so this is informational, not a hard CI gate. M12's
    -- calibration / tuning work is what raises the engine's score.
    H.assertTrue(rate >= 0.50,
        string.format("benchmark agreement %.0f%% is below the 50%% soft floor", rate * 100))
```

with:

```lua
    -- Rated-arena trust floor. The benchmark is still not a complete
    -- labelled dataset, but known obvious arena misses should now fail CI.
    H.assertTrue(rate >= 0.85,
        string.format("benchmark agreement %.0f%% is below the 85%% rated-arena floor", rate * 100))
```

- [ ] **Step 3: Run the benchmark again**

Run:

```bash
lua5.1 -e 'local H=dofile("ArenaCoachTBC/Tests/test_helpers.lua"); H.ADDON_DIR="ArenaCoachTBC"; H.installStubs(); _G.__ACC_TEST_HELPERS=H; dofile("ArenaCoachTBC/Tests/Benchmark_spec.lua"); local ok=H.run(); os.exit(ok and 0 or 1)'
```

Expected: PASS with the new 85% floor.

- [ ] **Step 4: Commit**

```bash
git add ArenaCoachTBC/Tests/Benchmark_spec.lua
git commit -m "test: raise rated-arena benchmark floor"
```

## Task 8: Document The Quality Pass

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add the changelog entry**

Under `## [Unreleased]` in `CHANGELOG.md`, add:

```markdown
### Fixed
- Rated-arena decision quality pass: corrected 2v2 pre-gate double-DPS opener handling, strengthened low-HP 2v2 kill-window priority, added data-driven active kill targets for matchups such as WLP drain, restored target HP display from `healthPct`, formatted target-aware HUD callouts without raw `%s`, and gated `BURST_NOW` on the full `BurstDecision`.

### Tests
- Added rated-arena regression coverage for the known benchmark misses and raised the benchmark floor to 85%.
```

- [ ] **Step 2: Review changelog placement**

Run:

```bash
sed -n '1,60p' CHANGELOG.md
```

Expected: `[Unreleased]` contains the new `Fixed` and `Tests` bullets before the `2.7.3` section.

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: document arena decision quality pass"
```

## Task 9: Full Verification

**Files:**
- No source edits expected.

- [ ] **Step 1: Run full test suite with coverage instrumentation**

Run:

```bash
lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua
```

Expected: `Results: 614 passed, 0 failed` or a higher pass count if new tests increased the total.

- [ ] **Step 2: Generate and check coverage**

Run:

```bash
luacov && tail -n 20 luacov.report.out
```

Expected: total coverage remains at or above 99%.

- [ ] **Step 3: Run locale parity**

Run:

```bash
lua5.1 tools/check_locales.lua
```

Expected: command exits 0 and reports locale parity.

- [ ] **Step 4: Run the standalone strategy smoke spec**

Run:

```bash
lua5.1 ArenaCoachTBC/Tests/StrategyEngine_spec.lua
```

Expected: PASS.

- [ ] **Step 5: Inspect git status**

Run:

```bash
git status --short
```

Expected: clean working tree.
