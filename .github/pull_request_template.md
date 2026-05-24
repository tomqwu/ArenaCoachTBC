# Summary

<!-- 1-3 bullet points describing the change and why. -->

# Test plan

- [ ] `lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua` passes locally
- [ ] `luacov && tail -n 5 luacov.report.out` shows Total >= 99%
- [ ] Manual smoke (if user-visible behaviour changed): `docs/manual-smoke.md`

# Checklist

- [ ] Tests added or updated
- [ ] `CHANGELOG.md` updated under `[Unreleased]` (or PR title includes `[skip-changelog]`)
- [ ] No automation introduced (`CastSpellByName`, `RunMacroText`, programmatic targeting/casting are forbidden)
- [ ] New spell IDs include a source comment (Wowhead URL or in-game tooltip)
- [ ] New locale keys added to every existing locale file (or marked TODO with comment)
- [ ] If this changes WeakAura bridge surface (`_G.ArenaCoachTBC.*`), documented in CHANGELOG as a contract change

# Related issues

<!-- Closes #N or Refs #N -->
