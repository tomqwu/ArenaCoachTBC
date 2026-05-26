-- Tests/Benchmark_spec.lua (M12 #75)
--
-- Canonical match-scenario benchmark. Each scenario is a hand-built
-- state with a labelled "correct mode" (and optionally a target class).
-- The benchmark reports per-scenario + overall agreement rate. CI
-- prints the agreement; the assertion threshold is intentionally
-- loose so this acts as a non-gating signal rather than a hard CI
-- gate. The full report is printed for inspection.
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
local g  = H.describe("Benchmark")

-- Each scenario builds and returns (state, expectedMode, optional expectedClass).
local scenarios = {
    {
        name = "RMP opener (pre-combat) -> OPEN priest",
        build = function()
            local s = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
            s.combatPhase = "PRE"; return s, "OPEN", "PRIEST"
        end,
    },
    {
        name = "WLD opener (pre-combat) -> OPEN warlock",
        build = function()
            local s = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
            s.combatPhase = "PRE"; return s, "OPEN", "WARLOCK"
        end,
    },
    {
        name = "Active RMP with priest at 10% -> KILL priest",
        build = function()
            local s = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
            s.combatPhase = "ACTIVE"
            for _, e in pairs(s.enemies) do if e.class == "PRIEST" then e.healthPct = 10 end end
            return s, "KILL", "PRIEST"
        end,
    },
    {
        name = "Healer trained -> DEFEND",
        build = function()
            local s = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
            s.combatPhase = "ACTIVE"
            s.observations = { healerUnderPressure = true }
            return s, "DEFEND"
        end,
    },
    {
        name = "Friendly healer low HP -> DEFEND",
        build = function()
            local s = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
            s.combatPhase = "ACTIVE"
            for _, f in pairs(s.friendlies) do
                if f.class == "DRUID" or f.class == "PRIEST" then f.healthPct = 25 end
            end
            return s, "DEFEND"
        end,
    },
    {
        name = "Enemy bloodlust active -> DEFEND",
        build = function()
            local s = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
            s.combatPhase = "ACTIVE"
            s.observations = { enemyBloodlustActive = true }
            return s, "DEFEND"
        end,
    },
    {
        name = "No enemies -> RESET",
        build = function()
            local s = SE:BuildTestState({})
            s.combatPhase = "ACTIVE"; s.enemies = {}; s.enemyClassList = nil
            return s, "RESET"
        end,
    },
    {
        name = "WMS active -> KILL mage",
        build = function()
            local s = SE:BuildTestState({"WARRIOR","MAGE","SHAMAN"})
            s.combatPhase = "ACTIVE"
            return s, "KILL"
        end,
    },
    {
        name = "TSG pre-combat -> OPEN paladin",
        build = function()
            local s = SE:BuildTestState({"WARRIOR","PALADIN"})
            s.combatPhase = "PRE"
            return s, "OPEN", "PALADIN"
        end,
    },
    {
        name = "Triple DPS no healer -> DEFEND (PRE phase)",
        build = function()
            local s = SE:BuildTestState({"WARRIOR","ROGUE","MAGE"})
            s.combatPhase = "PRE"
            for _, e in pairs(s.enemies) do e.roleGuess = "MELEE" end
            return s, "DEFEND"
        end,
    },
    {
        name = "Last primary differs from top -> SWAP (greedy)",
        build = function()
            local s = SE:BuildTestState({"PRIEST","MAGE"})
            s.combatPhase = "ACTIVE"
            s.aggression  = "greedy"
            local priest, mage
            for _, e in pairs(s.enemies) do
                if e.class == "PRIEST" then priest = e
                elseif e.class == "MAGE"   then mage   = e end
            end
            mage.hasTrinket = false
            s.lastPrimaryGUID = priest.guid
            return s, "SWAP", "MAGE"
        end,
    },
    {
        name = "SHATTER 2v2 KILL mage low HP",
        build = function()
            local s = SE:BuildTestState({"MAGE","PRIEST"})
            s.combatPhase = "ACTIVE"; s.bracket = 2
            for _, e in pairs(s.enemies) do if e.class == "MAGE" then e.healthPct = 25 end end
            return s, "KILL", "MAGE"
        end,
    },
    {
        name = "HUNTER+PRIEST 2v2 KILL priest",
        build = function()
            local s = SE:BuildTestState({"HUNTER","PRIEST"})
            s.combatPhase = "ACTIVE"; s.bracket = 2
            for _, e in pairs(s.enemies) do if e.class == "PRIEST" then e.healthPct = 15 end end
            return s, "KILL", "PRIEST"
        end,
    },
    {
        name = "WLS active KILL shaman",
        build = function()
            local s = SE:BuildTestState({"WARLOCK","SHAMAN"})
            s.combatPhase = "ACTIVE"
            return s, "KILL"
        end,
    },
    {
        name = "BEAST_CLEAVE pre -> OPEN hunter",
        build = function()
            local s = SE:BuildTestState({"HUNTER","WARRIOR"})
            s.combatPhase = "PRE"
            return s, "OPEN", "HUNTER"
        end,
    },
    {
        name = "RMP 3v3 with priest dead -> KILL mage",
        build = function()
            local s = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
            s.combatPhase = "ACTIVE"; s.bracket = 3
            for _, e in pairs(s.enemies) do if e.class == "PRIEST" then e.alive = false; e.healthPct = 0 end end
            return s, "KILL"
        end,
    },
    {
        name = "DOUBLE_HEALER mirror -> KILL primary",
        build = function()
            local s = SE:BuildTestState({"WARRIOR","SHAMAN","PALADIN","DRUID","PRIEST"})
            s.combatPhase = "ACTIVE"
            return s, "KILL"
        end,
    },
    {
        name = "Multiple bursts detected -> DEFEND",
        build = function()
            local s = SE:BuildTestState({"WARRIOR","MAGE","PRIEST"})
            s.combatPhase = "ACTIVE"
            s.observations = { multipleBurstsDetected = true }
            return s, "DEFEND"
        end,
    },
    {
        name = "Caster cleave triple-caster pre -> OPEN warlock",
        build = function()
            local s = SE:BuildTestState({"MAGE","WARLOCK","PRIEST"})
            s.combatPhase = "PRE"
            return s, "OPEN", "WARLOCK"
        end,
    },
    {
        name = "WLP drain 2v2 -> KILL paladin",
        build = function()
            local s = SE:BuildTestState({"WARLOCK","PALADIN"})
            s.combatPhase = "ACTIVE"; s.bracket = 2
            return s, "KILL", "PALADIN"
        end,
    },
    {
        name = "Hunter+Lock+Priest 3v3 KILL priest low HP",
        build = function()
            local s = SE:BuildTestState({"HUNTER","WARLOCK","PRIEST"})
            s.combatPhase = "ACTIVE"; s.bracket = 3
            for _, e in pairs(s.enemies) do if e.class == "PRIEST" then e.healthPct = 20 end end
            return s, "KILL", "PRIEST"
        end,
    },
}

H.it(g, "benchmark suite contains at least 20 scenarios", function()
    H.assertTrue(#scenarios >= 20, "expected >= 20 scenarios, got " .. #scenarios)
end)

H.it(g, "benchmark agreement rate is reported and meets the rated-arena floor", function()
    local agreed, total = 0, 0
    local report = {}
    for _, sc in ipairs(scenarios) do
        local ok, state, expectedMode, expectedClass = pcall(sc.build)
        if not ok then
            -- build failed: count as no-match
            table.insert(report, "[ERR] " .. sc.name)
            total = total + 1
        else
            -- build returned (state, mode, class) so reorder:
            local s, m, c = state, expectedMode, expectedClass
            local rec = SE:Evaluate(s)
            local modeOK  = rec.mode == m
            local classOK = (not c) or (rec.primaryTargetClass == c)
            local match   = modeOK and classOK
            if match then agreed = agreed + 1 end
            total = total + 1
            table.insert(report, string.format("[%s] %s -> mode=%s/%s class=%s/%s",
                match and "OK " or "MISS", sc.name,
                tostring(rec.mode), tostring(m),
                tostring(rec.primaryTargetClass), tostring(c)))
        end
    end
    local rate = total > 0 and (agreed / total) or 0
    print(string.format("[BENCHMARK] agreement: %d / %d = %.0f%%",
        agreed, total, rate * 100))
    for _, line in ipairs(report) do print("[BENCHMARK] " .. line) end
    -- Rated-arena trust floor. The benchmark is still not a complete
    -- labelled dataset, but known obvious arena misses should now fail CI.
    H.assertTrue(rate >= 0.85,
        string.format("benchmark agreement %.0f%% is below the 85%% rated-arena floor", rate * 100))
end)
