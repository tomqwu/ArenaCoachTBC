-- ArenaCoachTBC - Diminishing returns tracker
-- TBC has 6 DR categories; we follow the standard arena convention:
--   1st: full duration, 2nd: half, 3rd: quarter, 4th: immune
-- Reset time after the *last* CC ends defaults to 15-18 seconds. Made
-- configurable because behaviour and emulation specifics vary.
--
-- This is an *observation* tracker: we listen to SPELL_AURA_APPLIED with
-- known CC spells and bump that target's DR for the category. We do NOT
-- distinguish PvE-trinket immunity from DR-immunity; consumers should use
-- this as advisory ("don't expect another fear to land") not absolute truth.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.DRTracker = ns.DRTracker or {}

local DR = ns.DRTracker
DR._state = {}            -- guid -> { category -> { count, lastAppliedAt, lastDuration } }
DR.resetWindow = 17.0     -- seconds after last application; configurable
DR.categories = { "STUN", "FEAR", "DISORIENT", "INCAPACITATE", "ROOT", "CYCLONE" }

local function now()
    if type(GetTime) == "function" then return GetTime() end
    return os.time()
end

-- Convenience: returns DR multiplier for the *next* application
-- 1.0 = full, 0.5 = half, 0.25 = quarter, 0.0 = immune
function DR:NextMultiplier(guid, category)
    local g = self._state[guid]; if not g then return 1.0 end
    local rec = g[category]; if not rec then return 1.0 end
    if (now() - rec.lastAppliedAt) > self.resetWindow then
        rec.count = 0
        return 1.0
    end
    local c = rec.count or 0
    if     c == 0 then return 1.0
    elseif c == 1 then return 0.5
    elseif c == 2 then return 0.25
    else return 0.0 end
end

function DR:IsImmune(guid, category)
    return self:NextMultiplier(guid, category) == 0.0
end

function DR:Apply(guid, category, ts)
    if not guid or not category then return end
    ts = ts or now()
    self._state[guid] = self._state[guid] or {}
    local rec = self._state[guid][category] or { count = 0 }
    if (ts - (rec.lastAppliedAt or 0)) > self.resetWindow then
        rec.count = 0
    end
    rec.count = (rec.count or 0) + 1
    rec.lastAppliedAt = ts
    self._state[guid][category] = rec
end

-- Hook: called from CLEU with already-resolved category
function DR:OnCC(subEvent, destGUID, spellID, category, ts)
    if subEvent ~= "SPELL_AURA_APPLIED" then return end
    if not category then return end
    self:Apply(destGUID, category, ts)
end

function DR:Clear()
    self._state = {}
end

function DR:Forget(guid)
    self._state[guid] = nil
end
