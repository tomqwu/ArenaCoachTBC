-- ArenaCoachTBC - Composition signature -> recommended openers and callouts
-- The intent is to keep "what to do vs this comp" data-driven so it can be
-- expanded without touching the engine.
--
-- Signatures are *unordered* class sets. We sort and join classes to derive
-- a deterministic key, e.g.:
--   { MAGE, PRIEST, ROGUE } -> "MAGE_PRIEST_ROGUE"
-- Partial matches (3 of 5) are allowed via the "core" field. The engine
-- iterates compositions in declaration order; the first whose `core` set is
-- a subset of the enemy team wins.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.Strategies = ns.Strategies or {}

local ST = ns.Strategies

-- Canonical comp catalog. Each entry can specify:
--   id          : short name
--   label       : friendly description
--   core        : minimal set of classes that defines this comp
--   openTarget  : class to suggest opening on (if alive)
--   swapTarget  : class to consider swapping to
--   threats     : { class -> top danger note }
--   callouts    : ordered list of callout keys (resolved via locale)
--   defensiveTriggers : optional list of trigger names that force DEFEND
--   ownVariants : optional { ownArchetype -> overrides } so a single enemy
--                 entry can give different advice to different own teams.
ST.comps = {
    -- ============================================================
    -- "RMP" family (rogue + mage + priest), the canonical TBC comp.
    -- ============================================================
    {
        id    = "RMP",
        label = "Rogue / Mage / Priest",
        core  = { MAGE = true, PRIEST = true, ROGUE = true },
        openTarget = "PRIEST",
        swapTarget = "MAGE",
        threats = {
            MAGE   = "Polymorph + burst",
            ROGUE  = "Cheap Shot opener / Blind",
            PRIEST = "Fear chain",
        },
        callouts = {
            "CALL_TREMOR_FEAR",
            "CALL_GROUND_POLY",
            "CALL_FREEDOM_WAR",
            "CALL_DISP_POLY",
        },
        ownVariants = {
            MELEE_CLEAVE = { openTarget = "PRIEST", swapTarget = "MAGE" },
            DRAIN        = { openTarget = nil,     swapTarget = "PRIEST", note = "drain mage mana, force defensives" },
            JUNGLE       = { openTarget = "MAGE",  swapTarget = "PRIEST", note = "scatter+fear chain on mage" },
        },
    },
    -- WMS = Warrior / Mage / Shaman ("Battlecleave")
    {
        id    = "WMS",
        label = "Warrior / Mage / Shaman (Battlecleave)",
        core  = { WARRIOR = true, MAGE = true, SHAMAN = true },
        openTarget = "MAGE",
        swapTarget = "SHAMAN",
        callouts = { "CALL_PURGE", "CALL_TREMOR_FEAR", "CALL_FREEDOM_WAR" },
    },
    -- Warlock/Druid/X
    {
        id    = "WLD",
        label = "Warlock / Druid / X",
        core  = { WARLOCK = true, DRUID = true },
        openTarget = "WARLOCK",
        swapTarget = "DRUID",
        threats = {
            WARLOCK = "Fear / Death Coil / Unstable Affliction",
            DRUID   = "Cyclone / kite",
        },
        callouts = {
            "CALL_TREMOR_FEAR",
            "CALL_GROUND_DC",
            "CALL_PURGE",
            "CALL_HOJ_KILL",
        },
        ownVariants = {
            MELEE_CLEAVE = { openTarget = "WARLOCK", swapTarget = "DRUID" },
            DRAIN        = { openTarget = nil, note = "outlast, mana burn druid" },
        },
    },
    -- Warlock / Shaman cleave
    {
        id    = "WLS",
        label = "Warlock / Shaman",
        core  = { WARLOCK = true, SHAMAN = true },
        openTarget = "SHAMAN",
        swapTarget = "WARLOCK",
        callouts = { "CALL_PURGE", "CALL_TREMOR_FEAR" },
    },
    -- Warlock / Paladin "drain"
    {
        id    = "WLP",
        label = "Warlock / Paladin (Drain)",
        core  = { WARLOCK = true, PALADIN = true },
        openTarget = "PALADIN",
        swapTarget = "WARLOCK",
        callouts = { "CALL_PURGE", "CALL_MANA_BURN_PLAN" },
    },
    -- ============================================================
    -- Hunter comps
    -- ============================================================
    {
        id    = "HUNTER_COMP",
        label = "Hunter / Druid / X",
        core  = { HUNTER = true, DRUID = true },
        openTarget = "HUNTER",
        swapTarget = "DRUID",
        threats = {
            HUNTER = "Mana drain / kite",
            DRUID  = "Roots / cyclone / HoT race",
        },
        callouts = {
            "CALL_FREEDOM_WAR",
            "CALL_CLEANSE_ROOTS",
            "CALL_AVOID_OVERCHASE",
        },
    },
    {
        id    = "BEAST_CLEAVE",
        label = "Hunter / Warrior",
        core  = { HUNTER = true, WARRIOR = true },
        openTarget = "HUNTER",
        swapTarget = "WARRIOR",
        callouts = { "CALL_FREEDOM_WAR", "CALL_AVOID_OVERCHASE" },
    },
    -- ============================================================
    -- Paladin / Warrior / X "TSG"
    -- ============================================================
    {
        id    = "TSG",
        label = "Warrior / DK-style melee (TSG analog)",
        core  = { WARRIOR = true, PALADIN = true },
        openTarget = "PALADIN",
        swapTarget = "WARRIOR",
        callouts = { "CALL_PURGE", "CALL_HOJ_KILL" },
    },
    -- ============================================================
    -- Rogue + Druid "RLS"-style (Rogue/Lock-or-Mage/Shaman) approximations
    -- ============================================================
    {
        id    = "RLS",
        label = "Rogue / Caster / Shaman",
        core  = { ROGUE = true, SHAMAN = true },
        openTarget = "SHAMAN",
        swapTarget = "ROGUE",
        callouts = { "CALL_PURGE", "CALL_TREMOR_FEAR" },
    },
    -- ============================================================
    -- Mirror melee cleave
    -- ============================================================
    {
        id    = "MIRROR_MELEE",
        label = "Mirror melee cleave",
        core  = { WARRIOR = true, SHAMAN = true, PALADIN = true, DRUID = true, PRIEST = true },
        openTarget = "PRIEST",
        swapTarget = "DRUID",
        threats = {
            PRIEST = "Mana Burn / PainSup",
            DRUID  = "Cyclone / NS",
        },
        callouts = {
            "CALL_PURGE",
            "CALL_CYCLONE_OFF",
            "CALL_EARTHSHOCK_HEAL",
        },
    },
    -- ============================================================
    -- Caster cleave / triple caster
    -- ============================================================
    {
        id    = "TRIPLE_CASTER",
        label = "Triple caster",
        core  = { MAGE = true, WARLOCK = true, PRIEST = true },
        openTarget = "WARLOCK",
        swapTarget = "MAGE",
        callouts = { "CALL_GROUND_POLY", "CALL_PURGE", "CALL_TREMOR_FEAR" },
    },
    -- ============================================================
    -- Dynamic comps (resolved on healer-count, not class set)
    -- ============================================================
    {
        id    = "DOUBLE_HEALER",
        label = "Double healer",
        core  = {},
        dynamic = "DOUBLE_HEALER",
        openTarget = nil,
        callouts = {
            "CALL_MANA_BURN_PLAN",
            "CALL_CYCLONE_OFF",
            "CALL_PURGE",
        },
    },
    {
        id    = "TRIPLE_DPS",
        label = "Triple DPS / no healer",
        core  = {},
        dynamic = "TRIPLE_DPS",
        defaultMode = "DEFEND",
        callouts = {
            "CALL_PAIN_SUP_READY",
            "CALL_BOP_READY",
            "CALL_PEEL_PRIEST",
            "CALL_PEEL_DRUID",
        },
    },
}

