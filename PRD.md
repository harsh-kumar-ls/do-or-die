# Do or Die — Product Requirements Document

**Status:** Draft v0.2 · **Working title:** Do or Die · **Stack:** Flutter · **Platforms:** Android (v1) → Web (v2) → iOS (v3)
**Companion docs:** [COMPETITOR_ANALYSIS.md](COMPETITOR_ANALYSIS.md)
> **Note:** The project is now a personal 30-day trial first. The working plan is [PROJECT.md](PROJECT.md). This PRD becomes the launch-phase spec only if the trial passes.
**Format:** Structured after patterns that top product teams use (see changelog): a one-page summary up front (SeatGeek), a Who/Why/What opening (Product Hunt), a framed problem statement (Asana), explicit non-goals and a step-by-step flow (Square), and success criteria plus risks (Asana one-pager).

---

## 0. One-Page Summary

| | |
|---|---|
| **What** | A dark, System-driven habit game for Android. The user writes their own daily quest. Clear it to earn XP, stats and rank. Fail it and you enter the **Penalty Zone**: chosen apps are locked and a physical penalty (e.g. push-ups) is demanded. |
| **Who** | People who have repeatedly failed to keep habits with soft tools, and who respond to games, ranks and stakes. See Section 4. |
| **Why** | Habit apps without consequences are easy to ignore. Apps with consequences (Opal, Beeminder) feel like tools, not experiences. Solo Leveling-style apps have the theme but only in-game penalties. See Section 1.1. |
| **Why us / differentiator** | A serious, consistent System identity, combined with **real, user-tuned consequences** (digital and physical), all user-owned. |
| **v1** | Android. Quest, XP/rank/stats, notifications, digital and physical penalty, safety and anti-abuse rules. Local data only. |
| **v2** | Web, accounts and sync, Gates (multi-day challenges), optional camera verification, accountability contact. |
| **v3** | iOS, social layer, optional money pledges. |
| **Success** | Day 30 retention ≥ 35%; < 10% penalty-driven uninstalls. |
| **Biggest risks** | Google Play rules on app blocking; penalties so harsh users quit; physical-penalty safety. |
| **Blocking questions** | How to block apps on Android within Play policy; what happens if the user refuses permission. |

---

## 1. Problem Statement

People know which daily habits they want (exercise, study, sleep, reading) but fail to keep them. Existing habit trackers are easy to ignore: missing a day has no consequence, and the reward (a checkmark, a streak number) is weak. Users who want to change need **stakes** and **a reason to open the app every day**.

*Do or Die* turns daily habits into a dark, System-driven RPG. The user writes their own daily quest. Completing it earns XP, stat points and rank. Failing it throws them into the **Penalty Zone**, a real consequence that disables their distracting apps and forces a physical penalty. The theme (cold System voice, ranks, danger) gives the app the emotional weight a normal to-do list lacks.

**Inspiration note:** We borrow the *vibe* of Solo Leveling (a System issuing daily quests, a feared penalty, visible growth). We do **not** use its characters, names, story or assets. All names, art and copy are original.

### 1.1 Competitive Landscape (summary)

Full detail and sources in [COMPETITOR_ANALYSIS.md](COMPETITOR_ANALYSIS.md). Prices there are unverified.

| Category | Examples | What they do well | What they miss |
|---|---|---|---|
| RPG habit trackers | Habitica, Habit Hero | Mature gamification, parties, cross-platform | Light tone; penalty is in-game HP loss only; gamification fatigue |
| System-themed life-XP apps | Level Up: SoloLeveling Life XP, Quest Leveling, Solo Hunter, HabitForge | The aesthetic; on-device privacy | Thin execution; penalties appear in-game only; IP exposure from using Solo Leveling branding |
| Streak trackers | Streaks | Polish and simplicity | No consequence for failing; Apple-only |
| Commitment / stakes | Beeminder, stickK | Real consequences | Spreadsheet feel, money-only, no game |
| Focus / app blocking | Opal, one sec, Forest | Real phone friction | No habit or progression layer; costly (Opal reported $60–$100/year) |

**Gap we target:** nobody found combines a serious System identity, XP and rank, **and** real digital plus physical consequences with user-owned tasks.
**Evidence limit:** this is one desk-research pass; verify via the checklist in the competitor doc before launch decisions.

