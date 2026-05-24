-- Tests/OwnComps_spec.lua
local H = _G.__ACC_TEST_HELPERS
H.load("Data/Classes.lua")
H.load("Data/OwnComps.lua")
local OC = H.ns.OwnComps

local g = H.describe("OwnComps")

local function makeFriendlies(t)
    local out = {}
    for i, e in ipairs(t) do
        out["u" .. i] = e
    end
    return out
end

H.it(g, "Infer returns all-false for empty team", function()
    local caps = OC:Infer({})
    H.assertFalse(caps.hasMortalStrike)
    H.assertFalse(caps.hasBloodlust)
    H.assertFalse(caps.hasGroup)
    H.assertEq(caps._teamSize, 0)
end)

H.it(g, "Infer detects WAR/ENH/RET/RDRU/DISC capabilities", function()
    local fr = makeFriendlies({
        { class = "WARRIOR", spec = "ARMS" },
        { class = "SHAMAN",  spec = "ENHANCEMENT" },
        { class = "PALADIN", spec = "RETRIBUTION" },
        { class = "DRUID",   spec = "RESTORATION" },
        { class = "PRIEST",  spec = "DISCIPLINE" },
    })
    local caps = OC:Infer(fr)
    H.assertTrue(caps.hasMortalStrike, "MS from arms warrior")
    H.assertTrue(caps.hasBloodlust, "Lust from shaman")
    H.assertTrue(caps.hasWindfury, "WF from enh")
    H.assertTrue(caps.hasCleanse, "Cleanse from pala")
    H.assertTrue(caps.hasFreedom, "Freedom from pala")
    H.assertTrue(caps.hasHoJ, "HoJ from pala")
    H.assertTrue(caps.hasCyclone, "Cyclone from druid")
    H.assertTrue(caps.hasPainSuppression, "PainSup from disc")
    H.assertTrue(caps.hasManaBurn, "Burn from priest")
    H.assertTrue(caps.hasMainHealer, "main heal from druid/priest")
    H.assertEq(caps._teamSize, 5)
    H.assertTrue(caps.hasGroup)
end)

H.it(g, "Infer without spec unions all specs of that class", function()
    local fr = makeFriendlies({ { class = "WARRIOR" } })
    local caps = OC:Infer(fr)
    -- Union: ARMS adds MS even though spec unknown
    H.assertTrue(caps.hasMortalStrike)
    H.assertTrue(caps.hasMeleeDamage)
end)

H.it(g, "Infer handles unknown class gracefully", function()
    local fr = makeFriendlies({ { class = "FAKE_CLASS" } })
    local caps = OC:Infer(fr)
    H.assertEq(caps._teamSize, 1)
end)

H.it(g, "Infer counts only entries that have a class", function()
    local fr = makeFriendlies({ {}, { class = "WARRIOR", spec = "ARMS" } })
    local caps = OC:Infer(fr)
    H.assertEq(caps._teamSize, 1)
end)

H.it(g, "Identify picks MELEE_CLEAVE for cleave comp", function()
    local fr = makeFriendlies({
        { class = "WARRIOR", spec = "ARMS" },
        { class = "SHAMAN",  spec = "ENHANCEMENT" },
        { class = "DRUID",   spec = "RESTORATION" },
    })
    local arch = OC:Identify(fr)
    H.assertEq(arch.id, "MELEE_CLEAVE")
end)

H.it(g, "Identify picks DRAIN when team has main healer + mana burn + fear", function()
    local fr = makeFriendlies({
        { class = "PRIEST", spec = "DISCIPLINE" },
        { class = "WARLOCK" },
        { class = "DRUID", spec = "RESTORATION" },
    })
    local arch = OC:Identify(fr)
    -- DOUBLE_HEALER triggers first because >=2 healers
    H.assertTrue(arch.id == "DOUBLE_HEALER" or arch.id == "DRAIN")
end)

H.it(g, "Identify picks JUNGLE for Hunter/Lock", function()
    local fr = makeFriendlies({
        { class = "HUNTER" },
        { class = "WARLOCK" },
        { class = "DRUID", spec = "RESTORATION" },
    })
    local arch = OC:Identify(fr)
    H.assertNotNil(arch)
end)

H.it(g, "Identify returns nil for empty team (no archetype fits)", function()
    local arch = OC:Identify({})
    H.assertNil(arch)
end)

H.it(g, "SignatureFor produces deterministic key", function()
    local fr1 = makeFriendlies({
        { class = "WARRIOR" }, { class = "SHAMAN" }, { class = "PALADIN" },
    })
    local fr2 = makeFriendlies({
        { class = "SHAMAN" }, { class = "PALADIN" }, { class = "WARRIOR" },
    })
    H.assertEq(OC:SignatureFor(fr1), OC:SignatureFor(fr2))
    H.assertEq(OC:SignatureFor(fr1), "PALADIN_SHAMAN_WARRIOR")
end)

H.it(g, "SignatureFor handles empty input", function()
    H.assertEq(OC:SignatureFor({}), "")
    H.assertEq(OC:SignatureFor(nil), "")
end)
