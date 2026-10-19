import 'dart:convert';
import 'dart:ui' as ui;

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/games/ivan/ivan_game_screen.dart';
import 'package:andromeda_app/map/daily_quests.dart';
import 'package:andromeda_app/map/quest_map_screen.dart';
import 'package:andromeda_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:andromeda_app/map/quest_map_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_auth_storage.dart';

void main() {
  testWidgets('click targets lie inside the real painted ovals', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final data = await rootBundle.load('assets/map/quest_map_hd.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final bytes = (await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      for (final node in questMapNodes.where((node) => node.isRewardedQuest)) {
        final x = (node.nodeCenter.dx * frame.image.width).round();
        final y = (node.nodeCenter.dy * frame.image.height).round();
        final index = (y * frame.image.width + x) * 4;
        expect(bytes[index], greaterThan(215), reason: '${node.id}: red');
        expect(bytes[index + 1], greaterThan(185), reason: '${node.id}: green');
        expect(bytes[index + 2], greaterThan(130), reason: '${node.id}: blue');
      }
      codec.dispose();
      frame.image.dispose();
    });
  });
  const offers = [
    DailyQuestOffer(
      trackId: 'ivan',
      questId: 'Q_IVAN_ROAD_EASY_1',
      status: DailyQuestStatus.inProgress,
      rewardAmount: 10,
    ),
    DailyQuestOffer(
      trackId: 'squirrel',
      questId: 'Q_SQUIRREL_QUALITY_SIMPLE',
      status: DailyQuestStatus.available,
      rewardAmount: 10,
    ),
    DailyQuestOffer(
      trackId: 'goldfish',
      questId: 'Q_GOLDFISH_HOME_SIMPLE_1',
      status: DailyQuestStatus.available,
      rewardAmount: 10,
    ),
  ];
  const day = DailyQuestDay(
    periodId: 'day-1',
    sequenceNo: 1,
    planConfirmed: true,
    offers: offers,
  );

  testWidgets('between days the map offers an explicit start-day action', (
    tester,
  ) async {
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: QuestMapScreen(
          enableAmbientSceneMotion: false,
          dailyPreview: const DailyQuestDay(
            periodId: null,
            sequenceNo: null,
            planConfirmed: false,
            offers: [],
          ),
          onStartDayRequested: () => starts++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-start-new-day')), findsOneWidget);
    await tester.tap(find.text('Начать новый день'));
    expect(starts, 1);
    expect(find.byKey(const ValueKey('daily-badge-available')), findsNothing);
  });

  Future<void> openNode(WidgetTester tester, String id) async {
    final node = find.byKey(Key('quest-map-hero-$id'));
    await tester.ensureVisible(node);
    await tester.pump();
    await tester.tap(node);
    await tester.pumpAndSettle();
  }

  testWidgets('daily checks expire but finished character checks persist', (
    tester,
  ) async {
    var sequence = 1;
    final api = ApiClient(
      baseUrl: 'http://test',
      authStorage: FakeAuthStorage(initialToken: 'tok'),
      httpClient: MockClient((request) async {
        final Object body = request.url.path == '/economy/state'
            ? {
                'activeDay': {'id': 'day-$sequence'},
                'pet': {'pet_name': 'Мурзик', 'energy_level': 100},
                'quests': [
                  {
                    'id': 'Q_IVAN_ROAD_EASY_1',
                    'assignment_status': 'COMPLETED',
                  },
                  {
                    'id': 'Q_SQUIRREL_QUALITY_SIMPLE',
                    'assignment_status': 'COMPLETED',
                  },
                ],
              }
            : {
                'periodId': 'day-$sequence',
                'sequenceNo': sequence,
                'planConfirmed': true,
                'offers': sequence == 1
                    ? [
                        {
                          'trackId': 'ivan',
                          'questId': 'Q_IVAN_ROAD_EASY_1',
                          'status': 'COMPLETED',
                          'rewardAmount': 10,
                        },
                      ]
                    : [],
                'replays': [
                  {
                    'trackId': 'squirrel',
                    'questId': 'Q_SQUIRREL_QUALITY_SIMPLE',
                    'status': 'COMPLETED',
                    'rewardAmount': 10,
                  },
                  {
                    'trackId': 'ivan',
                    'questId': 'Q_IVAN_ROAD_EASY_1',
                    'status': 'COMPLETED',
                    'rewardAmount': 10,
                  },
                ],
              };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    Future<void> showDay() async {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(sequence),
          theme: AppTheme.light,
          home: QuestMapScreen(apiClient: api, enableAmbientSceneMotion: false),
        ),
      );
      await tester.pumpAndSettle();
    }

    await showDay();
    expect(
      find.byKey(const ValueKey('daily-stone-platform')),
      findsNWidgets(7),
    );
    expect(
      find.byKey(const ValueKey('daily-badge-completed')),
      findsNWidgets(2),
    );
    await openNode(tester, 'squirrel');
    expect(
      find.text('Ты уже помог, спасибо! Все задания этого персонажа пройдены.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    sequence = 2;
    await showDay();
    expect(find.byKey(const ValueKey('daily-badge-completed')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('quest-map-hero-ivan')),
        matching: find.byKey(const ValueKey('daily-badge-completed')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('quest-map-hero-squirrel')),
        matching: find.byKey(const ValueKey('daily-badge-completed')),
      ),
      findsOneWidget,
    );
    await openNode(tester, 'ivan');
    expect(find.text(noDailyQuestMessage), findsOneWidget);
  });

  testWidgets(
    'only offered characters have a 1 or static clock, with no status captions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const QuestMapScreen(
            dailyPreview: day,
            enableAmbientSceneMotion: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('daily-badge-available')),
        findsNWidgets(2),
      );
      expect(
        find.byKey(const ValueKey('daily-badge-inProgress')),
        findsOneWidget,
      );
      for (final node in questMapNodes.where((node) => node.isRewardedQuest)) {
        final target = find.byKey(Key('quest-map-hero-${node.id}'));
        final platform = find.descendant(
          of: target,
          matching: find.byKey(const ValueKey('daily-stone-platform')),
        );
        expect(tester.getCenter(platform), tester.getCenter(target));
        expect(
          (tester.widget<Image>(platform).image as AssetImage).assetName,
          'assets/map/checkpoint_road.webp',
        );
      }
      await openNode(tester, 'turnip');
      expect(find.text(noDailyQuestMessage), findsOneWidget);
      expect(find.text('Начать'), findsNothing);
    },
  );

  testWidgets(
    'resume at energy zero never asks to refill or spends again on map',
    (tester) async {
      final calls = <String>[];
      final api = ApiClient(
        baseUrl: 'http://test',
        authStorage: FakeAuthStorage(initialToken: 'tok'),
        httpClient: MockClient((request) async {
          calls.add(request.url.path);
          final Object body = switch (request.url.path) {
            '/economy/state' => {
              'activeDay': {'id': 'day-1'},
              'pet': {'pet_name': 'Мурзик', 'energy_level': 0},
              'quests': [
                {
                  'id': 'Q_IVAN_ROAD_EASY_1',
                  'assignment_status': 'IN_PROGRESS',
                },
              ],
            },
            '/quests/day' => {
              'periodId': 'day-1',
              'sequenceNo': 1,
              'planConfirmed': true,
              'offers': [
                {
                  'trackId': 'ivan',
                  'questId': 'Q_IVAN_ROAD_EASY_1',
                  'status': 'IN_PROGRESS',
                  'rewardAmount': 10,
                },
              ],
            },
            '/quests/Q_IVAN_ROAD_EASY_1/start' => {
              'resumed': true,
              'assignmentId': 'assignment-1',
            },
            _ => {},
          };
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: QuestMapScreen(apiClient: api, enableAmbientSceneMotion: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Игровой день 1'),
        findsOneWidget,
        reason: calls.join(', '),
      );
      await openNode(tester, 'ivan');
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();
      expect(find.byType(IvanGameScreen), findsOneWidget);
      expect(
        tester
            .widget<IvanGameScreen>(find.byType(IvanGameScreen))
            .enableSequentialNext,
        isFalse,
      );
      expect(find.byKey(const Key('energy-blocked-dialog')), findsNothing);
      expect(calls.where((path) => path == '/pet'), isEmpty);
      expect(calls.where((path) => path.endsWith('/start')).length, 1);
    },
  );

  testWidgets(
    'first request explains rules; dismissing them does not start the game',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const QuestMapScreen(
            dailyPreview: day,
            enableAmbientSceneMotion: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openNode(tester, 'squirrel');
      await tester.tap(find.text('Начать'));
      await tester.pumpAndSettle();
      expect(find.text('Как помочь: Внимательный покупатель'), findsOneWidget);
      expect(find.text('Чтение правил не тратит энергию.'), findsNothing);
      await tester.ensureVisible(find.text('Позже'));
      await tester.tap(find.text('Позже'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('daily-badge-available')),
        findsNWidgets(2),
      );
      expect(find.text('Как помочь: Внимательный покупатель'), findsNothing);
    },
  );

  for (final width in [320.0, 412.0, 800.0]) {
    testWidgets('daily markers and inactive message fit $width at 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const QuestMapScreen(
            dailyPreview: day,
            enableAmbientSceneMotion: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openNode(tester, 'turnip');
      expect(tester.takeException(), isNull);
    });
  }
}
