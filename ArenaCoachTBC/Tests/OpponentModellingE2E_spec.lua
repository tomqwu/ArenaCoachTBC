-- Tests/OpponentModellingE2E_spec.lua (M9 #66, closes M9)
--
-- End-to-end opponent-modelling tests. Drive 20 synthetic openings
-- against a team that *always* trinkets Fear, observe the engine learn
-- the tendency, and assert the profile-driven callout
-- (CALL_SAVE_TREMOR_HOJ) appears in rec.callouts after the sample
-- threshold. Re-run with a renamed team (different signature, same
-- behaviour) and assert the engine converges to the same callout —
-- profiles are per-team, no name-bleed across teams.

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
H.load("StrategyEngine.lua")

local SE  = H.ns.StrategyEngine
local OP  = H.ns.OpponentProfile

local g = H.describe("OpponentModellingE2E")

-- Helper: build a state with a 3v3 enemy team of given (class, name)
-- triples. Caller can mutate state.opponentProfile later.
local function buildEnemies(triples)
    local enemies = {}
    for i, t in ipairs(triples) do
        local key = "arena" .. i
        enemies[key] = {
            unit       = key,
            guid       = "g-" .. t[1] .. "-" .. t[2],
            class      = t[1],
            name       = t[2],
            alive      = true,
            healthPct  = 100,
            importantBuffs = {},
            observedSpells = {},
        }
    end
    return enemies
end

-- Run one "opening" against `team`: looks up the signature, marks one
-- observed=true on `tendency`, builds the full state shape, and calls
-- Evaluate. Returns the resulting rec.
local function runOpening(team, db, tendency)
    local sig = OP:Signature(team)
    OP:Update(sig, { tendency = tendency, observed = true }, db)
    local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})  -- friendly comp
    state.combatPhase    = "ACTIVE"
    state.enemies        = team
    state.opponentSignature = sig
    state.opponentProfile = OP:Get(sig, db)
    return SE:Evaluate(state), sig
end

H.it(g, "engine emits CALL_SAVE_TREMOR_HOJ after 20 trinket-fear openings", function()
    local db = { profiles = {} }
    local team = buildEnemies({
        { "ROGUE",  "Alpha"   },
        { "MAGE",   "Bravo"   },
        { "PRIEST", "Charlie" },
    })

    -- First few evaluations should NOT have the profile callout
    -- (n < MIN_SAMPLES_FOR_OPINION = 5).
    local rec = runOpening(team, db, "trinketsFear")
    local sawEarly = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_SAVE_TREMOR_HOJ" then sawEarly = true; break end
    end
    H.assertFalse(sawEarly, "should not emit profile callout after 1 observation")

    -- After 20 positive observations, the callout should fire.
    for _ = 1, 20 do rec = runOpening(team, db, "trinketsFear") end
    local sawLate = false
    for _, c in ipairs(rec.callouts or {}) do
        if c == "CALL_SAVE_TREMOR_HOJ" then sawLate = true; break end
    end
    H.assertTrue(sawLate, "expected CALL_SAVE_TREMOR_HOJ after 21 observations")
    H.assertTrue(rec.profileContrib ~= nil and rec.profileContrib:find("trinketsFear") ~= nil)
end)

