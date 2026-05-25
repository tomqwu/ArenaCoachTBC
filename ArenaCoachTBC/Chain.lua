-- ArenaCoachTBC - CC chain primitive (M8 #59)
--
-- A Chain is an ordered list of CC links, each describing a single
-- CC application:
--   { spellID = 408, target = guid, category = "STUN", by = caster_guid,
--     castTimeS = 0.0 }
--
-- - target / category : looked up against DRTracker for DR multiplier.
-- - by / spellID      : looked up against CooldownTracker for readiness.
-- - castTimeS         : optional projected cast time for the link. The
--                       caller uses it to compute the chain's overall
--                       duration; Chain.Validate only uses it implicitly
--                       through the within-chain DR accumulation order.
--
-- Validate(chain, state) returns (ok, reason). When ok is false, reason
-- is one of "DR_immune", "cd_pending", or "empty".
--
-- ExpectedProb(chain, state) returns the product of DR multipliers across
-- all links, taking into account DR applied by earlier links *in this
-- chain*. CDs not ready force the chain's expected probability to 0.0.
--
-- This module is pure: it never calls a WoW API directly. It only reads
-- DRTracker and CooldownTracker (themselves observation-only). Headless
-- tests drive it with a hand-rolled state.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.Chain = ns.Chain or {}

local Chain = ns.Chain

-- Build a chain from a list of link tables. Returns a chain table with
-- a single `links` field. The returned table is shallow-shared with the
-- input list (do not mutate after passing in).
function Chain:Build(links)
    return { links = links or {} }
end

-- Within-chain DR accumulation: walk the links in order, tracking how
-- many times each (target, category) pair has been hit so far in *this*
-- chain. A link's effective multiplier is min(observed_multiplier,
-- within_chain_multiplier).
local function withinChainMultiplier(count)
    if     count == 0 then return 1.0
    elseif count == 1 then return 0.5
    elseif count == 2 then return 0.25
    else return 0.0 end
end

-- Returns (ok, reason). ok=true means every link is currently expected
-- to land (DR multiplier > 0) and every caster has its CD available.
function Chain:Validate(chain, state)
    if not chain or not chain.links or #chain.links == 0 then
        return false, "empty"
    end

    local DR = ns.DRTracker
    local CT = ns.CooldownTracker
    local hits = {}  -- (target .. "|" .. category) -> count consumed in chain

    for _, link in ipairs(chain.links) do
        local key = (link.target or "") .. "|" .. (link.category or "")
        local observed = (DR and DR.NextMultiplier and link.target and link.category)
            and DR:NextMultiplier(link.target, link.category) or 1.0
        local within = withinChainMultiplier(hits[key] or 0)
        local eff = math.min(observed or 1.0, within)
        if eff <= 0 then
            return false, "DR_immune"
        end
        if link.spellID and link.by and CT and CT.IsReady then
            if not CT:IsReady(link.by, link.spellID) then
                return false, "cd_pending"
            end
        end
        hits[key] = (hits[key] or 0) + 1
    end

    return true
end

-- Score a list of already-instantiated chains and return a new array
-- sorted descending by ExpectedProb. Chains that return 0.0 are kept
-- so callers can see "everything is impossible right now" instead of
-- an empty list. opts.topK (default math.huge) clips the output to
-- the top K — useful for #61's bounded branching gate.
function Chain:ScoreAll(chains, opts)
    if not chains then return {} end
    local topK = (opts and opts.topK) or math.huge
    local scored = {}
    for _, c in ipairs(chains) do
        table.insert(scored, { chain = c, prob = self:ExpectedProb(c) })
    end
    -- Stable sort by descending prob: bubble down equal-prob ties to
    -- preserve catalog declaration order (matters so the engine's
    -- pick is reproducible across evaluations).
    table.sort(scored, function(a, b) return a.prob > b.prob end)
    if topK < #scored then
        for i = #scored, topK + 1, -1 do scored[i] = nil end
    end
    return scored
end

-- Returns a float in [0..1]: the product of effective DR multipliers
-- across all links. 0.0 if any link's CD is not ready or any DR is
-- already immune (consistent with Validate's rejection conditions).
function Chain:ExpectedProb(chain, state)
    if not chain or not chain.links or #chain.links == 0 then return 0.0 end

    local DR = ns.DRTracker
    local CT = ns.CooldownTracker
    local hits = {}
    local p = 1.0

    for _, link in ipairs(chain.links) do
        local key = (link.target or "") .. "|" .. (link.category or "")
        local observed = (DR and DR.NextMultiplier and link.target and link.category)
            and DR:NextMultiplier(link.target, link.category) or 1.0
        local within = withinChainMultiplier(hits[key] or 0)
        local eff = math.min(observed or 1.0, within)
        if eff <= 0 then return 0.0 end
        if link.spellID and link.by and CT and CT.IsReady then
            if not CT:IsReady(link.by, link.spellID) then
                return 0.0
            end
        end
        p = p * eff
        hits[key] = (hits[key] or 0) + 1
    end

    return p
end
