enum ChildDifficulty { beginner, advanced }

extension ChildDifficultyData on ChildDifficulty {
  String get apiValue => switch (this) {
    ChildDifficulty.beginner => 'SIMPLE',
    ChildDifficulty.advanced => 'ADVANCED',
  };

  String get title => switch (this) {
    ChildDifficulty.beginner => 'С подсказками',
    ChildDifficulty.advanced => 'Самостоятельно',
  };

  String get description => switch (this) {
    ChildDifficulty.beginner => 'Игра чаще напоминает, что делать дальше.',
    ChildDifficulty.advanced =>
      'Сначала пробуешь сам, а подсказка появится, если она нужна.',
  };
}

ChildDifficulty childDifficultyFromApi(Object? value) =>
    value == 'ADVANCED' ? ChildDifficulty.advanced : ChildDifficulty.beginner;
