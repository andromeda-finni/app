import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/day_summary/day_summary.dart';
import 'package:andromeda_app/day_summary/day_summary_mirror.dart';
import 'package:andromeda_app/day_summary/day_summary_screen.dart';
import 'package:andromeda_app/home/models/pet.dart';
import 'package:andromeda_app/theme/app_theme.dart';

const _summaryJson = <String, dynamic>{
  'periodId': '11111111-1111-1111-1111-111111111111',
  'sequenceNo': 4,
  'earnedAmount': 42,
  'plan': {'need': 10, 'want': 5, 'savings': 15},
  'actual': {'need': 0, 'want': 15, 'savings': 15},
  'needCovered': false,
  'planFollowed': false,
  'feedback': 'Сегодня план и действия немного разошлись. Мурзик ждёт заботы, а завтра попробуем ещё раз.',
  'recommendations': ['Сначала закрой обязательные траты на питомца.'],
};

void main() {
  test('parses the stable nested plan/fact contract', () {
    final summary = DaySummary.fromJson(_summaryJson);

    expect(summary.sequenceNo, 4);
    expect(summary.earnedAmount, 42);
    expect(summary.plan.need, 10);
    expect(summary.actual.want, 15);
    expect(summary.recommendations, hasLength(1));
  });

  testWidgets('shows one clouded mirror with plan, fact and advice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DaySummaryScreen(
          summary: DaySummary.fromJson(_summaryJson),
          onContinue: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Свет мой, зеркальце, скажи…'), findsOneWidget);
    expect(find.text('Заработано'), findsOneWidget);
    expect(find.text('Планировали'), findsOneWidget);
    expect(find.text('Получилось'), findsOneWidget);
    expect(find.text('Надо'), findsNWidgets(2));
    expect(find.text('Продолжить'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reflects the selected pet colour and current mood', (
    tester,
  ) async {
    const pet = Pet(
      name: 'Рыжик',
      furOptionId: 'FUR_ORANGE',
      accessoryOptionId: null,
      satiety: 60,
      joy: 80,
      health: 100,
      evolutionStage: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DaySummaryScreen(
          summary: DaySummary.fromJson(_summaryJson),
          pet: pet,
          onContinue: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reflection = tester.widget<Image>(
      find.byKey(const Key('day-summary-pet-reflection')),
    );
    expect(
      (reflection.image as AssetImage).assetName,
      // Orange kitten, default red collar, joyful mood.
      'assets/Cat/stages/kitten/red/happy_red.webp',
    );
    expect(
      find.bySemanticsLabel('Отражение питомца Рыжик в зеркале'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text on a narrow phone keeps totals and continue usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2), disableAnimations: true),
          child: child!,
        ),
        home: DaySummaryScreen(
          summary: DaySummary.fromJson(_summaryJson),
          onContinue: () => continued = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('42'), findsOneWidget);
    expect(find.text('Копилка'), findsNWidgets(2));
    final button = find.widgetWithText(ElevatedButton, 'Продолжить');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(continued, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        'cards clear the frame at width $width and scale $textScale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: DaySummaryScreen(
                summary: DaySummary.fromJson(_summaryJson),
                onContinue: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          final glass = find.descendant(
            of: find.byType(DaySummaryMirror),
            matching: find.byType(ClipPath),
          );
          final clipper = tester.widget<ClipPath>(glass).clipper!;
          final glassPath = clipper.getClip(tester.getSize(glass));
          final glassOrigin = tester.getTopLeft(glass);
          for (final label in ['Надо', 'Хочу', 'Копилка']) {
            final cards = find.ancestor(
              of: find.text(label),
              matching: find.byType(Container),
            );
            expect(cards, findsNWidgets(2));
            for (var index = 0; index < 2; index++) {
              // Include the 7.5px inner stroke and a visible gap. This catches
              // clipping by a shaped cap even when Flutter reports no overflow.
              final bounds = tester
                  .getRect(cards.at(index))
                  .shift(-glassOrigin)
                  .inflate(12);
              for (final corner in [
                bounds.topLeft,
                bounds.topRight,
                bounds.bottomLeft,
                bounds.bottomRight,
              ]) {
                expect(
                  glassPath.contains(corner),
                  isTrue,
                  reason: '$label card $index overlaps the ornamental frame',
                );
              }
            }
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
