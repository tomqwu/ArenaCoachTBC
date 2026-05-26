-- ArenaCoachTBC - ErrorReporter
--
-- Captures Lua errors into a ring buffer in SavedVariables so users can paste
-- a sanitised /acc bugreport into a GitHub issue without manually copying
-- BugSack output. The capture surface is intentionally small - higher-level
-- modules call ER:Capture(err, ctx) from within pcall - so this file has
-- zero coupling to WoW APIs.

local ADDON_NAME, ns = ...
ns = ns or {}
ns.ErrorReporter = ns.ErrorReporter or {}

local ER = ns.ErrorReporter
ER.MAX_ENTRIES = 20

-- ----- store -----

local function db()
    _G.ArenaCoachTBCDB = _G.ArenaCoachTBCDB or {}
    _G.ArenaCoachTBCDB.errors = _G.ArenaCoachTBCDB.errors or { log = {} }
    return _G.ArenaCoachTBCDB.errors
end

function ER:Reset() db().log = {} end
function ER:Recent(n)
    local log = db().log or {}
    n = n or self.MAX_ENTRIES
    if #log <= n then return log end
    local out = {}
    for i = #log - n + 1, #log do table.insert(out, log[i]) end
    return out
end

-- ----- sanitisation -----
-- Strips "<Name>-<Realm>" patterns, raw Player-... GUIDs, and any
-- known friendly/enemy character names from the supplied text.

local function escapePattern(s) return (s:gsub("(%W)", "%%%1")) end

function ER:Sanitize(text)
    if type(text) ~= "string" then return text end
    -- Player GUID format from CLEU: Player-12345-67890ABC
    text = text:gsub("Player%-%w+%-%w+", "Player-***")
    -- Bare guid- prefixed tokens used in tests + simulator
    text = text:gsub("guid%-%w+", "guid-***")
    -- Realm-suffix: "Name-Realm" - replace whole match with ***-***.
    -- Use word boundaries that match WoW name characters (letters + apostrophe).
    text = text:gsub("([%a']+)%-([%a']+)", "***-***")
    -- Known character names from the current state
    if _G.ArenaCoachTBCDB and _G.ArenaCoachTBCDB._knownNames then
        for _, name in ipairs(_G.ArenaCoachTBCDB._knownNames) do
            if name and #name > 1 then
                text = text:gsub(escapePattern(name), "***")
            end
        end
    end
    return text
end

-- Register names that should be masked (called by Core when it refreshes
-- enemies/friendlies). Idempotent; latest-call wins.
function ER:SetKnownNames(names)
    _G.ArenaCoachTBCDB = _G.ArenaCoachTBCDB or {}
    _G.ArenaCoachTBCDB._knownNames = names or {}
end

-- ----- capture -----

function ER:Capture(err, ctx)
    if not err then return end
    local store = db()
    store.log = store.log or {}
    local entry = {
        ts      = (type(GetTime) == "function") and GetTime() or os.time(),
        message = self:Sanitize(tostring(err)),
        context = ctx and self:Sanitize(tostring(ctx)) or nil,
    }
    table.insert(store.log, entry)
    while #store.log > self.MAX_ENTRIES do table.remove(store.log, 1) end
    return entry
end

-- ----- payload -----

local function buildHeader()
    local addonVer = "2.7.2"
    if ns.Spells and ns.WeakAuraBridge and _G.ArenaCoachTBC and _G.ArenaCoachTBC.GetVersion then
        addonVer = _G.ArenaCoachTBC.GetVersion()
    end
    local client = "unknown"
    if type(GetBuildInfo) == "function" then
        local v, b = GetBuildInfo()
        client = string.format("%s build %s", tostring(v), tostring(b))
    end
    return string.format("- **Addon**: ArenaCoachTBC %s\n- **Client**: %s", addonVer, client)
end

function ER:Format(maxErrors)
    maxErrors = maxErrors or 5
    local entries = self:Recent(maxErrors)
    local lines = {
        "## ArenaCoachTBC bug report",
        "",
        buildHeader(),
        "",
        string.format("### Last %d errors (sanitised)", #entries),
        "",
    }
    if #entries == 0 then
        table.insert(lines, "_No captured errors._")
    else
        for i, e in ipairs(entries) do
            table.insert(lines, string.format("**%d.** `[ts=%s]` %s",
                i, tostring(e.ts), tostring(e.message)))
            if e.context then
                table.insert(lines, string.format("   context: %s", tostring(e.context)))
            end
        end
    end
    return table.concat(lines, "\n")
end
