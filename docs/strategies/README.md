# Strategy primers — per-comp game plans

The engine's recommendation flows from the same data every match, but humans benefit from a primer they can read out-of-game. These per-comp pages document what each enemy team does, the engine's default plan against it, and the variations that the `ownVariants` table in `Data/Strategies.lua` applies based on **your** team archetype.

This directory is a starting point — contributions welcome. Each comp gets its own markdown file with a shared section structure so they're skim-friendly.

---

## File template

Each primer follows this layout:

1. **Identity** — class composition, common variations (e.g. "RMP" vs "RMP-Dest")
2. **What they want to do** — the opener and kill condition
3. **What kills you** — the failure modes you should be DEFEND'ing against
4. **Engine's default plan** — what `Data/Strategies.lua` says for this comp
5. **Per-archetype variations** — how the plan shifts when YOU are MELEE_CLEAVE vs CASTER_CLEAVE vs DRAIN vs JUNGLE vs DOUBLE_HEALER
6. **Callouts you'll see** — locale keys the engine emits in this match
7. **Common mistakes** — what a coach would yell at you for

---

## Comps with primers

| Comp | File | Status |
|---|---|---|
| RMP (Rogue / Mage / Priest) | [`rmp.md`](rmp.md) | starter primer |
| RMP-Disc (spec-confirmed variant) | (in `rmp.md`) | covered |
| WMS (Warrior / Mage / Shaman) | _pending_ | open an issue / PR |
| TSG (Warrior / DK / Paladin) | _pending_ | open an issue / PR |
| Jungle (Hunter / Feral / Healer) | _pending_ | open an issue / PR |
| RLS (Rogue / Warlock / Shaman) | _pending_ | open an issue / PR |
| DRAIN (Affli / Disc-Shadow Priest) | _pending_ | open an issue / PR |
| BG cleave (Warsong / Arathi pugs) | _pending_ | open an issue / PR |

Other comps are catalogued in [`Data/Strategies.lua`](../../ArenaCoachTBC/Data/Strategies.lua). Each `Strategies.comps` entry is a real engine signature; if you want to write a primer for one that's not in the table above, the structure already exists in code — the markdown is just the human-readable companion.

---

## How the engine matches your match to a comp

1. `Strategies:Identify(enemies)` walks the catalog and scores each candidate against the live class set + (when spec inference fires) the observed specs.
2. The best match becomes `state.comp`; `compConfidence` reflects how exclusive that match is.
3. `compSpecConfirmed = true` means the match required spec inference — e.g. RMP_DISC_3V3 only fires once the engine has seen Penance / Pain Suppression / Power Word: Shield from the priest. Until then you'll see the plain `RMP` match.
4. `state.ownArchetype` is computed in parallel from your party's capabilities via `OwnComps:Infer` and `OwnComps:Identify`.
5. If the matched comp has an `ownVariants` table for your archetype, the engine pulls overrides from there.

---

## Contributing a primer

1. Copy `rmp.md` as a template
2. Fill in the 7 sections for your comp
3. Add an entry to the table above
4. Add the link from your primer to `Strategies.comps[<your-comp-id>]` so readers can jump to the engine catalog entry
5. PR
