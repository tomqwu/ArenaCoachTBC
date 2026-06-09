-- ReplayReport.lua - deterministic, redacted golden replay reports.
--
-- This module is pure Lua. It formats Core:ReplayRecord output into a
-- compact timeline that can be committed as a golden file and compared in CI.

local ADDON_NAME, ns = ...
ns = ns or {}

local RR = {}
RR.VERSION = 1
RR.ACTION_BAR_SECONDS = 10

local function empty(value)
    return value == nil or value == ""
end

local function dash(value)
    if empty(value) then return "-" end
    return tostring(value)
end

local function splitLines(text)
    local out = {}
    text = tostring(text or "")
    if text ~= "" and text:sub(-1) ~= "\n" then text = text .. "\n" end
    for line in text:gmatch("([^\n]*)\n") do table.insert(out, line) end
    return out
end

local function stableJoin(values, sep)
    if not values or #values == 0 then return "-" end
    table.sort(values)
    return table.concat(values, sep or ",")
end

function RR:NewRedactor()
    local redactor = { guid = {}, name = {}, guidN = 0, nameN = 0 }

    function redactor:Guid(value)
        if empty(value) then return "-" end
        value = tostring(value)
        if not self.guid[value] then
            self.guidN = self.guidN + 1
            self.guid[value] = string.format("G%02d", self.guidN)
        end
        return self.guid[value]
    end

    function redactor:Name(value)
        if empty(value) then return "-" end
        value = tostring(value)
        if not self.name[value] then
            self.nameN = self.nameN + 1
            self.name[value] = string.format("P%02d", self.nameN)
        end
        return self.name[value]
    end

    return redactor
end

local function formatSpell(ev)
    if not ev then return "-" end
    if not empty(ev.spell) and not empty(ev.name) then
        return tostring(ev.spell) .. "/" .. tostring(ev.name)
    end
    return dash(ev.spell or ev.name)
end

local function formatEvent(ev)
    if not ev then return "-" end
    return dash(ev.sub) .. ":" .. formatSpell(ev)
end

local function formatEndpoint(guid, name, redactor)
    local g = redactor:Guid(guid)
    if empty(name) then return g end
    return g .. "/" .. redactor:Name(name)
end

local function targetToken(row, action, redactor)
    local name = action and action.targetName or row.primaryTargetName
    if not empty(name) then return redactor:Name(name) end
    local guid = action and (action.targetGuid or action.target) or row.primaryTarget
    if not empty(guid) then return redactor:Guid(guid) end
    return dash(action and (action.targetClass or action.targetUnit) or row.primaryTargetClass)
end

local function firstPlayerAction(actions)
    if type(actions) ~= "table" then return nil end
    for _, action in ipairs(actions) do
        if action.unit == "player" then return action end
    end
    return actions[1]
end

local function formatAction(row, redactor)
    local action = firstPlayerAction(row and row.playerActions)
    if not action then return "-" end
    return dash(action.unit) .. ":" .. dash(action.actionKey) .. "->" .. targetToken(row, action, redactor)
end

local function formatCallouts(callouts)
    local out = {}
    for _, key in ipairs(callouts or {}) do table.insert(out, tostring(key)) end
    return stableJoin(out, ",")
end

local function formatRejectedCallouts(items)
    local out = {}
    for _, item in ipairs(items or {}) do
        table.insert(out, dash(item.key) .. ":" .. dash(item.reason))
    end
    return stableJoin(out, ",")
end

local function formatRejectedActions(items)
    local out = {}
    for _, item in ipairs(items or {}) do
        table.insert(out, dash(item.unit) .. ":" .. dash(item.key) .. ":" .. dash(item.reason))
    end
    return stableJoin(out, ",")
end

local function formatRejected(row)
    local parts = {}
    local callouts = formatRejectedCallouts(row and row.rejectedCallouts)
    local actions = formatRejectedActions(row and row.rejectedActions)
    if callouts ~= "-" then table.insert(parts, "callouts=" .. callouts) end
    if actions ~= "-" then table.insert(parts, "actions=" .. actions) end
    if #parts == 0 then return "-" end
    return table.concat(parts, ";")
end

local function formatBars(row, redactor)
    local out = {}
    for _, action in ipairs((row and row.playerActions) or {}) do
        table.insert(out, dash(action.unit) .. ":" .. dash(action.actionKey)
            .. "@" .. tostring(RR.ACTION_BAR_SECONDS) .. "s"
            .. "->" .. targetToken(row, action, redactor))
    end
    return stableJoin(out, ",")
end

function RR:BuildRows(events, replayRows, opts)
    opts = opts or {}
    local redactor = opts.redactor or self:NewRedactor()
    local rows = {}
    for _, row in ipairs(replayRows or {}) do
        local ev = (events or {})[row.index or 0] or {}
        table.insert(rows, {
            index    = row.index or 0,
            time     = string.format("%.1f", tonumber(row.ts or ev.ts or 0) or 0),
            event    = formatEvent(ev),
            source   = formatEndpoint(ev.src or ev.sourceGUID, ev.srcName or ev.sourceName, redactor),
            dest     = formatEndpoint(ev.dst or ev.destGUID, ev.dstName or ev.destName, redactor),
            mode     = dash(row.mode),
            comp     = dash(row.comp),
            target   = dash(row.primaryTargetClass) .. "/" .. targetToken(row, nil, redactor),
            action   = formatAction(row, redactor),
            callouts = formatCallouts(row.callouts),
            rejected = formatRejected(row),
            bars     = formatBars(row, redactor),
        })
    end
    return rows
end

function RR:Format(events, replayRows, opts)
    opts = opts or {}
    local rows = self:BuildRows(events, replayRows, opts)
    local lines = {
        "# ArenaCoachTBC replay report",
        "reportVersion=" .. tostring(self.VERSION),
        "source=" .. dash(opts.source),
        string.format("events=%d rows=%d", #(events or {}), #rows),
        "idx | time | event | src>dst | mode | comp | target | playerAction | callouts | rejected | bars",
    }
    for _, row in ipairs(rows) do
        table.insert(lines, string.format(
            "%03d | %s | %s | %s>%s | %s | %s | %s | %s | %s | %s | %s",
            row.index, row.time, row.event, row.source, row.dest, row.mode, row.comp,
            row.target, row.action, row.callouts, row.rejected, row.bars))
    end
    return table.concat(lines, "\n") .. "\n"
end

function RR:DiffText(actual, expected, maxSamples)
    local a, b = splitLines(actual), splitLines(expected)
    local diffs, samples = 0, {}
    local n = math.max(#a, #b)
    maxSamples = maxSamples or 5
    for i = 1, n do
        if a[i] ~= b[i] then
            diffs = diffs + 1
            if #samples < maxSamples then
                table.insert(samples, {
                    line = i,
                    actual = a[i] or "<missing>",
                    expected = b[i] or "<missing>",
                })
            end
        end
    end
    return diffs, samples
end

ns.ReplayReport = RR
return RR
