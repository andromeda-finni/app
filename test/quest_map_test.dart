import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/core/child_difficulty.dart';
import 'package:andromeda_app/games/goldfish/goldfish_game_models.dart';
import 'package:andromeda_app/games/goldfish/goldfish_game_screen.dart';
import 'package:andromeda_app/games/ivan/ivan_game_models.dart';
import 'package:andromeda_app/games/ivan/ivan_game_screen.dart';
import 'package:andromeda_app/games/turnip/turnip_game_screen.dart';
import 'package:andromeda_app/map/quest_map_data.dart';
import 'package:andromeda_app/map/quest_map_screen.dart';
import 'package:andromeda_app/theme/app_theme.dart';

import 'support/fake_auth_storage.dart';

Widget _map({
  List<String> completed = const [],
  bool showBack = false,
  ChildDifficulty difficulty = ChildDifficulty.beginner,
}) {
  final client = MockClient(
    (request) async => http.Response(
      jsonEncode({
        'pet': {'pet_name': 'Мурзик', 'fur_option_id': 'FUR_GRAY'},
        'quests': [
          for (final id in completed)
            {'id': id, 'assignment_status': 'COMPLETED'},
        ],
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  );
  return MaterialApp(
    theme: AppTheme.light,
    home: QuestMapScreen(
      showBack: showBack,
      difficulty: difficulty,
      apiClient: ApiClient(
        httpClient: client,
        authStorage: FakeAuthStorage(initialToken: 'tok'),
        baseUrl: 'http://test',
      ),
    ),
  );
}

/// Taps a hero and waits for the cat's walk plus the sheet. The arrival pulse
/// repeats forever, so the clock is advanced instead of settling.
Future<void> _openNode(WidgetTester tester, String id) async {
  final hero = find.byKey(Key('quest-map-hero-$id'));
  await tester.ensureVisible(hero);
  await tester.pump();
  await tester.tap(hero);
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  group('progress comes from completed server quests', () {
    int indexOf(String id) => questMapNodes.indexWhere((n) => n.id == id);

    test('with nothing completed the turnip is the current node', () {
      expect(unlockedIndexFor(const {}), indexOf('turnip'));
    });

    test('the turnip harvest opens the mole', () {
      expect(unlockedIndexFor(const {'Q_TURNIP_HARVEST'}), indexOf('mole'));
    });

    test('finishing the mole opens Ivan', () {
      expect(
        unlockedIndexFor(const {'Q_TURNIP_HARVEST', 'Q_MOLE_FINE_PRINT'}),
        indexOf('ivan'),
      );
    });

    test('finishing either Ivan track opens the Goldfish game', () {
      expect(
        unlockedIndexFor(const {
          'Q_TURNIP_HARVEST',
          'Q_MOLE_FINE_PRINT',
          'Q_IVAN_ROAD_EASY_1',
          'Q_IVAN_ROAD_EASY_2',
        }),
        indexOf('goldfish'),
      );
    });

    test('finishing either Goldfish track opens the path up to Tugriki', () {
      expect(
        unlockedIndexFor(const {
          'Q_TURNIP_HARVEST',
          'Q_MOLE_FINE_PRINT',
          'Q_IVAN_ROAD_EASY_1',
          'Q_IVAN_ROAD_EASY_2',
          'Q_GOLDFISH_HOME_SIMPLE_1',
          'Q_GOLDFISH_HOME_SIMPLE_2',
        }),
        indexOf('tugriki'),
      );
    });

    test('with every game done the whole map is open', () {
      expect(
        unlockedIndexFor(const {
          'Q_TURNIP_HARVEST',
          'Q_MOLE_FINE_PRINT',
          'Q_IVAN_ROAD_HARD_1',
          'Q_IVAN_ROAD_HARD_2',
          'Q_GOLDFISH_HOME_ADVANCED_1',
          'Q_GOLDFISH_HOME_ADVANCED_2',
          'Q_TUGRIKI_CURRENCY',
        }),
        questMapNodes.length - 1,
      );
    });

    test('every playable node maps to a server quest', () {
      for (final node in questMapNodes.where((n) => n.isPlayable)) {
        expect(node.destination.questIds, isNotEmpty, reason: node.id);
      }
      expect(playableQuestCount, 5);
    });
  });

  testWidgets('a new child can only play the turnip', (tester) async {
    await tester.pumpWidget(_map());
    await tester.pumpAndSettle();

    expect(find.text('Пройдено 0 из 5'), findsOneWidget);
    // As a tab the map has no back arrow: there is nothing to go back to.
    expect(find.byTooltip('Назад'), findsNothing);

    await _openNode(tester, 'mole');
    expect(find.text('Сначала пройди предыдущее задание'), findsOneWidget);
    expect(find.text('Играть'), findsNothing);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pump(const Duration(milliseconds: 500));

    await _openNode(tester, 'turnip');
    expect(find.text('Играть'), findsOneWidget);
    await tester.tap(find.text('Играть'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(TurnipGameScreen), findsOneWidget);
  });

  testWidgets('server progress opens Ivan before Tugriki', (tester) async {
    await tester.pumpWidget(
      _map(completed: const ['Q_TURNIP_HARVEST', 'Q_MOLE_FINE_PRINT']),
    );
    await tester.pumpAndSettle();

    expect(find.text('Пройдено 2 из 5'), findsOneWidget);

    await _openNode(tester, 'ivan');
    expect(find.text('Играть'), findsOneWidget);
    await tester.tap(find.text('Играть'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(IvanGameScreen), findsOneWidget);
    expect(find.textContaining('Привет, Мурзик'), findsOneWidget);
  });

  test('a completed Ivan track is recognised as one map quest', () {
    expect(
      isIvanTrackComplete(const {'Q_IVAN_ROAD_EASY_1', 'Q_IVAN_ROAD_EASY_2'}),
      isTrue,
    );
  });

  test('a completed Goldfish track is recognised as one map quest', () {
    expect(
      isGoldfishTrackComplete(const {
        'Q_GOLDFISH_HOME_ADVANCED_1',
        'Q_GOLDFISH_HOME_ADVANCED_2',
      }),
      isTrue,
    );
  });

  testWidgets('map opens Goldfish with profile difficulty and pet name', (
    tester,
  ) async {
    await tester.pumpWidget(
      _map(
        completed: const [
          'Q_TURNIP_HARVEST',
          'Q_MOLE_FINE_PRINT',
          'Q_IVAN_ROAD_HARD_1',
          'Q_IVAN_ROAD_HARD_2',
        ],
        difficulty: ChildDifficulty.advanced,
      ),
    );
    await tester.pumpAndSettle();

    await _openNode(tester, 'goldfish');
    expect(find.text('Играть'), findsOneWidget);
    await tester.tap(find.text('Играть'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.byType(GoldfishGameScreen), findsOneWidget);
    expect(find.textContaining('Привет, Мурзик'), findsOneWidget);
    expect(
      tester
          .widget<GoldfishGameScreen>(find.byType(GoldfishGameScreen))
          .initialLevel,
      GoldfishLevelId.hardOne,
    );
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
      expect(find.byKey(const Key('quest-map-kitten')), findsOneWidget);
      expect(find.byTooltip('Назад'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
