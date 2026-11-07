# Do or Die — Systems & Dungeons PRD

**Status:** Draft v0.2 · **Date:** 2026-10-27 · **Platform:** Android only (web and iOS paused)
**Builds on:** [PROJECT.md](PROJECT.md) (penalty rules), [BUILD_LOOP.md](BUILD_LOOP.md) (how we build), [COMPETITOR_ANALYSIS.md](COMPETITOR_ANALYSIS.md) (incl. the 2026-10-27 addendum)
**Theme:** the feel of a cold game "System" (windows, daily quests, ranks, gates, boss trials, penalties). All names, quests, text, art and sound are original to Do or Die.

---

## 0. One-page summary

| | |
|---|---|
| **What** | The user chooses **one System** (Fitness, Personality or Focus). The System writes a daily quest for the user's **rank (E to S)** in that System. Clear **21 of the last 30 days** and a **Gate** opens; inside is a **Dungeon** of 3 floors ending in a **Rank Trial**. Clear it to rank up. Fail it and you enter the **Dungeon Penalty Zone**: double lock and double reps. Every 30 days the System issues a **report** of what you gained. |
| **Who** | People who want a guided path, not a blank to-do list: fitness beginners, people trying to grow socially or intellectually, and people trying to beat phone addiction. |
| **Why** | User-written quests stall: people set them too easy or too hard and never change them. A System that sets the quest, scales it by rank, and makes rank-ups a real fight gives structure and a reason to keep going. |
| **Differentiator** | Rank-ups are earned by clearing a **Dungeon with a boss trial**, and failure has a real cost. Competitors are fitness-only and rank by streak or XP. |
| **Decided** | One active System per user, no switching, next System only after completing the current one; System-written quests replace user-written ones; 21/30 opens a Gate; Dungeon failure = double lock + double reps in a separate zone, Gate closed 7 days; **no rank loss**. |
| **Biggest risks** | Quest difficulty wrong for a user; physical safety at higher Fitness ranks; automatic checks (Health Connect, usage access) being unreliable on some Android vendor skins. |

---

## 1. Problem

The trial build lets users write their own objectives. That works for someone who already knows what to do, but most people:
- set objectives that are too easy (no growth) or too hard (they quit), and never adjust them;
- don't know what the next step up looks like;
- lose motivation once the novelty of streaks wears off, because nothing marks real progress.

A System that **writes the quest**, **raises it with rank**, and makes each rank-up a **fight with a real cost** fixes all three.

### 1.1 Competitors (summary; detail in the addendum)

| App | How rank-up works | Gap we fill |
|---|---|---|
| SelfQuest | Streak length; fitness-only dungeons | No trial gate; fitness only |
| RankUp | XP from proof photos; **demotes** on skipped days | No dungeon or trial; fitness only |
| Level Up | XP from workout quests; "training dungeons" for runs | No trial gate; no real penalty |

---

## 2. Personas

> Hypotheses, not research. Validate with the user's own trial and 5–8 interviews before launch.

**Sam: "The Fitness Starter" (Fitness System).** 20s, sedentary job, wants to get fit but doesn't know a plan. Quits when workouts feel random. *Wins when:* the next step is always clear and slightly harder. *Quits when:* a jump in difficulty hurts or feels impossible.

**Noor: "The Quiet Achiever" (Personality System).** Reads and studies but avoids speaking up, struggles to start conversations. *Wins when:* small, specific social and learning tasks build confidence. *Quits when:* tasks feel embarrassing or vague.

**Maya: "The Doomscroller" (Focus System).** Loses evenings to short videos. Has tried screen-time limits and dismisses them. *Wins when:* the phone itself enforces the rule and progress is measured in minutes saved. *Quits when:* enforcement breaks work or payments.

**Anti-personas.** People with injuries or medical limits who need a clinician's plan (Fitness ranks are not medical advice); minors; people who want to write all their own goals (they are served by the old Custom mode, which this PRD retires).

**Job stories**
- When I start, I want the System to place me at the right level, so the first week is neither trivial nor crushing.
- When I've been consistent, I want a real challenge to prove I've grown, so the new rank means something.
- When I fail that challenge, I want a cost that hurts, so I take the next Gate seriously.
- After 30 days, I want to see exactly what changed, so I know the effort worked.

---

## 3. Goals and non-goals

