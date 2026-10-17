import 'dart:math';

import '../../core/api_client.dart';
import 'catch_food_models.dart';

class CatchFoodStart {
  const CatchFoodStart({
    required this.info,
    required this.id,
    required this.energyCost,
    this.finishedResult,
  });

  final CatchFoodInfo info;
  final String id;
  final int energyCost;
  final CatchFoodResult? finishedResult;
}

class CatchFoodService {
  const CatchFoodService(this.api);
  final ApiClient api;

  Future<CatchFoodInfo> load() async =>
      CatchFoodInfo.fromJson(await api.get('/minigames/catch-food'));

  Future<CatchFoodStart> start(String sessionId) async {
    final json = await api.post(
      '/minigames/catch-food/start',
      body: {'sessionId': sessionId},
    );
    final session = json['session'] as Map<String, dynamic>;
    if (session['id'] != sessionId) {
      throw const FormatException('Unexpected catch-food session');
    }
    return CatchFoodStart(
      info: CatchFoodInfo.fromJson(json),
      id: sessionId,
      energyCost: session['energyCost'] as int,
      finishedResult: session['finished'] == true
          ? CatchFoodResult.fromJson(session)
          : null,
    );
  }

  Future<int> finish(String id, CatchFoodResult result) async {
    final json = await api.post(
      '/minigames/catch-food/$id/finish',
      body: result.toJson(),
    );
    return json['bestScore'] as int;
  }

  /// Kept for a failed request's retry. A new key is created only when the
  /// player explicitly starts another paid attempt.
  static String newSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
