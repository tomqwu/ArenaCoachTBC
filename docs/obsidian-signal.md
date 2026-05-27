# Obsidian Signal

Obsidian Signal is ArenaCoachTBC's compact tactical HUD language. It exists to make live PvP advice feel like a calm command instrument, not a raid-warning billboard.

## Principles

- **Signal over decoration.** Every line, marker, and colour must help locate, rank, or read tactical information.
- **Compact command deck.** The HUD stays small enough for arena frames, cast bars, nameplates, action bars, WeakAuras, chat, and damage meters to remain usable.
- **Obsidian field.** Surfaces are warm almost-black reading plates; preserve the world, but never let it overpower the text.
- **Brass structure.** Borders, dividers, rulers, reticles, and labels use muted brass so the board reads as one deliberate instrument.
- **Cyan intelligence.** Cyan marks tactical data, secondary roles, and cool-state information.
- **Crimson consequence.** Crimson is reserved for committed kill signal or real urgency; it should never become wallpaper.
- **Bone-white truth.** Current HP, names, and numeric facts use the clearest neutral tone.
- **No big flashing.** Motion and alarm are constrained to passive text, thin accents, optional sound, nameplate cues, and fade-out behavior.

## HUD Application

- Main shell: one integrated board with visible drag and resize affordances.
- Center: the dominant action/target instrument with a target-health bar.
- Left: focus and pressure status.
- Right: tactical cue rail with spell-aware reminders.
- Bottom: 1/2/3/5 fixed assignment cards, led by a highlighted self-action card.
- Metadata: `OBSIDIAN / SIGNAL / <mode>` so screenshots and manual checks reveal the active visual language.

## Regression Checks

- The HUD must remain readable on light and dark map backgrounds.
- The board must be visible enough to drag, but not dark enough to hide the playfield.
- Side-rail headers must not wrap in the default compact board.
- DEFEND and RESET must hide inactive target-health instruments.
- Text must stay inside its panel at default size and after resizing.
- 2v2, 3v3, and 5v5 assignment slots must keep stable positions.
- The player's own bottom assignment must be visually dominant and readable before teammate context.
- Stale advice must fade away instead of sitting on screen.
