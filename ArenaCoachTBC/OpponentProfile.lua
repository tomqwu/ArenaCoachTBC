-- ArenaCoachTBC - OpponentProfile (M9 #63, the keystone)
--
-- Per-opponent-team behavioural profile keyed by team signature. Records
-- binary tendencies (do they trinket Fear? do they Ice Block at <30%?
-- do they kick the first heal? do they sap the priest?) as Beta(α, β)
-- priors. The Bayesian update is transparent: a successful observation
-- bumps α, a non-observation bumps β. Mean of Beta(α, β) is α / (α + β).
--
-- The signature is `<sorted_classes>#<djb2_hash_of_sorted_names>`. The
-- raw names are NEVER persisted — only the hash. This is by design:
-- per the v2 operating principle "learn locally, not globally", profiles
-- are user-local and contain no personally-identifying data. Two teams
-- with the same sorted classes get different signatures because their
-- name hashes differ; two encounters with the same team merge into the
-- same profile because the signatures match.
--
-- This module is *pure*: it reads/writes a passed-in `db` table (the
-- caller threads the SavedVariables in). It never touches a WoW API
-- directly. Headless tests drive it with a synthetic db.
--
-- Event sourcing (which CLEU events update which tendency) lands in
-- M10/M11. #63 is the type, the API, and the persistence shape only.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.OpponentProfile = ns.OpponentProfile or {}

local OP = ns.OpponentProfile

-- Canonical tendency list. Each tendency stores a Beta(α, β) pair,
-- both defaulting to 1 (uniform prior — no opinion until observed).
OP.TENDENCIES = {
    "trinketsFear",      -- when feared, do they pop trinket?
    "iceBlockBelow30",   -- mage: do they Ice Block at HP <30%?
    "kicksFirstHeal",    -- do they kick the first big heal cast?
    "sapsPriest",        -- when sapping, do they pick the priest?
}

-- djb2 hash, used to anonymise names so the SavedVariables key cannot
-- reveal who you played against. Not cryptographically secure — just
-- one-way enough to keep names out of the persistent store.
local function djb2(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + s:byte(i)) % 2147483647
    end
    return h
end

-- Compute the signature for a given enemies map / array. Returns a
-- deterministic string like "MAGE_PRIEST_ROGUE#1834729871". Enemies
-- without a class are ignored. Dead enemies still count.
function OP:Signature(enemies)
    if not enemies then return nil end
    local classes, names = {}, {}
    for _, e in pairs(enemies) do
        if e.class then
            table.insert(classes, e.class)
            table.insert(names, e.name or "")
        end
    end
    if #classes == 0 then return nil end
    table.sort(classes)
    table.sort(names)
    return table.concat(classes, "_") .. "#" .. tostring(djb2(table.concat(names, "|")))
end

-- Build a fresh profile with all tendencies at Beta(1, 1) (uniform).
local function newProfile()
    local p = { tendencies = {} }
    for _, t in ipairs(OP.TENDENCIES) do
        p.tendencies[t] = { alpha = 1, beta = 1, observations = 0 }
    end
    return p
end

-- Get the profile for a signature. Creates and persists a fresh one if
-- this is the first time we've seen this team. `db` is the SavedVariables
-- root (db.profiles is the profile store). Returns the profile table by
-- reference — mutations write through.
function OP:Get(signature, db)
    if not signature or not db then return nil end
    db.profiles = db.profiles or {}
    local p = db.profiles[signature]
    if not p then
        p = newProfile()
        db.profiles[signature] = p
    else
        -- Backfill any new tendencies added since the profile was first
        -- written (forward-compat for adding TENDENCIES entries between
        -- versions). Never overwrites existing data.
        p.tendencies = p.tendencies or {}
        for _, t in ipairs(OP.TENDENCIES) do
            if not p.tendencies[t] then
                p.tendencies[t] = { alpha = 1, beta = 1, observations = 0 }
            end
        end
    end
    return p
end

-- Update the profile for `signature` with an observed event. Event:
--   { tendency = "trinketsFear", observed = true|false }
-- Bumps alpha when observed=true (they did the thing), beta when
-- observed=false (they didn't). observations counter rises both ways.
-- Returns the updated tendency record, or nil on bad input.
function OP:Update(signature, event, db)
    if not signature or not event or not event.tendency or not db then return nil end
    local p = self:Get(signature, db)
    if not p then return nil end
    local rec = p.tendencies[event.tendency]
    if not rec then return nil end  -- unknown tendency key
    if event.observed == true then
        rec.alpha = rec.alpha + 1
    elseif event.observed == false then
        rec.beta = rec.beta + 1
    else
        return nil  -- event.observed must be boolean
    end
    rec.observations = (rec.observations or 0) + 1
    return rec
end

-- Forget a profile entirely. Used by /acc reset or a privacy command.
function OP:Forget(signature, db)
    if not signature or not db or not db.profiles then return end
    db.profiles[signature] = nil
end

-- Posterior mean of the Beta(α, β) prior for a given tendency:
--   α / (α + β). Defaults to 0.5 when the record is missing (uniform).
function OP:Mean(profile, tendency)
    if not profile or not profile.tendencies then return 0.5 end
    local rec = profile.tendencies[tendency]
    if not rec then return 0.5 end
    local denom = (rec.alpha or 1) + (rec.beta or 1)
    if denom == 0 then return 0.5 end
    return (rec.alpha or 1) / denom
end

-- Sample count for a tendency (how many observations contributed).
-- 0 means "no opinion yet" — callers should still fall back to comp
-- defaults at this point. The roadmap calls out ~20 observations as
-- the threshold where the profile becomes opinionated.
function OP:SampleCount(profile, tendency)
    if not profile or not profile.tendencies then return 0 end
    local rec = profile.tendencies[tendency]
    return (rec and rec.observations) or 0
end

-- ============================================================
-- M9 #64: Bayesian update variants + Estimate with CI + fallback
-- ============================================================

-- Threshold below which the profile is considered "not opinionated
-- enough" — Estimate fallback callers use the comp default until we
-- see at least this many observations. Roadmap target is ~20 for
-- "opinionated"; 5 is the gate where we stop emitting "I don't know"
-- and start trusting the prior with the sample we have.
OP.MIN_SAMPLES_FOR_OPINION = 5

-- Direct profile-level update. Equivalent to OP:Update with the
-- signature already resolved, used by code paths that already hold
-- a profile reference (e.g. inside a tight Evaluate loop where we
-- don't want to re-hash the signature).
function OP:UpdateBinary(profile, key, observed)
    if not profile or not profile.tendencies then return nil end
    local rec = profile.tendencies[key]
    if not rec then return nil end
    if observed == true then
        rec.alpha = (rec.alpha or 1) + 1
    elseif observed == false then
        rec.beta = (rec.beta or 1) + 1
    else
        return nil
    end
    rec.observations = (rec.observations or 0) + 1
    return rec
end

-- Approximate 95% CI on a Beta(α, β) distribution. We use a normal
-- approximation: mean ± 1.96 * sqrt(variance), clamped to [0, 1].
-- For α + β small, this is a rough overestimate of the true CI, but
-- it's deterministic, cheap, and good enough to drive callout
-- gating. (Anyone consuming the CI should also consult `n` and
-- treat n < 5 as "no signal yet".)
local function betaCI(alpha, beta)
    local n = alpha + beta
    if n <= 0 then return 0.5, 0.0, 1.0 end
    local mean = alpha / n
    -- Beta variance: α*β / ((α+β)^2 * (α+β+1))
    local variance = (alpha * beta) / (n * n * (n + 1))
    local sd = math.sqrt(variance)
    local half = 1.96 * sd
    local low  = math.max(0.0, mean - half)
    local high = math.min(1.0, mean + half)
    return mean, low, high
end

-- Returns { mean, low, high, n } for a tendency. n is the observation
-- count, NOT α+β (the prior bias counts separately). When the
-- tendency has not been observed, mean is 0.5 and CI is [0, 1].
function OP:Estimate(profile, key)
    if not profile or not profile.tendencies then
        return { mean = 0.5, low = 0.0, high = 1.0, n = 0 }
    end
    local rec = profile.tendencies[key]
    if not rec then
        return { mean = 0.5, low = 0.0, high = 1.0, n = 0 }
    end
    local mean, low, high = betaCI(rec.alpha or 1, rec.beta or 1)
    return { mean = mean, low = low, high = high, n = rec.observations or 0 }
end

-- Returns the comp default when the sample is too small (n <
-- MIN_SAMPLES_FOR_OPINION), else the posterior mean. Drives the
-- "fall back to comp default" gate from #65.
function OP:EstimateOrDefault(profile, key, compDefault)
    local est = self:Estimate(profile, key)
    if est.n < self.MIN_SAMPLES_FOR_OPINION then return compDefault end
    return est.mean
end