---

## 2. Goals

| # | Goal | Measure |
|---|------|---------|
| G1 | Make daily habit completion stick | ≥ 35% of users still completing quests on Day 30 (stretch 45%) |
| G2 | Make the penalty feel real without making users quit | Penalty-related uninstalls < 10% of installs within 30 days |
| G3 | Make the theme the product's identity | ≥ 60% of users rate the "System" feel 4+/5 in the Day 7 survey |
| G4 | Keep onboarding short | ≥ 70% of installs create their first quest within 3 minutes |
| G5 | Give users control over difficulty | ≥ 80% of users customize at least one quest or penalty in first week (indicates fit, not friction) |

---

## 3. Non-Goals (v1)

| Non-goal | Why |
|----------|-----|
| System-generated or AI-suggested tasks | The user knows their capacity and habits better than we can predict. Tasks are user-written. |
| Social features, leaderboards, guilds | Adds moderation and scale cost; core loop must be proven alone first. |
| Money pledges / financial stakes | Payment, app store policy and legal complexity. Revisit later. |
| Camera-based verification of exercise | Honor system in v1; computer vision is a v2+ investment. |
| Real-IP assets (Solo Leveling characters, names, art, music) | Legal risk. Original theme only. |
| Web and iOS in v1 | Android first; the Flutter codebase is structured to port. |

---

## 4. Users and Personas

> **Evidence status:** These personas are **hypotheses** from desk research and team assumptions. No user interviews have been done. Validate with 8–10 interviews (people who have tried and abandoned habit apps) before v1 design freeze. Names are fictional; update attributes after research.

### 4.1 Primary persona: Kai, "The Serial Restarter"

| | |
|---|---|
| **Snapshot** | Early-to-mid 20s, student or early-career. Plays games, watches anime or reads manga. Phone use is high. |
| **Context** | Starts a new routine every few weeks (gym, study, reading) and drops it within 10 days. Has tried 2–3 habit apps; all became ignorable notifications. |
| **Goals** | Build 2–4 specific daily habits and see real, proof-of-progress growth. Feel like a person who follows through. |
| **Frustrations** | "Missing a day costs nothing." Streaks feel meaningless; apps feel childish or corporate. Motivation fades after the novelty. |
| **Current workflow** | Notes app or a free tracker, phone alarms, occasionally a friend as a nag. |
| **What motivates them** | Progression (levels, ranks), identity ("I'm leveling up"), and a bit of fear. |
| **What would make them quit** | A penalty they can't tune; a childish tone; buggy blocking that locks them out of something important. |
| **Success from their seat** | 30 days without a reset, and a rank they're proud of. |
| **Hypothesis to test** | Kai will accept real penalties if they set them. |

### 4.2 Secondary persona: Maya, "The Distracted Professional"

| | |
|---|---|
| **Snapshot** | Late 20s to mid 30s, working full time. Gym or study goals squeezed around work. |
| **Context** | Doomscrolls in the evening and loses the time they'd planned for exercise or a side project. Has tried screen-time limits and ignores them. |
| **Goals** | Reclaim evenings; do a short, reliable daily routine. |
| **Frustrations** | Soft limits are easy to dismiss with one tap. Wants friction at the moment of temptation. |
| **Current workflow** | Built-in screen-time controls, calendar reminders. |
| **What motivates them** | Time back; relief from guilt. The game layer is a bonus, not the draw. |
| **What would make them quit** | Dramatic theming that feels silly at work; penalties that interfere with work apps. |
| **Success from their seat** | Phone use down, daily routine done, no work disruption. |
| **Hypothesis to test** | Maya values the digital penalty most and will use a low-key theme mode. *Design consequence: a "work-safe" selectable app list, and a reduced-drama option.* |

### 4.3 Tertiary persona: Sam, "The Fitness Grinder"

| | |
|---|---|
| **Snapshot** | Already trains. Wants discipline and tracking across training plus 1–2 other habits. |
| **Goals** | A daily system that keeps them honest and shows long-term growth. |
| **Frustrations** | Fitness apps track workouts but don't enforce anything outside them. |
| **Motivates** | Numbers, ranks, stat growth. |
| **Risk** | May over-set penalties (safety). *Design consequence: daily caps on physical penalties.* |

