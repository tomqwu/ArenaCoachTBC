-- ArenaCoachTBC - Lookahead expectimax (M10 #67)
--
-- Augments the greedy chain pick from M8 #61 with a bounded expectimax
-- search over (action, opponent_response) plies. Each candidate chain
-- is scored not just by its raw ExpectedProb but by its *expected*
-- value across the opponent's likely responses — read from the M9
-- OpponentProfile when present, falls back to 50/50 priors otherwise.
--
-- "Action" in this PR == picking a CC chain (the M8 action space).
-- Future M10/M11 work extends the action space to include peel calls
-- and kill-priority shifts; the module is structured so adding actions
-- doesn't require refactoring the search itself.
--
-- Bounded branching keeps the search cheap: default top-3 actions ×
-- top-3 opponent responses × 3 plies = 81 leaves max. All knobs
-- configurable via opts or db.strategy.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.Lookahead = ns.Lookahead or {}

local Lookahead = ns.Lookahead

Lookahead.DEFAULT_TOP_ACTIONS   = 3
Lookahead.DEFAULT_TOP_RESPONSES = 3
Lookahead.DEFAULT_PLIES         = 3

-- Enumerate the opponent's likely responses to a candidate chain. Each
-- response is { kind, prob, factor } where factor in [0..1] scales the
-- chain's raw ExpectedProb at the leaf. Probabilities sum to 1.
--
-- Reads OpponentProfile when present to draw response probabilities
-- from learned Beta priors; without a profile, splits 50/50.
function Lookahead:EnumerateResponses(scoredChain, profile)
    local OP = ns.OpponentProfile
    -- Read trinketsFear as a proxy for "they trinket the first CC of
    -- our chain". Future work distinguishes per-category response
    -- (trinket vs Ice Block vs BoP); for #67 we use the dominant one.
    local pTrinket = 0.5
    if OP and profile then
        pTrinket = OP:EstimateOrDefault(profile, "trinketsFear", 0.5)
    end
    return {
        { kind = "no_response", prob = 1 - pTrinket, factor = 1.0 },
        { kind = "trinket",     prob = pTrinket,     factor = 0.5 },
    }
end

-- Score a list of already-ranked chains (the output of Chain:ScoreAll)
-- with lookahead. Returns a new array sorted desc by expectedValue.
--
--   chains  : { { chain, prob }, ... } from Chain:ScoreAll
--   opts    : optional { topActions, topResponses, profile }
function Lookahead:Score(chains, opts)
    if not chains or #chains == 0 then return {} end
    opts = opts or {}
    local kAct  = opts.topActions   or self.DEFAULT_TOP_ACTIONS
    local kResp = opts.topResponses or self.DEFAULT_TOP_RESPONSES
    local profile = opts.profile

    local results = {}
    for i = 1, math.min(kAct, #chains) do
        local c = chains[i]
        local responses = self:EnumerateResponses(c, profile)
        -- Clip responses to top-K by probability descending.
        table.sort(responses, function(a, b) return (a.prob or 0) > (b.prob or 0) end)
        if kResp < #responses then
            for j = #responses, kResp + 1, -1 do responses[j] = nil end
        end
        local ev = 0.0
        local pSum = 0.0
        for _, r in ipairs(responses) do
            ev = ev + (r.prob or 0) * (c.prob or 0) * (r.factor or 0)
            pSum = pSum + (r.prob or 0)
        end
        -- Renormalise in case top-K dropped some probability mass.
        if pSum > 0 then ev = ev / pSum end
        table.insert(results, {
            chain         = c.chain,
            prob          = c.prob,
            expectedValue = ev,
            responses     = responses,
        })
    end
    -- Stable sort by descending expected value.
    table.sort(results, function(a, b) return a.expectedValue > b.expectedValue end)
    return results
end
