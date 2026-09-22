import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/onboarding/onboarding_data.dart';
import 'package:andromeda_app/onboarding/onboarding_step1_screen.dart';

void main() {
  testWidgets('onboarding step 1 requires a name and a fur color before continuing', (tester) async {
    OnboardingData? submitted;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingStep1Screen(onNext: (data) => submitted = data),
      ),
    );

    // "Далее" is disabled until both a name and a fur color are chosen.
    var button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Грошик');
    await tester.tap(find.text('серый'));
    await tester.pump();

    button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(submitted?.petName, 'Грошик');
    expect(submitted?.furColorId, 'FUR_GRAY');
  });
}