### 4.4 Anti-personas (we are not building for)
- **People in crisis or with a history of disordered exercise or self-punishment.** The penalty design must not reward harm; the app is not a therapeutic tool.
- **Minors under 13**; teens need a separate policy and safeguards.
- **People who want the app to decide their goals for them** (a coaching product like Fabulous serves them better).
- **Group and team accountability seekers** in v1; social arrives in v3.

### 4.5 Jobs to be done (job stories)

| # | Job story | Persona |
|---|---|---|
| J1 | When I keep abandoning routines after a week, I want something with real consequences, so I finally stick with it. | Kai |
| J2 | When I notice evenings disappearing into my phone, I want my distracting apps locked until I've done my tasks, so I can't just dismiss a reminder. | Maya |
| J3 | When I've done something hard, I want to see my progress as ranks and stats, so it feels earned. | Kai, Sam |
| J4 | When my life or capacity changes, I want to adjust my tasks and penalties, so the system fits me and I don't abandon it. | All |
| J5 | When I fail, I want the penalty to be hard but fair and escapable, so it motivates me rather than makes me quit. | All |

---

## 5. Core Concepts and Glossary (placeholder names, original IP)

| Term | Meaning |
|------|---------|
| **System** | The in-app voice and UI that issues quests and verdicts. Cold, formal, never cheerful. |
| **Hunter** *(placeholder; may rename)* | The user. |
| **Daily Quest** | The set of user-written tasks due that day. |
| **Task** | One item in the quest, with a name and a target (e.g. "Study — 45 minutes"). |
| **Penalty Zone** | The failure state: a timed lockdown the user must survive. |
| **Digital Penalty** | User-chosen apps are blocked for X minutes. |
| **Physical Penalty** | A set of exercises (e.g. 5 or 10 push-ups) the user must perform. |
| **Rank** | E → D → C → B → A → S progression based on level. |
| **Stats** | Allocatable attributes (e.g. Strength, Intellect, Discipline, Vitality). |

---

## 6. User Stories

### Onboarding
- As a new user, I want to tell the System what habits I want to build so that my quest reflects my life, not a generic template.
- As a new user, I want to set my own penalty level so that the punishment is severe enough to matter but not impossible.
- As a new user, I want to understand clearly, before I start, what happens if I fail so that I give informed consent to the penalty.

### Daily Quest
- As a user, I want to see today's quest the moment I open the app so that I know exactly what to do.
- As a user, I want to mark tasks complete so that I earn XP and progress toward the quest being cleared.
- As a user, I want a reminder before the deadline so that I do not fail by forgetting.

### Penalty Zone
- As a user who failed a quest, I want a clear, dramatic penalty experience so that failure feels consequential.
- As a user, I want my distracting apps to be blocked for my chosen duration so that I truly lose access.
- As a user, I want to complete a physical penalty to end the Penalty Zone early so that there is a path to redemption.
- As a user in a real emergency, I want a safe way to exit the lockdown so that the app never traps me from calls or safety apps.

### Progression
- As a user, I want to level up and allocate stat points so that my effort feels visible and mine.
- As a user, I want my rank to change over time so that I have long-term milestones.

### Customization
- As a user, I want to rewrite my tasks and penalties as my capacity changes so that the app stays realistic for me.
- As a user, I want edits to be fair and not exploitable so that the stakes remain real.

---

## 7. Requirements by Version

> Versions map to both **platform** and **feature depth**. Priorities within each version: P0 = must ship, P1 = should ship, P2 = designed-for, not built.

### 7.0 Core User Flow (v1, step by step)

1. **Install and open.** System-voice splash: "System detected. Candidate registration required."
2. **Write the quest.** User adds 1–5 tasks, each with a target. Nothing is pre-filled.
3. **Set the penalty.** User picks the apps to lock, the lock duration, and the physical penalty (exercise and reps).
4. **Consent.** A plain-language screen explains exactly what will happen on failure. The user must accept.
5. **Daily quest issued.** The home screen shows today's tasks, deadline and rank.
6. **Complete tasks** with hold-to-confirm. Progress bar fills.
7. **Branch A, all tasks done before the deadline:** quest Cleared, XP awarded, level-up if reached, stat points to allocate.
8. **Branch B, deadline passes with tasks incomplete:** quest Failed, Penalty Zone starts. Chosen apps lock; block screen shows the timer.
9. **In the Penalty Zone:** the user may complete the physical penalty to shorten or end the lockdown, or wait it out. Emergency exit is available but logged.
10. **Next day:** new quest is issued; any edits made in the meantime apply from here, subject to cooldown rules (R7).

