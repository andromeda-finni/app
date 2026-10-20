import '../core/api_client.dart';
import '../events/fox/fox_event_models.dart';
import '../events/fox/fox_event_wallet.dart';

class FoxEventService implements FoxEventWallet, FoxEventProgress {
  FoxEventService(this._api);

  final ApiClient _api;
  int _balance = 0;
  int gameDay = 0;

  @override
  int get balance => _balance;

  Future<FoxEventLaunch?> visit() async {
    final json = await _api.post('/fox-events/visit');
    _balance = (json['balance'] as num?)?.toInt() ?? 0;
    gameDay = (json['gameDay'] as num?)?.toInt() ?? 0;
    final raw = json['session'];
    if (raw is! Map) return null;
    final session = FoxEventSession.fromJson(Map<String, dynamic>.from(raw));
    return FoxEventLaunch(
      session: session,
      isReturnVisit: raw['isReturnVisit'] == true,
    );
  }

  @override
  Future<void> advance(FoxEventSession session, {String? choiceId}) async {
    try {
      final json = await _api.post(
        '/fox-events/advance',
        body: {
          'sessionId': session.id,
          'nodeId': session.currentNodeId,
          'choiceId': ?choiceId,
        },
      );
      final next = FoxEventSession.fromJson(
        Map<String, dynamic>.from(json['session'] as Map),
      );
      _balance = (json['balance'] as num).toInt();
      session
        ..currentNodeId = next.currentNodeId
        ..status = next.status
        ..dueGameDay = next.dueGameDay;
      session.appliedEffectKeys
        ..clear()
        ..addAll(next.appliedEffectKeys);
      session.choiceHistory
        ..clear()
        ..addAll(next.choiceHistory);
    } on ApiException catch (error) {
      if (error.code == 'insufficient_funds' ||
          error.code == 'insufficient_free_funds') {
        throw const FoxInsufficientFundsException();
      }
      rethrow;
    }
  }

  @override
  Future<FoxWalletChange> applyDelta({
    required int delta,
    required String effectKey,
  }) => throw UnsupportedError('Use the validated story transition.');
}
