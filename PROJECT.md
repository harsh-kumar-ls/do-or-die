# Do or Die — Personal Project Plan

**Status:** v0.1 · **Replaces PRD.md as the working document.** [PRD.md](PRD.md) is kept as the launch-phase reference; [COMPETITOR_ANALYSIS.md](COMPETITOR_ANALYSIS.md) stays as research.

---

## 1. What this is now

A habit app I build **for myself**, run for **30 days**, and only then decide whether to launch it publicly (Play Store, then web, then iOS).

**Core idea (unchanged):** a dark, System-style app issues my daily quest. Clear it and I earn XP, stats and rank. Fail it and I enter the **Penalty Zone**: my chosen apps are locked and I owe a physical penalty. Tasks and penalties are written and tuned by me.

**Why change the framing:** the PRD was written for a public product (personas, market metrics, store policy, monetization). Those matter only if the trial succeeds. For now the only user is me, and the only question is: **does this actually change my behavior?**

---

## 2. The one question the trial must answer

> Over 30 days, does the real penalty make me do my habits more reliably than I did before, without making me quit the app?

Everything else is secondary.

---

## 2.1 My setup (decided 2026-10-20)

**Daily quest**
| Task | Target | Tracking type (proposed) |
|---|---|---|
| Have breakfast | Once daily | Checkbox, with its own morning deadline (time TBD) |
| Study | 2 hours | In-app timer, accumulates toward 2:00 |
| Read | 30 pages | Page counter |

**Physical penalty:** 50 push-ups (counted in the app; doing them in sets is allowed).

**Phone:** a personal Android phone with a vendor skin known for aggressively killing background apps, so blocking reliability is tested first (see section 8).

**Apps to lock: chosen by the user, not fixed.** The user picks any installed apps from a list in the app. My choice for the trial: Instagram, YouTube, BGMI. Never selectable: phone, messages, maps, emergency, system settings, and this app. Changes to the list follow the edit rules (removing an app applies from the next day; adding one applies immediately).

**UI requirement (user, 2026-10-20):** highly interactive, polished, "classic" game-UI quality, and strongly in the Solo Leveling *System* style (glowing blue system windows, terse system notices, rank and stat panels, a menacing red Penalty Zone). Original art and copy only; no assets, logos, characters or text from the manhwa.

