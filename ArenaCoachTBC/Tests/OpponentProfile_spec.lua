-- Tests/OpponentProfile_spec.lua (M9 #63)
local H = _G.__ACC_TEST_HELPERS
H.load("OpponentProfile.lua")
local OP = H.ns.OpponentProfile

local g = H.describe("OpponentProfile")

local function freshDB() return { profiles = {} } end

H.it(g, "Signature returns nil for empty / nil enemies", function()
    H.assertNil(OP:Signature(nil))
    H.assertNil(OP:Signature({}))
    -- enemies with no class entries also produce nil
    H.assertNil(OP:Signature({ a = { name = "X" } }))
end)

H.it(g, "Signature is deterministic and sorted by class", function()
    local e1 = {
        a = { class = "MAGE",   name = "Alf"   },
        b = { class = "PRIEST", name = "Bea"   },
        c = { class = "ROGUE",  name = "Cal"   },
    }
    local e2 = {
        c = { class = "ROGUE",  name = "Cal"   },  -- different iteration order
        a = { class = "MAGE",   name = "Alf"   },
        b = { class = "PRIEST", name = "Bea"   },
    }
    H.assertEq(OP:Signature(e1), OP:Signature(e2))
    -- Class prefix is sorted: MAGE_PRIEST_ROGUE
    H.assertTrue(OP:Signature(e1):find("^MAGE_PRIEST_ROGUE#") ~= nil,
        "expected sorted-class prefix; got " .. OP:Signature(e1))
end)

H.it(g, "Signature differs when class set differs", function()
    local rmp = { a = { class = "ROGUE",  name = "A" },
                  b = { class = "MAGE",   name = "B" },
                  c = { class = "PRIEST", name = "C" } }
    local wld = { a = { class = "WARRIOR", name = "A" },
                  b = { class = "WARLOCK", name = "B" },
                  c = { class = "DRUID",   name = "C" } }
    H.assertTrue(OP:Signature(rmp) ~= OP:Signature(wld))
end)

H.it(g, "Signature differs when names differ (different teams of same comp)", function()
    local teamA = { a = { class = "ROGUE",  name = "Alpha" },
                    b = { class = "MAGE",   name = "Bravo" },
                    c = { class = "PRIEST", name = "Charlie" } }
    local teamB = { a = { class = "ROGUE",  name = "Delta" },
                    b = { class = "MAGE",   name = "Echo" },
                    c = { class = "PRIEST", name = "Foxtrot" } }
    H.assertTrue(OP:Signature(teamA) ~= OP:Signature(teamB),
        "two different teams of the same comp should have different signatures")
end)

H.it(g, "Signature does NOT contain raw names anywhere in its output", function()
    local enemies = { a = { class = "ROGUE", name = "Backalleybackstabber" } }
    local sig = OP:Signature(enemies)
    H.assertTrue(not sig:find("Backalleybackstabber", 1, true),
        "signature must not embed raw names; got " .. sig)
end)

H.it(g, "Get creates a fresh profile for an unseen signature", function()
    local db = freshDB()
    local p = OP:Get("MAGE_PRIEST_ROGUE#1234", db)
    H.assertNotNil(p)
    H.assertNotNil(p.tendencies.trinketsFear)
    H.assertEq(p.tendencies.trinketsFear.alpha, 1)
    H.assertEq(p.tendencies.trinketsFear.beta, 1)
    H.assertEq(p.tendencies.trinketsFear.observations, 0)
    -- The profile is persisted under db.profiles
    H.assertEq(db.profiles["MAGE_PRIEST_ROGUE#1234"], p)
end)

H.it(g, "Get for a known signature returns the same persisted profile", function()
    local db = freshDB()
    local p1 = OP:Get("X", db)
    p1.tendencies.trinketsFear.alpha = 7  -- mutate
    local p2 = OP:Get("X", db)
    H.assertEq(p2.tendencies.trinketsFear.alpha, 7)
end)

H.it(g, "Get backfills new tendencies for an older persisted profile", function()
    -- Simulate a profile written before kicksFirstHeal was a tracked tendency.
    local db = { profiles = {
        X = { tendencies = { trinketsFear = { alpha = 5, beta = 2, observations = 6 } } },
    } }
    local p = OP:Get("X", db)
    H.assertEq(p.tendencies.trinketsFear.alpha, 5)
    H.assertNotNil(p.tendencies.kicksFirstHeal, "missing tendencies should be backfilled")
    H.assertEq(p.tendencies.kicksFirstHeal.alpha, 1)
end)

H.it(g, "Update bumps alpha when observed=true", function()
    local db = freshDB()
    OP:Update("X", { tendency = "trinketsFear", observed = true }, db)
    local p = OP:Get("X", db)
    H.assertEq(p.tendencies.trinketsFear.alpha, 2)
    H.assertEq(p.tendencies.trinketsFear.beta, 1)
    H.assertEq(p.tendencies.trinketsFear.observations, 1)
end)

H.it(g, "Update bumps beta when observed=false", function()
    local db = freshDB()
    OP:Update("X", { tendency = "trinketsFear", observed = false }, db)
    local p = OP:Get("X", db)
    H.assertEq(p.tendencies.trinketsFear.alpha, 1)
    H.assertEq(p.tendencies.trinketsFear.beta, 2)
    H.assertEq(p.tendencies.trinketsFear.observations, 1)
end)

H.it(g, "Update ignores event without a boolean observed field", function()
    local db = freshDB()
    local r = OP:Update("X", { tendency = "trinketsFear" }, db)
    H.assertNil(r)
end)

H.it(g, "Update ignores unknown tendency keys", function()
    local db = freshDB()
    local r = OP:Update("X", { tendency = "imaginary", observed = true }, db)
    H.assertNil(r)
end)

H.it(g, "Mean returns alpha / (alpha + beta)", function()
    local db = freshDB()
    for _ = 1, 7 do OP:Update("X", { tendency = "trinketsFear", observed = true  }, db) end
    for _ = 1, 3 do OP:Update("X", { tendency = "trinketsFear", observed = false }, db) end
    local p = OP:Get("X", db)
    -- alpha = 1 + 7 = 8, beta = 1 + 3 = 4 -> 8/12 = 0.6667
    H.assertTrue(math.abs(OP:Mean(p, "trinketsFear") - (8 / 12)) < 1e-9)
end)

H.it(g, "Mean defaults to 0.5 for a fresh tendency", function()
    local db = freshDB()
    local p = OP:Get("X", db)
    H.assertEq(OP:Mean(p, "trinketsFear"), 0.5)
end)

H.it(g, "Mean returns 0.5 for unknown tendency", function()
    local db = freshDB()
    H.assertEq(OP:Mean(OP:Get("X", db), "imaginary"), 0.5)
end)

H.it(g, "SampleCount tracks total observations", function()
    local db = freshDB()
    OP:Update("X", { tendency = "trinketsFear", observed = true  }, db)
    OP:Update("X", { tendency = "trinketsFear", observed = false }, db)
    OP:Update("X", { tendency = "trinketsFear", observed = true  }, db)
    local p = OP:Get("X", db)
    H.assertEq(OP:SampleCount(p, "trinketsFear"), 3)
end)

H.it(g, "Forget removes the profile", function()
    local db = freshDB()
    OP:Get("X", db)
    H.assertNotNil(db.profiles.X)
    OP:Forget("X", db)
    H.assertNil(db.profiles.X)
end)

H.it(g, "Forget on unknown signature is a no-op", function()
    local db = freshDB()
    OP:Forget("nonexistent", db)  -- doesn't crash
end)

H.it(g, "persistence: profile written under db.profiles contains no name field", function()
    local db = freshDB()
    local enemies = { a = { class = "ROGUE", name = "Sneaky" },
                      b = { class = "MAGE",  name = "Sparky" } }
    local sig = OP:Signature(enemies)
    OP:Update(sig, { tendency = "trinketsFear", observed = true }, db)
    -- Walk the persistent shape and ensure no name leaked into the
    -- stored profile (only counts + key, where the key is a hash).
    for storedKey, profile in pairs(db.profiles) do
        H.assertTrue(not storedKey:find("Sneaky", 1, true),
            "stored key leaks name: " .. storedKey)
        H.assertTrue(not storedKey:find("Sparky", 1, true),
            "stored key leaks name: " .. storedKey)
        for tname, rec in pairs(profile.tendencies) do
            -- Every field on rec must be a number, not a string carrying a name
            for _, v in pairs(rec) do
                H.assertEq(type(v), "number",
                    "tendency " .. tname .. " field has non-number value type " .. type(v))
            end
        end
    end
end)

H.it(g, "all 4 acceptance-criteria tendencies are tracked", function()
    local db = freshDB()
    local p = OP:Get("X", db)
    H.assertNotNil(p.tendencies.trinketsFear)
    H.assertNotNil(p.tendencies.iceBlockBelow30)
    H.assertNotNil(p.tendencies.kicksFirstHeal)
    H.assertNotNil(p.tendencies.sapsPriest)
end)

H.it(g, "Update returns nil on bad inputs (nil signature / event / db)", function()
    H.assertNil(OP:Update(nil, { tendency = "trinketsFear", observed = true }, freshDB()))
    H.assertNil(OP:Update("X", nil, freshDB()))
    H.assertNil(OP:Update("X", { tendency = "trinketsFear", observed = true }, nil))
end)
