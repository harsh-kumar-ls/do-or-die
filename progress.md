# Do or Die — Progress

One place for where the project stands: what's built, what was decided, and what comes next. Last updated 2026-11-07 (app version 0.9.0).

The detailed records stay where they are. This file summarises them and points to them:

| File | What it holds |
|---|---|
| [PROJECT.md](PROJECT.md) | The 30-day trial plan and the original penalty rules |
| [SYSTEMS_PRD.md](SYSTEMS_PRD.md) | Systems, ranks, Gates, Dungeons, and every decision since (changelog at the end) |
| [BUILD_LOOP.md](BUILD_LOOP.md) | How the app is built and tested, with a dated entry for every milestone and release |
| [PRD.md](PRD.md) | The longer-term public product spec (v1 Android, v2 web, v3 iOS) |
| [COMPETITOR_ANALYSIS.md](COMPETITOR_ANALYSIS.md) | Research on similar apps |
| [design/](design/) | Approved visual direction, Claude Design prompts and prototypes, brand images |
| [release/PLAY_RELEASE.md](release/PLAY_RELEASE.md) | Play internal-testing kit: upload steps, store listing, Data safety, permission declarations |
| [Privacy policy](https://harsh-kumar-ls.github.io/do-or-die/privacy-policy.html) | Public page (from `docs/`), required by Play |

---

## 1. Where things stand

| | |
|---|---|
| **Version** | 0.9.0 (build 13): **Play internal-testing candidate, GO** |
| **Play bundle** | `dist/DoOrDie-0.9.0.aab`, signed with the upload key (verified) |
| **Phone** | Same code installed (`dist/DoOrDie-0.9.0-device.apk`, development-signed so the trial data is kept); no crashes, watcher running, System Check 7/7 |
| **Current run** | Personality System, rank E, day 8 of 30, live. 2 of 21 days toward the Gate, streak 1 (best 2) |
| **Tests** | Format and analyze clean; 205/205 automated tests; TestSprite 14/14 in one batch on the final build |
| **Code** | Committed and pushed on `main`; tagged `v0.9.0` |

**Waiting on you:** back up the upload key, then upload to Play internal testing (section 6.1).

---

## 2. What the app is

A habit app run by a cold, game-style **System**. Original theme, inspired only by the general vibe of "System" stories; no characters, names, logos or art from any existing work.

1. You choose **one System**: Fitness (trains STR, VIT), Personality (INT, CHA) or Focus (DIS).
2. A short **placement test** sets your starting rank (E, D or C at most).
3. Every day the System issues a **daily quest** for your System and rank. Clear it before midnight for XP.
4. Fail it and the **Penalty Zone** follows the next day:
   - Your chosen apps lock for 4 h + 20 min per level, starting at a random time during waking hours (never during your rest period).
   - You owe a penalty that matches your System: the push-ups and squats from your own daily quest for Fitness (never more, never doubled), pages plus a written reflection for Personality, a phone-free block for Focus.
   - Anything unpaid expires at midnight and is logged; nothing carries over (changed 2026-11-07, audit P0).
   - A 15-minute release is always available; it's free, but every release is counted.
5. Clear **21 of the last 30 days** and a **Gate** opens. Enter within 48 h for a 3-day **Dungeon**: Floor 1 is the quest +25%, Floor 2 is +50% and must be done by 18:00, Floor 3 is the **Rank Trial**. Clear it to rank up.
6. Fail a floor and the **Dungeon Penalty** follows: double lock (and double reading or phone-free penalty; exercise never doubles), Gate closed for 7 days. Ranks never go down.
7. A System is complete when rank S is held for 30 days. Only then can a second System be chosen. No switching before that.
8. Every 30 days a **report** shows what changed, including every release taken. It can be shared as an image.

---

## 3. What we have built (timeline)

### Planning (2026-10-19 to 2026-10-20)
- Public-product PRD, competitor analysis, then a personal 30-day trial plan (PROJECT.md) that replaced the PRD as the working document.
- Build loop with test tiers and hard gates (BUILD_LOOP.md).
- Visual direction chosen: "A2 + P3" (design/DESIGN.md).

### Phase 1: the trial build (M0–M8, 2026-10-20 to 2026-10-22)
| Milestone | What it delivered |
|---|---|
| M0 Environment | Flutter, Android SDK, JDK 17, phone connected over USB |
| M1 Domain core | Pure-Dart rules engine: days, clock, penalties, debt, sleep window, random lock scheduler, levels |
| M2 Storage and log | One saved document plus an append-only trial log (JSON and CSV export); user-chosen lock list with edit rules |
| M3 Quest UI | Quest, Status and Penalty screens, System notices, original sounds and haptics |
| M4 Notifications and trusted time | Scheduled warnings and notices; a trusted clock so changing the phone's time can't dodge a failure |
| M5 Blocking spike | Proved app blocking works on the phone |
| M6 Penalty Zone | Real locks on the user's chosen apps, block screen, protected apps |
| M7 Dry run | 3 days of penalties logged but not applied; restart trial (refused while a penalty is owed) |
| M8 Hardening | Watchdog for the blocker, System Check screen, outage logging, regression pass |

Changes from the first live days:
- The emergency exit became a repeatable **15-minute release** that spends lock time and is counted.
- **UPI apps stopped working** because banking apps refuse to run while any accessibility service is on. The accessibility service was removed and replaced by a foreground **watcher** that uses usage access and "display over other apps". UPI works again.

### Phase 2: Systems and Dungeons (S1–S8, 2026-10-27)
| Milestone | What it delivered |
|---|---|
| S1 | Systems catalogue: quests for every System and rank as data |
| S2 | Gate and Dungeon engine (21/30, 48 h entry, floors, deadlines, cooldowns); screen-time caps measured from usage access |
| S3 | Dungeon Penalty (double lock and penalty, own look and sound) |
| S4 | "Awakening" first-run flow with the placement test |
| S5 | System UI: rank badge, Gate banner, Dungeon floors, reduction valve, attributes |
| S6 | Automatic checks from usage access (Health Connect left out on purpose) |
| S7 | 30-day report |
| S8 | Independent review found 9 defects (3 wrongful-penalty risks); all fixed with tests |

### Releases since (2026-10-31)
| Version | What changed |
|---|---|
| 0.2.1 | Hotfix: black screen at start. Release builds stripped code the save system needs; shrinking is now off |
| 0.3.0 | Your first device feedback: onboarding fills the screen; placement questions match the quest; each System explained; **penalties follow the System** (no push-ups for Personality); each day's quest frozen when issued |
| 0.4.0 | Awakening rebuilt from the Claude Design prototype |
| 0.5.0 | Every other Claude Design screen ported: Quest, Status, Penalty Zone, notices, report, native block screen, flip-card System carousel |
| 0.5.1 | The line under the date shrinks to fit instead of cutting off |
| 0.6.0 | Report share image, 6-day reduction limit, banking and UPI apps never lockable, verdict line for records that rest on your word |
| 0.7.0 | The Player: an original animated avatar on Quest, Status and the System cards; System entry sequence; new app icon |
| 0.7.1 | "Lock served" caption, System name fits on Status, outages measured by a watcher heartbeat (restarts no longer counted) |
| 0.8.0 | An anime-style 3D character (later removed) |
| 0.9.0 | Character removed; animated System sigil; emblem icon and Play assets; release signing; Play-restricted battery permission removed; privacy policy; release kit; Penalty Zone fixes (no "lock served" on the next day, no app-name flash) |

---

## 4. Decisions so far

| Date | Decision |
|---|---|
| 2026-10-20 | Trial first, launch only if it works. Android only for now |
| 2026-10-20 | Penalty rules: next-day penalty, random lock in waking hours, push-up cap 150 then squats, unpaid doubles. Exercise does not end the lock early |
| 2026-11-07 | Audit P0 fixes: the exercise penalty is the push-ups and squats of the user's own daily quest (no level scaling, no doubling); nothing carries over or doubles; game changes are serialised (fixes a lost-update bug); 18+ confirmation, health notice and stop rule in the terms; backup and device transfer off. See audit/AUDIT_REPORT_2026-11-07.md |
| 2026-10-21 | Emergency exit replaced by the counted 15-minute release |
| 2026-10-22 | No accessibility service (banking apps refuse it); usage-access watcher instead |
| 2026-10-27 | One System at a time; System-written quests replace user-written ones; no rank loss; 21/30 opens a Gate |
| 2026-10-27 | 20% quest reduction kept (next day only, half XP) |
| 2026-10-31 | Each System has its own penalty; Personality reflection is 5 lines of 4+ words |
| 2026-10-31 | Release stays free (no XP or lock cost) |
| 2026-10-31 | One System active at a time, no switching even at a cost |
| 2026-10-31 | Attributes have no effect in V1; decide their role in V2 or V3 |
| 2026-10-31 | Report shareable as an image, honesty figures optional |
| 2026-10-31 | Reduction limited to 6 days in any 30 |
| 2026-10-31 | Banking and UPI apps can never be locked |
| 2026-10-31 | Not adopted from Claude Design: finishing the penalty does not end the lock early |
| 2026-10-31 | Publishing parked until the app has run well for a week or two |
| 2026-11-07 | Publish a beta now: Google Play **internal testing** on the existing personal developer account |
| 2026-11-07 | No character avatar. The animated System sigil (emblem + rank hexagon) is the app's face; a commissioned illustration can come later |
| 2026-11-07 | Privacy policy hosted on GitHub Pages from `docs/` |
| 2026-11-07 | Release process: manager plan, engineering, QA, then a production inspection with a go / no-go before anything ships |

---

## 5. How it's built and tested

**Stack:** Flutter 3.47.7 / Dart 3.13.5, Android SDK 36 (target 36), JDK 17. Packages: shared_preferences, flutter_local_notifications, flutter_soloud, flutter_animate, flutter_timezone, timezone, share_plus; dev: flutter_launcher_icons. Fonts: Chakra Petch and JetBrains Mono (both SIL OFL).

**Layout**
```
lib/domain/    rules engine (pure Dart): quests, penalties, levels, lock scheduling,
               Systems catalogue, Gates and Dungeons, placement, block list, config
lib/data/      saved game and the append-only log
lib/app/       GameService (the only API the UI uses), enforcer, notification planner,
               trusted clock, 30-day report
lib/platform/  Android bridges: blocker, notifications, network time, usage meter
lib/ui/        screens, HUD widgets, theme, sound
android/       watcher service, block screen, usage meter, trusted time (Kotlin)
test/          unit and widget tests
tools/         sound generator, TestSprite plan generator, brand image builder,
               local web server
docs/          privacy policy (GitHub Pages)
release/       Play release kit and store screenshots
```

**Gates, in order:** format, analyze, unit tests, widget tests, then TestSprite (web) and a device check.

**What each kind of test covers**
- Unit and widget tests: rules, penalties, quests, screens.
- TestSprite (14 tests): the web build with a test mode where hold buttons accept a click. Plans are generated by `tools/gen_testsprite_plans.py`; ids are in `testsprite-plans/test-ids.json`.
- Phone only: app blocking, the block screen, notifications, reboot and battery behaviour. TestSprite cannot cover these.

**Release rules learned the hard way**
- Code shrinking stays off for release builds (it caused the 0.2.0 black screen).
- Install updates with `adb install -r` only; a force stop turns the blocker off.
- Launch the exact release APK on the phone before handing it over.
- Play builds: `flutter build appbundle --release` (upload key). Phone builds: `DOD_DEBUG_SIGN=1 flutter build apk --release` (development key, so the existing install updates without losing data).
- The upload key lives outside the repo (`~/.do-or-die/upload-keystore.jks`); its passwords are in git-ignored `android/key.properties`. Never commit either.

---

## 6. What comes next

### 6.1 Now: Play internal testing (your part)
- [ ] Back up the upload key: `~/.do-or-die/upload-keystore.jks` and `android/key.properties` (password manager plus an offline copy).
- [ ] Play Console: create the app, then Internal testing, upload `dist/DoOrDie-0.9.0.aab`, fill the listing and App content from `release/PLAY_RELEASE.md`.
- [ ] Add testers by email and send them the opt-in link.
- [ ] Line up at least 12 people for the closed test (14 continuous days) that a personal account needs before a public release.
- [ ] Your own phone: stay on the sideloaded build during the trial; installing from Play means uninstalling first, which erases the trial data.

Done since the last update: the midnight checks worked (6 Nov cleared and credited); Status, Penalty Zone and System Check verified on the phone; UPI and banking apps unaffected.

### 6.2 Device checks still open (from BUILD_LOOP.md)
- [ ] Focus System: a phone-free block locks the chosen apps and unlocks when it ends.
- [ ] Focus caps: the social-media reading rises after using a locked app.
- [ ] Penalty and Dungeon Penalty block screens look right on the phone.
- [ ] A Gate, a Dungeon and a rank-up on the real phone (needs 21 cleared days).

### 6.3 Open questions
| Question | When |
|---|---|
| Attributes: change play, or show only the trained stats and drop points? | V2 or V3 |
| Does rank S get its own final Dungeon, or is "hold S for 30 days" the end? | Later |
| Health Connect for steps and distance, or keep the honour buttons? | Later |
| Protection against uninstalling during a run (device admin)? | Later |
| Final in-app name for the player | Later |

### 6.4 Small backlog
- A dedicated automated test for the "Most of it rests on your word" verdict line.
- A TestSprite test for the share sheet (needs a judged day in the web build).
- Tune XP and level thresholds after the first weeks (they are placeholders).
- Tune quest targets per rank from real use.

### 6.5 Release path
| Stage | Status |
|---|---|
| Internal testing (up to 100 invited testers) | **Ready**: bundle, listing, privacy policy, assets and answers prepared |
| Closed test (12+ testers, 14 continuous days) | Next; required before production on a personal account |
| Production (public) | **No-go** until the closed test ends cleanly and its feedback is handled |
| Then | The PRD.md roadmap: v1 Android hardening, v2 web, v3 iOS |

Review risks to watch: the foreground-service (special use) declaration may need a short video; the exact-alarm permission may draw a question; check that no other Play app is already named "Do or Die".

---

## 7. Working rules

- Tests first; gates in order; one milestone at a time; stop after 3 failed attempts on the same failure.
- Penalty rules live in `lib/domain/` and one config file, never in UI code.
- A wrongful penalty is the worst possible bug.
- Never enable a lock before its escape exists (releases, protected apps).
- System copy: terse and formal, no emojis, no exclamation marks.
- Don't change the phone's security settings or try to get around banking-app checks.
- Don't tap the phone or take screenshots while you're using it.
- Ask before anything outward-facing (publishing, posting, sending).
