import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/games/turnip/turnip_game_content.dart';
import 'package:andromeda_app/games/turnip/turnip_game_demo_screen.dart';
import 'package:andromeda_app/games/turnip/turnip_game_models.dart';
import 'package:andromeda_app/games/turnip/turnip_game_screen.dart';
import 'package:andromeda_app/home/games_screen.dart';
import 'package:andromeda_app/theme/app_theme.dart';

Widget _game(
  TurnipDifficulty difficulty, {
  TextScaler textScaler = TextScaler.noScaling,
  String petName = 'Лучик',
  ValueChanged<TurnipGameResult>? onCompleted,
}) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: TurnipGameScreen(
    difficulty: difficulty,
    petName: petName,
    onCompleted: onCompleted,
  ),
);

Future<void> _finishIntro(WidgetTester tester) async {
  for (var page = 0; page < 3; page++) {
    await tester.tap(find.byKey(const ValueKey('turnip-intro-continue')));
    await tester.pump();
  }
}

void main() {
  final introLines = turnipIntroLinesFor('Лучик');

  testWidgets('the child never sees a difficulty selector', (tester) async {
    await tester.pumpWidget(_game(TurnipDifficulty.hard));
    await tester.pump();

    expect(find.text('Нормальная'), findsNothing);
    expect(find.text('Сложная'), findsNothing);
    expect(find.text(introLines.first.text), findsOneWidget);
    expect(
      find.byKey(const ValueKey('turnip-intro-grandpa-portrait')),
      findsOneWidget,
    );
  });

  testWidgets('intro keeps the authored dialogue and opens the playfield', (
    tester,
  ) async {
    await tester.pumpWidget(_game(TurnipDifficulty.normal));
    await tester.pump();

    for (var page = 0; page < introLines.length; page++) {
      expect(find.text(introLines[page].speaker), findsOneWidget);
      expect(find.text(introLines[page].text), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('turnip-intro-continue')));
      await tester.pump();
    }

    expect(find.text(turnipTaskText), findsOneWidget);
    expect(find.text('0/5'), findsOneWidget);
  });

  testWidgets('normal version accepts helpers in an arbitrary order', (
    tester,
  ) async {
    final results = <TurnipGameResult>[];
    await tester.pumpWidget(
      _game(TurnipDifficulty.normal, onCompleted: results.add),
    );
    await tester.pump();
    await _finishIntro(tester);

    const order = [
      TurnipCharacter.mouse,
      TurnipCharacter.cat,
      TurnipCharacter.zhuchka,
      TurnipCharacter.granddaughter,
      TurnipCharacter.grandmother,
    ];
    for (final character in order) {
      await tester.tap(find.byKey(ValueKey('turnip-piece-${character.name}')));
      await tester.pump();
    }

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Репка вытащена!'), findsOneWidget);
    expect(find.text(turnipSuccessText), findsOneWidget);
    expect(find.text('Награда: 10 монет'), findsOneWidget);
    expect(find.bySemanticsLabel('Награда: 10 монет'), findsOneWidget);
    expect(results, hasLength(1));
    expect(results.single.questId, turnipQuestId);
    expect(results.single.rewardAmount, 10);
    await tester.pump(const Duration(seconds: 1));
    expect(results, hasLength(1));
    expect(
      find.bySemanticsLabel('Счастливые герои рядом с вытащенной репкой'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('turnip-final-grandpa')), findsNothing);
  });

  testWidgets('hard version rejects the wrong helper and shows a hint', (
    tester,
  ) async {
    await tester.pumpWidget(_game(TurnipDifficulty.hard));
    await tester.pump();
    await _finishIntro(tester);

    for (var attempt = 0; attempt < 3; attempt++) {
      await tester.tap(find.byKey(const ValueKey('turnip-piece-mouse')));
      await tester.pump(const Duration(milliseconds: 350));
    }

    expect(find.textContaining(turnipWrongOrderText), findsOneWidget);
    expect(find.textContaining(turnipHintText), findsOneWidget);
    expect(find.text('0/5'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('turnip-piece-grandmother')));
    await tester.pump();
    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets('dragging a helper onto the chain advances progress', (
    tester,
  ) async {
    await tester.pumpWidget(_game(TurnipDifficulty.hard));
    await tester.pump();
    await _finishIntro(tester);

    final piece = find.byKey(const ValueKey('turnip-piece-grandmother'));
    final target = find.byKey(const ValueKey('turnip-chain-target'));
    await tester.dragFrom(
      tester.getCenter(piece),
      tester.getCenter(target) - tester.getCenter(piece),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/5'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('turnip-chain-grandmother')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('turnip-scene-target')), findsNothing);
  });

  testWidgets('game fits a small phone with enlarged Russian text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _game(TurnipDifficulty.hard, textScaler: const TextScaler.linear(1.3)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await _finishIntro(tester);
    await tester.pump();
    expect(find.text(turnipTaskText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map card opens the externally configured version', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const GamesScreen(
          turnipDifficulty: TurnipDifficulty.hard,
          petName: 'Рыжик',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Репка'), findsOneWidget);
    expect(find.text('Сложная'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('turnip-game-card')));
    await tester.pumpAndSettle();

    expect(find.byType(TurnipGameScreen), findsOneWidget);
    expect(find.text(turnipIntroLinesFor('Рыжик').first.text), findsOneWidget);
  });

  testWidgets('demo launcher exposes both externally selected versions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const TurnipGameDemoScreen()),
    );

    expect(find.text('Попроще'), findsOneWidget);
    expect(find.text('Посложнее'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('turnip-demo-normal')));
    await tester.pumpAndSettle();
    final game = tester.widget<TurnipGameScreen>(find.byType(TurnipGameScreen));
    expect(game.difficulty, TurnipDifficulty.normal);
  });
}
