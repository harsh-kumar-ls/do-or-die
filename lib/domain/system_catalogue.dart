import 'progression.dart';
import 'systems.dart';

/// Every System's daily quests and Rank Trials, E to S. Starting values from
/// SYSTEMS_PRD.md section 6.1; tune here, never in UI code.
///
/// Fitness ranks are conservative progressions, not medical advice.

QuestItem _check(String id, String label) =>
    QuestItem(id, label, QuestKind.checkbox, 1);
QuestItem _min(String id, String label, int minutes) =>
    QuestItem(id, label, QuestKind.timer, minutes);
QuestItem _count(String id, String label, int n) =>
    QuestItem(id, label, QuestKind.counter, n);
QuestItem _metres(String id, String label, int m) =>
    QuestItem(id, label, QuestKind.distance, m);
QuestItem _cap(String id, String label, int minutes) =>
    QuestItem(id, label, QuestKind.screenCap, minutes);
QuestItem _free(String id, String label, int minutes) =>
    QuestItem(id, label, QuestKind.phoneFree, minutes);

const _holdS = 30;

final fitnessSystem = SystemSpec(
  SystemKind.fitness,
  'Fitness System',
  'Build strength and stamina, one rank at a time.',
  const [Stat.strength, Stat.vitality],
  {
    Rank.e: RankSpec(
      [
        _min('walk', 'Walk', 12),
        _count('pushups', 'Push-ups (knees allowed)', 10),
        _count('squats', 'Squats', 15),
      ],
      RankTrial('30 squats unbroken, then a 1.5 km walk in under 18 minutes', [
        _count('squats_unbroken', 'Squats without stopping', 30),
        _metres('walk_15', 'Walk 1.5 km in under 18 min', 1500),
      ]),
    ),
    Rank.d: RankSpec(
      [
        _min('walk', 'Walk', 20),
        _count('pushups', 'Push-ups', 20),
        _count('squats', 'Squats', 30),
        _count('plank', 'Plank (seconds, may be split)', 30),
      ],
      RankTrial(
        'A 2 km walk-jog in under 16 minutes, then 25 push-ups in sets',
        [
          _metres('walkjog_2', 'Walk-jog 2 km in under 16 min', 2000),
          _count('pushups_sets', 'Push-ups in sets', 25),
        ],
      ),
    ),
    Rank.c: RankSpec(
      [
        _metres('jog', 'Jog', 2000),
        _count('pushups', 'Push-ups', 30),
        _count('lunges', 'Lunges', 40),
        _count('plank', 'Plank (seconds, may be split)', 45),
      ],
      RankTrial('A 3 km continuous jog', [
        _metres('jog_3', 'Jog 3 km without stopping', 3000),
      ]),
    ),
    Rank.b: RankSpec(
      [
        _metres('run', 'Run', 3000),
        _count('pushups', 'Push-ups in sets', 45),
        _count('plank', 'Plank (seconds, may be split)', 60),
        _min('mobility', 'Mobility and stretching', 10),
      ],
      RankTrial('5 km in under 35 minutes', [
        _metres('run_5', 'Run 5 km in under 35 min', 5000),
      ]),
    ),
    Rank.a: RankSpec(
      [
        _metres('run', 'Run (or a 45-min workout)', 5000),
        _count('pushups', 'Push-ups in sets', 60),
      ],
      RankTrial('8 km, or a 2-hour hike', [
        _metres('long_8', 'Cover 8 km (run or hike)', 8000),
      ]),
    ),
    Rank.s: RankSpec(
      [
        _min('program', 'Full-intensity training session', 60),
        _check('log', 'Log the session'),
      ],
      RankTrial(
        'Hold S rank: $_holdS consecutive cleared days',
        const [],
        holdDays: _holdS,
      ),
    ),
  },
);

