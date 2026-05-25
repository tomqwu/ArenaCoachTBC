# ArenaCoachTBC

A real-time arena strategy coach for **World of Warcraft TBC Classic / TBC Anniversary**. Watches the fight, identifies the enemy comp (including spec), picks a kill target, plans CC chains, and emits a recommendation: `OPEN | KILL | SWAP | DEFEND | RESET`.

> **v2.0 ships the engine-depth roadmap.** Your coach now learns your opponents. A team you've played 20 times that always trinkets Fear stops getting the generic "tremor for fear" callout — Tremor gets saved for HoJ instead. A mage that consistently Ice Blocks at 30% causes the burst gate to hold. None of this is hardcoded — it learns per-team from observed combat, no character names persisted.

> ⚠️ **Advice only.** The addon never casts spells, never targets enemies, never clicks protected buttons, never modifies secure macros. It emits visual + audio + text recommendations. That's it.

---

## Works in every PvP context

| Context | Behaviour |
|---|---|
| **Arena 2v2 / 3v3 / 5v5** | Full engine: comp ID, spec inference, chain planning, opponent profiles, lookahead, burst gating, all visual + audio alerts. |
| **Battlegrounds** (WSG/AB/AV/EotS) | Engine adapts: nameplate-based enemy discovery, flag-carrier priority (+200), low-HP straggler boost, BG-specific callouts (`CALL_FLAG_CARRIER_LOW`, `CALL_BG_DEFEND`). Class-prior tier kicks in when the team-signature profile lacks samples (PUG'd rosters). |
| **World PvP / duels** | Engine simplifies: single-target focus, no SWAP thrash, no comp matching. `DUEL_REQUESTED` auto-engages. |
| **Arena-only alerts** stay gated to arena | Screen flash + voice cues only fire when `IsActiveBattlefieldArena()` is true. No spurious red flash in WSG. |

---

## Works with any team composition

Earlier versions documented a specific comp (WAR/ENH/RET/RDRU/DISC melee cleave) as the "tuned-for" team. **v2 doesn't have a tuned-for comp.** `OwnComps:Infer` walks your party and returns a capability table — `hasMortalStrike`, `hasBloodlust`, `hasFreedom`, `hasMassDispel`, `hasMainHealer`, etc. — then `OwnComps:Identify` picks an archetype:

| Archetype | When it fires | What it changes |
|---|---|---|
| `MELEE_CLEAVE` | ≥2 melee + a healer | Aggressive kill-pressure callouts; prefer healer opens |
| `CASTER_CLEAVE` | ≥2 casters + a healer | Ground/dispel-heavy callouts; off-healer CC priority |
| `DRAIN` | Affli/SP-style sustain | Mana-burn / outlast callouts; no aggressive opens |
| `JUNGLE` | Hunter + Feral + healer | Trap + scatter setup callouts |
| `DOUBLE_HEALER` | 2+ healers | Mana drain plan |

The 100+ enemy comp catalog in `Data/Strategies.lua` carries `ownVariants` so the same enemy team gets different advice depending on your archetype. There's no hardcoded "if class is X" anywhere in the engine — everything goes through capability inference. **Run any comp; the engine adapts.**

---

## Installation (one-time setup, ~2 min)

1. **Download** the latest zip from the [Releases page](https://github.com/tomqwu/ArenaCoachTBC/releases) — or use the [CurseForge listing](https://www.curseforge.com/wow/addons/arenacoachtbc).
2. **Extract the `ArenaCoachTBC/` folder** (the inner one containing `ArenaCoachTBC.toc`) into your WoW addons directory:
   - **TBC Classic / Anniversary**: `<WoW install>/_classic_/Interface/AddOns/`
   - **macOS**: typically `/Applications/World of Warcraft/_classic_/Interface/AddOns/`
   - **Windows**: typically `C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\`
3. **Restart the client** (or `/reload` if already in). Your AddOns list should now have `ArenaCoachTBC` enabled.
4. If you see "Out of Date" at character-select, enable **Load out of date AddOns**. Or bump `## Interface: 20505` in `ArenaCoachTBC.toc` to match your client.

---

## First-run checklist (~3 min)

```
/acc help              -- show all slash commands
/acc test              -- 14s scripted UI demo
/acc unlock            -- enable dragging
                          (drag the frame)
/acc lock              -- freeze position
/acc selftest verbose  -- in-client validation
```

After `/acc test` the recommendation frame appears center-screen and walks through 7 beats over 14 seconds (mode flips, BURST_NOW pulse, DEFEND screen flash, profile callout) — you'll see every kind of UI transition the addon emits. **If you see this demo, the addon is loaded and working.** Move the frame to a corner you'll actually look at during a match.

---

## Daily usage during arena

You don't run anything during a match. The addon auto-engages on `PLAYER_ENTERING_WORLD` when `UPDATE_BATTLEFIELD_STATUS` confirms you're in a rated/skirmish arena. The frame stays hidden outside arena (unless `/acc toggle` forced it on).

**What you'll see during a match:**

1. **Pre-combat (arena gates closed)**: Mode = `OPEN` (yellow), target = the comp's default open target. Plan your opener.
2. **Active**: Mode flips to `KILL` (red) / `SWAP` (orange) / `DEFEND` (blue). The big text shows who to attack; the stats row shows target HP% and kill probability; the callouts row shows utility cues; the chain block shows the canonical CC sequence; the comp badge shows whether the engine has confirmed enemy specs.
3. **Burst window**: `BURST READY` pill in the stats row — every burst gate has passed (kill probability ≥ threshold, chain ready, no incoming pressure). A loud sound cue + the red KILL edge glow flash up around the screen edges.
4. **Defensive**: When your healer is being trained or enemy lust pops, mode flips to `DEFEND` (blue). The edge glow turns blue; callouts shift to Pain Sup / BoP / peel reminders.

---

## Slash commands

| Command | Description |
|---|---|
| `/acc help` | Print the command list |
| `/acc toggle` | Show / hide the recommendation frame |
| `/acc lock` / `/acc unlock` | Freeze / release the frame for dragging |
| `/acc test` | 14s DBM-style UI demo (mode flips, BURST_NOW, DEFEND flash) |
| `/acc test bg` | BG-mode walk-through (flag carrier + low-HP straggler + CALL_BG_DEFEND) |
| `/acc test world` | World PvP walk-through (single-target focus) |
| `/acc test print` | Legacy chat-only summary |
| `/acc enemy <c1> <c2> ...` | Simulate a custom enemy comp |
| `/acc reset` | Wipe SavedVariables + `/reload` |
| `/acc strategy safe\|balanced\|greedy` | Manual aggression override |
| `/acc glow [on\|off]` | Toggle the mode-coloured screen edge glow (v2.2+) |
| `/acc nameplate [on\|off]` | Toggle nameplate highlights for KILL / SWAP targets (v2.2+) |
| `/acc debug` | Toggle debug print |
| `/acc selftest [verbose]` | In-client validation suite |
| `/acc simulate [key\|stop]` | Replay a scripted scenario |
| `/acc trace [on\|off\|dump\|clear\|status]` | Decision-trace ring buffer |
| `/acc record [on\|off\|dump\|clear\|status]` | CLEU recording for offline replay |
| `/acc whatif skip <i>` | Counterfactual replay (skip event #i) |
| `/acc bugreport` | Sanitised error report for issues |

---

## Configuration

All settings persist in `ArenaCoachTBCDB` (SavedVariables). They're forward-compatible — v1 saved-variables load on v2 without resetting your tuning.

**Key knobs** (editable via `Interface → AddOns → ArenaCoachTBC`):

| Key | Default | Description |
|---|---|---|
| `strategy.ratingAggression` | `"auto"` | `"auto"` reads `GetPersonalRatedInfo()` and tunes thresholds. Or pin: `"greedy"` / `"balanced"` / `"safe"` / a number. |
| `strategy.callBurstOnlyWhenMSActive` | `true` | Require Mortal Strike debuff on the target before `BURST_NOW`. |
| `strategy.requireWindfuryNearby` | `true` | Require Windfury Totem before burst. |
| `strategy.peelTriggerWindow` / `peelTriggerDamage` | `5` / `3` | Train detection sensitivity (damage events × window → DEFEND). |
| `strategy.lookaheadEnabled` | `true` | Engage the M10 expectimax over chain × opponent response. |
| `frame.compactMode` | `false` | Hides the friendly/enemy cooldown icon rows. |
| `alerts.sound` / `alerts.screenFlash` | `true` / `true` | Voice cue + URGENT-mode screen flash. |
| `alerts.edgeGlow` / `alerts.nameplate` | `true` / `true` | v2.2 mode-coloured edge glow + nameplate highlight. |

---

## Spell names and localisation

Spell IDs in `Data/Spells.lua` are **universal** — a single integer that's the same across every WoW locale. The names shown in the UI come from the **WoW client's locale** via `GetSpellInfo(spellID)` — so if you run a Chinese client you'll see Chinese spell names (e.g. *闷棍*), and an English client shows *Sap*. **The addon doesn't hard-code spell text anywhere.**

Same for **mouse-over tooltips on the icon rows** — they call `GameTooltip:SetSpellByID(spellID)` so the tooltip is the canonical Blizzard popup in your client's locale (icon + name + flavor text).

User-facing **callout strings** (e.g. "Tremor for fear", "Burst the priest") are addon-locale-keyed: `Locales/enUS.lua` is canonical with 112 keys, `Locales/zhCN.lua` is in parity. The addon picks the locale from `GetLocale()` automatically; override with `db.language` if needed.

---

## Customising the display with WeakAuras

The addon publishes its full recommendation through `_G.ArenaCoachTBC`. Build your own HUD by consuming the getters.

### Paste-ready import strings

5 ready-made templates. In WoW: `/wa` → **Import** (upper-left) → paste a string → **Import** in the preview dialog. Each is independent — grab any subset.

**1. Mode badge** — big colour-coded mode + target line. Hides outside arena.

```
!WA:2!fsvZUnnqqy1csGcsvacfjkhyLLaksOK2qvLALQq5h3QaPjbh3I4uyT9A7LAVR7(tBtvfh6jUsFeYJqKqCNNGkEe4rGNag)dn0FeS(Wo7mZ34zMVz3zkFFVp)4FG1QqUOxIIYzYsJD5mpAUSdi7tdknHY85IyCQ2snI4yVnovljdDJWszydj9iszRyDKIw2clim8hgNzMh7GvHzUYi7teH)mrq8jcB(2jEyfj8ujjYVpNYuonn7ABA5i5AHlXHgNWfQXsTJfjipVuCxies4WT7)WtucAqaCC(Nkke3PHAucXXvlv84j5BdZujvyLwA5gsC31cYdM6SYjFXxZCtlOfEEjeI6JyCfA4MvQNM)n5y3q7gnrQqcdjikTGH8XrscIW8a)J4U4ium3JGw)kOQSjrTfyklYfGZC9tRJy0ieM5D(zdlZbM2gLGW6KLAYKx1Vt93BAn0YCtZUdB1Eq9gDmB9c0fuB2TqB9Mnbvn7T1wMDBv3UDVUNQzfTKYqDo)068p5IsOZQJAAQ3Ka8(69wAr5OJ2TMweL8SqLkrUw1QbuvO2PcqIvHo5EhOREHI8xaPremC0o5KYxffSZTCKKyq2QwLAvw25aCaVDRzfh2Z3xsuZigLl06oguVK7bPp67FdL2UqoyVaYyrgHBdexdf5q1epQmjcpYgKnEYsJZj20tho7JUahMZj4e61qjtP4u7)nRAyCvkfbra8BkpI4cWXZDsHfbe1uN6lOXyXi7m1DXXfiUoRntVYCLa6YJG5EiGlKpsbZfVPDNogqMKoSyCSRpSw2BzpJuOaUlTMIBW7Q3)s4wD1fx8)IRL5gWaKXuCRSItnF))lUE9n7EP)xkwJ8smvHZlt)mYPGIwx6KVrgpKf7cUOOnuPsona7ghlwdzKkLde8oNT(xiYUnzLAs86BaRg(CMk5UBiOhHERg7jWkmY2(Ku1dG3UAl4AveLre922Ut7UMIpcdzu)rNnN1bupv4nFGtiHgeQWtWmx4XYSNSoBUFd
```

**2. Burst gate** — pulsing icon when `IsBurstAllowed()` is true on KILL mode.

```
!WA:2!LjvtVnnqqu12dGIqibhIGEaTQhGwjuIukhQqQQk2XTnq(sMqL4u6URh7DbNDD3pijCR9eNZfUNFcrcXD(fuv(hax4k8lG12bqfMd2V55rJN38M1QE3O3)GRWwdtQ6Nz4sHUYcQueXlXehoMNuzjxelvJX5Sv8sL4OdNB1WiAkwRzEA(7GQHJTPgE1qSce4txu8z5yc2WkkvaVfuSVMPGyqnu(YSiSbyZ1qA8ajxyi(b9gges0sRIce(4mPYSqBjHqs5CzKuxl0UKBo4(xyu8Kex6MpuTcEINzwgqOwTroEz5RrfuAd2y1HugqFdXw8NVSA2hITcAUI2ENkiepgjKg0OJQ1mxa(smLn0ZhzyGaPaJvjqX4unGarKR(vu)B91AR9SkTPzAQCcev0AxGfr)FPhbMUYiy7Dq7VpARN3UtNTQ4AoXTPegD2bd608vbHJcdokO3OwTFrtVobTEm6A0b9wX2033r53VB3GETAoSD)EZTIvBMQo1U5Fv7VNDJYwOMgwE0YxtGP7TBJzuYEnSQ0ShXmMm9tRxpHBywsnNxw3TqpBIT(1uXpDEhOe40tk9MpQwzs3GOHXoCyJAnQ9eYeCISDR1vt7hhRbZAQzLGFSfpk7oUPh95pHkwDOeN)Sqvy7dD2Nh3DfUmIRZsXZA7W3B9B99qQmvQE2gUiCcpYWoNWaEcZC(sSG6oNloQU82EjoF40lYFM3RWb8Pq6v5PhQGZSGGo74d(2UfX8CA)Y(E8bFPK8pGn(f
```

**3. Defensive alert** — top-centred DEFEND callout with the reason.

```
!WA:2!LnvtRnrqyyQ9GsqeXdbSxCyHQTGSbdA9diuYhBBJ0MKUDBbpfND3zYo6MzgN5DAsk9Gu8GG3kErpMFcbeV7VGI38Ap4pa)f4S7MsP05Y(mpV7(oVppp7Sq57f)5h8BSbseQUsGj46stJe8ywbo0IPSbLMX4uHAioJTuJuboEJtnAs)OuSwN0qZoIu2FOjfyL9Xkch)2P5LfddXqs(RYjhsujNlvekrfi2xgJbsYPAskTNGXHWMEDc88d1cJkIeYgkfkyQ2e6tgumxGiY2cTDZT6D)tafBWa72LEOAo8GgWejjmYObXWzfp6NtPbmy0(rjKO3hAYp5Zkl3JA4rzkALvlHqkcyuCu)nDRNjGMcCusqJMimp(AKUBsGDeXKvwfvRgYPL3gEDA5uIWJdTQKdA5692U(B88777TPxN(TAVx9gB716XORq71zoB9MnTun7UZo2(upOD3oNA4Zvvz7KU0Lt6fZjOmeK9aRAyXZEH55JXptAoC04QgvQ8rjai1VQsLbmiXe6AZHkwZ4dJmvUIo(N13jkoo9GcF9hQ5g8nd1KHwSFv3QUpnCeEGODRBOg3Ls1eyb1KcWTl5WILLTJp6x)e1YMSCn7qccNsSzNkp4cSbqdGmgMfZ0Yu8Kal2z5NmTiGY2j)YvsIureofHLmuTR582YmkIlG86qcHFHH44KzhxgKohhrPRTwyvkTiFowHo)JFf5GCDrRy)6Sq0NG15UQqzBWQzjOFKivOE9wR)NVLT((wR)xA(AXfBqfCqE3nuSJq7AWXkmGrbbNKrVN9kWlvcdKY4ev39d2UDhp17SAKrNC2D8hXIHKpTCycHnib2DgMhzVZL)NF1GU9(p
```

**4. Callout stream** — bottom-left stream of the top 3 callouts.

```
!WA:2!9rvtVnnqquvajqrCQcIe9cBdcirQYPnT9csrvXPPFGstQmU9cGcRTxBVu7DD3D2MMIGdvCGZ9a3j8pisi4C)fG4c37veCGFbS2oPvfKyV43o7mVzM3oRNQ40EV7UFdRGqUOBcq5mzHHUCMhnh7OX(0GcJOmFUigNATGzeh7T2jkjPNBewkdnL0JifTIvraTOfwqy4xmm7yESdgcZCLroGicplrq8jcB(ojEyGeEIKe5VnNYaNMT6y3YYrYvcxIdnoHlGHsLJfjiVUaURMcPEZn2(ohdcAqGE7mpqmgURjmiH44QKapEu(NEzMKagusl3qI7EoQSm)1Ijv9vm30oQCLciKGakbd1BDJgPnqto2n02Sj6n1rmAubcZZr3bmqMmDJMn7z1Qz3T2QvNvByVz3oNOyJlIIAIN5cINqliueKMJAkQ3OL40bbS5p4OLJRPerjpmeGe5JQwnGcHkhdTSvvx773xv9s1YV1YerWWr7MldFsmwpUUJKeRXw1mQzSKtFCaFZvVI4WU((scmRyqo4T3Se1l526YhD6NrnXrrCfGKGGGJhkYKzBTCzcKdHrEuzseEGTgx6(lmmxot3D4uKljCrCxCecNqr1)h1tFm1hX4q25CXeOX6eyC(LiiKWMOtLkLQsNZAA9v)VdqRQAME1RZj)Ez(uhn))JNikJi1mLfuUP2JjUDkzN3q7D(n2EJjqp3JsBTfMdPN)dnIPSYloxwARG84Apqia7ermOmjraLZY1COsN9(VGkHmmqTlR99P0NxjvTYjDYurwC63yU4lI7zSsvsh3SC5rCXJ3yLF5NT2yLFM8XVxO((BSYpwmBDvtFodoTHGQ7NoyHG3)4ulpr)CCwHoPPuk6UJD7n70s8s9ni1FGz7wRzB1N6bHx7woHeAqi8HryMR(xazpehA212U7wPU9ha
```

**5. Comp readout** — compact comp label + spec-confirmed / class-guessed badge.

```
!WA:2!LnvqRnrquyIkOeepuHavqCzbRTh6gAulwHsizBSTsBsz72Eno7SZU7y3DMTVzgtsP4HEYZ9MEm)eciEV)ck(tWdcI38xGZSBI1sFWY8M37BFZ377ntLAZf(PN8DKsMWHE5skNjQogZzH0s)aTFenU6eklIdzit0QTt5OW3CUsq6JtrcrsBb9esnVmvQKwZdbeg6DJlsZZcqYKcOmYhiqYpYbseb85hKhIKKKZfK0O94uMmWTtx)oEbcUcWKaAwohKJfQapsCjVKCSUec9M7T38NjbACSE7JwaM6EyB5OCsawjK8SjLl9lcjKiPs4Hti4JcufN8L1Y3psXWMoAXLQAzbePcyw930PLPbC5iCIFBxlel8gbD2Ki7WizJC5z5lUK1hx3IrtRsyHb6UKjf5Z1Y1TVxh3E7UBNUB0YF7EDpxXMs0A6d)rxD4ZoAjOiw6A0qrdN8YvIpAWQdp64tEvdfKM)SePmx8661JPYevGJwARR7VJhOQFnQ9hTusagk9WsP6RWun7UbcsM23RHtdNxemafZ3EJBbd7ffjiYkWOsN7xXMgM)qn9TU4BwM(ttpuixjhdfdcFTG2wsgkNesf5POr(AF7NUY4sb3SByLfUM0MYXOuluo1A9BiL600ilgxwKxMqyZKdBBJy8VFhBOY6guxt93bfqs1AihUrQYO2nT)VAWIUQggm7NtWUM74qgjSGSgZmZTpfhfT6QMpHg0Y4zOofSNctx9syyTT2AfpgwowreIzOM2kfC3XXYwJ3SAQL52IhMNYH3UvZF)8cBRM)6Zg7lB18Nrf2TBhXzYlAbun97IaGp4mtK91V4EmONkPugb6DG)oB3Td8E9iGgn6Yh4nGgktUZ8bjeACICLjigw)eV4Hwd)E79x
```

For the trigger code behind each template (if you want to roll your own variant), see `docs/weakaura-pack.md`.

**Highlights of the bridge API:**

```lua
_G.ArenaCoachTBC.GetMode()             -- "KILL" / "SWAP" / "DEFEND" / "OPEN" / "RESET"
_G.ArenaCoachTBC.GetPrimaryTarget()    -- enemy GUID
_G.ArenaCoachTBC.GetPrimaryTargetName()
_G.ArenaCoachTBC.IsBurstAllowed()      -- bool: burst gate passed
_G.ArenaCoachTBC.GetBurstDecision()    -- multi-gate breakdown
_G.ArenaCoachTBC.GetChain()            -- {id, label, expectedProb, steps, links}
_G.ArenaCoachTBC.GetKillProb(guid)     -- 0..1
_G.ArenaCoachTBC.GetCompConfidence()   -- 0..1
_G.ArenaCoachTBC.GetCompSpecConfirmed()
_G.ArenaCoachTBC.GetOpponentProfile()  -- read-only Beta priors
_G.ArenaCoachTBC.GetTendencyMean("trinketsFear")
```

The addon also fires `WeakAuras.ScanEvents("ACC_RECOMMENDATION", rec)` on every evaluation — wire a Custom Event trigger to react on each new rec instead of polling.

---

## How it learns (the M9 keystone)

The first time you fight any team, the engine has no opponent data — it falls back to comp defaults. Turn on `/acc record on` and play. The addon writes per-team behavioural profiles into `ArenaCoachTBCDB.profiles`, keyed by a hash of class composition + a djb2 hash of player names. **Names are never stored** — only the hash is.

Four binary tendencies tracked as Beta(α, β) priors:

- `trinketsFear` — when feared, do they trinket?
- `iceBlockBelow30` — mage: Ice Block at HP <30%?
- `kicksFirstHeal` — do they kick the first big heal?
- `sapsPriest` — when sapping, do they pick the priest?

After ~5 observations the profile becomes opinionated; after ~20 the posterior mean is reliable.

**To inspect:**
- `/acc trace dump` — shows last N decisions with profile contribution
- `/acc record dump` — raw CLEU event count
- `/acc whatif skip <i>` — replay log with event #i removed
- `tools/replay.lua <SavedVars>` — offline shell replay

---

## Running the tests

The engine is pure Lua and headless-testable. The suite stubs every WoW API needed.

```bash
# Full suite with coverage
lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua && luacov && tail -n 20 luacov.report.out

# Single standalone spec
lua5.1 ArenaCoachTBC/Tests/StrategyEngine_spec.lua

# Locale parity (every enUS key must exist in every other locale)
lua5.1 tools/check_locales.lua

# Replay a recorded SavedVariables log
lua5.1 tools/replay.lua <path/to/ArenaCoachTBC.lua>
```

CI runs syntax check → locale parity → tests → 99% coverage gate on every push and PR. v2.2.0 ships with **613 tests**, **99%+ coverage**, and an **81% baseline** agreement against hand-labelled benchmark scenarios.

---

## License

MIT.

---

# 中文 / Chinese

**魔兽世界 TBC 怀旧服 / TBC 周年服**的实时竞技场战术教练。监视战斗、识别敌方阵容（包含天赋）、选定击杀目标、规划控制链，并实时输出建议：`OPEN | KILL | SWAP | DEFEND | RESET`。

> **v2.0 引擎深度路线图已发布。** 你的教练现在能学习对手。打过 20 次的某支队伍，如果他们总是用饰品解除恐惧，则不再收到通用的"陷阱图腾解恐惧"提示——陷阱图腾会留给制裁之锤。如果某个法师习惯在 30% 血量冰块，爆发提示会被自动暂停。这些都不是写死的逻辑——它通过观察战斗按队伍学习，不会持久化任何玩家姓名。

> ⚠️ **仅提供建议。** 此插件不会自动施法、不会切换目标、不会点击受保护按钮、不会修改安全宏。它只输出视觉、音频、文字提示，仅此而已。

---

## 适用于所有 PvP 场景

| 场景 | 行为 |
|---|---|
| **竞技场 2v2 / 3v3 / 5v5** | 完整引擎：阵容识别、天赋推断、连锁规划、对手档案、lookahead、爆发判断、全部视觉与音频警报。 |
| **战场**（WSG/AB/AV/EotS） | 引擎自适应：铭牌探测敌人、夺旗者优先级（+200）、低血单位提升、战场专属提示（`CALL_FLAG_CARRIER_LOW`、`CALL_BG_DEFEND`）。队伍特征档案样本不足时（如临时组队）自动启用职业级先验。 |
| **户外 PvP / 决斗** | 引擎简化：单目标聚焦、不会左右横跳、不做阵容匹配。`DUEL_REQUESTED` 自动启动。 |
| **竞技场专属警报**仅在竞技场触发 | 屏幕闪烁与语音提示只在 `IsActiveBattlefieldArena()` 为真时触发。战场中不会出现错误的红色闪屏。 |

---

## 适用于任何队伍组合

之前的版本曾标榜专门为某特定阵容调优（WAR/ENH/RET/RDRU/DISC 近战劈砍）。**v2 不再有"专属调优"队伍。** `OwnComps:Infer` 扫描你的队伍并返回一个能力表——`hasMortalStrike`、`hasBloodlust`、`hasFreedom`、`hasMassDispel`、`hasMainHealer` 等——然后 `OwnComps:Identify` 从中识别原型：

| 原型 | 触发条件 | 影响 |
|---|---|---|
| `MELEE_CLEAVE` | ≥2 近战 + 治疗 | 激进击杀压力提示；优先开打治疗 |
| `CASTER_CLEAVE` | ≥2 法系 + 治疗 | 落雷/驱散重点；优先控副治 |
| `DRAIN` | 痛术 / 暗牧持续型 | 蓝量压制 / 拖延，不主动起手 |
| `JUNGLE` | 猎人 + 野德 + 治疗 | 陷阱 + 驱散组合 |
| `DOUBLE_HEALER` | ≥2 治疗 | 蓝量消耗 |

`Data/Strategies.lua` 中的 100+ 敌方阵容目录都附带 `ownVariants`，所以同一支敌方队伍会根据你的原型给出不同建议。引擎内没有任何"如果职业是 X"这样的硬编码——一切都通过能力推理。**任意阵容皆可，引擎自适应。**

---

## 安装（一次性配置，约 2 分钟）

1. 从 [Releases 页面](https://github.com/tomqwu/ArenaCoachTBC/releases) **下载最新 zip**，或使用 [CurseForge 列表](https://www.curseforge.com/wow/addons/arenacoachtbc)。
2. **解压并复制 `ArenaCoachTBC/` 文件夹**（含 `ArenaCoachTBC.toc` 的那个）到魔兽世界插件目录：
   - **TBC Classic / 周年服**：`<WoW install>/_classic_/Interface/AddOns/`
   - **macOS**：通常为 `/Applications/World of Warcraft/_classic_/Interface/AddOns/`
   - **Windows**：通常为 `C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\`
3. **重启客户端**（如已在游戏内，`/reload`）。插件列表中应出现已启用的 `ArenaCoachTBC`。
4. 若角色选择界面提示 "Out of Date"，启用底部的"**载入过期插件**"。或在 `ArenaCoachTBC.toc` 中将 `## Interface: 20505` 改为与你客户端匹配的版本号。

---

## 首次启动检查（约 3 分钟）

```
/acc help              -- 查看所有命令
/acc test              -- 14 秒 UI 演示
/acc unlock            -- 解锁拖动
                          （拖到合适位置）
/acc lock              -- 锁定位置
/acc selftest verbose  -- 客户端内自检
```

执行 `/acc test` 后，提示框会出现在屏幕中央，并在 14 秒内走完 7 个节拍（模式切换、爆发提示、防御警报、对手习惯提示）——你会看到插件能输出的所有 UI 变化。**看到这个演示，说明插件已正确加载。** 把框拖到你比赛中实际会看的位置。

---

## 比赛中的日常使用

比赛中无需主动操作。当 `PLAYER_ENTERING_WORLD` 触发且 `UPDATE_BATTLEFIELD_STATUS` 确认进入了竞技场（排位或练习），插件自动启动。竞技场之外提示框自动隐藏（除非 `/acc toggle` 强制开启）。

**比赛中你会看到：**

1. **战前（铁门未开）**：模式 = `OPEN`（黄色），目标 = 阵容默认起手目标。规划开场。
2. **战斗中**：模式切换为 `KILL`（红）/ `SWAP`（橙）/ `DEFEND`（蓝）。大字显示击杀目标；信息行显示目标血量百分比和击杀概率；提示行显示功能性提示；连锁块显示标准 CC 序列；阵容徽章显示天赋是否已确认。
3. **爆发窗口**：信息行出现 `BURST READY` 标签——所有爆发门禁通过（击杀概率 ≥ 阈值、连锁就绪、无即将到来的压力）。同时屏幕边缘出现红色 KILL 光晕，并播放响亮提示音。
4. **防御**：当你的治疗被集火或敌方爆发激活，模式切换为 `DEFEND`（蓝色）。屏幕边缘光晕转蓝；提示切换为痛苦压制 / 保护祝福 / 剥离。

---

## 命令一览

| 命令 | 说明 |
|---|---|
| `/acc help` | 显示命令列表 |
| `/acc toggle` | 显示 / 隐藏提示框 |
| `/acc lock` / `/acc unlock` | 锁定 / 解锁框体拖动 |
| `/acc test` | 14 秒 DBM 风格 UI 演示（模式切换、爆发、防御警报） |
| `/acc test bg` | 战场模式演示（夺旗者 + 低血单位 + 战场防御提示） |
| `/acc test world` | 户外 PvP 演示（单目标聚焦） |
| `/acc test print` | 仅文字版本（旧行为） |
| `/acc enemy <c1> <c2> ...` | 模拟自定义敌方阵容 |
| `/acc reset` | 清空存档并 `/reload` |
| `/acc strategy safe\|balanced\|greedy` | 手动调整侵略性 |
| `/acc glow [on\|off]` | 切换模式着色屏幕边缘光晕（v2.2+） |
| `/acc nameplate [on\|off]` | 切换击杀/换火目标的铭牌高亮（v2.2+） |
| `/acc debug` | 切换调试输出 |
| `/acc selftest [verbose]` | 客户端内自检 |
| `/acc simulate [key\|stop]` | 重放脚本化场景 |
| `/acc trace [on\|off\|dump\|clear\|status]` | 决策追踪环缓冲 |
| `/acc record [on\|off\|dump\|clear\|status]` | CLEU 录制（用于离线重放） |
| `/acc whatif skip <i>` | 反事实重放（跳过事件 #i） |
| `/acc bugreport` | 已脱敏的错误报告（贴到 GitHub） |

---

## 配置

所有设置持久化在 `ArenaCoachTBCDB`（SavedVariables）中。向后兼容——v1 存档在 v2 中无须重置即可加载。

**主要配置项**（通过游戏内 `界面 → 插件 → ArenaCoachTBC` 编辑）：

| 配置项 | 默认 | 说明 |
|---|---|---|
| `strategy.ratingAggression` | `"auto"` | `"auto"` 自动读取战场分数。也可锁定为 `"greedy"` / `"balanced"` / `"safe"` 或具体分数。 |
| `strategy.callBurstOnlyWhenMSActive` | `true` | 必须 MS 减疗已挂在目标上才允许爆发。 |
| `strategy.requireWindfuryNearby` | `true` | 必须风怒图腾就位才允许爆发。 |
| `strategy.peelTriggerWindow` / `peelTriggerDamage` | `5` / `3` | 集火检测灵敏度（伤害事件 × 时间窗 → DEFEND）。 |
| `strategy.lookaheadEnabled` | `true` | 启用 M10 lookahead（连锁 × 对手反应期望值最大化）。 |
| `frame.compactMode` | `false` | 隐藏己方/敌方冷却图标行。 |
| `alerts.sound` / `alerts.screenFlash` | `true` / `true` | 语音提示 + 紧急模式屏幕闪烁。 |
| `alerts.edgeGlow` / `alerts.nameplate` | `true` / `true` | v2.2 屏幕边缘模式着色光晕 + 铭牌高亮。 |

---

## 法术名称与本地化

`Data/Spells.lua` 中的法术 ID 是**通用的**——同一个整数对应所有语言客户端。UI 中显示的法术名称通过 `GetSpellInfo(spellID)` 从**魔兽客户端当前语言**获取——所以中文客户端会显示 *闷棍*，英文客户端显示 *Sap*。**插件不在任何地方硬编码法术名称。**

**图标行的鼠标悬停提示**也是如此——它们调用 `GameTooltip:SetSpellByID(spellID)`，所以提示就是暴雪标准的本地化弹窗（图标 + 名称 + 描述）。

面向用户的**提示文案**（如 "陷阱图腾解恐惧"、"集火牧师"）通过插件本地化键管理：`Locales/enUS.lua` 为基准，含 112 个键；`Locales/zhCN.lua` 严格对齐。插件通过 `GetLocale()` 自动选择语言，可通过 `db.language` 覆盖。

---

## 用 WeakAuras 自定义显示

插件通过 `_G.ArenaCoachTBC` 全局发布完整的推荐数据。你可以基于这些 getter 构建自己的 HUD。

### 直接导入字符串

5 个现成模板。游戏内：`/wa` → 点击左上角 **Import** → 粘贴字符串 → 在预览弹窗里再点 **Import**。每个模板互相独立，按需导入。

**1. 模式徽章** — 大字号、按模式着色的目标信息行。竞技场外自动隐藏。
**2. 爆发开关** — 当 KILL 模式下 `IsBurstAllowed()` 为真时显示脉动图标。
**3. 防御警报** — 屏幕顶部居中的 DEFEND 提示，带触发原因。
**4. 提示流** — 左下角显示前 3 个提示。
**5. 阵容信息** — 紧凑的阵容标签 + 天赋已确认 / 仅按职业推测徽章。

5 个 `!`-前缀的导入字符串与上方英文部分相同（请使用上面的代码块直接复制）。模板背后的触发器代码（如需自行变体）参见 `docs/weakaura-pack.md`。

**主要 API：**

```lua
_G.ArenaCoachTBC.GetMode()             -- "KILL" / "SWAP" / "DEFEND" / "OPEN" / "RESET"
_G.ArenaCoachTBC.GetPrimaryTarget()    -- 敌方 GUID
_G.ArenaCoachTBC.GetPrimaryTargetName()
_G.ArenaCoachTBC.IsBurstAllowed()      -- 爆发门禁是否通过
_G.ArenaCoachTBC.GetBurstDecision()    -- 多门禁细分
_G.ArenaCoachTBC.GetChain()            -- {id, label, expectedProb, steps, links}
_G.ArenaCoachTBC.GetKillProb(guid)     -- 0..1
_G.ArenaCoachTBC.GetCompConfidence()   -- 0..1
_G.ArenaCoachTBC.GetCompSpecConfirmed()
_G.ArenaCoachTBC.GetOpponentProfile()  -- 只读 Beta 先验
_G.ArenaCoachTBC.GetTendencyMean("trinketsFear")
```

插件每次评估后还会触发 `WeakAuras.ScanEvents("ACC_RECOMMENDATION", rec)`——连接 Custom Event 触发器即可基于事件响应，无需轮询。

---

## 学习机制（M9 关键模块）

首次对战任意队伍时，引擎没有对手数据——退回到阵容默认值。`/acc record on` 后开始游玩。插件按队伍写入行为档案到 `ArenaCoachTBCDB.profiles`，键为职业组合的哈希 + 玩家名的 djb2 哈希。**玩家姓名永远不存储**——只存哈希。

四个二元习惯，按 Beta(α, β) 先验追踪：

- `trinketsFear` — 被恐惧时是否使用饰品？
- `iceBlockBelow30` — 法师 30% 血量是否冰块？
- `kicksFirstHeal` — 是否打断第一个大治疗？
- `sapsPriest` — 闷棍时是否选牧师？

约 5 次观察后档案开始有"意见"；约 20 次后后验均值可靠。

**查看方式：**
- `/acc trace dump` — 显示最近 N 次决策及档案贡献
- `/acc record dump` — CLEU 事件原始数量
- `/acc whatif skip <i>` — 重放并跳过事件 #i
- `tools/replay.lua <SavedVars>` — 终端离线重放

---

## 运行测试

引擎是纯 Lua，可无头测试。测试套件已 stub 所需的所有 WoW API。

```bash
# 完整套件 + 覆盖率
lua5.1 -lluacov ArenaCoachTBC/Tests/run_all.lua && luacov && tail -n 20 luacov.report.out

# 独立 spec
lua5.1 ArenaCoachTBC/Tests/StrategyEngine_spec.lua

# 本地化对齐（每个 enUS 键必须存在于其他语言）
lua5.1 tools/check_locales.lua

# 重放 SavedVariables 录像
lua5.1 tools/replay.lua <path/to/ArenaCoachTBC.lua>
```

CI 在每次推送和 PR 上运行：语法检查 → 本地化对齐 → 测试 → 99% 覆盖率门禁。v2.2.0 共 **613 个测试**、**99%+ 覆盖率**、对人工标注基准场景的 **81% 一致率**。

---

## 许可证

MIT。
