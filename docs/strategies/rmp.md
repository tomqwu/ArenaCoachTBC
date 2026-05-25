# RMP — Rogue · Mage · Priest

The defining 3v3 comp of TBC. High kill setup ceiling, light defensive baseline. ArenaCoachTBC's catalog has two entries for this team:

- **`RMP`** — class-only match, fires immediately at gate-open
- **`RMP_DISC_3V3`** — spec-confirmed variant, fires once the engine has observed a Disc-flavoured cast from the priest (Penance, Pain Sup, Power Word: Shield)

See [`Data/Strategies.lua`](../../ArenaCoachTBC/Data/Strategies.lua) for the live engine entries.

---

## 1 · Identity

| Slot | Class | Typical spec | What it brings |
|---|---|---|---|
| Damage | Rogue | Subtlety / Combat | Cheap Shot / Kidney Shot / Blind, Cloak of Shadows |
| Damage | Mage | Frost / Arcane Surge | Polymorph, Counterspell, Ice Block, Frostbolt windups |
| Healing | Priest | Disc / Holy / Shadow | Penance, Pain Sup, Mass Dispel, Shadow Word: Death, Mind Control |

**Common variants** (catalog-level distinct comps for these):
- **RMP-Disc** — kill priest is the default plan; the Disc cooldown stack (Pain Sup, BoP from teammates if any, MD on hex) makes the priest fragile but punishing to mistime
- **RMP-Holy** — kill mage instead; holy lacks Pain Sup so it's the easier kill but harder to lock out
- **RMP-Shadow** — kill the priest; SPriest has no hardcast heals, so kill window is shorter

---

## 2 · What they want to do

**The opener (60% of their plan):**
1. Mage opens with `Polymorph` on the off-healer (usually you, if you're the healer)
2. Rogue stealth-saps the kill target (your DPS) or you
3. Mage `Counterspell`s the kicked spell
4. Rogue `Cheap Shot` → `Kidney Shot` chain on the kill target
5. Priest dispels your team's defensives mid-burst
6. Mage `Ice Lance` + `Frostbolt` for the burst window

**Kill condition** — they win when they catch your healer in 2 CCs back-to-back (sap → mage poly, or kidney → mind control) while their DPS dumps on your team's frailest target.

---

## 3 · What kills you

Three failure modes, in order of frequency:

1. **Healer eaten by chained CC** — Sap into Mage Poly is the canonical sequence; if you can't trinket the right link, you lose. Engine flips to `DEFEND` when it detects this pattern via `Patterns.lua`.
2. **Rogue burst goes uninterrupted** — Cheap → Kidney → Eviscerate windows on your cloth DPS while the mage spreads pressure. Engine raises `urgency` to URGENT on this.
3. **Mind Control off the map** — Priest grabs you, walks you off a ledge. Doesn't fire in Nagrand / Blade's Edge; deadly in Ruins / Dalaran.

---

## 4 · Engine's default plan

From `Strategies.comps.RMP`:

- **Open target**: PRIEST (class-only) → confirmed Disc Priest (spec-confirmed)
- **Swap target**: MAGE if priest goes immune (Ice Block off the team), else stay on priest
- **Default chain**: `CHAIN_RMP_SAP_INTO_KIDNEY` — sap off-healer / over-extended DPS, kidney the priest. ~62% expected probability vs a baseline priest profile.
- **Alternative chain**: `CHAIN_RMP_FEAR_INTO_BURST` — only viable when your team has a priest of your own (Psychic Scream) and the enemy mage has burned trinket.

---

## 5 · Per-archetype variations

Lookup in `Strategies.comps.RMP.ownVariants` (and `RMP_DISC_3V3.ownVariants`):

| Your archetype | Plan shift |
|---|---|
| **MELEE_CLEAVE** | Open priest hard, train through Pain Sup, save MS for post-trinket window. `CALL_BURST_BLOCK_INCOMING` fires if the priest's Ice-Block-tier defensives are up |
| **CASTER_CLEAVE** | Cyclone off-healer, sheep priest if you're Boomkin/Lock, kill mage second. Ground totem priority — RMP eats casters without grounding |
| **DRAIN** | Don't try to kill — outlast. Mana-burn priest, Death Coil mage on cast. `CALL_LOW_MANA_PUSH` fires when their priest hits 30% mana |
| **JUNGLE** | Trap the priest, scatter the mage's sheep / counterspell, kill rogue on engage (lowest defensive ceiling). Hunter pet stuns are gold here |
| **DOUBLE_HEALER** | Same drain plan but harder. Mana burn through Spirit Tap timing — engine knows when priest's MP5 is rolling and adjusts the burn schedule |

---

## 6 · Callouts you'll see

Localised keys (English / Chinese pairs in `Locales/{enUS,zhCN}.lua`):

- `CALL_TREMOR_FEAR` — "Tremor for fear" / "陷阱图腾解恐惧" — when their priest screams and you have a shaman
- `CALL_GROUND_POLY` — "Ground the poly" / "落雷止变" — grounding totem before the mage casts Polymorph
- `CALL_PURGE` — "Purge %s" / "驱散 %s" — shaman/priest purging Pain Sup or PWS
- `CALL_DISP_FROST` — "Dispel the slow" / "驱散冰冻" — clear Frostbolt slow off the kill target
- `CALL_HOJ_KILL` — "HoJ kill target" / "无敌锤上焦点" — paladin Hammer of Justice on the priest
- `CALL_SAVE_TREMOR_HOJ` — "Save Tremor for HoJ" / "陷阱图腾留给制裁之锤" — profile-driven, fires once the priest has shown they trinket Fear
- `BURST_NOW` — "BURST NOW" / "立即爆发" — gates passed (MS active, no incoming pressure, profile says priest is OOM on cooldowns)

---

## 7 · Common mistakes

What a coach would yell at you for, in this match:

- **Wasting Tremor on the first fear** — if you have a Disc priest profile that shows `trinketsFear=0.9`, that's wasted Tremor. Engine fires `CALL_SAVE_TREMOR_HOJ` to remind you. Build the profile by playing the team more than once with `/acc record on`.
- **Forcing burst into Pain Sup** — burst gate would have blocked this. If you fired anyway, `burstBlockedBy = "pain_sup_active"` shows in `/acc trace dump`.
- **Switching to mage too early** — RMP-Disc's Pain Sup is short (2 min CD on Disc). If you swap pre-cooldown, they trade trinket and PWS for free. Engine's SWAP only fires after `swap_target_advantage > 30 score points`.
- **Not pre-emptively defensive** — Polymorph + Sap is a known opener. If you see two enemies stealth/in-formation at gate-open, `OPEN` mode already says "Trinket if Sapped first" via the chain narration.

---

## Live engine reference

- Catalog entry: [`Data/Strategies.lua` → `Strategies.comps.RMP`](../../ArenaCoachTBC/Data/Strategies.lua)
- Spec-confirmed variant: same file, `RMP_DISC_3V3`
- Chain definitions: `Chain.lua` + the `chains` array on each comp entry
- Patterns that fire here: `Patterns.lua` — `RMP_CHEAP_BLIND`, `RMP_SAP_INTO_POLY`
- Tendencies tracked in the priest's profile: `trinketsFear`, `kicksFirstHeal`