-- Predefined enemy comps for /acc test
ST.testComps = {
    {
        label   = "RMP + Druid + Paladin",
        classes = { "ROGUE", "MAGE", "PRIEST", "DRUID", "PALADIN" },
    },
    {
        label   = "Warlock / Druid / Warrior / Priest / Shaman",
        classes = { "WARLOCK", "DRUID", "WARRIOR", "PRIEST", "SHAMAN" },
    },
    {
        label   = "Hunter / Druid / Priest / Mage / Rogue",
        classes = { "HUNTER", "DRUID", "PRIEST", "MAGE", "ROGUE" },
    },
    {
        label   = "Mirror: WAR/ENH/RET/RDRU/DISC",
        classes = { "WARRIOR", "SHAMAN", "PALADIN", "DRUID", "PRIEST" },
    },
    {
        label   = "Triple DPS: Rogue / Mage / Warlock / Priest / Shaman",
        classes = { "ROGUE", "MAGE", "WARLOCK", "PRIEST", "SHAMAN" },
    },
}

-- Apply the variant overrides for a given own archetype on top of a comp
-- entry. Returns a shallow-merged copy. Safe to call with `nil` ownArchetype.
function ST:ApplyOwnVariant(comp, ownArchetypeId)
    if not comp then return comp end
    if not ownArchetypeId or not comp.ownVariants then return comp end
    local v = comp.ownVariants[ownArchetypeId]
    if not v then return comp end
    local out = {}
    for k, val in pairs(comp) do out[k] = val end
    for k, val in pairs(v) do out[k] = val end
    out._variantApplied = ownArchetypeId
    return out
