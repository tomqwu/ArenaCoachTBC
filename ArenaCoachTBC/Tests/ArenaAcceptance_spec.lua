-- Tests/ArenaAcceptance_spec.lua
--
-- Arena-shaped strategy acceptance fixtures. These are intentionally more
-- concrete than unit tests: exact rosters, PvP context, expected personal
-- actions, and advice that must never appear.

local H = _G.__ACC_TEST_HELPERS

H.load("Locales/enUS.lua")
H.load("Data/Spells.lua")
H.load("Data/Classes.lua")
H.load("Data/OwnComps.lua")
H.load("Data/Strategies.lua")
H.load("Data/SpellSpecHints.lua")
H.load("DRTracker.lua")
H.load("CooldownTracker.lua")
H.load("Chain.lua")
H.load("OpponentProfile.lua")
H.load("Lookahead.lua")
H.load("Patterns.lua")
H.load("StrategyEngine.lua")

local SE = H.ns.StrategyEngine
local fixtures = dofile(H.ADDON_DIR .. "/Tests/Fixtures/arena_acceptance.lua")
local g = H.describe("ArenaAcceptance")

local function copyTable(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do out[k] = copyTable(v) end
    return out
end

local function mergeInto(dst, src)
    for k, v in pairs(src or {}) do
        if type(v) == "table" and type(dst[k]) == "table" then
            mergeInto(dst[k], v)
        else
            dst[k] = copyTable(v)
        end
    end
end

local function keyedUnits(list)
    local out = {}
    local function add(key, unit)
        local copy = copyTable(unit)
        copy.unit = copy.unit or tostring(key)
        copy.guid = copy.guid or copy.unit
        copy.alive = copy.alive ~= false
        copy.importantBuffs = copy.importantBuffs or {}
        copy.importantDebuffs = copy.importantDebuffs or {}
        copy.observedSpells = copy.observedSpells or {}
        out[copy.unit] = copy
    end
    for key, unit in pairs(list or {}) do
        if type(unit) == "table" then add(key, unit) end
    end
    return out
end

local function enemyClassList(enemies)
    local keys, out = {}, {}
    for key in pairs(enemies or {}) do table.insert(keys, key) end
    table.sort(keys)
    for _, key in ipairs(keys) do table.insert(out, enemies[key].class) end
    return out
end

local function resolveRefs(value, state)
    if type(value) == "string" and value:sub(1, 1) == "@" then
        local key = value:sub(2)
        local unit = (state.friendlies and state.friendlies[key]) or (state.enemies and state.enemies[key])
        return unit and unit.guid or value
    end
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = resolveRefs(v, state) end
    return out
end

local function buildState(fixture, step)
    local state = {
        friendlies = keyedUnits(fixture.friendlies),
        enemies = keyedUnits(step.enemies or fixture.enemies),
        observations = {},
        combatPhase = step.combatPhase or fixture.combatPhase or "ACTIVE",
        pvpContext = step.pvpContext or fixture.pvpContext or "arena",
        bracket = step.bracket or fixture.bracket,
        config = copyTable(step.config or fixture.config or {
            strategy = {
                callBurstOnlyWhenMSActive = false,
                requireWindfuryNearby = false,
            },
        }),
    }
    if fixture.enemies and step.enemies then
        state.enemies = keyedUnits(fixture.enemies)
        for unit, override in pairs(step.enemies) do
            state.enemies[unit] = state.enemies[unit] or { unit = unit, guid = unit, class = "WARRIOR" }
            mergeInto(state.enemies[unit], override)
        end
    end
    state.enemyClassList = enemyClassList(state.enemies)
    state.observations = resolveRefs(step.observations or fixture.observations or {}, state)
    return state
end

local function findAction(rec, unit)
    for _, action in ipairs((rec and rec.playerActions) or {}) do
        if action.unit == unit then return action end
    end
end

local function hasCallout(rec, key)
    for _, callout in ipairs((rec and rec.callouts) or {}) do
        if callout == key then return true end
    end
    return false
end

local function hasAction(rec, key)
    for _, action in ipairs((rec and rec.playerActions) or {}) do
        if action.actionKey == key then return true end
    end
    return false
end

local function hasRejectedCallout(rec, key, reason)
    for _, item in ipairs((rec and rec.rejectedCallouts) or {}) do
        if item.key == key and item.reason == reason then return true end
    end
    return false
end

local function assertAction(label, action, expected)
    H.assertNotNil(action, label .. " missing action")
    H.assertEq(action.actionKey, expected.actionKey, label .. " action")
    if expected.targetName ~= nil then
        H.assertEq(action.targetName, expected.targetName, label .. " target")
    else
        H.assertNil(action.targetName, label .. " target")
    end
    if expected.targetType then H.assertEq(action.targetType, expected.targetType, label .. " target type") end
end

local function assertStep(fixture, step)
    local state = buildState(fixture, step)
    local rec = SE:Evaluate(state)
    local expect = step.expect or {}
    local label = fixture.id .. "/" .. step.id

    H.assertEq(rec.mode, expect.mode, label .. " mode")
    if expect.noComp then H.assertNil(rec.comp, label .. " comp") end
    if expect.targetClass then H.assertEq(rec.primaryTargetClass, expect.targetClass, label .. " target class") end
    if expect.player then assertAction(label .. "/player", findAction(rec, "player"), expect.player) end
    for unit, actionExpect in pairs(expect.actions or {}) do
        assertAction(label .. "/" .. unit, findAction(rec, unit), actionExpect)
    end
    for _, key in ipairs(expect.callouts or {}) do
        H.assertTrue(hasCallout(rec, key), label .. " missing callout " .. key)
    end
    for _, key in ipairs(expect.forbiddenCallouts or {}) do
        H.assertFalse(hasCallout(rec, key), label .. " forbidden callout " .. key)
    end
    for _, key in ipairs(expect.forbiddenActions or {}) do
        H.assertFalse(hasAction(rec, key), label .. " forbidden action " .. key)
    end
    for key, reason in pairs(expect.rejectedCallouts or {}) do
        H.assertTrue(hasRejectedCallout(rec, key, reason),
            label .. " missing rejected callout " .. key .. ":" .. reason)
    end
    return rec
end

H.it(g, "fixture pack exact player action timeline and forbidden advice", function()
    local rows = {}
    for _, fixture in ipairs(fixtures) do
        for _, step in ipairs(fixture.steps or {}) do
            local rec = assertStep(fixture, step)
            local player = findAction(rec, "player")
            table.insert(rows, fixture.id .. "/" .. step.id .. "="
                .. rec.mode .. ":" .. (player and player.actionKey or "-")
                .. "->" .. tostring(player and player.targetName or "-"))
        end
    end
    H.assertTrue(#rows >= 8, "expected broad arena fixture coverage")
end)

H.it(g, "fixture pack stays inside CI performance budget", function()
    local states = {}
    for _, fixture in ipairs(fixtures) do
        for _, step in ipairs(fixture.steps or {}) do
            table.insert(states, buildState(fixture, step))
        end
    end
    local start = os.clock()
    local iterations = 50
    for _ = 1, iterations do
        for _, state in ipairs(states) do SE:Evaluate(state) end
    end
    local avgMs = ((os.clock() - start) / (iterations * #states)) * 1000
    H.assertTrue(avgMs < 10, string.format("arena fixture avg %.2fms (budget 10ms)", avgMs))
end)
