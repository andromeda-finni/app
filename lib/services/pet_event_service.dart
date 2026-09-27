import '../core/api_client.dart';
import '../events/pet_event_models.dart';

class PetEventService {
  PetEventService(this._api);

  final ApiClient _api;

  Future<PetEventOccurrence?> getActive() async {
    final json = await _api.getOptional('/pet-events/active');
    return json == null ? null : PetEventOccurrence.fromJson(json);
  }

  /// Returns the active occurrence only when this roll created a new event.
  Future<PetEventOccurrence?> roll() async {
    final result = await _api.post('/pet-events/roll');
    if (result['triggered'] != true) return null;
    final active = await getActive();
    if (active == null) {
      throw const FormatException('triggered pet event is not active');
    }
    return active;
  }

  Future<PetEventResolution> resolve(String occurrenceId) async {
    final json = await _api.post('/pet-events/$occurrenceId/resolve');
    return PetEventResolution.fromJson(json);
  }
}
