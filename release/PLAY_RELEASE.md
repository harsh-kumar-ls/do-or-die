# Do or Die: Google Play internal testing release

Version **0.9.0 (build 13)**. Track: **Internal testing** (up to 100 testers you invite by email; available minutes after upload, light review).

## 1. What to upload

| File | Use |
|---|---|
| `dist/DoOrDie-0.9.0.aab` | The App Bundle for Play Console. Signed with the upload key. |
| `design/brand/play_icon.png` | Store icon, 512 x 512. |
| `design/brand/feature_graphic.png` | Feature graphic, 1024 x 500. |
| `release/screenshots/*.png` | Phone screenshots, 1080 x 2400 (Quest, Status, Penalty Zone, System Check). |

`dist/DoOrDie-0.9.0-device.apk` is the same code signed with the development key, for the test phone only. Do not upload it.

## 2. The upload key (back it up today)

- Keystore: `~/.do-or-die/upload-keystore.jks` (outside the repository, which is public).
- Passwords and alias: `android/key.properties` (ignored by git).
- Back both up somewhere safe and private (a password manager plus an offline copy). Never commit them or share them.
- Use **Play App Signing** (the default for new apps): Google holds the app signing key; this file is only the upload key. If the upload key is lost, Play support can reset it, but that takes days.

Build commands:

```bash
flutter build appbundle --release
```

```bash
DOD_DEBUG_SIGN=1 flutter build apk --release
```

The first is for Play. The second signs with the development key so it can update the test phone's existing install.

## 3. Play Console steps (you do these; they are outward-facing)

1. Create the app: name **Do or Die**, default language English, App, Free.
2. **Testing → Internal testing → Create new release**, upload `DoOrDie-0.9.0.aab`, release notes from section 6.
3. **Testers**: create an email list, add testers, copy the opt-in link and send it to them.
4. Complete **App content** (section 5) and the **Store listing** (section 4). Internal testing can start before the listing is complete, but Play asks for most of App content first.
5. Testers open the opt-in link, accept, then install from the Play Store.

**Important for your own phone:** the Play build is signed by Google, the phone's current build by the development key. Android won't update one with the other. Installing from Play means uninstalling the current build first, and that **deletes the trial data on the phone**. Stay on the sideloaded build until the trial no longer matters, or accept the reset.

**Personal account rule:** before a public (production) release, a personal developer account must run a **closed test with at least 12 testers for 14 continuous days**. Internal testing does not count toward it. Start the closed test as soon as you have 12 people.

## 4. Store listing (draft)

**App name:** Do or Die

**Short description (80 max):**
A daily quest you cannot skip. Fail it, and the System locks your apps.

**Full description:**

> Do or Die turns self-discipline into a strict daily quest.
>
> Start with the Focus System: limits on the apps you choose, phone-free blocks, and a lock you set in advance. Add the Fitness or Personality pack if you want; you can switch at any time. A short placement test sets your starting rank, from E to C. Every day the System issues a quest for your rank.
>
> Clear it before midnight and you earn XP. Fail it and the Penalty Zone follows: the apps you chose lock for 4 hours the next day, at a time you picked, and Focus and Personality add a short penalty (a phone-free block, or reading and a reflection). Fitness never uses exercise as a punishment. Anything unpaid expires at midnight and is logged; nothing carries over.
>
> Clear 21 of 30 days and a Gate opens. Enter it for a three-day Dungeon that ends in a Rank Trial. Clear it to rank up. Fail it, and the Dungeon Penalty doubles the lock.
>
> Built to be fair:
> - Calls, messages, maps, settings, and banking and payment apps are never locked.
> - Locks never start during your rest period.
> - Each lock allows two 15-minute releases, and an emergency exit always ends it. Both are logged.
> - Judged wrongly? One verdict in any 14 days can be contested.
> - The first three days are a dry run: penalties are shown, not applied.
>
> Private by design: no account, no ads, no internet access. Everything stays on your phone.
>
> Do or Die is not a medical device and does not diagnose, treat, cure, or prevent any medical condition. Fitness quests are conservative progressions; the exercise penalty is never more than your own daily quest. Consult a healthcare professional before starting if you have a health condition or injury, and stop any exercise that causes pain. For adults 18 and over.

**Category:** Health & Fitness. **Tags:** habit tracker, discipline, productivity.
**Contact email:** your choice (Play shows it publicly).
**Privacy policy URL:** https://harsh-kumar-ls.github.io/do-or-die/privacy-policy.html

## 5. App content answers

**Data safety:**
- Does the app collect or share any required user data types? **No.**
- The app has no internet permission; all data stays on the device and is removed on uninstall. Android backup and device-to-device transfer are turned off (`android:allowBackup="false"` and `res/xml/data_extraction_rules.xml`), so nothing is copied to the user's Google account.
- Data encrypted in transit: not applicable (nothing is transmitted).

**Health apps declaration** (required for every app, testing tracks included): select **Activity and Fitness**; the app is not a medical device. The required statement is in the full description above.

**Ads:** No ads. **Target audience:** 18 and over (physical penalties and app locks are not designed for children). **Content rating questionnaire:** no violence, no user-generated content, no sharing of location, no purchases. **News app:** No. **Government app:** No. **Financial features:** None.

**Permission declarations:**

| Permission | Declaration |
|---|---|
| Foreground service, special use | Required form. Text: "The foreground service watches which app is open while a lock the user set up, a phone-free block the user started, or a pending daily verdict needs it, so the user's own lock can be enforced. It stops when none is pending; exact alarms wake it at midnight and just before a scheduled lock. The user can end any lock at once with the in-app emergency exit." Video: show the lock time in Settings, a failed day, the lock screen over a chosen app, and the emergency exit. |
| Usage access (`PACKAGE_USAGE_STATS`) | No form. The in-app prominent disclosure (what is read, why, that it stays on the phone, ACCEPT / NOT NOW) appears before Android's Usage access page, in the Awakening and in System Check. The privacy policy is also in the app (Status → Settings). |
| Display over other apps | No form. |
| Exact alarms (`SCHEDULE_EXACT_ALARM`) | User-granted on Android 14+. [Likely] no declaration for internal testing; if Play asks, the use is deadline warnings for the daily quest. |

`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` was removed in 0.9.0 (Play restricts it to a few app types). System Check now opens the battery list instead.

## 6. Release notes (internal testing)

> First test build. Choose a System, take the placement test, and clear your daily quest before midnight. The first three days are a dry run. Report anything that locks the wrong app, locks during your rest period, or judges a day wrongly.

## 7. Known review risks

- **App blocking:** Play allows digital-wellbeing apps that lock other apps when the user chooses and controls it. The disclosures above, the never-locked list and the release exist for this reason.
- **Foreground service special use:** the most likely place for a review question.
- **Name:** "Do or Die" is a common phrase; check the Play Store for an existing app with the same name before publishing.
- **Original IP:** all names, art, sound and copy are original. Keep any reference to other works out of the store listing.
