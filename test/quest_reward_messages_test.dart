import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/minigames/quest_reward_messages.dart';

void main() {
  test(
    'a recoverable quest answer shows the authored child-facing feedback',
    () {
      expect(
        questRecoveryMessage({
          'outcome': 'RECOVERABLE_ERROR',
          'feedback': 'Посчитай стоимость выбранных покупок ещё раз.',
        }),
        'Посчитай стоимость выбранных покупок ещё раз.',
      );
    },
  );

  test('an economy refusal explains the action needed instead of blaming the network', () {
    expect(
      questProblemMessage(
        ApiException(409, 'active_day_with_confirmed_plan_required'),
      ),
      contains('Начни день'),
    );
  });
}
