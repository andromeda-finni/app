import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/pet/pet_energy_status.dart';

void main() {
  test('uses the server clock for recovery countdowns', () {
    final status = PetEnergyStatus.fromJson({
      'energy_level': 0,
      'mode': 'STANDARD',
      'server_time': '2026-09-29T12:00:00.000Z',
      'energy_recovery': {
        'max_energy': 100,
        'activity_cost': 20,
        'energy_per_tick': 20,
        'tick_seconds': 180,
        'next_tick_at': '2026-09-29T12:03:00.000Z',
        'full_at': '2026-09-29T12:15:00.000Z',
      },
    }, receivedAt: DateTime.parse('2026-09-29T11:58:00.000Z'));

    expect(status.blocksActivities, isTrue);
    expect(status.isDemo, isFalse);
    expect(
      status.untilNextTick(DateTime.parse('2026-09-29T11:59:00.000Z')),
      const Duration(minutes: 2),
    );
    expect(
      status.untilFull(DateTime.parse('2026-09-29T11:59:00.000Z')),
      const Duration(minutes: 14),
    );
  });

  test('formats a bounded MM:SS countdown', () {
    expect(
      formatEnergyCountdown(const Duration(minutes: 2, seconds: 9)),
      '02:09',
    );
    expect(formatEnergyCountdown(const Duration(seconds: -1)), '00:00');
  });
}
