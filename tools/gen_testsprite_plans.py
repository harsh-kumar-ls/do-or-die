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


def show(system):
    """Brings a System's card to the front of the carousel."""
    if system == "FITNESS":
        return []
    return [act(f"On the 'CHOOSE YOUR SYSTEM' screen, click the small diamond button named 'Show the {system.title()} System' under the card, then wait 1 second")]


def awakening(system="FITNESS", answers=None):
    """The Awakening up to the Daily Quest screen. [answers] are
    (question text, value) pairs typed into the placement test."""
    steps = [LOAD, *CONTACT,
        *show(system),
        act(f"Click 'CHOOSE {system} SYSTEM'"),
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
        act("Wait 5 seconds for the rank badge and the '[ DAILY QUEST ]' cards to appear"),
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
            check("The 'Write one journal line' objective shows '0 / 1' and a small square button named 'Hold to confirm Write one journal line'"),
            act("Click the 'Hold to confirm Write one journal line' button once (test build: a click confirms)"),
            check("'Write one journal line' now shows '1 / 1' and its square button is gone"),
        ],
    ),
    "04-study-timer-live": (
        "Quest: the walk timer clock runs live and pauses",
        awakening() + [
            check("The 'Walk' objective shows a round clock reading '12:00' above 'REMAINING' and a 'START' button"),
            act("Click 'START' in the 'Walk' objective"),
            act("Wait 6 seconds without clicking anything"),
            check("The Walk clock now reads '11:56' or less (it counts down on its own), the button reads 'PAUSE' and the label 'RUNNING' is visible"),
            act("Click 'PAUSE'"),
            check("The button reads 'RESUME' and the text 'Pausing keeps your progress.' is shown under it"),
        ],
    ),
    "05-quest-complete-notice": (
        "Quest: completing every objective shows the System notice",
        awakening("PERSONALITY") + [
            act("In the 'Read (pages)' objective, click '+5' twice"),
            act("Click the 'Hold to confirm Write one journal line' button once"),
            act("Click the 'Hold to confirm Say hello to someone you rarely talk to' button once"),
            check("A '[ QUEST CLEARED ]' notice appears with the row 'Objectives' '3 / 3' and the note 'The reward is granted at 00:00.'"),
            act("Wait 2 seconds, then click 'ACKNOWLEDGE'"),
            check("The notification closes and the quest screen shows 'All objectives complete.'"),
        ],
    ),
    "06-status-tab": (
        "Status: the System rank, Gate progress and five attributes are shown",
        awakening() + [
            act("Click 'STATUS' in the bottom bar"),
            check("The '[ STATUS ]' screen shows the rank letter 'E' with 'RANK E · PLAYER' and 'FITNESS SYSTEM', 'LEVEL' with value '1', and a ring reading '0 / 21' and 'CLEARED' with 'NEXT GATE · 0 / 21' under it"),
            check("An 'ATTRIBUTES' panel shows five columns labelled 'STR', 'VIT', 'INT', 'CHA' and 'DIS', and the text 'NO POINTS'"),
        ],
    ),
    "07-penalty-tab": (
        "Penalty: with no failed day, the Penalty Zone shows no penalty and no chosen apps",
        awakening() + [
            act("Click 'PENALTY' in the bottom bar"),
            check("The '[ PENALTY ZONE ]' screen shows 'No penalty is in effect.', a clock '00:00:00', 'NO LOCK TODAY' and an 'EDIT LOCKED APPS' button"),
            check("No '[ PENALTY DEBT ]' panel and no 'RELEASE 15 MIN' button are shown"),
        ],
    ),
    "14-system-explainer": (
        "Awakening: choosing a System explains its first quest and its own penalty",
        [
            LOAD,
            *CONTACT,
            *show("PERSONALITY"),
            act("Click the front card (the button named 'Personality System') once to flip it, then wait 1 second"),
            check("The card now shows '[ PERSONALITY · BRIEF ]', a 'WHERE YOU START' list containing 'Read (pages)' with '10', and an 'IF YOU FAIL A DAY' section mentioning '20 pages and a written reflection' and no push-ups; the button at the bottom reads 'CHOOSE PERSONALITY SYSTEM'"),
            *show("FOCUS"),
            act("If the front card shows 'TAP TO INSPECT', click it once (the button named 'Focus System') and wait 1 second"),
            check("The card shows '[ FOCUS · BRIEF ]' and its 'IF YOU FAIL A DAY' section mentions 'a 60-minute phone-free block'; the button reads 'CHOOSE FOCUS SYSTEM'"),
        ],
    ),
    "08-onboarding-validation": (
        "Awakening: the choose button always names the System on the front card",
        [
            LOAD,
            *CONTACT,
            check("The 'CHOOSE YOUR SYSTEM' screen shows the FITNESS card in front, three diamond buttons under it, and a button reading 'CHOOSE FITNESS SYSTEM'"),
            *show("FOCUS"),
            check("The FOCUS card is now in front and the button reads 'CHOOSE FOCUS SYSTEM'; no 'PLACEMENT TEST' screen has been shown"),
            *show("PERSONALITY"),
            check("The button now reads 'CHOOSE PERSONALITY SYSTEM'"),
        ],
    ),
    "09-custom-objective": (
        "Awakening: a strong placement test starts the Player at rank C, never higher",
        awakening(answers=[("Most push-ups you can do in one set", 80), ("Minutes to walk or jog 1 km", 4)]) + [
            check("The '[ DAILY QUEST ]' window lists 'Jog' showing '0.0 / 2.0 km' and 'Push-ups' showing '0 / 30' (the rank C quest), and the quest window shows 'RANK C · FITNESS'"),
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
            check("The objective now shows 'APPS LOCKED' and a 'HOLD TO END BLOCK' button"),
            act("Click 'HOLD TO END BLOCK' once (test build: a click confirms)"),
            check("The button reads 'START BLOCK' again"),
        ],
    ),
    "12-reduction-valve": (
        "Status: lowering the quest by 20% applies from tomorrow at half XP",
        awakening() + [
            act("Click 'STATUS' in the bottom bar"),
            check("The 'QUEST REDUCTION' row on the '[ STATUS ]' screen shows 'Full quest · full XP.'"),
            act("In the 'QUEST REDUCTION' row, click '20%'"),
            check("The 'QUEST REDUCTION' row now shows '−20% targets · applies tomorrow · half XP'"),
            act("Click 'QUEST' in the bottom bar"),
            check("The 'Push-ups (knees allowed)' objective still shows '0 / 10' today (the reduction is not applied until tomorrow)"),
        ],
    ),
    "13-report": (
        "Status: the report opens and shows the honesty section",
        awakening() + [
            act("Click 'STATUS' in the bottom bar"),
            act("Click 'REPORT' on the '[ STATUS ]' window"),
            check("A '[ 30-DAY REPORT ]' screen is shown with 'NO JUDGED DAYS YET' and a '0%' 'CLEAR RATE' dial"),
            act("Scroll down the report page"),
            check("An 'HONESTY' section (with a 'RELEASES TAKEN' tile) and a 'VERDICT' box with 'Insufficient data. Continue.' are shown"),
            act("Click 'CLOSE'"),
            check("The '[ STATUS ]' screen is shown again"),
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