final personalitySystem = SystemSpec(
  SystemKind.personality,
  'Personality System',
  'Grow your mind and your presence with people.',
  const [Stat.intellect, Stat.charisma],
  {
    Rank.e: RankSpec(
      [
        _count('pages', 'Read (pages)', 10),
        _check('journal', 'Write one journal line'),
        _check('hello', 'Say hello to someone you rarely talk to'),
      ],
      RankTrial('Finish a short book (150 pages or fewer) inside the Dungeon', [
        _check('book', 'Finish a short book'),
      ]),
    ),
    Rank.d: RankSpec(
      [
        _count('pages', 'Read (pages)', 20),
        _min('journal', 'Journal', 5),
        _check('greet', 'Greet someone new'),
      ],
      RankTrial('Hold a 10-minute conversation with someone new', [
        _min('conversation', 'Conversation with someone new', 10),
      ]),
    ),
    Rank.c: RankSpec(
      [
        _count('pages', 'Read (pages)', 30),
        _min('skill', 'Learn a skill', 20),
        _check('conversation', 'Start one conversation'),
      ],
      RankTrial('Give a 3-minute talk to at least one person', [
        _check('talk', 'Give a 3-minute talk'),
      ]),
    ),
    Rank.b: RankSpec(
      [
        _min('deepwork', 'Deep work', 45),
        _check('speakup', 'Speak up once in a group'),
      ],
      RankTrial('Lead a group discussion or a meeting segment', [
        _check('lead', 'Lead a group discussion'),
      ]),
    ),
    Rank.a: RankSpec(
      [
        _check('teach', 'Teach something you learned'),
        _min('deepwork', 'Deep work', 60),
      ],
      RankTrial('Publish or present a finished piece of work', [
        _check('publish', 'Publish or present finished work'),
      ]),
    ),
    Rank.s: RankSpec(
      [_check('create', 'Create something: write, build or present')],
      RankTrial(
        'Hold S rank: $_holdS consecutive cleared days',
        const [],
        holdDays: _holdS,
      ),
    ),
  },
);

final focusSystem = SystemSpec(
  SystemKind.focus,
  'Focus System',
  'Take your attention back from your phone.',
  const [Stat.discipline],
  {
    Rank.e: RankSpec(
      [_free('morning', 'No phone after waking (minutes)', 20)],
      RankTrial('A 3-hour phone-free block', [
        _free('block_180', 'Phone-free block', 180),
      ]),
    ),
    Rank.d: RankSpec(
      [_cap('social', 'Social media (max minutes)', 60)],
      RankTrial('Social media under 30 minutes for the whole boss day', [
        _cap('social_30', 'Social media (max minutes)', 30),
      ]),
    ),
    Rank.c: RankSpec(
      [
        _cap('social', 'Social media (max minutes)', 40),
        _check('meals', 'No phone at meals'),
      ],
      RankTrial(
        'A phone-light day: under 15 minutes of social media, no phone at meals',
        [
          _cap('social_15', 'Social media (max minutes)', 15),
          _check('meals', 'No phone at meals'),
        ],
      ),
    ),
    Rank.b: RankSpec(
      [_free('block', 'Phone-free block', 120)],
      RankTrial('A 6-hour phone-free block', [
        _free('block_360', 'Phone-free block', 360),
      ]),
    ),
    Rank.a: RankSpec(
      [
        _cap('social', 'Social media (max minutes)', 20),
        _check('night', 'No phone after 22:30'),
      ],
      RankTrial('A 24-hour social-media fast', [
        _cap('social_0', 'Social media (max minutes)', 0),
      ]),
    ),
    Rank.s: RankSpec(
      [
        _check('locked', 'Chosen apps stay locked all day'),
        _check('twice', 'Messages checked at most twice'),
      ],
      RankTrial(
        'Hold S rank: $_holdS consecutive cleared days',
        const [],
        holdDays: _holdS,
      ),
    ),
  },
);

/// The full catalogue, keyed by System.
final systemCatalogue = <SystemKind, SystemSpec>{
  SystemKind.fitness: fitnessSystem,
  SystemKind.personality: personalitySystem,
  SystemKind.focus: focusSystem,
};
