-- ArenaCleaveCoachTBC - Tiny event bus
-- Wraps a single WoW frame for game-event listening, plus an in-addon
-- pub/sub for "logical" notifications (e.g. "ENEMY_BURST_DETECTED").
-- Keeps OnUpdate usage to zero on the bus itself.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.EventBus = ns.EventBus or {}

local EB = ns.EventBus
EB._subs       = {}   -- gameEvent -> { handler1, handler2 ... }
EB._addonSubs  = {}   -- addonEvent -> { handler1, handler2 ... }

-- A single frame is enough for all events in TBC 2.5.x
local frame
local function ensureFrame()
    if frame then return frame end
    if type(CreateFrame) ~= "function" then
        -- Outside-WoW environment (tests). Return a stub frame.
        frame = { _events = {}, _scripts = {} }
        function frame:RegisterEvent(evt) self._events[evt] = true end
        function frame:UnregisterEvent(evt) self._events[evt] = nil end
        function frame:SetScript(kind, fn) self._scripts[kind] = fn end
        return frame
    end
    frame = CreateFrame("Frame", "ArenaCleaveCoachTBCEventFrame")
    frame:SetScript("OnEvent", function(_, event, ...)
        EB:Dispatch(event, ...)
    end)
    return frame
end

function EB:Subscribe(gameEvent, handler)
    assert(type(gameEvent) == "string" and type(handler) == "function",
        "EventBus:Subscribe(event,handler) requires string+function")
    local f = ensureFrame()
    if not self._subs[gameEvent] then
        self._subs[gameEvent] = {}
        f:RegisterEvent(gameEvent)
    end
    table.insert(self._subs[gameEvent], handler)
end

function EB:Unsubscribe(gameEvent, handler)
    local list = self._subs[gameEvent]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == handler then table.remove(list, i) end
    end
    if #list == 0 then
        self._subs[gameEvent] = nil
        local f = ensureFrame()
        f:UnregisterEvent(gameEvent)
    end
end

function EB:Dispatch(gameEvent, ...)
    local list = self._subs[gameEvent]
    if not list then return end
    for _, handler in ipairs(list) do
        -- Pcall each handler so a broken subscriber doesn't kill the rest.
        local ok, err = pcall(handler, gameEvent, ...)
        if not ok and ns.Core and ns.Core.DebugPrint then
            ns.Core.DebugPrint("handler error on " .. tostring(gameEvent) .. ": " .. tostring(err))
        end
    end
end

-- In-addon notification channel (independent from WoW events)
function EB:On(addonEvent, handler)
    assert(type(addonEvent) == "string" and type(handler) == "function")
    if not self._addonSubs[addonEvent] then self._addonSubs[addonEvent] = {} end
    table.insert(self._addonSubs[addonEvent], handler)
end

function EB:Emit(addonEvent, ...)
    local list = self._addonSubs[addonEvent]
    if not list then return end
    for _, handler in ipairs(list) do
        local ok, err = pcall(handler, addonEvent, ...)
        if not ok and ns.Core and ns.Core.DebugPrint then
            ns.Core.DebugPrint("addon handler error on " .. tostring(addonEvent) .. ": " .. tostring(err))
        end
    end
end

-- Test helpers (no-op outside tests)
function EB:_Reset()
    self._subs = {}
    self._addonSubs = {}
    frame = nil
end
