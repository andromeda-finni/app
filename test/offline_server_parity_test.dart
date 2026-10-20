// Checks that the offline preview matches what the real server computes.
//
// Runs only against a live local backend:
//   OFFLINE_PARITY_URL=http://127.0.0.1:3000 flutter test test/offline_server_parity_test.dart
// It registers a fresh test child on that server.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:andromeda_app/core/offline/offline_economy.dart';

final _baseUrl = Platform.environment['OFFLINE_PARITY_URL'];

void main() {
  test(
    'offline preview equals the server after every core and stage-2 action',
    () async {
      final client = http.Client();
      addTearDown(client.close);
      String? token;

      Future<Map<String, dynamic>> call(
        String method,
        String path, [
        Map<String, dynamic>? body,
      ]) async {
        final request = http.Request(method, Uri.parse('$_baseUrl$path'))
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode(body ?? {});
        if (token != null) request.headers['Authorization'] = 'Bearer $token';
        final response = await http.Response.fromStream(
          await client.send(request),
        );
        expect(
          response.statusCode,
          lessThan(300),
          reason: '$method $path → ${response.body}',
        );
        final decoded = response.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : {'value': decoded};
      }

      final registration = await call('POST', '/auth/child/register', {
        'difficulty': 'ADVANCED',
      });
      token = registration['token'] as String;
      await call('POST', '/pet', {
        'petName': 'Сверка',
        'furOptionId': 'FUR_GRAY',
      });

      var ids = 0;
      final economy = OfflineEconomy(
        nextId: (kind) => 'offline-$kind-${++ids}',
      );
      var preview = await call('GET', '/economy/state');
      final realIds = <String, String>{};

      String real(String path) => path.replaceAllMapped(
        RegExp('offline-[a-z]+-[0-9]+'),
        (match) => realIds[match.group(0)] ?? match.group(0)!,
      );

      /// Performs [path] both ways and compares the observable state.
      Future<void> step(
        String method,
        String path, [
        Map<String, dynamic>? body,
        bool serverRollsEvent = false,
      ]) async {
        final outcome = economy.apply(method, path, body, preview);
        final response = await call(method, real(path), body);
        final created = outcome.createdId;
        if (created != null) {
          final serverId =
              response['periodId'] ??
              response['policyId'] ??
              response['inventoryItemId'] ??
              response['id'];
          if (serverId is String) realIds[created] = serverId;
        }
        preview = outcome.state ?? preview;
        final server = await call('GET', '/economy/state');
        final label = '$method $path';

        expect(preview['wallets'], server['wallets'], reason: label);
        for (final field in ['energy_level', 'joy_level', 'health_level']) {
          expect(
            preview['pet'][field],
            server['pet'][field],
            reason: '$label pet.$field',
          );
        }
        final day = preview['activeDay'] as Map?;
        final serverDay = server['activeDay'] as Map?;
        // Random pet events are rolled only by the server; a bill raises
        // the day's required spending, which the device cannot foresee.
        final rolled = serverRollsEvent && server['activeEvent'] != null;
        expect(day == null, serverDay == null, reason: '$label activeDay');
        if (day != null && serverDay != null) {
          for (final field in [
            'sequence_no',
            'budget_plan_status',
            'available_amount',
            'need_amount',
            'want_amount',
            'savings_amount',
            'required_need_amount',
            'actual_need_amount',
            'remaining_reserve',
          ]) {
            if (rolled && field.contains('need') ||
                rolled && field == 'remaining_reserve') {
              continue;
            }
            expect(day[field], serverDay[field], reason: '$label day.$field');
          }
        }
        final chest = preview['activeFrostChest'] as Map?;
        final serverChest = server['activeFrostChest'] as Map?;
        expect(chest == null, serverChest == null, reason: '$label chest');
        if (chest != null && serverChest != null) {
          for (final field in [
            'principal_amount',
            'bonus_amount',
            'days_remaining',
            'matured',
          ]) {
            expect(chest[field], serverChest[field], reason: '$label $field');
          }
        }
        final policy = preview['activeInsurance'] as Map?;
        final serverPolicy = server['activeInsurance'] as Map?;
        expect(policy == null, serverPolicy == null, reason: '$label policy');
        if (policy != null && serverPolicy != null) {
          expect(
            policy['coverage_sequence_no'],
            serverPolicy['coverage_sequence_no'],
            reason: label,
          );
        }
        final goal = preview['activeGoal'] as Map?;
        final serverGoal = server['activeGoal'] as Map?;
        for (final field in [
          'target_item_id',
          'target_amount',
          'status',
          'saved_amount',
          'remaining_amount',
        ]) {
          expect(
            goal?[field],
            serverGoal?[field],
            reason: '$label goal.$field',
          );
        }
        if (day == null &&
            serverDay == null &&
            (server['recentDays'] as List).isNotEmpty) {
          final recent = (preview['recentDays'] as List).first as Map;
          final serverRecent = (server['recentDays'] as List).first as Map;
          expect(
            recent['plan_followed'],
            serverRecent['plan_followed'],
            reason: '$label plan_followed',
          );
          expect(
            recent['feedback_text'],
            serverRecent['feedback_text'],
            reason: '$label feedback',
          );
        }
        // From here on, compare against the server's ids and timestamps.
        preview = {
          ...server,
          if (preview['_offline_stroke'] != null)
            '_offline_stroke': preview['_offline_stroke'],
          'activeDay': serverDay == null
              ? null
              : {
                  ...serverDay,
                  '_offline_actual_want': day?['_offline_actual_want'] ?? 0,
                  '_offline_net_savings': day?['_offline_net_savings'] ?? 0,
                },
        };
      }

      // The dream is chosen from the remembered catalog.
      await step('POST', '/goals', {'targetItemId': 'saucer'});
      // Day 1 — the first day has no random event on the server.
      await step('POST', '/periods');
      final dayId = (preview['activeDay'] as Map)['id'] as String;
      await step('PUT', '/periods/$dayId/budget-plan', {
        'needAmount': 15,
        'wantAmount': 5,
        'savingsAmount': 10,
      });
      await step('POST', '/periods/$dayId/budget-plan/confirm');
      await step('POST', '/purchases', {
        'itemId': 'FOOD_APPLE',
        'quantity': 2,
        'idempotencyKey': 'parity-apple',
      });
      await step('POST', '/pet/stroke');
      await step('POST', '/pet/stroke');
      await step('POST', '/insurance/purchase', {
        'idempotencyKey': 'parity-insurance',
      });
      await step('POST', '/savings/deposit', {
        'amount': 3,
        'idempotencyKey': 'parity-deposit',
      });
      await step('POST', '/savings/withdraw', {
        'amount': 2,
        'idempotencyKey': 'parity-withdraw',
      });
      await step('POST', '/periods/$dayId/close');

      // Day 2 — Morozko chest, and the random event if the server rolls one.
      await step('POST', '/periods', null, true);
      final day2 = (preview['activeDay'] as Map)['id'] as String;
      final event = preview['activeEvent'] as Map?;
      if (event != null) {
        await step('POST', '/pet-events/${event['id']}/resolve');
      }
      final required =
          (preview['activeDay'] as Map)['required_need_amount'] as int;
      final need = (preview['activeDay'] as Map)['remaining_reserve'] as int;
      await step('PUT', '/periods/$day2/budget-plan', {
        'needAmount': required,
        'wantAmount': 30 - required,
        'savingsAmount': 0,
      });
      await step('POST', '/periods/$day2/budget-plan/confirm');
      for (var bought = 0; bought < need; bought += 5) {
        await step('POST', '/purchases', {
          'itemId': 'FOOD_APPLE',
          'idempotencyKey': 'parity-day2-apple-$bought',
        });
      }
      await step('POST', '/frost-chests', {
        'principalAmount': 10,
        'idempotencyKey': 'parity-frost-1',
      });
      final early = (preview['activeFrostChest'] as Map)['id'] as String;
      await step('POST', '/frost-chests/$early/withdraw-early');
      await step('POST', '/frost-chests', {
        'principalAmount': 10,
        'idempotencyKey': 'parity-frost-2',
      });
      await step('POST', '/periods/$day2/close');
    },
    skip: _baseUrl == null
        ? 'Set OFFLINE_PARITY_URL to a running local backend'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a quest finished offline pays what the server pays',
    () async {
      final client = http.Client();
      addTearDown(client.close);

      Future<Map<String, dynamic>> call(
        String? token,
        String method,
        String path, [
        Map<String, dynamic>? body,
      ]) async {
        final request = http.Request(method, Uri.parse('$_baseUrl$path'))
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode(body ?? {});
        if (token != null) request.headers['Authorization'] = 'Bearer $token';
        final response = await http.Response.fromStream(
          await client.send(request),
        );
        expect(
          response.statusCode,
          lessThan(300),
          reason: '$method $path → ${response.body}',
        );
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      // The server picks three of seven characters a day; the turnip quest
      // has a known correct answer, so play a child whose day offers it.
      String? token;
      Map<String, dynamic>? daily;
      for (var attempt = 0; attempt < 6 && token == null; attempt++) {
        final child =
            (await call(null, 'POST', '/auth/child/register', {
                  'difficulty': 'ADVANCED',
                }))['token']
                as String;
        await call(child, 'POST', '/pet', {
          'petName': 'Сверка',
          'furOptionId': 'FUR_GRAY',
        });
        await call(child, 'POST', '/goals', {'targetItemId': 'saucer'});
        final day = await call(child, 'POST', '/periods');
        await call(child, 'PUT', '/periods/${day['periodId']}/budget-plan', {
          'needAmount': 10,
          'wantAmount': 20,
          'savingsAmount': 0,
        });
        await call(
          child,
          'POST',
          '/periods/${day['periodId']}/budget-plan/confirm',
        );
        final offers = await call(child, 'GET', '/quests/day');
        final hasTurnip = (offers['offers'] as List).any(
          (offer) => (offer as Map)['questId'] == 'Q_TURNIP_HARVEST',
        );
        if (hasTurnip) {
          token = child;
          daily = offers;
        }
      }
      if (token == null) {
        markTestSkipped('The turnip quest was not offered to any test child');
        return;
      }

      var ids = 0;
      final economy = OfflineEconomy(
        nextId: (kind) => 'offline-$kind-${++ids}',
      );
      final before = await call(token, 'GET', '/economy/state');
      final started = economy.apply(
        'POST',
        '/quests/Q_TURNIP_HARVEST/start',
        null,
        before,
        cachedDaily: daily,
      );
      final answer = {
        'stepNo': 1,
        'selectedOptionCode': 'grandmother,granddaughter,zhuchka,cat,mouse',
      };
      final finished = economy.apply(
        'POST',
        '/assignments/${started.createdId}/answer',
        answer,
        started.state,
        cachedDaily: started.daily,
      );

      final serverStart = await call(
        token,
        'POST',
        '/quests/Q_TURNIP_HARVEST/start',
      );
      final serverAnswer = await call(
        token,
        'POST',
        '/assignments/${serverStart['assignmentId']}/answer',
        answer,
      );
      final after = await call(token, 'GET', '/economy/state');
      final afterDay = await call(token, 'GET', '/quests/day');

      expect(serverAnswer['questCompleted'], isTrue);
      expect(finished.response['rewardAmount'], serverAnswer['rewardAmount']);
      expect(finished.response['balanceAfter'], serverAnswer['balanceAfter']);
      expect(finished.state!['wallets'], after['wallets']);
      expect(
        finished.state!['pet']['energy_level'],
        after['pet']['energy_level'],
      );
      String statusOf(Map<String, dynamic> day) =>
          ((day['offers'] as List).firstWhere(
                (offer) => (offer as Map)['questId'] == 'Q_TURNIP_HARVEST',
              ) as Map)['status']
              as String;
      expect(statusOf(finished.daily!), statusOf(afterDay));
    },
    skip: _baseUrl == null
        ? 'Set OFFLINE_PARITY_URL to a running local backend'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
