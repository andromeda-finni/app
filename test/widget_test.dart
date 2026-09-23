import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/onboarding/onboarding_data.dart';
import 'package:andromeda_app/onboarding/onboarding_step1_screen.dart';
import 'package:andromeda_app/onboarding/onboarding_step2_screen.dart';
import 'package:andromeda_app/onboarding/onboarding_step3_screen.dart';
import 'package:andromeda_app/onboarding/onboarding_step4_screen.dart';

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

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
      await _tapVisible(tester, find.text('серый'));

      button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);

      await _tapVisible(tester, find.byType(ElevatedButton));

      expect(submitted?.petName, 'Грошик');
      expect(submitted?.furColorId, 'FUR_GRAY');
    },
  );

  testWidgets(
    'step 3 requires moving a coin and allocating all coins before continuing',
    (tester) async {
      OnboardingData? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingStep3Screen(
            initialData: OnboardingData(),
            onBack: (_) {},
            onNext: (data) => submitted = data,
          ),
        ),
      );

      ElevatedButton nextButton() =>
          tester.widget<ElevatedButton>(find.byType(ElevatedButton).last);

      expect(nextButton().onPressed, isNull);
      expect(find.text('Осталось распределить: 10'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(3));

      final addCoin = find.bySemanticsLabel(
        'Добавить монету в категорию «Конфеты»',
      );
      await tester.ensureVisible(addCoin);
      for (var i = 0; i < kTutorialBudgetTotal - 1; i++) {
        await tester.tap(addCoin);
        await tester.pump();
      }
      expect(nextButton().onPressed, isNull);

      await tester.tap(addCoin);
      await tester.pump();
      expect(nextButton().onPressed, isNotNull);

      final removeCandy = find.bySemanticsLabel(
        'Убрать монету из категории «Конфеты»',
      );
      await _tapVisible(tester, removeCandy);
      expect(nextButton().onPressed, isNull);

      final addSavings = find.bySemanticsLabel(
        'Добавить монету в категорию «Копилка»',
      );
      await _tapVisible(tester, addSavings);
      expect(nextButton().onPressed, isNotNull);

      await _tapVisible(tester, find.text('Готово'));
      expect(submitted?.allocated, kTutorialBudgetTotal);
      expect(submitted?.budgetPracticed, isTrue);
    },
  );

  group('no overflow on small screens or large text scale', () {
    final screens = <String, Widget Function()>{
      'step 1': () => OnboardingStep1Screen(onNext: (_) async {}),
      'step 2': () => OnboardingStep2Screen(onBack: () {}, onNext: () {}),
      'step 3': () => OnboardingStep3Screen(
        initialData: OnboardingData(),
        onBack: (_) {},
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

    testWidgets('step 3 remains usable at 320x568 with 2x text scale', (
      tester,
    ) async {
      await _pumpAtSize(
        tester,
        OnboardingStep3Screen(
          initialData: OnboardingData(),
          onBack: (_) {},
          onNext: (_) {},
        ),
        logicalSize: const Size(320, 568),
        textScale: 2,
      );
    });
  });
}
