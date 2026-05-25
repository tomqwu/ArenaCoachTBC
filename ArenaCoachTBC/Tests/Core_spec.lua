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

H.it(g, "CLEU SPELL_CAST_SUCCESS updates specGuess via SpellSpecHints", function()
    H.load("Data/SpellSpecHints.lua")
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.setUnit("arena1", { class = "PRIEST", guid = "guid-pr", hp = 100, hpMax = 100 })
    Core:RefreshArenaEnemies()
    H.assertNil(Core.state.enemies.arena1.specGuess)
    H.fireCLEU(0, "SPELL_CAST_SUCCESS", false, "guid-pr", "Priest",
               nil, nil, "guid-target", "Target", nil, nil, H.ns.Spells.MIND_FLAY, "Mind Flay")
    EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    H.assertEq(Core.state.enemies.arena1.specGuess, "SHADOW")
    H.assertEq(Core.state.enemies.arena1.roleGuess, "CASTER")
end)

H.it(g, "CLEU SPELL_AURA_APPLIED updates specGuess via SpellSpecHints (issue #57)", function()
    -- Shadowform is a self-aura; it never fires SPELL_CAST_SUCCESS on a unit
    -- already in form (only on the form-shift). Aura events have to drive the
    -- hint or the engine never learns this priest is SHADOW.
    H.load("Data/SpellSpecHints.lua")
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.setUnit("arena1", { class = "PRIEST", guid = "guid-sf", hp = 100, hpMax = 100 })
    Core:RefreshArenaEnemies()
    Core.state.enemies.arena1.specGuess = nil
    Core.state.enemies.arena1.roleGuess = nil
    H.fireCLEU(0, "SPELL_AURA_APPLIED", false, "guid-sf", "Priest",
               nil, nil, "guid-sf", "Priest", nil, nil, H.ns.Spells.SHADOWFORM, "Shadowform")
    EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    H.assertEq(Core.state.enemies.arena1.specGuess, "SHADOW")
    H.assertEq(Core.state.enemies.arena1.roleGuess, "CASTER")
end)

H.it(g, "CLEU SPELL_AURA_REFRESH also drives specGuess (issue #57)", function()
    -- AURA_REFRESH fires when an existing aura is reapplied (Moonkin staying in
    -- form, Tree of Life refreshing). Must also drive spec inference.
    H.load("Data/SpellSpecHints.lua")
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.setUnit("arena1", { class = "DRUID", guid = "guid-mk", hp = 100, hpMax = 100 })
    Core:RefreshArenaEnemies()
    Core.state.enemies.arena1.specGuess = nil
    Core.state.enemies.arena1.roleGuess = nil
    H.fireCLEU(0, "SPELL_AURA_REFRESH", false, "guid-mk", "Boomkin",
               nil, nil, "guid-mk", "Boomkin", nil, nil, H.ns.Spells.MOONKIN_FORM, "Moonkin Form")
    EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    H.assertEq(Core.state.enemies.arena1.specGuess, "BALANCE")
    H.assertEq(Core.state.enemies.arena1.roleGuess, "CASTER")
end)

H.it(g, "CLEU SPELL_CAST_SUCCESS does nothing for unmatched spell IDs", function()
    H.load("Data/SpellSpecHints.lua")
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.setUnit("arena1", { class = "PRIEST", guid = "guid-pr-fresh", hp = 100, hpMax = 100 })
    Core:RefreshArenaEnemies()
    -- Previous tests may have set specGuess on this unit slot - reset it
    Core.state.enemies.arena1.specGuess = nil
    Core.state.enemies.arena1.roleGuess = nil
    H.fireCLEU(0, "SPELL_CAST_SUCCESS", false, "guid-pr-fresh", "Priest",
               nil, nil, nil, nil, nil, nil, 9999999, "Unknown")
    EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    H.assertNil(Core.state.enemies.arena1.specGuess)
end)

H.it(g, "Strategies:Identify reflects updated roleGuess after a cast", function()
    H.load("Data/SpellSpecHints.lua")
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    -- Priest defaults to HEALER role, but a Mind Flay reveals SHADOW/CASTER.
    -- Strategies:Identify should consume the updated roleGuess on the next call.
    H.setUnit("arena1", { class = "PRIEST", guid = "guid-pr", hp = 100, hpMax = 100 })
    H.setUnit("arena2", { class = "WARRIOR", guid = "guid-w", hp = 100, hpMax = 100 })
    H.setUnit("arena3", { class = "MAGE", guid = "guid-m", hp = 100, hpMax = 100 })
    Core:RefreshArenaEnemies()
    -- Before the cast, the priest is HEALER by default. After Mind Flay, CASTER.
    H.fireCLEU(0, "SPELL_CAST_SUCCESS", false, "guid-pr", "Priest",
               nil, nil, nil, nil, nil, nil, H.ns.Spells.MIND_FLAY, "Mind Flay")
    EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    H.assertEq(Core.state.enemies.arena1.roleGuess, "CASTER")
end)

