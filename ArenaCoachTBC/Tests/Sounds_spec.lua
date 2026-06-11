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

-- ============================================================
-- v2.9: observed-event cues + trimmed mode cues
-- ============================================================

H.it(g, "v2.9: byMode only chirps for KILL and DEFEND", function()
    H.assertNotNil(Sounds.byMode.KILL)
    H.assertNotNil(Sounds.byMode.DEFEND)
    H.assertNil(Sounds.byMode.SWAP, "SWAP flip must not chirp")
    H.assertNil(Sounds.byMode.OPEN, "OPEN flip must not chirp")
    H.assertNil(Sounds.byMode.RESET)
end)

H.it(g, "v2.9: byEvent maps the two observed-event cues distinctly", function()
    local trinket = Sounds.byEvent.ENEMY_TRINKET_USED
    local defensive = Sounds.byEvent.ENEMY_DEFENSIVE_USED
    H.assertNotNil(trinket)
    H.assertNotNil(defensive)
    H.assertNotEq(trinket, defensive, "the two events must sound different")
end)

H.it(g, "PlayEvent plays mapped events and no-ops on unknown keys", function()
    local saved = _G.PlaySoundFile
    local plays = 0
    _G.PlaySoundFile = function() plays = plays + 1; return true end
    H.assertTrue(Sounds:PlayEvent("ENEMY_TRINKET_USED"))
    H.assertFalse(Sounds:PlayEvent("NOT_AN_EVENT"))
    H.assertEq(plays, 1)
    _G.PlaySoundFile = saved
end)
