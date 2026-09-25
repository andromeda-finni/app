import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/events/fox/fox_event_content.dart';
import 'package:andromeda_app/events/fox/fox_event_dialog.dart';
import 'package:andromeda_app/events/fox/fox_event_engine.dart';
import 'package:andromeda_app/events/fox/fox_event_models.dart';
import 'package:andromeda_app/events/fox/fox_event_wallet.dart';
import 'package:andromeda_app/home/pet_home_screen.dart';
import 'package:andromeda_app/theme/app_theme.dart';

void main() {
  testWidgets('demo day opens a sudden Fox event popup', (tester) async {
    final engine = FoxRandomEventEngine(mode: FoxRuntimeMode.demo);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PetHomeScreen(engine: engine),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать новый игровой день'));
    // The covered home screen deliberately keeps an indeterminate progress
    // indicator alive while the modal event is open, so wait only for the
    // dialog's entrance animation instead of waiting for all frames to stop.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Пришел Лис'), findsOneWidget);
    expect(find.text('Поговорить'), findsOneWidget);
    expect(engine.gameDay, 1);
  });

  testWidgets('Fox popup fits a small phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final engine = FoxRandomEventEngine(mode: FoxRuntimeMode.demo);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: PetHomeScreen(engine: engine),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final script = foxScriptById('fox_younger_introduction');
    final session = FoxEventSession(
      scriptId: script.id,
      currentNodeId: script.initialNodeId,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: FoxEventDialog(
            script: script,
            session: session,
            wallet: InMemoryFoxEventWallet(),
            mode: FoxRuntimeMode.demo,
            currentGameDay: 1,
            isReturnVisit: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Пришел Лис'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dialog substitutes the pet name entered during onboarding', (
    tester,
  ) async {
    final script = foxScriptById('fox_older_urgent_secret');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FoxEventDialog(
            script: script,
            session: FoxEventSession(
              scriptId: script.id,
              currentNodeId: 'did_not_return',
            ),
            wallet: InMemoryFoxEventWallet(),
            mode: FoxRuntimeMode.normal,
            currentGameDay: 2,
            isReturnVisit: true,
            petName: 'Рыжик',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Узнать, что случилось'));
    await tester.pumpAndSettle();

    expect(find.text('Рыжик'), findsNWidgets(2));
    expect(find.text('Грошик'), findsNothing);
  });

  testWidgets('long Fox text advances by taps before showing choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final script = foxScriptById('fox_older_honey_business');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const Scaffold(),
      ),
    );
    final hostContext = tester.element(find.byType(Scaffold));
    final dialogFuture = showDialog<void>(
      context: hostContext,
      barrierDismissible: false,
      builder: (context) => FoxEventDialog(
        script: script,
        session: FoxEventSession(
          scriptId: script.id,
          currentNodeId: script.initialNodeId,
        ),
        wallet: InMemoryFoxEventWallet(),
        mode: FoxRuntimeMode.demo,
        currentGameDay: 1,
        isReturnVisit: false,
        petName: 'Рыжик',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Поговорить'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Привет, Рыжик!'), findsOneWidget);
    expect(find.text('Держи.'), findsNothing);
    expect(find.text('1/3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('fox-story-continue')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Иногда я прихожу'), findsOneWidget);
    expect(find.text('Держи.'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('fox-story-continue')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Через три дня'), findsOneWidget);
    expect(find.text('Держи.'), findsOneWidget);
    expect(find.text('Нажми, чтобы продолжить'), findsNothing);
    expect(tester.takeException(), isNull);

    Navigator.of(hostContext).pop();
    await tester.pumpAndSettle();
    await dialogFuture;
  });
}
