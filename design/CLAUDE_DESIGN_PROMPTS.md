# Claude Design prompts — Do or Die

Paste **Prompt 0** first in a new Claude Design project, then the screen prompts one at a time (in the same project, so it keeps the brief). When a screen is approved, export it as **HTML/CSS** (and illustrations as **SVG**) and drop the files into `design/claude-design/`. I will port them to Flutter.

---

## Prompt 0 — Project brief (paste first)

```
You are designing the mobile UI for "Do or Die", an Android habit app (Flutter) that I want to publish.

CONCEPT
A cold, game-like "System" turns self-improvement into daily quests. The user picks ONE System:
- FITNESS (trains STR, VIT): walks, push-ups, squats, planks, runs.
- PERSONALITY (trains INT, CHA): reading, journaling, talking to people, presenting work.
- FOCUS (trains DIS): phone-free blocks, social-media time caps, no phone at meals.
The System issues a daily quest for the user's rank (E, D, C, B, A, S). Clear it before midnight to earn XP. Fail it and the "Penalty Zone" follows: the user's chosen apps (Instagram, YouTube, games) lock for hours at an undisclosed time, plus a System-specific penalty (Fitness: push-ups; Personality: pages to read and a written reflection; Focus: a phone-free block).
Clear 21 of 30 days and a "Gate" opens. Entering it starts a 3-day "Dungeon": Floor 1 (+25%), Floor 2 (+50%, must finish by 18:00), Floor 3 the "Rank Trial" (boss). Clear it to rank up. Fail a floor and the "Dungeon Penalty" (double everything) follows.

MOOD
Dark sci-fi game HUD: a holographic "System window" floating over a void. Thin glowing frames with chamfered corners and corner brackets, scanlines, a faint grid, light glow on text. Cold, formal, a little intimidating, never cute. Inspired by the general vibe of "system" web-novel/manhwa UIs, but 100% ORIGINAL: no characters, names, logos, symbols or art from any existing anime, manhwa or game.

BRAND TOKENS (keep these)
- Background void #05070D, top glow #0B1730, panel rgba(10,18,34,0.72)
- System blue #4FB3FF, highlight #A9DCFF, body text #DBE7FF, dim text #7D8BA8
- Gold (rewards, ranks, titles) #F5C96A; warning #FF8A93
- Penalty Zone: red #FF3B4A on #090204, glitch allowed
- Dungeon Penalty: crimson #D7263D with gold #F5C96A on #060102
- Rank colours: E #9AA4B8, D #5BD69A, C #4FB3FF, B #B07CFF, A #FF9F45, S #F5C96A
- Fonts: "Chakra Petch" (bold, wide letter-spacing) for titles; "JetBrains Mono" for body/numbers
- Copy voice: terse, formal, no emojis, no exclamation marks. Window titles in brackets, e.g. "[ DAILY QUEST ]".

FRAME
Phone portrait 390 x 844, safe areas respected. Every screen fills the full height (no half-empty screens). Big touch targets (min 48 px). Prefer interaction over walls of text: tap, hold, swipe, reveal.

DELIVERABLE FOR EACH SCREEN
An interactive HTML/CSS prototype (vanilla, no framework), CSS variables for every token above, plus any illustrations as separate inline SVGs I can export. Show the main states (default, selected, pressed, done). Keep animations short (200-600 ms) and describe them in a comment so they can be rebuilt in Flutter.
Reply "Brief understood" and wait for the first screen.
```

---

## Prompt 1 — The Awakening (first launch)

```
Design the first-launch "Awakening" sequence (7 short steps with a thin progress bar at the top):
1. SYSTEM CONTACT: the screen is black; a System window powers on (vertical expand + flash). Text: "You have met the conditions to become a Player." then a hold-to-accept button "ACCEPT". Make this feel like a moment: particles converging into an emblem, a low hum.
2. CHOOSE YOUR SYSTEM (see Prompt 2 for the full design).
3. PLACEMENT TEST: 1-2 questions per System with big steppers (minus / number / plus) and a slider alternative. Subtitle: "These answers only set your starting rank. Your daily quest is shown next."
4. RANK ASSIGNED / YOUR DAILY QUEST: a rank badge (E, D or C) stamps in with its rank colour; then the daily quest items deal in one by one as numbered cards with their targets; then "At rank D the System adds: ..." as a teaser.
5. LOCK TARGETS: choose the apps that lock on a failed day (app icons in a grid with lock toggles).
6. REST PERIOD: pick sleep start/end on a 24-hour ring (locks never start while asleep).
7. PENALTY TERMS: the rules as short lines that reveal as you scroll; "HOLD TO ACCEPT" fills like a charge bar over 1 second.
Show each step as its own frame. Keep it under 2 minutes for a user.
```

## Prompt 2 — Choosing a System (interactive, illustrated)