---

### VERSION 1 — Android MVP: "Prove the loop"

**Goal:** A single user on Android can write a quest, complete it daily, level up, and face a real penalty if they fail.

#### P0 — Must have

**R1. Onboarding (user-written quest)**
- Short flow in System voice: welcome → "What habits will you build?" → user adds 1–5 tasks (name + target + optional unit) → sets penalty → consent screen.
- Acceptance:
  - [ ] User can create, name and set a target for 1–5 tasks.
  - [ ] No tasks are auto-suggested or pre-filled.
  - [ ] Onboarding can be completed in under 3 minutes.
  - [ ] User must explicitly accept the penalty consent screen to continue.

**R2. Daily Quest issue and deadline**
- A new quest is issued each day at a user-set time (default midnight) using the same user-written tasks. The deadline is a user-set cutoff (default 23:59 local).
- Acceptance:
  - [ ] The quest appears on app open with all tasks and their targets.
  - [ ] Tasks can be marked complete via a deliberate gesture (hold-to-confirm) to avoid accidental taps.
  - [ ] When all tasks are complete, the quest is marked **Cleared** and the System issues a verdict.
  - [ ] When the deadline passes with any task incomplete, the quest is marked **Failed**.
  - [ ] The deadline is evaluated correctly across timezone and device clock changes (no free resets by changing the clock).

**R3. Notifications**
- Quest-issued notification, a warning before the deadline (default 2 hours, configurable), and a failure notification.
- Acceptance:
  - [ ] Notifications fire reliably in the background on Android 10+, including after reboot.
  - [ ] User can configure warning time and disable non-critical notifications.
  - [ ] Notification copy follows System voice (no emojis, no cheerleading).

**R4. XP, levels, ranks, stats**
- Clearing a quest earns XP. XP levels the user up. Each level grants stat points the user allocates. Rank (E–S) is tied to level thresholds.
- Acceptance:
  - [ ] XP is awarded only on quest clear (partial completion earns reduced or zero XP, rule to be tuned).
  - [ ] Level-up triggers a distinct animation, sound and System notice.
  - [ ] User can allocate stat points; allocation is persisted.
  - [ ] Rank displayed on the main screen and updates at thresholds.

**R5. Penalty Zone — Digital Penalty**
- On a failed quest, user-chosen apps are blocked for X minutes (user-configured, with defined min/max).
- Acceptance:
  - [ ] User selects which apps to block during setup, from installed apps.
  - [ ] When a quest fails, blocked apps cannot be used for the configured duration; opening one shows a Penalty Zone block screen.
  - [ ] Phone, messages, emergency and system settings apps are **always** exempt and cannot be selected.
  - [ ] The block survives app kill and device reboot until the timer ends.
  - [ ] Required Android permissions are requested with a clear in-app explanation, and the app degrades gracefully if the user refuses (see Open Questions).

**R6. Penalty Zone — Physical Penalty**
- User selects a physical penalty (e.g. 5 or 10 push-ups, or another exercise they define) that can end or shorten the Digital Penalty.
- Acceptance:
  - [ ] User can pick or write the exercise and the repetition count.
  - [ ] Completion is confirmed by an honor-system gesture plus an in-app counter in v1.
  - [ ] Completing the physical penalty reduces the remaining digital lockdown by a defined amount, or ends it (configurable rule).

**R7. Self-adjustable tasks and penalties (anti-abuse rules)**
- Tasks and penalties are fully user-editable. To prevent users from lowering the penalty right after failing, edits follow fairness rules.
- Acceptance:
  - [ ] Edits take effect from the **next** quest cycle, not the current one.
  - [ ] Reducing a penalty or target has a cooldown (default 24 hours) before it applies.
  - [ ] Increasing difficulty applies immediately-next-cycle with no cooldown.
  - [ ] No edit can retroactively change a quest already issued or failed.

