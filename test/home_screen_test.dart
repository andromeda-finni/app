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

const _periodId = '11111111-1111-1111-1111-111111111111';

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
  String status = 'DRAFT',
}) => {
  'id': _periodId,
  'sequence_no': 3,
  'required_need_amount': 10,
  'remaining_reserve': 10,
  'budget_plan_id': 'plan-1',
  'budget_plan_status': status,
  'available_amount': available,
  'need_amount': need,
  'want_amount': want,
  'savings_amount': savings,
};

Map<String, dynamic> _economy({Map<String, dynamic>? pet, Object? activeDay}) =>
    {
      'pet': pet ?? _pet(),
      'wallets': {'SPENDABLE': 42, 'SAVINGS': 18},
      'activeDay': activeDay,
      'activeGoal': {
        'name': 'Воздушный змей',
        'target_amount': 100,
        'saved_amount': 18,
      },
      'activeEvent': null,
      'inventory': [
        {'name': 'Гусли-самогуды'},
      ],
    };

Widget _screen({
  required Future<http.Response> Function(http.Request request) handler,
  double textScale = 1,
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
              RegExp(r'^assets/Cat/Red_collar/\w+/(striped|red|white)\.png$'),
            ),
          );
        }
      }
    });
  });

  testWidgets('home contains only the day flow and dream', (tester) async {
    await _pump(
      tester,
      _screen(handler: (_) async => _json(_economy(activeDay: null))),
    );

    expect(find.text('Грошик'), findsOneWidget);
    expect(find.text('Моя мечта'), findsOneWidget);
    expect(find.text('Воздушный змей'), findsOneWidget);
    expect(find.text('Начать новый игровой день'), findsOneWidget);
    expect(find.text('Завершить день'), findsOneWidget);
    expect(find.text('Прогресс и подсказка'), findsOneWidget);
    expect(find.text('Сытость'), findsNothing);
    expect(find.byKey(const Key('home-pet-scene')), findsOneWidget);
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
    expect(find.text('30%'), findsOneWidget);
    expect(find.text('Радость'), findsOneWidget);
    expect(find.text('Коллекция'), findsOneWidget);
    expect(find.text('Гусли-самогуды'), findsOneWidget);
    expect(find.text('Стол подорожника'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pet-care-back')));
    await tester.pumpAndSettle();
    expect(find.text('Моя мечта'), findsOneWidget);
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
