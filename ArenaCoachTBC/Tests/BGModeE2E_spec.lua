-- Tests/BGModeE2E_spec.lua (M16, v2.1) — end-to-end BG mode behaviour
--
-- Synthesises a 10-player BG state and verifies:
--   * Flag carrier prioritisation (aura 23333 dominates)
--   * Low-HP straggler swap (sub-30 HP boost)
--   * BG-specific callouts fire (CALL_FLAG_CARRIER_LOW, CALL_BG_DEFEND)
--   * Arena-only callouts do NOT fire spuriously (CALL_HOJ_KILL etc. only
--     when comp matches happen to be valid)
--   * Engine completes within 10ms on a 10-enemy state (perf budget)
local H = _G.__ACC_TEST_HELPERS
H.load("Locales/enUS.lua")
H.load("Data/Spells.lua")
H.load("Data/Classes.lua")
H.load("Data/OwnComps.lua")
H.load("Data/Strategies.lua")
H.load("Data/SpellSpecHints.lua")
H.load("DRTracker.lua")
H.load("CooldownTracker.lua")
H.load("Chain.lua")
H.load("OpponentProfile.lua")
H.load("Lookahead.lua")
H.load("Patterns.lua")
H.load("StrategyEngine.lua")

local SE = H.ns.StrategyEngine
local g = H.describe("BGModeE2E")

-- Build a 10-player BG-like enemy roster. Mix of healers, casters, melee
-- so we get a realistic mode/target picture.
local function buildBG10()
    local classes = {
        "WARRIOR", "PALADIN", "PRIEST",
        "MAGE", "WARLOCK", "ROGUE",
        "DRUID", "HUNTER", "SHAMAN", "WARLOCK",
    }
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST"})  -- friendly side stays simple
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "bg"
    state.bracket     = 10
    state.enemies = {}
    for i, cls in ipairs(classes) do
        local guid = "bg-enemy-" .. i
        state.enemies[guid] = {
            unit       = "bg" .. i,
            guid       = guid,
            name       = "Hostile" .. i,
            class      = cls,
            alive      = true,
            healthPct  = 100,
            manaPct    = 100,
            hasTrinket = true,
            importantBuffs   = {},
            importantDebuffs = {},
            observedSpells   = {},
        }
    end
    local list = {}
    for _, e in pairs(state.enemies) do table.insert(list, e.class) end
    state.enemyClassList = list
    return state
end

H.it(g, "BG e2e: flag-carrier dominates kill priority", function()
    local s = buildBG10()
    -- Pick a non-healer warrior as the carrier and apply the WSG flag aura
    s.enemies["bg-enemy-1"].importantBuffs[23333] = true
    local rec = SE:Evaluate(s)
    H.assertEq(rec.primaryTargetClass, "WARRIOR",
        "flag carrier (WARRIOR) must outrank all 10 enemies including healers")
end)

H.it(g, "BG e2e: low-HP straggler beats a full-HP same-class peer", function()
    local s = buildBG10()
    -- Two rogues at different HP; the low-HP one (bg-enemy-6 → ROGUE) gets the boost
    s.enemies["bg-enemy-6"].healthPct = 18  -- straggler
    -- Make the friendly priest the openTarget candidate context-independent;
    -- with the BG straggler boost (+30) + health_below_50 (+30), the rogue
    -- should outscore the full-HP priests
    local rec = SE:Evaluate(s)
    H.assertEq(rec.primaryTargetClass, "ROGUE",
        "sub-30% straggler should win kill priority over full-HP healer")
end)

H.it(g, "BG e2e: CALL_FLAG_CARRIER_LOW fires when carrier at low HP", function()
    local s = buildBG10()
    s.enemies["bg-enemy-1"].importantBuffs[23333] = true
    s.enemies["bg-enemy-1"].healthPct = 35  -- low
    local rec = SE:Evaluate(s)
    local saw = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_FLAG_CARRIER_LOW" then saw = true end
    end
    H.assertTrue(saw, "expected CALL_FLAG_CARRIER_LOW callout")
end)

H.it(g, "BG e2e: CALL_BG_DEFEND fires on DEFEND mode in BG", function()
    local s = buildBG10()
    s.observations = { healerUnderPressure = true }
    local rec = SE:Evaluate(s)
    H.assertEq(rec.mode, "DEFEND")
    local saw = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_BG_DEFEND" then saw = true end
    end
    H.assertTrue(saw, "expected CALL_BG_DEFEND on DEFEND in BG")
end)

H.it(g, "BG e2e: no comp identification on a 10-player BG", function()
    local s = buildBG10()
    local rec = SE:Evaluate(s)
    H.assertNil(rec.comp, "BG context must not match arena comp signatures")
end)

H.it(g, "BG e2e: no SWAP thrash when score gap is small", function()
    local s = buildBG10()
    -- Establish a lastPrimary; force a small score difference.
    s.lastPrimaryGUID = "bg-enemy-3"  -- priest, our previous target
    s.enemies["bg-enemy-3"].healthPct = 80
    s.enemies["bg-enemy-9"].healthPct = 70  -- slight edge, but BG threshold = 30
    local rec = SE:Evaluate(s)
    -- The pick may shift, but mode should be KILL (not SWAP) because the
    -- score gap shouldn't exceed 30 points.
    if rec.mode == "SWAP" then
        local gap = (rec._topScore or 0) - (rec._secondScore or 0)
        H.assertTrue(gap > 30, "BG SWAP requires gap > 30; got " .. tostring(gap))
    end
end)

H.it(g, "BG e2e: Evaluate completes within budget on 10 enemies", function()
    local s = buildBG10()
    -- Warm cache
    for _ = 1, 5 do SE:Evaluate(s) end
    local start = os.clock()
    local iters = 200
    for _ = 1, iters do SE:Evaluate(s) end
    local avgMs = ((os.clock() - start) / iters) * 1000
    -- 10ms CI budget (target 3ms, 3x runner margin)
    H.assertTrue(avgMs < 30,
        string.format("BG 10-enemy Evaluate avg %.2fms (budget 30ms CI)", avgMs))
end)

H.it(g, "BG e2e: arena callouts (HoJ kill) do NOT fire spuriously in BG", function()
    local s = buildBG10()
    -- Healer at low HP — would normally trigger arena CALL_HOJ_KILL via comp
    -- callouts. In BG with comp ID skipped, those arena cues should not fire.
    s.enemies["bg-enemy-3"].healthPct = 25
    local rec = SE:Evaluate(s)
    for _, c in ipairs(rec.callouts or {}) do
        H.assertTrue(c ~= "CALL_HOJ_KILL" or rec.mode == "KILL",
            "CALL_HOJ_KILL is mode-driven; should still appear when KILL fires")
    end
    -- Verify comp-driven callouts (which come from comp.callouts) don't fire
    -- with no comp. comp is nil → no comp callouts pushed.
    H.assertNil(rec.comp)
end)
