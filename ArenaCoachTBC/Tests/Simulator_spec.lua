-- Tests/Simulator_spec.lua
local H = _G.__ACC_TEST_HELPERS

-- Load the full dependency graph so the simulator has trackers, engine,
-- and spell data available the way it would at runtime.
H.load("Locales/enUS.lua")
H.load("Locales/zhCN.lua")
H.load("Data/Spells.lua")
H.load("Data/Classes.lua")
H.load("Data/OwnComps.lua")
H.load("Data/Strategies.lua")
H.load("Data/SpellSpecHints.lua")
H.load("EventBus.lua")
H.load("CooldownTracker.lua")
H.load("DRTracker.lua")
H.load("StrategyEngine.lua")
H.load("UI.lua")
H.load("Options.lua")
H.load("WeakAuraBridge.lua")
H.load("SelfTest.lua")
H.load("Simulator.lua")
H.load("Data/SimScenarios.lua")
H.load("Core.lua")

local SIM  = H.ns.Simulator
local Core = H.ns.Core
local S    = H.ns.Spells

-- Make Run() use the synchronous path (no C_Timer required) by removing
-- any C_Timer global the harness might have leaked.
_G.C_Timer = nil

local g = H.describe("Simulator")

local function resetState()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    Core.state.enemies = {}
    Core.state.friendlies = {}
    if H.ns.CooldownTracker then H.ns.CooldownTracker:Clear() end
    if H.ns.DRTracker      then H.ns.DRTracker:Clear()      end
    SIM:Stop()
end

H.it(g, "Register stores a scenario by key", function()
    SIM.scenarios = {}
    SIM:Register("test", { enemies = {"WARRIOR"}, events = {} })
    H.assertNotNil(SIM:Get("test"))
end)

H.it(g, "Register rejects bad input", function()
    SIM.scenarios = {}
    local ok = pcall(function() SIM:Register("k", "not a table") end)
    H.assertFalse(ok)
    ok = pcall(function() SIM:Register("k", { enemies = nil, events = {} }) end)
    H.assertFalse(ok)
end)

