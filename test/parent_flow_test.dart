import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/main.dart';
import 'package:andromeda_app/parent/parent_home_screen.dart';
import 'package:andromeda_app/settings/child_settings_screen.dart';

import 'support/fake_auth_storage.dart';

http.Response _json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _childId = '18b24a3b-4078-4df9-a084-133b56a676fd';

Map<String, dynamic> _overview() => {
  'pet': {
    'pet_name': 'Пушок',
    'evolution_stage': 1,
    'energy_level': 80,
    'joy_level': 60,
    'health_level': 55,
  },
  'wallets': {'SPENDABLE': 12, 'SAVINGS': 5, 'FROZEN': 0},
  'goal': {'name': 'Блюдце', 'target_amount': 80, 'saved_amount': 5},
  'activeDay': null,
  'activeEvent': {'title': 'Питомец заболел', 'amount_due': 7},
  'completedQuests': [
    {'title': 'Осторожно, мелкий шрифт', 'needed_hints': true},
    {'title': 'Ярмарка тугриков', 'needed_hints': false},
  ],
  'days': {'finished': 3, 'followed': 2},
  'recentDays': <Object>[],
  'recentActivity': [
    {
      'event_type': 'SAVINGS_DEPOSIT',
      'wallet_kind': 'SPENDABLE',
      'delta_amount': -5,
      'occurred_at': '2026-09-25T18:40:00Z',
    },
    {
      'event_type': 'SAVINGS_DEPOSIT',
      'wallet_kind': 'SAVINGS',
      'delta_amount': 5,
      'occurred_at': '2026-09-25T18:40:00Z',
    },
    {
      'event_type': 'QUEST_REWARD',
      'wallet_kind': 'SPENDABLE',
      'delta_amount': 15,
      'occurred_at': '2026-09-25T18:30:00Z',
    },
  ],
};

Future<void> _pumpParent(
  WidgetTester tester, {
  required FakeAuthStorage storage,
  required MockClient client,
}) async {
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: ParentHomeScreen(
        onBack: () {},
        authStorage: storage,
        apiClient: ApiClient(
          httpClient: client,
          authStorage: storage,
          baseUrl: 'http://test',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the role gate offers both child and parent', (tester) async {
    await tester.pumpWidget(const GroshikApp());
    await tester.pumpAndSettle();

    expect(find.text('Я ребёнок'), findsOneWidget);
    expect(find.text('Я родитель'), findsOneWidget);
  });

  testWidgets('a new parent creates a cabinet and gets a one-time code', (
    tester,
  ) async {
    final storage = FakeAuthStorage();
    final client = MockClient((request) async {
      return switch (request.url.path) {
        '/auth/parent/register' => _json({
          'userId': 'p1',
          'token': 'parent-token',
        }, 201),
        '/parent/children' => _json(<Object>[]),
        '/auth/parent/invites' => _json({
          'inviteCode': '6B9BEBHW',
          'expiresAt': '2026-10-02T12:00:00Z',
        }, 201),
        _ => _json({'error': 'unexpected'}, 500),
      };
    });

    await _pumpParent(tester, storage: storage, client: client);
    expect(find.text('Создать кабинет'), findsOneWidget);

    await tester.tap(find.text('Создать кабинет'));
    await tester.pumpAndSettle();
    expect(await storage.readToken(), 'parent-token');
    expect(find.text('Пригласите ребёнка'), findsOneWidget);

    await tester.tap(find.text('Получить код'));
    await tester.pumpAndSettle();
    // Split for reading aloud; the child's field accepts it either way.
    expect(find.text('6B9B-EBHW'), findsOneWidget);
  });

  testWidgets('a linked child is shown with real data only', (tester) async {
    final storage = FakeAuthStorage(initialToken: 'parent-token');
    final client = MockClient((request) async {
      return switch (request.url.path) {
        '/parent/children' => _json([
          {'childUserId': _childId, 'petName': 'Пушок'},
        ]),
        '/parent/children/$_childId/overview' => _json(_overview()),
        _ => _json({'error': 'unexpected'}, 500),
      };
    });

    await _pumpParent(tester, storage: storage, client: client);

    expect(find.text('Пушок: прогресс'), findsOneWidget);
    expect(find.text('2 из 3'), findsOneWidget);
    expect(find.text('Копит на «Блюдце»'), findsOneWidget);
    // Attention cards come only from real signals: the unpaid bill and the
    // quest finished with hints — not the one solved first time.
    expect(find.text('Питомец заболел'), findsOneWidget);
    expect(find.text('Тема «Осторожно, мелкий шрифт»'), findsOneWidget);
    expect(find.text('Тема «Ярмарка тугриков»'), findsNothing);
    // A transfer is booked on both wallets but appears once in the feed.
    expect(find.text('Отложено в копилку'), findsOneWidget);
    expect(find.text('Награда за задание'), findsOneWidget);
    // Nothing from the old prototype survives.
    expect(find.text('ПРОТОТИП'), findsNothing);
    expect(find.textContaining('Грошик'), findsNothing);
  });

  testWidgets('a revoked parent session starts over instead of looping', (
    tester,
  ) async {
    final storage = FakeAuthStorage(initialToken: 'dead-token');
    final client = MockClient(
      (request) async => _json({'error': 'unauthorized'}, 401),
    );

    await _pumpParent(tester, storage: storage, client: client);

    expect(await storage.readToken(), isNull);
    expect(find.text('Создать кабинет'), findsOneWidget);
  });

  testWidgets('the child links a parent from settings with the spoken code', (
    tester,
  ) async {
    String? sentCode;
    final client = MockClient((request) async {
      if (request.url.path == '/child/parent-link') {
        return _json({'linked': false, 'linkedAt': null});
      }
      sentCode =
          (jsonDecode(request.body) as Map<String, dynamic>)['inviteCode']
              as String?;
      return _json({'linkId': 'l1', 'parentUserId': 'p1'});
    });

    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ChildSettingsScreen(
          apiClient: ApiClient(
            httpClient: client,
            authStorage: FakeAuthStorage(initialToken: 'child-token'),
            baseUrl: 'http://test',
          ),
          initialSettings: const ChildSettingsSnapshot(),
          onSettingsChanged: (_) {},
          onSwitchAudience: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('parent-invite-code-field')),
      '6b9b-ebhw',
    );
    await tester.tap(find.text('Подключить родителя'));
    await tester.pumpAndSettle();

    // The hyphen a parent reads aloud is not part of the code.
    expect(sentCode, '6b9bebhw');
    expect(
      find.text('Родитель подключён и видит твой прогресс.'),
      findsOneWidget,
    );
  });
}
