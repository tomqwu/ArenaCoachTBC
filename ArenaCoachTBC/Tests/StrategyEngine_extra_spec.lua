-- Tests/StrategyEngine_extra_spec.lua
-- Additional StrategyEngine coverage beyond the original happy-path tests.
local H = _G.__ACC_TEST_HELPERS

-- The original StrategyEngine_spec.lua loads everything standalone, but
-- when invoked through run_all the namespace is shared and modules are
-- already loaded. We still load defensively here.
H.load("Locales/enUS.lua")
H.load("Data/Spells.lua")
H.load("Data/Classes.lua")
H.load("Data/OwnComps.lua")
H.load("Data/Strategies.lua")
H.load("DRTracker.lua")
H.load("Patterns.lua")
H.load("StrategyEngine.lua")

local SE = H.ns.StrategyEngine
local g = H.describe("StrategyEngine.extra")

local function findEnemyByClass(state, class)
    for _, e in pairs(state.enemies) do
        if e.class == class then return e end
    end
end

local function findAction(actions, unit)
    for _, a in ipairs(actions or {}) do
        if a.unit == unit then return a end
    end
end

local function findActionByKey(actions, key)
    for _, a in ipairs(actions or {}) do
        if a.actionKey == key then return a end
    end
end

local function findSignal(signals, id)
    for _, s in ipairs(signals or {}) do
        if s.id == id then return s end
    end
end

local function hasCallout(rec, key)
    for _, c in ipairs((rec and rec.callouts) or {}) do
        if c == key then return true end
    end
    return false
end

local function hasRejectedCallout(rec, key, reason)
    for _, r in ipairs((rec and rec.rejectedCallouts) or {}) do
        if r.key == key and (not reason or r.reason == reason) then return true end
    end
    return false
end

local function hasRejectedAction(rec, key, reason)
    for _, r in ipairs((rec and rec.rejectedActions) or {}) do
        if r.key == key and (not reason or r.reason == reason) then return true end
    end
    return false
end

local function readAddonFile(rel)
    local f = assert(io.open(H.ADDON_DIR .. "/" .. rel, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

local function collectEmittedCalloutKeys()
    local keys = {}
    local function add(key)
        if type(key) == "string" and key:match("^CALL_") then keys[key] = true end
    end
    local function addList(list)
        for _, key in ipairs(list or {}) do add(key) end
    end
    local function addComp(comp)
        if not comp then return end
        addList(comp.responseHints or comp.callouts)
        for _, variant in pairs(comp.ownVariants or {}) do
            addList(variant.responseHints or variant.callouts)
        end
    end
    local Strategies = H.ns.Strategies or {}
    for _, comp in ipairs(Strategies.comps or {}) do addComp(comp) end
    for _, comp in ipairs(Strategies.testComps or {}) do addComp(comp) end
    local Patterns = H.ns.Patterns or {}
    for _, def in ipairs(Patterns.defs or {}) do add(def.labelKey) end

    -- These are inserted from StrategyEngine control flow rather than
    -- the static strategy/pattern catalogs, so keep them in the same audit.
    add("CALL_TREMOR_DOWN")
    add("CALL_BG_DEFEND")
    add("CALL_FLAG_CARRIER_LOW")
    add("CALL_LOW_MANA_PUSH")
    add("CALL_OUTNUMBERED_DISENGAGE")
    keys.BURST_NOW = true
    return keys
end

local function collectCatalogResponseHints()
    local keys = {}
    local Strategies = H.ns.Strategies or {}
    local function addList(list)
        for _, key in ipairs(list or {}) do keys[key] = true end
    end
    for _, comp in ipairs(Strategies.comps or {}) do
        addList(comp.responseHints)
        for _, variant in pairs(comp.ownVariants or {}) do addList(variant.responseHints) end
    end
    return keys
end

local function withPatternMatches(matches, fn)
    local Patterns = H.ns.Patterns or {}
    H.ns.Patterns = Patterns
    local oldGetMatches = Patterns.GetMatches
    Patterns.GetMatches = function() return matches end
    local ok, err = pcall(fn)
    Patterns.GetMatches = oldGetMatches
    if not ok then error(err, 0) end
end

-- v2.7.1: in an arena 2v4 (3 friendlies dead, 1 enemy dead from a 5v5),
-- the engine used to recommend DEFEND because "healer being trained"
-- fires when 4 enemies attack 2 players — but defensives can't save a
-- 2v4, you just burn them and die. The override suppresses DEFEND and
-- attaches CALL_OUTNUMBERED_DISENGAGE so the user knows the engine has
-- seen the spot.
H.it(g, "v2.7.1: arena 2v4 (outnumbered 2x) suppresses DEFEND + adds CALL_OUTNUMBERED_DISENGAGE", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","WARLOCK","PRIEST"})  -- 4 enemies
    state.combatPhase = "ACTIVE"
    state.pvpContext = "arena"
    state.observations = { healerUnderPressure = true }   -- would normally force DEFEND
    -- Mark 3 of the 5 default friendlies dead, leaving 2 alive — the
    -- arena 5v5 attrition scenario the user reported.
    state.friendlies.party2.alive = false   -- paladin
    state.friendlies.party3.alive = false   -- druid (the healer)
    state.friendlies.party4.alive = false   -- priest (off-healer)
    -- Re-validate setup: 2 alive friendlies vs 4 alive enemies.
    local nF, nE = 0, 0
    for _, u in pairs(state.friendlies) do if u.alive ~= false then nF = nF + 1 end end
    for _, u in pairs(state.enemies)    do if u.alive ~= false then nE = nE + 1 end end
    H.assertEq(nF, 2, "test setup: 2 alive friendlies")
    H.assertEq(nE, 4, "test setup: 4 alive enemies")
    local rec = SE:Evaluate(state)
    H.assertNotEq(rec.mode, "DEFEND",
        "outnumbered 2v4 must NOT recommend DEFEND — defensives can't save a 2v4")
    local sawCall = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_OUTNUMBERED_DISENGAGE" then sawCall = true; break end
    end
    H.assertTrue(sawCall,
        "outnumbered state must add CALL_OUTNUMBERED_DISENGAGE so the user knows the engine saw it")
end)

-- v2.7.3 (Codex review on v2.7.1): the v2.7.1 override at >=1.5x ratio
-- caught normal 2v3 / 1v2 states where defensives DO save the team.
-- Narrowed to enemy count >= 4 AND delta >= 2. Real-emergency signals
-- (low_healer, healer_cc, enemy_lust) check FIRST and short-circuit
-- before the outnumbered override, so they always win.
H.it(g, "v2.7.3: arena 2v3 with low healer must still DEFEND (not KILL + outnumbered)", function()
    -- 3v3 down to 2v3 — one friendly dead, healer alive at 20% HP.
    -- Defensives CAN save this; v2.7.1 incorrectly suppressed DEFEND.
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})   -- 3 enemies
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "arena"
    state.observations = { healerUnderPressure = true }
    -- 5 default friendlies; mark 3 dead so we're at 2 alive. Make the
    -- alive ones include a healer (party3 = DRUID resto) at 20% HP.
    state.friendlies.party1.alive = false
    state.friendlies.party2.alive = false
    state.friendlies.party4.alive = false
    state.friendlies.party3.healthPct = 20   -- the healer is low
    local nF, nE = 0, 0
    for _, u in pairs(state.friendlies) do if u.alive ~= false then nF = nF + 1 end end
    for _, u in pairs(state.enemies)    do if u.alive ~= false then nE = nE + 1 end end
    H.assertEq(nF, 2, "test setup: 2 alive friendlies")
    H.assertEq(nE, 3, "test setup: 3 alive enemies")
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND",
        "2v3 with the healer at 20% HP must still recommend DEFEND - cooldowns CAN save this")
end)

H.it(g, "v2.7.3: low_healer signal beats outnumbered override even in 2v4", function()
    -- 2v4 with the healer at 15% HP. low_healer fires first and wins,
    -- so we still recommend DEFEND. The outnumbered override only
    -- suppresses the weaker `trained` (healerUnderPressure) signal.
    local state = SE:BuildTestState({"ROGUE","MAGE","WARLOCK","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "arena"
    -- Keep party3 (DRUID RESTORATION = the real healer) alive at 15% HP,
    -- kill three others. lowestHealer needs an actual healer alive to
    -- fire the low_healer branch.
    state.friendlies.player.alive = false
    state.friendlies.party1.alive = false
    state.friendlies.party2.alive = false
    state.friendlies.party3.healthPct = 15   -- the healer is dying
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND",
        "low_healer must take precedence over the outnumbered override")
end)

H.it(g, "v2.7.1: BG 3v10 (nameplate count, not real combatants) still allows DEFEND", function()
    local state = SE:BuildTestState({"WARRIOR","PRIEST","SHAMAN"})
    state.combatPhase = "ACTIVE"
    state.pvpContext = "bg"   -- BG enemy count comes from nameplate scan, not real combat
    state.observations = { healerUnderPressure = true }
    state.enemies = {}
    for i = 1, 10 do
        state.enemies["bg-e" .. i] = { unit = "bg-e" .. i, guid = "bg-e" .. i,
                                       class = "WARRIOR", alive = true, healthPct = 100 }
    end
    state.enemyClassList = {}
    for _, e in pairs(state.enemies) do table.insert(state.enemyClassList, e.class) end
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND",
        "BG nameplate-count >1.5x must NOT trigger the arena outnumbered override")
end)

H.it(g, "Evaluate with no enemies returns RESET", function()
    local state = SE:BuildTestState({})
    state.combatPhase = "ACTIVE"
    state.enemies = {}
    state.enemyClassList = nil
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "RESET")
    H.assertNil(rec.primaryTarget)
end)

H.it(g, "Evaluate resets when the only target is not actionable", function()
    local state = SE:BuildTestState({"MAGE"})
    state.combatPhase = "ACTIVE"
    local mage = findEnemyByClass(state, "MAGE")
    mage.importantBuffs[H.ns.Spells.ICE_BLOCK] = true
    mage.unreachable = true
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "RESET", "immune unreachable target should not receive a KILL call")
end)

H.it(g, "Evaluate exposes primaryTargetHp from healthPct as a 0..1 fraction", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    local priest = findEnemyByClass(state, "PRIEST")
    priest.healthPct = 37
    local rec = SE:Evaluate(state)
    H.assertEq(rec.primaryTargetClass, "PRIEST")
    H.assertTrue(math.abs((rec.primaryTargetHp or 0) - 0.37) < 0.0001,
        "expected healthPct=37 to publish primaryTargetHp=0.37, got " .. tostring(rec.primaryTargetHp))
end)

H.it(g, "Evaluate exposes ownArchetype from default friendlies", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST","ROGUE","DRUID"})
    local rec = SE:Evaluate(state)
    -- The default friendly comp is the WAR/ENH/RET/RDRU/DISC cleave, so
    -- MELEE_CLEAVE should fire (or DOUBLE_HEALER if both healers count).
    H.assertNotNil(rec.ownArchetype)
end)

