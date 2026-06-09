-- Tests/ReplayReport_spec.lua
local H = _G.__ACC_TEST_HELPERS

H.load("Locales/enUS.lua")
H.load("Data/Spells.lua")
H.load("Data/Classes.lua")
H.load("Data/OwnComps.lua")
H.load("Data/Strategies.lua")
H.load("Data/SpellSpecHints.lua")
H.load("CooldownTracker.lua")
H.load("DRTracker.lua")
H.load("StrategyEngine.lua")
H.load("ReplayReport.lua")
H.load("Core.lua")

local RR = H.ns.ReplayReport
local Core = H.ns.Core

local g = H.describe("ReplayReport")

local function readFile(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

H.it(g, "formats deterministic redacted rows with rejected reasons", function()
    local events = {
        {
            ts = 2.25,
            sub = "SPELL_CAST_SUCCESS",
            src = "Player-Alice-0001",
            srcName = "Alice",
            dst = "Player-Bob-0002",
            dstName = "Bob",
            spell = 123,
            name = "Test Spell",
        },
    }
    local rows = {
        {
            index = 1,
            ts = 2.25,
            mode = "KILL",
            comp = "TEST_COMP",
            primaryTarget = "Player-Bob-0002",
            primaryTargetName = "Bob",
            primaryTargetClass = "PRIEST",
            callouts = { "Z_LAST", "A_FIRST" },
            rejectedCallouts = {
                { key = "Z_REJECT", reason = "missing_z" },
                { key = "A_REJECT", reason = "missing_a" },
            },
            rejectedActions = {
                { unit = "party1", key = "ACTION_Z", reason = "missing_z" },
                { unit = "player", key = "ACTION_A", reason = "missing_a" },
            },
            playerActions = {
                { unit = "party1", actionKey = "ACTION_PARTY", targetName = "Bob" },
                { unit = "player", actionKey = "ACTION_SELF", targetName = "Bob" },
            },
            signals = {
                { kind = "strategy", id = "strategy:KILL", ownerUnit = "player", targetName = "Bob", expiresAt = 10 },
                { kind = "callout", id = "callout:A_FIRST", ownerUnit = "team", targetName = "Bob", expiresAt = 8 },
                { kind = "player_action", id = "player_action:player:ACTION_SELF", ownerUnit = "player", targetName = "Bob", expiresAt = 12 },
            },
        },
    }

    local report = RR:Format(events, rows, { source = "fixture.lua" })
    H.assertTrue(report:find("G01/P01>G02/P02", 1, true) ~= nil, report)
    H.assertTrue(report:find("player:ACTION_SELF->P02", 1, true) ~= nil, report)
    H.assertTrue(report:find("A_FIRST,Z_LAST", 1, true) ~= nil, report)
    H.assertTrue(report:find("callouts=A_REJECT:missing_a,Z_REJECT:missing_z", 1, true) ~= nil, report)
    H.assertTrue(report:find("actions=party1:ACTION_Z:missing_z,player:ACTION_A:missing_a", 1, true) ~= nil, report)
    H.assertTrue(report:find("callout:callout:A_FIRST@team->P02~8.0", 1, true) ~= nil, report)
    H.assertTrue(report:find("player_action:player_action:player:ACTION_SELF@player->P02~12.0", 1, true) ~= nil, report)
    H.assertTrue(report:find("Alice", 1, true) == nil, report)
    H.assertTrue(report:find("Player%-Alice") == nil, report)
end)

H.it(g, "DiffText reports stable samples", function()
    local diffs, samples = RR:DiffText("a\nb\n", "a\nc\n")
    H.assertEq(diffs, 1)
    H.assertEq(#samples, 1)
    H.assertEq(samples[1].line, 2)
    H.assertEq(samples[1].actual, "b")
    H.assertEq(samples[1].expected, "c")

    local clean = RR:DiffText("a\n", "a\n")
    H.assertEq(clean, 0)
end)

H.it(g, "tiny replay fixture matches committed golden report", function()
    local oldDB = _G.ArenaCoachTBCDB
    _G.ArenaCoachTBCDB = nil
    dofile(H.ADDON_DIR .. "/Tests/Fixtures/replay_tiny.lua")
    local db = _G.ArenaCoachTBCDB
    local rows = Core:ReplayRecord(db.record.events, nil, { state = db.record.context })
    local report = RR:Format(db.record.events, rows, {
        source = "ArenaCoachTBC/Tests/Fixtures/replay_tiny.lua",
    })
    local expected = readFile(H.ADDON_DIR .. "/Tests/Fixtures/replay_tiny.golden.txt")
    local diffs, samples = RR:DiffText(report, expected)
    _G.ArenaCoachTBCDB = oldDB
    H.assertEq(diffs, 0, samples[1] and (samples[1].expected .. " != " .. samples[1].actual) or "")
end)
