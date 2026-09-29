import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/core/pet_assets.dart';
import 'package:andromeda_app/games/turnip/turnip_game_screen.dart';
import 'package:andromeda_app/map/quest_map_data.dart';
import 'package:andromeda_app/map/quest_map_screen.dart';
import 'package:andromeda_app/theme/app_theme.dart';

import 'support/fake_auth_storage.dart';

Widget _map({
  List<String> completed = const [],
  List<String> inProgress = const [],
  bool showBack = false,
  double textScale = 1,
  bool failProgress = false,
  bool ambientMotion = false,
}) {
  final client = MockClient((request) async {
    if (failProgress) {
      return http.Response(
        jsonEncode({'error': 'unavailable'}),
        503,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    const rewards = {
      'Q_TURNIP_HARVEST': 10,
      'Q_MOLE_FINE_PRINT': 15,
      'Q_TUGRIKI_CURRENCY': 15,
    };
    return http.Response(
      jsonEncode({
        'pet': {'pet_name': 'Мурзик', 'fur_option_id': 'FUR_GRAY'},
        'quests': [
          for (final entry in rewards.entries)
            {
              'id': entry.key,
              'reward_amount': entry.value,
              'assignment_status': completed.contains(entry.key)
                  ? 'COMPLETED'
                  : inProgress.contains(entry.key)
                  ? 'IN_PROGRESS'
                  : null,
            },
        ],
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  return MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: QuestMapScreen(
      showBack: showBack,
      enableAmbientSceneMotion: ambientMotion,
      apiClient: ApiClient(
        httpClient: client,
        authStorage: FakeAuthStorage(initialToken: 'tok'),
        baseUrl: 'http://test',
      ),
    ),
  );
}

/// Taps a quest marker and lets movement plus the anchored prompt finish.
Future<void> _openNode(WidgetTester tester, String id) async {
  final hero = find.byKey(Key('quest-map-hero-$id'));
  await tester.ensureVisible(hero);
  await tester.pump();
  await tester.tap(hero);
  await tester.pumpAndSettle();
}

void main() {
  group('progress comes from completed server quests', () {
    int indexOf(String id) => questMapNodes.indexWhere((n) => n.id == id);

    test('with nothing completed the turnip is the current node', () {
      expect(currentPlayableNodeIndex(const {}), indexOf('turnip'));
    });

    test('the turnip harvest opens the mole', () {
      expect(
        currentPlayableNodeIndex(const {'Q_TURNIP_HARVEST'}),
        indexOf('mole'),
      );
    });

    test('finishing the mole opens the path up to Tugriki', () {
      // Story-only nodes in between have nothing to complete, so they must not
      // block the child from reaching Tugriki.
      expect(
        currentPlayableNodeIndex(const {
          'Q_TURNIP_HARVEST',
          'Q_MOLE_FINE_PRINT',
        }),
        indexOf('tugriki'),
      );
    });

    test('with every game done there is no false current future chapter', () {
      expect(
        currentPlayableNodeIndex(const {
          'Q_TURNIP_HARVEST',
          'Q_MOLE_FINE_PRINT',
          'Q_TUGRIKI_CURRENCY',
        }),
        isNull,
      );
    });

    test('story-only chapters are always marked as coming soon', () {
      final completed = {
        'Q_TURNIP_HARVEST',
        'Q_MOLE_FINE_PRINT',
        'Q_TUGRIKI_CURRENCY',
      };
      for (final node in questMapNodes.where((node) => !node.isPlayable)) {
        expect(
          stateForQuestMapNode(node, completed),
          QuestMapNodeState.comingSoon,
          reason: node.id,
        );
      }
    });

    test('every playable node maps to a server quest', () {
      for (final node in questMapNodes.where((n) => n.isPlayable)) {
        expect(node.destination.questId, isNotNull, reason: node.id);
      }
      expect(playableQuestCount, 3);
    });

    test('checkpoint anchors match the painted map artwork', () {
      const sourceWidth = 821.0;
      const sourceHeight = 1916.0;
      const expectedPixels = <Offset>[
        Offset(374.65, 1853.50),
        Offset(392.04, 1381.20),
        Offset(411.58, 1178.44),
        Offset(471.02, 902.34),
        Offset(350.96, 684.20),
        Offset(457.66, 487.95),
        Offset(472.57, 299.69),
        Offset(742, 248),
      ];
      const expectedCatStops = <Offset>[
        Offset(374.65, 1853.50),
        Offset(392.04, 1381.20),
        Offset(411.58, 1178.44),
        Offset(471.02, 902.34),
        Offset(350.96, 684.20),
        Offset(457.66, 487.95),
        Offset(472.57, 299.69),
        Offset(742, 248),
      ];

      for (var index = 0; index < questMapNodes.length; index++) {
        final node = questMapNodes[index];
        expect(
          node.nodeCenter.dx * sourceWidth,
          closeTo(expectedPixels[index].dx, 0.02),
          reason: node.id,
        );
        expect(
          node.nodeCenter.dy * sourceHeight,
          closeTo(expectedPixels[index].dy, 0.02),
          reason: node.id,
        );
        expect(
          node.catStop.dx * sourceWidth,
          closeTo(expectedCatStops[index].dx, 0.02),
          reason: '${node.id} cat x',
        );
        expect(
          node.catStop.dy * sourceHeight,
          closeTo(expectedCatStops[index].dy, 0.02),
          reason: '${node.id} cat y',
        );
      }
    });
  });

  testWidgets('a new child can only play the turnip', (tester) async {
    await tester.pumpWidget(_map());
    await tester.pumpAndSettle();

    expect(find.text('Квест №1'), findsOneWidget);
    // As a tab the map has no back arrow: there is nothing to go back to.
    expect(find.byTooltip('Назад'), findsNothing);

    await _openNode(tester, 'mole');
    expect(find.text('Откроется после квеста 1 «Репка»'), findsOneWidget);
    expect(find.byKey(const Key('quest-scene-highlight-mole')), findsOneWidget);
    expect(find.text('Начать'), findsNothing);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pump(const Duration(milliseconds: 500));

    await _openNode(tester, 'turnip');
    expect(find.text('Начать'), findsOneWidget);
    expect(find.text('10 монет за прохождение'), findsOneWidget);
    await tester.tap(find.text('Начать'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(TurnipGameScreen), findsOneWidget);
  });

  testWidgets('server progress opens the path up to Tugriki', (tester) async {
    await tester.pumpWidget(
      _map(completed: const ['Q_TURNIP_HARVEST', 'Q_MOLE_FINE_PRINT']),
    );
    await tester.pumpAndSettle();

    expect(find.text('Квест №7'), findsOneWidget);

    await _openNode(tester, 'tugriki');
    expect(find.text('Начать'), findsOneWidget);
    expect(find.text('15 монет за прохождение'), findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pump(const Duration(milliseconds: 500));

    await _openNode(tester, 'bakery');
    expect(find.textContaining('Глава в разработке'), findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pump(const Duration(milliseconds: 500));

    await _openNode(tester, 'badger');
    expect(find.textContaining('Глава в разработке'), findsOneWidget);
  });

  testWidgets('in-progress quest uses an honest resume action', (tester) async {
    await tester.pumpWidget(
      _map(
        completed: const ['Q_TURNIP_HARVEST'],
        inProgress: const ['Q_MOLE_FINE_PRINT'],
      ),
    );
    await tester.pumpAndSettle();

    await _openNode(tester, 'mole');
    expect(find.text('Продолжить'), findsOneWidget);
    expect(find.text('Продолжи приключение.'), findsOneWidget);
    expect(find.textContaining('Мурзик готов'), findsNothing);
  });

  testWidgets('completed playable quest can be replayed without a reward', (
    tester,
  ) async {
    await tester.pumpWidget(_map(completed: const ['Q_TURNIP_HARVEST']));
    await tester.pumpAndSettle();

    await _openNode(tester, 'turnip');
    expect(find.text('Играть ещё раз'), findsOneWidget);
    expect(
      find.text('Можно пройти ещё раз для тренировки — без повторной награды.'),
      findsOneWidget,
    );
  });

  testWidgets('an accessible checkpoint moves the cat before prompting', (
    tester,
  ) async {
    await tester.pumpWidget(_map(completed: const ['Q_TURNIP_HARVEST']));
    await tester.pumpAndSettle();

    final turnip = find.byKey(const Key('quest-map-hero-turnip'));
    await tester.ensureVisible(turnip);
    await tester.tap(turnip);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(const Key('quest-prompt-turnip')), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/map/cat_walk/striped.webp',
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quest-prompt-turnip')), findsOneWidget);
    expect(
      find.byKey(const Key('quest-scene-highlight-turnip')),
      findsOneWidget,
    );
  });

  testWidgets('the cat animates on every trip between accessible checkpoints', (
    tester,
  ) async {
    await tester.pumpWidget(_map(completed: const ['Q_TURNIP_HARVEST']));
    await tester.pumpAndSettle();

    final turnip = find.byKey(const Key('quest-map-hero-turnip'));
    await tester.ensureVisible(turnip);
    await tester.tap(turnip);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();

    final mole = find.byKey(const Key('quest-map-hero-mole'));
    await tester.ensureVisible(mole);
    await tester.tap(mole);
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const Key('quest-prompt-mole')), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/map/cat_walk/striped.webp',
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quest-prompt-mole')), findsOneWidget);
  });

  testWidgets('road markers and symbols communicate every checkpoint state', (
    tester,
  ) async {
    await tester.pumpWidget(_map(completed: const ['Q_TURNIP_HARVEST']));
    await tester.pumpAndSettle();

    String assetName(Widget widget) => (widget as Image).image is AssetImage
        ? ((widget.image as AssetImage).assetName)
        : '';
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            assetName(widget) == 'assets/map/checkpoint_road_v2.png',
      ),
      findsNWidgets(questMapNodes.length),
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('quest-map-hero-turnip')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('quest-map-hero-mole')),
        matching: find.byIcon(Icons.play_arrow_rounded),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('quest-map-hero-tugriki')),
        matching: find.byIcon(Icons.lock_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('quest-map-hero-ivan')),
        matching: find.byIcon(Icons.lock_rounded),
      ),
      findsOneWidget,
    );

    final currentMarker = find.descendant(
      of: find.byKey(const Key('quest-map-hero-mole')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/map/checkpoint_road_v2.png',
      ),
    );
    expect(tester.getSize(currentMarker).width, greaterThanOrEqualTo(92));
    expect(
      tester.getSize(find.byKey(const Key('quest-map-cat'))).width,
      greaterThanOrEqualTo(82),
    );

    final occupiedNodeRect = tester.getRect(
      find.byKey(const Key('quest-map-hero-mole')),
    );
    final catRect = tester.getRect(find.byKey(const Key('quest-map-cat')));
    expect(catRect.bottomCenter.dx, closeTo(occupiedNodeRect.center.dx, 0.1));
    expect(catRect.bottomCenter.dy, closeTo(occupiedNodeRect.center.dy, 0.1));
  });

  testWidgets('current story scene keeps its ambient motion after one cycle', (
    tester,
  ) async {
    await tester.pumpWidget(_map(ambientMotion: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('quest-scene-highlight-turnip')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 4));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('all playable quests produce a real terminal map state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _map(
        completed: const [
          'Q_TURNIP_HARVEST',
          'Q_MOLE_FINE_PRINT',
          'Q_TUGRIKI_CURRENCY',
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 квеста пройдено'), findsOneWidget);
    expect(find.text('Все доступные задания пройдены'), findsOneWidget);
  });

  testWidgets('progress error blocks false map state and offers retry', (
    tester,
  ) async {
    await tester.pumpWidget(_map(failProgress: true));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить прогресс карты'), findsOneWidget);
    expect(find.byKey(const Key('retry-map-progress')), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('renders without overflow at ${width.toInt()} logical pixels', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 740);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_map(showBack: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quest-map-scroll')), findsOneWidget);
      expect(find.byKey(const Key('quest-map-cat')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  catMapIdleAsset(furOptionId: 'FUR_GRAY'),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Назад'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final textScale in [1.3, 2.0]) {
    testWidgets('supports ${textScale}x text scaling', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_map(showBack: true, textScale: textScale));
      await tester.pumpAndSettle();
      await _openNode(tester, 'turnip');

      expect(find.byKey(const Key('play-turnip')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
