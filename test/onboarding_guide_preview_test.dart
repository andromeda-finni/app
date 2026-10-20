import 'package:andromeda_app/onboarding/onboarding_data.dart';
import 'package:andromeda_app/onboarding/onboarding_guide_preview.dart';
import 'package:andromeda_app/onboarding/widgets/tutorial_budget_card.dart';
import 'package:andromeda_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  OnboardingData data() => OnboardingData(
    petName: 'Мурзик',
    furColorId: 'FUR_ORANGE',
    collarColorId: 'ACC_COLLAR_BLUE',
  );

  Future<void> open(WidgetTester tester, int page, {double scale = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: OnboardingGuidePreview(initialPage: page, initialData: data()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Day explanation uses the short heading', (tester) async {
    await open(tester, 5);
    expect(find.text('Один игровой день'), findsNothing);
    expect(find.text('Твой день'), findsOneWidget);
    expect(find.text('Составь план'), findsOneWidget);
  });

  testWidgets('Creation requires name, fur and collar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingGuidePreview()));
    final action = find.widgetWithText(ElevatedButton, 'Познакомиться');
    expect(tester.widget<ElevatedButton>(action).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Мурзик');
    await tester.pump();
    expect(tester.widget<ElevatedButton>(action).onPressed, isNull);
  });

  testWidgets('Name and appearance survive back navigation', (tester) async {
    await open(tester, 1);
    expect(find.textContaining('Это Мурзик.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName.endsWith(
              'kitten/blue/happy_red.webp',
            ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Мурзик',
    );
  });

  testWidgets('Glossary opens and dismisses without advancing', (tester) async {
    await open(tester, 3);
    await tester.ensureVisible(find.text('Открыть объяснение'));
    await tester.tap(find.text('Открыть объяснение'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Это план: сколько у тебя монет'),
      findsOneWidget,
    );
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(find.text('4 / 8'), findsOneWidget);
  });

  testWidgets('Ten coin practice cannot be skipped and preserves allocation', (
    tester,
  ) async {
    await open(tester, 4);
    final action = find.widgetWithText(
      ElevatedButton,
      'Сохранить учебный план',
    );
    expect(tester.widget<ElevatedButton>(action).onPressed, isNull);
    expect(find.text('Пропустить объяснения'), findsNothing);
    final card = tester.widget<TutorialBudgetCard>(
      find.byType(TutorialBudgetCard),
    );
    card.onChanged(
      card.data.copyWith(candyAmount: 2, otherAmount: 5, piggyAmount: 3),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(action).onPressed, isNotNull);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TutorialBudgetCard>(find.byType(TutorialBudgetCard))
          .data
          .allocated,
      10,
    );
  });

  for (final width in [320.0, 412.0, 800.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('All pages fit width $width text $scale', (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (var page = 0; page < 8; page++) {
          await tester.pumpWidget(const SizedBox.shrink());
          await open(tester, page, scale: scale);
          expect(tester.takeException(), isNull, reason: 'page $page');
          await tester.drag(
            find.byType(SingleChildScrollView).first,
            const Offset(0, -1800),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'scrolled page $page');
        }
      });
    }
  }
}