**Goals**
| # | Goal | Measure |
|---|---|---|
| G1 | Users reach their first Gate | ≥ 60% of users who start a System open a Gate within 45 days |
| G2 | Dungeons feel hard but fair | First-attempt clear rate between 40% and 75% |
| G3 | Real, visible gains | ≥ 70% of 30-day reports show improvement on the System's main measure |
| G4 | Users stay | Day-60 retention ≥ 30% |

**Non-goals (this phase)**
| Non-goal | Why |
|---|---|
| More than one active System at a time | Decided: one per user; focus beats breadth |
| User-written quests | Decided: System quests replace them |
| Rank loss / demotion | Decided: ranks are earned for good |
| Social features, leaderboards, PvP | Single-player first |
| Web and iOS | Android only until this is right |
| Medical-grade fitness programming | We give conservative progressions and safety rules, not medical advice |

---

## 4. Concepts

| Term | Meaning |
|---|---|
| **System** | A training path: **Fitness** (STR, VIT), **Personality** (INT, new CHA stat) or **Focus** (DIS). One is active at a time, with **no switching**; the next can be chosen only after the current one is complete. |
| **Rank** | E, D, C, B, A, S within the active System. Never lost. |
| **Daily quest** | Written by the System for your System and rank. Replaces user-written objectives. |
| **Gate** | Opens when **21 of the last 30 days** in the active System are cleared. Must be entered within 48 hours or it closes (no penalty, re-opens after 3 days if still eligible). |
| **Dungeon** | 3 floors on consecutive days: Floor 1, Floor 2, Boss (Rank Trial). |
| **Rank Trial** | The boss: one specific test for that rank-up. |
| **Penalty Zone** | Existing daily penalty (push-ups/squats + random lock), unchanged. |
| **Dungeon Penalty Zone** | New, separate: **double lock + double reps**, its own look and sound; Gate closed for **7 days**. |
| **Level / XP** | Unchanged and global: XP from cleared days and Dungeons; level drives penalty scaling. |

---

## 5. Core flows

### 5.1 First launch: Awakening
1. The System appears (dramatic onboarding in original text) and asks the user to accept it.
2. **Choose your System:** Fitness, Personality or Focus, each with a one-line description and what it trains.
3. **Placement test** (2 minutes, System-specific; see 6.3). The System assigns a starting rank (E, D or C max).
4. Lock targets, sleep window and penalty terms, as today.
5. Dry run: 3 days (existing M7 behaviour).

### 5.2 A normal day
1. At wake time the System issues the daily quest for your System and rank.
2. Complete it before midnight. Automatic checks where available (6.4).
3. Midnight: cleared (XP) or failed (normal Penalty Zone the next day, unchanged rules).

### 5.3 Ranking up through a Dungeon
1. On the day the 21-of-30 condition is met, a notification and an in-app System window: **a Gate has opened** (rank shown, colour by rank).
2. The user enters within 48 hours (hold-to-enter).
3. **Floor 1** (day 1): the daily quest +25%.
4. **Floor 2** (day 2): the daily quest +50%, finished before 18:00.
5. **Boss** (day 3): the Rank Trial for that rank.
6. Each floor must be cleared that day. The normal daily quest is suspended during a Dungeon (the floor replaces it).
7. **Clear:** rank up, +5 stat points, a Gatebreaker title for that rank, rank badge colour change, the 30-day window resets.
8. **Fail any floor:** Dungeon Penalty Zone the next day; Gate closed 7 days; the 21-of-30 window continues (no reset, no rank loss).

### 5.4 One System until it's complete (decided 2026-10-27)
- **No switching.** The user chooses one System and stays in it.
- A System is **complete** when its S-rank Rank Trial is cleared (hold S for 30 consecutive cleared days).
- Only then can the user choose a **second System**, which starts with its own placement test. The completed System keeps its S rank for good and appears on the Status screen as completed.
- Reason: clearing two Systems at once isn't realistic for a normal person; focus beats breadth.
- Reaffirmed 2026-10-31: exactly one System is active and running in the background at any time. No switching, not even at a cost.

### 5.5 Releases and the reduction valve (decided 2026-10-31)
- **The 15-minute release stays free.** It costs no XP and no extra lock. Every release is counted and shown in the report's honesty section and verdict.
- **The reduction valve is limited to 6 reduced days in any 30.** Past the limit the full quest returns automatically until older reduced days leave the window. Status shows the days left. The limit is computed only from the valve settings, so a past day's quest never changes.

### 5.6 Never-locked apps
Phone, messages, contacts, maps, emergency, Settings, this app, the launcher, and banking and UPI apps (Google Pay, PhonePe, Paytm, BHIM, CRED and the major bank apps) can never be lock targets, whatever the user picks. Saved lists drop them on load.

