-- Tests/SelfTest_spec.lua
local H = _G.__ACC_TEST_HELPERS
H.load("SelfTest.lua")
local ST = H.ns.SelfTest

local function makePrinter()
    local lines = {}
    local fn = function(s) table.insert(lines, tostring(s)) end
    return fn, lines
end

local g = H.describe("SelfTest")

H.it(g, "Register appends a check", function()
    ST:Reset()
    ST:Register("a", function() return true end)
    H.assertEq(#ST.checks, 1)
    H.assertEq(ST.checks[1].name, "a")
end)

H.it(g, "Run reports pass/fail counts", function()
    ST:Reset()
    ST:Register("yes", function() return true end)
    ST:Register("no",  function() return false, "nope" end)
    local p, fail, results = ST:Run(false, function() end)
    H.assertEq(p, 1)
    H.assertEq(fail, 1)
    H.assertEq(#results, 2)
end)

H.it(g, "Run verbose prints PASS and FAIL lines", function()
    ST:Reset()
    ST:Register("yes", function() return true end)
    ST:Register("no",  function() return false, "nope" end)
    local printer, lines = makePrinter()
    ST:Run(true, printer)
    local sawPass, sawFail = false, false
    for _, ln in ipairs(lines) do
        if ln:find("PASS  yes") then sawPass = true end
        if ln:find("FAIL  no: nope") then sawFail = true end
    end
    H.assertTrue(sawPass, "missing PASS line")
    H.assertTrue(sawFail, "missing FAIL line")
end)

H.it(g, "Run non-verbose hides PASS lines but still prints FAILs", function()
    ST:Reset()
    ST:Register("yes", function() return true end)
    ST:Register("no",  function() return false, "nope" end)
    local printer, lines = makePrinter()
    ST:Run(false, printer)
    local sawPass, sawFail = false, false
    for _, ln in ipairs(lines) do
        if ln:find("PASS  yes") then sawPass = true end
        if ln:find("FAIL  no: nope") then sawFail = true end
    end
    H.assertFalse(sawPass, "non-verbose should hide PASS")
    H.assertTrue(sawFail, "non-verbose must still show FAILs")
end)

H.it(g, "Run treats a thrown error as a failure", function()
    ST:Reset()
    ST:Register("throws", function() error("boom") end)
    local p, fail = ST:Run(false, function() end)
    H.assertEq(p, 0)
    H.assertEq(fail, 1)
end)

H.it(g, "RegisterDefaults populates real checks", function()
    -- Load the full namespace so default checks have something to look at
    H.load("Locales/enUS.lua")
    H.load("Data/Spells.lua")
    H.load("Data/Classes.lua")
    H.load("Data/OwnComps.lua")
    H.load("Data/Strategies.lua")
    H.load("EventBus.lua")
    H.load("CooldownTracker.lua")
    H.load("DRTracker.lua")
    H.load("StrategyEngine.lua")
    H.load("Core.lua")
    H.installStubs()
    H.load("WeakAuraBridge.lua")
    ST:Reset()
    ST:RegisterDefaults()
    H.assertTrue(#ST.checks >= 8, "expected >=8 default checks, got " .. #ST.checks)
end)

H.it(g, "All default checks pass against a fully loaded namespace", function()
    ST:Reset()
    ST:RegisterDefaults()
    local _p, fail, results = ST:Run(false, function() end)
    if fail > 0 then
        local names = {}
        for _, r in ipairs(results) do
            if not r.ok then table.insert(names, r.name .. ": " .. tostring(r.detail)) end
        end
        error("selftest failed checks: " .. table.concat(names, " | "))
    end
end)
