-- Tests/Core_spec.lua
-- These tests load Core after all dependent modules, then exercise event
-- handlers, slash commands, and the test-mode entry points. Slash dispatch
-- in Core uses `print`; we capture stdout into a buffer so we can verify
-- text was emitted without polluting test output.

local H = _G.__ACC_TEST_HELPERS

-- Ensure each Core dep is loaded once into the shared namespace.
H.load("Locales/enUS.lua")
H.load("Locales/zhCN.lua")
H.load("Data/Spells.lua")
H.load("Data/Classes.lua")
H.load("Data/OwnComps.lua")
H.load("Data/Strategies.lua")
H.load("EventBus.lua")
H.load("CooldownTracker.lua")
H.load("DRTracker.lua")
H.load("StrategyEngine.lua")
H.load("UI.lua")
H.load("Options.lua")
H.load("WeakAuraBridge.lua")
H.load("Core.lua")

local Core = H.ns.Core
local EB = H.ns.EventBus

-- Earlier specs (EventBus_spec) call EB:_Reset() which wipes all
-- subscriptions including Core's. Re-boot so the WoW-event tests below
-- still receive dispatches.
Core:Boot()

local g = H.describe("Core")

-- Capture print output so tests don't pollute stdout
local originalPrint = print
local captured = {}
local function startCapture()
    captured = {}
    _G.print = function(...)
        local n = select("#", ...)
        local parts = {}
        for i = 1, n do parts[i] = tostring(select(i, ...)) end
        table.insert(captured, table.concat(parts, "\t"))
    end
end
local function stopCapture()
    _G.print = originalPrint
end

H.it(g, "InitDB applies all defaults", function()
    _G.ArenaCoachTBCDB = nil
    local db = Core:InitDB()
    H.assertTrue(db.enabled)
    H.assertEq(db.frame.point, "CENTER")
    H.assertEq(db.strategy.aggression, "balanced")
    H.assertEq(db.alerts.sound, true)
end)

H.it(g, "InitDB preserves existing user keys (no overwrite)", function()
    _G.ArenaCoachTBCDB = { enabled = false, frame = { x = 999 } }
    local db = Core:InitDB()
    H.assertFalse(db.enabled)
    H.assertEq(db.frame.x, 999)
    H.assertEq(db.frame.point, "CENTER")  -- filled in
end)

H.it(g, "CurrentLocale returns GetLocale value on auto", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.ArenaCoachTBCDB.language = "auto"
    H.setLocale("zhCN")
    H.assertEq(Core:CurrentLocale(), "zhCN")
    H.setLocale("enUS")
end)

H.it(g, "CurrentLocale returns explicit override", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.ArenaCoachTBCDB.language = "deDE"
    H.assertEq(Core:CurrentLocale(), "deDE")
    _G.ArenaCoachTBCDB.language = "auto"
end)

H.it(g, "Core.L returns localized string or fallback", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.assertEq(Core.L("OPEN"), "OPEN")
    H.assertEq(Core.L("DEFINITELY_NOT_A_KEY"), "DEFINITELY_NOT_A_KEY")
end)