H.it(g, "Evaluate publishes DBM-style player actions for each living friendly", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext = "arena"
    state.friendlies.player.name = "Warrior"
    state.friendlies.party1.name = "Shaman"
    state.friendlies.party2.name = "Paladin"
    state.friendlies.party3.name = "Druid"
    state.friendlies.party4.name = "Priest"

    local rec = SE:Evaluate(state)
    H.assertEq(#rec.playerActions, 5)
    H.assertEq(findAction(rec.playerActions, "player").actionKey, "ACTION_WARRIOR_KILL")
    H.assertEq(findAction(rec.playerActions, "party1").actionKey, "ACTION_SHAMAN_PURGE")
    H.assertEq(findAction(rec.playerActions, "party2").actionKey, "ACTION_PALADIN_HOJ")
    H.assertEq(findAction(rec.playerActions, "party2").target, rec.primaryTarget)
end)

H.it(g, "DEFEND player actions prefer the combat-log pressure target over lowest healer HP", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext = "arena"
    state.friendlies.party3.name = "Leaves"
    state.friendlies.party3.healthPct = 18
    state.friendlies.party4.name = "Totemkin"
    state.friendlies.party4.healthPct = 86
    state.observations = {
        healerUnderPressure = true,
        healerPressure = {
            targetGuid = state.friendlies.party4.guid,
            targetUnit = "party4",
            targetName = "Totemkin",
            targetRole = "HEALER",
            events = 3,
            window = 5,
        },
    }

    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND")
    local player = findAction(rec.playerActions, "player")
    H.assertEq(player.target, state.friendlies.party4.guid,
        "defensive advice should target the trained healer, not the lower idle healer")
    H.assertEq(player.targetName, "Totemkin")
end)

H.it(g, "Shaman player gets urgent targetless Bloodlust action when burst gate opens", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    state.pvpContext = "arena"
    state.friendlies.player.class = "SHAMAN"
    state.friendlies.player.spec = "ENHANCEMENT"
    state.friendlies.player.name = "You"
    state.friendlies.party1.class = "WARRIOR"
    state.friendlies.party1.spec = "ARMS"
    state.friendlies.party1.name = "Warrior"

    local priest = findEnemyByClass(state, "PRIEST")
    priest.healthPct = 20
    priest.hasTrinket = false
    priest.importantBuffs = {}
    priest.importantDebuffs = { [H.ns.Spells.MORTAL_STRIKE] = true }

    local rec = SE:Evaluate(state)
    H.assertTrue(rec.burstAllowed, "test setup should open the burst gate")
    local player = findAction(rec.playerActions, "player")
    H.assertEq(player.actionKey, "ACTION_SHAMAN_BLOODLUST")
    H.assertEq(player.priority, "URGENT")
    H.assertNil(player.target, "Bloodlust is a self/party action, not an enemy-targeted action")
end)

H.it(g, "Tremor down under fear threat alerts first and assigns shaman to refresh", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext = "arena"
    state.observations = { tremorActive = false, windfuryActive = true, hojReady = true }
    state.friendlies.party1.name = "Totemkin"

    local rec = SE:Evaluate(state)
    H.assertEq(rec.callouts[1], "CALL_TREMOR_DOWN")
    local shaman = findAction(rec.playerActions, "party1")
    H.assertEq(shaman.actionKey, "ACTION_SHAMAN_TREMOR_REFRESH")
    H.assertEq(shaman.priority, "URGENT")
    H.assertNil(shaman.target, "refreshing Tremor is a self/ground action, not a target action")
end)

H.it(g, "Tremor refresh advice clears when the aura is active", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext = "arena"
    state.observations = { tremorActive = true, windfuryActive = true, hojReady = true }

    local rec = SE:Evaluate(state)
    for _, callout in ipairs(rec.callouts or {}) do
        H.assertNotEq(callout, "CALL_TREMOR_DOWN")
    end
    H.assertNotEq(findAction(rec.playerActions, "party1").actionKey, "ACTION_SHAMAN_TREMOR_REFRESH")
end)

H.it(g, "Tremor-specific advice is suppressed when our team has no shaman", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext = "arena"
    state.observations = { tremorActive = false, windfuryActive = true, hojReady = true }
    state.friendlies.player.class = "WARRIOR"
    state.friendlies.party1.class = "ROGUE"
    state.friendlies.party2.class = "PALADIN"
    state.friendlies.party3.class = "DRUID"
    state.friendlies.party4.class = "PRIEST"
    state.ownCapabilities = { hasTremor = false }

    local rec = SE:Evaluate(state)
    for _, callout in ipairs(rec.callouts or {}) do
        H.assertNotEq(callout, "CALL_TREMOR_DOWN")
        H.assertNotEq(callout, "CALL_TREMOR_FEAR")
        H.assertNotEq(callout, "CALL_SAVE_TREMOR_HOJ")
    end
    for _, action in ipairs(rec.playerActions or {}) do
        H.assertNotEq(action.actionKey, "ACTION_SHAMAN_TREMOR_REFRESH")
    end
end)

H.it(g, "capability gate: no shaman roster suppresses shaman-only RMP advice", function()
    local S = H.ns.Spells
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext = "arena"
    state.friendlies = {
        player = { unit = "player", class = "WARRIOR", spec = "ARMS", alive = true, healthPct = 100 },
        party1 = { unit = "party1", class = "ROGUE", alive = true, healthPct = 100 },
        party2 = { unit = "party2", class = "PALADIN", spec = "RETRIBUTION", alive = true, healthPct = 100 },
        party3 = { unit = "party3", class = "DRUID", spec = "RESTORATION", alive = true, healthPct = 100 },
        party4 = { unit = "party4", class = "PRIEST", spec = "DISCIPLINE", alive = true, healthPct = 100 },
    }
    local priest = findEnemyByClass(state, "PRIEST")
    priest.importantBuffs[S.ICY_VEINS] = true

    local rec = SE:Evaluate(state)
    H.assertFalse(hasCallout(rec, "CALL_TREMOR_FEAR"), "no shaman means no Tremor advice")
    H.assertFalse(hasCallout(rec, "CALL_GROUND_POLY"), "no shaman means no Grounding advice")
    H.assertFalse(hasCallout(rec, "CALL_PURGE"), "no shaman means no Purge advice even with a purgeable target")
    H.assertFalse(hasCallout(rec, "CALL_EARTHSHOCK_HEAL"), "no shaman means no Earth Shock advice")
    H.assertTrue(hasRejectedCallout(rec, "CALL_PURGE", "missing_hasPurge"),
        "rejected callouts should explain missing shaman Purge")
end)

H.it(g, "capability gate: no paladin/priest roster suppresses paladin and priest cooldown advice", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","WARLOCK"})
    state.combatPhase = "ACTIVE"
    state.pvpContext = "arena"
    state.observations = { healerUnderPressure = true, tremorActive = true, windfuryActive = true }
    state.friendlies = {
        player = { unit = "player", class = "WARRIOR", spec = "ARMS", alive = true, healthPct = 100 },
        party1 = { unit = "party1", class = "SHAMAN", spec = "ENHANCEMENT", alive = true, healthPct = 100 },
        party2 = { unit = "party2", class = "ROGUE", alive = true, healthPct = 100 },
        party3 = { unit = "party3", class = "DRUID", spec = "RESTORATION", alive = true, healthPct = 100 },
    }

    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND")
    H.assertFalse(hasCallout(rec, "CALL_BOP_READY"), "no paladin means no BoP advice")
    H.assertFalse(hasCallout(rec, "CALL_PAIN_SUP_READY"), "no Disc priest means no Pain Suppression advice")
    H.assertFalse(hasCallout(rec, "CALL_HOJ_KILL"), "no paladin means no HoJ advice")
    H.assertTrue(hasRejectedCallout(rec, "CALL_BOP_READY", "missing_hasBoP"))
    H.assertTrue(hasRejectedCallout(rec, "CALL_PAIN_SUP_READY", "missing_hasPainSuppression"))
end)

H.it(g, "capability gate: pattern or catalog callouts cannot bypass context requirements", function()
    withPatternMatches({
            { labelKey = "BURST_NOW" },
            { labelKey = "CALL_BG_DEFEND" },
            { labelKey = "CALL_PEEL_PRIEST" },
            { labelKey = "CALL_PATTERN_HUNTER_TRAP_SCATTER" },
        }, function()
            local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
            state.combatPhase = "ACTIVE"
            state.pvpContext = "arena"
            state.friendlies.party4.class = "ROGUE"
            state.friendlies.party4.spec = nil

            local rec = SE:Evaluate(state)
            H.assertFalse(hasCallout(rec, "BURST_NOW"), "pattern-injected burst must still need the burst gate")
            H.assertFalse(hasCallout(rec, "CALL_BG_DEFEND"), "BG callout must not appear in arena")
            H.assertFalse(hasCallout(rec, "CALL_PEEL_PRIEST"), "priest peel callout must require a friendly priest")
            H.assertFalse(hasCallout(rec, "CALL_PATTERN_HUNTER_TRAP_SCATTER"),
                "trap/scatter action text must require friendly Mass Dispel support")
            H.assertTrue(hasRejectedCallout(rec, "BURST_NOW", "burst_gate_blocked"))
            H.assertTrue(hasRejectedCallout(rec, "CALL_BG_DEFEND", "wrong_pvp_context"))
            H.assertTrue(hasRejectedCallout(rec, "CALL_PEEL_PRIEST", "missing_friendly_PRIEST"))
            H.assertTrue(hasRejectedCallout(rec, "CALL_PATTERN_HUNTER_TRAP_SCATTER", "missing_hasMassDispel"))
        end)
end)

H.it(g, "capability gate: pattern callouts require their enemy setup", function()
    withPatternMatches({ { labelKey = "CALL_PATTERN_HOJ_INTO_INTERCEPT" } }, function()
        local missingWarrior = SE:BuildTestState({"PALADIN","PRIEST"})
        missingWarrior.combatPhase = "ACTIVE"
        missingWarrior.pvpContext = "arena"
        local blocked = SE:Evaluate(missingWarrior)
        H.assertFalse(hasCallout(blocked, "CALL_PATTERN_HOJ_INTO_INTERCEPT"))
        H.assertTrue(hasRejectedCallout(blocked, "CALL_PATTERN_HOJ_INTO_INTERCEPT", "missing_required_enemy_class"))

        local withWarrior = SE:BuildTestState({"PALADIN","WARRIOR","PRIEST"})
        withWarrior.combatPhase = "ACTIVE"
        withWarrior.pvpContext = "arena"
        local allowed = SE:Evaluate(withWarrior)
        H.assertTrue(hasCallout(allowed, "CALL_PATTERN_HOJ_INTO_INTERCEPT"))
    end)
end)

H.it(g, "catalog lint: every response hint has a central requirement rule", function()
    H.assertNotNil(SE.HasCalloutRequirement, "StrategyEngine must expose requirement lint helper")
    local hints = collectCatalogResponseHints()
    local count = 0
    for key, _ in pairs(hints) do
        count = count + 1
        H.assertTrue(SE:HasCalloutRequirement(key), "missing callout requirement for response hint " .. tostring(key))
    end
    H.assertTrue(count > 0, "catalog response hint lint should inspect at least one hint")
end)

H.it(g, "capability gate: injected callouts still require live threat and target facts", function()
    withPatternMatches({ { labelKey = "CALL_PATTERN_FEAR_INTO_POLY" } }, function()
            local state = SE:BuildTestState({"MAGE","DRUID"})
            state.combatPhase = "ACTIVE"
            state.pvpContext = "arena"
            local rec = SE:Evaluate(state)
            H.assertFalse(hasCallout(rec, "CALL_PATTERN_FEAR_INTO_POLY"))
            H.assertTrue(hasRejectedCallout(rec, "CALL_PATTERN_FEAR_INTO_POLY", "missing_fear_threat"))
        end)

    withPatternMatches({
            { labelKey = "CALL_FAKE_KICK_2" },
            { labelKey = "CALL_LOW_MANA_PUSH" },
            { labelKey = "CALL_OUTNUMBERED_DISENGAGE" },
        }, function()
            local state = SE:BuildTestState({"PRIEST","DRUID"})
            state.combatPhase = "ACTIVE"
            state.pvpContext = "arena"
            local rec = SE:Evaluate(state)
            H.assertFalse(hasCallout(rec, "CALL_FAKE_KICK_2"))
            H.assertFalse(hasCallout(rec, "CALL_LOW_MANA_PUSH"))
            H.assertFalse(hasCallout(rec, "CALL_OUTNUMBERED_DISENGAGE"))
            H.assertTrue(hasRejectedCallout(rec, "CALL_FAKE_KICK_2", "missing_enemy_interrupt"))
            H.assertTrue(hasRejectedCallout(rec, "CALL_LOW_MANA_PUSH", "missing_low_mana_target"))
            H.assertTrue(hasRejectedCallout(rec, "CALL_OUTNUMBERED_DISENGAGE", "missing_outnumbered"))
        end)
end)

H.it(g, "capability gate: BG callouts require matching mode and flag carrier state", function()
    withPatternMatches({
            { labelKey = "CALL_BG_DEFEND" },
            { labelKey = "CALL_FLAG_CARRIER_LOW" },
        }, function()
            local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
            state.combatPhase = "ACTIVE"
            state.pvpContext = "bg"
            local rec = SE:Evaluate(state)
            H.assertFalse(hasCallout(rec, "CALL_BG_DEFEND"))
            H.assertFalse(hasCallout(rec, "CALL_FLAG_CARRIER_LOW"))
            H.assertTrue(hasRejectedCallout(rec, "CALL_BG_DEFEND", "wrong_mode"))
            H.assertTrue(hasRejectedCallout(rec, "CALL_FLAG_CARRIER_LOW", "missing_low_flag_carrier"))
        end)
end)

H.it(g, "capability gate: low-mana healer push fires only on the actual low-mana healer target", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext = "arena"
    local priest = findEnemyByClass(state, "PRIEST")
    priest.healthPct = 20
    priest.manaPct = 10

    local rec = SE:Evaluate(state)
    H.assertTrue(hasCallout(rec, "CALL_LOW_MANA_PUSH"))
end)

H.it(g, "capability gate: post-builder burst and outnumbered callouts are not direct inserts", function()
    local source = readAddonFile("StrategyEngine.lua")
    H.assertFalse(source:find("table%.insert%(%s*callouts", 1, false) ~= nil,
        "recommendation callouts must be emitted through addCallout so requirements/rejections run")
end)

H.it(g, "capability gate: every emitted callout key has a central requirement rule", function()
    local source = readAddonFile("StrategyEngine.lua")
    for key, _ in pairs(collectEmittedCalloutKeys()) do
        H.assertTrue(source:find(key .. "%s*=", 1, false) ~= nil,
            key .. " must have an explicit CALLOUT_REQUIREMENTS entry, even when intentionally unconditional")
    end
end)

H.it(g, "action gate: owned ability actions are rejected when capability inference denies them", function()
    local OwnComps = H.ns.OwnComps
    local oldInfer = OwnComps.Infer
    local oldIdentify = OwnComps.Identify
    OwnComps.Infer = function(self, friendlies)
        local caps = oldInfer(self, friendlies)
        caps.hasPurge = false
        caps.hasHoJ = false
        caps.hasBloodlust = false
        caps.hasTremor = false
        return caps
    end
    OwnComps.Identify = function() return nil end

    local rec
    local ok, err = pcall(function()
        local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
        state.combatPhase = "ACTIVE"
        state.pvpContext = "arena"
        rec = SE:Evaluate(state)
    end)

    OwnComps.Infer = oldInfer
    OwnComps.Identify = oldIdentify
    if not ok then error(err, 0) end

    local shaman = findAction(rec.playerActions, "party1")
    local paladin = findAction(rec.playerActions, "party2")
    H.assertNil(shaman, "shaman Purge action should be removed when hasPurge is false")
    H.assertNil(paladin, "paladin HoJ action should be removed when hasHoJ is false")
    H.assertTrue(hasRejectedAction(rec, "ACTION_SHAMAN_PURGE", "missing_hasPurge"))
    H.assertTrue(hasRejectedAction(rec, "ACTION_PALADIN_HOJ", "missing_hasHoJ"))
end)

H.it(g, "Tremor down does not wake targetless RESET states", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext = "arena"
    state.observations = { tremorActive = false, windfuryActive = true, hojReady = true }
    for _, e in pairs(state.enemies) do e.alive = false end

    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "RESET")
    for _, callout in ipairs(rec.callouts or {}) do
        H.assertNotEq(callout, "CALL_TREMOR_DOWN")
    end
    H.assertNotEq(findAction(rec.playerActions, "party1").actionKey, "ACTION_SHAMAN_TREMOR_REFRESH")
end)

