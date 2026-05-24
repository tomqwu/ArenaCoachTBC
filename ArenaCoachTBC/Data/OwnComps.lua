-- ArenaCoachTBC - Own-comp capability inference
-- Walks the friendly team and infers what the team CAN DO (Mortal Strike,
-- Bloodlust, Cleanse, Freedom, Mass Dispel, off-heals, cyclone CC, etc.)
-- so the strategy engine never has to hardcode "warrior provides MS".
--
-- This makes the addon useful for *any* 2v2/3v3/5v5 group, not only the
-- default WAR/ENH/RET/RDRU/DISC cleave the addon was originally designed for.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.OwnComps = ns.OwnComps or {}

local OC = ns.OwnComps

-- ============================================================
-- Capability flags. Boolean per team; never per individual.
-- ============================================================
OC.capabilities = {
    "hasMortalStrike",      -- Warrior Arms, Hunter (Aimed Shot), Mut Rogue (Wound Poison)
    "hasBloodlust",         -- Shaman
    "hasWindfury",          -- Enhancement Shaman
    "hasCleanse",           -- Paladin
    "hasFreedom",           -- Paladin
    "hasBoP",               -- Paladin
    "hasHoJ",               -- Paladin
    "hasDispelMagic",       -- Priest / Shaman (Cleanse Spirit)
    "hasMassDispel",        -- Priest (TBC)
    "hasPainSuppression",   -- Disc Priest
    "hasManaBurn",          -- Priest
    "hasFear",              -- Priest, Warlock
    "hasCyclone",           -- Druid
    "hasRoots",             -- Druid
    "hasNS",                -- Druid
    "hasInnervate",         -- Druid
    "hasPurge",             -- Shaman
    "hasGrounding",         -- Shaman
    "hasTremor",            -- Shaman
    "hasInterrupt",         -- Rogue Kick, Warrior Pummel, Mage CS, Shaman Earth Shock
    "hasOffhealer",         -- Paladin / Druid / Priest / Shaman off-heal
    "hasMainHealer",        -- dedicated resto/disc/holy
    "hasMeleeDamage",
    "hasRangedDamage",
    "hasMagicDamage",
    "hasPet",               -- Warlock / Hunter
    "hasGroup",             -- not solo
}

-- Per (class, spec) -> which capabilities it grants. Spec optional; if
-- omitted, all specs of that class grant the capability.
-- Entries are { capability = true, ... }
OC.classCaps = {
    WARRIOR = {
        __any__ = { hasMeleeDamage = true, hasInterrupt = true },
        ARMS    = { hasMortalStrike = true },
        FURY    = {},
        PROT    = {},
    },
    SHAMAN = {
        __any__       = { hasBloodlust = true, hasGrounding = true, hasTremor = true, hasPurge = true, hasInterrupt = true, hasDispelMagic = true, hasOffhealer = true },
        ENHANCEMENT   = { hasWindfury = true, hasMeleeDamage = true },
        ELEMENTAL     = { hasRangedDamage = true, hasMagicDamage = true },
        RESTORATION   = { hasMainHealer = true },
    },
    PALADIN = {
        __any__       = { hasCleanse = true, hasFreedom = true, hasBoP = true, hasHoJ = true, hasOffhealer = true },
        RETRIBUTION   = { hasMeleeDamage = true },
        HOLY          = { hasMainHealer = true },
        PROTECTION    = {},
    },
    DRUID = {
        __any__       = { hasCyclone = true, hasRoots = true, hasNS = true, hasInnervate = true, hasOffhealer = true },
        RESTORATION   = { hasMainHealer = true },
        BALANCE       = { hasRangedDamage = true, hasMagicDamage = true },
        FERAL         = { hasMeleeDamage = true },
    },
    PRIEST = {
        __any__       = { hasDispelMagic = true, hasMassDispel = true, hasFear = true, hasManaBurn = true, hasOffhealer = true },
        DISCIPLINE    = { hasMainHealer = true, hasPainSuppression = true },
        HOLY          = { hasMainHealer = true },
        SHADOW        = { hasMagicDamage = true, hasRangedDamage = true },
    },
    MAGE = {
        __any__       = { hasMagicDamage = true, hasRangedDamage = true, hasInterrupt = true },
    },
    WARLOCK = {
        __any__       = { hasMagicDamage = true, hasRangedDamage = true, hasFear = true, hasPet = true },
    },
    ROGUE = {
        __any__       = { hasMeleeDamage = true, hasInterrupt = true },
        ASSASSINATION = { hasMortalStrike = true }, -- Wound Poison MS effect
    },
    HUNTER = {
        __any__       = { hasRangedDamage = true, hasPet = true, hasInterrupt = true },
        MARKSMANSHIP  = { hasMortalStrike = true }, -- Aimed Shot MS effect
    },
}