**Penalty rules (decided 2026-10-20, from the user's description):**
1. Every task's deadline is end of day. Breakfast can be ticked any time that day.
2. A task not completed by the end of day D is a **failed task**.
3. If **any** task fails on day D, the penalty applies on the **next day (D+1)**. One penalty per failed day, however many tasks failed.
4. **Physical:** `50 + 5 × (level − 1)` push-ups, due by the end of D+1. Example: level 10 is 95, level 11 is 100.
5. **Push-up cap: 150** (reached at level 21). Past the cap, push-ups stay at 150 and **squats** are added: 50 at level 22, +5 per level after that.
6. **Digital:** Instagram, YouTube and BGMI are locked for `4 hours + 20 minutes × (level − 1)` on D+1. Level 1 is 4h, level 10 is 7h. The lock does **not** last the whole day.
7. **The lock starts at a random time on D+1, not announced in advance** (the twist). It must never start or run during sleep:
   - The user sets a sleep window (default 23:00–07:00). The user can change it, effective from the next day.
   - The start time is picked at random so the whole lock fits inside waking hours.
   - If the lock is longer than the waking window (very high levels), it is clamped to the waking window. Logged.
8. Doing the exercise does **not** end the lock early.
9. **Carry-over with 100% interest:** unpaid reps are **doubled** and added to the next day's debt. Example: owe 50, do 40, so 20 are added tomorrow. Carry-over **can exceed the 150 cap**.

All numbers live in one config file.

**Still to decide:** the points in section 9.

---

## 3. Scope: Phase 1 (personal build)

**Build only what the 30-day test needs.** Android, installed directly on my phone (no Play Store, no accounts, no cloud).

### Must have
| # | Feature | Notes |
|---|---|---|
| 1 | **Task setup** | I write 1–5 tasks with targets. Editable. |
| 2 | **Daily quest** | Issued each day; deadline I choose; hold-to-confirm completion. |
| 3 | **Failure detection** | Deadline passes with incomplete tasks, quest Failed. Must be reliable (see risks). |
| 4 | **Digital penalty** | Chosen apps blocked for X minutes after a failure. Survives app kill and reboot. |
| 5 | **Physical penalty** | I choose exercise and reps (e.g. 10 push-ups); completing it shortens or ends the lock. |
| 6 | **XP, level, rank, stats** | Enough to feel progress: XP on clear, levels, rank E→S, stat points I allocate. |
| 7 | **Notifications** | Quest issued, deadline warning, failure. |
| 8 | **Safety valve** | Emergency exit from the lock (logged), plus calls, messages, maps and the dialer are never blockable. |
| 9 | **Edit rules** | Easing a task or penalty only applies from the next day, so I can't soften things after failing. |
| 10 | **Trial log** | Every clear, fail, penalty, emergency exit and edit is recorded locally and exportable, so I can judge the 30 days honestly. |
| 11 | **Theme** | Dark UI, System-blue and Penalty-red, terse System-voice copy, distinct sounds. Keep it simple; polish is Phase 2. |

### Deliberately cut for now
Accounts and cloud sync, web, iOS, Gates (multi-day challenges), social features, leaderboards, camera push-up verification, money pledges, AI features, Play Store compliance work, onboarding polish, monetization.

**Why cut them:** none of them helps answer the one question. They come back only if the trial passes.

---

## 4. Technical approach (personal use)

- **Flutter**, Android only for now. Keep platform-specific code (app blocking, notifications, boot handling) behind interfaces so web and iOS can be added later.
- **Install via a direct APK or `flutter run`** onto my own phone. No store review, so I'm free to use the most reliable blocking method.
- **App blocking:** I recommend an **Android Accessibility Service** (detects the foreground app and shows a block screen) paired with a foreground service. It's the most reliable approach for personal use. It is also the one Google Play scrutinizes most, so it's a **launch-time risk**, not a trial blocker. The alternative (usage-stats access plus an overlay) is a possible fallback for launch.
- **Storage:** local database on the device. Export as JSON or CSV for the trial review.
- **Time handling:** use a trusted time source and store the deadline as an absolute timestamp, so changing the phone clock can't dodge a failure and timezone changes don't cause false ones.
- **Anti-self-sabotage (optional):** uninstalling the app is the obvious escape. Device-admin protection can make that harder; decide later whether I want it, since a lock I can't escape is a safety question too.

---

## 5. 30-day trial protocol

**Before day 1 (setup):** pick 2–3 tasks I can honestly do daily, set a penalty I'll find uncomfortable but safe, choose the apps to lock.

**Days 1–3: dry run.** Run the app with penalties **logged but not applied**. Goal: confirm quests, deadlines and failure detection behave correctly. A wrongful penalty on day 1 would sour the whole trial, and other stakes apps' reviews show false failures destroy trust fast.

**Days 4–30: live.** Real penalties on.

**Daily (30 seconds):** the app logs automatically; I add one line only if something felt wrong.

**Weekly (10 minutes):** review the log. Am I clearing quests? Do I game it? Which tasks or penalties are too easy or too hard? Adjust once per week at most.

**Rules for myself**
- No editing tasks or penalties mid-day.
- Emergency exit only for real emergencies; each use is logged and I review them.
- If a penalty makes me skip sleep, meals or recovery, stop and reduce it. The goal is better habits, not self-punishment.

---

## 6. Success criteria and go/no-go

Judge at day 30 from the log, not from memory.

| Measure | Pass | Fail signal |
|---|---|---|
| Quest clear rate (days 4–30) | ≥ 70% | < 50% |
| Still opening the app daily in week 4 | Yes | Skipping the app itself |
| Emergency exits used | ≤ 3 in the live period | Used to dodge, not for emergencies |
| Compared with my habit consistency before the app | Clearly better, by my own honest read | No change |
| Penalty feels fair | Mostly yes | Frequent false failures or bugs |
| Would I miss it if it stopped? | Yes | No |

**Decision at day 30**
- **Go (launch track):** most pass, and I want to keep using it. Next: find 3–5 friends to try it (my own use is a biased sample of one), resolve the Play Store blocking-policy question, then follow the public PRD for v1 hardening, web (v2) and iOS (v3).
- **Iterate:** mixed result. Fix the specific cause (task design, penalty level, bugs) and run another 2 weeks.
- **Stop or pivot:** it didn't change my behavior. That's a valid result and a cheap one.

---

## 7. Risks (personal version)

| Risk | Mitigation |
|---|---|
| **A bug causes a wrongful penalty** | 3-day dry run; a grace and dispute path for false failures; log everything |
| **Blocking is unreliable** (OEM battery killers kill the service) | Test on my actual phone early; exempt the app from battery optimization; verify the lock survives reboot |
| **I cheat or bypass it** | Edit cooldowns; log emergency exits; optionally device-admin protection |
| **Penalty too harsh, I quit** | Start gentle; tune weekly; cap physical reps |
| **Physical penalty injures or over-trains me** | Only exercises I choose, daily rep cap, stop rule above |
| **Trial result isn't generalizable** | Treat it as a go/no-go for friends' testing, not proof of market fit |

---

## 8. Build order

1. Project skeleton, local storage, design tokens and theme.
2. Task setup and daily quest loop (issue, complete, clear or fail), with trusted-time deadlines.
3. XP, levels, rank, stats.
4. Notifications.
5. Trial log and export.
6. Digital penalty (blocking), the riskiest piece, so test it early on my phone.
7. Physical penalty and the shorten-the-lock rule.
8. Safety valve and edit rules.
9. Dry-run mode, then start the trial.

I'd actually do step 6 as a spike right after step 1, because if blocking doesn't work reliably on my phone, the plan changes.

---

## 9. Open questions

| # | Question | Blocking? |
|---|---|---|
| 1 | ~~First habits~~ Decided: breakfast, study 2h, read 30 pages | Done |
| 2 | ~~Apps to lock~~ Decided: Instagram, YouTube, BGMI | Done |
| 3 | ~~Physical penalty~~ Decided: 50 push-ups | Done |
| 4 | Do I want device-admin protection against uninstalling during the trial? | No |
| 5 | ~~Phone~~ Decided: a personal Android phone | Done |
| 6 | Final name and in-app title for me (placeholder "Hunter")? | No |
| 7 | ~~Per-task deadlines~~ Decided: all end of day; penalty starts next day for the whole day | Done |
| 8 | ~~Per task or per day~~ Decided: 50 per failed day | Done |
| 9 | ~~Level scaling~~ Decided: +5 push-ups and +20 min lock per level | Done |
| 10 | ~~Cap~~ Decided: 150 push-ups, then squats at 50, +5/level | Done |
| 11 | ~~Lock length~~ Decided: 4h + 20 min/level, not the whole day; exercise doesn't end it early | Done |
| 12 | ~~Carry-over~~ Decided: yes | Done |
| 13 | ~~Lock start~~ Decided: random, inside waking hours (user-set sleep window) | Done |
| 14 | ~~Carry-over vs cap~~ Decided: carry-over doubles and can exceed the cap | Done |

---

## 10. After the trial

If the answer is "go", the work moves back to [PRD.md](PRD.md): personas validated with real people, competitor facts verified (SelfQuest in particular, which already ships camera rep counting), Play Store policy resolved for blocking, and then the v1 / v2 / v3 scope there.
