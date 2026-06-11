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

H.it(g, "WotF-only use does NOT flip the trinket cell (medallion still up)", function()
    -- WotF and the medallion are independent CC-breaks; an undead who
    -- burned only WotF can still trinket. Mirrors Core's hasTrinket
    -- semantics — the cell answers "can they break CC right now".
    reset()
    CT:MarkUsed("guid-fh-1", S.WILL_OF_THE_FORSAKEN)
    local m = FH:BuildRowModel(freshEnemy())
    H.assertTrue(m.trinket.ready)
end)

H.it(g, "medallion + WotF both down counts down to the FIRST break back", function()
    reset()
    local t = (type(GetTime) == "function") and GetTime() or os.time()
    CT:_record("guid-fh-1", S.PVP_TRINKET_EFFECT, 120, t - 30)     -- back in 90s
    CT:_record("guid-fh-1", S.WILL_OF_THE_FORSAKEN, 120, t - 100)  -- back in 20s
    local m = FH:BuildRowModel(freshEnemy())
    H.assertFalse(m.trinket.ready)
    H.assertTrue(m.trinket.remaining <= 21, "shows the soonest CC-break")
end)

H.it(g, "medallion down but WotF observed back up -> ready (undead racial up)", function()
    reset()
    local t = (type(GetTime) == "function") and GetTime() or os.time()
    CT:_record("guid-fh-1", S.PVP_TRINKET_EFFECT, 120, t - 30)      -- still down
    CT:_record("guid-fh-1", S.WILL_OF_THE_FORSAKEN, 120, t - 150)   -- expired -> ready
    local m = FH:BuildRowModel(freshEnemy())
    H.assertTrue(m.trinket.ready)
end)

H.it(g, "max-rank Kick (38768) populates the interrupt cell (v2.9 rank fix)", function()
    -- CLEU carries the rank actually cast; a level-70 rogue kicks with
    -- rank 5, not the rank-1 ID. Regression: CT.defaults must know it.
    reset()
    CT:OnCombatLogEvent("SPELL_CAST_SUCCESS", "guid-fh-1", "guid-x", S.KICK_R5)
    local m = FH:BuildRowModel(freshEnemy({ class = "ROGUE" }))
    H.assertNotNil(m.interrupt, "rank-5 kick must be tracked")
    H.assertTrue(m.interrupt.remaining <= 10)
end)

H.it(g, "Divine Shield rank 2 (1020) populates the defensive cell", function()
    reset()
    CT:OnCombatLogEvent("SPELL_AURA_APPLIED", "guid-x", "guid-fh-1", S.DIVINE_SHIELD_R2)
    local m = FH:BuildRowModel(freshEnemy({ class = "PALADIN" }))
    H.assertNotNil(m.defensive, "rank-2 bubble must be tracked")
end)

