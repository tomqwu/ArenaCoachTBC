-- Tests/Performance_spec.lua
-- Quality bars enforced as tests:
--   1. StrategyEngine:Evaluate completes in <5ms (target <1ms; allow 5x CI margin)
--   2. 100 simulated arenas back-to-back stay within a tight memory delta
local H = _G.__ACC_TEST_HELPERS

H.load("Locales/enUS.lua")
H.load("Data/Spells.lua")
H.load("Data/Classes.lua")
H.load("Data/OwnComps.lua")
H.load("Data/Strategies.lua")
H.load("Data/SpellSpecHints.lua")
H.load("EventBus.lua")
H.load("CooldownTracker.lua")
H.load("DRTracker.lua")
H.load("Chain.lua")
H.load("OpponentProfile.lua")
H.load("Lookahead.lua")
H.load("Patterns.lua")
H.load("StrategyEngine.lua")

local SE = H.ns.StrategyEngine
local g = H.describe("Performance")

H.it(g, "Evaluate completes in <5ms per call on a 5v5 state (target <1ms)", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST","DRUID","PALADIN"})
    state.combatPhase = "ACTIVE"
    -- Warm up to avoid first-call jit / table-allocation noise.
    for i = 1, 10 do SE:Evaluate(state) end
    local start = os.clock()
    local iters = 200
    for i = 1, iters do SE:Evaluate(state) end
    local avgMs = ((os.clock() - start) / iters) * 1000
    -- 5ms is the CI margin; locally we aim for <1ms.
    H.assertTrue(avgMs < 5,
        string.format("Evaluate avg %.3fms per call (budget 5ms)", avgMs))
end)

-- =================================================================
-- M10 #70: Lookahead + pattern budget. 99p < 10ms, mean < 3ms.
-- =================================================================
H.it(g, "Evaluate with lookahead+patterns stays within budget (mean<3ms, 99p<10ms)", function()
    local LA = H.ns.Lookahead
    LA:ResetCacheStats()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST","DRUID","PALADIN"})
    state.combatPhase = "ACTIVE"
    state.config.strategy.lookaheadEnabled = true
    -- Warm up: include the path with chains by giving the state an
    -- enemy team that maps to a comp with chains (RMP-flavoured).
    state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.config.strategy.lookaheadEnabled = true
    for i = 1, 10 do SE:Evaluate(state) end

    local iters = 200
    local samples = {}
    for i = 1, iters do
        local t0 = os.clock()
        SE:Evaluate(state)
        table.insert(samples, (os.clock() - t0) * 1000)  -- ms
    end
    table.sort(samples)
    local sum = 0
    for _, v in ipairs(samples) do sum = sum + v end
    local mean = sum / iters
    local p99  = samples[math.floor(iters * 0.99)] or samples[iters]

    -- Mean budget: 3ms target, 10ms CI margin.
    H.assertTrue(mean < 10,
        string.format("Evaluate+lookahead mean %.3fms exceeds 10ms CI budget", mean))
    -- 99p budget: 10ms target, 30ms CI margin (3x).
    H.assertTrue(p99 < 30,
        string.format("Evaluate+lookahead p99 %.3fms exceeds 30ms CI budget", p99))

    local stats = LA:CacheStats()
    -- We expect cache hits because each Evaluate's Score loops over
    -- multiple chains using one cached response distribution.
    H.assertTrue(stats.total > 0, "expected at least one cache lookup")
end)

