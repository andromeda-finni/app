import 'dart:convert';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/core/pet_assets.dart';
import 'package:andromeda_app/home/home_screen.dart';
import 'package:andromeda_app/home/models/pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_auth_storage.dart';
import 'support/pump_catch_food.dart';

const _periodId = '11111111-1111-1111-1111-111111111111';
const _activePetEvent = {
  'id': 'event-1',
  'event_definition_id': 'POOR_PAW',
  'amount_due': 10,
  'triggered_at': '2026-09-27T10:00:00.000Z',
};

http.Response _json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _pet({
  int satiety = 60,
  int joy = 55,
  int health = 100,
  int stage = 1,
}) => {
  'pet_name': 'Грошик',
  'fur_option_id': 'FUR_GRAY',
  'accessory_option_id': null,
  'energy_level': satiety,
  'joy_level': joy,
  'health_level': health,
  'evolution_stage': stage,
};

Map<String, dynamic> _draftDay({
  int available = 30,
  int need = 0,
  int want = 0,
  int savings = 0,
  int remainingReserve = 10,
  String status = 'DRAFT',
}) => {
  'id': _periodId,
  'sequence_no': 3,
  'required_need_amount': 10,
  'remaining_reserve': remainingReserve,
  'budget_plan_id': 'plan-1',
  'budget_plan_status': status,
  'available_amount': available,
  'need_amount': need,
  'want_amount': want,
  'savings_amount': savings,
};

Map<String, dynamic> _economy({
  Map<String, dynamic>? pet,
  Object? activeDay,
  Map<String, dynamic>? activeEvent,
  List<Map<String, dynamic>> parentTasks = const [],
}) => {
  'pet': pet ?? _pet(),
  'wallets': {'SPENDABLE': 42, 'SAVINGS': 18},
  'activeDay': activeDay,
  'activeGoal': {
    'name': 'Воздушный змей',
    'target_amount': 100,
    'saved_amount': 18,
  },
  'activeEvent': activeEvent,
  'parentTasks': parentTasks,
  'inventory': [
    {
      'id': 'inventory-boots',
      'item_id': 'boots',
      'name': 'Сапоги-скороходы',
      'durability_current': 80,
      'durability_max': 100,
    },
  ],
};

