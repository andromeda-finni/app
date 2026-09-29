import '../core/api_client.dart';

class InsuranceService {
  InsuranceService(this._api);

  final ApiClient _api;
  bool _running = false;

  Future<bool> purchaseInsurance() async {
    if (_running) return false;
    _running = true;
    try {
      await _api.post(
        '/insurance/purchase',
        body: {
          'idempotencyKey':
              'insurance-${DateTime.now().microsecondsSinceEpoch}',
        },
      );
      return true;
    } finally {
      _running = false;
    }
  }
}
