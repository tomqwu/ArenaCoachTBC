-- Validate release packaging metadata before a tag is published.
-- This catches the "approved but empty/missing CurseForge file" class of
-- mistakes locally and in CI.

local root = arg[1] or "."
root = root:gsub("/$", "")

local addonDir = root .. "/ArenaCoachTBC"
local tocPath = addonDir .. "/ArenaCoachTBC.toc"
local failures = {}

local function fail(fmt, ...)
    table.insert(failures, string.format(fmt, ...))
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

local function exists(path)
    local f = io.open(path, "rb")
    if not f then return false end
    f:close()
    return true
end

local function size(path)
    local f = io.open(path, "rb")
    if not f then return 0 end
    local n = f:seek("end") or 0
    f:close()
    return n
end

local function checkPkgmeta(path)
    local text = readFile(path)
    if not text then
        fail("missing package metadata: %s", path)
        return
    end
    local lineNo = 0
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        lineNo = lineNo + 1
        local hash = line:find("#", 1, true)
        if hash then
            local before = line:sub(1, hash - 1)
            if before:match("%S") then
                fail("%s:%d has an inline # comment; CurseForge pkgmeta parsing can drop package contents", path, lineNo)
            end
        end
    end
end

local toc = readFile(tocPath)
if not toc then
    fail("missing addon TOC: %s", tocPath)
else
    local version = toc:match("\n## Version:%s*([%w%._%-]+)") or toc:match("^## Version:%s*([%w%._%-]+)")
    if not version then
        fail("%s missing ## Version", tocPath)
    end

    if not toc:match("\n## Interface%-BCC:%s*%d+") and not toc:match("^## Interface%-BCC:%s*%d+") then
        fail("%s missing ## Interface-BCC for CurseForge BCC game-version detection", tocPath)
    end

    if not toc:match("\n## X%-Curse%-Project%-ID:%s*%d+") and not toc:match("^## X%-Curse%-Project%-ID:%s*%d+") then
        fail("%s missing numeric ## X-Curse-Project-ID", tocPath)
    end

    local shipped = 0
    for line in (toc .. "\n"):gmatch("([^\n]*)\n") do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and not trimmed:match("^##") and not trimmed:match("^#") then
            if trimmed:match("^Tests[\\/]") then
                fail("%s references test-only file in shipped TOC: %s", tocPath, trimmed)
            end
            if trimmed:match("^%.release[\\/]") or trimmed:match("^%.pkgmeta$") then
                fail("%s references packager-only path in shipped TOC: %s", tocPath, trimmed)
            end
            local rel = trimmed:gsub("\\", "/")
            local path = addonDir .. "/" .. rel
            if not exists(path) then
                fail("%s references missing file: %s", tocPath, trimmed)
            elseif size(path) == 0 then
                fail("%s references empty file: %s", tocPath, trimmed)
            else
                shipped = shipped + 1
            end
        end
    end
    if shipped < 20 then
        fail("TOC only ships %d files; package looks suspiciously empty", shipped)
    end

    if version then
        local versionFiles = {
            addonDir .. "/UI.lua",
            addonDir .. "/WeakAuraBridge.lua",
            addonDir .. "/ErrorReporter.lua",
            addonDir .. "/Tests/WeakAuraBridge_spec.lua",
            addonDir .. "/README.md",
        }
        for _, path in ipairs(versionFiles) do
            local text = readFile(path)
            if not text then
                fail("missing version-bearing file: %s", path)
            elseif not text:find(version, 1, true) then
                fail("%s does not contain addon version %s", path, version)
            end
        end
        local changelog = readFile(root .. "/CHANGELOG.md") or ""
        if not changelog:find("## [" .. version .. "]", 1, true) then
            fail("CHANGELOG.md missing ## [%s] release notes", version)
        end
    end
end

checkPkgmeta(root .. "/.pkgmeta")
checkPkgmeta(addonDir .. "/.pkgmeta")

local addonPkgmeta = readFile(addonDir .. "/.pkgmeta") or ""
if not addonPkgmeta:find("manual-changelog:", 1, true)
   or not addonPkgmeta:find("filename: CHANGELOG.md", 1, true) then
    fail("%s/.pkgmeta must point BigWigs at CHANGELOG.md for release notes", addonDir)
end

local workflow = readFile(root .. "/.github/workflows/release.yml") or ""
if not workflow:find("Validate GitHub release zip shape", 1, true) then
    fail("release workflow missing zip-shape validation step")
end
if not workflow:find("Prepare BigWigs packager checkout", 1, true) then
    fail("release workflow missing temporary addon-root packager checkout")
end
if workflow:find("ln -s ../.git", 1, true) or workflow:find("Expose .git to the addon subdir", 1, true) then
    fail("release workflow must not use the nested .git symlink packaging workaround")
end
local packagerPos = workflow:find("Run BigWigs packager", 1, true)
if not packagerPos then
    fail("release workflow missing BigWigs packager upload step")
else
    local packagerBlock = workflow:sub(packagerPos, math.min(#workflow, packagerPos + 800))
    if packagerBlock:match("continue%-on%-error:%s*true") then
        fail("BigWigs packager step must not continue-on-error on stable tags")
    end
    if not packagerBlock:find("-t .packager", 1, true) then
        fail("BigWigs packager step should use the prepared addon-root checkout")
    end
    if not packagerBlock:find("-g bcc", 1, true) then
        fail("BigWigs packager step should force BCC game-version upload with -g bcc")
    end
end

if #failures > 0 then
    io.stderr:write("Package shape check failed:\n")
    for _, msg in ipairs(failures) do
        io.stderr:write(" - " .. msg .. "\n")
    end
    os.exit(1)
end

print("Package shape check passed.")
