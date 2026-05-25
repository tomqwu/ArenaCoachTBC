-- ArenaCoachTBC - Strategy engine
-- This file is the brain of the addon. It is intentionally framework-free so
-- it can be unit-tested outside WoW with stubs (see Tests/StrategyEngine_spec.lua).
--
-- Public surface:
--   StrategyEngine:Evaluate(state) -> Recommendation
--
-- The scoring algorithm is a transparent weighted sum:
--   target.score = roleWeight + vulnerability + teamSynergy - dangerPenalty
-- Highest scoring living enemy becomes recommendation.primaryTarget. The
-- second-highest is offered as recommendation.secondaryTarget (swap).
--
-- Mode selection:
--   - DEFEND   : friendly healer critically low / multiple bursts / no kill
--   - OPEN     : combat not yet engaged and we have a clean opener
--   - SWAP     : top score belongs to a different target than our last call
--   - KILL     : steady pressure on top scorer
--   - RESET    : neither side has a kill window; LoS / mana drink
--
-- All callouts are returned as locale *keys*; UI/text layer is responsible
-- for resolving them so we can render different languages without changing
-- the engine.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.StrategyEngine = ns.StrategyEngine or {}

local SE = ns.StrategyEngine

-- ============================================================
-- Scoring weights (kept here as named constants to make tuning trivial)
-- Per-bracket overrides live in SE.bracketWeights; SE:GetWeights(bracket)
-- merges default + overrides. Engine call sites use this everywhere
-- instead of reading SE.weights directly so future bracket-tuning lands
-- without touching call sites.
-- ============================================================
SE.weights = {
    role_healer          =  25,
    role_cloth_dps       =  15,
    role_melee_overext   =  10,
    health_below_50      =  30,
    low_mana_healer      =  20,
    trinket_down         =  20,
    major_defensive_down =  15,
    no_immunity          =  10,
    purgeable_defensive  =  10,
    kill_defensive_soon  = -10,  -- penalty when target's major defensive comes off CD within ~15s
    ms_active            =  25,
    our_hoj_ready        =  15,
    our_bloodlust        =  15,
    windfury_active      =  10,
    priest_can_dispel    =  10,
    off_healer_cc        =  15,
    comp_open_target     =  20,
    comp_swap_target     =  10,
    -- penalties
    target_immune        = -100,
    target_unreachable   =  -30,
    target_los_blocked   =  -20,
    melee_locked_down    =  -20,
    our_healer_cc        =  -25,
    our_team_low_hp      =  -30,
}

-- Per-bracket weight overrides. Only list keys that DIFFER from default.
-- 2v2: healer kill is the entire game plan -> overweight role_healer.
-- 3v3: swap targets matter; healer slightly less unique.
-- 5v5: defaults are tuned for 5v5 cleave; no overrides needed.
SE.bracketWeights = {
    [2] = { role_healer = 40, role_cloth_dps = 18 },
    [3] = { role_healer = 30 },
    [5] = {},
}

