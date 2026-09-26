import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';

import 'package:andromeda_app/games/turnip/turnip_game_content.dart';
import 'package:andromeda_app/games/turnip/turnip_game_models.dart';
import 'package:andromeda_app/games/turnip/turnip_game_screen.dart';
import 'package:andromeda_app/theme/app_theme.dart';

import 'support/fake_auth_storage.dart';

Widget _game(
  TurnipDifficulty difficulty, {
  TextScaler textScaler = TextScaler.noScaling,
  String petName = 'Лучик',
  ValueChanged<TurnipGameResult>? onCompleted,
  ApiClient? apiClient,
}) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: TurnipGameScreen(
    difficulty: difficulty,
    apiClient: apiClient,
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
    // Without a server the game is practice: no reward is promised.
    expect(find.textContaining('Награда:'), findsNothing);
    expect(
      find.text('Тренировочный режим: результат не меняет кошелёк.'),
      findsOneWidget,
    );
    expect(results, hasLength(1));
    expect(results.single.questId, turnipQuestId);
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

  testWidgets('the harvest is paid by the server, once', (tester) async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      final body = switch (request.url.path) {
        '/quests/$turnipQuestId/start' => {
          'assignmentId': 'a-1',
          'nextStepNo': 1,
          'rewardAmount': 10,
        },
        '/assignments/a-1/answer' => {
          'outcome': 'SUCCESS',
          'questCompleted': true,
          'rewardAmount': 10,
        },
        _ => <String, Object>{},
      };
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await tester.pumpWidget(
      _game(
        TurnipDifficulty.normal,
        apiClient: ApiClient(
          httpClient: client,
          authStorage: FakeAuthStorage(initialToken: 'tok'),
          baseUrl: 'http://test',
        ),
      ),
    );
    await tester.pump();
    await _finishIntro(tester);
    for (final character in TurnipCharacter.values) {
      await tester.tap(find.byKey(ValueKey('turnip-piece-${character.name}')));
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(calls, [
      'POST /quests/$turnipQuestId/start',
      'POST /assignments/a-1/answer',
    ]);
    expect(find.text('Награда: 10 монет'), findsOneWidget);

    // Replaying is practice: no second submission and no second reward.
    await tester.tap(find.byKey(const ValueKey('turnip-replay')));
    await tester.pump();
    for (final character in TurnipCharacter.values) {
      await tester.tap(find.byKey(ValueKey('turnip-piece-${character.name}')));
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(calls, hasLength(2));
    expect(find.textContaining('Награда:'), findsNothing);
  });
}
