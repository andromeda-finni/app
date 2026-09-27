import '../core/api_client.dart';
import '../events/pet_event_models.dart';

class PetEventRollResult {
  const PetEventRollResult({this.event, this.insuranceNotice});

  final PetEventOccurrence? event;
  final String? insuranceNotice;
}

class PetEventService {
  PetEventService(this._api);

  final ApiClient _api;

  Future<PetEventOccurrence?> getActive() async {
    final json = await _api.getOptional('/pet-events/active');
    return json == null ? null : PetEventOccurrence.fromJson(json);
  }

  /// Returns either a billable occurrence or the outcome of one-day cover.
  Future<PetEventRollResult> roll() async {
    final result = await _api.post('/pet-events/roll');
    final notice = result['insuranceNotice'] as String?;
    if (result['triggered'] != true) {
      return PetEventRollResult(insuranceNotice: notice);
    }
    final active = await getActive();
    if (active == null) {
      throw const FormatException('triggered pet event is not active');
    }
    return PetEventRollResult(event: active, insuranceNotice: notice);
  }

  Future<PetEventResolution> resolve(String occurrenceId) async {
    final json = await _api.post('/pet-events/$occurrenceId/resolve');
    return PetEventResolution.fromJson(json);
  }
}
