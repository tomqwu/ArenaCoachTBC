-- Tests/EventBus_spec.lua
local H = _G.__ACC_TEST_HELPERS
H.load("EventBus.lua")
local EB = H.ns.EventBus

local g = H.describe("EventBus")

H.it(g, "Subscribe + Dispatch fires handlers", function()
    EB:_Reset()
    local called = 0
    EB:Subscribe("FOO", function(evt, x) called = called + (x or 1) end)
    EB:Dispatch("FOO", 7)
    H.assertEq(called, 7)
end)

H.it(g, "Multiple subscribers all fire", function()
    EB:_Reset()
    local a, b = 0, 0
    EB:Subscribe("EV", function() a = a + 1 end)
    EB:Subscribe("EV", function() b = b + 2 end)
    EB:Dispatch("EV")
    H.assertEq(a, 1)
    H.assertEq(b, 2)
end)

H.it(g, "Dispatching unknown event is a no-op", function()
    EB:_Reset()
    EB:Dispatch("NOPE", 1, 2, 3)
end)

H.it(g, "Handler error in one subscriber does not kill the rest", function()
    EB:_Reset()
    local bRan = false
    EB:Subscribe("X", function() error("boom") end)
    EB:Subscribe("X", function() bRan = true end)
    EB:Dispatch("X")
    H.assertTrue(bRan)
end)

H.it(g, "Unsubscribe removes a specific handler", function()
    EB:_Reset()
    local hits = 0
    local h = function() hits = hits + 1 end
    EB:Subscribe("Y", h)
    EB:Dispatch("Y")
    EB:Unsubscribe("Y", h)
    EB:Dispatch("Y")
    H.assertEq(hits, 1)
end)

H.it(g, "Unsubscribe of non-existent event is safe", function()
    EB:_Reset()
    EB:Unsubscribe("ZZZ", function() end)
end)

H.it(g, "Subscribe rejects bad args", function()
    EB:_Reset()
    local ok = pcall(function() EB:Subscribe(nil, function() end) end)
    H.assertFalse(ok)
    ok = pcall(function() EB:Subscribe("E", nil) end)
    H.assertFalse(ok)
end)

H.it(g, "On + Emit work for addon-internal events", function()
    EB:_Reset()
    local got = nil
    EB:On("INTERNAL", function(evt, payload) got = payload end)
    EB:Emit("INTERNAL", "hello")
    H.assertEq(got, "hello")
end)

H.it(g, "Emit with no subscribers is a no-op", function()
    EB:_Reset()
    EB:Emit("NOPE")
end)

H.it(g, "On rejects bad args", function()
    EB:_Reset()
    local ok = pcall(function() EB:On(nil, function() end) end)
    H.assertFalse(ok)
end)

H.it(g, "Addon-event errors do not kill other handlers", function()
    EB:_Reset()
    local bRan = false
    EB:On("X", function() error("boom") end)
    EB:On("X", function() bRan = true end)
    EB:Emit("X")
    H.assertTrue(bRan)
end)
