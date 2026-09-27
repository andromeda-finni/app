import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/events/pet_event_models.dart';

void main() {
  test(
    'approved random-event catalog contains exactly the six agreed events',
    () {
      expect(petEventCatalog.keys.toSet(), {
        'POOR_PAW',
        'SICK',
        'HUNGRY',
        'COLD_NIGHT',
        'ROOF_LEAK',
        'BEAVER_DAM',
      });
      expect(petEventCatalog.map((id, event) => MapEntry(id, event.amount)), {
        'POOR_PAW': 10,
        'SICK': 15,
        'HUNGRY': 10,
        'COLD_NIGHT': 8,
        'ROOF_LEAK': 14,
        'BEAVER_DAM': 7,
      });
      expect(
        petEventCatalog.values.every(
          (event) => event.amount >= 2 && event.amount <= 20,
        ),
        isTrue,
      );
    },
  );

  test('an occurrence rejects stale prices and unknown definitions', () {
    Map<String, dynamic> occurrence(String definitionId, int amount) => {
      'id': '22222222-2222-2222-2222-222222222222',
      'event_definition_id': definitionId,
      'amount_due': amount,
    };

    expect(
      () => PetEventOccurrence.fromJson(occurrence('POOR_PAW', 100)),
      throwsFormatException,
    );
    expect(
      () => PetEventOccurrence.fromJson(occurrence('NOT_APPROVED', 10)),
      throwsFormatException,
    );
  });
}
