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


LOAD = act("Open the app at / and wait up to 30 seconds for a black screen with the text 'TOUCH TO ESTABLISH CONTACT' (a Flutter web app; it can take a while to load, and controls are exposed in the accessibility tree)")

CONTACT = [
    act("Click 'TOUCH TO ESTABLISH CONTACT'"),
    act("Wait 6 seconds while the emblem forms and the '[ NOTIFICATION ]' window types its message"),
    act("Click 'ACCEPT' once (this test build accepts a click in place of the hold)"),
]


# The web build can't list installed apps, so this step shows no apps there.
CONFIRM_APPS = act("Click 'CONFIRM TARGETS' on the 'LOCK TARGETS' screen (the web build lists no apps; that is expected)")


def awakening(system="FITNESS", answers=None):
    """The Awakening up to the Daily Quest screen. [answers] are
    (question text, value) pairs typed into the placement test."""
    steps = [LOAD, *CONTACT,
        act(f"On the 'CHOOSE YOUR SYSTEM' screen, click the {system} card"),
        act(f"Click 'BIND {system}'"),
    ]
    for question, value in answers or []:
        # Type with the keyboard: Flutter web ignores a value set directly
        # on the input element (a programmatic fill).
        steps += [
            act(f"On the 'PLACEMENT TEST' screen, click the big number for '{question}'"),
            act("Press the Backspace key three times to empty it"),
            act(f"Type {value} with the keyboard (key presses, not a programmatic fill)"),
        ]
    steps += [
        act("Click 'SUBMIT'"),
        act("Wait 3 seconds for the rank badge and the '[ DAILY QUEST ]' cards to appear"),
        act("Click 'CONTINUE'"),
        CONFIRM_APPS,
        act("Click 'SET REST PERIOD' on the 'REST PERIOD' screen"),
        act("On the 'PENALTY TERMS' screen, scroll the list of terms down to the last term, 'The System does not negotiate.', until the text 'ALL TERMS READ' appears"),
        act("Click 'HOLD TO ACCEPT' once (this test build accepts a click in place of the hold)"),
        act("Click 'ENTER' on the '[ PLAYER REGISTERED ]' window"),
    ]
    return steps


ON_QUEST = check("The main '[ DAILY QUEST ]' screen is shown with a bottom bar containing 'QUEST', 'STATUS' and 'PENALTY'")


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
        awakening("PERSONALITY") + [
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
        awakening("PERSONALITY") + [
            act("In the 'Read (pages)' objective, click '+5' twice"),
            act("Click 'HOLD TO CONFIRM' once in the 'Write one journal line' objective"),
            act("Click 'HOLD TO CONFIRM' once in the 'Say hello to someone you rarely talk to' objective"),
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
    "14-system-explainer": (
        "Awakening: choosing a System explains its first quest and its own penalty",
        [
            LOAD,
            *CONTACT,
            act("On the 'CHOOSE YOUR SYSTEM' screen, click the PERSONALITY card"),
            check("The PERSONALITY card expands and shows 'RANK E STARTS WITH' followed by 'Read (pages) 10', and a 'FAIL A DAY' line that mentions '20 pages and a written reflection' and no push-ups; the button reads 'BIND PERSONALITY'"),
            act("Click the FOCUS card"),
            check("The FOCUS card is now expanded, its 'FAIL A DAY' line mentions 'a 60-minute phone-free block', and the button reads 'BIND FOCUS'"),
        ],
    ),
    "08-onboarding-validation": (
        "Awakening: binding is disabled until a System is chosen",
        [
            LOAD,
            *CONTACT,
            check("The 'CHOOSE YOUR SYSTEM' screen shows three cards, FITNESS, PERSONALITY and FOCUS"),
            check("The 'BIND SYSTEM' button at the bottom is disabled (dimmed and not clickable) because no card is selected; this is the expected behaviour, and no 'PLACEMENT TEST' screen is shown"),
            act("Click the FITNESS card"),
            check("The button now reads 'BIND FITNESS' and is enabled"),
        ],
    ),
    "09-custom-objective": (
        "Awakening: a strong placement test starts the Player at rank C, never higher",
        awakening(answers=[("Most push-ups you can do in one set", 80), ("Minutes to walk or jog 1 km", 4)]) + [
            check("The '[ DAILY QUEST ]' window lists 'Jog' showing '0.0 / 2.0 km' and 'Push-ups' showing '0 / 30' (the rank C quest), and the top bar shows 'RANK C'"),
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
        awakening("FOCUS") + [
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
