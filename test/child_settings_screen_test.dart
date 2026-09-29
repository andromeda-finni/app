import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/settings/child_settings_screen.dart';

import 'support/fake_auth_storage.dart';

void main() {
  testWidgets('changing difficulty persists the complete settings contract', (
    tester,
  ) async {
    Map<String, dynamic>? savedBody;
    final client = MockClient((request) async {
      if (request.url.path == '/child/parent-link') {
        return _json({'linked': false, 'linkedAt': null});
      }
      if (request.url.path == '/child/settings' && request.method == 'GET') {
        return _json({
          'difficulty': 'SIMPLE',
          'soundEnabled': true,
          'musicEnabled': false,
          'largeTextEnabled': true,
        });
      }
      if (request.url.path == '/child/settings' && request.method == 'PUT') {
        savedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _json(savedBody!);
      }
      return _json({'error': 'unexpected'}, 500);
    });

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

    await tester.tap(find.text('Самостоятельно'));
    await tester.pumpAndSettle();

    expect(savedBody, {
      'difficulty': 'ADVANCED',
      'soundEnabled': true,
      'musicEnabled': false,
      'largeTextEnabled': true,
    });
  });
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
