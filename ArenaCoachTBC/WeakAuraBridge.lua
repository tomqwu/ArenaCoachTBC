-- ArenaCoachTBC - WeakAura bridge
-- Exposes the addon's current recommendation, full state snapshot, own-team
-- archetype, capabilities, and per-enemy/per-friendly data through a single
-- global. WeakAuras can drive both display and additional logic by consuming
-- these getters without needing internal module access.
--
-- This is the ONLY intentional global pollution by the addon.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.WeakAuraBridge = ns.WeakAuraBridge or {}

local WAB = ns.WeakAuraBridge

WAB._last  = nil    -- last recommendation
WAB._state = nil    -- last state snapshot (shallow ref)

local API = {}

-- ----- Recommendation -----
function API.GetRecommendation() return WAB._last end
function API.GetMode()           return WAB._last and WAB._last.mode end
function API.GetPriority()       return WAB._last and WAB._last.priority end
function API.GetReason()         return WAB._last and WAB._last.reason end
function API.GetConfidence()     return WAB._last and WAB._last.confidence end

-- ----- Targeting -----
function API.GetPrimaryTarget()        return WAB._last and WAB._last.primaryTarget end
function API.GetPrimaryTargetName()    return WAB._last and WAB._last.primaryTargetName end
function API.GetPrimaryTargetClass()   return WAB._last and WAB._last.primaryTargetClass end
function API.GetSecondaryTarget()      return WAB._last and WAB._last.secondaryTarget end
function API.GetSecondaryTargetName()  return WAB._last and WAB._last.secondaryTargetName end
function API.GetSecondaryTargetClass() return WAB._last and WAB._last.secondaryTargetClass end

-- ----- Callouts & burst -----
function API.GetCallouts()       return WAB._last and WAB._last.callouts or {} end
function API.IsBurstAllowed()    return WAB._last and WAB._last.burstAllowed or false end
function API.GetBurstBlocker()   return WAB._last and WAB._last.burstBlockedBy end

-- ----- Comp identification -----
function API.GetEnemyComp()        return WAB._last and WAB._last.comp end
function API.GetEnemyCompLabel()   return WAB._last and WAB._last.compLabel end
function API.GetCompConfidence()   return WAB._last and WAB._last.compConfidence or 0.0 end
function API.GetCompSpecConfirmed() return (WAB._last and WAB._last.compSpecConfirmed) == true end
function API.GetOwnComp()          return WAB._last and WAB._last.ownArchetype end
function API.GetOwnCompLabel()     return WAB._last and WAB._last.ownArchetypeLabel end
function API.GetCapabilities()
    return WAB._last and WAB._last.ownCapabilities or {}
end
function API.HasCapability(cap)
    local c = API.GetCapabilities()
    return (c and c[cap]) == true
end

-- ----- State snapshot (read-only refs; do not mutate) -----
function API.GetEnemies()
    return WAB._state and WAB._state.enemies or {}
end
function API.GetFriendlies()
    return WAB._state and WAB._state.friendlies or {}
end
function API.GetEnemyByGUID(guid)
    if not guid then return nil end
    for _, e in pairs(API.GetEnemies()) do
        if e.guid == guid then return e end
    end
end
function API.GetCombatPhase()
    return WAB._state and WAB._state.combatPhase
end
function API.GetBracket()
    return WAB._state and WAB._state.bracket
end

-- Locale helper for WeakAura templates that want to render callouts in
-- the active language without re-implementing the locale fallback.
function API.L(key)
    if ns.Core and ns.Core.L then return ns.Core.L(key) end
    return key
end

-- ----- Debug / version -----
function API.GetDebugState()
    return {
        last       = WAB._last,
        state      = WAB._state,
        version    = "1.1.0",
        addon      = ADDON_NAME,
    }
end
function API.GetVersion() return "1.1.0" end

function WAB:Publish(recommendation, state)
    self._last  = recommendation
    self._state = state
    if WeakAuras and WeakAuras.ScanEvents then
        local ok = pcall(WeakAuras.ScanEvents, "ACC_RECOMMENDATION", recommendation)
        if not ok and ns.Core and ns.Core.DebugPrint then
            ns.Core.DebugPrint("WeakAuras.ScanEvents call failed (ignored)")
        end
    end
end

if type(_G) == "table" then
    _G.ArenaCoachTBC = _G.ArenaCoachTBC or {}
    for k, v in pairs(API) do
        _G.ArenaCoachTBC[k] = v
    end
end
