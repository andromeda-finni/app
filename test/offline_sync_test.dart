import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/core/offline/offline_storage.dart';
import 'package:andromeda_app/core/offline/offline_sync.dart';

import 'support/fake_auth_storage.dart';

/// A tiny fake server: answers the economy read model and records every
/// mutation it receives. [online] switches the "network".
class _Server {
  bool online = true;

  /// The backend is up but its database is not (`docker compose down`):
  /// every request fails with 500 and /health with 503.
  bool databaseDown = false;
  final requests = <String>[];
  final bodies = <String, Map<String, dynamic>>{};
  final refuse = <String, String>{};

  Map<String, dynamic> state = {
    'rules': {'dailyIncome': 30, 'foodReserve': 10, 'daysPerWeek': 7},
    'pet': {'pet_name': 'Мурзик', 'energy_level': 50, 'joy_level': 50},
    'wallets': {'SPENDABLE': 0, 'SAVINGS': 0, 'FROZEN': 0},
    'activeDay': null,
    'activeEvent': null,
    'activeGoal': {'id': 'g1', 'target_amount': 80, 'saved_amount': 0},
    'shopItems': [
      {
        'id': 'apple',
        'kind': 'NEED',
        'name': 'Яблоко',
        'price': 5,
        'energy_delta': 10,
        'joy_delta': 0,
      },
    ],
    'quests': <Object>[],
    'recentDays': <Object>[],
  };

  Map<String, dynamic> day = {
    'periodId': null,
    'planConfirmed': false,
    'offers': <Object>[],
  };

  /// What the server says about a replayed quest answer.
  bool confirmsQuest = true;

  late final client = MockClient((request) async {
    if (!online) throw const SocketException('offline');
    if (databaseDown) {
      return request.url.path == '/health'
          ? _json({'ok': false, 'error': 'database_unreachable'}, 503)
          : _json({'error': 'internal_server_error'}, 500);
    }
    final key = '${request.method} ${request.url.path}';
    if (request.url.path != '/health' && request.method != 'GET') {
      requests.add(key);
      if (request.body.isNotEmpty) {
        bodies[key] = jsonDecode(request.body) as Map<String, dynamic>;
      }
    }
    final refusal = refuse[key];
    if (refusal != null) return _json({'error': refusal}, 409);
    return switch (key) {
      'GET /economy/state' => _json(state),
      'GET /quests/day' => _json(day),
      'POST /assignments/server-assignment-7/answer' => _json({
        'outcome': confirmsQuest ? 'SUCCESS' : 'RECOVERABLE_ERROR',
        'questCompleted': confirmsQuest,
      }),
      'GET /health' => _json({'ok': true}),
      'POST /periods' => _json({'periodId': 'server-day-1'}, 201),
      'POST /frost-chests' => _json({'id': 'server-chest-9'}, 201),
      'POST /quests/Q1/start' => _json({
        'assignmentId': 'server-assignment-7',
        'completed': false,
      }),
      _ => _json({'ok': true}),
    };
  });
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late _Server server;
  late OfflineSync sync;
  late ApiClient api;
  late DateTime now;
  late MemoryOfflineStorage storage;

  ApiClient clientFor(String token) => ApiClient(
    httpClient: server.client,
    authStorage: FakeAuthStorage(initialToken: token),
    baseUrl: 'http://test',
    offline: sync,
  );

  setUp(() {
    server = _Server();
    now = DateTime(2026, 10, 18, 12);
    storage = MemoryOfflineStorage();
    sync = OfflineSync(storage: storage, autoRetry: false, clock: () => now);
    api = clientFor('child-token');
  });

  /// Moves past the short window in which requests skip the network.
  void later() => now = now.add(const Duration(seconds: 10));

  test('the last state stays readable without a connection', () async {
    await api.get('/economy/state');
    server.online = false;

    final offline = await api.get('/economy/state');
    expect(offline['pet']['pet_name'], 'Мурзик');
    expect(sync.isOffline, isTrue);

    later();
    server.online = true;
    await api.get('/economy/state');
    expect(sync.isOffline, isFalse);
  });