**R8. Safety guardrails**
- Acceptance:
  - [ ] Physical penalties have an enforced maximum per day, set conservatively; the app shows a "do only what is safe for your body" notice.
  - [ ] The System never assigns penalties on its own; only user-defined penalties exist.
  - [ ] Emergency exit exists in the Penalty Zone (a deliberate, hard-to-trigger bypass that ends the lockdown and logs the use).
  - [ ] Digital lockdown never blocks calls, emergency services, or the system dialer.

**R9. Local data and accounts**
- v1 stores data locally on the device. No account is required.
- Acceptance:
  - [ ] All quests, history, stats and settings persist locally across app restarts.
  - [ ] User can export or delete all data.

**R10. Theme implementation**
- Dark UI with System-blue accents and Penalty-red alerts, translucent System windows, System-voice copy, and distinct sound and haptics for quest, level-up and Penalty Zone.
- Acceptance:
  - [ ] A consistent design token set (colors, typography, window components) is used across all screens.
  - [ ] All user-facing copy passes the voice guide (formal, terse, no emojis or exclamation marks).
  - [ ] Penalty Zone visuals are clearly different from the standard UI.

#### P1 — Should have
- Quest history and calendar view of cleared and failed days.
- Streak counter and personal best.
- Home-screen widget showing today's quest status.
- Haptic and sound settings; reduced-motion option.
- Difficulty presets for penalty (Gentle / Standard / Brutal) as starting points users can edit.

#### P2 — Designed for, not built
- Cloud sync and accounts.
- Camera-based exercise verification.
- Gates (multi-day challenges), social and accountability features.

#### Out of scope for v1
Web, iOS, social, money pledges, AI-suggested tasks.

---

### VERSION 2 — Web and Depth: "Take it everywhere"

**Goal:** Users can use the app on the web, keep progress across devices, and get a richer progression and verification system.

#### P0
- **Flutter web build** with the same core loop (quest, XP, rank, stats, history).
- **Accounts and cloud sync** (email and Google sign-in) so Android and web share one profile.
- **Penalty Zone on web (limited):** web cannot block other apps. The web Penalty Zone consists of the physical penalty and a locked in-app experience, plus an optional sync that triggers the digital penalty on the user's Android device if they failed.
- **Responsive layouts** for desktop and mobile browsers.

#### P1
- **Gates:** optional multi-day challenges with bonus rewards.
- **Camera-based exercise verification** (on-device pose detection for push-ups and similar), optional.
- **Accountability contact:** opt-in notification to a chosen person when a quest fails.
- **Skills, titles and achievements** layer on top of stats.
- Richer analytics for the user (completion trends, weakest habits).

#### P2
- Social features (friends, guilds).
- Monetization groundwork.

---

### VERSION 3 — iOS and Ecosystem: "Complete the set"

**Goal:** Reach iOS users with feature parity where the platform allows, and open social and monetization paths.

#### P0
- **iOS app** from the shared Flutter codebase.
- **iOS digital penalty** using Apple's Screen Time / Family Controls APIs. This requires Apple's entitlement approval and has stricter limits than Android, so the iOS penalty may differ in behavior (see Open Questions).
- Cross-device sync across Android, web and iOS.
- iOS-native notifications and widgets.

#### P1
- Social layer: friends, accountability partners, optional leaderboards.
- Money-pledge mode (opt-in stakes), subject to store policy and legal review.
- Seasonal events and expanded rank tiers beyond S.

#### P2
- Wearable integration (step, workout and sleep data for auto-verification).
- Coach or community content.

---

## 8. Success Metrics

**Leading (first 1–4 weeks)**
| Metric | Target | Stretch |
|--------|--------|---------|
| Onboarding completion | 70% | 85% |
| First quest created within 3 min | 70% | 80% |
| Day 1 / Day 7 retention | 45% / 25% | 55% / 35% |
| Quest clear rate (daily, among active users) | 55% | 70% |
| Users who grant app-blocking permission | 60% | 75% |

