-- Tests/FactsHUD_spec.lua (v2.9)
-- The facts HUD's model builders are pure; we drive them with synthetic
-- CooldownTracker / DRTracker state and assert on the row models and
-- formatted strings. The frame layer is smoke-tested via the mocked
-- CreateFrame from test_helpers.
local H = _G.__ACC_TEST_HELPERS
H.load("Data/Spells.lua")
H.load("CooldownTracker.lua")
H.load("DRTracker.lua")
H.load("FactsHUD.lua")

local S  = H.ns.Spells
local CT = H.ns.CooldownTracker
local DR = H.ns.DRTracker
local FH = H.ns.FactsHUD

local g = H.describe("FactsHUD")

local function freshEnemy(over)
    local e = {
        unit = "arena1", guid = "guid-fh-1", name = "Evilmage",
        class = "MAGE", alive = true, healthPct = 72,
    }
    for k, v in pairs(over or {}) do e[k] = v end
    return e
end

local function reset()
    CT:Clear()
    DR:Clear()
end

H.it(g, "BuildRowModel returns nil for dead or class-less enemies", function()
    reset()
    H.assertNil(FH:BuildRowModel(nil))
    H.assertNil(FH:BuildRowModel(freshEnemy({ alive = false })))
    -- class-less (slot seen but not yet resolved): no row
    H.assertNil(FH:BuildRowModel({ unit = "arena1", guid = "g", alive = true }))
end)

H.it(g, "trinket cell is READY until a medallion use is observed", function()
    reset()
    local m = FH:BuildRowModel(freshEnemy())
    H.assertTrue(m.trinket.ready)
    CT:MarkUsed("guid-fh-1", S.PVP_TRINKET_EFFECT)
    m = FH:BuildRowModel(freshEnemy())
    H.assertFalse(m.trinket.ready)
    H.assertTrue(m.trinket.remaining > 100, "2m trinket should have >100s left")
end)

H.it(g, "WotF also drives the trinket cell (separate CC-break CD)", function()
    reset()
    CT:MarkUsed("guid-fh-1", S.WILL_OF_THE_FORSAKEN)
    local m = FH:BuildRowModel(freshEnemy())
    H.assertFalse(m.trinket.ready)
end)

H.it(g, "defensive cell empty until observed, then shows the downed CD", function()
    reset()
    local m = FH:BuildRowModel(freshEnemy())
    H.assertNil(m.defensive)
    CT:MarkUsed("guid-fh-1", S.ICE_BLOCK)
    m = FH:BuildRowModel(freshEnemy())
    H.assertEq(m.defensive.spellID, S.ICE_BLOCK)
    H.assertTrue(m.defensive.remaining > 250)
end)

H.it(g, "defensive cell picks the CD coming back soonest when several are down", function()
    reset()
    local t = (type(GetTime) == "function") and GetTime() or os.time()
    CT:_record("guid-fh-1", S.ICE_BLOCK, 300, t)          -- back in 300s
    CT:_record("guid-fh-1", S.CLOAK_OF_SHADOWS, 120, t)   -- back in 120s
    local m = FH:BuildRowModel(freshEnemy({ class = "ROGUE" }))
    H.assertEq(m.defensive.spellID, S.CLOAK_OF_SHADOWS)
end)

H.it(g, "interrupt cell tracks a downed kick (free-cast window)", function()
    reset()
    CT:MarkUsed("guid-fh-1", S.KICK)
    local m = FH:BuildRowModel(freshEnemy({ class = "ROGUE" }))
    H.assertEq(m.interrupt.spellID, S.KICK)
    H.assertTrue(m.interrupt.remaining <= 10)
end)