  test('the cache survives an app restart', () async {
    await api.get('/economy/state');
    server.online = false;

    final restarted = OfflineSync(storage: storage, autoRetry: false);
    final client = ApiClient(
      httpClient: server.client,
      authStorage: FakeAuthStorage(initialToken: 'child-token'),
      baseUrl: 'http://test',
      offline: restarted,
    );
    final state = await client.get('/economy/state');
    expect(state['pet']['pet_name'], 'Мурзик');
  });

  test(
    'a day played offline reaches the server in order with real ids',
    () async {
      await api.get('/economy/state');
      server.online = false;

      final started = await api.post('/periods');
      final dayId = started['periodId'] as String;
      expect(dayId, startsWith('offline-'));
      await api.put(
        '/periods/$dayId/budget-plan',
        body: {'needAmount': 10, 'wantAmount': 10, 'savingsAmount': 10},
      );
      await api.post('/periods/$dayId/budget-plan/confirm');
      final bought = await api.post(
        '/purchases',
        body: {'itemId': 'apple', 'idempotencyKey': 'purchase-key-1'},
      );
      expect(bought['balanceAfter'], 15);

      final preview = await api.get('/economy/state');
      expect(preview['wallets'], {'SPENDABLE': 15, 'SAVINGS': 10, 'FROZEN': 0});
      expect(sync.pendingCount, 4);
      expect(server.requests, isEmpty);

      later();
      server.online = true;
      final revision = sync.syncRevision;
      await api.get('/economy/state');

      expect(server.requests, [
        'POST /periods',
        'PUT /periods/server-day-1/budget-plan',
        'POST /periods/server-day-1/budget-plan/confirm',
        'POST /purchases',
      ]);
      // The original key travels with the replay, so a purchase is never
      // charged twice even if the first attempt reached the server.
      expect(
        server.bodies['POST /purchases']?['idempotencyKey'],
        'purchase-key-1',
      );
      expect(sync.pendingCount, 0);
      expect(sync.syncRevision, greaterThan(revision));
    },
  );

  test('a server whose database is down counts as offline', () async {
    await api.get('/economy/state');
    server.databaseDown = true;

    final cached = await api.get('/economy/state');
    expect(cached['pet']['pet_name'], 'Мурзик');
    expect(sync.isOffline, isTrue);
    await api.post('/pet/stroke');
    expect(sync.pendingCount, 1);

    // A long outage must not use up the action's retry budget.
    for (var attempt = 0; attempt < 6; attempt++) {
      later();
      await api.get('/economy/state');
    }
    expect(sync.pendingCount, 1);
    expect(sync.takeNotices(), isEmpty);

    later();
    server.databaseDown = false;
    await api.get('/economy/state');
    expect(server.requests, contains('POST /pet/stroke'));
    expect(sync.pendingCount, 0);
    expect(sync.isOffline, isFalse);
  });

  test(
    'a refused action is dropped with its dependants and explained',
    () async {
      await api.get('/economy/state');
      server.online = false;
      final started = await api.post('/periods');
      await api.put(
        '/periods/${started['periodId']}/budget-plan',
        body: {'needAmount': 10, 'wantAmount': 20, 'savingsAmount': 0},
      );

      later();
      server.online = true;
      server.refuse['POST /periods'] = 'financial_goal_required';
      await api.get('/economy/state');

      expect(server.requests, ['POST /periods']);
      expect(sync.pendingCount, 0);
      expect(sync.takeNotices().single, contains('Начало дня'));
    },
  );

  /// Today's offers loaded while online, with a confirmed plan.
  Future<void> playOnlineDay() async {
    server.state['activeDay'] = {
      'id': 'd1',
      'sequence_no': 2,
      'budget_plan_status': 'CONFIRMED',
      'required_need_amount': 10,
      'remaining_reserve': 0,
    };
    server.state['wallets'] = {'SPENDABLE': 5, 'SAVINGS': 0, 'FROZEN': 0};
    server.day = {
      'periodId': 'd1',
      'planConfirmed': true,
      'offers': [
        {
          'trackId': 'turnip',
          'questId': 'Q1',
          'assignmentId': null,
          'status': 'AVAILABLE',
          'rewardAmount': 10,
          'stepCount': 1,
        },
      ],
    };
    await api.get('/economy/state');
    await api.get('/quests/day');
  }

