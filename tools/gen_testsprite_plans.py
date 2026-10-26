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


def awakening(system="FITNESS SYSTEM", answers=None):
    """The Awakening up to the Daily Quest screen. [answers] are
    (question text, value) pairs typed into the placement test."""
    steps = [
        LOAD,
        act("Click 'ACCEPT' on the '[ SYSTEM ]' window"),
        act(f"On the '[ CHOOSE YOUR SYSTEM ]' window, click the card titled '{system}'"),
        act("Click 'CONFIRM SYSTEM'"),
    ]
    for question, value in answers or []:
        steps.append(act(f"On the '[ PLACEMENT TEST ]' window, clear the number box for '{question}' and type {value}"))
    steps += [
        act("Click 'SUBMIT' on the '[ PLACEMENT TEST ]' window"),
        act("Click 'CONTINUE' on the '[ RANK ASSIGNED ]' window"),
        CONFIRM_APPS,
        act("Click 'CONFIRM' on the '[ REST PERIOD ]' window"),
        act("Click 'HOLD TO ACCEPT' once on the '[ PENALTY TERMS ]' window (this test build accepts a click in place of the hold)"),
    ]
    return steps


ON_QUEST = check("The '[ DAILY QUEST ]' screen is shown with a bottom bar containing 'QUEST', 'STATUS' and 'PENALTY'")


