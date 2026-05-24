-- ArenaCoachTBC - SelfTest
-- A handful of fast assertions runnable inside the live WoW client via
-- `/acc selftest`. Catches the things headless CI cannot: partial module
-- load failures, missing locale keys after a client patch, broken event
-- wiring when another addon clobbers the namespace.
--
-- Checks must be cheap (microseconds), side-effect-free (or self-cleaning),
-- and must not require the player to be in an arena.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.SelfTest = ns.SelfTest or {}

local ST = ns.SelfTest
ST.checks = ST.checks or {}

function ST:Register(name, fn)
    table.insert(self.checks, { name = name, fn = fn })
end

function ST:Reset()
    self.checks = {}
end

-- Run all registered checks. Returns (pass, fail, results).
-- `printer` defaults to print; pass a custom one for non-chat output.
function ST:Run(verbose, printer)
    printer = printer or print
    local pass, fail, results = 0, 0, {}
    for _, c in ipairs(self.checks) do
        local okCall, ok, detail = pcall(c.fn)
        if not okCall then
            ok, detail = false, tostring(ok)
        end
        if ok then
            pass = pass + 1
            if verbose then printer(string.format("  PASS  %s", c.name)) end
        else
            fail = fail + 1
            if verbose then
                printer(string.format("  FAIL  %s: %s", c.name, tostring(detail or "no detail")))
            end
        end
        table.insert(results, { name = c.name, ok = ok, detail = detail })
    end
    if not verbose then
        for _, r in ipairs(results) do
            if not r.ok then
                printer(string.format("  FAIL  %s: %s", r.name, tostring(r.detail or "no detail")))
            end
        end
    end
    printer(string.format("SelfTest: %d passed, %d failed (of %d)", pass, fail, #self.checks))
    return pass, fail, results
end

-- Register the default check set. Idempotent.
function ST:RegisterDefaults()
    self:Reset()
    local S    = ns.Spells
    local CT   = ns.CooldownTracker
    local DR   = ns.DRTracker
    local SE   = ns.StrategyEngine
    local Str  = ns.Strategies
    local OC   = ns.OwnComps
    local EB   = ns.EventBus
    local Core = ns.Core

    self:Register("Spells.CATEGORIES non-empty", function()
        if not S or not S.CATEGORIES then return false, "Spells.CATEGORIES missing" end
        return next(S.CATEGORIES) ~= nil
    end)

    self:Register("Spells.IMMUNITY_BUFFS non-empty", function()
        if not S or not S.IMMUNITY_BUFFS then return false, "missing table" end
        return next(S.IMMUNITY_BUFFS) ~= nil
    end)

    self:Register("CooldownTracker round-trip", function()
        if not CT then return false, "CooldownTracker missing" end
        CT:Clear()
        CT:MarkUsed("st-guid", 27619)
        local r = CT:GetRemaining("st-guid", 27619)
        CT:Clear()
        if not r or r <= 0 then return false, "remaining was " .. tostring(r) end
        return true
    end)

    self:Register("DRTracker accepts a CC", function()
        if not DR or not DR.OnCC then return false, "DRTracker missing" end
        DR:OnCC("SPELL_AURA_APPLIED", "st-guid", S and S.PSYCHIC_SCREAM or 10890, "FEAR")
        return true
    end)

    self:Register("StrategyEngine evaluates synthetic state", function()
        if not SE or not SE.Evaluate then return false, "StrategyEngine missing" end
        local state
        if SE.BuildTestState then
            state = SE:BuildTestState({"WARRIOR"})
        else
            state = { phase = "PRE", enemies = {}, friendlies = {} }
        end
        local rec = SE:Evaluate(state)
        if rec == nil then return false, "Evaluate returned nil" end
        return true
    end)

    self:Register("Strategies.Identify is callable without erroring", function()
        if not Str or not Str.Identify then return false, "Strategies missing" end
        Str:Identify({})  -- empty list is fine, return value can be nil
        return true
    end)

    self:Register("OwnComps.Identify is callable without erroring", function()
        if not OC or not OC.Identify then return false, "OwnComps missing" end
        OC:Identify({})
        return true
    end)

    self:Register("EventBus emits an addon event", function()
        if not EB or not EB.On or not EB.Emit then return false, "EventBus missing" end
        local fired = 0
        EB:On("ACC_SELFTEST_PING", function() fired = fired + 1 end)
        EB:Emit("ACC_SELFTEST_PING")
        return fired == 1, "fired=" .. tostring(fired)
    end)

    self:Register("Locale resolves a known key", function()
        if not Core or not Core.L then return false, "Core.L missing" end
        local s = Core.L("HELP_HEADER")
        return type(s) == "string" and #s > 0, "got: " .. tostring(s)
    end)

    self:Register("WeakAura bridge exposes GetVersion", function()
        if not _G.ArenaCoachTBC then return false, "_G.ArenaCoachTBC missing" end
        return type(_G.ArenaCoachTBC.GetVersion) == "function"
    end)
end