  test('a quest finished offline pays coins and syncs with real ids', () async {
    await playOnlineDay();
    server.online = false;

    final start = await api.post('/quests/Q1/start');
    final assignment = start['assignmentId'] as String;
    final result = await api.post(
      '/assignments/$assignment/answer',
      body: {'stepNo': 1, 'selectedOptionCode': 'ok'},
    );
    expect(result['questCompleted'], isTrue);
    expect(result['rewardAmount'], 10);
    final preview = await api.get('/economy/state');
    expect(preview['wallets']['SPENDABLE'], 15);
    expect(preview['pet']['energy_level'], 30);

    later();
    server.online = true;
    await api.get('/economy/state');
    expect(server.requests, [
      'POST /quests/Q1/start',
      'POST /assignments/server-assignment-7/answer',
    ]);
    expect(server.bodies['POST /assignments/server-assignment-7/answer'], {
      'stepNo': 1,
      'selectedOptionCode': 'ok',
    });
    expect(sync.takeNotices(), isEmpty);
  });

  test(
    'a day opened offline shows an empty list instead of an error',
    () async {
      await playOnlineDay();
      // Yesterday is closed and a new day starts without a connection.
      server.state['activeDay'] = null;
      server.state['activeGoal'] = {'id': 'g1', 'target_amount': 80};
      await api.get('/economy/state');
      server.online = false;
      final started = await api.post('/periods');

      final day = await api.get('/quests/day');
      expect(day['periodId'], started['periodId']);
      expect(day['offers'], isEmpty);
      await expectLater(
        api.post('/quests/Q1/start'),
        throwsA(
          isA<ApiException>().having((e) => e.isNetworkError, 'net', true),
        ),
      );
    },
  );

  test('coins the server does not confirm are explained', () async {
    await playOnlineDay();
    server.online = false;
    final start = await api.post('/quests/Q1/start');
    await api.post(
      '/assignments/${start['assignmentId']}/answer',
      body: {'stepNo': 1, 'selectedOptionCode': 'wrong'},
    );

    later();
    server.online = true;
    server.confirmsQuest = false;
    await api.get('/economy/state');
    expect(sync.takeNotices().single, contains('не засчитал'));
  });

  test('a chest opened offline is withdrawn by its real id', () async {
    server.state['rules'] = {
      ...server.state['rules'] as Map<String, dynamic>,
      'frostMinimum': 10,
      'frostMaximum': 50,
      'frostStep': 10,
      'frostDays': 5,
      'frostBonusPercent': 10,
    };
    server.state['wallets'] = {'SPENDABLE': 40, 'SAVINGS': 0, 'FROZEN': 0};
    server.state['activeDay'] = {
      'id': 'd1',
      'sequence_no': 2,
      'budget_plan_status': 'CONFIRMED',
      'required_need_amount': 10,
      'remaining_reserve': 0,
    };
    await api.get('/economy/state');
    server.online = false;

    final chest = await api.post(
      '/frost-chests',
      body: {'principalAmount': 20, 'idempotencyKey': 'frost-key-1'},
    );
    await api.post('/frost-chests/${chest['id']}/withdraw-early');
    final preview = await api.get('/economy/state');
    expect(preview['wallets'], {'SPENDABLE': 40, 'SAVINGS': 0, 'FROZEN': 0});

    later();
    server.online = true;
    await api.get('/economy/state');
    expect(server.requests, [
      'POST /frost-chests',
      'POST /frost-chests/server-chest-9/withdraw-early',
    ]);
  });

  test('actions that need the server still say so offline', () async {
    await api.get('/economy/state');
    server.online = false;
    await expectLater(
      api.post('/child/parent-link/redeem', body: {'code': 'ABC123'}),
      throwsA(isA<ApiException>().having((e) => e.isNetworkError, 'net', true)),
    );
    expect(sync.pendingCount, 0);
  });

  test(
    'another child on the device never sees the first one\'s data',
    () async {
      await api.get('/economy/state');
      server.online = false;
      await api.post('/periods');

      final other = clientFor('other-child-token');
      await expectLater(
        other.get('/economy/state'),
        throwsA(isA<ApiException>()),
      );
      expect(sync.pendingCount, 0);
    },
  );
}
