import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/events/fox/fox_event_content.dart';
import 'package:andromeda_app/events/fox/fox_event_dialog_controller.dart';
import 'package:andromeda_app/events/fox/fox_event_engine.dart';
import 'package:andromeda_app/events/fox/fox_event_models.dart';
import 'package:andromeda_app/events/fox/fox_event_wallet.dart';

void main() {
  group('FoxRandomEventEngine', () {
    test('normal mode rolls the configured random chance once per day', () {
      final never = FoxRandomEventEngine(
        triggerProbability: 0,
        mode: FoxRuntimeMode.normal,
        random: Random(1),
      );
      final always = FoxRandomEventEngine(
        triggerProbability: 1,
        mode: FoxRuntimeMode.normal,
        random: Random(1),
      );

      expect(never.startNextDay(), isNull);
      expect(never.gameDay, 1);
      expect(always.startNextDay(), isNotNull);
      expect(always.gameDay, 1);
    });

    test('a due return visit wins over a new random event', () {
      final engine = FoxRandomEventEngine(
        triggerProbability: 0,
        mode: FoxRuntimeMode.normal,
      );
      final first = engine.startNextDay(forceEvent: true)!;
      engine.acceptDialogResult(FoxDialogResult.waitingForNextDay);

      expect(engine.isWaitingForReturn, isTrue);
      expect(first.session.dueGameDay, 2);

      final returned = engine.startNextDay();
      expect(returned, isNotNull);
      expect(returned!.isReturnVisit, isTrue);
      expect(returned.session, same(first.session));
      expect(engine.gameDay, 2);
    });

    test('scripts run in their authored order and then restart', () {
      final engine = FoxRandomEventEngine(
        triggerProbability: 1,
        ageGroup: FoxAgeGroup.younger,
      );

      final scriptIds = <String>[];
      for (var index = 0; index < 4; index++) {
        final launch = engine.startNextDay()!;
        scriptIds.add(launch.session.scriptId);
        engine.acceptDialogResult(FoxDialogResult.completed);
      }

      expect(scriptIds, [
        'fox_younger_introduction',
        'fox_younger_treasure',
        'fox_younger_boots',
        'fox_younger_introduction',
      ]);
    });

    test('hard difficulty begins with Honey Business', () {
      final engine = FoxRandomEventEngine(
        triggerProbability: 1,
        ageGroup: FoxAgeGroup.older,
      );

      final first = engine.startNextDay()!;
      engine.acceptDialogResult(FoxDialogResult.completed);
      final second = engine.startNextDay()!;

      expect(first.session.scriptId, 'fox_older_honey_business');
      expect(second.session.scriptId, 'fox_older_urgent_secret');
    });
  });

  group('FoxEventDialogController', () {
    test('demo mode immediately resolves a next-day repayment', () async {
      final script = foxScriptById('fox_younger_introduction');
      final session = FoxEventSession(
        scriptId: script.id,
        currentNodeId: script.initialNodeId,
      );
      final wallet = InMemoryFoxEventWallet(initialBalance: 100);
      final controller = FoxEventDialogController(
        script: script,
        session: session,
        wallet: wallet,
        mode: FoxRuntimeMode.demo,
        currentGameDay: 1,
        isReturnVisit: false,
        demoTransitionDuration: Duration.zero,
      );

      await controller.continueFromArrival();
      await controller.select(_choice(controller, 'give_now'));
      expect(wallet.balance, 90);

      final result = await controller.select(_choice(controller, 'wait'));

      expect(result.dialogResult, FoxDialogResult.completed);
      expect(wallet.balance, 100);
      expect(session.status, FoxSessionStatus.completed);
      expect(session.currentNodeId, 'returned_without_questions');
    });

    test(
      'normal mode pauses until day + 1 and applies repayment once',
      () async {
        final script = foxScriptById('fox_younger_introduction');
        final session = FoxEventSession(
          scriptId: script.id,
          currentNodeId: script.initialNodeId,
        );
        final wallet = InMemoryFoxEventWallet(initialBalance: 100);
        final firstVisit = FoxEventDialogController(
          script: script,
          session: session,
          wallet: wallet,
          mode: FoxRuntimeMode.normal,
          currentGameDay: 4,
          isReturnVisit: false,
        );

        await firstVisit.continueFromArrival();
        await firstVisit.select(_choice(firstVisit, 'give_now'));
        final result = await firstVisit.select(_choice(firstVisit, 'wait'));

        expect(result.dialogResult, FoxDialogResult.waitingForNextDay);
        expect(session.dueGameDay, 5);
        expect(wallet.balance, 90);

        final returnVisit = FoxEventDialogController(
          script: script,
          session: session,
          wallet: wallet,
          mode: FoxRuntimeMode.normal,
          currentGameDay: 5,
          isReturnVisit: true,
        );
        await returnVisit.continueFromArrival();
        await returnVisit.continueFromArrival();

        expect(wallet.balance, 100);
        expect(session.status, FoxSessionStatus.completed);
      },
    );
  });
}

FoxChoice _choice(FoxEventDialogController controller, String id) =>
    controller.node.choices.firstWhere((choice) => choice.id == id);