Widget _screen({
  required Future<http.Response> Function(http.Request request) handler,
  double textScale = 1,
  VoidCallback? onOpenInsurance,
  bool isActive = true,
  int refreshSignal = 0,
  bool focusPlan = false,
}) {
  final client = MockClient(handler);
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: HomeScreen(
          apiClient: ApiClient(
            httpClient: client,
            authStorage: FakeAuthStorage(initialToken: 'tok'),
            baseUrl: 'http://test',
          ),
          onOpenInsurance: onOpenInsurance,
          isActive: isActive,
          refreshSignal: refreshSignal,
          focusPlan: focusPlan,
        ),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(430, 1800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(screen);
  await tester.pumpAndSettle();
}

void main() {
  group('pet mood', () {
    test('rejects a pet response without the chosen name', () {
      expect(
        () => Pet.fromJson({..._pet(), 'pet_name': ''}),
        throwsFormatException,
      );
    });

    test('an unpaid illness makes the pet visibly sad', () {
      expect(moodFor(satiety: 80, joy: 80, health: 55), PetMood.sad);
      expect(moodFor(satiety: 80, joy: 80, health: 100), PetMood.happy);
    });

    test('bad news wins over good news', () {
      expect(moodFor(satiety: 100, joy: 10, health: 100), PetMood.sad);
    });

    test('each mood resolves to art for every fur colour', () {
      for (final fur in ['FUR_GRAY', 'FUR_ORANGE', 'FUR_WHITE']) {
        for (final mood in PetMood.values) {
          expect(
            catAsset(furOptionId: fur, mood: mood),
            matches(
              RegExp(r'^assets/Cat/Red_collar/\w+/(striped|red|white)\.webp$'),
            ),
          );
        }
      }
    });
  });

  testWidgets('home contains the day flow, dream and repeatable mini-game', (
    tester,
  ) async {
    await _pump(
      tester,
      _screen(handler: (_) async => _json(_economy(activeDay: null))),
    );

    expect(find.text('Грошик'), findsOneWidget);
    expect(find.text('Моя мечта'), findsOneWidget);
    expect(find.text('Воздушный змей'), findsOneWidget);
    // The side panel's buttons are pictures; their names stay available
    // as tooltips and to screen readers.
    for (final label in [
      'Забота о питомце',
      'Распределить заработанные монеты',
      'Начать новый игровой день',
      'Прогресс и подсказка',
    ]) {
      expect(find.byTooltip(label), findsOneWidget);
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    expect(find.text('Завершить день'), findsOneWidget);
    expect(find.text('Сытость'), findsNothing);
    expect(find.byKey(const Key('home-pet-scene')), findsOneWidget);
    expect(find.byKey(const Key('open-catch-food')), findsOneWidget);
  });

  testWidgets(
    'catch food opens without a game day and refreshes home on return',
    (tester) async {
      var homeLoads = 0;
      var starts = 0;
      await _pump(
        tester,
        _screen(
          handler: (request) async {
            if (request.url.path == '/minigames/catch-food') {
              return _json({
                'config': {
                  'energyCost': 20,
                  'durationMs': 60000,
                  'maxMisses': 3,
                  'travelMs': 2400,
                  'firstSpawnMs': 600,
                  'initialSpawnMs': 1300,
                  'minimumSpawnMs': 700,
                  'catchWindowMs': 180,
                  'spoiledFoodPercent': 20,
                },
                'pet': _pet(),
                'bestScore': 0,
              });
            }
            if (request.url.path.endsWith('/start')) starts++;
            homeLoads++;
            return _json(_economy(activeDay: null));
          },
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('open-catch-food')));
      await tester.tap(find.byKey(const Key('open-catch-food')));
      await pumpCatchFoodReady(tester);
      expect(find.byKey(const Key('catch-food-start')), findsOneWidget);
      expect(starts, 0);
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(homeLoads, 2);
      expect(find.byKey(const Key('home-pet-scene')), findsOneWidget);
    },
  );

  testWidgets('stroking the pet raises joy from the server answer', (
    tester,
  ) async {
    var strokes = 0;
    await _pump(
      tester,
      _screen(
        handler: (request) async {
          if (request.url.path == '/pet/stroke') {
            strokes++;
            return _json({..._pet(satiety: 30, joy: 41), 'joy_gain': 0.5});
          }
          return _json(
            _economy(pet: _pet(satiety: 30, joy: 40), activeDay: _draftDay()),
          );
        },
      ),
    );

    await tester.tap(find.byKey(const Key('open-pet-care')));
    await tester.pumpAndSettle();
    expect(find.text('40'), findsOneWidget);

    await tester.tap(find.byKey(const Key('meadow-pet-scene')));
    await tester.pumpAndSettle();

    expect(strokes, 1);
    expect(find.text('41'), findsOneWidget);
    expect(find.text('40'), findsNothing);
  });

  testWidgets('pet care is a separate screen and returns home', (tester) async {
    await _pump(
      tester,
      _screen(
        handler: (_) async => _json(
          _economy(pet: _pet(satiety: 30, joy: 40), activeDay: _draftDay()),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-pet-care')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meadow-pet-scene')), findsOneWidget);
    expect(find.text('Сытость'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('Радость'), findsOneWidget);
    expect(find.text('Коллекция'), findsOneWidget);
    // Owned artifacts are shown with their wear, not as "not yet received".
    expect(
      find.bySemanticsLabel(RegExp('Сапоги-скороходы, прочность 80 из 100')),
      findsOneWidget,
    );
    expect(find.text('Стол подорожника'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pet-care-back')));
    await tester.pumpAndSettle();
    expect(find.text('Моя мечта'), findsOneWidget);
  });

  testWidgets(
    'active event opens on home entry and can be reopened from its banner',
    (tester) async {
      Future<http.Response> handler(http.Request request) async =>
          _json(_economy(activeDay: _draftDay(), activeEvent: _activePetEvent));
      await _pump(tester, _screen(handler: handler));

      expect(find.byKey(const Key('pet-event-banner')), findsOneWidget);
      expect(find.text('Ой! Грошик уколол лапку!'), findsOneWidget);
      expect(find.byKey(const Key('pet-event-resolve')), findsOneWidget);

      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pet-event-resolve')), findsNothing);

      await tester.pumpWidget(_screen(handler: handler, refreshSignal: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pet-event-resolve')), findsNothing);
      await tester.tap(find.byKey(const Key('pet-event-banner')));
      await tester.pumpAndSettle();

      expect(find.text('Ой! Грошик уколол лапку!'), findsOneWidget);
      expect(find.byKey(const Key('pet-event-resolve')), findsOneWidget);
    },
  );

  testWidgets('an event waits until the home tab becomes active', (
    tester,
  ) async {
    Future<http.Response> handler(http.Request request) async =>
        _json(_economy(activeDay: _draftDay(), activeEvent: _activePetEvent));
    await _pump(tester, _screen(handler: handler, isActive: false));
    expect(find.byKey(const Key('pet-event-resolve')), findsNothing);

    await tester.pumpWidget(_screen(handler: handler));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pet-event-resolve')), findsOneWidget);
  });

  testWidgets('an event is presented before a requested budget plan', (
    tester,
  ) async {
    await _pump(
      tester,
      _screen(
        focusPlan: true,
        handler: (_) async => _json(
          _economy(activeDay: _draftDay(), activeEvent: _activePetEvent),
        ),
      ),
    );
    expect(find.byKey(const Key('pet-event-resolve')), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pet-event-resolve')), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('resolving an automatic event refreshes the home', (
    tester,
  ) async {
    var resolved = false;
    var resolutions = 0;
    await _pump(
      tester,
      _screen(
        handler: (request) async {
          if (request.url.path == '/pet-events/event-1/resolve' &&
              request.method == 'POST') {
            resolved = true;
            resolutions++;
            return _json({'spendableBalance': 32, 'healthLevel': 100});
          }
          return _json({
            ..._economy(
              pet: _pet(health: resolved ? 100 : 55),
              activeDay: _draftDay(),
              activeEvent: resolved ? null : _activePetEvent,
            ),
            'wallets': {'SPENDABLE': resolved ? 32 : 42, 'SAVINGS': 18},
          });
        },
      ),
    );
    await tester.tap(find.byKey(const Key('pet-event-resolve')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    expect(resolutions, 1);
    expect(find.byKey(const Key('pet-event-resolve')), findsNothing);
    expect(find.byKey(const Key('pet-event-banner')), findsNothing);
    expect(find.text('32'), findsOneWidget);
  });

  testWidgets('plantain table keeps insurance navigation', (tester) async {
    var insuranceOpened = false;
    await _pump(
      tester,
      _screen(
        handler: (_) async => _json(_economy(activeDay: _draftDay())),
        onOpenInsurance: () => insuranceOpened = true,
      ),
    );

    await tester.tap(find.byKey(const Key('open-pet-care')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Стол подорожника'));

    expect(insuranceOpened, isTrue);
  });

  testWidgets('parent task remains actionable on the new home', (tester) async {
    String? submittedPath;
    final state = _economy(
      activeDay: _draftDay(),
      parentTasks: const [
        {
          'id': '33333333-3333-3333-3333-333333333333',
          'title': 'Полить цветы',
          'reward_amount': 7,
          'status': 'AVAILABLE',
        },
      ],
    );
    await _pump(
      tester,
      _screen(
        handler: (request) async {
          if (request.method == 'POST') submittedPath = request.url.path;
          return _json(state);
        },
      ),
    );

    expect(find.text('Полить цветы'), findsOneWidget);
    await tester.tap(find.text('Я сделал(а)'));
    await tester.pumpAndSettle();

    expect(
      submittedPath,
      '/child/tasks/33333333-3333-3333-3333-333333333333/submit',
    );
  });

  testWidgets('closing a covered day opens the summary mirror', (tester) async {
    final state = _economy(
      activeDay: _draftDay(status: 'CONFIRMED', remainingReserve: 0),
    );
    await _pump(
      tester,
      _screen(
        handler: (request) async {
          if (request.url.path.endsWith('/close')) {
            return _json({
              'periodId': _periodId,
              'sequenceNo': 3,
              'earnedAmount': 30,
              'plan': {'need': 10, 'want': 10, 'savings': 10},
              'actual': {'need': 10, 'want': 0, 'savings': 10},
              'needCovered': true,
              'planFollowed': true,
              'feedback': 'Грошик доволен.',
              'recommendations': <String>[],
            });
          }
          return _json(state);
        },
      ),
    );

    await tester.tap(find.byKey(const Key('finish-day')));
    await tester.pumpAndSettle();

    expect(find.text('Свет мой, зеркальце, скажи…'), findsOneWidget);
  });

  testWidgets('renaming persists through PUT /pet', (tester) async {
    Map<String, dynamic>? putBody;
    await _pump(
      tester,
      _screen(
        handler: (request) async {
          if (request.url.path == '/pet' && request.method == 'PUT') {
            putBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _json({'ok': true});
          }
          return _json(_economy(activeDay: null));
        },
      ),
    );

    await tester.tap(find.byKey(const Key('edit-pet-name')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pet-name-field')), 'Финни');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(putBody?['petName'], 'Финни');
    expect(putBody?['furOptionId'], 'FUR_GRAY');
    expect(find.text('Финни'), findsOneWidget);
  });

  testWidgets('draft plan enforces the protected food reserve', (tester) async {
    String? planBody;
    await _pump(
      tester,
      _screen(
        handler: (request) async {
          if (request.url.path.endsWith('/budget-plan')) {
            planBody = request.body;
          }
          return _json(_economy(activeDay: _draftDay(available: 3)));
        },
      ),
    );

    await tester.tap(find.byKey(const Key('open-budget-plan')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Добавить монету: Обязательное'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Добавить монету: Необязательное'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Добавить монету: В копилку'));
    await tester.pump();

    // The protected reserve remains enforced even in the compact editor.
    expect(find.textContaining('хотя бы 10'), findsOneWidget);
    expect(planBody, isNull);
  });

  testWidgets('starts a day through POST /periods', (tester) async {
    var started = false;
    await _pump(
      tester,
      _screen(
        handler: (request) async {
          if (request.url.path == '/periods' && request.method == 'POST') {
            started = true;
            return _json({'id': _periodId});
          }
          return _json(_economy(activeDay: null));
        },
      ),
    );

    await tester.tap(find.byKey(const Key('open-budget-plan')));
    await tester.pumpAndSettle();
    expect(started, isTrue);
    expect(find.byKey(const Key('pet-event-resolve')), findsNothing);
  });

  testWidgets('starting a day presents the server event without another roll', (
    tester,
  ) async {
    var started = false;
    final posts = <String>[];
    await _pump(
      tester,
      _screen(
        handler: (request) async {
          if (request.method == 'POST') posts.add(request.url.path);
          if (request.url.path == '/periods' && request.method == 'POST') {
            started = true;
            return _json({'periodId': _periodId, 'eventTriggered': true}, 201);
          }
          return _json(
            _economy(
              activeDay: started ? _draftDay() : null,
              activeEvent: started ? _activePetEvent : null,
            ),
          );
        },
      ),
    );
    await tester.tap(find.byKey(const Key('open-budget-plan')));
    await tester.pumpAndSettle();

    expect(posts, ['/periods']);
    expect(find.text('Ой! Грошик уколол лапку!'), findsOneWidget);
    expect(find.byKey(const Key('pet-event-resolve')), findsOneWidget);
  });

  testWidgets('360dp with enlarged text has no overflow', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    await _pump(
      tester,
      _screen(
        textScale: 1.35,
        handler: (_) async => _json(_economy(activeDay: _draftDay())),
      ),
      size: const Size(360, 1400),
    );
    await tester.tap(find.byKey(const Key('open-pet-care')));
    await tester.pumpAndSettle();

    expect(
      errors.where((error) => error.exceptionAsString().contains('overflowed')),
      isEmpty,
    );
  });

  testWidgets('failed load offers a retry', (tester) async {
    var attempts = 0;
    await _pump(
      tester,
      _screen(
        handler: (_) async {
          attempts++;
          return attempts == 1
              ? _json({'error': 'boom'}, 500)
              : _json(_economy(activeDay: null));
        },
      ),
    );

    expect(find.text('Повторить'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Грошик'), findsOneWidget);
  });
}
