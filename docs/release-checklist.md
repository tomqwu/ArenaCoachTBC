# Release Checklist

Use this before every stable tag. The goal is to prove the addon is useful, packaged, published, and locally installable before a release is considered done.

## Before Tagging

- Update `CHANGELOG.md` with a versioned section for the release. Include player-facing behavior changes plus a `### Tests` section with the validation evidence.
- Verify version-bearing files match the TOC version: `ArenaCoachTBC/ArenaCoachTBC.toc`, `ArenaCoachTBC/UI.lua`, `ArenaCoachTBC/WeakAuraBridge.lua`, `ArenaCoachTBC/ErrorReporter.lua`, `ArenaCoachTBC/README.md`, and version-sensitive tests.
- Run the local gate:

```bash
rm -f luacov.stats.out luacov.report.out
lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua
luacov
tail -n 25 luacov.report.out
lua5.1 tools/replay.lua --golden ArenaCoachTBC/Tests/Fixtures/replay_tiny.golden.txt ArenaCoachTBC/Tests/Fixtures/replay_tiny.lua
lua5.1 tools/check_locales.lua
lua5.1 tools/check_package_shape.lua
lua5.1 tools/check_release_gate.lua
lua5.1 ArenaCoachTBC/Tests/StrategyEngine_spec.lua
git diff --check
```

## Publish

- Commit the release bump on `main`.
- Push `main`.
- Create and push the annotated stable tag, for example `vX.Y.Z`.
- Wait for the tag `Release` workflow to complete successfully. Stable tags must fail if package shape, release notes, golden replay, coverage, GitHub release upload, CurseForge upload, or Wago upload fails.

## Verify

- Open the GitHub release and confirm `ArenaCoachTBC-v<version>.zip` exists.
- Confirm the release notes include player-facing changes, `### How to test`, and `### Validation evidence`.
- Confirm the GitHub Actions `Release` run succeeded for the stable tag.
- Confirm CurseForge and Wago show the uploaded version after their review delay.

## Install The Exact Release

Replace the local addon with the exact GitHub release zip. For this workstation the local addon root is `F:\World of Warcraft\_anniversary_\Interface\AddOns`.

```powershell
$addonRoot = 'F:\World of Warcraft\_anniversary_\Interface\AddOns'
$version = 'vX.Y.Z'
$zip = Join-Path $env:TEMP "ArenaCoachTBC-$version.zip"
$url = "https://github.com/tomqwu/ArenaCoachTBC/releases/download/$version/ArenaCoachTBC-$version.zip"
Invoke-WebRequest -Uri $url -OutFile $zip
Remove-Item -LiteralPath (Join-Path $addonRoot 'ArenaCoachTBC') -Recurse -Force
Expand-Archive -LiteralPath $zip -DestinationPath $addonRoot -Force
Select-String -LiteralPath (Join-Path $addonRoot 'ArenaCoachTBC\ArenaCoachTBC.toc') -Pattern '^## Version:'
```

The installed folder should contain the addon files, should not contain `Tests`, and the TOC should print the release `## Version:`.
