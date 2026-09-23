import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/onboarding/onboarding_data.dart';
import 'package:andromeda_app/onboarding/onboarding_step1_screen.dart';
import 'package:andromeda_app/onboarding/onboarding_step2_screen.dart';
import 'package:andromeda_app/onboarding/onboarding_step3_screen.dart';
import 'package:andromeda_app/onboarding/onboarding_step4_screen.dart';

/// Pumps [child] at a given logical screen size and text-scale factor and
/// asserts nothing threw (in particular no RenderFlex overflow, which
/// throws during layout/paint rather than failing an `expect`).
Future<void> _pumpAtSize(
  WidgetTester tester,
  Widget child, {
  required Size logicalSize,
  double textScale = 1.0,
}) async {
  final dpr = tester.view.devicePixelRatio;
  tester.view.physicalSize = Size(
    logicalSize.width * dpr,
    logicalSize.height * dpr,
  );
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: widget!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
    'onboarding step 1 requires a name and a fur color before continuing',
    (tester) async {
      OnboardingData? submitted;

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingStep1Screen(onNext: (data) async => submitted = data),
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
      await tester.pumpAndSettle();

      expect(submitted?.petName, 'Грошик');
      expect(submitted?.furColorId, 'FUR_GRAY');
    },
  );

  group('no overflow on small screens or large text scale', () {
    final screens = <String, Widget Function()>{
      'step 1': () => OnboardingStep1Screen(onNext: (_) async {}),
      'step 2': () => OnboardingStep2Screen(onBack: () {}, onNext: () {}),
      'step 3': () => OnboardingStep3Screen(
        initialData: OnboardingData(),
        onBack: () {},
        onNext: (_) {},
      ),
      'step 4': () => OnboardingStep4Screen(onBack: () {}, onFinish: () {}),
    };

    for (final entry in screens.entries) {
      testWidgets('${entry.key} at 320x568', (tester) async {
        await _pumpAtSize(
          tester,
          entry.value(),
          logicalSize: const Size(320, 568),
        );
      });

      testWidgets('${entry.key} at 412x915 with 1.3x text scale', (
        tester,
      ) async {
        await _pumpAtSize(
          tester,
          entry.value(),
          logicalSize: const Size(412, 915),
          textScale: 1.3,
        );
      });

      testWidgets('${entry.key} at 320x568 with 1.3x text scale (worst case)', (
        tester,
      ) async {
        await _pumpAtSize(
          tester,
          entry.value(),
          logicalSize: const Size(320, 568),
          textScale: 1.3,
        );
      });
    }
  });
}
