-- Tests/Sounds_spec.lua (M12 #77)
local H = _G.__ACC_TEST_HELPERS
H.load("Sounds.lua")

local Sounds = H.ns.Sounds
local g = H.describe("Sounds")

H.it(g, "byCallout maps at least a handful of canonical callouts", function()
    local count = 0
    for _ in pairs(Sounds.byCallout) do count = count + 1 end
    H.assertTrue(count >= 5, "expected >=5 sound mappings, got " .. count)
end)

H.it(g, "PathFor returns nil for an unknown callout", function()
    H.assertNil(Sounds:PathFor("CALL_NONEXISTENT"))
end)

H.it(g, "Play is a no-op when PlaySoundFile is absent (headless)", function()
    -- The test harness doesn't stub PlaySoundFile globally; Play should
    -- return false (no-op) without erroring.
    H.assertFalse(Sounds:Play("CALL_HOJ_KILL"))
    H.assertFalse(Sounds:Play("CALL_NONEXISTENT"))
end)

H.it(g, "Play invokes PlaySoundFile when present", function()
    local saved = _G.PlaySoundFile
    local called = false
    _G.PlaySoundFile = function(path, channel) called = true; return true end
    H.assertTrue(Sounds:Play("CALL_HOJ_KILL"))
    H.assertTrue(called)
    _G.PlaySoundFile = saved
end)
