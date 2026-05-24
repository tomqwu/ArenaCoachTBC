#!/usr/bin/env lua5.1
-- tools/check_locales.lua
--
-- Fast standalone parity check: every key in enUS must exist in every other
-- locale file under ArenaCoachTBC/Locales/. Exits non-zero with a precise
-- listing of missing keys per locale so a CI failure reads like:
--
--   zhCN missing 2 key(s):
--     - HELP_TRACE
--     - SIMULATE_STOPPED
--
-- The full test suite also enforces parity, but a dedicated CI step surfaces
-- locale problems before the slower Lua test run even starts.

local function basename(p) return p:match("([^/\\]+)%.lua$") end

local function loadLocale(path)
    local ns = {}
    local chunk = assert(loadfile(path))
    chunk("ArenaCoachTBC", ns)
    -- The locale files set ns.locales[<code>] = { ... }; pull that out.
    local code = basename(path)
    if not (ns.locales and ns.locales[code]) then
        error("locale file " .. path .. " does not populate ns.locales." .. code)
    end
    return code, ns.locales[code]
end

local function listLocaleFiles()
    -- Resolve LOCALES_DIR from this script's path so the tool works from any CWD.
    local scriptDir = debug.getinfo(1, "S").source
        :gsub("^@", ""):match("(.+)[/\\][^/\\]+$") or "."
    local dir = scriptDir .. "/../ArenaCoachTBC/Locales"
    local handle = assert(io.popen('ls -1 "' .. dir .. '"/*.lua 2>/dev/null'))
    local files = {}
    for line in handle:lines() do table.insert(files, line) end
    handle:close()
    table.sort(files)
    return files
end

local files = listLocaleFiles()
assert(#files > 0, "no locale files found")

local refCode, refTbl = "enUS", nil
local locales = {}
for _, p in ipairs(files) do
    local code, tbl = loadLocale(p)
    locales[code] = tbl
    if code == "enUS" then refTbl = tbl end
end

if not refTbl then
    io.stderr:write("enUS reference locale missing\n"); os.exit(2)
end

local refKeyCount = 0
for _ in pairs(refTbl) do refKeyCount = refKeyCount + 1 end
print(string.format("Reference locale enUS has %d keys", refKeyCount))

local fail = false
for code, tbl in pairs(locales) do
    if code ~= refCode then
        local missing = {}
        for k in pairs(refTbl) do
            if tbl[k] == nil then table.insert(missing, k) end
        end
        if #missing > 0 then
            table.sort(missing)
            io.stderr:write(string.format(
                "%s missing %d key(s):\n", code, #missing))
            for _, k in ipairs(missing) do io.stderr:write("  - " .. k .. "\n") end
            fail = true
        else
            print(string.format("%s OK (%d keys)", code,
                (function() local n = 0; for _ in pairs(tbl) do n = n + 1 end; return n end)()))
        end
    end
end

os.exit(fail and 1 or 0)
