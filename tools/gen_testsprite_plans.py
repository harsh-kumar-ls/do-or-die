#!/usr/bin/env python3
"""Writes the TestSprite frontend plans into testsprite-plans/.

Every TestSprite run starts in a fresh browser, so each plan first registers
through onboarding. The web build under test must be compiled with
--dart-define=DOD_TEST_MODE=true (hold buttons accept a click there).

    python3 tools/gen_testsprite_plans.py
"""

import json
import os

PROJECT_ID = "d37f7ffc-2ffc-4da9-88ea-8ee0106eba69"
OUT = os.path.join(os.path.dirname(__file__), "..", "testsprite-plans")


def act(text):
    return {"type": "action", "description": text}


def check(text):
    return {"type": "assertion", "description": text}


LOAD = act("Open the app at / and wait up to 30 seconds for the '[ SYSTEM ]' window to appear (a Flutter web app; it can take a while to load, and controls are exposed in the accessibility tree)")


# The web build can't list installed apps, so this step shows no apps there.
CONFIRM_APPS = act("Click 'CONFIRM APPS' on the '[ LOCK TARGETS ]' window (the web build lists no apps; that is expected)")


def onboarding(study_minutes=None):
    steps = [LOAD, act("Click 'BEGIN REGISTRATION'")]
    if study_minutes is not None:
        steps.append(act(
            f"In the second objective row (named 'Study'), clear the 'Target minutes' text box and type {study_minutes}"
        ))
    steps += [
        act("Click 'CONFIRM OBJECTIVES'"),
        CONFIRM_APPS,
        act("Click 'CONFIRM' on the '[ REST PERIOD ]' window"),
        act("Click 'HOLD TO ACCEPT' once (this test build accepts a click in place of the hold)"),
        check("The '[ DAILY QUEST ]' screen is shown with a bottom bar containing 'QUEST', 'STATUS' and 'PENALTY'"),
    ]
    return steps


PLANS = {
    "02-read-counter": (
        "Quest: the Read counter adds pages with +5 and +10",
        onboarding() + [
            check("The 'Read' objective shows '0 / 30'"),
            act("In the 'Read' objective, click '+5'"),
            act("In the 'Read' objective, click '+10'"),
            check("The 'Read' objective now shows '15 / 30'"),
        ],
    ),
    "03-breakfast-confirm": (
        "Quest: breakfast is confirmed with the hold button",
        onboarding() + [
            check("The 'Have breakfast' objective shows '0 / 1' and a 'HOLD TO CONFIRM' button"),
            act("Click 'HOLD TO CONFIRM' once (test build: a click confirms)"),
            check("The button now reads 'CONFIRMED' and 'Have breakfast' shows '1 / 1'"),
        ],
    ),
    "04-study-timer-live": (
        "Quest: the study timer clock runs live and pauses",
        onboarding() + [
            check("The 'Study' objective shows a clock reading '00:00:00', the label 'NOT STARTED' and a 'START' button"),
            act("Click 'START' in the 'Study' objective"),
            act("Wait 6 seconds without clicking anything"),
            check("The Study clock shows at least '00:00:04' (it advanced on its own) and the label 'RUNNING' is visible"),
            act("Click 'PAUSE'"),
            check("The label under the Study clock reads 'PAUSED' and the button reads 'RESUME'"),
        ],
    ),
    "05-quest-complete-notice": (
        "Quest: completing every objective shows the System notice",
        onboarding(study_minutes=1) + [
            act("Click 'HOLD TO CONFIRM' once for 'Have breakfast'"),
            act("In the 'Read' objective, click '+10' three times"),
            act("Click 'START' in the 'Study' objective, then wait 70 seconds without clicking"),
            check("A '[ NOTIFICATION ]' window appears containing the text 'The daily quest has been completed.' and 'Reward: +100 XP'"),
            act("Click 'ACKNOWLEDGE'"),
            check("The notification closes and the quest screen shows 'All objectives complete.'"),
        ],
    ),
    "06-status-tab": (
        "Status: the status screen shows rank, level and attributes",
        onboarding() + [
            act("Click 'STATUS' in the bottom bar"),
            check("A '[ STATUS ]' window shows the rank letter 'E', the label 'RANK', and rows 'LEVEL' with value '1' and 'QUESTS CLEARED' with value '0'"),
            check("An 'ATTRIBUTES' window shows four attributes labelled 'STR', 'INT', 'DIS' and 'VIT', and 'AVAILABLE POINTS' with value '0'"),
        ],
    ),
    "07-penalty-tab": (
        "Penalty: with no failed day, the Penalty Zone shows no penalty and no chosen apps",
        onboarding() + [
            act("Click 'PENALTY' in the bottom bar"),
            check("A '[ PENALTY ZONE ]' window shows 'No penalty is in effect.', a clock '00:00:00' and 'NO LOCK TODAY'"),
            check("The text 'No apps chosen. A failed day locks nothing until you choose some.' and an 'EDIT LOCKED APPS' button are shown"),
            check("No 'PUSH-UPS OWED' window and no 'RELEASE 15 MIN' button are shown"),
        ],
    ),
    "08-onboarding-validation": (
        "Onboarding: an objective without a name is refused",
        [
            LOAD,
            act("Click 'BEGIN REGISTRATION'"),
            act("Click '+ ADD OBJECTIVE'"),
            act("Click 'CONFIRM OBJECTIVES' without typing a name in the new, empty objective"),
            check("The error text 'Every task needs a name.' is shown and the '[ DAILY QUEST ]' setup window is still displayed (no '[ REST PERIOD ]' window)"),
        ],
    ),
    "09-custom-objective": (
        "Onboarding: a user-written objective appears on the Daily Quest",
        [
            LOAD,
            act("Click 'BEGIN REGISTRATION'"),
            act("Click '+ ADD OBJECTIVE'"),
            act("In the new empty 'Objective name' text box (the fourth one), type 'Meditate'"),
            act("Click 'CONFIRM OBJECTIVES'"),
            CONFIRM_APPS,
            act("Click 'CONFIRM' on the '[ REST PERIOD ]' window"),
            act("Click 'HOLD TO ACCEPT' once (this test build accepts a click in place of the hold)"),
            check("The '[ DAILY QUEST ]' screen lists four objectives including 'Meditate' with '0 / 1' and its own 'HOLD TO CONFIRM' button"),
        ],
    ),
    "10-mute-toggle": (
        "Shell: the sound toggle switches between mute and unmute",
        onboarding() + [
            check("A button named 'Mute sound' is visible next to the date at the top"),
            act("Click the 'Mute sound' button"),
            check("The same button is now named 'Turn sound on'"),
        ],
    ),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for slug, (name, steps) in PLANS.items():
        path = os.path.join(OUT, f"{slug}.json")
        with open(path, "w") as f:
            json.dump({"projectId": PROJECT_ID, "type": "frontend", "name": name, "planSteps": steps}, f, indent=2)
            f.write("\n")
        print(path)


if __name__ == "__main__":
    main()
