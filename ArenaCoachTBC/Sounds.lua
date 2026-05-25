-- ArenaCoachTBC - Voice callout dispatch (M12 #77)
--
-- Maps callout keys to PlaySoundFile paths and dispatches a one-shot
-- audio cue per callout transition. Headless-safe: when PlaySoundFile
-- is not available (tests, classic client without the API), Play is a
-- no-op. Sound assets ship as placeholder paths — the actual audio
-- files are an artist deliverable that lands with v2.0 alongside the
-- visual polish in this PR.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.Sounds = ns.Sounds or {}

local Sounds = ns.Sounds

-- Stable per-callout sound IDs. The values are PlaySoundFile-compatible
-- paths; the artist drop populates files at these paths in the addon
-- distribution zip. Headless tests just exercise the dispatch.
Sounds.byCallout = {
    CALL_HOJ_KILL              = "Sound/Voice/HoJKill.ogg",
    CALL_TREMOR_FEAR           = "Sound/Voice/TremorFear.ogg",
    CALL_PURGE                 = "Sound/Voice/Purge.ogg",
    CALL_BURST_BLOCK_INCOMING  = "Sound/Voice/HoldBurst.ogg",
    CALL_FAKE_KICK_2           = "Sound/Voice/FakeKick2.ogg",
    CALL_SAVE_TREMOR_HOJ       = "Sound/Voice/SaveTremor.ogg",
    BURST_NOW                  = "Sound/Voice/BurstNow.ogg",
}

function Sounds:PathFor(callout)
    return self.byCallout[callout]
end

function Sounds:Play(callout)
    local path = self:PathFor(callout)
    if not path then return false end
    if type(PlaySoundFile) == "function" then
        local ok = pcall(PlaySoundFile, path, "Master")
        return ok
    end
    return false
end
