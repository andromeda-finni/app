import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/events/fox/fox_event_content.dart';
import 'package:andromeda_app/events/fox/fox_event_models.dart';

void main() {
  test('contains every Fox scenario from both age groups', () {
    expect(kFoxScripts, hasLength(5));
    expect(foxScriptsFor(FoxAgeGroup.younger), hasLength(3));
    expect(foxScriptsFor(FoxAgeGroup.older), hasLength(2));
    expect(
      kFoxScripts.map((script) => script.title),
      containsAll(<String>{
        'Знакомство',
        'Клад',
        'Красивые сапоги',
        'Медовый бизнес',
        'Срочный секрет',
      }),
    );
  });

  test('difficulty labels are child-facing', () {
    expect(FoxAgeGroup.younger.label, 'Нормальная');
    expect(FoxAgeGroup.older.label, 'Сложная');
  });

  test('first hard scenario keeps the authored introduction in pages', () {
    final start = foxScriptById('fox_older_honey_business').node('start');

    expect(start.mood, FoxMood.friendly);
    expect(start.textPages, [
      'Привет, {petName}! Я Лис. Живу неподалёку. Рад познакомиться!',
      'Иногда я прихожу к друзьям за советом и помощью. Будь другом, помоги пожалуйста.',
      'Сейчас мне очень нужны 20 монет. Через три дня я верну тебе 25.',
    ]);
  });

  test('every scenario choice points to an existing node', () {
    for (final script in kFoxScripts) {
      expect(
        script.nodes,
        contains(script.initialNodeId),
        reason: '${script.title}: missing initial node',
      );
      for (final node in script.nodes.values) {
        expect(
          node.terminal || node.choices.isNotEmpty,
          isTrue,
          reason: '${script.title}/${node.id}: dead end',
        );
        for (final choice in node.choices) {
          expect(
            script.nodes,
            contains(choice.nextNodeId),
            reason: '${script.title}/${node.id}/${choice.id}: missing target',
          );
        }
      }
    }
  });

  test('delayed outcomes use exactly the next game day contract', () {
    final delayed = kFoxScripts
        .expand((script) => script.nodes.values)
        .where((node) => node.waitUntilNextGameDay)
        .toList();

    expect(delayed, isNotEmpty);
    expect(delayed.every((node) => node.terminal), isTrue);
  });
}
