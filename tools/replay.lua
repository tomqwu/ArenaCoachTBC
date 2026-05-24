#!/usr/bin/env lua5.1
-- tools/replay.lua
--
-- Replays a recorded CLEU log against the StrategyEngine and prints each
-- post-event recommendation. Pairs with /acc record on in-game.
--
-- Usage:
--   lua5.1 tools/replay.lua <path/to/ArenaCoachTBC.lua>
--
-- The SavedVariables file is a snippet of Lua that assigns ArenaCoachTBCDB
-- as a table. We dofile() it after stubbing the globals it references, then
-- walk db.record.events through the addon's trackers and the engine.

local svPath = arg[1]
if not svPath then
    io.stderr:write("Usage: lua5.1 tools/replay.lua <ArenaCoachTBC.lua>\n")
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
print(string.format("Replaying %d events from %s", #events, svPath))

-- A bare-minimum state: one synthetic enemy per unique sourceGUID we observe.
local state = {
    enemies        = {},
    friendlies     = {},
    observations   = {},
    enemyClassList = {},
    combatPhase    = "ACTIVE",
    bracket        = 5,
}

local function ensureEnemy(guid)
    if not guid then return nil end
    if not state.enemies[guid] then
        state.enemies[guid] = {
            unit = guid, guid = guid, class = "WARRIOR",
            alive = true, healthPct = 100, hasTrinket = true,
            importantBuffs = {}, importantDebuffs = {}, observedSpells = {},
        }
    end
    return state.enemies[guid]
end

local SE = ns.StrategyEngine
local CT = ns.CooldownTracker
local DR = ns.DRTracker
local S  = ns.Spells

local printedRecs = 0
for i, ev in ipairs(events) do
    _G.GetTime = function() return ev.ts or 0 end
    CT:OnCombatLogEvent(ev.sub, ev.src, ev.dst, ev.spell)
    if S and S.CATEGORIES and S.CATEGORIES[ev.spell] then
        DR:OnCC(ev.sub, ev.dst, ev.spell, S.CATEGORIES[ev.spell], ev.ts)
    end
    ensureEnemy(ev.src)
    if ev.sub == "SPELL_CAST_SUCCESS" or ev.sub == "UNIT_DIED"
       or ev.sub == "SPELL_AURA_APPLIED" or ev.sub == "SPELL_AURA_REMOVED" then
        -- Rebuild the class list each Evaluate.
        local list = {}
        for _, e in pairs(state.enemies) do table.insert(list, e.class) end
        state.enemyClassList = list
        local rec = SE:Evaluate(state)
        if rec and (i % 25 == 0 or i == #events) then
            printedRecs = printedRecs + 1
            print(string.format("[%4d] t=%-8s mode=%s target=%s reason=%s",
                i, tostring(ev.ts), tostring(rec.mode),
                tostring(rec.primaryTargetClass), tostring(rec.reason)))
        end
    end
end

print(string.format("Done. Replayed %d events, printed %d recommendation snapshots.",
    #events, printedRecs))
