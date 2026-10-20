# Do or Die — Competitor Analysis

**Status:** v0.2 · **Date:** 2026-10-20 · **Method:** desktop web research (one pass) plus the user's Play Store screenshots (section B2)

> **Confidence warning.** Sources were mostly app-store listings, price aggregators and review blogs, several written by competing vendors. Prices conflict between sources and are marked *unverified*. Before this goes into any investor or launch material, check each product's official site and store page. Section 7 lists what to verify.

---

## 1. Market map

Do or Die sits where five product categories overlap. Nobody we found covers all of them.

| Category | What users get | Examples |
|----------|----------------|----------|
| **A. RPG habit trackers** | Habits turned into XP, HP, quests, parties | Habitica, Habit Hero |
| **B. "System"-themed life-XP apps** (direct competitors) | Solo Leveling-style quests, XP, ranks, sometimes a penalty | Level Up: SoloLeveling Life XP, Quest Leveling, Solo Hunter: Level Up, HabitForge |
| **C. Streak / habit trackers** | Clean tracking, streak preservation | Streaks, plus many others |
| **D. Commitment / stakes apps** | Real consequences, usually money | Beeminder, stickK |
| **E. Focus and app-blocking** | Real phone friction, no habit layer | Opal, one sec, Forest, Dull |
| **F. Wellness coaching** | Guided routines, science-led framing | Fabulous |

**Our position:** category B's theme, plus category E's real device friction, plus category D's seriousness about stakes, with fully user-defined tasks (unlike F's guided approach).

---

## 2. Competitor profiles

### A. RPG habit trackers

**Habitica** (iOS, Android, web)
- Habits, dailies and to-dos become an RPG with HP, XP, parties and bosses.
- Free core product; optional paid tier. Price figures conflict across sources ($4.99/month in one, ~$6.42/month in another), so *unverified*.
- Strengths: mature, generous free tier, strong social and party layer, cross-platform.
- Weaknesses (directional, from a review blog): gamification fatigue, group-feature reliability problems. Cartoon pixel-art tone is the opposite of a dark, serious System.
- **Penalty:** HP loss inside the game only. Nothing happens on the user's phone or body.

**Habit Hero** (Product Hunt listing)
- Create a hero and level it by completing real habits; positions itself on consistency over streaks.
- **Correction (Play Store check):** a Play Store app called "Habit Hero: Kids Routine App" (Bytesurge Labs) is a kids' chores and reward-chart app, not an adult RPG tracker. These may be different products sharing a name. Treat as not a competitor.

### B. "System"-themed life-XP apps (closest competitors)

**Level Up: SoloLeveling Life XP** (Android)
- Daily recurring quests, one-time goals, XP, streaks. Data stays on-device, no account.
- Seen only via a third-party download page (FileHippo), so details are thin. It does not appear to offer real-world penalties.

**Solo Hunter: Level Up** (iOS)
- Listing describes a **penalty system when you miss a quest**, RPG progression and a global leaderboard. Free with in-app purchases.
- **Update (hands-on, Play Store):** the user checked and found **no penalty option** in Solo Hunter. The App Store listing's penalty claim does not carry over to the Android app. Our penalty gap is confirmed for this app. Play listing: 3.7 stars, 10K+ downloads, 77 MB, in-app purchases, uses a manga-style character and "System" UI.

**Quest Leveling** (iOS)
- Free, no login, data on device. A privacy plus; no cloud backup means progress is lost on reinstall.

**HabitForge** (web, creator-built)
- Explicitly inspired by the System's daily quests and XP. Its creator says they wanted to avoid "over-gamified" complexity.

**Notion / ClickUp "Solo Leveling system" templates**
- Widely shared life-RPG templates. One reviewer reported points not showing for some stats. Often treat the penalty as a joke. These show strong **demand for the aesthetic**, with a weak execution bar.

### B2. Hands-on update: Google Play screenshots (2026-10-20)

Source: the user's own Play Store screenshots. Ratings and download counts are as shown on the listing that day.

| App | Developer | Rating | Downloads | Pricing | What the listing shows |
|---|---|---|---|---|---|
| **Level Up: Solo Leveling System** | Rwired | 4.6 | 10K+ | In-app purchases. User reports **590 lifetime or 220/month** (currency presumably INR; confirm) | Daily quests, streaks, bonus XP for quest groups, "Dungeons" (challenges like 30 days of no-porn, break bad habits), rankings and leaderboard. Clean blue theme, not dark and menacing. |
| **SelfQuest** | SelfQuest | 3.2 | **500K+** | In-app purchases | Pixel-art hunter, "Level up in real life", E-to-S hunter rank, workouts as battles ("every rep = damage"), **camera pose tracking that counts reps**, PvP and rankings. Fitness-first. |
| **Solo Hunter: Level Up** | Alok Haldiya | 3.7 | 10K+ | User reports **650** (one-time, currency presumably INR; confirm) | Manga-style System UI, stats (STR/INT/AGI/VIT/SEN), daily quests due by midnight. **No penalty option** (user-verified). |
| **Unnamed "AI quest path" app** | not captured | 4.1 | 1K+ | not captured | "Tell the AI your goal. It builds your RPG quest path." Photo-real System-window marketing. AI generates tasks, the opposite of our user-written approach. Name not captured; identify before citing. |
| **Habit Hero: Kids Routine** | Bytesurge Labs | 4.5 | 5K+ | not captured | Kids' chores. Not a competitor. |
| **Unnamed stakes app (reviews only)** | not captured | 3.5 (366 ratings) | not captured | not captured | Money-stakes style: users "submit a report" and get debited on failure. |

