# Do or Die — Design Direction (draft for sign-off)

**Mockup:** [mockup.html](mockup.html), interactive, 3 screens: Daily Quest (with completion notice and level-up), Status, Penalty Zone.
**Status:** **Approved 2026-10-20: A2 + P3** (chosen from [variants.html](variants.html)).
- **Main app = A2:** Electric Blue palette at Balanced intensity (glow 10px @ 45%, grid 5%, scanlines 1.8%, frame lines 35%).
- **Penalty Zone = P3:** Penalty red at Intense (glow 20px @ 85%, grid 10%, scanlines 4%, frame lines 60%) with the periodic glitch on the title.

## Identity
- A cold "System" interface: near-black void, faint grid, thin electric-blue window frames with corner brackets, chamfered corners.
- Penalty Zone flips the whole palette to red, with a slow glitch on the title.
- Original art and copy only. No assets, characters, logos or text from Solo Leveling.

## Tokens
| Token | Value | Use |
|---|---|---|
| void | `#05070d` | Background |
| panel | `rgba(10,18,34,.72)` | Window fill |
| sys | `#4fb3ff` | Frames, bars, accents |
| sys-hi | `#a9dcff` | Titles, highlighted values |
| text | `#dbe7ff` | Body |
| dim | `#7d8ba8` | Secondary |
| gold | `#f5c96a` | Completed objectives, rewards |
| red | `#ff3b4a` | Penalty Zone, warnings |

**Type:** Chakra Petch (headings, rank letter, big numbers) + JetBrains Mono (system text, stats). Both OFL; bundle the files for offline use.

## Motion rules
- Windows "power on": scale from a thin line, brief brightness flash, ~420ms, ease-out.
- Titles decode from random glyphs (~400ms).
- Stagger stacked windows by ~120ms. Whole entrance under ~700ms; a tap skips it.
- Glow only on what just changed (level-up, stat increase, completed task). Resting panels stay crisp.
- Respect reduce-motion.

## Interaction patterns
- Checkbox tasks: **hold to confirm** (~0.9s fill), never a single tap.
- Timer tasks: start / pause, progress bar fills live.
- Counter tasks: +1 / +5 / +10.
- Quest cleared: notification window with reward, then LEVEL UP pulse if earned.
- Stats: + buttons spend points, with a short glow on the changed number.
- Penalty Zone: lock countdown, apps locked, reps owed with +1 / +10, carry-over warning, logged emergency exit.

## Flutter build plan (from UI research, 2026-10-20)
- `flutter_animate`: entrance, stagger, shimmer, shake.
- `flutter_shaders` + own `.frag`: scanlines, noise, chromatic aberration (test on web early).
- `flutter_soloud`: low-latency UI sounds, distinct low tone for Penalty Zone, mute toggle.
- `gaimon`: haptics on Android (no-op on web).
- `google_fonts` (fonts bundled).
- `newton_particles`: level-up burst.
- `animated_glitch`: Penalty Zone title.
- Window frames, corner brackets and glowing borders: **own CustomPainter widgets** (the signature look).
- Study, not copy: arwes (motion and sound orchestration), auris (Flutter HUD theming structure).
