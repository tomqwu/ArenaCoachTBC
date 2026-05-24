-- Tests/Options_spec.lua
local H = _G.__ACC_TEST_HELPERS
H.load("Locales/enUS.lua")
H.load("Options.lua")

local OPT = H.ns.Options
local g = H.describe("Options")

_G.ArenaCoachTBCDB = {
    enabled = true, locked = false,
    alerts = { sound = true, raidWarning = false, partyChat = false },
    strategy = {}, debug = false,
    frame = { point = "CENTER", x = 0, y = 0, scale = 1 },
}

H.it(g, "BuildPanel returns a panel", function()
    local p = OPT:BuildPanel()
    H.assertNotNil(p)
    H.assertEq(p.name, "ArenaCoachTBC")
end)

H.it(g, "Panel OnShow refresh runs without error", function()
    local p = OPT:BuildPanel()
    local fn = p._scripts.OnShow
    H.assertNotNil(fn)
    fn(p)
end)

H.it(g, "Apply with db is a no-op shape", function()
    OPT:Apply(_G.ArenaCoachTBCDB)
end)

H.it(g, "Settings.RegisterCanvasLayoutCategory fallback path", function()
    -- Wipe the OPT cached panel so a second BuildPanel rebuilds and exercises
    -- the alternate registration path.
    local savedAdd = _G.InterfaceOptions_AddCategory
    _G.InterfaceOptions_AddCategory = nil
    _G.Settings = {
        RegisterCanvasLayoutCategory = function(panel, name)
            return { id = "ACC", name = name, panel = panel }
        end,
        RegisterAddOnCategory = function(cat) end,
    }
    local p = OPT:BuildPanel()
    H.assertNotNil(p)
    _G.InterfaceOptions_AddCategory = savedAdd
    _G.Settings = nil
end)

H.it(g, "Checkbox onclick handlers persist to DB", function()
    local p = OPT:BuildPanel()
    -- Find the enabled checkbox by global name (set by CreateFrame stub)
    local cb = _G.ACCEnabledCheck
    H.assertNotNil(cb)
    cb._checked = false
    cb._scripts.OnClick(cb)
    H.assertFalse(_G.ArenaCoachTBCDB.enabled)
    cb._checked = true
    cb._scripts.OnClick(cb)
    H.assertTrue(_G.ArenaCoachTBCDB.enabled)
end)

H.it(g, "All checkbox OnClicks fire without error", function()
    OPT:BuildPanel()
    for _, name in ipairs({"ACCEnabledCheck","ACCLockCheck","ACCSoundCheck","ACCDebugCheck","ACCPartyChatCheck"}) do
        local cb = _G[name]
        if cb and cb._scripts.OnClick then
            cb._checked = true
            cb._scripts.OnClick(cb)
            cb._checked = false
            cb._scripts.OnClick(cb)
        end
    end
end)
