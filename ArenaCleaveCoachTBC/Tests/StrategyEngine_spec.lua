-- ArenaCleaveCoachTBC - StrategyEngine unit tests
-- Run from the addon root directory with vanilla Lua 5.1+:
--     lua ArenaCleaveCoachTBC/Tests/StrategyEngine_spec.lua
-- (or `lua5.1 Tests/StrategyEngine_spec.lua` from inside the addon dir)
--
-- These tests stub the WoW API (GetTime, UnitClass, UnitHealth, etc.)
-- and load each module file by passing the addon name + shared namespace
-- as if the WoW client were doing it.

-- ============================================================
-- WoW API stubs (only what the engine actually touches)
-- ============================================================
_G.GetTime               = function() return 100 end
_G.GetLocale             = function() return "enUS" end
_G.GetSpellInfo          = function(id) return "Spell" .. tostring(id), nil, "" end
_G.GetSpellTexture       = function(id) return "" end
_G.UnitExists            = function() return false end
_G.UnitGUID              = function(u) return "guid-" .. tostring(u) end
_G.UnitName              = function(u) return tostring(u) end
_G.UnitClass             = function(u) return "Warrior", "WARRIOR" end
_G.UnitHealth            = function() return 100 end
_G.UnitHealthMax         = function() return 100 end
_G.UnitPower             = function() return 100 end
_G.UnitPowerMax          = function() return 100 end
_G.UnitIsDeadOrGhost     = function() return false end
_G.CombatLogGetCurrentEventInfo = function() return nil end
-- We intentionally leave CreateFrame nil; that triggers test mode in modules.

-- ============================================================
-- Module loader
-- ============================================================
local ADDON_NAME = "ArenaCleaveCoachTBC"
local ns = {}

-- Resolve the addon root relative to this script's path.
local function scriptDir()
    local src = (arg and arg[0]) or debug.getinfo(1, "S").source or ""
    src = src:gsub("^@", "")
    local dir = src:match("(.+)[/\\][^/\\]+$")
    if not dir or dir == "" then dir = "." end
    return dir
end

local THIS_DIR = scriptDir()
local ADDON_DIR = THIS_DIR .. "/.."

local function load(rel)
    local path = ADDON_DIR .. "/" .. rel
    local chunk, err = loadfile(path)
    if not chunk then error("loadfile failed for " .. path .. ": " .. tostring(err)) end
    return chunk(ADDON_NAME, ns)
end

load("Locales/enUS.lua")
load("Data/Spells.lua")
load("Data/Classes.lua")
load("Data/Strategies.lua")
load("EventBus.lua")
load("CooldownTracker.lua")
load("DRTracker.lua")
load("StrategyEngine.lua")

local SE = ns.StrategyEngine
assert(SE, "StrategyEngine failed to load")

-- ============================================================
-- Tiny test harness
-- ============================================================
local tests = {}
local function test(name, fn) table.insert(tests, { name = name, fn = fn }) end

local function assertEq(a, b, msg)
    if a ~= b then
        error(string.format("assertEq failed: %s -- expected %s, got %s",
            tostring(msg or ""), tostring(b), tostring(a)), 2)
    end
end
local function assertTrue(v, msg)
    if not v then error("assertTrue failed: " .. tostring(msg or ""), 2) end
end
local function assertNotEq(a, b, msg)
    if a == b then
        error(string.format("assertNotEq failed: %s -- both were %s",
            tostring(msg or ""), tostring(a)), 2)
    end
end

local function findEnemyByClass(state, class)
    for _, e in pairs(state.enemies) do
        if e.class == class then return e end
    end
end

-- ============================================================
-- Tests
-- ============================================================

test("healer exposed should be primary target", function()
    local state = SE:BuildTestState({ "WARRIOR", "ROGUE", "PRIEST", "MAGE", "WARLOCK" })
    local rec = SE:Evaluate(state)
    assertTrue(rec, "got a recommendation")
    assertEq(rec.primaryTargetClass, "PRIEST", "priest should be top-scored")
end)

