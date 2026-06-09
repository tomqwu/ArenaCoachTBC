#!/usr/bin/env lua5.1
-- tools/replay.lua
--
-- Replays a recorded CLEU log against the StrategyEngine and prints a
-- deterministic, redacted report. Pairs with /acc record on in-game.
--
-- Usage:
--   lua5.1 tools/replay.lua [--golden report.txt] [--update-golden report.txt] <path/to/ArenaCoachTBC.lua>
--
-- The SavedVariables file is a snippet of Lua that assigns ArenaCoachTBCDB
-- as a table. We dofile() it after stubbing the globals it references, then
-- walk db.record.events through the addon's trackers and the engine.

local svPath, goldenPath, updateGoldenPath
local i = 1
while i <= #arg do
    local a = arg[i]
    if a == "--golden" then
        i = i + 1; goldenPath = arg[i]
    elseif a == "--update-golden" then
        i = i + 1; updateGoldenPath = arg[i]
    elseif not svPath then
        svPath = a
    else
        io.stderr:write("Unexpected argument: " .. tostring(a) .. "\n")
        os.exit(2)
    end
    i = i + 1
end

if not svPath then
    io.stderr:write("Usage: lua5.1 tools/replay.lua [--golden report.txt] [--update-golden report.txt] <ArenaCoachTBC.lua>\n")
    os.exit(2)
end

-- Resolve the addon root relative to this script so we can load modules.
local scriptDir = debug.getinfo(1, "S").source
    :gsub("^@", ""):match("(.+)[/\\][^/\\]+$") or "."
local addonDir = scriptDir .. "/../ArenaCoachTBC"
package.path = addonDir .. "/?.lua;" .. package.path

-- Minimal WoW API stubs (just enough for the engine and trackers).
_G.GetTime    = function() return 0 end
_G.GetLocale  = function() return "enUS" end
_G.GetSpellInfo = function(id) return "Spell" .. tostring(id) end
_G.SlashCmdList = {}

-- Load addon files into a shared namespace.
local function loadAddon(file)
    local chunk = assert(loadfile(addonDir .. "/" .. file))
    return chunk("ArenaCoachTBC", _G.__ACC_NS)
end
_G.__ACC_NS = {}
loadAddon("Locales/enUS.lua")
loadAddon("Data/Spells.lua")
loadAddon("Data/Classes.lua")
loadAddon("Data/OwnComps.lua")
loadAddon("Data/Strategies.lua")
loadAddon("Data/SpellSpecHints.lua")
loadAddon("CooldownTracker.lua")
loadAddon("DRTracker.lua")
loadAddon("StrategyEngine.lua")
loadAddon("ReplayReport.lua")
loadAddon("Core.lua")
local ns = _G.__ACC_NS

-- Load the SavedVariables file. It assigns into the global table.
local svChunk, err = loadfile(svPath)
if not svChunk then io.stderr:write("Cannot load SV: " .. tostring(err) .. "\n"); os.exit(2) end
svChunk()
local db = _G.ArenaCoachTBCDB
if not (db and db.record and db.record.events) then
    io.stderr:write("SV has no record.events; nothing to replay\n"); os.exit(0)
end

local events = db.record.events
local context = db.record.context or db.record.replayContext or {}
local rows = ns.Core:ReplayRecord(events, nil, { state = context })
local report = ns.ReplayReport:Format(events, rows, { source = svPath })
io.write(report)

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

local function writeFile(path, text)
    local f = assert(io.open(path, "wb"))
    f:write(text)
    f:close()
end

if updateGoldenPath then
    writeFile(updateGoldenPath, report)
    io.stderr:write("Updated golden report: " .. updateGoldenPath .. "\n")
end

if goldenPath then
    local expected = readFile(goldenPath)
    if not expected then
        io.stderr:write("Cannot read golden report: " .. goldenPath .. "\n")
        os.exit(2)
    end
    local diffs, samples = ns.ReplayReport:DiffText(report, expected)
    if diffs > 0 then
        io.stderr:write(string.format("Golden replay drift: %d differing lines\n", diffs))
        for _, sample in ipairs(samples) do
            io.stderr:write(string.format(
                "line %d\n  expected: %s\n  actual:   %s\n",
                sample.line, sample.expected, sample.actual))
        end
        os.exit(1)
    end
    io.stderr:write("Golden replay matched: " .. goldenPath .. "\n")
end