H.it(g, "DR badges appear per CC'd category with glyph + multiplier", function()
    reset()
    DR:Apply("guid-fh-1", "STUN")
    DR:Apply("guid-fh-1", "FEAR")
    DR:Apply("guid-fh-1", "FEAR")
    local m = FH:BuildRowModel(freshEnemy())
    H.assertEq(#m.dr, 2)
    local byCat = {}
    for _, d in ipairs(m.dr) do byCat[d.category] = d end
    H.assertEq(byCat.STUN.mult, 0.5)
    H.assertEq(byCat.FEAR.mult, 0.25)
    H.assertTrue(byCat.STUN.glyph:find("S") == 1)
end)

H.it(g, "DR badge shows IMM on the 4th application", function()
    reset()
    for _ = 1, 3 do DR:Apply("guid-fh-1", "STUN") end
    local m = FH:BuildRowModel(freshEnemy())
    H.assertEq(m.dr[1].mult, 0.0)
    H.assertNotNil(m.dr[1].glyph:find("IMM"))
end)

H.it(g, "BuildModel orders arena slots first and skips empty slots", function()
    reset()
    local state = { enemies = {
        arena1 = freshEnemy(),
        arena3 = freshEnemy({ unit = "arena3", guid = "guid-fh-3", name = "Evilpriest", class = "PRIEST" }),
        arena2 = { unit = "arena2", alive = false },  -- dead slot skipped
    } }
    local rows = FH:BuildModel(state)
    H.assertEq(#rows, 2)
    H.assertEq(rows[1].unit, "arena1")
    H.assertEq(rows[2].unit, "arena3")
end)

H.it(g, "BuildModel falls back to GUID-keyed (BG/world) enemies sorted by name", function()
    reset()
    local state = { enemies = {
        ["Player-1"] = { unit = "nameplate1", guid = "Player-1", name = "Zed", class = "ROGUE", alive = true, healthPct = 90 },
        ["Player-2"] = { unit = "nameplate2", guid = "Player-2", name = "Anna", class = "MAGE", alive = true, healthPct = 80 },
    } }
    local rows = FH:BuildModel(state)
    H.assertEq(#rows, 2)
    H.assertEq(rows[1].name, "Anna")
    H.assertEq(rows[2].name, "Zed")
end)

H.it(g, "FormatRow renders name+hp, trinket state, and DR string", function()
    reset()
    CT:MarkUsed("guid-fh-1", S.PVP_TRINKET_EFFECT)
    DR:Apply("guid-fh-1", "STUN")
    local m = FH:BuildRowModel(freshEnemy())
    local txt = FH:FormatRow(m)
    H.assertNotNil(txt.nameText:find("Evilmage 72%%"))
    H.assertEq(txt.trinketText:sub(1, 2), "T-")
    H.assertNotNil(txt.drText:find("S:"))
end)

H.it(g, "FormatRow shows T+ when trinket is up", function()
    reset()
    local txt = FH:FormatRow(FH:BuildRowModel(freshEnemy()))
    H.assertEq(txt.trinketText, "T+")
    H.assertEq(txt.defText, "")
    H.assertEq(txt.intText, "")
end)

H.it(g, "minutes formatting for long cooldowns", function()
    reset()
    CT:MarkUsed("guid-fh-1", S.ICE_BLOCK)  -- 300s -> "5m"
    local txt = FH:FormatRow(FH:BuildRowModel(freshEnemy()))
    H.assertNotNil(txt.defText:find("m$"), "long CDs render as minutes")
end)

-- ============================================================
-- Frame layer smoke tests (mocked CreateFrame)
-- ============================================================

H.it(g, "CreateFrame builds MAX_ROWS rows once", function()
    FH.frame = nil
    local f = FH:CreateFrame()
    H.assertNotNil(f)
    H.assertEq(#f.rows, FH.MAX_ROWS)
    H.assertEq(FH:CreateFrame(), f, "second call returns the same frame")
end)

H.it(g, "Update hides the frame when factsHud is disabled", function()
    reset()
    _G.ArenaCoachTBCDB = { factsHud = { enabled = false } }
    FH.frame = nil
    FH:CreateFrame()
    FH:Update({ enemies = { arena1 = freshEnemy() }, pvpContext = "arena" })
    H.assertFalse(FH.frame:IsShown())
end)

H.it(g, "Update hides outside PvP contexts and shows in arena", function()
    reset()
    _G.ArenaCoachTBCDB = { factsHud = { enabled = true } }
    FH.frame = nil
    FH:CreateFrame()
    FH:Update({ enemies = { arena1 = freshEnemy() }, pvpContext = "none" })
    H.assertFalse(FH.frame:IsShown())
    FH:Update({ enemies = { arena1 = freshEnemy() }, pvpContext = "arena" })
    H.assertTrue(FH.frame:IsShown())
end)

H.it(g, "ticker repaint runs through the OnUpdate accumulator", function()
    reset()
    _G.ArenaCoachTBCDB = { factsHud = { enabled = true } }
    FH.frame = nil
    FH:CreateFrame()
    FH:Update({ enemies = { arena1 = freshEnemy() }, pvpContext = "arena" })
    local handler = FH.frame:GetScript("OnUpdate")
    H.assertNotNil(handler)
    handler(FH.frame, FH.REFRESH_INTERVAL + 0.1)  -- must not error
end)
H.it(g, "FormatRow renders a downed kick with seconds countdown", function()
    reset()
    CT:MarkUsed("guid-fh-1", S.KICK)  -- 10s CD -> seconds formatting
    local txt = FH:FormatRow(FH:BuildRowModel(freshEnemy({ class = "ROGUE" })))
    H.assertEq(txt.intText:sub(1, 5), "KICK ")
    H.assertNotNil(txt.intText:match("KICK %d+$"), "sub-minute CDs render as seconds")
end)

H.it(g, "drag handlers persist the frame position to db.factsFrame", function()
    reset()
    _G.ArenaCoachTBCDB = { factsHud = { enabled = true }, locked = false }
    FH.frame = nil
    local f = FH:CreateFrame()
    local down = f:GetScript("OnMouseDown")
    local up   = f:GetScript("OnMouseUp")
    H.assertNotNil(down); H.assertNotNil(up)
    down(f, "LeftButton")   -- must not error (StartMoving mocked)
    up(f)
    H.assertNotNil(_G.ArenaCoachTBCDB.factsFrame)
    H.assertEq(_G.ArenaCoachTBCDB.factsFrame.point, "CENTER")
    -- locked frames must not start moving
    _G.ArenaCoachTBCDB.locked = true
    down(f, "LeftButton")
end)