### 5.7 Attributes: deferred to V2 or V3 (decided 2026-10-31)
STR, VIT, INT, CHA and DIS are earned and shown, and stat points can be assigned, but **they have no effect on play in V1.** Claude Design's review flagged that points which do nothing will feel fake within a week. To decide in V2 or V3:
- Either attributes change play (for example harder targets and more XP in the trained stats, or unlocking optional objectives),
- or Status shows only the two stats the active System trains, and stat points are removed.
Until then the UI dims untrained stats and makes no promise about what points do.

---

## 6. Requirements

### 6.1 Daily quests by System and rank (starting values, tunable)

**Fitness** (STR, VIT)
| Rank | Daily quest | Rank Trial (boss, to reach the next rank) |
|---|---|---|
| E | 12-min walk · 10 push-ups (knees allowed) · 15 squats | 30 squats unbroken + 1.5 km walk under 18 min |
| D | 20-min walk · 20 push-ups · 30 squats · 30 s plank | 2 km walk-jog under 16 min + 25 push-ups in sets |
| C | 2 km jog · 30 push-ups · 40 lunges · 45 s plank | 3 km continuous jog |
| B | 3 km run · 45 push-ups in sets · 60 s plank · 10 min mobility | 5 km under 35 min |
| A | 5 km run *or* 45-min workout · 60 push-ups in sets | 8 km *or* a 2-hour hike |
| S | Full-intensity personal program, logged daily | Hold S: 30 consecutive cleared days |

**Personality** (INT, CHA)
| Rank | Daily quest | Rank Trial |
|---|---|---|
| E | Read 10 pages · one journal line | Finish a short book (≤ 150 pages) within the Dungeon |
| D | 20 pages · 5-min journal · greet someone new | Hold a 10-minute conversation with someone new |
| C | 30 pages · 20 min learning a skill · start one conversation | Give a 3-minute talk to at least one person |
| B | 45 min deep work · speak up once in a group | Lead a group discussion or meeting segment |
| A | Teach something you learned · 60 min deep work | Publish or present a finished piece of work |
| S | Create something every day (write, build, present) | Hold S: 30 consecutive cleared days |

**Focus** (DIS)
| Rank | Daily quest | Rank Trial |
|---|---|---|
| E | No phone for the first 20 min after waking | A 3-hour phone-free block |
| D | Social media under 60 min/day | Social media under 30 min for the boss day |
| C | Under 40 min · no phone at meals | A full phone-light day: under 15 min social, no phone at meals |
| B | One 2-hour phone-free block daily | A 6-hour phone-free block |
| A | Under 20 min · no phone after 22:30 | A 24-hour social-media fast |
| S | Locked apps locked all day by choice; messages checked twice a day | Hold S: 30 consecutive cleared days |

Acceptance:
- [ ] Quests and trials are data (one catalogue file), not hard-coded in UI.
- [ ] Each quest item has a type the app can track: checkbox, timer, counter, screen-time cap, phone-free block, or steps/distance.
- [ ] The user can lower a quest by up to 20% for a medical or practical reason; the change applies next day, is logged, and caps XP for that day at 50%. *(Safety valve; see 6.6.)*

