-- ArenaCoachTBC - Cooldown tracker
-- Records observed spell casts from the combat log and answers queries like
-- "is enemy X's Ice Block ready?". This is intentionally conservative -- when
-- a cooldown is uncertain we report nil and let the strategy engine decide
-- whether to treat that as "ready" or "unknown".
--
-- We never use the player's own cooldown API for enemies (that's not possible
-- across faction); everything comes from combat log SPELL_CAST_SUCCESS or
-- SPELL_AURA_APPLIED.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.CooldownTracker = ns.CooldownTracker or {}

local CT = ns.CooldownTracker
CT._cooldowns = {}   -- guid -> { spellID -> { used = ts, ready = ts+dur, dur = duration } }

-- Default cooldown durations (seconds) for enemy spells in TBC 2.4.3
-- These can be adjusted per build. When in doubt, prefer "longer" so we don't
-- assume an enemy CD is ready when it isn't.
CT.defaults = {
    -- Mage
    [27619] = 300, -- Ice Block (5m, glyph reduced post-TBC; conservative here)
    [12472] = 480, -- Cold Snap (8m)
    [27090] = 30,  -- Counterspell (24s baseline; 30s for safety)
    -- Rogue
    [31224] = 120, -- Cloak of Shadows (1.5m; spec'd lower)
    [26669] = 270, -- Evasion (4.5m; reduced w/ talents)
    [26889] = 180, -- Vanish (talent-reduced; 3m baseline)
    [2094]  = 180, -- Blind (3m base; talents 2m)
    -- Warlock
    [27223] = 120, -- Death Coil (2m)
    [18708] = 900, -- Fel Domination (15m)
    [24259] = 24,  -- Spell Lock (felhunter)
    -- Paladin (enemy)
    [642]   = 300, -- Divine Shield (5m glyphless)
    [10278] = 300, -- Blessing of Protection
    [1044]  = 25,  -- Blessing of Freedom
    [10308] = 60,  -- Hammer of Justice (60s baseline; 40s spec'd)
    -- Druid (enemy)
    [17116] = 180, -- Nature's Swiftness
    [29166] = 360, -- Innervate (6m)
    [33786] = 0,   -- Cyclone has no fixed CD, but DR applies; tracked separately
    [22812] = 60,  -- Barkskin
    -- Priest (enemy)
    [33206] = 120, -- Pain Suppression
    [10890] = 27,  -- Psychic Scream (27s)
    -- Hunter
    [27068] = 120, -- Wyvern Sting
    [19503] = 30,  -- Scatter Shot
    [14310] = 30,  -- Freezing Trap
    [19263] = 300, -- Deterrence (5m)
    [23989] = 300, -- Readiness
    -- Universal PvP trinket effect
    [42292] = 120, -- PvP medallion
}

local function now()
    if type(GetTime) == "function" then return GetTime() end
    return os.time()
end

function CT:_record(guid, spellID, duration, ts)
    if not guid or not spellID then return end
    duration = duration or self.defaults[spellID]
    ts = ts or now()
    self._cooldowns[guid] = self._cooldowns[guid] or {}
    self._cooldowns[guid][spellID] = {
        used  = ts,
        ready = duration and (ts + duration) or nil,
        dur   = duration,
    }
end

function CT:MarkUsed(guid, spellID, timestamp)
    self:_record(guid, spellID, nil, timestamp)
end

function CT:GetRemaining(guid, spellID)
    local g = self._cooldowns[guid]; if not g then return nil end
    local rec = g[spellID]; if not rec then return nil end
    if not rec.ready then return nil end
    local remaining = rec.ready - now()
    if remaining <= 0 then return 0 end
    return remaining
end

function CT:IsReady(guid, spellID)
    local rem = self:GetRemaining(guid, spellID)
    -- nil means "we've never observed it used" -> treat as ready
    if rem == nil then return true end
    return rem <= 0
end

-- Get all observed cooldowns for a unit
function CT:ForUnit(guid)
    return self._cooldowns[guid] or {}
end

function CT:Forget(guid)
    self._cooldowns[guid] = nil
end

function CT:Clear()
    self._cooldowns = {}
end

-- Wire combat log -> cooldown updates
-- subEvent: SPELL_CAST_SUCCESS, SPELL_AURA_APPLIED, etc.
function CT:OnCombatLogEvent(subEvent, sourceGUID, destGUID, spellID, ...)
    if not subEvent or not spellID then return end
    if subEvent == "SPELL_CAST_SUCCESS" then
        if self.defaults[spellID] then
            self:_record(sourceGUID, spellID)
        end
    elseif subEvent == "SPELL_AURA_APPLIED" then
        -- PvP trinket use shows up as an aura applied to self
        if spellID == 42292 then
            self:_record(destGUID, 42292)
        end
        -- Ice Block / Divine Shield are casts but also auras - record from aura too
        if spellID == 27619 or spellID == 642 or spellID == 10278 then
            self:_record(destGUID, spellID)
        end
    end
end