**Lagging (1–3 months)**
| Metric | Target | Stretch |
|--------|--------|---------|
| Day 30 retention | 35% | 45% |
| Average active streak length | 10 days | 18 days |
| Penalty-driven uninstalls (uninstall within 24h of first penalty) | < 10% | < 5% |
| Play Store rating | 4.3 | 4.6 |

Measurement: privacy-respecting product analytics (tool TBD) plus in-app Day 7 and Day 30 surveys.

---

## 9. Key Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| **Google Play policy on app blocking.** Accessibility-service or overlay use for blocking is closely scrutinized. | Could block publishing or force redesign of the digital penalty. | Prefer UsageStats and overlay with a clear disclosed purpose; prepare a policy justification early; test with Play pre-launch review. |
| **Users cheat the penalty** (uninstall, force-stop, edit settings). | Weakens stakes. | Anti-abuse edit rules (R7); design the penalty as persistent and boot-surviving; accept that a determined user can always uninstall, as the app serves willing participants. |
| **Penalty too harsh, so users quit.** | Retention loss. | User-set penalty levels; presets; "Gentle" default for first week; track penalty-uninstalls. |
| **Physical-penalty safety.** | Injury, liability. | Caps, warnings, user-defined only, no System-assigned exercises. |
| **iOS limits on app blocking.** | Parity gap in v3. | Plan iOS penalty as a different design; seek entitlement early. |
| **IP similarity to Solo Leveling.** | Legal. | Original names, art, copy and audio. Legal review before launch. |

---

## 10. Open Questions

| # | Question | Owner | Blocking? |
|---|----------|-------|-----------|
| 1 | Which Android mechanism for blocking apps (UsageStats + overlay vs. Accessibility Service) is acceptable to Google Play for this use case? | Engineering / Legal | **Yes, before v1 build** |
| 2 | If the user refuses blocking permission, does the digital penalty degrade to a reminder-only mode, or is permission required to use the app? | Product | **Yes** |
| 3 | What are the min and max limits for digital penalty duration and physical penalty reps? | Product / Safety | Yes |
| 4 | Does partial completion earn XP, or is the quest all-or-nothing? | Product / Design | No |
| 5 | Is the emergency exit unlimited, or limited per week? | Product | No |
| 6 | What is the final product name and the user title (Hunter is a placeholder)? Needs a trademark check. | Product / Legal | No (before launch) |
| 7 | Monetization model (free, subscription, one-time)? | Stakeholder | No |
| 8 | Minimum Android version to support? Proposed: Android 10+. | Engineering | No |
| 9 | Should data be local-only in v1, or should we add accounts earlier? Proposed: local-only. | Engineering | No |

---

## 11. Timeline Considerations

- **No hard deadline given.** Proposed sequence: v1 (Android) → v2 (web) → v3 (iOS).
- **Gating dependency for v1:** resolve Open Question 1 (Play policy and blocking mechanism) before significant build, because it shapes the central feature.
- **Gating dependency for v3:** Apple Family Controls entitlement application should be filed during v2.
- **Suggested v1 milestones:** theme and design system, then quest and XP loop, then notifications, then Penalty Zone (digital then physical), then safety and anti-abuse, then beta.
- Shared Flutter code should keep platform-specific logic (app blocking, notifications) behind interfaces so web and iOS can swap implementations.

---

## 12. Changelog and Format Notes

**v0.2**
- Added one-page summary (Section 0), competitive landscape (1.1, with full companion doc), full personas, anti-personas and job stories (Section 4), and a step-by-step core flow (7.0).
- **Format basis:** web research on templates recommended by [Lenny Rachitsky](https://www.lennysnewsletter.com/p/my-favorite-templates-issue-37): SeatGeek's one-page-summary-first pattern, Square's non-goals and step-by-step flow, Asana's problem-statement framing and success-criteria-and-risks focus, Product Hunt's Who/Why/What opening. Persona structure follows common templates (role, goals, frustrations, workflow, jobs to be done) and the guidance to state who the product is **not** for. We could not retrieve the full section lists of Intercom's or Figma's templates, so those are not directly reflected.
- Sections 1–3 and 5–11 carried over from v0.1 (content unchanged except where noted above).

**v0.1**
- Initial draft with scope for v1, v2 and v3.

---

*End of PRD v0.2. Pending changes from stakeholder review.*
