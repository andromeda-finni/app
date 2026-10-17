import 'dart:convert';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/dictionary/dictionary_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  DeviceDictionaryStorage profile(
    String? petId, {
    String host = 'http://test',
  }) => DeviceDictionaryStorage(
    apiClient: ApiClient(
      baseUrl: host,
      authStorage: FakeAuthStorage(initialToken: 'child-token'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/pet');
        return http.Response(jsonEncode({'id': petId}), 200);
      }),
    ),
  );

  test('notes persist for one profile and never leak into another', () async {
    await profile('pet-a').write('dictionary', 'budget');
    expect(await profile('pet-a').read('dictionary'), 'budget');
    expect(await profile('pet-b').read('dictionary'), isNull);
    expect(
      await profile('pet-a', host: 'http://another-backend').read('dictionary'),
      isNull,
    );
  });

  test(
    'a missing profile cannot read or write shared anonymous notes',
    () async {
      final anonymous = profile(null);
      await expectLater(anonymous.read('dictionary'), throwsFormatException);
      await expectLater(
        anonymous.write('dictionary', 'budget'),
        throwsFormatException,
      );
    },
  );
}