local function copyTable(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

function SE:GetWeights(bracket)
    local merged = copyTable(self.weights)
    if bracket and self.bracketWeights[bracket] then
        for k, v in pairs(self.bracketWeights[bracket]) do merged[k] = v end
    end
    return merged
end

-- ============================================================
-- Helpers
-- ============================================================
local function isAlive(e) return e and e.alive ~= false and (e.healthPct or 100) > 0 end

local function roleOf(enemy)
    if enemy.roleGuess then return enemy.roleGuess end
    local Classes = ns.Classes
    if not Classes then return "MELEE" end
    return Classes:DefaultRole(enemy.class)
end

local function isHealer(enemy)
    return roleOf(enemy) == "HEALER"
end

local function isCloth(enemy)
    local Classes = ns.Classes
    if not Classes then return false end
    return Classes:IsCloth(enemy.class)
end

-- Returns the active immunity name on `enemy` (e.g. "Ice Block") or nil.
local function activeImmunity(enemy)
    if not enemy.importantBuffs then return nil end
    local Spells = ns.Spells
    if not Spells then return nil end
    for spellID, _ in pairs(enemy.importantBuffs) do
        if Spells.IMMUNITY_BUFFS and Spells.IMMUNITY_BUFFS[spellID] then
            return Spells.IMMUNITY_BUFFS[spellID]
        end
    end
    return nil
end

-- Returns the seconds remaining until this enemy's soonest major defensive
-- comes off cooldown, based on observed casts. nil means "no defensive has
-- ever been observed used" - treat as already-available (no penalty).
local function nextMajorDefensiveCD(enemy)
    if not enemy or not enemy.guid then return nil end
    local CT = ns.CooldownTracker
    local S  = ns.Spells
    if not CT or not S or not S.IMMUNITY_BUFFS then return nil end
    local soonest = nil
    for spellID, _ in pairs(S.IMMUNITY_BUFFS) do
        local rem = CT:GetRemaining(enemy.guid, spellID)
        if rem and rem > 0 and (not soonest or rem < soonest) then
            soonest = rem
        end
    end
    return soonest
end

local function hasPurgeableBuff(enemy)
    if not enemy.importantBuffs then return false end
    local Spells = ns.Spells
    if not Spells or not Spells.PURGEABLE then return false end
    for spellID, _ in pairs(enemy.importantBuffs) do
        if Spells.PURGEABLE[spellID] then return true end
    end
    return false
end

-- Lowest HP healer in our group, or nil
local function lowestHealer(friendlies)
    if not friendlies then return nil end
    local lowest, lowHP = nil, 101
    for _, f in pairs(friendlies) do
        if f.alive ~= false and (f.class == "PRIEST" or f.class == "DRUID")
           and (f.healthPct or 100) < lowHP then
            lowest = f; lowHP = f.healthPct or 100
        end
    end
    return lowest
end

-- Roughly: any friendly DPS rooted/snared without freedom/cleanse coverage?
local function meleeLockedDown(state)
    local friendlies = state.friendlies or {}
    for _, f in pairs(friendlies) do
        if f.alive ~= false and (f.class == "WARRIOR" or f.class == "SHAMAN" or f.class == "PALADIN") then
            if f.debuffs and (f.debuffs.rooted or f.debuffs.snared) and not (f.buffs and f.buffs.freedom) then
                return true
            end
        end
    end
    return false
end

local function ourHealerCCd(state)
    local friendlies = state.friendlies or {}
    for _, f in pairs(friendlies) do
        if (f.class == "PRIEST" or f.class == "DRUID") and f.debuffs
           and (f.debuffs.stunned or f.debuffs.feared or f.debuffs.sheeped or f.debuffs.silenced) then
            return true
        end
    end
    return false
end

local function teamAvgHP(state)
    local total, n = 0, 0
    for _, f in pairs(state.friendlies or {}) do
        if f.alive ~= false then
            total = total + (f.healthPct or 100); n = n + 1
        end
    end
    if n == 0 then return 100 end
    return total / n
end

-- ============================================================
-- Scoring
-- ============================================================
local function scoreEnemy(enemy, state, comp)
    local w = SE:GetWeights(state and state.bracket)
    local score = 0
    local contrib = {}  -- ordered list of {reasonKey, points}
    local function add(pts, key)
        if pts and pts ~= 0 then
            score = score + pts
            table.insert(contrib, { key = key, pts = pts })
        end
    end

    -- ----- role
    if isHealer(enemy) then
        add(w.role_healer, "role_healer")
    elseif isCloth(enemy) then
        add(w.role_cloth_dps, "role_cloth_dps")
    elseif enemy.overextended then
        add(w.role_melee_overext, "role_melee_overext")
    end

    -- ----- vulnerability
    if (enemy.healthPct or 100) < 50 then
        add(w.health_below_50, "health_below_50")
    end
    if isHealer(enemy) and enemy.manaPct and enemy.manaPct < 25 then
        add(w.low_mana_healer, "low_mana_healer")
    end
    if enemy.hasTrinket == false then
        add(w.trinket_down, "trinket_down")
    end
    if enemy.majorDefensiveDown then
        add(w.major_defensive_down, "major_defensive_down")
    end
    -- Penalty when their major defensive (Ice Block / Divine Shield / BoP)
    -- is about to come off CD - committing burst into a soon-immune target
    -- is wasted effort.
    local nextDef = nextMajorDefensiveCD(enemy)
    if nextDef and nextDef < 15 then
        add(w.kill_defensive_soon, "kill_defensive_soon")
    end
    if not activeImmunity(enemy) then
        add(w.no_immunity, "no_immunity")
    end
    if hasPurgeableBuff(enemy) then
        add(w.purgeable_defensive, "purgeable_defensive")
    end

    local phase = state.combatPhase or "PRE"
    local cfg = (state.config and state.config.strategy) or {}
    if comp and comp.openTarget and phase == "PRE" and enemy.class == comp.openTarget then
        add(w.comp_open_target, "comp_open_target")
    end
    if comp and comp.swapTarget and phase ~= "PRE" and cfg.allowDpsSwap ~= false
       and enemy.class == comp.swapTarget then
        add(w.comp_swap_target, "comp_swap_target")
    end

    -- ----- team synergy
    local obs = state.observations or {}
    if obs.msActiveOn and obs.msActiveOn == enemy.guid then
        add(w.ms_active, "ms_active")
    end
    if obs.hojReady then
        add(w.our_hoj_ready, "our_hoj_ready")
    end
    if obs.bloodlustReady or obs.bloodlustActive then
        add(w.our_bloodlust, "our_bloodlust")
    end
    if obs.windfuryActive then
        add(w.windfury_active, "windfury_active")
    end
    if obs.priestCanDispel then
        add(w.priest_can_dispel, "priest_can_dispel")
    end
    if obs.offHealerCC then
        add(w.off_healer_cc, "off_healer_cc")
    end

    -- ----- danger / penalties
    local immunityName = activeImmunity(enemy)
    if immunityName then
        add(w.target_immune, "target_immune")
    end
    if enemy.unreachable then add(w.target_unreachable, "target_unreachable") end
    if enemy.losBlocked   then add(w.target_los_blocked, "target_los_blocked") end
    if meleeLockedDown(state) then add(w.melee_locked_down, "melee_locked_down") end
    if ourHealerCCd(state)   then add(w.our_healer_cc, "our_healer_cc") end
    if teamAvgHP(state) < 45 then add(w.our_team_low_hp, "our_team_low_hp") end

    -- sort contributors by absolute magnitude so reasons are most-impactful first
    table.sort(contrib, function(a, b)
        return math.abs(a.pts) > math.abs(b.pts)
    end)

    return score, contrib, immunityName
end

-- ============================================================
-- M11 #72: Kill-probability model with auditable breakdown
-- ============================================================
-- Each component contributes additively in [0..1], summed and clamped.
-- The breakdown is surfaced so /acc trace + WeakAuras can show the
-- engine's "why we think we can kill" reasoning to the player.
SE.KILL_PROB_WEIGHTS = {
    hpDelta            = 1.0,   -- 1 - hp/100, weighted directly
    defensiveDown      = 0.10,  -- target has used trinket
    immunityAbsent     = 0.10,  -- target has no active Ice Block / DS / BoP
    burstReady         = 0.05,  -- our HoJ/burst ready
    healerLowMana      = 0.10,  -- their healer below mana threshold
    drClean            = 0.05,  -- target's STUN DR is at 1.0
}

function SE:KillProb(target, state)
    if not target then return { prob = 0, components = {} } end
    local W = self.KILL_PROB_WEIGHTS
    local hp = 1 - ((target.healthPct or 100) / 100)
    local comps = { hp = hp * W.hpDelta }
    if target.hasTrinket == false then comps.defensiveDown = W.defensiveDown
    else comps.defensiveDown = 0 end
    local activeImm = false
    if target.importantBuffs and ns.Spells and ns.Spells.IMMUNITY_BUFFS then
        for id, _ in pairs(target.importantBuffs) do
            if ns.Spells.IMMUNITY_BUFFS[id] then activeImm = true; break end
        end
    end
    comps.immunityAbsent = (not activeImm) and W.immunityAbsent or 0
    comps.burstReady = (state and state.observations and state.observations.hojReady)
        and W.burstReady or 0
    comps.healerLowMana = 0
    if state and state.enemies then
        for _, e in pairs(state.enemies) do
            local role = e.roleGuess
            if role == "HEALER" and e.manaPct and e.manaPct < 30 then
                comps.healerLowMana = W.healerLowMana
                break
            end
        end
    end
    comps.drClean = 0
    if ns.DRTracker and ns.DRTracker.NextMultiplier and target.guid then
        if ns.DRTracker:NextMultiplier(target.guid, "STUN") == 1.0 then
            comps.drClean = W.drClean
        end
    end
    local total = 0
    for _, v in pairs(comps) do total = total + v end
    return {
        prob       = math.max(0, math.min(1.0, total)),
        components = comps,
    }
end

-- ============================================================
-- M11 #73: Multi-reason burst gate
-- ============================================================
-- Each gate is independently auditable: { allowed, value, threshold,
-- reason }. blockedBy is the first failing gate; allowed is false if
-- any gate fails. The kill_prob threshold scales with aggression
-- (rating-derived via M11 #71).
SE.BURST_KILL_PROB_THRESHOLD = {
    greedy   = 0.35,
    balanced = 0.45,
    safe     = 0.55,
}

function SE:BurstDecision(state, target, chain)
    state = state or {}
    local gates = {}
    local agg = state.aggression
        or (state.config and state.config.strategy and state.config.strategy.aggression)
        or "balanced"

    -- 1. kill_prob gate
    local killProb = target and self:KillProb(target, state).prob or 0
    local killThreshold = self.BURST_KILL_PROB_THRESHOLD[agg]
        or self.BURST_KILL_PROB_THRESHOLD.balanced
    gates.kill_prob = {
        allowed   = killProb >= killThreshold,
        value     = killProb,
        threshold = killThreshold,
    }

    -- 2. chain_ready gate
    local chainEP = chain and (chain.expectedProb or 0) or 0
    gates.chain_ready = {
        allowed = chain ~= nil and chainEP > 0,
        value   = chainEP,
    }

    -- 3. incoming_pressure gate
    local obs = state.observations or {}
    local underPressure = obs.healerUnderPressure or obs.enemyBloodlustActive
        or obs.multipleBurstsDetected
    gates.incoming_pressure = {
        allowed = not underPressure,
        reason  = underPressure and "healer trained / enemy lust" or nil,
    }

    -- 4. rating_aware: an audit trail of the aggression label that
    -- influenced the thresholds above. Always allowed; surfaces context.
    gates.rating_aware = {
        allowed    = true,
        aggression = agg,
        rating     = state.rating,
    }

    local order = { "kill_prob", "chain_ready", "incoming_pressure", "rating_aware" }
    local allowed, blockedBy = true, nil
    for _, key in ipairs(order) do
        if gates[key].allowed == false then
            allowed = false
            if not blockedBy then blockedBy = key end
        end
    end
    return { allowed = allowed, blockedBy = blockedBy, gates = gates }
end

-- ============================================================
-- Defense / phase heuristics
-- ============================================================
local function shouldDefend(state)
    local lowest = lowestHealer(state.friendlies)
    -- M11 #71: defensive HP threshold shifts with aggression.
    -- Greedy: 30 (only defend on real emergencies). Safe: 50 (defend earlier).
    local hpThreshold = 40
    local agg = state.aggression or (state.config and state.config.strategy and state.config.strategy.aggression)
    if agg == "greedy" then hpThreshold = 30
    elseif agg == "safe" then hpThreshold = 50 end
    if lowest and (lowest.healthPct or 100) < hpThreshold then return true, "low_healer" end
    if ourHealerCCd(state) then return true, "healer_cc" end

    local obs = state.observations or {}
    if obs.enemyBloodlustActive then return true, "enemy_lust" end
    if obs.multipleBurstsDetected then return true, "multi_burst" end
    if obs.healerUnderPressure then return true, "trained" end

    -- enemy comp = triple DPS, no clean opener
    local Strategies = ns.Strategies
    local comp = Strategies and (Strategies:Identify(state.enemyClassList or {}, state.enemies, state.bracket))
    if comp and comp.defaultMode == "DEFEND" then
        if (state.combatPhase or "PRE") == "PRE" then
            return true, "triple_dps_pre"
        end
    end
    return false
end

-- ============================================================
-- Burst gating per spec rules:
--   - MS must be active on the kill target (when configured)
--   - Windfury must be active when configured
--   - No melee locked down without freedom
--   - Target must not be immune
-- ============================================================
local function burstAllowed(state, target)
    local cfg = (state.config and state.config.strategy) or {}
    local obs = state.observations or {}

    if target then
        if activeImmunity(target) then return false, "target_immune" end
    end

    if cfg.callBurstOnlyWhenMSActive then
        if not obs.msActiveOn or (target and obs.msActiveOn ~= target.guid) then
            return false, "no_ms"
        end
    end
    if cfg.requireWindfuryNearby and not obs.windfuryActive then
        return false, "no_windfury"
    end
    if meleeLockedDown(state) then
        return false, "melee_root"
    end
    return true
end

-- ============================================================
-- Build callouts (locale keys) from comp + current state
-- ============================================================
-- CC-callout -> DR category. Used to suppress CC suggestions when the
-- relevant DR is already in immune territory.
local CC_CALLOUT_CATEGORY = {
    CALL_HOJ_KILL    = "STUN",
    CALL_CYCLONE_OFF = "CYCLONE",
}

-- For a CC callout, return the enemy whose DR we should check. nil means
-- "no specific target" (callout always allowed).
local function ccTargetFor(key, primaryTarget, state)
    if key == "CALL_HOJ_KILL" then return primaryTarget end
    if key == "CALL_CYCLONE_OFF" then
        -- Off-healer: any healer enemy that isn't the primary kill target.
        for _, e in pairs(state.enemies or {}) do
            if isHealer(e) and isAlive(e)
               and (not primaryTarget or e.guid ~= primaryTarget.guid) then
                return e
            end
        end
    end
    return nil
end

-- Returns true if a CC callout is still worth firing. nil/no-data = allow.
-- DR mult of 0 = immune; we suppress.
local function drAllowsCallout(key, primaryTarget, state)
    local cat = CC_CALLOUT_CATEGORY[key]
    if not cat then return true end
    local target = ccTargetFor(key, primaryTarget, state)
    if not target or not target.guid then return true end
    local DR = ns.DRTracker
    if not DR or not DR.NextMultiplier then return true end
    local mult = DR:NextMultiplier(target.guid, cat)
    if mult == nil then return true end  -- no observed DR yet
    return mult > 0
end

local function buildCallouts(state, comp, primaryTarget, mode)
    local out = {}
    local seen = {}
    local function push(key)
        if key and not seen[key] and drAllowsCallout(key, primaryTarget, state) then
            table.insert(out, key); seen[key] = true
        end
    end

    if comp and comp.callouts then
        for _, k in ipairs(comp.callouts) do push(k) end
    end

    local obs = state.observations or {}
    local cfg = (state.config and state.config.strategy) or {}

    if mode == "DEFEND" then
        push("CALL_PAIN_SUP_READY")
        push("CALL_BOP_READY")
    elseif mode == "KILL" then
        if obs.hojReady then push("CALL_HOJ_KILL") end
        if primaryTarget and hasPurgeableBuff(primaryTarget) then push("CALL_PURGE") end
        if primaryTarget and primaryTarget.class == "PRIEST" then
            push("CALL_EARTHSHOCK_HEAL")
        end
        if primaryTarget and isHealer(primaryTarget)
           and primaryTarget.manaPct then
            -- M11 #71: low-mana push threshold shifts with aggression.
            -- Greedy pushes at higher mana (we'll burst earlier); safe
            -- waits longer.
            local manaT = 25
            local agg = state.aggression or cfg.aggression
            if agg == "greedy" then manaT = 30
            elseif agg == "safe" then manaT = 20 end
            if primaryTarget.manaPct < manaT then push("CALL_LOW_MANA_PUSH") end
        end
    elseif mode == "OPEN" then
        if cfg.preferHealerOpen then push("CALL_HOJ_KILL") end
        push("CALL_TREMOR_FEAR")
    end

    -- M9 #65: profile-driven callouts. When state.opponentProfile is
    -- present and a tendency's posterior mean is high enough (with
    -- enough samples — EstimateOrDefault handles the threshold), emit
    -- the matching "this team does X, plan around it" callout. The
    -- per-decision contribution is also recorded as a comma-joined
    -- string for trace logging.
    local OP = ns.OpponentProfile
    local profile = state.opponentProfile
    if OP and profile then
        local contrib = {}
        local function checkTendency(key, threshold, callKey)
            local v = OP:EstimateOrDefault(profile, key, 0.5)
            if v >= threshold then
                push(callKey)
                table.insert(contrib, string.format("%s=%.2f", key, v))
            end
        end
        checkTendency("kicksFirstHeal",  0.7, "CALL_FAKE_KICK_2")
        checkTendency("trinketsFear",    0.7, "CALL_SAVE_TREMOR_HOJ")
        checkTendency("iceBlockBelow30", 0.7, "CALL_BURST_BLOCK_INCOMING")
        if #contrib > 0 then
            state._profileContrib = table.concat(contrib, ",")
        end
    end

    -- M10 #69: pattern-driven callouts. Patterns observe the live
    -- CLEU stream via Core; here we just consume the matches.
    if ns.Patterns and ns.Patterns.GetMatches then
        local matches = ns.Patterns:GetMatches()
        for _, m in ipairs(matches) do
            push(m.labelKey)
        end
    end

    return out
end

-- ============================================================
-- Pick mode based on phase, comp, and target situation
-- ============================================================
local function decideMode(state, topTarget, secondTarget, comp)
    local defend, _ = shouldDefend(state)
    if defend then return "DEFEND" end

    local phase = state.combatPhase or "PRE"
    if phase == "PRE" then
        if topTarget then return "OPEN" end
        return "RESET"
    end

    -- no living enemies with positive score -> reset
    if not topTarget then return "RESET" end

    -- last call differs from this one -> swap
    if state.lastPrimaryGUID and topTarget.guid and state.lastPrimaryGUID ~= topTarget.guid then
        local cfg = (state.config and state.config.strategy) or {}
        if cfg.allowDpsSwap == false and not isHealer(topTarget) then
            return "KILL"
        end
        local threshold = 10
        -- M11 #71: state.aggression (resolved by Core, possibly from
        -- rating) wins over the static config.aggression.
        local agg = state.aggression or cfg.aggression
        if agg == "safe" then threshold = 20
        elseif agg == "greedy" then threshold = 0 end
        -- only call SWAP if the swap target is significantly more attractive
        if not secondTarget or (topTarget._score - secondTarget._score) > threshold then
            return "SWAP"
        end
    end

    return "KILL"
end

-- ============================================================
-- Public entrypoint
-- ============================================================
function SE:Evaluate(state)
    state = state or {}
    state.enemies = state.enemies or {}
    state.friendlies = state.friendlies or {}
    state.observations = state.observations or {}
    state.config = state.config or {}

    -- Derive enemy class list for comp identification
    local classes = state.enemyClassList
    if not classes then
        classes = {}
        for _, e in pairs(state.enemies) do
            if e.class then table.insert(classes, e.class) end
        end
        state.enemyClassList = classes
    end

    -- Detect our own team capabilities + archetype so we can give
    -- comp-aware advice instead of hardcoding "warrior provides MS".
    local OwnComps = ns.OwnComps
    local ownCaps, ownArchetype
    if OwnComps then
        ownCaps      = OwnComps:Infer(state.friendlies)
        ownArchetype = OwnComps:Identify(state.friendlies, ownCaps)
    end
    state._ownCaps      = ownCaps
    state._ownArchetype = ownArchetype

    local Strategies = ns.Strategies
    local comp, compConfidence = nil, 0.0
    if Strategies then
        comp, compConfidence = Strategies:Identify(classes, state.enemies, state.bracket)
    end
    if Strategies and Strategies.ApplyOwnVariant and ownArchetype then
        comp = Strategies:ApplyOwnVariant(comp, ownArchetype.id)
    end

    -- Score every alive enemy
    local scored = {}
    local fullReason = {}
    for _, e in pairs(state.enemies) do
        if isAlive(e) then
            local s, contrib, immunity = scoreEnemy(e, state, comp)
            e._score = s
            e._contrib = contrib
            e._immunity = immunity
            table.insert(scored, e)
        end
    end

    table.sort(scored, function(a, b) return (a._score or 0) > (b._score or 0) end)

    local topTarget = scored[1]
    local secondTarget = scored[2]

    -- Determine mode
    local mode = decideMode(state, topTarget, secondTarget, comp)

    -- Build callouts
    local callouts = buildCallouts(state, comp, topTarget, mode)

    -- Build human-readable reason from top contributing factors
    local reasonParts = {}
    if topTarget and topTarget._contrib then
        for i = 1, math.min(3, #topTarget._contrib) do
            local c = topTarget._contrib[i]
            table.insert(reasonParts, c.key .. "(" .. tostring(c.pts) .. ")")
        end
    end
    local reason
    if mode == "DEFEND" then
        reason = "defensive: " .. (select(2, shouldDefend(state)) or "unknown")
    elseif mode == "RESET" then
        reason = "reset / no clear target"
    else
        -- KILL / SWAP / OPEN always have a topTarget (decideMode invariant)
        reason = string.format("%s [%s]", topTarget.class or "?", table.concat(reasonParts, ", "))
    end
    -- Append comp-match confidence so /acc trace + the bug report can show it.
    if comp and comp.id then
        local tag = (comp.specs ~= nil) and "spec-confirmed" or "class-guessed"
        reason = reason .. string.format(" | %s %s (%.2f)", comp.id, tag, compConfidence or 0.0)
    end

    -- Burst guidance
    local burstOK, burstWhy = burstAllowed(state, topTarget)
    if mode == "KILL" and burstOK then
        table.insert(callouts, "BURST_NOW")
    end

    local confidence
    if not topTarget then
        confidence = 0.0
    else
        local diff = (topTarget._score or 0) - ((secondTarget and secondTarget._score) or 0)
        -- normalize: 0-50 spread -> 0.5-1.0
        confidence = math.max(0.0, math.min(1.0, 0.5 + diff / 100))
    end

    local priority = "MEDIUM"
    if mode == "DEFEND" then priority = "URGENT"
    elseif mode == "SWAP" then priority = "HIGH"
    elseif mode == "OPEN" then priority = "MEDIUM"
    elseif mode == "RESET" then priority = "LOW"
    else priority = "HIGH" end

    -- M8 #61: chain scoring. Pick the top-scoring chain for this comp
    -- against the current state. nil if the comp has no chains, no
    -- chain has at least one castable link, or the top chain's
    -- expected probability is 0.
    local pickedChain = nil
    if comp and comp.chains and Strategies and Strategies.InstantiateChains and ns.Chain then
        local topG = topTarget and topTarget.guid or nil
        local secondG = secondTarget and secondTarget.guid or nil
        local concrete = Strategies:InstantiateChains(comp, topG, secondG, state.enemies)
        if #concrete > 0 then
            local cfg = (state.config and state.config.strategy) or {}
            local topK = cfg.chainK or 3
            local scored = ns.Chain:ScoreAll(concrete, { topK = topK })
            if scored[1] and scored[1].prob > 0 then
                -- M10 #67: lookahead. Pass through Lookahead:Score to
                -- re-rank by expected value (chain prob × opponent
                -- response weights from the profile). Falls back to
                -- the greedy chain pick when Lookahead is absent or
                -- disabled.
                local pickedScored = scored[1]
                local pickedExpected = nil
                local LA = ns.Lookahead
                if LA and (cfg.lookaheadEnabled ~= false) then
                    local laOut = LA:Score(scored, {
                        topActions   = cfg.lookaheadTopActions   or LA.DEFAULT_TOP_ACTIONS,
                        topResponses = cfg.lookaheadTopResponses or LA.DEFAULT_TOP_RESPONSES,
                        profile      = state.opponentProfile,
                    })
                    if laOut[1] then
                        -- Map back from lookahead result to the
                        -- matching scored entry so we keep prob too.
                        for _, s in ipairs(scored) do
                            if s.chain == laOut[1].chain then pickedScored = s; break end
                        end
                        pickedExpected = laOut[1].expectedValue
                    end
                end
                local picked = pickedScored.chain
                pickedChain = {
                    id            = picked.id,
                    label         = picked.label,
                    labelKey      = picked.labelKey,
                    steps         = #picked.links,
                    links         = picked.links,
                    expectedProb  = pickedScored.prob,
                    expectedValue = pickedExpected,  -- nil when LA disabled / absent
                }
            end
        end
    end

    return {
        mode            = mode,
        primaryTarget   = topTarget and topTarget.guid or nil,
        primaryTargetName = topTarget and topTarget.name or nil,
        primaryTargetClass= topTarget and topTarget.class or nil,
        secondaryTarget = secondTarget and secondTarget.guid or nil,
        secondaryTargetName = secondTarget and secondTarget.name or nil,
        secondaryTargetClass = secondTarget and secondTarget.class or nil,
        confidence      = confidence,
        reason          = reason,
        callouts        = callouts,
        priority        = priority,
        comp            = comp and comp.id or nil,
        compLabel       = comp and comp.label or nil,
        compConfidence  = compConfidence,
        compSpecConfirmed = (comp ~= nil) and (comp.specs ~= nil) or false,
        chain           = pickedChain,
        profileContrib  = state._profileContrib,
        opponentSignature = state.opponentSignature,
        aggression      = state.aggression,
        rating          = state.rating,
        burstDecision   = (mode == "KILL") and self:BurstDecision(state, topTarget, pickedChain) or nil,
        ownArchetype    = ownArchetype and ownArchetype.id or nil,
        ownArchetypeLabel = ownArchetype and ownArchetype.label or nil,
        ownCapabilities = ownCaps,
        burstAllowed    = burstOK,
        burstBlockedBy  = (not burstOK) and burstWhy or nil,
        _topScore       = topTarget and topTarget._score or 0,
        _secondScore    = secondTarget and secondTarget._score or 0,
    }
end

-- Convenience: turn the spec's English ownComp string into a friendly group
-- model. Used by /acc test and by the bootstrap before real units arrive.
function SE:DefaultFriendlies()
    return {
        player = { unit = "player", class = "WARRIOR", spec = "ARMS",       alive = true, healthPct = 100 },
        party1 = { unit = "party1", class = "SHAMAN",  spec = "ENHANCEMENT", alive = true, healthPct = 100 },
        party2 = { unit = "party2", class = "PALADIN", spec = "RETRIBUTION", alive = true, healthPct = 100 },
        party3 = { unit = "party3", class = "DRUID",   spec = "RESTORATION", alive = true, healthPct = 100 },
        party4 = { unit = "party4", class = "PRIEST",  spec = "DISCIPLINE",  alive = true, healthPct = 100 },
    }
end

-- Build a synthetic state from a class list (for /acc test or /acc enemy)
function SE:BuildTestState(classList, opts)
    opts = opts or {}
    local enemies = {}
    for i, cls in ipairs(classList) do
        local unit = "arena" .. i
        enemies[unit] = {
            unit = unit,
            guid = "guid-" .. unit,
            name = cls:lower():gsub("^%l", string.upper),
            class = cls,
            alive = true,
            healthPct = 100,
            hasTrinket = true,
            importantBuffs = {},
            importantDebuffs = {},
            observedSpells = {},
        }
    end
    return {
        enemies        = enemies,
        friendlies     = self:DefaultFriendlies(),
        observations   = opts.observations or { msActiveOn = nil, windfuryActive = true, hojReady = true },
        config         = opts.config or { strategy = { callBurstOnlyWhenMSActive = false, requireWindfuryNearby = false } },
        combatPhase    = opts.combatPhase or "PRE",
    }
end
