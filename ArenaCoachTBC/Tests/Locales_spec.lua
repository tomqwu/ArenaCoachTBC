-- Tests/Locales_spec.lua
local H = _G.__ACC_TEST_HELPERS
H.load("Locales/enUS.lua")
H.load("Locales/zhCN.lua")

local g = H.describe("Locales")

H.it(g, "enUS contains required keys", function()
    local en = H.ns.locales.enUS
    H.assertNotNil(en)
    for _, k in ipairs({"OPEN","KILL","SWAP","DEFEND","RESET",
                        "HELP_HEADER","HELP_TOGGLE","HELP_LOCK",
                        "REASON_DEFAULT","UI_TITLE","DEBUG_PREFIX",
                        "PRIO_LOW","PRIO_HIGH","PRIO_URGENT","PRIO_MEDIUM",
                        "TEST_HEADER"}) do
        H.assertNotNil(en[k], "enUS missing " .. k)
    end
end)

H.it(g, "zhCN contains the same key set as enUS", function()
    local en = H.ns.locales.enUS
    local zh = H.ns.locales.zhCN
    H.assertNotNil(zh)
    for k, _ in pairs(en) do
        H.assertNotNil(zh[k], "zhCN missing " .. k)
    end
end)

H.it(g, "all CALL_* keys present in both locales", function()
    local en = H.ns.locales.enUS
    local zh = H.ns.locales.zhCN
    for k, _ in pairs(en) do
        if k:find("^CALL_") then
            H.assertNotNil(zh[k], "zhCN missing " .. k)
        end
    end
end)
