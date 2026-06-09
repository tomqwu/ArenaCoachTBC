# Arena Acceptance Fixtures

ArenaCoachTBC uses two replayable test shapes for arena-quality work:

- `ArenaCoachTBC/Tests/Fixtures/arena_acceptance.lua` holds curated arena snapshots: roster, enemy team, PvP context, observations, expected personal actions, teammate actions, forbidden callouts, forbidden actions, and rejected reason codes.
- `ArenaCoachTBC/Tests/Fixtures/*.golden.txt` holds full golden replay reports produced from SavedVariables recordings through `tools/replay.lua`.

Use acceptance snapshots when a screenshot or clip shows a wrong decision and the important state can be described directly. Use golden replays when the timing of combat-log events matters.

## Add an Acceptance Snapshot

1. Copy the closest scenario in `arena_acceptance.lua`.
2. Keep the roster exact: only include teammates that were actually in the match.
3. Mark the context with `pvpContext`, `bracket`, `combatPhase`, and observations such as `healerPressure`, `windfuryActive`, `msActiveOn`, or `hojReady`.
4. Add expected `player` and teammate `actions`.
5. Add `forbiddenCallouts` and `forbiddenActions` for every impossible warning that must stay suppressed.
6. Add `rejectedCallouts` when a blocked warning should leave a stable debug reason.
7. Run `lua5.1 ArenaCoachTBC/Tests/run_all.lua`.

Reference tokens such as `@arena2` or `@party2` resolve to that unit's GUID inside the test harness.

## Add a Golden Replay

1. In game before queueing, run `/acc trace on`, `/acc record on`, and `/combatlog`.
2. After the match, `/reload` or logout so SavedVariables are written.
3. Run:

```sh
lua5.1 tools/replay.lua --update-golden ArenaCoachTBC/Tests/Fixtures/<name>.golden.txt <path/to/ArenaCoachTBC.lua>
```

4. Review the report. It should be redacted and should explain event, target, personal action, callouts, rejected reasons, and action bars.
5. Commit the SavedVariables fixture only if it is sanitized and small enough for the repo. Otherwise reduce it to an acceptance snapshot.
6. Lock it with:

```sh
lua5.1 tools/replay.lua --golden ArenaCoachTBC/Tests/Fixtures/<name>.golden.txt <path/to/fixture.lua>
```
