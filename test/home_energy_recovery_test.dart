import 'dart:convert';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_auth_storage.dart';

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _pet({required String mode, required int energy}) => {
  'id': 'pet-1',
  'pet_name': 'Финни',
  'fur_option_id': 'FUR_GRAY',
  'energy_level': energy,
  'joy_level': 80,
  'health_level': 100,
  'evolution_stage': 1,
  'mode': mode,
  'server_time': '2026-09-29T12:00:00.000Z',
  'energy_recovery': {
    'max_energy': 100,
    'activity_cost': 20,
    'energy_per_tick': 20,
    'tick_seconds': 180,
    'next_tick_at': energy < 100 ? '2026-09-29T12:03:00.000Z' : null,
    'full_at': energy < 100 ? '2026-09-29T12:15:00.000Z' : null,
  },
};

Map<String, dynamic> _economy(Map<String, dynamic> pet) => {
  'pet': pet,
  'wallets': {'SPENDABLE': 50, 'SAVINGS': 10, 'FROZEN': 0},
  'activeDay': null,
  'activeGoal': null,
  'activeEvent': null,
  'parentTasks': <Object>[],
  'inventory': <Object>[],
  'recentDays': <Object>[],
};

Widget _screen(http.Client client) => MaterialApp(
  home: Scaffold(
    body: HomeScreen(
      apiClient: ApiClient(
        httpClient: client,
        authStorage: FakeAuthStorage(initialToken: 'token'),
        baseUrl: 'http://test',
      ),
      onChooseGoal: () {},
      onOpenShop: () {},
    ),
  ),
);

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(screen);
  await tester.pump(const Duration(milliseconds: 150));
}

void main() {
  testWidgets('shows server-owned recovery countdown', (tester) async {
    final client = MockClient(
      (_) async => _json(_economy(_pet(mode: 'STANDARD', energy: 0))),
    );

    await _pump(tester, _screen(client));

    expect(find.byKey(const Key('pet-energy-recovery')), findsOneWidget);
    expect(find.textContaining('Питомец отдыхает'), findsOneWidget);
    expect(find.byKey(const Key('demo-recover-energy')), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('demo recovery refreshes the current home model', (tester) async {
    var recoveryCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/pet/recover-energy') {
        recoveryCalls++;
        return _json(_pet(mode: 'DEMO', energy: 100));
      }
      return _json(_economy(_pet(mode: 'DEMO', energy: 0)));
    });

    await _pump(tester, _screen(client));
    await tester.tap(find.byKey(const Key('demo-recover-energy')));
    await tester.pump(const Duration(milliseconds: 150));

    expect(recoveryCalls, 1);
    expect(find.byKey(const Key('pet-energy-recovery')), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