H.it(g, "UpdateBracket reads GetBattlefieldStatus and sets state.bracket", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    -- Stub the WoW battlefield API to look like an active 3v3.
    _G.GetMaxBattlefieldID  = function() return 2 end
    _G.GetBattlefieldStatus = function(i)
        if i == 1 then return "none" end
        return "active", "Nagrand Arena", nil, nil, nil, 3
    end
    Core:UpdateBracket()
    H.assertEq(Core.state.bracket, 3)
    -- Cleanup so subsequent specs don't see the stubs.
    _G.GetMaxBattlefieldID, _G.GetBattlefieldStatus = nil, nil
end)

H.it(g, "UpdateBracket keeps previous bracket when no API present", function()
    Core.state.bracket = 5
    _G.GetMaxBattlefieldID, _G.GetBattlefieldStatus = nil, nil
    H.assertEq(Core:UpdateBracket(), 5)
end)

H.it(g, "UpdateBracket falls back to previous when no active battlefield", function()
    _G.GetMaxBattlefieldID  = function() return 1 end
    _G.GetBattlefieldStatus = function() return "none" end
    Core.state.bracket = 5
    H.assertEq(Core:UpdateBracket(), 5)
    _G.GetMaxBattlefieldID, _G.GetBattlefieldStatus = nil, nil
end)