end

-- Look up the best-fit comp for a given enemy class array.
-- Optionally accepts the enemies map so per-enemy roleGuess overrides take
-- effect (used by the live engine; tests rely on this too).
-- Returns the matching entry, or nil if none.
function ST:Identify(enemyClassList, enemies)
    if not enemyClassList or #enemyClassList == 0 then return nil end

    local Classes = ns.Classes
    local presence = {}
    local healers, dps = 0, 0

    -- Prefer the enemies table when available so roleGuess overrides win.
    if enemies and next(enemies) then
        for _, e in pairs(enemies) do
            if e.class then
                presence[e.class] = true
                local role = e.roleGuess
                if not role and Classes then role = Classes:DefaultRole(e.class) end
                if role == "HEALER" then healers = healers + 1
                else dps = dps + 1 end
            end
        end
    else
        for _, cls in ipairs(enemyClassList) do
            presence[cls] = true
            local def = Classes and Classes:DefaultRole(cls) or nil
            if def == "HEALER" then
                healers = healers + 1
            else
                dps = dps + 1
            end
        end
    end

    -- Dynamic role-count comps win when they fire because the role mix
    -- changes the entire game plan (no-healer = defensive, double-healer =
    -- mana drain), regardless of which specific dps classes are on the field.
    if healers == 0 then
        for _, comp in ipairs(self.comps) do
            if comp.dynamic == "TRIPLE_DPS" then return comp end
        end
    end
    if healers >= 2 then
        for _, comp in ipairs(self.comps) do
            if comp.dynamic == "DOUBLE_HEALER" then return comp end
        end
    end

    -- Static signature match (need all `core` classes present)
    for _, comp in ipairs(self.comps) do
        if not comp.dynamic then
            local ok = true
            local coreCount = 0
            for cls, _ in pairs(comp.core) do
                coreCount = coreCount + 1
                if not presence[cls] then ok = false; break end
            end
            if ok and coreCount > 0 then
                return comp
            end
        end
    end

    return nil
end
