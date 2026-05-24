-- ArenaCleaveCoachTBC - WeakAura bridge
-- Exposes the addon's current recommendation through a single global so a
-- WeakAura custom trigger / custom text function can query it without
-- needing to know any internal module layout.
--
-- This is the ONLY intentional global pollution by the addon.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.WeakAuraBridge = ns.WeakAuraBridge or {}

local WAB = ns.WeakAuraBridge

-- Last evaluated recommendation snapshot
WAB._last = nil

-- Public API table (assigned to _G.ArenaCleaveCoachTBC below).
local API = {}

function API.GetRecommendation()
    return WAB._last
end

function API.GetPrimaryTarget()
    if not WAB._last then return nil end
    return WAB._last.primaryTarget
end

function API.GetCallouts()
    if not WAB._last then return {} end
    return WAB._last.callouts or {}
end

function API.GetDebugState()
    return {
        last       = WAB._last,
        version    = "1.0.0",
        addon      = ADDON_NAME,
    }
end

-- Called by Core after every Evaluate(). Decoupled so the engine doesn't need
-- to know the bridge exists.
function WAB:Publish(recommendation)
    self._last = recommendation
    -- Optionally fire a custom event for advanced WAs that prefer triggers.
    if WeakAuras and WeakAuras.ScanEvents then
        local ok = pcall(WeakAuras.ScanEvents, "ACC_RECOMMENDATION", recommendation)
        if not ok and ns.Core and ns.Core.DebugPrint then
            ns.Core.DebugPrint("WeakAuras.ScanEvents call failed (ignored)")
        end
    end
end

-- Install global ONCE (defensive against the addon being loaded twice in dev)
if type(_G) == "table" then
    _G.ArenaCleaveCoachTBC = _G.ArenaCleaveCoachTBC or {}
    for k, v in pairs(API) do
        _G.ArenaCleaveCoachTBC[k] = v
    end
end