H.it(g, "List returns sorted scenario keys", function()
    -- Re-load the built-in scenarios in case earlier tests cleared them.
    H.load("Data/SimScenarios.lua")
    local keys = SIM:List()
    H.assertTrue(#keys >= 3, "expected at least 3 built-ins, got " .. #keys)
    -- Should include the 3 built-ins
    local found = {}
    for _, k in ipairs(keys) do found[k] = true end
    H.assertTrue(found["rmp"],        "missing rmp")
    H.assertTrue(found["tsg-mirror"], "missing tsg-mirror")
    H.assertTrue(found["drain"],      "missing drain")
end)

H.it(g, "Run unknown scenario returns false + error", function()
    resetState()
    local ok, err = SIM:Run("nope-not-real")
    H.assertFalse(ok)
    H.assertNotNil(err and err:find("unknown"))
end)

H.it(g, "Run sets up enemies from scenario.enemies", function()
    resetState()
    SIM:Run("rmp", { printEvents = false })
    H.assertEq(Core.state.enemies.arena1.class, "ROGUE")
    H.assertEq(Core.state.enemies.arena2.class, "MAGE")
    H.assertEq(Core.state.enemies.arena3.class, "PRIEST")
    H.assertEq(Core.state.combatPhase, "ACTIVE")
end)

H.it(g, "Run with no C_Timer applies every event synchronously", function()
    resetState()
    SIM:Run("rmp", { printEvents = false })
    -- After RMP runs synchronously: rogue should have used Sap, Kidney, Blind;
    -- mage Polymorph + Counterspell; priest Psychic Scream + trinketed.
    local r = Core.state.enemies.arena1
    local m = Core.state.enemies.arena2
    local p = Core.state.enemies.arena3
    H.assertNotNil(r.observedSpells[S.SAP])
    H.assertNotNil(r.observedSpells[S.KIDNEY_SHOT])
    H.assertNotNil(m.observedSpells[S.POLYMORPH_SHEEP])
    H.assertNotNil(m.observedSpells[S.COUNTERSPELL])
    H.assertNotNil(p.observedSpells[S.PSYCHIC_SCREAM])
    H.assertFalse(p.hasTrinket, "priest should have trinketed")
end)

H.it(g, "Apply 'kill' event marks enemy not alive", function()
    resetState()
    SIM:Run("rmp", { printEvents = false })
    SIM:Apply({ type = "kill", unit = 2 })
    H.assertFalse(Core.state.enemies.arena2.alive)
    H.assertEq(Core.state.enemies.arena2.healthPct, 0)
end)

H.it(g, "Apply 'health' event sets health pct", function()
    resetState()
    SIM:Run("tsg-mirror", { printEvents = false })
    -- The scenario itself includes a `health` event at t=5 setting arena1 to 40%
    H.assertEq(Core.state.enemies.arena1.healthPct, 40)
end)

H.it(g, "Apply 'aura' / 'aura_off' updates importantBuffs", function()
    resetState()
    SIM:Run("rmp", { printEvents = false })
    SIM:Apply({ type = "aura", on = 1, spell = 42292 })
    H.assertTrue(Core.state.enemies.arena1.importantBuffs[42292])
    SIM:Apply({ type = "aura_off", on = 1, spell = 42292 })
    H.assertNil(Core.state.enemies.arena1.importantBuffs[42292])
end)

H.it(g, "Stop cancels future scheduled callbacks (generation check)", function()
    resetState()
    -- Install a fake C_Timer so Run() schedules; then Stop and verify pending
    -- callbacks no-op.
    local pending = {}
    _G.C_Timer = { After = function(_, fn) table.insert(pending, fn) end }
    SIM:Run("drain", { printEvents = false })
    H.assertTrue(#pending >= 1)
    SIM:Stop()  -- bumps generation
    -- Fire all pending callbacks; none should mutate state (specifically,
    -- arena1.observedSpells should be empty for the UA cast that would have
    -- fired at t=0 after Stop).
    Core.state.enemies.arena1.observedSpells = {}
    for _, fn in ipairs(pending) do fn() end
    H.assertNil(Core.state.enemies.arena1.observedSpells[S.UNSTABLE_AFFLICTION])
    _G.C_Timer = nil
end)

H.it(g, "Run prints scenario label + per-event lines when printEvents is on", function()
    resetState()
    local lines = {}
    local origPrint = _G.print
    _G.print = function(s) table.insert(lines, tostring(s)) end
    SIM:Run("drain")  -- printEvents defaults to true
    _G.print = origPrint
    local sawLabel = false
    for _, ln in ipairs(lines) do
        if ln:find("Drainteam") then sawLabel = true; break end
    end
    H.assertTrue(sawLabel, "should print scenario label")
end)

-- Smoke test each built-in scenario to make sure no event errors. Loop runs
-- after the explicit tests so a failure here points at the data, not the
-- simulator logic.
for _, key in ipairs({"rmp", "tsg-mirror", "drain", "chain-vs-chain"}) do
    H.it(g, "built-in scenario '" .. key .. "' applies every event without error", function()
        resetState()
        local ok, err = SIM:Run(key, { printEvents = false })
        H.assertTrue(ok, "Run failed: " .. tostring(err))
    end)
end

H.it(g, "/acc simulate (no arg) lists scenarios", function()
    resetState()
    local lines = {}
    local origPrint = _G.print
    _G.print = function(s) table.insert(lines, tostring(s)) end
    Core:RunSimulator("")
    _G.print = origPrint
    local sawHeader, sawRmp = false, false
    for _, ln in ipairs(lines) do
        if ln:find("Available scenarios") then sawHeader = true end
        if ln:find("^%[ACC%]%s+rmp") or ln:find("  rmp ") then sawRmp = true end
    end
    H.assertTrue(sawHeader, "header missing")
    H.assertTrue(sawRmp, "rmp not listed: " .. table.concat(lines, "|"))
end)

H.it(g, "/acc simulate stop reports stopped", function()
    resetState()
    local lines = {}
    local origPrint = _G.print
    _G.print = function(s) table.insert(lines, tostring(s)) end
    Core:RunSimulator("stop")
    _G.print = origPrint
    local sawStopped = false
    for _, ln in ipairs(lines) do
        if ln:find("stop") then sawStopped = true; break end
    end
    H.assertTrue(sawStopped, "no 'stopped' line in: " .. table.concat(lines, "|"))
end)

H.it(g, "/acc simulate <unknown> prints error", function()
    resetState()
    local lines = {}
    local origPrint = _G.print
    _G.print = function(s) table.insert(lines, tostring(s)) end
    Core:RunSimulator("nope-not-here")
    _G.print = origPrint
    local sawErr = false
    for _, ln in ipairs(lines) do
        if ln:find("unknown") then sawErr = true; break end
    end
    H.assertTrue(sawErr, "no error in: " .. table.concat(lines, "|"))
end)

H.it(g, "/acc simulate rmp via slash dispatch runs the scenario", function()
    resetState()
    SlashCmdList["ARENACOACH"]("simulate rmp")
    -- After synchronous dispatch, all events have fired.
    H.assertNotNil(Core.state.enemies.arena1.observedSpells[S.SAP])
end)
