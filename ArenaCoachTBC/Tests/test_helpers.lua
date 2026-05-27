-- Tests/test_helpers.lua - shared mocks, loaders, and test harness.
-- Returned table is also assigned to _G.__ACC_TEST_HELPERS by run_all.lua
-- so individual spec files can pick it up.

local H = {}

H.ADDON_NAME = "ArenaCoachTBC"
H.ADDON_DIR  = nil          -- set by run_all.lua
H.ns         = {}           -- shared addon namespace across all specs
H.groups     = {}           -- registered test groups
H.installed  = false

-- ============================================================
-- Mock CreateFrame: a generic frame-like object that is both
-- callable (so `f.SomeMethod(...)` works for unknown setters)
-- and indexable (so `f.Text:SetText(...)` works).
-- ============================================================
local mockMethods = {}
function mockMethods:RegisterEvent(e)     self._events[e] = true end
function mockMethods:UnregisterEvent(e)   self._events[e] = nil end
function mockMethods:IsEventRegistered(e) return self._events[e] == true end
function mockMethods:SetScript(k, fn)     self._scripts[k] = fn end
function mockMethods:GetScript(k)         return self._scripts[k] end
function mockMethods:HasScript(k)         return self._scripts[k] ~= nil end
function mockMethods:Show()               self._shown = true end
function mockMethods:Hide()               self._shown = false end
function mockMethods:IsShown()            return self._shown end
function mockMethods:GetPoint()           return "CENTER", nil, "CENTER", 0, 0 end
function mockMethods:GetChecked()         return self._checked end
function mockMethods:SetChecked(v)        self._checked = v and true or false end
function mockMethods:GetName()            return self._name end
function mockMethods:SetSize(w, h)        self._width = w; self._height = h end
function mockMethods:GetWidth()           return self._width end
function mockMethods:GetHeight()          return self._height end
function mockMethods:SetPoint(...)        self._point = {...} end
function mockMethods:ClearAllPoints()     self._point = nil end
-- v2.1.3: track FontString-style text so UI tests can assert on
-- rendered output (`f.bigText._text`).
function mockMethods:SetText(text)        self._text = tostring(text or "") end
function mockMethods:GetText()            return self._text end
function mockMethods:SetTextColor()       end
function mockMethods:SetShadowColor(r, g, b, a)
    self._shadowColor = { r, g, b, a }
end
function mockMethods:SetShadowOffset(x, y)
    self._shadowOffset = { x, y }
end
function mockMethods:SetJustifyH()        end
function mockMethods:SetJustifyV()        end
function mockMethods:SetWidth(w)          self._width = w end
function mockMethods:SetHeight(h)         self._height = h end
function mockMethods:SetColorTexture(r, g, b, a)
    self._color = { r, g, b, a }
end
function mockMethods:SetTexture(...)
    local n = select("#", ...)
    if n >= 3 then
        self._color = { select(1, ...) }
    else
        self._texture = select(1, ...)
    end
end
function mockMethods:SetFont(path, size, flags)
    self._fontPath = path
    self._fontSize = size
    self._fontFlags = flags
end
function mockMethods:SetAlpha(v)          self._alpha = v end
function mockMethods:GetAlpha()           return self._alpha end

local makeMockFrame  -- forward decl

function mockMethods:CreateFontString()   return makeMockFrame() end
function mockMethods:CreateTexture()      return makeMockFrame() end
function mockMethods:CreateAnimationGroup() return makeMockFrame() end

makeMockFrame = function(opts)
    opts = opts or {}
    local m = {
        _events   = {},
        _scripts  = {},
        _shown    = true,
        _checked  = false,
        _name     = opts.name,
        _kind     = opts.kind,
        _template = opts.template,
    }
    -- Pre-populate Text for CheckButton-style frames
    if opts.template and opts.template:find("CheckButton") then
        m.Text = makeMockFrame()
    end
    setmetatable(m, {
        __index = function(t, k)
            local known = mockMethods[k]
            if known then rawset(t, k, known); return known end
            -- Unknown index: lazily create a child mock so chained access
            -- (`enabled.Text:SetText(...)`) keeps working in any direction.
            local child = makeMockFrame()
            rawset(t, k, child)
            return child
        end,
        __call = function(t, ...) return t end,
    })
    return m
end
H.makeMockFrame = makeMockFrame

-- Track all CreateFrame results for assertions
H.frames = {}

