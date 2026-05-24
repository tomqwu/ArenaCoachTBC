-- Tests/ErrorReporter_spec.lua
local H = _G.__ACC_TEST_HELPERS
H.load("ErrorReporter.lua")
local ER = H.ns.ErrorReporter

local g = H.describe("ErrorReporter")

local function reset()
    _G.ArenaCoachTBCDB = nil
    ER:Reset()
end

H.it(g, "Capture stores an entry with sanitised message", function()
    reset()
    ER:Capture("attempt to index field 'guid-arena1-XYZ' (a nil value)")
    local recent = ER:Recent()
    H.assertEq(#recent, 1)
    H.assertNotNil(recent[1].message:find("guid%-%*%*%*"), "guid not sanitised: " .. recent[1].message)
end)

H.it(g, "Sanitize strips Player-... GUIDs", function()
    H.assertNotNil(ER:Sanitize("crash in Player-12345-AABBCC"):find("Player%-%*%*%*"))
end)

H.it(g, "Sanitize strips Name-Realm tokens", function()
    local out = ER:Sanitize("error from Greenz-Frostmourne joining group")
    H.assertNotNil(out:find("%*%*%*%-%*%*%*"))
    H.assertNil(out:find("Frostmourne"))
end)

H.it(g, "Sanitize uses _knownNames registered via SetKnownNames", function()
    reset()
    ER:SetKnownNames({"Bobtheking", "Eviltrickz"})
    local out = ER:Sanitize("Bobtheking did 5000 damage to Eviltrickz")
    H.assertNil(out:find("Bobtheking"))
    H.assertNil(out:find("Eviltrickz"))
end)

H.it(g, "Capture honours the MAX_ENTRIES ring buffer", function()
    reset()
    for i = 1, 30 do ER:Capture("err " .. i) end
    H.assertEq(#ER:Recent(50), ER.MAX_ENTRIES)
    -- Oldest dropped: last entry should be "err 30"
    local recent = ER:Recent(50)
    H.assertNotNil(recent[#recent].message:find("err 30"))
end)

H.it(g, "Format returns a payload header + each entry", function()
    reset()
    ER:Capture("first error")
    ER:Capture("second error")
    local out = ER:Format(5)
    H.assertNotNil(out:find("## ArenaCoachTBC bug report"))
    H.assertNotNil(out:find("first error"))
    H.assertNotNil(out:find("second error"))
end)

H.it(g, "Format with no errors says so", function()
    reset()
    local out = ER:Format(5)
    H.assertNotNil(out:find("No captured errors"))
end)

H.it(g, "Capture with context preserves and sanitises it", function()
    reset()
    ER:Capture("boom", "spell from Player-99-DEAD")
    local recent = ER:Recent()
    H.assertNotNil(recent[1].context)
    H.assertNotNil(recent[1].context:find("Player%-%*%*%*"))
end)

H.it(g, "Capture with nil err is a no-op", function()
    reset()
    ER:Capture(nil)
    H.assertEq(#ER:Recent(), 0)
end)
