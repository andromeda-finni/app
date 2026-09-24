import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/minigames/mole/mole_game_data.dart';
import 'package:andromeda_app/minigames/mole/mole_game_screen.dart';
import 'package:andromeda_app/screens/home_screen.dart';

void main() {
  test('mole scenario contains all five checks from the source script', () {
    expect(moleEpisodes, hasLength(5));
    expect(
      moleEpisodes.map((episode) => episode.id),
      containsAll(<String>[
        'grain_delivery',
        'lantern_offer',
        'extra_receipt_item',
        'wrong_total',
        'two_error_challenge',
      ]),
    );
    expect(moleEpisodes.first.questions.single.correctCode, '12');
    expect(moleEpisodes.last.questions.first.correctCode, '16');
    expect(moleEpisodes.last.questions.last.correctCode, 'seller');
  });

  testWidgets('wrong answer explains the error and a retry completes a check', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MoleGameScreen()));
    await tester.pumpAndSettle();

    final hint = find.byKey(const Key('mole-hint-button'));
    await tester.scrollUntilVisible(
      hint,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(hint);
    await tester.pumpAndSettle();

    final wrongAnswer = find.byKey(const Key('mole-answer-8'));
    await tester.scrollUntilVisible(
      wrongAnswer,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(wrongAnswer);
    await tester.pumpAndSettle();
    await tester.tap(wrongAnswer);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Сложи цену мешка и стоимость доставки'),
      findsOneWidget,
    );

    final correctAnswer = find.byKey(const Key('mole-answer-12'));
    await tester.scrollUntilVisible(
      correctAnswer,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(correctAnswer);
    await tester.pumpAndSettle();
    await tester.tap(correctAnswer);
    await tester.pumpAndSettle();

    expect(find.textContaining('Верно: 8 за зерно'), findsOneWidget);
    expect(find.text('Следующая проверка'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home card for the mole game fits a small phone', (tester) async {
    final dpr = tester.view.devicePixelRatio;
    tester.view.physicalSize = Size(320 * dpr, 568 * dpr);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('«Осторожно, мелкий шрифт»'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