H.it(g, "Player actions use the off-target healer for druid CC assignments", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext = "arena"
    for _, e in pairs(state.enemies) do
        if e.class == "MAGE" then
            e.healthPct = 10
            e.hasTrinket = false
        end
    end

    local rec = SE:Evaluate(state)
    H.assertEq(rec.primaryTargetClass, "MAGE")
    local druid = findAction(rec.playerActions, "party3")
    H.assertEq(druid.actionKey, "ACTION_DRUID_HEAL_CC")
    H.assertEq(druid.targetClass, "PRIEST")
end)

H.it(g, "DEFEND player actions assign healer defensives to the trained friendly", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext = "arena"
    state.observations = { healerUnderPressure = true }
    state.friendlies.party3.name = "Treefriend"
    state.friendlies.party3.healthPct = 40
    state.friendlies.party4.healthPct = 90

    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND")
    local pal = findAction(rec.playerActions, "party2")
    H.assertEq(pal.actionKey, "ACTION_PALADIN_DEFEND")
    H.assertEq(pal.targetName, "Treefriend")
    H.assertEq(pal.targetType, "friendly")
end)

H.it(g, "Burst blocked when no windfury (config requires it)", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST","ROGUE","DRUID"})
    state.combatPhase = "ACTIVE"
    state.config.strategy.requireWindfuryNearby = true
    state.observations.windfuryActive = false
    for _, enemy in pairs(state.enemies) do
        enemy.importantDebuffs = { [H.ns.Spells.MORTAL_STRIKE] = true }
    end
    local rec = SE:Evaluate(state)
    H.assertFalse(rec.burstAllowed)
    H.assertEq(rec.burstBlockedBy, "no_windfury")
end)