-- =================================================================
-- v2.1.1: AV-scale 40-enemy perf — same engine, much bigger team
-- =================================================================
H.it(g, "AV-scale Evaluate completes within budget on 40 enemies", function()
    -- Build a 40-enemy BG state. Mix of classes so scoring exercises
    -- every code path (healers, casters, melee, low-HP stragglers).
    local classes = {
        "WARRIOR","MAGE","PRIEST","DRUID","PALADIN",
        "ROGUE","HUNTER","SHAMAN","WARLOCK","PRIEST",
        "WARRIOR","MAGE","DRUID","PALADIN","ROGUE",
        "HUNTER","SHAMAN","WARLOCK","WARRIOR","MAGE",
        "PRIEST","DRUID","PALADIN","ROGUE","HUNTER",
        "SHAMAN","WARLOCK","WARRIOR","MAGE","PRIEST",
        "DRUID","PALADIN","ROGUE","HUNTER","SHAMAN",
        "WARLOCK","WARRIOR","MAGE","PRIEST","DRUID",
    }
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "bg"
    state.bracket     = 40
    state.enemies = {}
    for i, cls in ipairs(classes) do
        state.enemies["av-" .. i] = {
            unit       = "av" .. i,
            guid       = "av-" .. i,
            name       = "Hostile" .. i,
            class      = cls,
            alive      = true,
            healthPct  = 100 - (i % 10) * 10,  -- some low-HP stragglers
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

    -- Warm + measure
    for _ = 1, 5 do SE:Evaluate(state) end
    local iters = 100
    local start = os.clock()
    for _ = 1, iters do SE:Evaluate(state) end
    local avgMs = ((os.clock() - start) / iters) * 1000
    -- AV-scale budget: 50ms p99 CI (the 4x-of-10v10 scaling factor).
    -- Locally aiming <10ms; allow 5x for noisy GH runners.
    H.assertTrue(avgMs < 50,
        string.format("AV 40-enemy Evaluate avg %.2fms exceeds 50ms CI budget", avgMs))
end)

-- =================================================================
-- v2.5.0: full evaluation cycle (Evaluate -> UI:Apply -> WAB:Publish)
-- under budget. Pre-v2.2.5 the city-lag bug came from world_idle
-- nameplate events that ran the full cycle on every plate add/remove;
-- this test caps the cycle to a measurable budget so we'd catch any
-- regression that re-introduces that pattern.
-- =================================================================
H.it(g, "Full evaluation cycle Evaluate->UI->WAB stays under 15ms (mean of 100)", function()
    H.load("UI.lua")
    H.load("ScreenEdgeGlow.lua")
    H.load("Nameplate.lua")
    H.load("WeakAuraBridge.lua")
    local UI = H.ns.UI
    local WAB = H.ns.WeakAuraBridge
    -- Pin a PvP context so the v2.2.5 auto-hide gate doesn't no-op us.
    H.ns.Core = H.ns.Core or {}
    H.ns.Core.state = H.ns.Core.state or {}
    H.ns.Core.state.pvpContext = "arena"

    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    UI:CreateFrame()

    for _ = 1, 10 do
        local rec = SE:Evaluate(state); UI:Apply(rec); WAB:Publish(rec, state)
    end

    local iters = 100
    local start = os.clock()
    for _ = 1, iters do
        local rec = SE:Evaluate(state)
        UI:Apply(rec)
        WAB:Publish(rec, state)
    end
    local avgMs = ((os.clock() - start) / iters) * 1000
    H.assertTrue(avgMs < 15,
        string.format("full cycle avg %.3fms exceeds 15ms CI budget", avgMs))

    H.ns.Core.state.pvpContext = nil
end)

H.it(g, "100 simulated arenas back-to-back stay within 200kb memory delta", function()
    -- Force collection so the baseline is realistic.
    collectgarbage("collect")
    collectgarbage("collect")
    local before = collectgarbage("count")  -- kilobytes

    local comps = {
        {"WARRIOR","SHAMAN","PALADIN","DRUID","PRIEST"},
        {"ROGUE","MAGE","PRIEST","DRUID","PALADIN"},
        {"WARLOCK","SHAMAN","DRUID","WARRIOR","PRIEST"},
        {"HUNTER","WARLOCK","PRIEST"},
        {"MAGE","PRIEST"},
    }
    for i = 1, 100 do
        local state = SE:BuildTestState(comps[(i % #comps) + 1])
        state.combatPhase = "ACTIVE"
        SE:Evaluate(state)
        -- Drop the local so GC can reclaim between iterations.
        state = nil
    end

    collectgarbage("collect")
    collectgarbage("collect")
    local after = collectgarbage("count")
    local deltaKb = after - before
    -- Issue #34 says <100kb; allow 2x slack for spec-test framework overhead.
    H.assertTrue(deltaKb < 200,
        string.format("memory grew %.1fkb after 100 arenas (budget 200)", deltaKb))
end)