```
Design the "Choose your System" step as the centrepiece of onboarding. It must EXPLAIN the three Systems in an interactive, attractive, illustrative way, not a boring list.
- Three large swipeable cards (carousel with peeking neighbours), one per System: FITNESS, PERSONALITY, FOCUS.
- Each card has an original emblem illustration (SVG, line-art hologram style in system blue with a glow; Fitness = an abstract figure/kettlebell motif, Personality = an open book merging into a speech wave, Focus = a lens/eye with concentric rings). Emblems animate subtly (rotating rings, pulsing core).
- Card front: emblem, name, one-line promise ("Build strength and stamina, one rank at a time." / "Grow your mind and your presence with people." / "Take your attention back from your phone."), stat chips (STR VIT / INT CHA / DIS).
- Tap the card to FLIP it (or expand it) to the back: "Where you start (rank E)" with today's real quest items, "Where it ends (rank S)", "If you fail a day" (the app lock + that System's own penalty), and a mini rank ladder E→S in rank colours.
- Bottom: "CHOOSE FITNESS SYSTEM" primary button that changes with the selected card; note "One System at a time. No switching until it is complete."
Content to use:
FITNESS rank E: Walk 12 min · Push-ups (knees allowed) 10 · Squats 15. Rank S: a full-intensity personal programme, logged daily. Penalty: 50 push-ups (+5 per level).
PERSONALITY rank E: Read 10 pages · Write one journal line · Say hello to someone you rarely talk to. Rank S: create something every day. Penalty: 20 pages of reading and a written reflection on why the quest failed.
FOCUS rank E: No phone for the first 20 minutes after waking. Rank S: locked apps stay locked all day by choice. Penalty: a 60-minute phone-free block with your chosen apps locked.
Every System: on a failed day your chosen apps lock for 4 hours at a time you are not told.
```

## Prompt 3 — Daily Quest screen

```
Design the main "[ DAILY QUEST ]" screen (bottom nav: QUEST, STATUS, PENALTY).
- Top bar: date, sound toggle, rank badge in rank colour.
- The quest window fills the screen: each objective is a row with name, progress (e.g. "6 / 10", "45%", "0.8 / 2.0 km", "20 / 60 min" for a cap where lower is better) and its control: hold-to-confirm (checkbox), big timer clock with START/PAUSE (timed), +1/+5/+10 steppers (counts), +100 m/+500 m (distance), START BLOCK / END BLOCK (phone-free block that locks apps).
- A completed objective collapses with a gold check and a short shimmer.
- Footer: countdown to midnight, warning line "Failure to complete will result in a penalty.", XP bar with pending reward.
- States to show: fresh day; half done; all done (gold "All objectives complete." + reward notice window); Dungeon Floor 2 variant ("[ DUNGEON · FLOOR 2 ]", countdown to 18:00, harder accent); a Gate-open banner at the top with a hold-to-enter button and 48-hour countdown.
```

## Prompt 4 — Penalty Zone and Dungeon Penalty

```
Design the Penalty tab in two looks:
A) PENALTY ZONE (red #FF3B4A, glitch on titles, heavy scanlines): big lock countdown "03:12:45 UNTIL ACCESS IS RESTORED" (or "THE LOCK WILL BEGIN WITHOUT WARNING" when pending), chips of the locked apps, "HOLD 3S · RELEASE 15 MIN" (every release is counted and shown), and the System-specific debt window:
  - Fitness: PUSH-UPS OWED 20 / 50 with +1 / +10 REPS.
  - Personality: PAGES OWED 5 / 20 with +1 / +5 PAGES, and REFLECTION OWED with a text box (at least 5 lines) and SUBMIT.
  - Focus: PHONE-FREE MINUTES OWED 0 / 60 with START PENALTY BLOCK and a live clock.
B) DUNGEON PENALTY (crimson #D7263D + gold, darker, more ceremonial): same layout, title "[ DUNGEON PENALTY ]", subtitle "The Dungeon was not cleared. Double lock, double penalty."
Also design the full-screen block screen Android shows over a locked app (title, reason, countdown, "Leave" button) for both looks and for the calm blue "[ PHONE-FREE BLOCK ]" variant.
```

## Prompt 5 — Big moments (notices)

```
Design the System notice overlays (centred window over a dimmed screen, one "ACKNOWLEDGE" button), each with its own entrance animation:
- QUEST CLEARED (+100 XP, gold), LEVEL UP (level number counts up, stat points), WARNING (quest failed, red)
- [ GATE ]: "A Gate has opened. Rank E Dungeon. Enter within 48 hours." — a portal/rift illustration in the rank colour opening behind the window.
- [ RANK UP ]: the old rank badge shatters and the new one forms in its colour; title earned "Gatebreaker · Fitness D"; "+5 stat points".
- [ DUNGEON FAILED ]: crimson, heavy, "Floor 1 was not cleared. Dungeon Penalty today: double lock and double penalty. Your rank is kept."
- [ SYSTEM COMPLETE ]: gold, the S badge with a long glow.
```

## Prompt 6 — Status and Report

```
Design the STATUS tab (single screen, no inner scrolling on a 390x844 phone): huge rank letter in rank colour with glow, System name, latest title in gold, rows LEVEL / EXPERIENCE / NEXT GATE (e.g. "14 / 21 CLEARED" as a segmented progress ring) / CURRENT STREAK / TRIAL DAY, a QUEST REDUCTION control (0% 10% 20%, "applies tomorrow · half XP"), buttons REPORT and SYSTEM CHECK, and an ATTRIBUTES panel with five stats (STR VIT INT CHA DIS) each with a "+" to spend points.
Then the 30-DAY REPORT screen: clear-rate dial, rank journey (start badge → current badge), "then and now" targets, 30-square consistency calendar (gold cleared, red failed, blue dry run), HONESTY section (penalty zones, dungeon penalties, releases taken, blocker outages, honour confirmations, reduced days), and a cold one-line VERDICT. Include a "share as image" card layout (1080x1350) of the report.
```
