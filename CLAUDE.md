# Do or Die — project instructions

Personal 30-day-trial habit app (Flutter, Android first). Original "System"-style theme inspired by Solo Leveling's vibe; never use its characters, names or assets.

**Read first:** PROJECT.md (what to build, rules), BUILD_LOOP.md (how to build and test), PRD.md (later launch scope), COMPETITOR_ANALYSIS.md (research).

**Working rules**
- Follow the build loop in BUILD_LOOP.md: tests first, gates in order, one milestone at a time, stop after 3 failed attempts on the same failure.
- PROJECT.md overrides PRD.md where they differ.
- Penalty rules live in `lib/domain/` as pure Dart plus one config file. No penalty logic in UI code.
- Never enable a lock before its tested escape (emergency exit, protected apps) exists.
- A wrongful penalty bug is the highest-severity defect.
- TestSprite tests web builds and APIs only. Native Android behaviour (blocking, notifications, reboot) is verified by integration tests and the manual device checklist; say so rather than claiming TestSprite covered it.
- Ask before large installs or anything outward-facing.
- System-voice copy: terse, formal, no emojis, no exclamation marks.
