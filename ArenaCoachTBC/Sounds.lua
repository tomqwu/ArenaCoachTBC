-- ArenaCoachTBC - Voice callout dispatch (M12 #77, audio fix v2.1.6)
--
-- v2.1.6: pre-v2.1.6 this module referenced Sound/Voice/*.ogg paths that
-- were never bundled in the addon zip, so every PlaySoundFile call
-- silently failed and "audio callouts" did not actually exist. Replaced
-- the .ogg paths with numeric PlaySound IDs (SoundKit IDs) that ship
-- with the WoW Classic client itself, so cues fire reliably on every
-- system without an extra asset download.
--
-- Headless-safe: when PlaySound is not available (tests, lua harness),
-- Play is a no-op.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.Sounds = ns.Sounds or {}

local Sounds = ns.Sounds

-- Stable per-callout sound IDs. Values are TBC Classic SoundKit IDs
-- (numeric) passed to PlaySound; these ship with WoW itself and never
-- 404. Sources (Wowhead Classic SoundKit DB):
--   8959  RaidWarning chime  — sharp alert tone
--   8454  PvPThroughQueue    — short ding
--   8458  RaidBossEmoteWarn  — louder alert
--   12867 PvPVictory         — celebratory chord
--   1517  IG_QUEST_LIST_OPEN — short pop
--   3093  IG_QUEST_LIST_CLOSE
Sounds.byCallout = {
    CALL_HOJ_KILL              = 8959,   -- Hammer-of-Justice landed → push damage
    CALL_TREMOR_FEAR           = 8454,   -- Tremor cleansing fear → safe to commit
    CALL_TREMOR_DOWN           = 8458,   -- Shaman needs to refresh Tremor under fear threat
    CALL_PURGE                 = 8454,
    CALL_BURST_BLOCK_INCOMING  = 8458,   -- Hold burst — enemy defensive in
    CALL_FAKE_KICK_2           = 1517,
    CALL_SAVE_TREMOR_HOJ       = 8458,
    BURST_NOW                  = 12867,  -- Loud go-cue when burst gate opens
}

-- Mode-transition cues (v2.1.6). Played by UI:Apply when the recommended
-- mode flips. Separate from callout cues above so users can have one set
-- on and the other off later.
-- v2.9: trimmed from 4 modes to the 2 that carry real urgency — every
-- mode flip chirping made the cues meaningless (4 near-identical dings
-- per fight teaches the ear to ignore all of them). KILL = "go",
-- DEFEND = "survive". SWAP/OPEN/RESET are visible on the HUD without
-- audio.
Sounds.byMode = {
    KILL   = 8959,
    DEFEND = 8458,
}

-- Observed-event cues (v2.9). These fire on *enemy actions seen in the
-- combat log*, not on our advice — the GladiatorlosSA insight: "enemy
-- trinket used" is worth more than any recommendation because it is a
-- fact the player would otherwise have to catch in the combat-log
-- scroll. Distinct sounds per event class.
Sounds.byEvent = {
    ENEMY_TRINKET_USED   = 12867,  -- loud chord: their CC-break is gone for 2m
    ENEMY_DEFENSIVE_USED = 8454,   -- short ding: Ice Block / bubble / CloS just burned
}

function Sounds:PathFor(callout)
    return self.byCallout[callout]
end

local function play(id)
    if not id then return false end
    if type(PlaySound) == "function" then
        local ok = pcall(PlaySound, id, "Master")
        return ok
    end
    -- Older clients may have PlaySoundFile but not PlaySound; rare in TBC.
    if type(PlaySoundFile) == "function" then
        local ok = pcall(PlaySoundFile, tostring(id), "Master")
        return ok
    end
    return false
end

function Sounds:Play(callout)
    return play(self.byCallout[callout])
end

function Sounds:PlayMode(mode)
    return play(self.byMode[mode])
end

function Sounds:PlayEvent(eventKey)
    return play(self.byEvent[eventKey])
end
