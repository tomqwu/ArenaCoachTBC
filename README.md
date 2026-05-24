# wow_tbc_arena_pvp_strategy

A World of Warcraft addon — **ArenaCoachTBC** — that coaches a 5v5
melee cleave team during TBC Classic / TBC Anniversary arena.

Team comp it's tuned for:

- Arms Warrior
- Enhancement Shaman
- Retribution Paladin
- Restoration Druid
- Discipline Priest

> ⚠️ Advice only. The addon does **not** cast spells, target enemies,
> click protected buttons, or modify secure macros. It emits visual,
> audio, and text recommendations — nothing else.

## What it does

- Watches arena state via WoW events (`ARENA_OPPONENT_UPDATE`,
  `COMBAT_LOG_EVENT_UNFILTERED`, `UNIT_AURA`, `PLAYER_REGEN_*`, etc.)
- Scores every enemy with a transparent weighted sum
  (role + vulnerability + team synergy − danger)
- Emits one of `OPEN | KILL | SWAP | DEFEND | RESET` with a primary
  target, swap candidate, callouts, and a burst-go/no-go flag
- Tracks enemy cooldowns (Ice Block, Divine Shield, BoP, PvP trinket,
  Death Coil, NS, Innervate, Counterspell, etc.) from the combat log
- Tracks basic DR categories (STUN, FEAR, DISORIENT, INCAPACITATE,
  ROOT, CYCLONE) with a configurable reset window
- Publishes the live recommendation through `_G.ArenaCoachTBC`
  and `WeakAuras.ScanEvents("ACC_RECOMMENDATION", rec)` so a WA can
  render it

## Repository layout

```
ArenaCoachTBC/        <- the actual addon folder (drop in Interface/AddOns/)
├── ArenaCoachTBC.toc
├── Core.lua                 -- event wiring + slash commands + state
├── EventBus.lua             -- tiny pub/sub over one WoW frame
├── StrategyEngine.lua       -- scoring + recommendation builder (tested)
├── CooldownTracker.lua      -- observe combat log -> enemy CDs
├── DRTracker.lua            -- diminishing return categories
├── UI.lua                   -- movable frame + icon rows
├── Options.lua              -- Blizzard interface panel
├── WeakAuraBridge.lua       -- exposes _G.ArenaCoachTBC API
├── Data/
│   ├── Spells.lua           -- centralized spell ID database
│   ├── Classes.lua          -- class -> role / armor / specs
│   └── Strategies.lua       -- comp signatures and callouts
├── Locales/{enUS,zhCN}.lua
├── Tests/StrategyEngine_spec.lua
└── README.md                <- full installation/usage doc
```

## Quick start

1. Copy the `ArenaCoachTBC` folder into
   `<WoW>/_classic_/Interface/AddOns/`.
2. Log in, `/acc help`, drag the frame, `/acc lock`.
3. Try `/acc test` to see recommendations for five sample enemy comps.

See **[ArenaCoachTBC/README.md](ArenaCoachTBC/README.md)**
for the full slash-command list, scoring weights, WeakAura snippets,
spell-ID extension guide, and limitations.

## Running the tests

The strategy engine runs outside the WoW client with stubbed APIs:

```bash
lua5.1 ArenaCoachTBC/Tests/StrategyEngine_spec.lua
```

Expected:

```
Results: 10 passed, 0 failed
```

## License

MIT.