PLANS = {
    "01-onboarding-to-quest": (
        "Awakening: a new Player chooses the Fitness System and receives its rank E daily quest",
        awakening() + [
            ON_QUEST,
            check("The '[ DAILY QUEST ]' window lists the objectives 'Walk', 'Push-ups (knees allowed)' showing '0 / 10', and 'Squats' showing '0 / 15'"),
        ],
    ),
    "02-read-counter": (
        "Quest: the push-up counter adds reps with +5 and +1",
        awakening() + [
            act("In the 'Push-ups (knees allowed)' objective, click '+5'"),
            act("In the 'Push-ups (knees allowed)' objective, click '+1'"),
            check("The 'Push-ups (knees allowed)' objective now shows '6 / 10' while 'Squats' still shows '0 / 15'"),
        ],
    ),
    "03-breakfast-confirm": (
        "Quest: a checkbox objective is confirmed with the hold button",
        awakening("PERSONALITY SYSTEM") + [
            check("The 'Write one journal line' objective shows '0 / 1' and a 'HOLD TO CONFIRM' button"),
            act("Click 'HOLD TO CONFIRM' once in the 'Write one journal line' objective (test build: a click confirms)"),
            check("That button now reads 'CONFIRMED' and 'Write one journal line' shows '1 / 1'"),
        ],
    ),
    "04-study-timer-live": (
        "Quest: the walk timer clock runs live and pauses",
        awakening() + [
            check("The 'Walk' objective shows a clock reading '00:00:00' and a 'START' button"),
            act("Click 'START' in the 'Walk' objective"),
            act("Wait 6 seconds without clicking anything"),
            check("The Walk clock shows at least '00:00:04' (it advanced on its own) and the label 'RUNNING' is visible"),
            act("Click 'PAUSE'"),
            check("The label under the Walk clock reads 'PAUSED' and the button reads 'RESUME'"),
        ],
    ),
    "05-quest-complete-notice": (
        "Quest: completing every objective shows the System notice",
        awakening("PERSONALITY SYSTEM") + [
            act("In the 'Read (pages)' objective, click '+5' twice"),
            act("Click 'HOLD TO CONFIRM' once in the 'Write one journal line' objective"),
            check("A '[ NOTIFICATION ]' window appears containing 'The daily quest has been completed.' and 'Reward: +100 XP'"),
            act("Click 'ACKNOWLEDGE'"),
            check("The notification closes and the quest screen shows 'All objectives complete.'"),
        ],
    ),
    "06-status-tab": (
        "Status: the System rank, Gate progress and five attributes are shown",
        awakening() + [
            act("Click 'STATUS' in the bottom bar"),
            check("The '[ STATUS ]' window shows the rank letter 'E', the label 'FITNESS SYSTEM · RANK', 'LEVEL' with value '1', and 'NEXT GATE' with value '0 / 21 CLEARED'"),
            check("An 'ATTRIBUTES' window shows five attributes labelled 'STR', 'VIT', 'INT', 'CHA' and 'DIS', and 'POINTS' with value '0'"),
        ],
    ),
    "07-penalty-tab": (
        "Penalty: with no failed day, the Penalty Zone shows no penalty and no chosen apps",
        awakening() + [
            act("Click 'PENALTY' in the bottom bar"),
            check("A '[ PENALTY ZONE ]' window shows 'No penalty is in effect.', a clock '00:00:00' and 'NO LOCK TODAY'"),
            check("No 'PUSH-UPS OWED' window and no 'RELEASE 15 MIN' button are shown"),
        ],
    ),
    "08-onboarding-validation": (
        "Awakening: continuing without choosing a System is refused",
        [
            LOAD,
            act("Click 'ACCEPT' on the '[ SYSTEM ]' window"),
            act("Click 'CONFIRM SYSTEM' without clicking any System card"),
            check("The error text 'Choose a System.' is shown and the '[ CHOOSE YOUR SYSTEM ]' window is still displayed (no '[ PLACEMENT TEST ]' window)"),
        ],
    ),
    "09-custom-objective": (
        "Awakening: a strong placement test starts the Player at rank C, never higher",
        awakening(answers=[("Most push-ups you can do in one set", 80), ("Minutes to walk or jog 1 km", 4)])[:-4] + [
            check("The '[ RANK ASSIGNED ]' window shows 'FITNESS SYSTEM · RANK C' and the line 'Ranks above C are earned only through Dungeons.'"),
        ] + awakening()[-4:] + [
            check("The '[ DAILY QUEST ]' window lists 'Jog' showing '0.0 / 2.0 km' and 'Push-ups' showing '0 / 30'"),
        ],
    ),
    "10-mute-toggle": (
        "Shell: the sound toggle switches between mute and unmute",
        awakening() + [
            check("A button named 'Mute sound' is visible next to the date at the top"),
            act("Click the 'Mute sound' button"),
            check("The same button is now named 'Turn sound on'"),
        ],
    ),
    "11-phone-free-block": (
        "Quest: a Focus phone-free block starts and ends from its objective",
        awakening("FOCUS SYSTEM") + [
            check("The '[ DAILY QUEST ]' window lists 'No phone after waking (minutes)' with a 'START BLOCK' button"),
            act("Click 'START BLOCK'"),
            check("The button now reads 'END BLOCK' and the text 'Chosen apps are locked until the block ends.' is shown under it"),
            act("Click 'END BLOCK'"),
            check("The button reads 'START BLOCK' again"),
        ],
    ),
    "12-reduction-valve": (
        "Status: lowering the quest by 20% applies from tomorrow at half XP",
        awakening() + [
            act("Click 'STATUS' in the bottom bar"),
            check("The 'QUEST REDUCTION' row on the '[ STATUS ]' window shows 'Full quest'"),
            act("In the 'QUEST REDUCTION' row, click '20%'"),
            check("The 'QUEST REDUCTION' row now shows 'Tomorrow 20% · half XP'"),
            act("Click 'QUEST' in the bottom bar"),
            check("The 'Push-ups (knees allowed)' objective still shows '0 / 10' today (the reduction is not applied until tomorrow)"),
        ],
    ),
    "13-report": (
        "Status: the report opens and shows the honesty section",
        awakening() + [
            act("Click 'STATUS' in the bottom bar"),
            act("Click 'REPORT' on the '[ STATUS ]' window"),
            check("A '[ REPORT ]' window is shown with 'No day has been judged yet.'"),
            act("Scroll down the report page"),
            check("Windows titled 'HONESTY' (with a 'RELEASES TAKEN' row) and '[ VERDICT ]' (with 'Insufficient data. Continue.') are shown"),
            act("Click 'CLOSE'"),
            check("The '[ STATUS ]' window is shown again"),
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