### 6.2 Gates and Dungeons
- [ ] The Gate opens exactly when cleared days in the trailing 30-day window reach 21; it is checked at day close.
- [ ] Gate entry window 48 h; not entering closes it without penalty; re-opens after 3 days if still eligible.
- [ ] Floors are consecutive days; a floor fails if not cleared by its deadline (Floor 2: 18:00; others: midnight).
- [ ] During a Dungeon, normal daily-quest failure rules do not also apply (no double punishment for the same day).
- [ ] Clear → rank +1, +5 stat points, title, log entry; Fail → Dungeon Penalty Zone, Gate cooldown 7 days, log entry.
- [ ] No rank is ever lowered.
- [ ] Dry-run days never open a Gate (they don't count toward 21).

### 6.3 Placement test
- Fitness: max push-ups in one set; 1 km walk/jog time.
- Personality: pages read per day lately; comfort starting a conversation (1–5).
- Focus: yesterday's social-media minutes (read from usage access when available).
- Placement can grant E, D or C only (B+ must be earned through Dungeons).

### 6.4 Automatic checks
| Quest type | Source | Permission |
|---|---|---|
| Screen-time cap, phone-free block | Usage access (already granted for the watcher) | None new |
| Steps / distance | Health Connect | New, optional; falls back to honour system |
| Reading, journaling, deep work | In-app timer and counter | None |
| Social tasks (Personality) | Honour system with a one-line note | None |

### 6.5 Dungeon Penalty Zone
- [ ] Applies the day after a failed floor.
- [ ] **Lock length = 2 × the normal lock for your level**, random start within waking hours, clamped to waking hours (existing scheduler).
- [ ] ~~**Exercise = 2 × the normal penalty for your level**; unpaid reps carry over doubled.~~ **Changed 2026-11-07:** exercise stays at the daily quest's own push-ups and squats; reading and phone-free penalties double; nothing carries over.
- [ ] Releases still work (15 min each, counted); the block screen and Penalty tab show **DUNGEON PENALTY** in the new palette.
- [ ] Distinct look (darker palette with crimson and gold), title and sound, so it never feels like an ordinary failed day.
- [ ] Restart Trial and diagnostics are refused while it is in effect (existing rule).

### 6.6 Safety
- Fitness ranks are conservative progressions, not medical advice; onboarding says so and recommends a doctor's advice for health conditions.
- **Changed 2026-11-07:** the exercise penalty is never more than the user's own daily quest and never doubles; the terms carry a health notice (not a medical device; ask a healthcare professional), a stop rule and an 18+ confirmation.
- The 20% quest reduction valve (6.1) exists so injury never forces a failure.

### 6.7 The 30-day report
Generated every 30 days and at the end of each Dungeon:
- Rank journey (ranks reached, Dungeons cleared and failed).
- Before vs after on the System's main measures (e.g. push-ups, km, pages, social-media minutes).
- Stat growth (STR, VIT, INT, CHA, DIS).
- Consistency calendar and longest streak.
- Honesty section: releases, Penalty Zones, Dungeon Penalty Zones, watcher outages.
- The System's verdict (short, cold, original text) and the next Gate it expects.
- Saved locally; shareable as a 1080 x 1350 image through the phone's share sheet. Before sharing, the user can drop the honesty figures (Penalty Zones, releases, reduced days, share confirmed on their word).

### 6.8 Data and migration
- New state: active System, per-System rank and history, Gate state, Dungeon state (floor, deadlines), switch cooldown, new CHA stat.
- **Migration:** the current trial game is archived (existing archive). New users and a restarted trial go through Awakening.

---

## 7. Build milestones (same loop as BUILD_LOOP.md)

| # | Milestone | Done when |
|---|---|---|
| S1 | Systems catalogue + rank state (pure Dart) | Quests per System/rank load from data; ranks never decrease; tests |
| S2 | Gate & Dungeon engine (pure Dart) | 21/30 window, 48 h entry, floors with deadlines, clear/fail outcomes, cooldowns; tests incl. clock edge cases |
| S3 | Dungeon Penalty Zone | Double lock and double reps through the existing enforcer; tests; device check |
| S4 | Awakening onboarding + placement | New onboarding flow; placement assigns E–C; tests |
| S5 | UI: System screen, Gate notice, Dungeon floors, boss screen, Dungeon Penalty look and sound | Widget tests; device check |
| S6 | Automatic checks: usage-access screen time; Health Connect steps (optional) | Verified on the phone |
| S7 | 30-day report | Report from real log data; widget tests |
| S8 | Hardening + regression | All tests, TestSprite web pass, device checklist |

---

## 8. Success metrics (personal trial first)

- Days cleared ≥ 70% outside Dungeons.
- First Gate opened within 35 days of starting.
- First-attempt Dungeon clear rate 40–75% (too high means trials are too easy).
- Report shows improvement on the System's main measure.

---

## 9. Risks

| Risk | Mitigation |
|---|---|
| Quest too hard or too easy for a user | Placement test; 20% reduction valve; values in one data file, tuned from the trial |
| Injury at higher Fitness ranks | Conservative progressions; safety notice; stop rule; reduction valve |
| Health Connect or usage stats unreliable on some vendor skins | Honour-system fallback; System Check shows status |
| Dungeon Penalty too harsh, user quits | Releases still available; Gate cooldown not rank loss; monitor in trial |
| Banking apps and developer mode | Not caused by the app; documented install path without developer mode |
| Theme close to the source work | Feel and generic mechanics only; all names, text, art and sound original |

---

## 10. Open questions

| # | Question | Blocking? |
|---|---|---|
| 1 | ~~Switching System~~ **Decided:** no switching; the next System only after the current one is complete (5.4) | Done |
| 2 | ~~Quest-reduction valve~~ **Decided:** keep it (up to 20%, next day, logged, XP capped at 50% that day) | Done |
| 3 | Should the S rank have its own final Dungeon, or is "hold S for 30 days" the end? | No |
| 4 | Health Connect for steps: add in S6 or later? | No |
| 5 | ~~Report sharing~~ **Decided:** share as an image, honesty figures optional (6.7) | Done |
| 6 | ~~Release cost~~ **Decided:** the release stays free (5.5) | Done |
| 7 | Attributes: change play, or show only the trained stats? Deferred to V2 or V3 (5.7) | No |

---

## Changelog
- **v0.8 (2026-11-07, iteration 1 of the audit loop; user decisions):** Focus is the core System and comes first; Fitness and Personality are optional packs; switching System is allowed at any time outside a Dungeon (starts tomorrow, ranks kept, the Gate count restarts). Fitness owes no penalty besides the lock. The lock lasts a fixed 4 hours from a time the user chose (default 18:00). Each lock allows 2 releases; an emergency exit always ends it (logged). One verdict in any 14 days can be contested. Removing an app from the lock list takes effect after 7 days and the list can't be emptied. Settings screen (rest period, lock time, switching, log export, in-app privacy policy). Supersedes 5.4 (no switching) and 5.5 (unlimited free release).
- **v0.7 (2026-11-07, independent audit P0 fixes):** the exercise penalty is the push-ups and squats of the user's own daily quest for that day (reduction valve applied; never scaled by level, never doubled by the Dungeon Penalty; rank S Fitness owes none); unpaid penalties expire at midnight and are logged, never carried or doubled; the Dungeon Penalty doubles the lock and a reading or phone-free penalty only; the terms add the health notice, a stop rule and an 18+ confirmation; app data is excluded from backup and device transfer. Supersedes the exercise lines in 6.5 and 6.6. See audit/AUDIT_REPORT_2026-11-07.md.
- **v0.6 (2026-10-31, user decisions after the Claude Design review):** release stays free; one System at a time is reaffirmed; attributes deferred to V2 or V3 with no effect in V1; the reduction valve is limited to 6 days in any 30; banking and UPI apps are never locked; the report can be shared as an image, with the honesty figures optional; the verdict adds "Most of it rests on your word" when more than 60% of judged days carry an honour confirmation.
- **v0.5 (2026-10-31, from the Claude Design review):** the Personality reflection needs five lines of at least four words each; counted objectives and penalty reps have an undo (never below zero); the reduction valve is locked while a Dungeon is in progress; System notices queue by priority (gate, rank-up, failure, cleared) with a "NOTICE i / n" counter, and ACKNOWLEDGE arms only after the notice has played; a cleared quest with a screen-time cap says the cap still holds until 23:59; the report's verdict opens with one rule-based headline (under half cleared, more releases than locks served, lock outages, or the clear rate).
- **v0.4 (2026-10-31, from the first device test):** each System has its own penalty besides the app lock: Fitness owes push-ups (squats past the cap); Personality owes pages (20 +2/level, cap 60) and a written reflection of at least five lines (kept in the log); Focus owes a phone-free block (60 min +5/level, cap 180) run in the app with the chosen apps locked. Anything unpaid still doubles. Personality rank E adds "Say hello to someone you rarely talk to". Each day's quest is frozen when first issued, so an app update never changes a quest already shown. The System choice explains each System (what it trains, rank E and S quests, its penalty); the placement test says it only sets the rank; the rank step reveals the daily quest.
- **v0.3 (2026-10-27, from the QA review):** a System chosen after completing one starts the next day (never judged on the day it is chosen); Dungeon floors are built on the full daily quest and ignore the reduction valve (full XP); the Dungeon Penalty keeps the 150 push-up cap, with the excess added as squats; Floor 2 screen-time caps are measured up to 18:00; a cap with no reading at judging is not kept unless it was confirmed on the honour system; the report is always available from Status (it is built live, so it covers the end of each Dungeon), and the 30-day notice is issued even if the app wasn't opened on day 31.
- **v0.2 (2026-10-27):** no switching between Systems; a second System only after the current one is complete (S-rank trial cleared). The 20% reduction valve is kept.
- **v0.1 (2026-10-27):** first draft from the user's decisions: Systems (one active), System-written quests, 21/30 Gate rule, 3-floor Dungeons with a Rank Trial boss, Dungeon Penalty Zone (double lock + double reps, 7-day Gate cooldown), no rank loss, 30-day report.