test("immunity active suppresses kill target", function()
    -- Set up a state where Mage and Priest both alive, but Priest has Ice Block.
    local state = SE:BuildTestState({ "WARRIOR", "MAGE", "PRIEST", "ROGUE", "WARLOCK" })
    local priest = findEnemyByClass(state, "PRIEST")
    -- Priest doesn't normally have Ice Block; we use Divine Shield ID for an immunity buff
    -- on the priest just to validate the immunity scoring path.
    priest.importantBuffs[ns.Spells.DIVINE_SHIELD] = true
    local rec = SE:Evaluate(state)
    assertNotEq(rec.primaryTargetClass, "PRIEST", "priest should not be primary while immune")
end)

test("MS active increases target score", function()
    local state = SE:BuildTestState({ "WARRIOR", "PRIEST", "MAGE", "WARLOCK", "ROGUE" })
    local mage = findEnemyByClass(state, "MAGE")
    -- Score baseline (no MS marker)
    local recA = SE:Evaluate(state)
    local mageA = mage._score
    -- Now set MS active on the mage (different state to avoid score reuse)
    local state2 = SE:BuildTestState({ "WARRIOR", "PRIEST", "MAGE", "WARLOCK", "ROGUE" })
    local mage2 = findEnemyByClass(state2, "MAGE")
    state2.observations.msActiveOn = mage2.guid
    SE:Evaluate(state2)
    assertTrue(mage2._score > mageA,
        string.format("expected mage score with MS to exceed baseline (%d > %d)", mage2._score, mageA))
end)

test("trinket down increases target score", function()
    local state = SE:BuildTestState({ "WARRIOR", "PRIEST", "MAGE", "WARLOCK", "ROGUE" })
    local mage = findEnemyByClass(state, "MAGE")
    mage.hasTrinket = true
    SE:Evaluate(state)
    local scoreWith = mage._score
    local state2 = SE:BuildTestState({ "WARRIOR", "PRIEST", "MAGE", "WARLOCK", "ROGUE" })
    local mage2 = findEnemyByClass(state2, "MAGE")
    mage2.hasTrinket = false
    SE:Evaluate(state2)
    assertTrue(mage2._score > scoreWith,
        string.format("expected trinket-down score to be higher (%d > %d)", mage2._score, scoreWith))
end)

test("friendly healer low HP triggers DEFEND", function()
    local state = SE:BuildTestState({ "WARRIOR", "ROGUE", "PRIEST", "MAGE", "WARLOCK" })
    state.friendlies.party4.healthPct = 25  -- our priest
    state.combatPhase = "ACTIVE"
    local rec = SE:Evaluate(state)
    assertEq(rec.mode, "DEFEND", "low healer must trigger DEFEND mode")
end)

test("enemy triple DPS triggers defensive recommendation in PRE", function()
    local state = SE:BuildTestState({ "ROGUE", "MAGE", "WARLOCK", "PRIEST", "SHAMAN" })
    -- This composition: priest+shaman without resto specs default to healer/hybrid;
    -- to force triple DPS we override roles
    findEnemyByClass(state, "PRIEST").roleGuess = "CASTER"
    findEnemyByClass(state, "SHAMAN").roleGuess = "MELEE"
    -- We also need to override default role lookup -> rebuild class list
    state.combatPhase = "PRE"
    local rec = SE:Evaluate(state)
    assertEq(rec.mode, "DEFEND", "triple DPS in PRE should be DEFEND")
end)

