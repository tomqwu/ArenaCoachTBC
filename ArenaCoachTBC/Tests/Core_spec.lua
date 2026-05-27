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
H.load("Data/SpellSpecHints.lua")
H.load("EventBus.lua")
H.load("CooldownTracker.lua")
H.load("DRTracker.lua")
H.load("StrategyEngine.lua")
H.load("UI.lua")
H.load("Options.lua")
H.load("WeakAuraBridge.lua")
H.load("Simulator.lua")
H.load("Data/SimScenarios.lua")
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

H.it(g, "InitDB migrates only untouched prototype-A side positions", function()
    _G.ArenaCoachTBCDB = {
        unitFrame = { point = "CENTER", x = -258, y = 120, scale = 1.0 },
        railFrame = { point = "CENTER", x = 258, y = 120, scale = 1.0 },
    }
    local db = Core:InitDB()
    H.assertEq(db.unitFrame.x, -230)
    H.assertEq(db.railFrame.x, 230)
    H.assertEq(db.layoutVersion, 2814)

    _G.ArenaCoachTBCDB = {
        unitFrame = { point = "CENTER", x = -180, y = 96, scale = 1.0 },
        railFrame = { point = "CENTER", x = 190, y = 88, scale = 1.0 },
    }
    db = Core:InitDB()
    H.assertEq(db.unitFrame.x, -180)
    H.assertEq(db.unitFrame.y, 96)
    H.assertEq(db.railFrame.x, 190)
    H.assertEq(db.railFrame.y, 88)
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

H.it(g, "Refresh clears stale enemy identity when arena unit disappears", function()
    H.setUnit("arena4", { class = "MAGE", guid = "guid-stale-mage", hp = 100, hpMax = 100 })
    Core:RefreshArenaEnemies()
    H.assertEq(Core.state.enemies.arena4.class, "MAGE")
    H.setUnit("arena4", nil)
    Core:RefreshArenaEnemies()
    H.assertFalse(Core.state.enemies.arena4.alive)
    H.assertNil(Core.state.enemies.arena4.class)
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

H.it(g, "RunTestMode (default) runs the realistic arena simulator", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.C_Timer = nil  -- force synchronous fallback so beats fire inline
    if not H.ns.UI.frame then H.ns.UI:CreateFrame() end
    startCapture()
    Core:RunTestMode()
    stopCapture()
    local sawStart, sawEnd = false, false
    for _, ln in ipairs(captured) do
        if ln:find("Realistic 3v3 arena", 1, true) then sawStart = true end
        if ln:find("Arena round ends", 1, true) then sawEnd = true end
    end
    H.assertTrue(sawStart, "expected realistic arena simulator start")
    H.assertTrue(sawEnd, "expected final arena reset event")
    H.assertEq(Core.state.pvpContext, "arena")
    H.assertEq(Core.state.bracket, 3)
end)

H.it(g, "RunTestMode 'print' triggers the legacy chat-only summary", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    Core:RunTestMode("print")
    stopCapture()
    -- Print mode walks all testComps (5 of them) + header
    H.assertTrue(#captured >= 5, "print mode should emit >=5 lines")
end)

H.it(g, "RunTestMode hud demo restores frame visibility when it started hidden", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.C_Timer = nil  -- synchronous fallback runs end-of-demo restore immediately
    if not H.ns.UI.frame then H.ns.UI:CreateFrame() end
    H.ns.UI:Hide()
    startCapture()
    Core:RunTestMode("hud")
    stopCapture()
    -- After the synchronous restore fires, frame should be hidden again
    H.assertFalse(H.ns.UI.frame._shown,
        "demo should restore hidden state when it started hidden")
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

H.it(g, "/acc visual toggles update persisted settings", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()

    SlashCmdList["ARENACOACH"]("highcontrast on")
    H.assertTrue(_G.ArenaCoachTBCDB.frame.highContrast)
    SlashCmdList["ARENACOACH"]("highcontrast off")
    H.assertFalse(_G.ArenaCoachTBCDB.frame.highContrast)
    SlashCmdList["ARENACOACH"]("hc")
    H.assertTrue(_G.ArenaCoachTBCDB.frame.highContrast)

    SlashCmdList["ARENACOACH"]("verbose on")
    H.assertTrue(_G.ArenaCoachTBCDB.frame.verbose)
    SlashCmdList["ARENACOACH"]("verbose off")
    H.assertFalse(_G.ArenaCoachTBCDB.frame.verbose)
    SlashCmdList["ARENACOACH"]("verbose")
    H.assertTrue(_G.ArenaCoachTBCDB.frame.verbose)

    SlashCmdList["ARENACOACH"]("off")
    H.assertFalse(_G.ArenaCoachTBCDB.enabled)
    SlashCmdList["ARENACOACH"]("on")
    H.assertTrue(_G.ArenaCoachTBCDB.enabled)

    SlashCmdList["ARENACOACH"]("glow on")
    H.assertTrue(_G.ArenaCoachTBCDB.alerts.edgeGlow)
    SlashCmdList["ARENACOACH"]("glow off")
    H.assertFalse(_G.ArenaCoachTBCDB.alerts.edgeGlow)
    SlashCmdList["ARENACOACH"]("glow")
    H.assertTrue(_G.ArenaCoachTBCDB.alerts.edgeGlow)

    SlashCmdList["ARENACOACH"]("nameplate off")
    H.assertFalse(_G.ArenaCoachTBCDB.alerts.nameplate)
    SlashCmdList["ARENACOACH"]("nameplate on")
    H.assertTrue(_G.ArenaCoachTBCDB.alerts.nameplate)
    SlashCmdList["ARENACOACH"]("nameplate")
    H.assertFalse(_G.ArenaCoachTBCDB.alerts.nameplate)

    stopCapture()
    H.assertTrue(#captured >= 10)
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
    -- v2.4.0: per-beat chat lines only print in verbose mode now.
    _G.ArenaCoachTBCDB.frame.verbose = true
    startCapture()
    SlashCmdList["ARENACOACH"]("test")
    stopCapture()
    H.assertTrue(#captured >= 5)
end)

H.it(g, "/acc test hud forwards the hud subcommand", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.ArenaCoachTBCDB.frame.verbose = true
    _G.C_Timer = nil
    if not H.ns.UI.frame then H.ns.UI:CreateFrame() end
    startCapture()
    SlashCmdList["ARENACOACH"]("test hud")
    stopCapture()
    local sawHudStart = false
    for _, ln in ipairs(captured) do
        if ln:find("arena RMP 3v3 HUD walk-through", 1, true) then sawHudStart = true end
    end
    H.assertTrue(sawHudStart, "slash /acc test hud should run the HUD tour, not the real-arena replay")
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

local function clearArenaApis()
    _G.IsActiveBattlefieldArena = nil
    _G.GetInstanceInfo = nil
    _G.GetMaxBattlefieldID = nil
    _G.GetBattlefieldStatus = nil
    _G.GetPersonalRatedInfo = nil
    Core._friendlyDamageTs = {}
end

local function setupRealisticArena3v3()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil
    Core:InitDB()
    Core.state.enemies = {}
    Core.state.friendlies = {}
    Core.state.observations = {}
    Core._friendlyDamageTs = {}
    H.ns.WeakAuraBridge._last = nil
    H.ns.WeakAuraBridge._state = nil
    if H.ns.UI then H.ns.UI._flash = nil; H.ns.UI:CreateFrame() end
    H._unitData = {}
    H.clearAuras()
    H._gameTime = 1000

    _G.IsActiveBattlefieldArena = function() return true end
    _G.GetInstanceInfo = function() return "Nagrand Arena", "arena" end
    _G.GetMaxBattlefieldID = function() return 1 end
    _G.GetBattlefieldStatus = function()
        return "active", "Nagrand Arena", nil, nil, nil, 3
    end

    H.setUnit("player", { class = "WARRIOR", guid = "guid-player", name = "Warrior", hp = 10000, hpMax = 10000 })
    H.setUnit("party1", { class = "SHAMAN",  guid = "guid-shaman", name = "Shaman",  hp = 10000, hpMax = 10000 })
    H.setUnit("party2", { class = "PALADIN", guid = "guid-pal",    name = "Paladin", hp = 10000, hpMax = 10000 })
    H.setUnit("party3", { class = "DRUID",   guid = "guid-druid",  name = "Druid",   hp = 10000, hpMax = 10000 })
    H.setUnit("party4", { class = "PRIEST",  guid = "guid-priest-friendly", name = "Priest", hp = 10000, hpMax = 10000 })

    H.setUnit("arena1", { class = "PRIEST", guid = "guid-enemy-priest", name = "EnemyPriest", hp = 10000, hpMax = 10000, mp = 7000, mpMax = 10000 })
    H.setUnit("arena2", { class = "MAGE",   guid = "guid-enemy-mage",   name = "EnemyMage",   hp = 10000, hpMax = 10000, mp = 8000, mpMax = 10000 })
    H.setUnit("arena3", { class = "ROGUE",  guid = "guid-enemy-rogue",  name = "EnemyRogue",  hp = 10000, hpMax = 10000 })
    H.setUnit("arena4", { exists = false })
    H.setUnit("arena5", { exists = false })
end

H.it(g, "EventBus PLAYER_ENTERING_WORLD handler runs without error", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    EB:Dispatch("PLAYER_ENTERING_WORLD")
end)

H.it(g, "v2.7.2: ARENA_OPPONENT_UPDATE no longer flips combatPhase to ACTIVE", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    Core.state.combatPhase = "PRE"
    H.setUnit("arena1", { class = "PRIEST", hp = 100, hpMax = 100 })
    EB:Dispatch("ARENA_OPPONENT_UPDATE")
    -- Pre-v2.7.2 this flipped to ACTIVE the moment opponents became
    -- visible — which is BEFORE the arena gates open. User report:
    -- "it suggest to kill even before the game". PLAYER_REGEN_DISABLED
    -- is the legitimate PRE -> ACTIVE transition.
    H.assertEq(Core.state.combatPhase, "PRE",
        "ARENA_OPPONENT_UPDATE must NOT transition PRE -> ACTIVE")
end)

H.it(g, "v2.7.2: PLAYER_ENTERING_WORLD resets per-match state", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    -- Seed stale state from a 'previous match' — phantom enemies + ACTIVE
    -- phase from when the player left an arena.
    Core.state.enemies = {
        ["ghost1"] = { unit = "arena1", guid = "ghost1", class = "MAGE",
                       name = "PhantomName", alive = false, healthPct = 0 },
    }
    Core.state.enemyClassList = { "MAGE" }
    Core.state.lastPrimaryGUID = "ghost1"
    Core.state.combatPhase = "POST"
    EB:Dispatch("PLAYER_ENTERING_WORLD")
    -- Fresh state for the next match:
    H.assertEq(Core.state.combatPhase, "PRE", "PEW must reset combatPhase to PRE")
    H.assertNil(Core.state.lastPrimaryGUID, "PEW must clear lastPrimaryGUID")
    H.assertNil(next(Core.state.enemies),
        "PEW must clear state.enemies so phantom names don't leak into the next match")
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

H.it(g, "real arena lifecycle stays OPEN before gates and KILLs after combat starts", function()
    setupRealisticArena3v3()
    EB:Dispatch("PLAYER_ENTERING_WORLD")
    EB:Dispatch("ARENA_OPPONENT_UPDATE")

    H.assertEq(Core.state.pvpContext, "arena")
    H.assertEq(Core.state.bracket, 3)
    H.assertEq(Core.state.combatPhase, "PRE")
    H.assertEq(_G.ArenaCoachTBC.GetMode(), "OPEN",
        "visible arena opponents before combat should plan opener, not call KILL")

    EB:Dispatch("PLAYER_REGEN_DISABLED")
    H.assertEq(Core.state.combatPhase, "ACTIVE")
    H.assertEq(_G.ArenaCoachTBC.GetMode(), "KILL")
    H.assertEq(_G.ArenaCoachTBC.GetPrimaryTargetClass(), "PRIEST")
    H.assertEq(_G.ArenaCoachTBC.GetEnemyComp(), "RMP_3V3")
    H.assertNil(H.ns.UI._flash, "arena recommendations should not create a full-screen flash")
    clearArenaApis()
end)

H.it(g, "real arena healer-train damage flips DEFEND through CLEU without flashing", function()
    setupRealisticArena3v3()
    _G.ArenaCoachTBCDB.alerts.screenFlash = true -- legacy saved setting should still be quiet
    EB:Dispatch("PLAYER_ENTERING_WORLD")
    EB:Dispatch("ARENA_OPPONENT_UPDATE")
    EB:Dispatch("PLAYER_REGEN_DISABLED")
    H.assertEq(_G.ArenaCoachTBC.GetMode(), "KILL")

    for i = 1, 3 do
        H.fireCLEU(1000 + i, "SPELL_DAMAGE", false, "guid-enemy-rogue", "EnemyRogue",
                   nil, nil, "guid-priest-friendly", "Priest", nil, nil,
                   H.ns.Spells.HEMORRHAGE, "Hemorrhage", nil, 1200)
        EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    end

    H.assertEq(_G.ArenaCoachTBC.GetMode(), "DEFEND",
        "repeated real CLEU damage on our healer should publish DEFEND")
    H.assertTrue(Core.state.observations.healerUnderPressure,
        "healer train signal should be present on state")
    H.assertNil(H.ns.UI._flash, "legacy screenFlash=true must not strobe during the arena run")
    clearArenaApis()
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

H.it(g, "CLEU accepts legacy vararg SPELL and SWING payloads", function()
    setupRealisticArena3v3()
    Core:RefreshFriendlies()
    Core:RefreshArenaEnemies()
    Core.state.combatPhase = "ACTIVE"

    local saved = _G.CombatLogGetCurrentEventInfo
    _G.CombatLogGetCurrentEventInfo = nil
    local ok, err = pcall(function()
        EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED",
            1000, "SPELL_AURA_APPLIED",
            "src", "Source", nil,
            "guid-enemy-priest", "EnemyPriest", nil,
            42292, "PvP Trinket")
        H.assertFalse(Core.state.enemies.arena1.hasTrinket,
            "legacy SPELL_* payload should still expose spellID")

        for i = 1, 3 do
            EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED",
                1000 + i, "SWING_DAMAGE",
                "guid-enemy-rogue", "EnemyRogue", nil,
                "guid-priest-friendly", "Priest", nil,
                1200, 0, 1)
        end
        H.assertTrue(Core.state.observations.healerUnderPressure,
            "legacy SWING_* payload should still count healer pressure")
        H.assertNil(H.ns.CooldownTracker:GetRemaining("guid-enemy-rogue", 1200),
            "SWING_DAMAGE amount must not be parsed as a spell ID")
    end)
    _G.CombatLogGetCurrentEventInfo = saved
    clearArenaApis()
    if not ok then error(err) end
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

H.it(g, "train detection accumulates damage on friendly healers", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.setUnit("player", { class = "PRIEST", guid = "guid-me", hp = 100, hpMax = 100 })
    Core:RefreshFriendlies()
    Core._friendlyDamageTs = {}
    -- Three damage events on a healer in quick succession
    H._gameTime = 100
    for i = 1, 3 do
        H.fireCLEU(100 + i, "SPELL_DAMAGE", false, "enemy-src", "Source",
                   nil, nil, "guid-me", "Me", nil, nil, 30330, "Mortal Strike", nil, 1000)
        EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    end
    H.assertEq(#Core._friendlyDamageTs, 3)
end)

H.it(g, "train detection ignores damage on non-healer friendlies", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.setUnit("player", { class = "WARRIOR", guid = "guid-war", hp = 100, hpMax = 100 })
    Core:RefreshFriendlies()
    Core._friendlyDamageTs = {}
    H.fireCLEU(100, "SPELL_DAMAGE", false, "enemy-src", "Source",
               nil, nil, "guid-war", "Me", nil, nil, 30330, "Mortal Strike", nil, 1000)
    EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    H.assertEq(#Core._friendlyDamageTs, 0)
end)

H.it(g, "train detection forces DEFEND when threshold exceeded", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    -- v2.7.1: explicitly clear state.enemies so the v2.7.1 arena
    -- outnumbered-override doesn't suppress DEFEND. Earlier tests in
    -- the same Lua process (e.g. BGModeE2E's buildBG10) leave 10
    -- enemies in Core.state; rebootForEvents only resets the event
    -- bus, not the shared state table.
    Core.state.enemies = {}
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

H.it(g, "aura observations detect live burst, CC, and dispel signals", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.clearAuras()
    H.setUnit("player", { class = "PRIEST", guid = "guid-me", hp = 100, hpMax = 100 })
    H.setUnit("arena1", { class = "PRIEST", guid = "guid-pr", hp = 100, hpMax = 100 })
    H.setAuras("player", "HELPFUL", {
        { name = "Windfury Totem", spellID = H.ns.Spells.WINDFURY_TOTEM },
        { name = "Blessing of Freedom", spellID = H.ns.Spells.BLESSING_FREEDOM },
        { name = "Bloodlust", spellID = H.ns.Spells.BLOODLUST },
    })
    H.setAuras("player", "HARMFUL", {
        { name = "Hammer of Justice", spellID = H.ns.Spells.HAMMER_OF_JUSTICE },
        { name = "Psychic Scream", spellID = H.ns.Spells.PSYCHIC_SCREAM },
        { name = "Polymorph", spellID = H.ns.Spells.POLYMORPH_SHEEP },
        { name = "Blind", spellID = H.ns.Spells.BLIND },
        { name = "Frost Nova", spellID = H.ns.Spells.FROST_NOVA },
        { name = "Counterspell", spellID = H.ns.Spells.COUNTERSPELL },
    })
    H.setAuras("arena1", "HELPFUL", {
        { name = "Ice Block", spellID = H.ns.Spells.ICE_BLOCK },
        { name = "Pain Suppression", spellID = H.ns.Spells.PAIN_SUPPRESSION },
        { name = "Blessing of Freedom", spellID = H.ns.Spells.BLESSING_FREEDOM },
        { name = "Bloodlust", spellID = H.ns.Spells.BLOODLUST },
        { name = "Death Wish", spellID = H.ns.Spells.DEATH_WISH },
    })
    H.setAuras("arena1", "HARMFUL", {
        { name = "Mortal Strike", spellID = H.ns.Spells.MORTAL_STRIKE },
    })
    Core:RefreshFriendlies()
    Core:RefreshArenaEnemies()
    Core:Evaluate()
    H.assertEq(Core.state.observations.msActiveOn, "guid-pr")
    H.assertTrue(Core.state.observations.windfuryActive)
    H.assertTrue(Core.state.observations.bloodlustActive)
    H.assertTrue(Core.state.observations.enemyBloodlustActive)
    H.assertTrue(Core.state.observations.multipleBurstsDetected)
    H.assertTrue(Core.state.observations.priestCanDispel)
    H.assertTrue(Core.state.friendlies.player.buffs.freedom)
    H.assertTrue(Core.state.friendlies.player.debuffs.stunned)
    H.assertTrue(Core.state.friendlies.player.debuffs.feared)
    H.assertTrue(Core.state.friendlies.player.debuffs.sheeped)
    H.assertTrue(Core.state.friendlies.player.debuffs.disoriented)
    H.assertTrue(Core.state.friendlies.player.debuffs.rooted)
    H.assertTrue(Core.state.friendlies.player.debuffs.silenced)
    H.assertTrue(Core.state.enemies.arena1.importantBuffs[H.ns.Spells.ICE_BLOCK])
    H.assertTrue(Core.state.enemies.arena1.importantBuffs[H.ns.Spells.PAIN_SUPPRESSION])
    H.assertTrue(Core.state.enemies.arena1.importantBuffs[H.ns.Spells.BLESSING_FREEDOM])
    H.clearAuras()
end)

H.it(g, "aura observations fall back to UnitBuff and UnitDebuff", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.setUnit("player", { class = "SHAMAN", guid = "guid-me", hp = 100, hpMax = 100 })
    H.setUnit("arena1", { class = "PRIEST", guid = "guid-pr", hp = 100, hpMax = 100 })
    Core:RefreshFriendlies()
    Core:RefreshArenaEnemies()
    local savedAura, savedBuff, savedDebuff = _G.UnitAura, _G.UnitBuff, _G.UnitDebuff
    _G.UnitAura = nil
    _G.UnitBuff = function(unit, i)
        if unit == "player" and i == 1 then
            return "Windfury Totem", nil, nil, nil, nil, nil, nil, nil, nil, H.ns.Spells.WINDFURY_TOTEM
        end
    end
    _G.UnitDebuff = function(unit, i)
        if unit == "arena1" and i == 1 then
            return "Mortal Strike", nil, nil, nil, nil, nil, nil, nil, nil, H.ns.Spells.MORTAL_STRIKE
        end
    end
    Core:RefreshAuraObservations()
    H.assertTrue(Core.state.observations.windfuryActive)
    H.assertEq(Core.state.observations.msActiveOn, "guid-pr")
    _G.UnitAura, _G.UnitBuff, _G.UnitDebuff = savedAura, savedBuff, savedDebuff
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

-- =================================================================
-- M11 #71: rating-aware aggression
-- =================================================================

H.it(g, "CurrentAggression returns explicit string when set", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.assertEq(Core:CurrentAggression({ config = { strategy = { ratingAggression = "greedy" } } }), "greedy")
end)

H.it(g, "CurrentAggression resolves auto from state.rating", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    local cfg = { config = { strategy = { ratingAggression = "auto" } } }
    H.assertEq(Core:CurrentAggression({ rating = 1500, config = cfg.config }), "greedy")
    H.assertEq(Core:CurrentAggression({ rating = 2000, config = cfg.config }), "balanced")
    H.assertEq(Core:CurrentAggression({ rating = 2400, config = cfg.config }), "safe")
end)

H.it(g, "CurrentAggression falls back to config.aggression when no rating", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.assertEq(Core:CurrentAggression({
        config = { strategy = { ratingAggression = "auto", aggression = "balanced" } } }), "balanced")
end)

H.it(g, "CurrentAggression treats numeric ratingAggression as a rating override", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    H.assertEq(Core:CurrentAggression({
        config = { strategy = { ratingAggression = 2500 } } }), "safe")
end)

H.it(g, "UpdateRating returns nil without the WoW API", function()
    -- GetPersonalRatedInfo isn't defined in headless tests
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    Core.state = Core.state or { bracket = 5 }
    Core.state.bracket = 5
    H.assertNil(Core:UpdateRating())
end)

-- =================================================================
-- M10 #68: /acc whatif counterfactual replay
-- =================================================================

H.it(g, "ReplayRecord runs events through engine without polluting trackers", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    local events = {
        { ts = 0,   sub = "SPELL_CAST_SUCCESS", src = "g1", dst = "g2", spell = H.ns.Spells.KIDNEY_SHOT },
        { ts = 1.5, sub = "SPELL_AURA_APPLIED", src = "g1", dst = "g2", spell = H.ns.Spells.KIDNEY_SHOT },
    }
    -- Snapshot live tracker state before / after — must be unchanged.
    local ctBefore = next(H.ns.CooldownTracker._cooldowns or {})
    local drBefore = next(H.ns.DRTracker._state or {})
    local out = Core:ReplayRecord(events)
    H.assertTrue(#out >= 1, "expected at least one rec snapshot from replay")
    H.assertEq(next(H.ns.CooldownTracker._cooldowns or {}), ctBefore,
        "ReplayRecord must not leak into live CooldownTracker")
    H.assertEq(next(H.ns.DRTracker._state or {}), drBefore,
        "ReplayRecord must not leak into live DRTracker")
end)

H.it(g, "DiffReplays returns 0 differences for identical sequences", function()
    local a = { { mode = "KILL", comp = "RMP", chainId = "x" } }
    local b = { { mode = "KILL", comp = "RMP", chainId = "x" } }
    local n, samples = Core:DiffReplays(a, b)
    H.assertEq(n, 0)
    H.assertEq(#samples, 0)
end)

H.it(g, "DiffReplays reports differences with samples", function()
    local a = { { mode = "KILL", comp = "RMP", chainId = "x" } }
    local b = { { mode = "SWAP", comp = "RMP", chainId = "x" } }
    local n, samples = Core:DiffReplays(a, b)
    H.assertEq(n, 1)
    H.assertEq(#samples, 1)
    H.assertTrue(samples[1].base:find("KILL") ~= nil)
    H.assertTrue(samples[1].cf:find("SWAP") ~= nil)
end)

H.it(g, "/acc whatif with no record reports 'no recording loaded'", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    startCapture()
    SlashCmdList["ARENACOACH"]("whatif")
    stopCapture()
    local found = false
    for _, ln in ipairs(captured) do
        if ln:find("no recording loaded") then found = true end
    end
    H.assertTrue(found, "expected 'no recording loaded' message")
end)

H.it(g, "/acc whatif help prints usage when record is loaded", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.ArenaCoachTBCDB.record.events = {
        { ts = 0, sub = "SPELL_CAST_SUCCESS", src = "g1", dst = "g2", spell = H.ns.Spells.KIDNEY_SHOT },
    }
    startCapture()
    SlashCmdList["ARENACOACH"]("whatif help")
    stopCapture()
    local sawSkip = false
    for _, ln in ipairs(captured) do
        if ln:find("whatif skip") then sawSkip = true end
    end
    H.assertTrue(sawSkip, "expected /acc whatif skip in help text")
end)

H.it(g, "/acc whatif skip <i> prints divergence summary", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.ArenaCoachTBCDB.record.events = {
        { ts = 0, sub = "SPELL_CAST_SUCCESS", src = "g1", dst = "g2", spell = H.ns.Spells.KIDNEY_SHOT },
        { ts = 2, sub = "SPELL_CAST_SUCCESS", src = "g2", dst = "g1", spell = H.ns.Spells.HAMMER_OF_JUSTICE },
    }
    startCapture()
    SlashCmdList["ARENACOACH"]("whatif skip 1")
    stopCapture()
    local found = false
    for _, ln in ipairs(captured) do
        if ln:find("recs diverged") then found = true end
    end
    H.assertTrue(found, "expected divergence output: " .. table.concat(captured, "|"))
end)

-- =================================================================
-- M13 (v2.1): PvP context detection + non-arena enemy discovery
-- =================================================================

local function clearWoWApis()
    -- Used by tests that want to drop into the headless / fixture branch.
    _G.IsActiveBattlefieldArena = nil
    _G.GetInstanceInfo          = nil
    _G.UnitIsPVP                = nil
end

H.it(g, "DetectPvPContext returns 'arena' when IsActiveBattlefieldArena true", function()
    clearWoWApis()
    _G.IsActiveBattlefieldArena = function() return true end
    Core.state = Core.state or {}
    Core.state.pvpContext = nil
    H.assertEq(Core:DetectPvPContext(), "arena")
    H.assertEq(Core.state.pvpContext, "arena")
end)

H.it(g, "DetectPvPContext returns 'bg' when GetInstanceInfo returns pvp", function()
    clearWoWApis()
    _G.IsActiveBattlefieldArena = function() return false end
    _G.GetInstanceInfo          = function() return "Warsong Gulch", "pvp" end
    Core.state.pvpContext = nil
    H.assertEq(Core:DetectPvPContext(), "bg")
end)

H.it(g, "DetectPvPContext returns 'arena' when GetInstanceInfo returns arena (no battlefield API)", function()
    clearWoWApis()
    _G.GetInstanceInfo = function() return "Nagrand Arena", "arena" end
    Core.state.pvpContext = nil
    H.assertEq(Core:DetectPvPContext(), "arena")
end)

H.it(g, "DetectPvPContext returns 'world' when PvP-flagged + recent hostile contact", function()
    clearWoWApis()
    _G.IsActiveBattlefieldArena = function() return false end
    _G.GetInstanceInfo          = function() return nil, nil end
    _G.UnitIsPVP                = function(u) return u == "player" end
    H._gameTime = 1000
    Core.state.pvpContext = nil
    Core._lastWorldHostileTs = 990  -- 10s ago
    H.assertEq(Core:DetectPvPContext(), "world")
end)

H.it(g, "DetectPvPContext returns 'world_idle' when PvP-flagged but no recent hostile", function()
    clearWoWApis()
    _G.IsActiveBattlefieldArena = function() return false end
    _G.GetInstanceInfo          = function() return nil, nil end
    _G.UnitIsPVP                = function(u) return u == "player" end
    H._gameTime = 1000
    Core.state.pvpContext = nil
    Core._lastWorldHostileTs = 900  -- >30s ago
    H.assertEq(Core:DetectPvPContext(), "world_idle")
end)

H.it(g, "DetectPvPContext returns 'none' when nothing PvP", function()
    clearWoWApis()
    _G.IsActiveBattlefieldArena = function() return false end
    _G.GetInstanceInfo          = function() return "Stormwind", "none" end
    _G.UnitIsPVP                = function() return false end
    Core.state.pvpContext = nil
    H.assertEq(Core:DetectPvPContext(), "none")
end)

H.it(g, "DetectPvPContext is permissive headless (preserves fixture)", function()
    clearWoWApis()
    Core.state.pvpContext = "arena"  -- test fixture
    H.assertEq(Core:DetectPvPContext(), "arena", "headless must not trample fixture")
end)

H.it(g, "RefreshEnemiesNonArena populates from nameplate scan", function()
    Core.state = Core.state or {}
    Core.state.enemies = {}
    -- Stub UnitExists + UnitIsEnemy + UnitIsPlayer + UnitGUID + UnitName + UnitClass
    local stubGuid = "guid-baddie"
    _G.UnitExists  = function(u) return u == "nameplate1" end
    _G.UnitIsEnemy = function(_, u) return u == "nameplate1" end
    _G.UnitIsPlayer = function(u) return u == "nameplate1" end
    _G.UnitGUID    = function(u) return u == "nameplate1" and stubGuid or nil end
    _G.UnitName    = function(u) return u == "nameplate1" and "Baddie" or nil end
    _G.UnitClass   = function(u) return u == "nameplate1" and "Rogue", "ROGUE" or nil, nil end
    _G.UnitHealth  = function(u) return u == "nameplate1" and 8000 or 0 end
    _G.UnitHealthMax = function(u) return u == "nameplate1" and 10000 or 0 end
    _G.UnitPower   = function() return 0 end
    _G.UnitPowerMax = function() return 0 end
    _G.UnitIsDeadOrGhost = function() return false end
    H._gameTime = 1000
    Core:RefreshEnemiesNonArena()
    H.assertNotNil(Core.state.enemies[stubGuid],
        "nameplate1 GUID should be keyed in enemies map")
    H.assertEq(Core.state.enemies[stubGuid].name, "Baddie")
    H.assertEq(Core.state.enemies[stubGuid].class, "ROGUE")
end)

H.it(g, "RefreshEnemiesNonArena handles sparse nameplate unit ids", function()
    Core.state = Core.state or {}
    Core.state.enemies = {}
    local stubGuid = "guid-sparse-nameplate"
    _G.UnitExists  = function(u) return u == "nameplate2" end
    _G.UnitIsEnemy = function(_, u) return u == "nameplate2" end
    _G.UnitIsPlayer = function(u) return u == "nameplate2" end
    _G.UnitGUID    = function(u) return u == "nameplate2" and stubGuid or nil end
    _G.UnitName    = function(u) return u == "nameplate2" and "Sparse" or nil end
    _G.UnitClass   = function(u) return u == "nameplate2" and "Mage", "MAGE" or nil, nil end
    _G.UnitHealth  = function(u) return u == "nameplate2" and 5000 or 0 end
    _G.UnitHealthMax = function(u) return u == "nameplate2" and 10000 or 0 end
    _G.UnitPower   = function() return 0 end
    _G.UnitPowerMax = function() return 0 end
    _G.UnitIsDeadOrGhost = function() return false end
    H._gameTime = 1000
    Core:RefreshEnemiesNonArena()
    H.assertNotNil(Core.state.enemies[stubGuid],
        "nameplate scan must continue past a missing nameplate1")
    H.assertEq(Core.state.enemies[stubGuid].class, "MAGE")
end)

H.it(g, "RefreshEnemiesNonArena skips friendly nameplates", function()
    Core.state.enemies = {}
    _G.UnitExists   = function(u) return u == "nameplate1" end
    _G.UnitIsEnemy  = function() return false end  -- friendly
    _G.UnitIsPlayer = function() return true end
    Core:RefreshEnemiesNonArena()
    local count = 0
    for k, _ in pairs(Core.state.enemies) do count = count + 1 end
    H.assertEq(count, 0, "friendly nameplates must not enter enemies map")
end)

H.it(g, "_NonArenaCLEUStub creates entry from CLEU when no nameplate yet", function()
    Core.state.enemies = {}
    H._gameTime = 1000
    Core:_NonArenaCLEUStub("guid-stub", "Sneaky")
    H.assertNotNil(Core.state.enemies["guid-stub"])
    H.assertEq(Core.state.enemies["guid-stub"].name, "Sneaky")
    H.assertEq(Core.state.enemies["guid-stub"]._lastSeen, 1000)
end)

H.it(g, "_NonArenaCLEUStub does not overwrite an existing entry", function()
    Core.state.enemies = { ["guid-known"] = { name = "Real", class = "PRIEST" } }
    Core:_NonArenaCLEUStub("guid-known", "DontOverwrite")
    H.assertEq(Core.state.enemies["guid-known"].name, "Real",
        "must not overwrite existing enemy with stub")
end)

H.it(g, "CLEU creates non-arena enemy stubs only when hostile damage hits us", function()
    rebootForEvents()
    clearWoWApis()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    Core.state.pvpContext = "world"
    Core.state.enemies = {}
    Core._friendlyGUIDs = { ["guid-player"] = { class = "WARRIOR", alive = true } }
    _G.UnitExists = function() return false end
    H._gameTime = 1000

    H.fireCLEU(1000, "SPELL_CAST_SUCCESS", false, "guid-enemy", "Enemy",
               nil, nil, "guid-other", "Other", nil, nil, H.ns.Spells.POLYMORPH, "Polymorph")
    EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    H.assertNil(Core.state.enemies["guid-enemy"],
        "unrelated world CLEU casts should not create phantom enemies")

    H.fireCLEU(1001, "SPELL_DAMAGE", false, "guid-enemy", "Enemy",
               nil, nil, "guid-player", "Player", nil, nil, H.ns.Spells.PYROBLAST, "Pyroblast")
    EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
    H.assertNotNil(Core.state.enemies["guid-enemy"],
        "damage to a friendly should create a combat stub when no nameplate is visible")
end)

H.it(g, "CLEU treats Classic landed swing and damage shield events as pressure", function()
    for _, subEvent in ipairs({ "SWING_DAMAGE_LANDED", "DAMAGE_SHIELD" }) do
        rebootForEvents()
        clearWoWApis()
        _G.ArenaCoachTBCDB = nil; Core:InitDB()
        Core.state.pvpContext = "world"
        Core.state.enemies = {}
        Core._friendlyGUIDs = { ["guid-player"] = { class = "DRUID", alive = true } }
        Core._friendlyDamageTs = {}
        _G.UnitExists = function() return false end
        H._gameTime = 1000

        local evalCount = 0
        local savedEvaluate = Core.Evaluate
        Core.Evaluate = function() evalCount = evalCount + 1 end

        for i = 1, 3 do
            H.fireCLEU(1000 + i, subEvent, false, "guid-enemy", "Enemy",
                       nil, nil, "guid-player", "Player", nil, nil,
                       H.ns.Spells.PYROBLAST, "Pyroblast")
            EB:Dispatch("COMBAT_LOG_EVENT_UNFILTERED")
        end

        Core.Evaluate = savedEvaluate
        H.assertNotNil(Core.state.enemies["guid-enemy"],
            subEvent .. " should create a non-arena enemy stub")
        H.assertEq(#Core._friendlyDamageTs, 3,
            subEvent .. " should count toward trained-friendly pressure")
        H.assertEq(evalCount, 1,
            subEvent .. " should trigger Evaluate once the pressure threshold is met")
    end
end)

H.it(g, "RefreshEnemiesNonArena TTL-prunes stale entries (>30s)", function()
    Core.state.enemies = {
        ["guid-stale"] = { guid = "guid-stale", name = "Old", class = "ROGUE",
                           alive = true, importantBuffs = {}, _lastSeen = 100 },
    }
    _G.UnitExists = function() return false end  -- no nameplates visible
    H._gameTime = 200  -- 100s elapsed > 30s TTL
    Core:RefreshEnemiesNonArena()
    H.assertNil(Core.state.enemies["guid-stale"], "stale entry should be pruned")
end)

H.it(g, "RefreshEnemiesNonArena TTL keeps entries within window", function()
    Core.state.enemies = {
        ["guid-fresh"] = { guid = "guid-fresh", name = "New", class = "MAGE",
                           alive = true, importantBuffs = {}, _lastSeen = 180 },
    }
    _G.UnitExists = function() return false end
    H._gameTime = 200  -- 20s elapsed < 30s TTL
    Core:RefreshEnemiesNonArena()
    H.assertNotNil(Core.state.enemies["guid-fresh"], "fresh entry must survive prune")
end)

H.it(g, "RefreshEnemiesNonArena does NOT prune arena-keyed entries", function()
    -- Defensive: arena enemies are keyed by unit ID like "arena1", not GUID.
    -- The non-arena TTL prune must skip those so RefreshArenaEnemies retains ownership.
    Core.state.enemies = {
        arena1 = { unit = "arena1", guid = "g1", alive = true, _lastSeen = 0 },
    }
    _G.UnitExists = function() return false end
    H._gameTime = 10000
    Core:RefreshEnemiesNonArena()
    H.assertNotNil(Core.state.enemies.arena1, "arena entries must not be pruned by non-arena TTL")
end)

H.it(g, "UpdateRating early-returns when pvpContext != 'arena'", function()
    -- Stub GetPersonalRatedInfo so the function COULD return a rating, but
    -- pvpContext gate should prevent the call.
    _G.GetPersonalRatedInfo = function() return 2400 end
    Core.state.bracket = 2
    Core.state.pvpContext = "bg"
    H.assertNil(Core:UpdateRating(), "non-arena context must return nil")
    Core.state.pvpContext = "arena"
    H.assertEq(Core:UpdateRating(), 2400, "arena context should pass through")
end)

-- =================================================================
-- M15 (v2.1): duel detection
-- =================================================================

H.it(g, "duel start forces pvpContext = 'world' and seeds enemy from target", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    Core.state.enemies = {}
    Core.state.pvpContext = "none"
    -- Stub target API to return a hostile player
    _G.UnitExists  = function(u) return u == "target" end
    _G.UnitIsPlayer = function(u) return u == "target" end
    _G.UnitGUID    = function(u) return u == "target" and "g-dueler" or nil end
    _G.UnitName    = function(u) return u == "target" and "Dueler" or nil end
    _G.UnitClass   = function(u) return u == "target" and "Rogue", "ROGUE" or nil, nil end
    _G.UnitHealth  = function() return 10000 end
    _G.UnitHealthMax = function() return 10000 end
    _G.UnitPower   = function() return 0 end
    _G.UnitPowerMax = function() return 0 end
    _G.UnitIsDeadOrGhost = function() return false end
    H._gameTime = 1000
    EB:Dispatch("DUEL_REQUESTED")
    H.assertEq(Core.state.pvpContext, "world")
    H.assertNotNil(Core.state.enemies["g-dueler"])
    H.assertEq(Core.state.enemies["g-dueler"].name, "Dueler")
end)

H.it(g, "duel end clears recent hostile + re-detects context", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    Core.state.pvpContext = "world"
    Core._lastWorldHostileTs = 1000
    H._gameTime = 2000
    -- Stub APIs so DetectPvPContext returns "none"
    _G.IsActiveBattlefieldArena = function() return false end
    _G.GetInstanceInfo          = function() return "Stormwind", "none" end
    _G.UnitIsPVP                = function() return false end
    EB:Dispatch("DUEL_FINISHED")
    H.assertEq(Core._lastWorldHostileTs, 0,
        "duel end should clear last hostile timestamp")
    H.assertEq(Core.state.pvpContext, "none",
        "duel end should re-detect to current context")
end)

-- =================================================================
-- v2.1.1: /acc test bg and /acc test world subcommands
-- =================================================================

H.it(g, "/acc test bg runs the BG walk-through demo", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    -- v2.4.0: per-beat notes (including the "flag" beat) only print in
    -- verbose mode now. Flip the toggle so this test's beat assertion
    -- still holds.
    _G.ArenaCoachTBCDB.frame.verbose = true
    _G.C_Timer = nil
    if not H.ns.UI.frame then H.ns.UI:CreateFrame() end
    startCapture()
    Core:RunTestMode("bg")
    stopCapture()
    local sawStart, sawFlagBeat = false, false
    for _, ln in ipairs(captured) do
        if ln:find("BG walk-through", 1, true) then sawStart = true end
        if ln:find("flag", 1, true) then sawFlagBeat = true end
    end
    H.assertTrue(sawStart, "expected BG-mode demo start banner")
    H.assertTrue(sawFlagBeat, "expected at least one beat mentioning the flag carrier")
end)

H.it(g, "/acc test world runs the world PvP walk-through demo", function()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    _G.C_Timer = nil
    if not H.ns.UI.frame then H.ns.UI:CreateFrame() end
    startCapture()
    Core:RunTestMode("world")
    stopCapture()
    local sawStart = false
    for _, ln in ipairs(captured) do
        if ln:find("world PvP walk-through", 1, true) then sawStart = true end
    end
    H.assertTrue(sawStart, "expected world-mode demo start banner")
end)

-- =================================================================
-- v2.1.2: nameplate event → re-evaluate in BG / world
-- =================================================================

H.it(g, "NAME_PLATE_UNIT_ADDED triggers Evaluate in BG context", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    Core.state.pvpContext = "bg"
    local evalCount = 0
    local saved = Core.Evaluate
    Core.Evaluate = function() evalCount = evalCount + 1 end
    EB:Dispatch("NAME_PLATE_UNIT_ADDED", "nameplate1")
    EB:Dispatch("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    Core.Evaluate = saved
    H.assertEq(evalCount, 2, "BG context should re-evaluate on add + remove")
end)

H.it(g, "NAME_PLATE events do NOT trigger Evaluate outside PvP contexts", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    Core.state.pvpContext = "none"
    local evalCount = 0
    local saved = Core.Evaluate
    Core.Evaluate = function() evalCount = evalCount + 1 end
    EB:Dispatch("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Core.Evaluate = saved
    H.assertEq(evalCount, 0, "non-PvP context should ignore nameplate events")
end)

H.it(g, "NAME_PLATE events trigger Evaluate in arena world context", function()
    rebootForEvents()
    _G.ArenaCoachTBCDB = nil; Core:InitDB()
    Core.state.pvpContext = "world"
    local evalCount = 0
    local saved = Core.Evaluate
    Core.Evaluate = function() evalCount = evalCount + 1 end
    EB:Dispatch("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Core.Evaluate = saved
    H.assertEq(evalCount, 1, "world context should re-evaluate on nameplate add")
end)