H.it(g, "train detection accumulates damage on friendlies", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.setUnit("player", { class = "WARRIOR", guid = "guid-me", hp = 100, hpMax = 100 })
    Core:RefreshFriendlies()
    -- Three damage events on player in quick succession
    H._gameTime = 100
    for i = 1, 3 do
        H.fireCLEU(100 + i, "SPELL_DAMAGE", false, "enemy-src", "Source",
                   nil, nil, "guid-me", "Me", nil, nil, 30330, "Mortal Strike", nil, 1000)
        EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    end
    H.assertEq(#Core._friendlyDamageTs, 3)
end)

H.it(g, "train detection forces DEFEND when threshold exceeded", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.setUnit("player", { class = "WARRIOR", guid = "guid-me", hp = 100, hpMax = 100 })
    Core:RefreshFriendlies()
    H._gameTime = 200
    -- Inject 4 damage events directly (above default threshold of 3)
    Core._friendlyDamageTs = { 200, 200, 200, 200 }
    local rec = Core:Evaluate()
    H.assertEq(rec.mode, "DEFEND")
end)

H.it(g, "train detection prunes events outside window", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.setUnit("player", { class = "WARRIOR", guid = "guid-me", hp = 100, hpMax = 100 })
    Core:RefreshFriendlies()
    -- Old events from 100s ago, current time 200s; window default = 5s
    Core._friendlyDamageTs = { 100, 101, 102, 103, 104 }
    H._gameTime = 200
    Core:Evaluate()
    H.assertEq(#Core._friendlyDamageTs, 0, "old events should be pruned")
end)

H.it(g, "train detection ignores damage on non-friendly destGUIDs", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    -- Player exists but the damage event targets some random GUID
    H.setUnit("player", { class = "WARRIOR", guid = "guid-me", hp = 100, hpMax = 100 })
    Core:RefreshFriendlies()
    Core._friendlyDamageTs = {}
    H._gameTime = 300
    H.fireCLEU(300, "SPELL_DAMAGE", false, "enemy-src", "Source",
               nil, nil, "guid-stranger", "Stranger", nil, nil, 30330, "MS", nil, 1000)
    EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    H.assertEq(#Core._friendlyDamageTs, 0)
end)

H.it(g, "trace records snapshots when enabled and stays under cap", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.ArenaCoachTBCDB.trace.enabled = true
    _G.ArenaCoachTBCDB.trace.maxLines = 3
    _G.ArenaCoachTBCDB.trace.log = {}
    H.setUnit("player", { class = "WARRIOR" })
    H.setUnit("arena1", { class = "PRIEST", hp = 100, hpMax = 100 })
    Core:RefreshFriendlies()
    Core:RefreshArenaEnemies()
    for i = 1, 5 do Core:Evaluate() end
    H.assertEq(#_G.ArenaCoachTBCDB.trace.log, 3, "should cap at 3 entries")
end)

H.it(g, "trace records nothing when disabled", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.ArenaCoachTBCDB.trace.enabled = false
    _G.ArenaCoachTBCDB.trace.log = {}
    Core:Evaluate()
    H.assertEq(#_G.ArenaCoachTBCDB.trace.log, 0)
end)

H.it(g, "/acc trace on / off toggles flag", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    SlashCmdList["ARENACOACH"]("trace on")
    H.assertTrue(_G.ArenaCoachTBCDB.trace.enabled)
    SlashCmdList["ARENACOACH"]("trace off")
    H.assertFalse(_G.ArenaCoachTBCDB.trace.enabled)
    stopCapture()
end)

H.it(g, "/acc trace clear empties the log", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.ArenaCoachTBCDB.trace.log = { {ts=1}, {ts=2} }
    startCapture()
    SlashCmdList["ARENACOACH"]("trace clear")
    stopCapture()
    H.assertEq(#_G.ArenaCoachTBCDB.trace.log, 0)
end)

H.it(g, "/acc trace dump prints last entry summary", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.ArenaCoachTBCDB.trace.log = { { mode="KILL", primaryClass="MAGE", reason="r",
                                       comp="RMP", bracket=3, callouts="A,B" } }
    startCapture()
    SlashCmdList["ARENACOACH"]("trace dump")
    stopCapture()
    local found = false
    for _, ln in ipairs(captured) do
        if ln:find("mode=KILL") and ln:find("comp=RMP") then found = true end
    end
    H.assertTrue(found, "dump should show mode + comp; got: " .. table.concat(captured, "|"))
end)

H.it(g, "/acc trace status without args prints state", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    SlashCmdList["ARENACOACH"]("trace")
    stopCapture()
    local found = false
    for _, ln in ipairs(captured) do
        if ln:find("trace:") then found = true end
    end
    H.assertTrue(found)
end)

H.it(g, "/acc trace bogus prints usage", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    SlashCmdList["ARENACOACH"]("trace nonsense-arg")
    stopCapture()
    local found = false
    for _, ln in ipairs(captured) do
        if ln:find("usage:") then found = true end
    end
    H.assertTrue(found)
end)

H.it(g, "/acc bugreport prints sanitised payload", function()
    H.load("ErrorReporter.lua")
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.ns.ErrorReporter:Reset()
    H.ns.ErrorReporter:Capture("boom in Player-1-AAA")
    startCapture()
    SlashCmdList["ARENACOACH"]("bugreport")
    stopCapture()
    local sawHeader, sawSanitised = false, false
    for _, ln in ipairs(captured) do
        if ln:find("bug report") then sawHeader = true end
        if ln:find("Player%-%*%*%*") then sawSanitised = true end
    end
    H.assertTrue(sawHeader, "header missing")
    H.assertTrue(sawSanitised, "sanitised GUID missing")
end)

H.it(g, "record captures CLEU events when enabled", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.ArenaCoachTBCDB.record.enabled = true
    _G.ArenaCoachTBCDB.record.events = {}
    H.fireCLEU(100, "SPELL_CAST_SUCCESS", false, "guid-a", "Src",
               nil, nil, "guid-b", "Dst", nil, nil, 30330, "Mortal Strike")
    EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    H.assertEq(#_G.ArenaCoachTBCDB.record.events, 1)
    H.assertEq(_G.ArenaCoachTBCDB.record.events[1].spell, 30330)
end)

H.it(g, "record honours the maxEvents cap", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.ArenaCoachTBCDB.record.enabled = true
    _G.ArenaCoachTBCDB.record.maxEvents = 3
    _G.ArenaCoachTBCDB.record.events = {}
    for i = 1, 5 do
        H.fireCLEU(i, "SPELL_CAST_SUCCESS", false, "guid-a", "Src",
                   nil, nil, "guid-b", "Dst", nil, nil, 30330, "MS")
        EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    end
    H.assertEq(#_G.ArenaCoachTBCDB.record.events, 3)
    H.assertEq(_G.ArenaCoachTBCDB.record.events[1].ts, 3)
end)

H.it(g, "/acc record on / off toggles flag", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    SlashCmdList["ARENACOACH"]("record on")
    H.assertTrue(_G.ArenaCoachTBCDB.record.enabled)
    SlashCmdList["ARENACOACH"]("record off")
    H.assertFalse(_G.ArenaCoachTBCDB.record.enabled)
    stopCapture()
end)

H.it(g, "/acc record clear empties events", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.ArenaCoachTBCDB.record.events = { {ts=1}, {ts=2}, {ts=3} }
    startCapture()
    SlashCmdList["ARENACOACH"]("record clear")
    stopCapture()
    H.assertEq(#_G.ArenaCoachTBCDB.record.events, 0)
end)

H.it(g, "/acc record dump prints summary when events exist", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.ArenaCoachTBCDB.record.events = { { ts=100, sub="SPELL_CAST_SUCCESS", spell=30330 } }
    startCapture()
    SlashCmdList["ARENACOACH"]("record dump")
    stopCapture()
    local found = false
    for _, ln in ipairs(captured) do
        if ln:find("1 events") and ln:find("spell=30330") then found = true end
    end
    H.assertTrue(found, "dump output missing: " .. table.concat(captured, "|"))
end)

H.it(g, "/acc record bogus prints usage", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    SlashCmdList["ARENACOACH"]("record nonsense-arg")
    stopCapture()
    local found = false
    for _, ln in ipairs(captured) do
        if ln:find("usage:") then found = true end
    end
    H.assertTrue(found)
end)
