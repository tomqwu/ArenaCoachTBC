-- ArenaCoachTBC - Pattern recognition (M10 #69)
--
-- Named recurring kill setups, matched by sequence-of-cast detection
-- against the live CLEU stream. Each pattern is an ordered list of
-- spell matchers with per-step time windows; when all steps match
-- (each step's cast lands within `withinSeconds` of the previous),
-- the engine emits CALL_PATTERN_<id> as a forward-looking callout.
--
-- Five built-in patterns seeded for v2.0. Adding new ones is data-only:
-- append to ns.Patterns.defs and the engine + locale machinery picks
-- them up.
--
-- The module is pure: it owns its own per-spell-id index, gets fed
-- via Patterns:Observe(spellID, ts) from Core's CLEU dispatch, and
-- exposes Patterns:GetMatches(threshold) for consumers. The match
-- state has a TTL so old half-matches don't linger across rounds.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.Patterns = ns.Patterns or {}

local P = ns.Patterns
local S = ns.Spells

P.DEFAULT_MATCH_THRESHOLD = 0.7
P.STATE_TTL_SECONDS       = 12.0  -- forget a half-match after this long

-- A pattern definition: ordered list of steps. Each step matches a
-- specific spellID (extendable to category matchers later) and must
-- occur within `withinSeconds` of the previous step.
P.defs = {
    {
        id        = "RMP_CHEAP_BLIND",
        labelKey  = "CALL_PATTERN_RMP_CHEAP_BLIND",
        steps     = {
            { spellID = S and S.KIDNEY_SHOT, withinSeconds = math.huge },
            { spellID = S and S.BLIND,       withinSeconds = 6.0       },
        },
    },
    {
        id        = "SHATTER_NOVA_SHEEP",
        labelKey  = "CALL_PATTERN_SHATTER_NOVA_SHEEP",
        steps     = {
            { spellID = S and S.FROST_NOVA, withinSeconds = math.huge },
            { spellID = S and S.POLYMORPH,  withinSeconds = 3.0       },
        },
    },
    {
        id        = "FEAR_INTO_POLY",
        labelKey  = "CALL_PATTERN_FEAR_INTO_POLY",
        steps     = {
            { spellID = S and S.HOWL_OF_TERROR, withinSeconds = math.huge },
            { spellID = S and S.POLYMORPH,      withinSeconds = 4.0       },
        },
    },
    {
        id        = "HUNTER_TRAP_SCATTER",
        labelKey  = "CALL_PATTERN_HUNTER_TRAP_SCATTER",
        steps     = {
            { spellID = S and S.FREEZING_TRAP, withinSeconds = math.huge },
            { spellID = S and S.SCATTER_SHOT,  withinSeconds = 4.0       },
        },
    },
    {
        id        = "HOJ_INTO_INTERCEPT",
        labelKey  = "CALL_PATTERN_HOJ_INTO_INTERCEPT",
        steps     = {
            { spellID = S and S.HAMMER_OF_JUSTICE, withinSeconds = math.huge },
            { spellID = S and S.INTERCEPT,         withinSeconds = 3.0       },
        },
    },
}

-- Per-pattern progress state: { stepIdx (last matched), lastTs }.
P._progress = {}

local function now()
    if type(GetTime) == "function" then return GetTime() end
    return os.time()
end

-- Observe a single cast event. Call from Core's CLEU dispatch on
-- SPELL_CAST_SUCCESS / SPELL_AURA_APPLIED.
function P:Observe(spellID, ts)
    if not spellID then return end
    ts = ts or now()
    for _, def in ipairs(self.defs) do
        if def.steps then
            local prog = self._progress[def.id] or { stepIdx = 0, lastTs = 0 }
            -- Expire stale half-matches before evaluating the next step.
            if (ts - prog.lastTs) > self.STATE_TTL_SECONDS then
                prog.stepIdx = 0
            end
            local nextStep = def.steps[prog.stepIdx + 1]
            if nextStep and spellID == nextStep.spellID then
                if prog.stepIdx == 0 or (ts - prog.lastTs) <= (nextStep.withinSeconds or math.huge) then
                    prog.stepIdx = prog.stepIdx + 1
                    prog.lastTs  = ts
                end
            end
            self._progress[def.id] = prog
        end
    end
end

-- Match probability for a pattern: completed-steps / total-steps.
-- A fully-matched pattern returns 1.0.
function P:Probability(patternID)
    local prog = self._progress[patternID]
    if not prog then return 0.0 end
    for _, def in ipairs(self.defs) do
        if def.id == patternID then
            local total = #def.steps
            if total == 0 then return 0.0 end
            return prog.stepIdx / total
        end
    end
    return 0.0
end

-- Returns array of { id, labelKey, prob } for patterns whose
-- probability meets the threshold (default DEFAULT_MATCH_THRESHOLD).
function P:GetMatches(threshold)
    threshold = threshold or self.DEFAULT_MATCH_THRESHOLD
    local out = {}
    for _, def in ipairs(self.defs) do
        local prob = self:Probability(def.id)
        if prob >= threshold then
            table.insert(out, { id = def.id, labelKey = def.labelKey, prob = prob })
        end
    end
    return out
end

-- Reset all pattern progress (called on /reload, /acc reset, or new
-- arena pop).
function P:Clear()
    self._progress = {}
end