-- Infer capability set from a friendly table.
-- friendlies = { unit = { class = "WARRIOR", spec = "ARMS", ... }, ... }
function OC:Infer(friendlies)
    local caps = {}
    for _, c in ipairs(self.capabilities) do caps[c] = false end
    local n = 0
    for _, f in pairs(friendlies or {}) do
        if f and f.class then
            n = n + 1
            local entry = self.classCaps[f.class]
            if entry then
                if entry.__any__ then
                    for k, _ in pairs(entry.__any__) do caps[k] = true end
                end
                if f.spec and entry[f.spec:upper()] then
                    for k, _ in pairs(entry[f.spec:upper()]) do caps[k] = true end
                end
                if not f.spec then
                    -- No spec info: union all specs (conservative for capabilities)
                    for specName, specCaps in pairs(entry) do
                        if specName ~= "__any__" then
                            for k, _ in pairs(specCaps) do caps[k] = true end
                        end
                    end
                end
            end
        end
    end
    caps.hasGroup = n > 1
    caps._teamSize = n
    return caps
end

-- ============================================================
-- Own archetype detection.
-- Archetypes describe broad team identities used to pick
-- complementary strategies vs the enemy.
-- ============================================================
OC.archetypes = {
    {
        id = "MELEE_CLEAVE",
        label = "Melee cleave",
        requires = { hasMortalStrike = true, hasMeleeDamage = true },
        prefers  = { hasFreedom = true, hasBloodlust = true },
        playstyle = "open + sustained pressure, swap on long defensives",
    },
    {
        id = "CASTER_CLEAVE",
        label = "Caster cleave",
        requires = { hasMagicDamage = true },
        prefers  = { hasMainHealer = true, hasInterrupt = true },
        playstyle = "CC chain into burst window",
    },
    {
        id = "DRAIN",
        label = "Drain / attrition",
        requires = { hasMainHealer = true },
        prefers  = { hasManaBurn = true, hasFear = true },
        playstyle = "pillar, drain, mana burn",
    },
    {
        id = "JUNGLE",
        label = "Pet cleave (Hunter/Lock)",
        requires = { hasPet = true, hasRangedDamage = true },
        prefers  = { hasMainHealer = true },
        playstyle = "kite + pet damage + scatter/fear chain",
    },
    {
        id = "DOUBLE_HEALER",
        label = "Double healer",
        requires = { hasMainHealer = true },
        prefers  = {},
        dynamic  = function(caps, friendlies)
            local healers = 0
            for _, f in pairs(friendlies or {}) do
                local Classes = ns.Classes
                if Classes and Classes:IsHealer(f.class, f.spec) then healers = healers + 1 end
            end
            return healers >= 2
        end,
        playstyle = "outlast everything",
    },
}

-- Score each archetype and return the best fit.
function OC:Identify(friendlies, caps)
    caps = caps or self:Infer(friendlies)
    local best, bestScore
    for _, arch in ipairs(self.archetypes) do
        local ok = true
        if arch.requires then
            for k, _ in pairs(arch.requires) do
                if not caps[k] then ok = false; break end
            end
        end
        if ok and arch.dynamic then
            ok = arch.dynamic(caps, friendlies) and true or false
        end
        if ok then
            local score = 0
            if arch.prefers then
                for k, _ in pairs(arch.prefers) do
                    if caps[k] then score = score + 1 end
                end
            end
            if not bestScore or score > bestScore then
                best, bestScore = arch, score
            end
        end
    end
    return best
end

-- Compose a comp signature key from friendlies (sorted class set)
function OC:SignatureFor(friendlies)
    local classes = {}
    for _, f in pairs(friendlies or {}) do
        if f.class then table.insert(classes, f.class) end
    end
    table.sort(classes)
    return table.concat(classes, "_")
end
