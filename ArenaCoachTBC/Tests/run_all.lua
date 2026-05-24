-- Tests/run_all.lua - runs every spec in this directory in one Lua process
-- (so luacov captures coverage across all modules in one stats file).
--
-- Usage:
--   lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua

local function scriptDir()
    local src = (arg and arg[0]) or debug.getinfo(1, "S").source or ""
    src = src:gsub("^@", "")
    local d = src:match("(.+)[/\\][^/\\]+$")
    if not d or d == "" then d = "." end
    return d
end

local THIS_DIR  = scriptDir()
local ADDON_DIR = THIS_DIR .. "/.."

local H = dofile(THIS_DIR .. "/test_helpers.lua")
H.ADDON_DIR = ADDON_DIR
H.installStubs()
_G.__ACC_TEST_HELPERS = H
_G.__ACC_TEST_RUNNER  = true

-- Order matters: data first, then trackers, engine, ui, options, bridge, core.
local specs = {
    "Spells_spec.lua",
    "Classes_spec.lua",
    "Strategies_spec.lua",
    "OwnComps_spec.lua",
    "EventBus_spec.lua",
    "CooldownTracker_spec.lua",
    "DRTracker_spec.lua",
    "WeakAuraBridge_spec.lua",
    "Locales_spec.lua",
    "StrategyEngine_extra_spec.lua",
    "UI_spec.lua",
    "Options_spec.lua",
    "Core_spec.lua",
    "Coverage_extras_spec.lua",
}

for _, spec in ipairs(specs) do
    dofile(THIS_DIR .. "/" .. spec)
end

local ok = H.run()
os.exit(ok and 0 or 1)