H.it(g, "callouts diverge from comp-default once threshold is met", function()
    -- Compare: same comp + same friendly side, but team A has been
    -- observed trinketing-fear 20 times; team B is fresh. Team A's
    -- callouts should include the profile callout; team B's should not.
    local db = { profiles = {} }
    local teamA = buildEnemies({
        { "ROGUE",  "Alpha"   },
        { "MAGE",   "Bravo"   },
        { "PRIEST", "Charlie" },
    })
    local teamB = buildEnemies({
        { "ROGUE",  "Delta"   },
        { "MAGE",   "Echo"    },
        { "PRIEST", "Foxtrot" },
    })

    for _ = 1, 20 do runOpening(teamA, db, "trinketsFear") end
    local recA = runOpening(teamA, db, "trinketsFear")
    local recB
    do
        -- Evaluate teamB without training: profile starts fresh.
        local sigB = OP:Signature(teamB)
        local state = SE:BuildTestState({"WARLOCK","DRUID","WARRIOR"})
        state.combatPhase = "ACTIVE"
        state.enemies = teamB
        state.opponentSignature = sigB
        state.opponentProfile = OP:Get(sigB, db)
        recB = SE:Evaluate(state)
    end

    local hasACall = false
    for _, c in ipairs(recA.callouts or {}) do
        if c == "CALL_SAVE_TREMOR_HOJ" then hasACall = true end
    end
    local hasBCall = false
    for _, c in ipairs(recB.callouts or {}) do
        if c == "CALL_SAVE_TREMOR_HOJ" then hasBCall = true end
    end
    H.assertTrue(hasACall,  "trained team A should fire CALL_SAVE_TREMOR_HOJ")
    H.assertFalse(hasBCall, "untrained team B should not fire CALL_SAVE_TREMOR_HOJ")
end)

H.it(g, "profile sanitisation: renaming the team converges to the same callout", function()
    -- Same comp, different names => different signature => independent
    -- profile. Training BOTH teams to the same tendency converges to
    -- the same callout. This is the "keyed correctly" assertion from
    -- the issue: the comp + observed behaviour, not the names,
    -- determines the recommendation.
    local db = { profiles = {} }
    local teamA = buildEnemies({
        { "ROGUE",  "Alpha"   },
        { "MAGE",   "Bravo"   },
        { "PRIEST", "Charlie" },
    })
    local teamB = buildEnemies({
        { "ROGUE",  "Delta"   },
        { "MAGE",   "Echo"    },
        { "PRIEST", "Foxtrot" },
    })

    -- Train both teams the same way (20 observed trinkets).
    for _ = 1, 20 do runOpening(teamA, db, "trinketsFear") end
    for _ = 1, 20 do runOpening(teamB, db, "trinketsFear") end

    local recA = runOpening(teamA, db, "trinketsFear")
    local recB = runOpening(teamB, db, "trinketsFear")

    local function hasCallout(rec, want)
        for _, c in ipairs(rec.callouts or {}) do
            if c == want then return true end
        end
        return false
    end
    H.assertTrue(hasCallout(recA, "CALL_SAVE_TREMOR_HOJ"))
    H.assertTrue(hasCallout(recB, "CALL_SAVE_TREMOR_HOJ"))

    -- The two signatures must differ (no name-bleed):
    H.assertTrue(recA.opponentSignature ~= recB.opponentSignature)

    -- The persistent store should hold exactly two profiles, one per team.
    local count = 0
    for _ in pairs(db.profiles) do count = count + 1 end
    H.assertEq(count, 2)

    -- And no raw name string appears anywhere in the store.
    for k, p in pairs(db.profiles) do
        for _, nm in ipairs({"Alpha","Bravo","Charlie","Delta","Echo","Foxtrot"}) do
            H.assertTrue(not k:find(nm, 1, true), "name leaked into signature key: " .. k)
            for tk, rec in pairs(p.tendencies or {}) do
                for _, v in pairs(rec) do
                    H.assertEq(type(v), "number",
                        "tendency " .. tk .. " field has non-number type")
                end
            end
        end
    end
end)

H.it(g, "match-by-match convergence: callout appears the first time at n>=5", function()
    local db = { profiles = {} }
    local team = buildEnemies({
        { "ROGUE",  "Alpha"   },
        { "MAGE",   "Bravo"   },
        { "PRIEST", "Charlie" },
    })
    local firstAppearance = nil
    for i = 1, 10 do
        local rec = runOpening(team, db, "trinketsFear")
        for _, c in ipairs(rec.callouts or {}) do
            if c == "CALL_SAVE_TREMOR_HOJ" and not firstAppearance then
                firstAppearance = i
            end
        end
    end
    H.assertNotNil(firstAppearance, "callout should appear within 10 observations")
    H.assertTrue(firstAppearance >= 5,
        "callout should not appear before MIN_SAMPLES_FOR_OPINION; first at " .. firstAppearance)
end)