-- ============================================================
-- WoW API stubs
-- ============================================================
function H.installStubs()
    if H.installed then return end
    H.installed = true

    H._unitData     = H._unitData or {}      -- unit -> {class, guid, name, hp, hpMax, mp, mpMax, dead, exists}
    H._auras        = H._auras or {}         -- unit -> HELPFUL/HARMFUL -> { {name, spellID}, ... }
    H._lastCLEU     = nil
    H._curLocale    = "enUS"
    H._gameTime     = 100

    local function ud(u) return H._unitData[u] end

    _G.GetTime = function() return H._gameTime end
    _G.GetLocale = function() return H._curLocale end
    _G.GetSpellInfo = function(id)
        if not id then return nil end
        return "Spell" .. tostring(id), nil, ""
    end
    _G.GetSpellTexture = function(id) return id and "" or nil end
    _G.UnitExists = function(u)
        local d = ud(u)
        if d == nil then return false end
        return d.exists ~= false
    end
    _G.UnitGUID = function(u) local d = ud(u); return d and d.guid or ("guid-" .. tostring(u)) end
    _G.UnitName = function(u) local d = ud(u); return d and d.name or tostring(u) end
    _G.UnitClass = function(u)
        local d = ud(u)
        if not d then return "Warrior", "WARRIOR" end
        return d.classLocalized or d.class or "Warrior", d.class or "WARRIOR"
    end
    _G.UnitHealth = function(u) local d = ud(u); return d and d.hp or 100 end
    _G.UnitHealthMax = function(u) local d = ud(u); return d and d.hpMax or 100 end
    _G.UnitPower = function(u) local d = ud(u); return d and d.mp or 100 end
    _G.UnitPowerMax = function(u) local d = ud(u); return d and d.mpMax or 100 end
    _G.UnitIsDeadOrGhost = function(u) local d = ud(u); return d and d.dead == true or false end
    _G.CombatLogGetCurrentEventInfo = function()
        if not H._lastCLEU then return nil end
        return unpack(H._lastCLEU, 1, H._lastCLEU.n)
    end
    _G.UnitAura = function(u, i, filter)
        local byUnit = H._auras[u]
        local list = byUnit and byUnit[filter or "HELPFUL"] or nil
        local aura = list and list[i] or nil
        if not aura then return nil end
        return aura.name, nil, nil, nil, nil, nil, nil, nil, nil, aura.spellID
    end

    _G.CreateFrame = function(kind, name, parent, template)
        local f = makeMockFrame{ kind = kind, name = name, template = template }
        table.insert(H.frames, f)
        if name then _G[name] = f end
        return f
    end

    _G.UIParent = _G.UIParent or makeMockFrame{ name = "UIParent" }

    _G.SlashCmdList = _G.SlashCmdList or {}
    _G.InterfaceOptions_AddCategory = function() end
    _G.Settings = nil

    _G.GameTooltip = {
        SetOwner = function() end,
        SetText  = function() end,
        Show     = function() end,
        Hide     = function() end,
    }
end

function H.setUnit(unit, data)
    H._unitData[unit] = data
end

function H.setAuras(unit, filter, list)
    H._auras[unit] = H._auras[unit] or {}
    H._auras[unit][filter or "HELPFUL"] = list or {}
end

function H.clearAuras()
    H._auras = {}
end

function H.fireCLEU(...)
    H._lastCLEU = { n = select("#", ...), ... }
end

function H.advanceTime(seconds)
    H._gameTime = H._gameTime + (seconds or 1)
end

function H.setLocale(loc)
    H._curLocale = loc
end

-- ============================================================
-- Module loader
-- ============================================================
function H.load(rel)
    assert(H.ADDON_DIR, "H.ADDON_DIR not set")
    local path = H.ADDON_DIR .. "/" .. rel
    local chunk, err = loadfile(path)
    if not chunk then error("loadfile failed: " .. path .. ": " .. tostring(err)) end
    return chunk(H.ADDON_NAME, H.ns)
end

-- ============================================================
-- Test registration
-- ============================================================
function H.describe(name)
    local g = { name = name, tests = {}, before = nil, after = nil }
    table.insert(H.groups, g)
    return g
end

function H.it(group, name, fn)
    table.insert(group.tests, { name = name, fn = fn })
end

-- ============================================================
-- Assertions
-- ============================================================
function H.assertEq(a, b, msg)
    if a ~= b then
        error(string.format("assertEq failed: %s -- expected %s, got %s",
            tostring(msg or ""), tostring(b), tostring(a)), 2)
    end
end
function H.assertNotEq(a, b, msg)
    if a == b then
        error(string.format("assertNotEq failed: %s -- both were %s",
            tostring(msg or ""), tostring(a)), 2)
    end
end
function H.assertTrue(v, msg)
    if not v then error("assertTrue failed: " .. tostring(msg or ""), 2) end
end
function H.assertFalse(v, msg)
    if v then error("assertFalse failed: " .. tostring(msg or ""), 2) end
end
function H.assertNil(v, msg)
    if v ~= nil then error("assertNil failed: " .. tostring(msg or "") .. " -- was " .. tostring(v), 2) end
end
function H.assertNotNil(v, msg)
    if v == nil then error("assertNotNil failed: " .. tostring(msg or ""), 2) end
end
function H.assertType(v, t, msg)
    if type(v) ~= t then
        error(string.format("assertType failed: %s -- expected %s, got %s",
            tostring(msg or ""), t, type(v)), 2)
    end
end
function H.assertContains(haystack, needle, msg)
    for _, v in pairs(haystack) do
        if v == needle then return end
    end
    error("assertContains failed: " .. tostring(msg or "") .. " -- needle not found", 2)
end

-- ============================================================
-- Runner
-- ============================================================
function H.run()
    local pass, fail = 0, 0
    local failures = {}
    for _, g in ipairs(H.groups) do
        for _, t in ipairs(g.tests) do
            local ok, err = pcall(t.fn)
            if ok then
                pass = pass + 1
                print(string.format("PASS [%s] %s", g.name, t.name))
            else
                fail = fail + 1
                print(string.format("FAIL [%s] %s", g.name, t.name))
                print("    " .. tostring(err))
                table.insert(failures, g.name .. " / " .. t.name)
            end
        end
    end
    print(string.format("\nResults: %d passed, %d failed", pass, fail))
    if fail > 0 then
        for _, n in ipairs(failures) do print("  - " .. n) end
    end
    return fail == 0
end

return H