**What this adds**
1. **SelfQuest is the strongest competitor so far**, with 500K+ downloads and camera-based rep counting. We had listed camera verification as v2 and as a differentiator-in-waiting; SelfQuest already ships it. Its 3.2 rating means execution is weak, so there is room, but "camera verification" is no longer unique.
2. **Nobody here has a real penalty.** User-verified for Solo Hunter; none of the other listings advertises one. The digital-plus-physical penalty gap still stands (unconfirmed for SelfQuest and Level Up beyond what the listings show).
3. **Pricing anchors.** Level Up at 590 lifetime or 220/month, Solo Hunter at 650: users in this niche are being asked to pay, and lifetime pricing exists. (Unconfirmed currency, so don't convert yet.)
4. **AI-generated tasks exist** in at least one app; our user-written approach is a deliberate contrast, not an oversight.
5. **Reliability is the failure mode of stakes apps.** The 3.5-star reviews (visible in the screenshot) complain of being **marked unsuccessful after submitting on time**, a wrong timestamp, a Submit button that doesn't always work, and being **debited before they could report**. The developer reverses charges when asked, but users resent the repeated emails. **Lesson for us:** wrongful penalties destroy trust faster than weak penalties. We need trustworthy deadline and time handling, an undo/grace window, and a clear way to dispute a false failure.

### C. Streak trackers

**Streaks** (Apple only)
- Paid, one-time (~$4.99–$5.99, sources conflict, *unverified*). Capped at 24 habits. Focused on clean streak preservation.
- Strength: polished and simple. Weakness: no consequence for missing a day beyond a broken chain; Apple-only.

### D. Commitment / stakes apps

**Beeminder**
- Graph a measurable goal; derail and you pay. Integrates with dozens of data sources (Fitbit, RescueTime, etc.). Historical pledge ladder ($5, $10, $30, $90 and up) is from an old post; current pricing *unverified*.
- Strength: real stakes with real automation. Weakness: spreadsheet-like, no game feel, money-only.

**stickK**
- Commitment contracts founded by Yale economists, with optional money stakes and a referee who verifies reports. Current status and pricing *unconfirmed*.

### E. Focus and app-blocking

**Opal**
- Blocks apps on a schedule. Reported price conflicts: ~$99.99/year (complaints on its own forum) vs. $59.99/year or $6.99/month in an aggregator. *Unverified.* Controls access only; no habit layer.

**one sec**
- Adds a breathing pause before an app opens. Reported free for one app, ~$14.99/year for all (competitor-blog figure). A cited study found reduced app opens; *claim from an interested source, unverified*.

**Forest**
- Plant a tree during focus; leaving the app kills it. iOS one-time ~$3.99, Android reportedly free (sources conflict).

**Dull, UNDOOMED and others**
- Cheaper blockers (~$15–$18/year per a competitor blog).

### F. Wellness coaching

**Fabulous**
- Science-framed guided routines; reported $40–$100/year (secondhand). Opposite philosophy: the app tells you what to do. We let the user decide.

---

## 3. Feature comparison

✅ = yes · ◐ = partial or unconfirmed · ❌ = no

| Capability | Habitica | System-themed apps (B) | Streaks | Beeminder / stickK | Opal / one sec | **Do or Die** |
|---|---|---|---|---|---|---|
| User-written tasks | ✅ | ✅ | ✅ | ✅ | n/a | ✅ |
| Cold, dark "System" tone | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ (core identity) |
| XP, levels, ranks, stats | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| Penalty on failure | ◐ in-game | ◐ in-game | ❌ | ✅ money | ❌ | ✅ digital + physical |
| Real phone friction (app blocking) | ❌ | ❌ (unconfirmed) | ❌ | ❌ | ✅ | ✅ |
| Physical penalty task | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| User-adjustable difficulty | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ with fairness rules |
| Social / parties | ✅ | ◐ leaderboards | ❌ | ◐ | ❌ | v3 |
| Works offline, no account | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ v1 |
| Android | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ v1 |
| Web | ✅ | ◐ | ❌ | ✅ | ❌ | v2 |

---

## 4. Key findings

1. **The aesthetic has proven demand and weak execution.** Many Solo Leveling templates, a web tool and several apps exist, but we found nothing premium. There is room for a well-designed, serious version.
2. **Penalty is the real gap.** Penalties in this category appear to be in-game only. Combining a **digital lockdown with a physical task** is, on this evidence, unoccupied. This is our strongest differentiator.
3. **Willingness to pay for friction is real.** Opal is reportedly priced at $60–$100/year and Beeminder is built on pledges. Users pay when consequences are real, which supports a future paid tier.
4. **Penalty-based products are polarizing.** Opal's pricing complaints and one sec's gentle "pause" approach show a tension: strong friction works but annoys. Our user-adjustable penalties with fairness rules are the answer, and we should test them.
5. **Cheating and data loss are known failure modes.** Users log habits they didn't do, and streaks vanish after reinstall or sync errors. We need cooldowns on penalty edits (already in the PRD) and, in v2, cloud backup.
6. **"On-device, no account" is a selling point** for B-category apps, but it costs users their progress on reinstall. Our v1 local-only approach is acceptable; the loss risk should be disclosed and v2 sync prioritized.
7. **Gamification fatigue is real (Habitica).** Keep our system lean: a few stats, clear ranks, no sprawling economy.

---

## 5. Where we win and where we're exposed

**Differentiators to protect**
- A consistent, serious System identity (voice, sound, UI).
- Real consequences that work across devices where the platform allows.
- User ownership of tasks and penalties.

**Exposures**
- **Habitica** and others can add penalties. Our theme and execution have to stay ahead.
- **Opal** owns "serious phone blocking" and has funding. We can't win on blocking depth, only on integration with habits and theme.
- **IP risk:** category B's use of Solo Leveling branding is legally exposed. Staying original (our decision) is both safer and a differentiator.
- **Platform risk:** Play and App Store rules on blocking affect us and Opal alike.

---

## 6. Implications for the PRD

- Lead positioning: **"The habit app where failing costs you something real."**
- Keep penalty customization (it addresses the Opal-style backlash) and keep the anti-abuse cooldowns.
- Plan cloud sync early (v2) and make local data export a v1 feature.
- Do not compete on social in v1; Habitica's lead there is large.
- Treat a paid tier as plausible (Opal and Beeminder evidence), but don't commit pricing yet.

---

## 7. To verify before relying on this document

- [x] ~~Play listings for Level Up, Solo Hunter, SelfQuest~~ (done via user screenshots, see B2). Still to do: capture the unnamed AI app and the unnamed stakes app names; install SelfQuest and Level Up to test whether either has any penalty.
- [x] ~~Whether Solo Hunter's penalty has any consequence~~: none (user-verified).
- [ ] Read SelfQuest's 1-star reviews (3.2 average) for what users hate.
- [ ] Current official pricing for Habitica, Streaks, Beeminder, stickK, Opal, one sec, Forest, Fabulous.
- [ ] stickK's current operating status.
- [ ] Recent 1–3 star reviews for the closest competitors, to find real user complaints.
- [ ] Any Solo Leveling-themed apps that launched in the last six months.

---

## Sources

- [Habitica vs Streaks vs Fabulous (Postmake)](https://postmake.io/compare/the-fabulous-vs-streaks-vs-habitica)
- [Streaks vs Habitica (Toolradar)](https://toolradar.com/compare/streaks-vs-habitica)
- [Habitica Pricing (Toolradar)](https://toolradar.com/tools/habitica/pricing)
- [Habit trackers ranked 2026 (Unstar)](https://unstar.app/blog/streaks-habitica-way-of-life-strides-habit-tracking-apps-ranked-2026)
- [Habitica alternatives (Habi)](https://habi.app/insights/habitica-alternatives/): vendor-authored
- [Habitica Review (CRM.org)](https://crm.org/news/habitica-review)
- [Level Up: SoloLeveling Life XP (FileHippo)](https://filehippo.com/android/download_level-up-sololeveling-life-xp/)
- [HabitForge](https://hunted.space/product/habitforge-3)
- [Habit Hero (Product Hunt)](https://www.producthunt.com/p/self-promotion/habit-hero-an-rpg-style-habit-tracker-built-for-consistency-not-streaks)
- [Quest Leveling (App Store)](https://apps.apple.com/py/app/quest-leveling/id6744368718?l=en-GB)
- [Solo Hunter: Level Up (App Store)](https://apps.apple.com/us/app/-/id6758021041)
- [Life Leveling: The System (Notion)](https://www.notion.com/templates/life-leveling-the-system)
- [Beeminder: money](https://beeminder.com/money) · [Beeminder: about](https://beeminder.com/about)
- [stickK (App Store)](https://apps.apple.com/app/id776128765)
- [Opal alternative (Dull)](https://www.getdull.app/opal-alternative/): competitor-authored
- [Opal pricing (AisoTools)](https://aisotools.com/pricing/opal-screen-time)
- [Opal community: pricing](https://community.opal.so/t/unfortunate-pricing/3246)
- [Forest pricing (Toolradar)](https://toolradar.com/tools/forest/pricing)
