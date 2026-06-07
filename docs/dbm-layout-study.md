# DBM layout study

This note studies the visible layout language of Deadly Boss Mods and what it
means for ArenaCoachTBC. It is based on the public DBM CurseForge gallery,
Wowhead's DBM guide, DBM setup guidance, and the current DBM source defaults.

## DBM's main combat surfaces

### Center warnings

DBM uses the center of the screen for brief warning text, not a permanent board.
The public warning screenshot shows one or two large centered lines with spell
icons bracketing the text. The current source matches that shape:

- regular warning text defaults to `CENTER`, `Y = 260`, font size `20`;
- special warning text defaults to `CENTER`, `Y = 75`, font size `35`;
- special warnings are capped at two stacked lines;
- both warning lines fade after a short duration rather than staying up;
- spell icons can wrap the warning text left and right;
- warning severity changes sound, color, flash, and repetition.

DBM's key layout insight is that center warnings are ephemeral commands. They
are loud for a moment, then disappear so the player can see the fight.

### Timer bars

DBM's timer bars are compact stacked strips with an icon, label, and countdown.
The public timer screenshot shows multiple colored bars grouped vertically, with
inline icons and right-aligned remaining time.

Source defaults reinforce that compactness:

- normal bars default to `183 x 20`, scale `0.9`;
- normal bar anchor defaults near the upper-right quadrant;
- huge/imminent bars default to `200 x 20`, scale `1.03`;
- huge bar anchor defaults near center, `Y = -120`;
- bars transition into the huge anchor when they become soon;
- color-by-type is enabled by default;
- icon-left is enabled, icon-right is disabled;
- text font defaults to size `10`;
- long bars can be hidden, and bars can fade.

DBM's key layout insight is that future information belongs in bars, not in a
large text block. The player scans count, icon, and color faster than prose.

### Range and info frames

DBM keeps secondary information in small, independent movable widgets:

- range text frame defaults around `128 x 12`;
- range radar defaults to `128 x 128` with a translucent black background;
- info frame starts tiny and grows with lines/columns;
- both frames are draggable and clamped to screen;
- right-click context menus expose lock, lines, columns, range, and strata.

DBM's key layout insight is that persistent secondary information should be
small, movable, and opt-in per encounter, not welded into the central warning.

### Options/config GUI

DBM's options GUI is large, transparent over the game world, and heavily
navigational:

- left-side tree for modules/bosses/categories;
- right-side detailed options for the selected module;
- checkboxes and dropdowns for individual warnings, sounds, and bars;
- resizable main panel;
- "move me" or unlock flows for positioning live widgets.

This is not a combat HUD. It is an out-of-combat configuration surface.

## Visual rules DBM uses well

- Icon first: warning and bar rows use spell icons as recognition anchors.
- One concern per surface: warnings, bars, range, info, and options are separate.
- Short text: center warnings are commands, not explanations.
- Imminence changes location: near-future bars graduate into the larger anchor.
- Severity changes multiple channels: color, icon, sound, and sometimes flash.
- Movable anchors matter: users place surfaces around their existing UI.
- Setup mode is explicit: `/dbm unlock` reveals anchors before a real fight.

## What ArenaCoachTBC should copy conceptually

- Keep the permanent HUD smaller than our current instinct. Arena players
  already have arena frames, party frames, cast bars, nameplates, trinket
  trackers, action bars, chat, and WeakAuras.
- Treat the center as a short-lived command surface: `KILL Holyman`,
  `PEEL healer`, `SWAP Frostbiter`, then fade.
- Move future or sustained advice into compact rows/bars/icons: interrupt soon,
  pain suppression fading, trinket down, enemy burst window, teammate CC.
- Make self-action dominant but brief. The bottom row should answer
  "what should I do?" first, with teammate actions quieter.
- Add a DBM-like unlock/setup mode that clearly shows every movable/resizable
  module and its drag handle.
- Prefer icon+label+timer rows over paragraph reminders.
- Allow independent positions for the permanent compact HUD, cue rail, self
  action strip, and optional replay/test report.

## What ArenaCoachTBC should avoid copying

- Full-screen flashing as a default. DBM supports it, but the user has already
  rejected big flashing. Our urgency should use color, icons, sound, and fade.
- A giant always-on center dashboard. DBM's actual combat layout is not one big
  dashboard; it is small anchors plus transient warnings.
- Raid-boss assumptions. PvP advice changes with human opponents and can go
  stale fast, so stale fade and confidence display are more important than
  static boss-timer certainty.

## Concrete HUD direction

For ArenaCoachTBC, the DBM-inspired shape should be:

1. **Center command line**: one large short-lived action, with optional spell icon
   and target name. It fades when no fresh recommendation arrives.
2. **Compact timer/cue stack**: two to five bar-like cue rows with icons,
   category color, and optional seconds/confidence.
3. **Self action card**: small persistent card for the player's immediate job.
4. **Team assignment strip**: quieter teammate cards, fixed 2v2/3v3/5v5 slots.
5. **Replay/test panel**: only visible in test mode, showing the event timeline
   and expected recommendation changes at readable speed.
6. **Unlock overlay**: visible drag/resize frames for each module, with lighter
   translucent backgrounds so the player can see what is movable.

The visual goal is not "DBM skin." It is DBM's proven information economy:
short command in the center, bar/icon rows for timing, small movable widgets for
supporting context, and configuration outside combat.

## References

- DBM CurseForge gallery: https://www.curseforge.com/wow/addons/deadly-boss-mods/gallery
- DBM warning screenshot: https://media.forgecdn.net/attachments/76/27/dbm-warnings1.png
- DBM timer-bar screenshot: https://media.forgecdn.net/attachments/76/31/dbm_timers.jpg
- DBM configuration screenshot: https://media.forgecdn.net/attachments/76/30/Screen_Shot_2015-07-06_at_7.10.03_AM.jpg
- Wowhead DBM guide: https://www.wowhead.com/guide/deadly-boss-mods-addon-guide-5995
- DBM setup guide mirror: https://github-wiki-see.page/m/DeadlyBossMods/DeadlyBossMods/wiki/%5BNew-User-Guide%5D-Initial-Setup-Tips
