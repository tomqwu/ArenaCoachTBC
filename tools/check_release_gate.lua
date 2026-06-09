-- Validate the release workflow and release-note contract.
-- This is intentionally string-based so it runs under plain Lua 5.1 in CI.

local root = arg[1] or "."
root = root:gsub("/$", "")

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

local function requireText(text, needle, label)
    if not text or not text:find(needle, 1, true) then
        fail("missing %s: %s", label, needle)
    end
end

local function tocVersion()
    local toc = readFile(root .. "/ArenaCoachTBC/ArenaCoachTBC.toc")
    if not toc then
        fail("missing ArenaCoachTBC/ArenaCoachTBC.toc")
        return nil
    end
    local version = toc:match("^## Version:%s*([%w%._%-]+)") or toc:match("\n## Version:%s*([%w%._%-]+)")
    if not version then
        fail("ArenaCoachTBC.toc missing ## Version")
    end
    return version
end

local function changelogSection(changelog, version)
    local header = "## [" .. version .. "]"
    local startAt = changelog:find(header, 1, true)
    if not startAt then
        fail("CHANGELOG.md missing %s release notes", header)
        return ""
    end
    local sectionStart = changelog:find("\n", startAt, true)
    if not sectionStart then return "" end
    local rest = changelog:sub(sectionStart + 1)
    local nextHeader = rest:find("\n## %[")
    if nextHeader then
        rest = rest:sub(1, nextHeader - 1)
    end
    return rest
end

local function hasBulletedHeading(section, heading)
    local pattern = "###%s+" .. heading .. "%s*\n%s*%-"
    return section:match(pattern) ~= nil
end

local version = tocVersion()
local changelog = readFile(root .. "/CHANGELOG.md") or ""
if version then
    local section = changelogSection(changelog, version)
    local hasBehavior = hasBulletedHeading(section, "Added")
        or hasBulletedHeading(section, "Changed")
        or hasBulletedHeading(section, "Fixed")
        or hasBulletedHeading(section, "Removed")
    if not hasBehavior then
        fail("CHANGELOG.md [%s] needs a bulleted Added/Changed/Fixed/Removed section for player-facing release notes", version)
    end
    if not hasBulletedHeading(section, "Tests") then
        fail("CHANGELOG.md [%s] needs a bulleted Tests section with validation evidence", version)
    end
end

local workflow = readFile(root .. "/.github/workflows/release.yml") or ""
requireText(workflow, "tags: ['v*']", "stable tag trigger")
requireText(workflow, "Install release gate dependencies", "release dependency install step")
requireText(workflow, '- name: "Release gate: locale, package, release notes, and golden replay"', "quoted release metadata/golden gate step")
requireText(workflow, "lua5.1 tools/check_locales.lua", "locale gate command")
requireText(workflow, "lua5.1 tools/check_package_shape.lua", "package shape gate command")
requireText(workflow, "lua5.1 tools/check_release_gate.lua", "release gate command")
requireText(workflow, "lua5.1 tools/replay.lua --golden", "golden replay command")
requireText(workflow, '- name: "Release gate: tests and coverage"', "quoted release test/coverage step")
requireText(workflow, "lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua", "coverage test command")
requireText(workflow, "lua5.1 ArenaCoachTBC/Tests/StrategyEngine_spec.lua", "standalone strategy smoke command")
requireText(workflow, "Coverage below 99%", "coverage failure guard")
requireText(workflow, "Stable releases require CHANGELOG.md notes", "stable release-note failure")
requireText(workflow, "### Validation evidence", "release-note validation evidence section")
requireText(workflow, "BigWigs upload to CurseForge/Wago", "publish evidence text")
requireText(workflow, "Validate GitHub release zip shape", "zip shape gate")
requireText(workflow, "Run BigWigs packager (stable tag only - uploads to CurseForge / Wago)", "BigWigs publish step")
requireText(workflow, "Publish GitHub Release", "GitHub release step")

if workflow:find("- name: Release gate:", 1, true) then
    fail("release workflow step names containing ':' must be quoted for YAML parsing")
end

local packagerPos = workflow:find("Run BigWigs packager", 1, true)
if packagerPos then
    local packagerBlock = workflow:sub(packagerPos, math.min(#workflow, packagerPos + 900))
    if packagerBlock:match("continue%-on%-error:%s*true") then
        fail("stable BigWigs packager step must not use continue-on-error")
    end
    requireText(packagerBlock, "CF_API_KEY", "CurseForge token on publish step")
    requireText(packagerBlock, "WAGO_API_TOKEN", "Wago token on publish step")
end

local tests = readFile(root .. "/.github/workflows/test.yml") or ""
requireText(tests, "Release workflow gate", "test workflow release lint step")
requireText(tests, "Golden replay gate", "test workflow golden replay step")
requireText(tests, "lua5.1 tools/check_release_gate.lua", "Lua release lint in test workflow")
requireText(tests, "luajit tools/check_release_gate.lua", "LuaJIT release lint in test workflow")

local checklist = readFile(root .. "/docs/release-checklist.md") or ""
requireText(checklist, "GitHub release", "release checklist GitHub verification")
requireText(checklist, "CurseForge", "release checklist CurseForge verification")
requireText(checklist, "Wago", "release checklist Wago verification")
requireText(checklist, "local addon", "release checklist local install")
requireText(checklist, "ArenaCoachTBC-v", "release checklist exact zip naming")
requireText(checklist, "## Version:", "release checklist TOC version verification")

if #failures > 0 then
    io.stderr:write("Release gate check failed:\n")
    for _, msg in ipairs(failures) do
        io.stderr:write(" - " .. msg .. "\n")
    end
    os.exit(1)
end

print("Release gate check passed.")