test("Bloodlust burst recommendation requires MS if config says so", function()
    local state = SE:BuildTestState({ "WARRIOR", "MAGE", "PRIEST", "WARLOCK", "ROGUE" })
    state.config.strategy.callBurstOnlyWhenMSActive = true
    state.config.strategy.requireWindfuryNearby     = true
    state.combatPhase = "ACTIVE"
    state.observations.bloodlustReady   = true
    state.observations.windfuryActive   = true
    -- No msActiveOn set -> burst should be blocked
    local rec = SE:Evaluate(state)
    assertEq(rec.burstAllowed, false, "burst must be blocked when MS not on target")
    assertEq(rec.burstBlockedBy, "no_ms", "block reason should be no_ms")

    -- Now set MS active on top target and re-evaluate fresh state
    local state2 = SE:BuildTestState({ "WARRIOR", "MAGE", "PRIEST", "WARLOCK", "ROGUE" })
    state2.config.strategy.callBurstOnlyWhenMSActive = true
    state2.config.strategy.requireWindfuryNearby     = true
    state2.combatPhase = "ACTIVE"
    state2.observations.bloodlustReady = true
    state2.observations.windfuryActive = true
    local priest = findEnemyByClass(state2, "PRIEST")
    state2.observations.msActiveOn = priest.guid
    local rec2 = SE:Evaluate(state2)
    assertEq(rec2.burstAllowed, true, "burst should now be allowed")
end)

test("target swap recommended when Mage has no Ice Block and low HP", function()
    local state = SE:BuildTestState({ "WARRIOR", "MAGE", "PRIEST", "WARLOCK", "DRUID" })
    state.combatPhase = "ACTIVE"

    -- Initial primary call on Priest
    local rec1 = SE:Evaluate(state)
    state.lastPrimaryGUID = rec1.primaryTarget

    -- Now mage is at low HP, priest is fine -> top score moves to mage
    local mage = findEnemyByClass(state, "MAGE")
    mage.healthPct = 20
    mage.hasTrinket = false
    mage.importantBuffs = {}    -- no ice block
    local rec2 = SE:Evaluate(state)
    assertEq(rec2.primaryTargetClass, "MAGE", "mage should be top target")
    assertEq(rec2.mode, "SWAP", "should recommend SWAP because last call differs")
end)

test("test-mode comps each produce a recommendation", function()
    local Strategies = ns.Strategies
    assertTrue(Strategies and Strategies.testComps and #Strategies.testComps == 5)
    for i, c in ipairs(Strategies.testComps) do
        local state = SE:BuildTestState(c.classes)
        local rec = SE:Evaluate(state)
        assertTrue(rec, "comp #" .. i .. " produced a recommendation")
        assertTrue(rec.mode == "OPEN" or rec.mode == "DEFEND" or rec.mode == "RESET",
            "comp #" .. i .. " mode in PRE should be OPEN/DEFEND/RESET, got " .. tostring(rec.mode))
    end
end)

test("WeakAuraBridge exposes API after evaluate", function()
    load("WeakAuraBridge.lua")
    local state = SE:BuildTestState({ "WARRIOR", "ROGUE", "PRIEST", "MAGE", "WARLOCK" })
    local rec = SE:Evaluate(state)
    ns.WeakAuraBridge:Publish(rec)
    assertTrue(_G.ArenaCleaveCoachTBC, "global bridge installed")
    assertTrue(_G.ArenaCleaveCoachTBC.GetRecommendation(), "GetRecommendation returns last rec")
    assertEq(_G.ArenaCleaveCoachTBC.GetPrimaryTarget(), rec.primaryTarget, "GetPrimaryTarget matches")
end)

-- ============================================================
-- Run
-- ============================================================
local pass, fail = 0, 0
local failures = {}
for _, t in ipairs(tests) do
    local ok, err = pcall(t.fn)
    if ok then
        pass = pass + 1
        print("PASS " .. t.name)
    else
        fail = fail + 1
        print("FAIL " .. t.name)
        print("    " .. tostring(err))
        table.insert(failures, t.name)
    end
end

print(string.format("\nResults: %d passed, %d failed", pass, fail))
if fail > 0 then
    for _, name in ipairs(failures) do print("  - " .. name) end
    os.exit(1)
end
os.exit(0)