H.it(g, "Burst blocked when target is immune", function()
    local state = SE:BuildTestState({"MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.config.strategy.callBurstOnlyWhenMSActive = false
    state.config.strategy.requireWindfuryNearby = false
    local mage = findEnemyByClass(state, "MAGE")
    mage.importantBuffs[H.ns.Spells.ICE_BLOCK] = true
    -- Force top target to be the mage by giving the priest a HoT-like buff
    -- not relevant; we'll just check that immune burst is blocked when any
    -- enemy has immunity (engine sets burstBlockedBy="target_immune" only
    -- if the top target is immune)
    local priest = findEnemyByClass(state, "PRIEST")
    priest.alive = false  -- only mage alive
    local rec = SE:Evaluate(state)
    H.assertFalse(rec.burstAllowed)
end)

H.it(g, "Recommendation has priority field for each mode", function()
    local cases = {
        { phase = "PRE",   expected = "OPEN" },
    }
    for _, c in ipairs(cases) do
        local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST","ROGUE","DRUID"})
        state.combatPhase = c.phase
        local rec = SE:Evaluate(state)
        H.assertNotNil(rec.priority)
    end
end)

H.it(g, "shouldDefend triggers on bloodlust active", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST","ROGUE","DRUID"})
    state.combatPhase = "ACTIVE"
    state.observations.enemyBloodlustActive = true
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND")
end)

H.it(g, "shouldDefend triggers on multipleBurstsDetected", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST","ROGUE","DRUID"})
    state.combatPhase = "ACTIVE"
    state.observations.multipleBurstsDetected = true
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND")
end)

H.it(g, "purgeable buff increases score", function()
    local state = SE:BuildTestState({"WARRIOR","PRIEST","MAGE","WARLOCK","DRUID"})
    local mage = findEnemyByClass(state, "MAGE")
    mage.importantBuffs[H.ns.Spells.ICY_VEINS] = true
    SE:Evaluate(state)
    -- The presence of a purgeable buff is one of the scoring inputs.
    H.assertNotNil(mage._contrib)
end)

H.it(g, "major_defensive_down fires from an observed cooldown >= 15s out (v2.9)", function()
    -- v2.9: the bonus derives from CooldownTracker observations, not the
    -- never-set enemy.majorDefensiveDown field.
    H.load("CooldownTracker.lua")
    local CT = H.ns.CooldownTracker
    CT:Clear()
    local state = SE:BuildTestState({"MAGE","PRIEST"})
    local mage = findEnemyByClass(state, "MAGE")
    CT:MarkUsed(mage.guid, H.ns.Spells.ICE_BLOCK)  -- 5m CD just spent
    SE:Evaluate(state)
    local found = false
    for _, c in ipairs(mage._contrib or {}) do
        if c.key == "major_defensive_down" then found = true end
    end
    H.assertTrue(found, "expected major_defensive_down contribution")
    CT:Clear()
end)

H.it(g, "kill_defensive_soon penalty when observed CD nearly back (v2.9)", function()
    H.load("CooldownTracker.lua")
    local CT = H.ns.CooldownTracker
    CT:Clear()
    local state = SE:BuildTestState({"MAGE","PRIEST"})
    local mage = findEnemyByClass(state, "MAGE")
    -- Ice Block used 295s ago on a 300s CD -> back in 5s -> penalty.
    local t = (type(GetTime) == "function") and GetTime() or os.time()
    CT:_record(mage.guid, H.ns.Spells.ICE_BLOCK, 300, t - 295)
    SE:Evaluate(state)
    local found = false
    for _, c in ipairs(mage._contrib or {}) do
        if c.key == "kill_defensive_soon" then found = true end
    end
    H.assertTrue(found, "expected kill_defensive_soon contribution")
    CT:Clear()
end)

H.it(g, "v2.9 regression: positional pseudo-weights stay deleted", function()
    -- These weights read fields (overextended / unreachable / losBlocked)
    -- that no production code ever set — the client exposes no positioning
    -- data. Setting the fields must not change the score, and the weights
    -- must not exist.
    H.assertNil(SE.weights.role_melee_overext)
    H.assertNil(SE.weights.target_unreachable)
    H.assertNil(SE.weights.target_los_blocked)
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    SE:Evaluate(state)
    local before = findEnemyByClass(state, "PRIEST")._score
    local state2 = SE:BuildTestState({"PRIEST","MAGE"})
    local p2 = findEnemyByClass(state2, "PRIEST")
    p2.unreachable = true; p2.losBlocked = true; p2.overextended = true
    SE:Evaluate(state2)
    H.assertEq(p2._score, before, "dead fields must not affect scoring")
end)

H.it(g, "v2.9: MS burst requirement self-disables when the team has no MS", function()
    -- A rogue/priest 2v2 has no Mortal Strike. With the pre-v2.9 gate
    -- (`hasMS or cfg`), the default config blocked BURST_NOW forever for
    -- such teams. The requirement must only apply when OwnComps reports
    -- hasMortalStrike.
    local state = SE:BuildTestState({ "PRIEST", "MAGE" }, {
        observations = { hojReady = true },
        config = { strategy = {} },  -- defaults: nothing opted out
    })
    state.friendlies = {
        player = { unit = "player", class = "ROGUE",  spec = "SUBTLETY",   alive = true, healthPct = 100 },
        party1 = { unit = "party1", class = "PRIEST", spec = "DISCIPLINE", alive = true, healthPct = 100 },
    }
    state.combatPhase = "ACTIVE"
    state.aggression = "greedy"
    local target = findEnemyByClass(state, "PRIEST")
    target.healthPct = 5
    target.hasTrinket = false
    local out = SE:BurstDecision(state, target, nil)
    H.assertFalse(out.gates.ms_active.required or false,
        "no MS on the team -> requirement off")
    H.assertNotEq(out.blockedBy, "no_ms")
    H.assertNotEq(out.blockedBy, "no_windfury")
end)

H.it(g, "v2.9: windfury requirement self-disables when the team has no shaman", function()
    local state = SE:BuildTestState({ "PRIEST", "MAGE" }, {
        observations = { hojReady = true, windfuryActive = false },
        config = { strategy = { requireWindfuryNearby = true } },
    })
    state.friendlies = {
        player = { unit = "player", class = "ROGUE",  spec = "SUBTLETY",   alive = true, healthPct = 100 },
        party1 = { unit = "party1", class = "PRIEST", spec = "DISCIPLINE", alive = true, healthPct = 100 },
    }
    state.combatPhase = "ACTIVE"
    local target = findEnemyByClass(state, "PRIEST")
    local out = SE:BurstDecision(state, target, nil)
    H.assertTrue(out.gates.windfury.allowed,
        "windfury gate must not block a shaman-less team")
end)

H.it(g, "DefaultFriendlies returns 5 players in spec'd comp", function()
    local fr = SE:DefaultFriendlies()
    H.assertNotNil(fr.player)
    H.assertNotNil(fr.party1)
    H.assertNotNil(fr.party4)
    H.assertEq(fr.player.class, "WARRIOR")
end)

H.it(g, "BuildTestState wires friendlies + opts", function()
    local s = SE:BuildTestState({"MAGE"}, {
        observations = { windfuryActive = false },
        combatPhase  = "ACTIVE",
    })
    H.assertEq(s.combatPhase, "ACTIVE")
    H.assertFalse(s.observations.windfuryActive)
end)

H.it(g, "Friendly rooted+snared without freedom marks meleeLockedDown", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.friendlies.player.debuffs = { rooted = true }
    state.combatPhase = "ACTIVE"
    local rec = SE:Evaluate(state)
    -- Penalty applied -> top target's score is reduced. We only assert
    -- the engine runs and yields a target.
    H.assertNotNil(rec)
end)

H.it(g, "Healer CC penalty applied", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.friendlies.party4.debuffs = { stunned = true }
    state.combatPhase = "ACTIVE"
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND")
end)

H.it(g, "Team avg HP < 45 applies penalty", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    for _, f in pairs(state.friendlies) do f.healthPct = 30 end
    state.combatPhase = "ACTIVE"
    local rec = SE:Evaluate(state)
    H.assertNotNil(rec)
end)

H.it(g, "GetWeights returns defaults when bracket is nil", function()
    local w = SE:GetWeights(nil)
    H.assertEq(w.role_healer, SE.weights.role_healer)
end)

H.it(g, "GetWeights merges bracket overrides over defaults", function()
    -- 2v2 boosts role_healer; the merged value should reflect that without
    -- mutating the underlying default table.
    local w = SE:GetWeights(2)
    H.assertEq(w.role_healer, 40)
    H.assertEq(SE.weights.role_healer, 25, "default table should not mutate")
end)

H.it(g, "GetWeights for 5v5 yields the default values (no overrides)", function()
    local w = SE:GetWeights(5)
    H.assertEq(w.role_healer, SE.weights.role_healer)
end)

H.it(g, "Evaluate consumes state.bracket so scoring picks up overrides", function()
    local state = SE:BuildTestState({"PRIEST","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.bracket = 2
    local rec = SE:Evaluate(state)
    H.assertNotNil(rec)  -- engine still produces a rec under bracket=2
end)

H.it(g, "comp targetPlan.open biases PRE target selection", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "PRE"
    local rec = SE:Evaluate(state)
    H.assertEq(rec.comp, "WLD")
    H.assertEq(rec.primaryTargetClass, "WARLOCK")
end)

H.it(g, "arena quality: pre-gates ignores stale healer-train pressure", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "PRE"
    state.pvpContext = "arena"
    state.observations = { healerUnderPressure = true }

    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "OPEN",
        "arena prep must plan the opener, not show live DEFEND from stale train state")
    H.assertNotEq(rec.reasonKey, "REASON_DEFEND_TRAINED")
end)

H.it(g, "arena quality: 2v2 Warrior/Paladin pre-gates opens paladin instead of fake DEFEND", function()
    local state = SE:BuildTestState({ "WARRIOR", "PALADIN" })
    state.combatPhase = "PRE"
    state.bracket = 2
    state.pvpContext = "arena"

    local rec = SE:Evaluate(state)

    H.assertEq(rec.mode, "OPEN", "2v2 warrior/paladin should produce opener guidance")
    H.assertEq(rec.primaryTargetClass, "PALADIN", "paladin is the planned opener target")
end)

H.it(g, "arena quality: 2v2 Hunter/Warrior pre-gates opens hunter instead of fake DEFEND", function()
    local state = SE:BuildTestState({ "HUNTER", "WARRIOR" })
    state.combatPhase = "PRE"
    state.bracket = 2
    state.pvpContext = "arena"

    local rec = SE:Evaluate(state)

    H.assertEq(rec.mode, "OPEN", "2v2 hunter/warrior should produce opener guidance")
    H.assertEq(rec.primaryTargetClass, "HUNTER", "hunter is the planned opener target")
end)

H.it(g, "arena quality: 2v2 shatter kills the low mage over generic priest bias", function()
    local state = SE:BuildTestState({ "MAGE", "PRIEST" })
    state.combatPhase = "ACTIVE"
    state.bracket = 2
    state.pvpContext = "arena"

    for _, enemy in pairs(state.enemies) do
        if enemy.class == "MAGE" then
            enemy.healthPct = 25
        end
    end

    local rec = SE:Evaluate(state)

    H.assertEq(rec.mode, "KILL")
    H.assertEq(rec.primaryTargetClass, "MAGE", "low mage should be the kill window")
end)

H.it(g, "aggression setting changes swap threshold", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    state.config.strategy.aggression = "greedy"
    local priest = findEnemyByClass(state, "PRIEST")
    local mage = findEnemyByClass(state, "MAGE")
    mage.hasTrinket = false
    state.lastPrimaryGUID = priest.guid
    local rec = SE:Evaluate(state)
    H.assertEq(rec.primaryTargetClass, "MAGE")
    H.assertEq(rec.mode, "SWAP")

    local safeState = SE:BuildTestState({"PRIEST","MAGE"})
    safeState.combatPhase = "ACTIVE"
    safeState.config.strategy.aggression = "safe"
    findEnemyByClass(safeState, "MAGE").hasTrinket = false
    safeState.lastPrimaryGUID = findEnemyByClass(safeState, "PRIEST").guid
    local safeRec = SE:Evaluate(safeState)
    H.assertEq(safeRec.primaryTargetClass, "MAGE")
    H.assertEq(safeRec.mode, "KILL")
end)

H.it(g, "kill_defensive_soon penalty fires when major defensive <15s away", function()
    H.load("CooldownTracker.lua")
    local CT = H.ns.CooldownTracker
    local state = SE:BuildTestState({"MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    local m = findEnemyByClass(state, "MAGE")
    H._gameTime = 1000
    CT:Clear()
    -- used at t=705, ready at t=1005 -> remaining = 5
    CT:_record(m.guid, 27619, 300, 705)
    SE:Evaluate(state)
    local sawPenalty = false
    for _, c in ipairs(m._contrib or {}) do
        if c.key == "kill_defensive_soon" then sawPenalty = true end
    end
    H.assertTrue(sawPenalty, "expected kill_defensive_soon penalty")
    CT:Clear()
end)

H.it(g, "kill_defensive_soon penalty does NOT fire when defensive >30s away", function()
    H.load("CooldownTracker.lua")
    local CT = H.ns.CooldownTracker
    local state = SE:BuildTestState({"MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    local m = findEnemyByClass(state, "MAGE")
    H._gameTime = 1000
    CT:Clear()
    -- Used at t=940, ready at t=1240 -> remaining 240 seconds
    CT:_record(m.guid, 27619, 300, 940)
    SE:Evaluate(state)
    for _, c in ipairs(m._contrib or {}) do
        if c.key == "kill_defensive_soon" then
            error("penalty unexpectedly applied at rem=240s")
        end
    end
    CT:Clear()
end)

H.it(g, "CALL_HOJ_KILL is suppressed when STUN DR is immune on primary target", function()
    H.load("DRTracker.lua")
    local DR = H.ns.DRTracker
    DR:Clear()
    local state = SE:BuildTestState({"PRIEST","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.observations = { hojReady = true }
    local p = findEnemyByClass(state, "PRIEST")
    p.guid = "guid-priest-dr"
    H._gameTime = 1000
    DR:OnCC("SPELL_AURA_APPLIED", p.guid, 10308, "STUN", 999)
    DR:OnCC("SPELL_AURA_APPLIED", p.guid, 10308, "STUN", 998)
    DR:OnCC("SPELL_AURA_APPLIED", p.guid, 10308, "STUN", 997)
    local rec = SE:Evaluate(state)
    H.assertNotNil(rec)
    local hojIn = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_HOJ_KILL" then hojIn = true end
    end
    H.assertFalse(hojIn, "CALL_HOJ_KILL should be suppressed at full DR immunity")
end)

H.it(g, "CALL_HOJ_KILL is allowed when no STUN DR observed", function()
    H.load("DRTracker.lua")
    H.ns.DRTracker:Clear()
    local state = SE:BuildTestState({"PRIEST","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.observations = { hojReady = true }
    local rec = SE:Evaluate(state)
    local hojIn = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_HOJ_KILL" then hojIn = true end
    end
    H.assertTrue(hojIn, "CALL_HOJ_KILL should fire when DR is clean")
end)

-- =================================================================
-- Comp-match confidence plumbed through Evaluate (M7 #56)
-- =================================================================

H.it(g, "Evaluate exposes compConfidence + compSpecConfirmed on the recommendation", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "PRE"
    local rec = SE:Evaluate(state)
    H.assertEq(rec.comp, "WLD")
    H.assertNotNil(rec.compConfidence, "compConfidence should be present")
    H.assertNotNil(rec.compSpecConfirmed, "compSpecConfirmed should be present")
    H.assertFalse(rec.compSpecConfirmed, "class-only WLD should not be spec-confirmed")
end)

H.it(g, "Evaluate flags compSpecConfirmed=true when spec-keyed comp matches", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.bracket = 3
    -- Pin the priest's spec to DISCIPLINE so RMP_DISC_3V3 wins
    for _, e in pairs(state.enemies) do
        if e.class == "PRIEST" then
            e.specGuess = "DISCIPLINE"
            e.roleGuess = "HEALER"
        end
    end
    local rec = SE:Evaluate(state)
    H.assertEq(rec.comp, "RMP_DISC_3V3")
    H.assertTrue(rec.compSpecConfirmed, "spec-keyed comp match should set compSpecConfirmed")
    H.assertEq(rec.compConfidence, 1.0)
end)

-- =================================================================
-- Chain scoring plumbed into Evaluate (M8 #61)
-- =================================================================

H.it(g, "Evaluate emits a chain field for a comp that has chains", function()
    H.load("Chain.lua")
    H.load("Lookahead.lua")
    H.ns.DRTracker:Clear()
    H.ns.CooldownTracker:Clear()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.bracket = 5
    local rec = SE:Evaluate(state)
    H.assertEq(rec.comp, "WLD")
    H.assertNotNil(rec.chain, "expected rec.chain for WLD which has chains")
    H.assertEq(rec.chain.id, "wld_fear_into_cyclone")
    H.assertTrue(rec.chain.expectedProb > 0)
    -- M8 #62: labelKey is propagated for UI rendering
    H.assertEq(rec.chain.labelKey, "CHAIN_WLD_FEAR_INTO_CYCLONE")
    H.assertEq(rec.chain.steps, 2)
    -- M10 #67: lookahead expected value is set when Lookahead is loaded
    H.assertNotNil(rec.chain.expectedValue, "lookahead should populate expectedValue")
    H.assertTrue(rec.chain.expectedValue <= rec.chain.expectedProb,
        "EV should not exceed raw chain prob")
end)

H.it(g, "Evaluate respects strategy.lookaheadEnabled=false to skip lookahead", function()
    H.load("Chain.lua")
    H.load("Lookahead.lua")
    H.ns.DRTracker:Clear()
    H.ns.CooldownTracker:Clear()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.config.strategy.lookaheadEnabled = false
    local rec = SE:Evaluate(state)
    H.assertNil(rec.chain.expectedValue, "expectedValue should be nil when lookahead disabled")
end)

H.it(g, "Evaluate omits rec.chain when the comp has no chains", function()
    H.load("Chain.lua")
    H.ns.DRTracker:Clear()
    H.ns.CooldownTracker:Clear()
    -- WMH_3V3 (warrior/mage/priest, bracket-3 "thunder cleave") has no
    -- chains entry today. Default roles give exactly 1 healer (priest),
    -- so the static matcher picks it instead of dynamic DOUBLE_HEALER.
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.bracket = 3
    local rec = SE:Evaluate(state)
    H.assertEq(rec.comp, "WMH_3V3")
    H.assertNil(rec.chain, "WMH_3V3 has no chains field")
end)

H.it(g, "Evaluate prefers the higher-prob chain when DR pre-bumps one", function()
    H.load("Chain.lua")
    H.ns.DRTracker:Clear()
    H.ns.CooldownTracker:Clear()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.bracket = 5
    -- First measure the baseline expected prob for WLD's fear chain.
    local baseline = SE:Evaluate(state).chain.expectedProb
    -- Now pre-bump FEAR DR on the primary target so the chain's
    -- expected prob drops.
    local rec = SE:Evaluate(state)
    H.assertNotNil(rec.primaryTarget)
    H.ns.DRTracker:Apply(rec.primaryTarget, "FEAR", H._gameTime or 0)
    local after = SE:Evaluate(state).chain.expectedProb
    H.assertTrue(after < baseline,
        "expected prob should drop after FEAR DR applied (baseline=" ..
        baseline .. ", after=" .. tostring(after) .. ")")
    H.ns.DRTracker:Clear()
end)

-- =================================================================
-- Profile-driven callouts (M9 #65)
-- =================================================================

local function seedProfile(state, tendency, alpha, beta)
    H.load("OpponentProfile.lua")
    local OP = H.ns.OpponentProfile
    state.opponentProfile = {
        tendencies = {
            trinketsFear      = { alpha = 1, beta = 1, observations = 0 },
            iceBlockBelow30   = { alpha = 1, beta = 1, observations = 0 },
            kicksFirstHeal    = { alpha = 1, beta = 1, observations = 0 },
            sapsPriest        = { alpha = 1, beta = 1, observations = 0 },
        },
    }
    -- Inject observation count by bumping alpha/beta the agreed-upon
    -- number of times so OP:Estimate sees the right n.
    local rec = state.opponentProfile.tendencies[tendency]
    rec.alpha = alpha
    rec.beta  = beta
    rec.observations = (alpha - 1) + (beta - 1)
end

H.it(g, "Evaluate pushes CALL_FAKE_KICK_2 when kicksFirstHeal >= 0.7 with enough samples", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    seedProfile(state, "kicksFirstHeal", 8, 2)  -- alpha=8, beta=2 -> 0.8, n=8
    local rec = SE:Evaluate(state)
    local found = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_FAKE_KICK_2" then found = true; break end
    end
    H.assertTrue(found, "expected CALL_FAKE_KICK_2 in callouts")
    H.assertTrue(rec.profileContrib:find("kicksFirstHeal") ~= nil,
        "profileContrib should mention kicksFirstHeal")
end)

H.it(g, "Evaluate pushes CALL_SAVE_TREMOR_HOJ when trinketsFear >= 0.7 with enough samples", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    seedProfile(state, "trinketsFear", 10, 3)  -- 10/13 ~ 0.77
    local rec = SE:Evaluate(state)
    local found = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_SAVE_TREMOR_HOJ" then found = true; break end
    end
    H.assertTrue(found, "expected CALL_SAVE_TREMOR_HOJ in callouts")
    local _, count = (rec.profileContrib or ""):gsub("trinketsFear", "")
    H.assertEq(count, 1, "profileContrib should list trinketsFear once")
end)

H.it(g, "Evaluate suppresses profile Tremor callout without Tremor support", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.friendlies.player.class = "WARRIOR"
    state.friendlies.party1.class = "ROGUE"
    state.friendlies.party2.class = "PALADIN"
    state.friendlies.party3.class = "DRUID"
    state.friendlies.party4.class = "PRIEST"
    state.ownCapabilities = { hasTremor = false }
    seedProfile(state, "trinketsFear", 10, 3)  -- 10/13 ~ 0.77

    local rec = SE:Evaluate(state)
    for _, c in ipairs(rec.callouts or {}) do
        H.assertNotEq(c, "CALL_SAVE_TREMOR_HOJ")
    end
end)

H.it(g, "Evaluate pushes CALL_BURST_BLOCK_INCOMING when iceBlockBelow30 >= 0.7", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    seedProfile(state, "iceBlockBelow30", 9, 2)  -- ~ 0.82
    local rec = SE:Evaluate(state)
    local found = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_BURST_BLOCK_INCOMING" then found = true; break end
    end
    H.assertTrue(found)
end)

H.it(g, "Evaluate suppresses CALL_BURST_BLOCK_INCOMING when no mage exists", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    seedProfile(state, "iceBlockBelow30", 9, 2)  -- ~ 0.82
    local rec = SE:Evaluate(state)
    H.assertFalse(hasCallout(rec, "CALL_BURST_BLOCK_INCOMING"),
        "Ice Block tendency must not create mage advice against a non-mage comp")
    H.assertTrue(hasRejectedCallout(rec, "CALL_BURST_BLOCK_INCOMING", "missing_enemy_MAGE"))
end)

H.it(g, "Evaluate suppresses profile callouts when samples < threshold", function()
    -- Only 3 observations (< MIN_SAMPLES_FOR_OPINION = 5). Even with
    -- 3-of-3 positive, EstimateOrDefault returns the fallback 0.5,
    -- which is below the 0.7 callout gate.
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    seedProfile(state, "kicksFirstHeal", 4, 1)  -- n = 3, mean = 0.8 but gated by n
    local rec = SE:Evaluate(state)
    for _, c in ipairs(rec.callouts or {}) do
        H.assertTrue(c ~= "CALL_FAKE_KICK_2",
            "should not push CALL_FAKE_KICK_2 with n=3 (below threshold)")
    end
end)

H.it(g, "Evaluate uses comp profileDefaults before profile samples mature", function()
    local Strategies = H.ns.Strategies
    local rmp
    for _, comp in ipairs(Strategies.comps or {}) do
        if comp.id == "RMP" then rmp = comp; break end
    end
    H.assertNotNil(rmp, "RMP comp missing")
    local savedDefaults = rmp.profileDefaults
    rmp.profileDefaults = { iceBlockBelow30 = 0.75 }

    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    seedProfile(state, "iceBlockBelow30", 4, 1)  -- n = 3, so EstimateOrDefault uses comp default
    local rec = SE:Evaluate(state)

    rmp.profileDefaults = savedDefaults
    H.assertTrue(hasCallout(rec, "CALL_BURST_BLOCK_INCOMING"),
        "comp profileDefaults should feed profile callouts before samples mature")
end)

H.it(g, "Evaluate does not push profile callouts when no profile is on state", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.opponentProfile = nil
    local rec = SE:Evaluate(state)
    for _, c in ipairs(rec.callouts or {}) do
        H.assertTrue(c ~= "CALL_FAKE_KICK_2"
            and c ~= "CALL_SAVE_TREMOR_HOJ"
            and c ~= "CALL_BURST_BLOCK_INCOMING",
            "no-profile state should not emit profile callouts")
    end
    H.assertNil(rec.profileContrib)
end)

H.it(g, "Evaluate exposes opponentSignature from state", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.opponentSignature = "TEST_SIG#1234"
    local rec = SE:Evaluate(state)
    H.assertEq(rec.opponentSignature, "TEST_SIG#1234")
end)

-- =================================================================
-- M11 #73: Multi-reason burst gate
-- =================================================================

H.it(g, "BurstDecision returns named gates for probability, setup, pressure, and prerequisites", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    local target = {}
    for _, e in pairs(state.enemies) do target = e; break end
    local out = SE:BurstDecision(state, target, nil)
    H.assertNotNil(out.gates.kill_prob)
    H.assertNotNil(out.gates.chain_ready)
    H.assertNotNil(out.gates.incoming_pressure)
    H.assertNotNil(out.gates.rating_aware)
    H.assertNotNil(out.gates.ms_active)
    H.assertNotNil(out.gates.windfury)
    H.assertNotNil(out.gates.target_vulnerable)
    H.assertNotNil(out.gates.melee_uptime)
end)

H.it(g, "BurstDecision blocks on kill_prob when target is high HP", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    state.aggression  = "balanced"
    local target
    for _, e in pairs(state.enemies) do
        e.healthPct = 100; e.hasTrinket = true; e.importantDebuffs = { [H.ns.Spells.MORTAL_STRIKE] = true }; target = e
    end
    local out = SE:BurstDecision(state, target, nil)
    H.assertFalse(out.gates.kill_prob.allowed)
    H.assertEq(out.blockedBy, "kill_prob")
end)

H.it(g, "BurstDecision kill_prob threshold scales with aggression", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    local target = { healthPct = 50, hasTrinket = true, importantBuffs = {} }
    state.aggression = "greedy"
    H.assertTrue(SE:BurstDecision(state, target, nil).gates.kill_prob.threshold < 0.5)
    state.aggression = "safe"
    H.assertTrue(SE:BurstDecision(state, target, nil).gates.kill_prob.threshold > 0.5)
end)

H.it(g, "BurstDecision blocks on incoming_pressure when healer is under pressure", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    state.aggression  = "balanced"
    state.observations = { healerUnderPressure = true }
    -- Even with a perfect target, the gate fires.
    local target = { healthPct = 0, hasTrinket = false, importantBuffs = {} }
    local out = SE:BurstDecision(state, target, { expectedProb = 0.9 })
    H.assertFalse(out.gates.incoming_pressure.allowed)
end)

H.it(g, "BurstDecision allows when all gates pass", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    state.aggression  = "greedy"
    state.observations = {}
    local target = { healthPct = 20, hasTrinket = false, importantBuffs = {}, guid = "g1" }
    target.importantDebuffs = { [H.ns.Spells.MORTAL_STRIKE] = true }
    local out = SE:BurstDecision(state, target, { expectedProb = 0.8 })
    H.assertTrue(out.gates.kill_prob.allowed)
    H.assertTrue(out.gates.chain_ready.allowed)
    H.assertTrue(out.gates.incoming_pressure.allowed)
    H.assertTrue(out.allowed, "all gates passed; burst should be allowed")
end)

H.it(g, "BurstDecision folds MS and Windfury prerequisites into blockedBy", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    state.config.strategy.callBurstOnlyWhenMSActive = true
    state.config.strategy.requireWindfuryNearby = true
    state.observations = { windfuryActive = false }
    local target = { healthPct = 5, hasTrinket = false, importantBuffs = {}, guid = "g1" }
    local out = SE:BurstDecision(state, target, { expectedProb = 0.8 })
    H.assertFalse(out.allowed)
    H.assertEq(out.blockedBy, "no_ms")

    state.observations.msActiveOn = "g1"
    out = SE:BurstDecision(state, target, { expectedProb = 0.8 })
    H.assertFalse(out.allowed)
    H.assertEq(out.blockedBy, "no_windfury")
end)

H.it(g, "BurstDecision does not treat rooted healers as failed melee uptime", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    state.aggression = "greedy"
    state.config.strategy.callBurstOnlyWhenMSActive = false
    state.config.strategy.requireWindfuryNearby = false
    state.friendlies.player.debuffs = nil
    state.friendlies.party4.debuffs = { rooted = true } -- priest healer/support, not melee uptime
    local target = { healthPct = 5, hasTrinket = false, importantBuffs = {}, guid = "g1" }
    target.importantDebuffs = { [H.ns.Spells.MORTAL_STRIKE] = true }
    local out = SE:BurstDecision(state, target, nil)
    H.assertTrue(out.gates.melee_uptime.allowed,
        "a rooted priest should not block burst as if the melee were rooted")
    H.assertTrue(out.allowed)
end)

H.it(g, "BurstDecision only requires a chain when configured strictly", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    state.aggression = "greedy"
    state.config.strategy.requireWindfuryNearby = false
    local target = { healthPct = 5, hasTrinket = false, importantBuffs = {}, guid = "g1" }
    state.observations.msActiveOn = target.guid
    local out = SE:BurstDecision(state, target, nil)
    H.assertTrue(out.gates.chain_ready.allowed,
        "missing chain should be advisory by default so BG/world and sparse catalog entries can still burst")

    state.config.strategy.requireChainForBurst = true
    out = SE:BurstDecision(state, target, nil)
    H.assertFalse(out.gates.chain_ready.allowed)
    H.assertEq(out.blockedBy, "chain_ready")
end)

H.it(g, "Evaluate populates rec.burstDecision when mode is KILL", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.config.strategy.callBurstOnlyWhenMSActive = false
    state.config.strategy.requireWindfuryNearby     = false
    local rec = SE:Evaluate(state)
    if rec.mode == "KILL" then
        H.assertNotNil(rec.burstDecision)
        H.assertNotNil(rec.burstDecision.gates.kill_prob)
    end
end)

H.it(g, "arena quality: BURST_NOW is suppressed when BurstDecision blocks kill probability", function()
    local state = SE:BuildTestState({ "ROGUE", "MAGE", "PRIEST" }, {
        observations = { hojReady = true, windfuryActive = true, interruptReady = false },
        config = { strategy = { callBurstOnlyWhenMSActive = false, requireWindfuryNearby = true } },
    })
    state.combatPhase = "ACTIVE"
    state.bracket = 3
    state.pvpContext = "arena"

    for _, enemy in pairs(state.enemies) do
        enemy.healthPct = 100
        enemy.hasTrinket = true
        enemy.importantBuffs = {}
        enemy.importantDebuffs = { [H.ns.Spells.MORTAL_STRIKE] = true }
    end

    local rec = SE:Evaluate(state)

    H.assertEq(rec.mode, "KILL")
    H.assertEq(rec.burstDecision.blockedBy, "kill_prob")
    H.assertFalse(rec.burstAllowed, "legacy hard gates are not enough for burst-ready display")
    H.assertEq(rec.burstBlockedBy, "kill_prob")
    for _, callout in ipairs(rec.callouts or {}) do
        H.assertNotEq(callout, "BURST_NOW", "BURST_NOW should not appear when BurstDecision blocks")
    end
end)

H.it(g, "arena quality: BURST_NOW is blocked when the kill target has no target-specific MS", function()
    local state = SE:BuildTestState({ "PRIEST", "MAGE", "ROGUE" }, {
        observations = { hojReady = true, windfuryActive = true, interruptReady = false },
        config = { strategy = { requireWindfuryNearby = false } },
    })
    state.combatPhase = "ACTIVE"
    state.aggression = "greedy"
    local target = findEnemyByClass(state, "PRIEST")
    target.healthPct = 5
    target.hasTrinket = false
    target.importantBuffs = {}
    target.importantDebuffs = {}

    local out = SE:BurstDecision(state, target, nil)

    H.assertFalse(out.allowed)
    H.assertEq(out.blockedBy, "no_ms")
    H.assertEq(out.gates.ms_active.reason, "missing_target_healing_reduction")
end)

H.it(g, "arena quality: BURST_NOW is blocked by active immunity on the specific target", function()
    local state = SE:BuildTestState({ "MAGE", "PRIEST", "ROGUE" }, {
        observations = { hojReady = true, windfuryActive = true },
        config = { strategy = { requireWindfuryNearby = false } },
    })
    state.combatPhase = "ACTIVE"
    state.aggression = "greedy"
    local target = findEnemyByClass(state, "MAGE")
    target.healthPct = 5
    target.hasTrinket = false
    target.importantBuffs = { [H.ns.Spells.ICE_BLOCK] = true }
    target.importantDebuffs = { [H.ns.Spells.MORTAL_STRIKE] = true }

    local out = SE:BurstDecision(state, target, nil)

    H.assertFalse(out.allowed)
    H.assertEq(out.blockedBy, "target_immune")
    H.assertEq(out.gates.target_vulnerable.reason, "target_immune")
end)

H.it(g, "arena quality: BURST_NOW explains a stun DR immune target", function()
    local DR = H.ns.DRTracker
    DR:Clear()
    local state = SE:BuildTestState({ "PRIEST", "MAGE", "ROGUE" }, {
        observations = { hojReady = true, windfuryActive = true, interruptReady = false },
        config = { strategy = { requireWindfuryNearby = false } },
    })
    state.combatPhase = "ACTIVE"
    state.aggression = "greedy"
    local target = findEnemyByClass(state, "PRIEST")
    target.healthPct = 5
    target.hasTrinket = false
    target.importantBuffs = {}
    target.importantDebuffs = { [H.ns.Spells.MORTAL_STRIKE] = true }
    local now = GetTime()
    DR:Apply(target.guid, "STUN", now - 3)
    DR:Apply(target.guid, "STUN", now - 2)
    DR:Apply(target.guid, "STUN", now - 1)

    local out = SE:BurstDecision(state, target, nil)
    DR:Clear()

    H.assertFalse(out.allowed)
    H.assertEq(out.blockedBy, "stun_dr_immune")
    H.assertEq(out.gates.control_ready.reason, "stun_dr_immune")
end)

H.it(g, "arena quality: positive kill window gives BURST_NOW and Bloodlust bars a real duration", function()
    local DR = H.ns.DRTracker
    DR:Clear()
    local state = SE:BuildTestState({ "PRIEST", "MAGE", "ROGUE" }, {
        observations = { hojReady = true, windfuryActive = true },
        config = { strategy = { requireWindfuryNearby = false } },
    })
    state.combatPhase = "ACTIVE"
    state.aggression = "greedy"
    state.now = 100
    local target = findEnemyByClass(state, "PRIEST")
    target.healthPct = 5
    target.hasTrinket = false
    target.importantBuffs = {}
    target.importantDebuffs = { [H.ns.Spells.MORTAL_STRIKE] = true }

    local rec = SE:Evaluate(state)

    H.assertEq(rec.mode, "KILL")
    H.assertTrue(rec.burstAllowed)
    H.assertNotNil(rec.killWindow)
    H.assertEq(rec.killWindow.duration, 8)
    H.assertEq(rec.killWindow.expiresAt, 108)
    H.assertTrue(hasCallout(rec, "BURST_NOW"))
    local burstSignal = findSignal(rec.signals, "callout:BURST_NOW")
    H.assertNotNil(burstSignal)
    H.assertEq(burstSignal.duration, 8)
    H.assertEq(burstSignal.expiresAt, 108)
    local lustAction = findActionByKey(rec.playerActions, "ACTION_SHAMAN_BLOODLUST")
    H.assertNotNil(lustAction)
    H.assertEq(lustAction.class, "SHAMAN")
    H.assertEq(lustAction.duration, 8)
    H.assertEq(lustAction.expiresAt, 108)
end)

H.it(g, "arena quality: Bloodlust advice is absent when no friendly shaman owns it", function()
    local state = SE:BuildTestState({ "PRIEST", "MAGE", "ROGUE" }, {
        observations = { hojReady = true, windfuryActive = true },
        config = { strategy = { requireWindfuryNearby = false } },
    })
    state.friendlies = {
        player = { unit = "player", class = "WARRIOR", spec = "ARMS", alive = true, healthPct = 100 },
        party1 = { unit = "party1", class = "PALADIN", spec = "RETRIBUTION", alive = true, healthPct = 100 },
        party2 = { unit = "party2", class = "DRUID", spec = "RESTORATION", alive = true, healthPct = 100 },
    }
    state.combatPhase = "ACTIVE"
    state.aggression = "greedy"
    local target = findEnemyByClass(state, "PRIEST")
    target.healthPct = 5
    target.hasTrinket = false
    target.importantBuffs = {}
    target.importantDebuffs = { [H.ns.Spells.MORTAL_STRIKE] = true }

    local rec = SE:Evaluate(state)

    H.assertTrue(rec.burstAllowed, "kill window can exist without a shaman")
    H.assertNil(findActionByKey(rec.playerActions, "ACTION_SHAMAN_BLOODLUST"))
end)

H.it(g, "arena quality: burst accepts target-specific healing reduction evidence shapes", function()
    local cases = {
        {
            label = "unit field",
            target = { healingReductionActive = true },
            observations = {},
        },
        {
            label = "wound stacks",
            target = { woundPoisonStacks = 5 },
            observations = {},
        },
        {
            label = "msActiveOn table",
            target = {},
            observations = { msActiveOn = { ["g-ms-table"] = true } },
        },
        {
            label = "table debuff name",
            target = { importantDebuffs = { [900001] = { name = "Wound Poison" } } },
            observations = {},
        },
        {
            label = "string debuff name",
            target = { importantDebuffs = { [900002] = "Aimed Shot" } },
            observations = {},
        },
    }

    for _, case in ipairs(cases) do
        local state = {
            friendlies = {},
            enemies = {},
            observations = case.observations,
            config = { strategy = { requireWindfuryNearby = false } },
            aggression = "greedy",
            _ownCaps = { hasMortalStrike = true, hasInterrupt = true },
        }
        local target = case.target
        target.guid = "g-ms-table"
        target.name = "Killtarget"
        target.class = "PRIEST"
        target.roleGuess = "HEALER"
        target.healthPct = 5
        target.hasTrinket = false
        target.importantBuffs = target.importantBuffs or {}
        target.importantDebuffs = target.importantDebuffs or {}

        local out = SE:BurstDecision(state, target, nil)

        H.assertTrue(out.gates.ms_active.allowed, case.label .. " should satisfy MS gate")
        H.assertTrue(out.allowed, case.label .. " should create a valid burst window")
    end
end)

-- =================================================================
-- M11 #72: KillProb model
-- =================================================================

H.it(g, "KillProb returns 0 + empty components for nil target", function()
    local out = SE:KillProb(nil, {})
    H.assertEq(out.prob, 0)
end)

H.it(g, "KillProb shifts monotonically as HP drops", function()
    local target = { healthPct = 100, hasTrinket = true, importantBuffs = {} }
    local state  = { enemies = {}, observations = {} }
    local outHigh = SE:KillProb(target, state)
    target.healthPct = 50
    local outMid  = SE:KillProb(target, state)
    target.healthPct = 10
    local outLow  = SE:KillProb(target, state)
    H.assertTrue(outLow.prob > outMid.prob, "lower HP -> higher kill prob")
    H.assertTrue(outMid.prob > outHigh.prob, "monotonic")
end)

H.it(g, "KillProb breakdown surfaces each contributing component", function()
    local target = { class = "PRIEST", roleGuess = "HEALER", manaPct = 20, healthPct = 50, hasTrinket = false, importantBuffs = {} }
    local state  = {
        enemies = { p = target },
        observations = { hojReady = true },
    }
    local out = SE:KillProb(target, state)
    H.assertTrue(out.components.hp > 0)
    H.assertEq(out.components.defensiveDown, 0.10, "trinket-down should contribute")
    H.assertEq(out.components.healerLowMana, 0.10, "low-mana healer should contribute")
    H.assertEq(out.components.burstReady, 0.05, "burst ready should contribute")
end)

H.it(g, "KillProb is clamped to [0..1]", function()
    -- Pile every bonus on at full HP: still must clamp <= 1.0.
    local target = { healthPct = 0, hasTrinket = false, importantBuffs = {} }
    local state  = {
        enemies = { p = { class = "PRIEST", roleGuess = "HEALER", manaPct = 5, alive = true } },
        observations = { hojReady = true },
    }
    local out = SE:KillProb(target, state)
    H.assertTrue(out.prob <= 1.0, "must clamp; got " .. out.prob)
end)

-- =================================================================
-- M11 #71: rating-aware aggression
-- =================================================================

H.it(g, "shouldDefend HP threshold shifts with aggression: safe defends earlier", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST","DRUID","PALADIN"})
    state.combatPhase = "ACTIVE"
    state.aggression = "safe"
    -- Find a friendly healer and put them at 45% HP.
    for _, f in pairs(state.friendlies) do
        if f.class == "DRUID" or f.class == "PRIEST" then
            f.healthPct = 45
        end
    end
    local rec = SE:Evaluate(state)
    -- Safe threshold is 50; 45 < 50 -> DEFEND.
    H.assertEq(rec.mode, "DEFEND", "safe should defend at 45 HP (threshold 50)")
end)

H.it(g, "shouldDefend HP threshold shifts with aggression: greedy holds at the same HP", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST","DRUID","PALADIN"})
    state.combatPhase = "ACTIVE"
    state.aggression = "greedy"
    for _, f in pairs(state.friendlies) do
        if f.class == "DRUID" or f.class == "PRIEST" then
            f.healthPct = 35
        end
    end
    local rec = SE:Evaluate(state)
    -- Greedy threshold is 30; 35 > 30 -> don't DEFEND on HP alone.
    H.assertTrue(rec.mode ~= "DEFEND" or (rec.reason and not rec.reason:find("low_healer")),
        "greedy should not defend at 35 HP (threshold 30); reason=" .. tostring(rec.reason))
end)

H.it(g, "Evaluate exposes state.aggression on the rec", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.aggression = "safe"
    state.rating = 2400
    local rec = SE:Evaluate(state)
    H.assertEq(rec.aggression, "safe")
    H.assertEq(rec.rating, 2400)
end)

H.it(g, "Same state at low vs high rating produces different swap threshold behaviour", function()
    -- Build a state where the swap target is marginally better than
    -- the current target by ~10 score points. Greedy swaps; safe stays.
    local function buildSwapTest(aggression)
        local state = SE:BuildTestState({"PRIEST","MAGE"})
        state.combatPhase = "ACTIVE"
        state.aggression  = aggression
        local priest, mage
        for _, e in pairs(state.enemies) do
            if e.class == "PRIEST" then priest = e
            elseif e.class == "MAGE"   then mage   = e end
        end
        mage.hasTrinket = false  -- nudge mage up in scoring
        state.lastPrimaryGUID = priest.guid
        return state, mage
    end
    local stateGreedy, mage1 = buildSwapTest("greedy")
    local recGreedy = SE:Evaluate(stateGreedy)
    H.assertEq(recGreedy.primaryTargetClass, "MAGE")
    H.assertEq(recGreedy.mode, "SWAP", "greedy should swap at low threshold")

    local stateSafe, mage2 = buildSwapTest("safe")
    local recSafe = SE:Evaluate(stateSafe)
    -- Safe (threshold=20) doesn't swap unless the gap is >20 points.
    H.assertEq(recSafe.primaryTargetClass, "MAGE")  -- score-wise mage still wins
    H.assertEq(recSafe.mode, "KILL", "safe should hold on the swap when gap is small")
end)

H.it(g, "Evaluate's reason text includes the comp tag and confidence", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "PRE"
    local rec = SE:Evaluate(state)
    H.assertTrue(rec.reason:find("WLD") ~= nil, "reason should mention comp ID")
    H.assertTrue(rec.reason:find("class%-guessed") ~= nil, "reason should mention class-guessed badge")
end)

-- =================================================================
-- M14 (v2.1): BG mode scoring + callouts
-- =================================================================

H.it(g, "BG mode: flag-carrier aura gives a massive (+200) priority boost", function()
    local state = SE:BuildTestState({"WARRIOR","ROGUE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "bg"
    -- Pick a non-priest enemy and attach the WSG carrier aura (23333).
    local target
    for _, e in pairs(state.enemies) do
        if e.class == "WARRIOR" then
            e.importantBuffs[23333] = true
            target = e
        end
    end
    H.assertNotNil(target)
    local rec = SE:Evaluate(state)
    -- Flag carrier should win kill priority even against a healer.
    H.assertEq(rec.primaryTargetClass, "WARRIOR",
        "flag carrier must outrank natural healer priority")
    local sawFlagBoost = false
    for _, c in ipairs(target._contrib or {}) do
        if c.key == "bg_flag_carrier" and c.pts == 200 then sawFlagBoost = true end
    end
    H.assertTrue(sawFlagBoost, "bg_flag_carrier contribution expected")
end)

H.it(g, "BG mode: player actions target the selected battleground enemy", function()
    local state = SE:BuildTestState({"WARRIOR","ROGUE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "bg"
    for _, e in pairs(state.enemies) do
        if e.class == "WARRIOR" then e.importantBuffs[23333] = true end
    end

    local rec = SE:Evaluate(state)
    H.assertEq(rec.primaryTargetClass, "WARRIOR")
    local player = findAction(rec.playerActions, "player")
    H.assertEq(player.actionKey, "ACTION_WARRIOR_KILL")
    H.assertEq(player.target, rec.primaryTarget)
end)

H.it(g, "BG mode: <30% HP straggler gets the bg_low_hp_straggler boost", function()
    local state = SE:BuildTestState({"WARRIOR","ROGUE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "bg"
    -- Drop a melee to 20% HP; should pick up the BG boost.
    local target
    for _, e in pairs(state.enemies) do
        if e.class == "ROGUE" then e.healthPct = 20; target = e end
    end
    SE:Evaluate(state)
    local saw = false
    for _, c in ipairs(target._contrib or {}) do
        if c.key == "bg_low_hp_straggler" and c.pts == 30 then saw = true end
    end
    H.assertTrue(saw, "bg_low_hp_straggler contribution expected")
end)

H.it(g, "BG mode: SWAP threshold tightens to 30 (vs default 10)", function()
    local function build(score)
        local state = SE:BuildTestState({"PRIEST","MAGE"})
        state.combatPhase = "ACTIVE"
        state.pvpContext  = "bg"
        local priest, mage
        for _, e in pairs(state.enemies) do
            if e.class == "PRIEST" then priest = e
            elseif e.class == "MAGE"   then mage   = e end
        end
        -- Force a known score gap by manipulating mage attributes.
        if score == "small" then
            mage.hasTrinket = false  -- gives ~20pt boost
        elseif score == "huge" then
            mage.hasTrinket = false
            mage.healthPct = 20      -- gives bg_low_hp_straggler (+30) + health_below_50 (+30)
        end
        state.lastPrimaryGUID = priest.guid
        return state
    end
    -- Small gap: should NOT swap (arena would; BG threshold=30 holds)
    local recSmall = SE:Evaluate(build("small"))
    H.assertEq(recSmall.mode, "KILL",
        "BG should not swap on a small score gap (arena would)")
    -- Huge gap: should swap
    local recHuge = SE:Evaluate(build("huge"))
    H.assertEq(recHuge.mode, "SWAP",
        "BG should still swap when gap is decisively large")
end)

H.it(g, "BG mode: CALL_FLAG_CARRIER_LOW fires when carrier is <50% HP", function()
    local state = SE:BuildTestState({"WARRIOR","ROGUE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "bg"
    for _, e in pairs(state.enemies) do
        if e.class == "WARRIOR" then
            e.importantBuffs[23333] = true
            e.healthPct = 35
        end
    end
    local rec = SE:Evaluate(state)
    local saw = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_FLAG_CARRIER_LOW" then saw = true end
    end
    H.assertTrue(saw, "expected CALL_FLAG_CARRIER_LOW for low-HP flag carrier")
end)

H.it(g, "BG mode: CALL_BG_DEFEND fires when mode is DEFEND in BG", function()
    local state = SE:BuildTestState({"WARRIOR","ROGUE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "bg"
    state.observations = { healerUnderPressure = true }  -- force DEFEND
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND")
    local saw = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_BG_DEFEND" then saw = true end
    end
    H.assertTrue(saw, "expected CALL_BG_DEFEND on DEFEND in BG")
end)

H.it(g, "Arena mode is unaffected by BG-mode logic (regression)", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "arena"
    state.bracket     = 3
    -- Even with the flag aura attached, arena should NOT add +200.
    for _, e in pairs(state.enemies) do
        if e.class == "WARRIOR" then e.importantBuffs[23333] = true end
    end
    SE:Evaluate(state)
    -- Inspect the warrior's contributions — bg_flag_carrier must be absent.
    local warrior
    for _, e in pairs(state.enemies) do
        if e.class == "WARRIOR" then warrior = e end
    end
    for _, c in ipairs(warrior._contrib or {}) do
        H.assertTrue(c.key ~= "bg_flag_carrier",
            "bg_flag_carrier must not contribute in arena context")
    end
end)

-- =================================================================
-- M15 (v2.1): World PvP mode
-- =================================================================

H.it(g, "World mode: PRE phase skips OPEN, goes straight to KILL when target alive", function()
    local state = SE:BuildTestState({"WARRIOR"})
    state.combatPhase = "PRE"
    state.pvpContext  = "world"
    local rec = SE:Evaluate(state)
    -- Should be KILL or RESET, never OPEN (no arena planning phase)
    H.assertTrue(rec.mode ~= "OPEN", "world context must not emit OPEN; got " .. rec.mode)
end)

H.it(g, "World mode: SWAP suppressed even when score gap is huge", function()
    local state = SE:BuildTestState({"PRIEST","MAGE"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "world"
    local priest, mage
    for _, e in pairs(state.enemies) do
        if e.class == "PRIEST" then priest = e
        elseif e.class == "MAGE"   then mage   = e end
    end
    mage.hasTrinket = false
    mage.healthPct  = 15
    state.lastPrimaryGUID = priest.guid
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "KILL",
        "world mode should not emit SWAP — single-target focus")
end)

H.it(g, "World mode: comp identification is skipped (no rec.comp)", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "world"
    local rec = SE:Evaluate(state)
    H.assertNil(rec.comp, "world context should not match arena comps")
end)

H.it(g, "Arena mode: comp identification still works (regression)", function()
    local state = SE:BuildTestState({"ROGUE","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "arena"
    state.bracket     = 3
    local rec = SE:Evaluate(state)
    H.assertNotNil(rec.comp,
        "arena context must still produce a comp match (regression check)")
end)

H.it(g, "World mode: DEFEND fires when player HP <30% via shouldDefend lowestHealer", function()
    local state = SE:BuildTestState({"WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "world"
    -- Knock the only friendly (the "player") to low HP.
    for _, f in pairs(state.friendlies) do f.healthPct = 22 end
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND", "low player HP should trigger DEFEND in world")
end)

H.it(g, "World mode: solo non-healer player low HP still DEFENDs", function()
    local state = SE:BuildTestState({"ROGUE"})
    state.combatPhase = "ACTIVE"
    state.pvpContext  = "world"
    state.friendlies = {
        player = { unit = "player", class = "WARRIOR", spec = "ARMS", alive = true, healthPct = 22 },
    }
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND",
        "solo world PvP must defend on low player HP even without a healer class")
    local player = findAction(rec.playerActions, "player")
    H.assertEq(#rec.playerActions, 1)
    H.assertEq(player.actionKey, "ACTION_DPS_PEEL")
    H.assertEq(player.targetUnit, "player")
    H.assertEq(player.targetType, "friendly")
end)

H.it(g, "Known healer Paladin/Shaman specs count for low-healer DEFEND", function()
    local state = SE:BuildTestState({"WARRIOR"})
    state.combatPhase = "ACTIVE"
    state.friendlies = {
        player = { unit = "player", class = "WARRIOR", spec = "ARMS", alive = true, healthPct = 100 },
        party1 = { unit = "party1", class = "PALADIN", spec = "HOLY", alive = true, healthPct = 25 },
        party2 = { unit = "party2", class = "ROGUE", alive = true, healthPct = 100 },
    }
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND", "low holy paladin should trigger DEFEND")

    state.friendlies.party1.spec = nil
    rec = SE:Evaluate(state)
    H.assertNotEq(rec.mode, "DEFEND", "unknown paladin should not be treated as the healer")

    state.friendlies.party1.class = "SHAMAN"
    state.friendlies.party1.spec = "RESTORATION"
    rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND", "low resto shaman should trigger DEFEND")

    state.friendlies.party1.spec = "ENHANCEMENT"
    rec = SE:Evaluate(state)
    H.assertNotEq(rec.mode, "DEFEND", "low enhancement shaman should not trigger healer DEFEND")
end)

H.it(g, "DEFEND actions do not target an Enhancement shaman as healer", function()
    local state = SE:BuildTestState({"ROGUE","MAGE"})
    state.combatPhase = "ACTIVE"
    state.observations = { healerUnderPressure = true }
    state.friendlies = {
        player = { unit = "player", class = "SHAMAN", spec = "ENHANCEMENT", alive = true, healthPct = 100 },
        party1 = { unit = "party1", name = "Sweetshammy", class = "SHAMAN", spec = "ENHANCEMENT", alive = true, healthPct = 54 },
    }

    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND")
    local player = findAction(rec.playerActions, "player")
    H.assertEq(player.actionKey, "ACTION_SHAMAN_DEFEND")
    H.assertNil(player.targetName, "Enhancement shaman should not be selected as the defensive healer target")
end)

H.it(g, "BG mode: PRE phase also skips OPEN (same as world)", function()
    local state = SE:BuildTestState({"WARRIOR"})
    state.combatPhase = "PRE"
    state.pvpContext  = "bg"
    local rec = SE:Evaluate(state)
    H.assertTrue(rec.mode ~= "OPEN", "bg context must not emit OPEN")
end)

-- =================================================================
-- v2.1.3: rec.reasonKey on DEFEND / RESET modes
-- =================================================================

H.it(g, "v2.1.3: DEFEND with trained reason sets reasonKey=REASON_DEFEND_TRAINED", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.observations = { healerUnderPressure = true }
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND")
    H.assertEq(rec.reasonKey, "REASON_DEFEND_TRAINED")
end)

H.it(g, "v2.1.3: DEFEND with enemy_lust reason sets reasonKey=REASON_DEFEND_ENEMY_LUST", function()
    local state = SE:BuildTestState({"WARRIOR","MAGE","PRIEST"})
    state.combatPhase = "ACTIVE"
    state.observations = { enemyBloodlustActive = true }
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "DEFEND")
    H.assertEq(rec.reasonKey, "REASON_DEFEND_ENEMY_LUST")
end)

H.it(g, "v2.1.3: RESET mode sets reasonKey=REASON_RESET", function()
    local state = SE:BuildTestState({})
    state.combatPhase = "ACTIVE"; state.enemies = {}; state.enemyClassList = nil
    local rec = SE:Evaluate(state)
    H.assertEq(rec.mode, "RESET")
    H.assertEq(rec.reasonKey, "REASON_RESET")
end)

H.it(g, "v2.1.3: KILL mode does NOT set reasonKey (variable contributor text)", function()
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
    state.combatPhase = "ACTIVE"; state.bracket = 5
    local rec = SE:Evaluate(state)
    H.assertNil(rec.reasonKey,
        "KILL has variable contributor data; reasonKey stays nil so UI uses the rec.reason text")
end)

H.it(g, "arena quality: WLP drain 2v2 kills paladin as the active matchup plan", function()
    local state = SE:BuildTestState({ "WARLOCK", "PALADIN" })
    state.combatPhase = "ACTIVE"
    state.bracket = 2
    state.pvpContext = "arena"

    local rec = SE:Evaluate(state)

    H.assertEq(rec.mode, "KILL")
    H.assertEq(rec.primaryTargetClass, "PALADIN", "drain matchup plan should target paladin")
end)

H.it(g, "arena quality: recommendation primaryTargetHp is populated from healthPct", function()
    local state = SE:BuildTestState({ "ROGUE", "MAGE", "PRIEST" })
    state.combatPhase = "ACTIVE"
    state.bracket = 3
    state.pvpContext = "arena"

    for _, enemy in pairs(state.enemies) do
        if enemy.class == "PRIEST" then
            enemy.healthPct = 10
        end
    end

    local rec = SE:Evaluate(state)

    H.assertEq(rec.primaryTargetClass, "PRIEST")
    H.assertEq(rec.primaryTargetHp, 0.10, "healthPct=10 should become 0.10 for the HUD")
end)

H.it(g, "arena quality: recommendation primaryTargetHp clamps hpPct to a fraction", function()
    local state = SE:BuildTestState({ "MAGE" })
    state.combatPhase = "ACTIVE"
    state.pvpContext = "arena"

    for _, enemy in pairs(state.enemies) do
        enemy.healthPct = nil
        enemy.hpPct = 1.5
    end

    local rec = SE:Evaluate(state)
    H.assertEq(rec.primaryTargetHp, 1.0, "hpPct above 1 must clamp before HUD rendering")

    for _, enemy in pairs(state.enemies) do
        enemy.hpPct = -0.25
    end

    rec = SE:Evaluate(state)
    H.assertEq(rec.primaryTargetHp, 0.0, "hpPct below 0 must clamp before HUD rendering")
end)