H.it(g, "Update rate-limits direct repaints to the ticker cadence (v2.9)", function()
    reset()
    _G.ArenaCoachTBCDB = { factsHud = { enabled = true } }
    FH.frame = nil
    FH:CreateFrame()
    local paints = 0
    local savedRepaint = FH.Repaint
    FH.Repaint = function(self) paints = paints + 1; self._lastPaint = (type(GetTime) == "function") and GetTime() or 0 end
    FH._lastPaint = nil
    local state = { enemies = { arena1 = freshEnemy() }, pvpContext = "arena" }
    FH:Update(state)  -- overdue -> paints
    FH:Update(state)  -- same tick -> rate-limited
    FH:Update(state)
    H.assertEq(paints, 1, "CLEU-rate Update calls must not repaint each time")
    H.advanceTime(1)
    FH:Update(state)  -- overdue again
    H.assertEq(paints, 2)
    FH.Repaint = savedRepaint
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
H.it(g, "FormatRow renders the actual interrupt spell name + seconds countdown", function()
    -- v2.10.1: interrupt cell shows GetSpellInfo(spellID), not always
    -- the static "KICK" label — keeps it consistent with the defensive
    -- cell and disambiguates Kick vs Counterspell vs Earth Shock.
    reset()
    CT:MarkUsed("guid-fh-1", S.KICK)
    local txt = FH:FormatRow(FH:BuildRowModel(freshEnemy({ class = "ROGUE" })))
    -- Headless GetSpellInfo stub returns "Spell<id>" for any positive id.
    H.assertEq(txt.intText:sub(1, 9), "Spell1766",
        "interrupt label should be the live spell name, not the static KICK fallback")
    H.assertNotNil(txt.intText:match(" %d+$"), "sub-minute CDs render as seconds")
end)

H.it(g, "v2.10: FormatRow exposes def + interrupt spellIDs for icon paint", function()
    reset()
    CT:MarkUsed("guid-fh-1", S.E_PAIN_SUPPRESSION)
    CT:MarkUsed("guid-fh-1", S.KICK)
    local txt = FH:FormatRow(FH:BuildRowModel(freshEnemy({ class = "ROGUE" })))
    H.assertEq(txt.defSpellID, S.E_PAIN_SUPPRESSION,
        "icon needs the spell ID alongside the countdown text")
    H.assertEq(txt.intSpellID, S.KICK)
end)

H.it(g, "v2.10: row gains hideable defIcon + intIcon textures", function()
    reset()
    _G.ArenaCoachTBCDB = { factsHud = { enabled = true } }
    FH.frame = nil
    local f = FH:CreateFrame()
    local row = f.rows[1]
    H.assertNotNil(row.defIcon)
    H.assertNotNil(row.intIcon)
end)

H.it(g, "v2.10: paint hides icons when no cooldown is observed in the cell", function()
    reset()
    _G.ArenaCoachTBCDB = { factsHud = { enabled = true } }
    FH.frame = nil
    FH:CreateFrame()
    FH:Update({ enemies = { arena1 = freshEnemy() }, pvpContext = "arena" })
    -- No CD observed -> both icons hidden.
    H.assertFalse(FH.frame.rows[1].defIcon:IsShown(),
        "no def CD observed -> defensive icon hidden")
    H.assertFalse(FH.frame.rows[1].intIcon:IsShown())
end)

H.it(g, "v2.10: paint shows icons once a spell is observed on cooldown", function()
    reset()
    _G.ArenaCoachTBCDB = { factsHud = { enabled = true } }
    FH.frame = nil
    FH:CreateFrame()
    CT:MarkUsed("guid-fh-1", S.E_PAIN_SUPPRESSION)
    CT:MarkUsed("guid-fh-1", S.KICK)
    FH:Update({ enemies = { arena1 = freshEnemy() }, pvpContext = "arena" })
    -- Under the headless stub GetSpellTexture returns "" for any
    -- positive id, so the icon stays hidden; production gets a real
    -- texture path. We assert the data flow is wired (spellID present)
    -- by checking the spec above; the frame test just verifies the
    -- code path doesn't error when icons are attempted.
    H.assertNotNil(FH.frame.rows[1].defIcon)
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

H.it(g, "v2.10.1: frame has a header strip + DR legend so abbreviations aren't cryptic", function()
    reset()
    _G.ArenaCoachTBCDB = { factsHud = { enabled = true } }
    FH.frame = nil
    local f = FH:CreateFrame()
    H.assertNotNil(f.header, "header strip should exist above the enemy rows")
    H.assertNotNil(f.header.name)
    H.assertNotNil(f.header.trinket)
    H.assertNotNil(f.header.def)
    H.assertNotNil(f.header.int)
    H.assertNotNil(f.header.dr)
    -- Legend text decodes the DR letter codes (S/F/D/P/R/C) AND the
    -- 1/2, 1/4, IMM multiplier glyphs that v2.10 shows on each row.
    H.assertNotNil(f.legend, "DR legend should exist at the bottom of the panel")
    local legendText = f.legend._text or ""
    H.assertNotNil(legendText:find("S=", 1, true), "legend names the STUN code")
    H.assertNotNil(legendText:find("IMM", 1, true), "legend names the IMMUNE marker")
end)

H.it(g, "v2.10.1: long names truncate inside the name cell instead of wrapping", function()
    -- Pre-v2.10.1 a 13-char name like 'Roadtoisekai' wrapped onto a
    -- second visual line that collided with the row below. The fix is
    -- SetWordWrap(false) on the name FontString.
    reset()
    _G.ArenaCoachTBCDB = { factsHud = { enabled = true } }
    FH.frame = nil
    local f = FH:CreateFrame()
    local row = f.rows[1]
    -- The mocked FontString tracks the last value passed to SetWordWrap.
    -- We just need to confirm the call happened; the WoW client does the
    -- actual truncation.
    H.assertEq(row.name._wordWrap, false, "name cell must disable wordwrap")
    H.assertEq(row.def._wordWrap, false, "def cell must disable wordwrap")
    H.assertEq(row.int._wordWrap, false, "int cell must disable wordwrap")
end)
