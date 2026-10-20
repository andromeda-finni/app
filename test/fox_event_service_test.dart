import 'dart:convert';
import 'dart:io';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/events/fox/fox_event_content.dart';
import 'package:andromeda_app/events/fox/fox_event_dialog_controller.dart';
import 'package:andromeda_app/events/fox/fox_event_models.dart';
import 'package:andromeda_app/services/fox_event_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_auth_storage.dart';

void main() {
  test('backend story rules match every authored choice and effect', () {
    final source = File('backend/src/modules/foxEvents/content.ts')
        .readAsStringSync();
    final rules = jsonDecode(
      source.substring(source.indexOf('{'), source.lastIndexOf('}') + 1),
    ) as Map;
    expect(rules.length, kFoxScripts.length);
    for (final script in kFoxScripts) {
      final rule = rules[script.id] as Map;
      expect(rule['ageGroup'], script.ageGroup.name);
      expect(rule['initialNodeId'], script.initialNodeId);
      final nodes = rule['nodes'] as Map;
      expect(nodes.length, script.nodes.length);
      for (final node in script.nodes.values) {
        final row = nodes[node.id] as Map;
        expect(row['terminal'], node.terminal);
        expect(row['waitUntilNextGameDay'], node.waitUntilNextGameDay);
        expect(row['coinDeltaOnEnter'], node.coinDeltaOnEnter);
        expect((row['choices'] as Map).length, node.choices.length);
        for (final choice in node.choices) {
          expect(row['choices'][choice.id], {
            'nextNodeId': choice.nextNodeId,
            'coinDelta': choice.coinDelta,
          });
        }
      }
    }
  });

  test(
    'real dialogue uses server balance and survives a failed response',
    () async {
      final state = {
        'id': '11111111-1111-4111-8111-111111111111',
        'scriptId': 'fox_younger_introduction',
        'currentNodeId': 'start',
        'status': 'active',
        'isReturnVisit': false,
        'appliedEffectKeys': <String>[],
        'choiceHistory': <String>[],
      };
      var fail = false;
      final requests = <Map<String, dynamic>>[];
      final api = ApiClient(
        authStorage: FakeAuthStorage(initialToken: 'test-token'),
        baseUrl: 'http://test',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/advance')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            requests.add(body);
            expect(body.containsKey('delta'), false);
            if (fail) return http.Response('{"error":"network_error"}', 503);
            if (body['choiceId'] == 'give_now') {
              state['currentNodeId'] = 'gave_without_questions';
            }
          }
          return http.Response(
            jsonEncode({
              'session': state,
              'gameDay': 3,
              'balance': state['currentNodeId'] == 'start' ? 42 : 32,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final service = FoxEventService(api);
      final launch = (await service.visit())!;
      final controller = FoxEventDialogController(
        script: foxScriptById(launch.session.scriptId),
        session: launch.session,
        wallet: service,
        mode: FoxRuntimeMode.normal,
        currentGameDay: service.gameDay,
        isReturnVisit: false,
      );
      addTearDown(controller.dispose);
      expect(service.balance, 42);
      fail = true;
      await controller.continueFromArrival();
      expect(controller.showArrival, true);
      expect(controller.errorMessage, isNotNull);
      fail = false;
      await controller.continueFromArrival();
      expect(controller.showArrival, false);
      final choice = controller.node.choices.firstWhere(
        (c) => c.id == 'give_now',
      );
      fail = true;
      await controller.select(choice);
      expect(controller.node.id, 'start');
      expect(service.balance, 42);
      fail = false;
      await controller.select(choice);
      expect(controller.node.id, 'gave_without_questions');
      expect(service.balance, 32);
      expect(requests.last['sessionId'], state['id']);
    },
  );
}