H.it(g, "DebugPrint only prints when debug=true", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.ArenaCoachTBCDB.debug = false
    startCapture()
    Core.DebugPrint("hello")
    H.assertEq(#captured, 0)
    _G.ArenaCoachTBCDB.debug = true
    Core.DebugPrint("hello")
    H.assertTrue(#captured >= 1)
    _G.ArenaCoachTBCDB.debug = false
    stopCapture()
end)

H.it(g, "RefreshFriendlies fills the friendlies table", function()
    H.setUnit("player", { class = "WARRIOR", hp = 100, hpMax = 100, mp = 100, mpMax = 100 })
    H.setUnit("party1", { class = "SHAMAN",  hp = 100, hpMax = 100, mp = 100, mpMax = 100 })
    Core:RefreshFriendlies()
    H.assertEq(Core.state.friendlies.player.class, "WARRIOR")
    H.assertEq(Core.state.friendlies.party1.class, "SHAMAN")
end)

H.it(g, "RefreshArenaEnemies fills the enemies table and class list", function()
    H.setUnit("arena1", { class = "MAGE", hp = 100, hpMax = 100 })
    H.setUnit("arena2", { class = "PRIEST", hp = 50, hpMax = 100 })
    Core:RefreshArenaEnemies()
    H.assertEq(Core.state.enemies.arena1.class, "MAGE")
    H.assertEq(Core.state.enemies.arena2.healthPct, 50)
    H.assertTrue(#Core.state.enemyClassList >= 2)
end)

H.it(g, "Refresh marks unit not alive when it doesn't exist", function()
    H.setUnit("arena3", nil)
    Core:RefreshArenaEnemies()
    H.assertFalse(Core.state.enemies.arena3.alive)
end)

H.it(g, "Refresh handles dead unit", function()
    H.setUnit("arena1", { class = "MAGE", hp = 0, hpMax = 100, dead = true })
    Core:RefreshArenaEnemies()
    H.assertFalse(Core.state.enemies.arena1.alive)
end)

H.it(g, "Refresh handles zero-max mana cleanly", function()
    H.setUnit("player", { class = "WARRIOR", hp = 100, hpMax = 100, mp = 0, mpMax = 0 })
    Core:RefreshFriendlies()
    H.assertNil(Core.state.friendlies.player.manaPct)
end)

H.it(g, "Evaluate publishes recommendation", function()
    -- Earlier tests can leave enabled=false (intentional, for the merge-
    -- preserve test). Reset DB fully here so we start clean.
    _G.ArenaCoachTBCDB = nil
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.ArenaCoachTBCDB.debug = false
    _G.ArenaCoachTBCDB.enabled = true
    H.setUnit("player", { class = "WARRIOR" })
    H.setUnit("arena1", { class = "PRIEST", hp = 100, hpMax = 100 })
    Core:RefreshFriendlies()
    Core:RefreshArenaEnemies()
    local rec = Core:Evaluate()
    H.assertNotNil(rec)
end)

H.it(g, "Evaluate is a no-op when disabled", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.ArenaCoachTBCDB.enabled = false
    local r = Core:Evaluate()
    H.assertNil(r)
    _G.ArenaCoachTBCDB.enabled = true
end)

H.it(g, "RunTestMode produces output for every sample comp", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    Core:RunTestMode()
    stopCapture()
    H.assertTrue(#captured >= 5, "captured output is too short")
end)

H.it(g, "RunEnemySim with classes simulates a comp", function()
    startCapture()
    Core:RunEnemySim("war mage priest druid pala")
    stopCapture()
    H.assertTrue(#captured >= 1)
end)

H.it(g, "RunEnemySim with empty input prints usage", function()
    startCapture()
    Core:RunEnemySim("")
    stopCapture()
    H.assertTrue(#captured >= 1)
end)

H.it(g, "slash command /acc help prints help", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    SlashCmdList["ARENACOACH"]("help")
    stopCapture()
    H.assertTrue(#captured >= 5, "help should print many lines")
end)

H.it(g, "RunSelfTest produces output and reports a summary", function()
    H.load("SelfTest.lua")
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    Core:RunSelfTest(false)
    stopCapture()
    H.assertTrue(#captured >= 2, "expected header + summary, got " .. #captured)
    local lastLine = captured[#captured]
    H.assertNotNil(lastLine:find("SelfTest:"), "summary line missing: " .. lastLine)
end)

H.it(g, "slash command /acc selftest verbose dispatches", function()
    H.load("SelfTest.lua")
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    SlashCmdList["ARENACOACH"]("selftest verbose")
    stopCapture()
    -- verbose mode emits at least one PASS line plus the summary
    local sawPass, sawSummary = false, false
    for _, ln in ipairs(captured) do
        if ln:find("PASS  ") then sawPass = true end
        if ln:find("SelfTest:") then sawSummary = true end
    end
    H.assertTrue(sawPass, "verbose mode should print PASS lines")
    H.assertTrue(sawSummary, "summary should be printed")
end)

H.it(g, "/acc toggle / lock / unlock all run", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    SlashCmdList["ARENACOACH"]("toggle")
    SlashCmdList["ARENACOACH"]("lock")
    H.assertTrue(_G.ArenaCoachTBCDB.locked)
    SlashCmdList["ARENACOACH"]("unlock")
    H.assertFalse(_G.ArenaCoachTBCDB.locked)
    stopCapture()
end)

H.it(g, "/acc debug toggles flag", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.ArenaCoachTBCDB.debug = false
    startCapture()
    SlashCmdList["ARENACOACH"]("debug")
    H.assertTrue(_G.ArenaCoachTBCDB.debug)
    SlashCmdList["ARENACOACH"]("debug")
    H.assertFalse(_G.ArenaCoachTBCDB.debug)
    stopCapture()
end)

H.it(g, "/acc strategy valid sets aggression", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    SlashCmdList["ARENACOACH"]("strategy safe")
    H.assertEq(_G.ArenaCoachTBCDB.strategy.aggression, "safe")
    SlashCmdList["ARENACOACH"]("strategy balanced")
    H.assertEq(_G.ArenaCoachTBCDB.strategy.aggression, "balanced")
    SlashCmdList["ARENACOACH"]("strategy greedy")
    H.assertEq(_G.ArenaCoachTBCDB.strategy.aggression, "greedy")
    stopCapture()
end)

H.it(g, "/acc strategy with bad arg prints usage", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    SlashCmdList["ARENACOACH"]("strategy weird")
    stopCapture()
    H.assertTrue(#captured >= 1)
end)

H.it(g, "/acc reset wipes the DB", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    SlashCmdList["ARENACOACH"]("reset")
    H.assertNil(_G.ArenaCoachTBCDB)
    stopCapture()
end)

H.it(g, "/acc test runs", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    SlashCmdList["ARENACOACH"]("test")
    stopCapture()
    H.assertTrue(#captured >= 5)
end)

H.it(g, "/acc enemy runs", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    SlashCmdList["ARENACOACH"]("enemy war mage priest druid pala")
    stopCapture()
    H.assertTrue(#captured >= 1)
end)

H.it(g, "/acc unknown command prints unknown", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    SlashCmdList["ARENACOACH"]("xyzzy")
    stopCapture()
    H.assertTrue(#captured >= 1)
end)

H.it(g, "/acc with empty input falls through to help", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    SlashCmdList["ARENACOACH"]("")
    stopCapture()
    H.assertTrue(#captured >= 5)
end)

-- Earlier tests in the EventBus group call EB:_Reset() which wipes ALL
-- subscriptions including Core's. We re-Boot inside each event-driven test
-- below so handlers are guaranteed to be registered.
local function rebootForEvents()
    H.ns.EventBus:_Reset()  -- start from a known empty state
    Core:Boot()             -- re-register all of Core's handlers
end

H.it(g, "EventBus PLAYER_ENTERING_WORLD handler runs without error", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    EB:Dispatch("PLAYER_ENTERING_WORLD")
end)

H.it(g, "EventBus ARENA_OPPONENT_UPDATE handler runs", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.setUnit("arena1", { class = "PRIEST", hp = 100, hpMax = 100 })
    EB:Dispatch("ARENA_OPPONENT_UPDATE")
    H.assertEq(Core.state.combatPhase, "ACTIVE")
end)

H.it(g, "EventBus GROUP_ROSTER_UPDATE handler runs", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    EB:Dispatch("GROUP_ROSTER_UPDATE")
end)

H.it(g, "EventBus UNIT_AURA handler is a no-op for unknown unit", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    EB:Dispatch("UNIT_AURA", "weirdunit")
    EB:Dispatch("UNIT_AURA", nil)
    EB:Dispatch("UNIT_AURA", "player")
    EB:Dispatch("UNIT_AURA", "arena1")
end)

H.it(g, "EventBus PLAYER_REGEN_DISABLED/ENABLED transitions combatPhase", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    EB:Dispatch("PLAYER_REGEN_DISABLED")
    H.assertEq(Core.state.combatPhase, "ACTIVE")
    EB:Dispatch("PLAYER_REGEN_ENABLED")
    H.assertEq(Core.state.combatPhase, "POST")
end)

H.it(g, "EventBus UNIT_SPELLCAST_SUCCEEDED records cooldown for arenaN", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.setUnit("arena1", { class = "MAGE", guid = "guid-mage1", hp = 100, hpMax = 100 })
    EB:Dispatch("UNIT_SPELLCAST_SUCCEEDED", "arena1", nil, 27619)
    H.assertNotNil(H.ns.CooldownTracker:GetRemaining("guid-mage1", 27619))
end)

H.it(g, "EventBus UNIT_SPELLCAST_SUCCEEDED ignores non-arena units", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    EB:Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 27619)
    EB:Dispatch("UNIT_SPELLCAST_SUCCEEDED", nil, nil, 27619)
end)

H.it(g, "CLEU fires DR + cooldown trackers + re-evaluates", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.setUnit("arena1", { class = "PRIEST", guid = "guid-pr", hp = 100, hpMax = 100 })
    Core:RefreshArenaEnemies()
    H.fireCLEU(0, "SPELL_AURA_APPLIED", false, "src", "Source",
               nil, nil, "guid-pr", "Priest", nil, nil, 42292, "PvP Trinket")
    EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    H.assertFalse(Core.state.enemies.arena1.hasTrinket)
end)

H.it(g, "CLEU SPELL_AURA_APPLIED with category records DR", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.setUnit("arena1", { class = "PRIEST", guid = "guid-pr", hp = 100, hpMax = 100 })
    Core:RefreshArenaEnemies()
    H._gameTime = 1000
    H.ns.DRTracker:Clear()
    H.fireCLEU(H._gameTime, "SPELL_AURA_APPLIED", false, "src", "Source",
               nil, nil, "guid-pr", "Priest", nil, nil, H.ns.Spells.HAMMER_OF_JUSTICE, "HoJ")
    EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    H.assertTrue(H.ns.DRTracker:NextMultiplier("guid-pr", "STUN") < 1.0)
end)

H.it(g, "CLEU with nil info is a no-op", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.fireCLEU(nil)
    EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
end)

H.it(g, "CLEU SPELL_AURA_REMOVED clears important buffs", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.setUnit("arena1", { class = "MAGE", guid = "guid-mage", hp = 100, hpMax = 100 })
    Core:RefreshArenaEnemies()
    Core.state.enemies.arena1.importantBuffs[27619] = true
    H.fireCLEU(0, "SPELL_AURA_REMOVED", false, "src", "Source",
               nil, nil, "guid-mage", "Mage", nil, nil, 27619, "Ice Block")
    EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    H.assertNil(Core.state.enemies.arena1.importantBuffs[27619])
end)
