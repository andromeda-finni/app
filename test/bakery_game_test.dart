import 'dart:convert';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/core/child_difficulty.dart';
import 'package:andromeda_app/minigames/bakery/bakery_game_data.dart';
import 'package:andromeda_app/minigames/bakery/bakery_game_screen.dart';
import 'package:andromeda_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_auth_storage.dart';

void main() {
  group('bakery calculations', () {
    test('required recipe separates profit from final wallet', () {
      final game = BakeryGameState(difficulty: ChildDifficulty.beginner)
        ..basket.addAll({
          BakeryIngredient.flour,
          BakeryIngredient.berries,
          BakeryIngredient.butter,
        });

      expect(game.basketTotal, 12);
      expect(game.cashAfterShopping, 8);
      expect(game.revenue, 20);
      expect(game.profit, 8);
      expect(game.finalWallet, 28);
      expect(game.reward, 12);
      expect(game.piesBaked, 5);
    });

    test(
      'optional honey lowers profit and advanced mode adds one unsold pie',
      () {
        final game = BakeryGameState(difficulty: ChildDifficulty.advanced)
          ..basket.addAll(BakeryIngredient.values);

        expect(game.basketTotal, 18);
        expect(game.cashAfterShopping, 2);
        expect(game.profit, 2);
        expect(game.finalWallet, 22);
        expect(game.reward, 15);
        expect(game.piesBaked, 6);
        expect(game.unsoldCount, 1);
      },
    );

    test('wrong answers preserve progress and reveal a retry hint', () {
      final game = BakeryGameState(difficulty: ChildDifficulty.beginner)
        ..basket.addAll({
          BakeryIngredient.flour,
          BakeryIngredient.berries,
          BakeryIngredient.butter,
        })
        ..stage = BakeryStage.remainderQuiz;

      expect(game.answerRemainder(12), isFalse);
      expect(game.stage, BakeryStage.remainderQuiz);
      expect(game.remainderMistakes, 1);
      expect(game.answerRemainder(8), isTrue);
      expect(game.stage, BakeryStage.cooking);
    });
  });

  testWidgets('honey choice guides the child but allows the extra purchase', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const BakeryGameScreen(difficulty: ChildDifficulty.beginner),
      ),
    );
    await tester.pump();
    final start = find.byKey(const ValueKey('bakery-start'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(find.textContaining('Мёд в рецепте не нужен'), findsNothing);
    expect(
      find.text('Рецепт: мука, ягоды и масло. Выбери, что купить.'),
      findsOneWidget,
    );

    final honey = find.byKey(const ValueKey('bakery-item-honey'));
    await tester.ensureVisible(honey);
    await tester.tap(honey);
    await tester.pumpAndSettle();
    expect(find.text('Берём мёд?'), findsOneWidget);
    expect(find.text('Убрать мёд'), findsOneWidget);
    expect(find.text('Да, беру'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bakery-honey-remove')));
    await tester.pumpAndSettle();
    expect(find.text('В корзине: 0'), findsOneWidget);

    await tester.ensureVisible(honey);
    await tester.tap(honey);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bakery-honey-keep')));
    await tester.pumpAndSettle();
    expect(find.text('В корзине: 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('complete honey flow explains the smaller profit and saves it', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.reset);

    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path} ${request.body}');
      final response = switch (request.url.path) {
        '/quests/$kBakeryQuestId/start' => {
          'assignmentId': 'bakery-a1',
          'rewardAmount': 12,
          'nextStepNo': 1,
        },
        '/assignments/bakery-a1/answer' => {
          'outcome': 'SUCCESS',
          'questCompleted': true,
          'rewardAmount': 12,
        },
        _ => <String, Object>{},
      };
      return http.Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BakeryGameScreen(
          difficulty: ChildDifficulty.beginner,
          apiClient: ApiClient(
            httpClient: client,
            authStorage: FakeAuthStorage(initialToken: 'token'),
            baseUrl: 'http://test',
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('bakery-start')));
    await tester.pumpAndSettle();
    for (final item in const [
      BakeryIngredient.flour,
      BakeryIngredient.berries,
      BakeryIngredient.butter,
    ]) {
      await tester.tap(find.byKey(ValueKey('bakery-item-${item.name}')));
      await tester.pump();
    }
    final honey = find.byKey(const ValueKey('bakery-item-honey'));
    await tester.ensureVisible(honey);
    await tester.tap(honey);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bakery-honey-keep')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('bakery-buy')));
    await tester.tap(find.byKey(const ValueKey('bakery-buy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bakery-answer-2')));
    await tester.pumpAndSettle();

    for (final item in const [
      BakeryIngredient.flour,
      BakeryIngredient.berries,
      BakeryIngredient.butter,
    ]) {
      await tester.tap(find.byKey(ValueKey('bakery-cook-${item.name}')));
      await tester.pump();
    }
    await tester.ensureVisible(find.byKey(const ValueKey('bakery-bake')));
    await tester.tap(find.byKey(const ValueKey('bakery-bake')));
    await tester.pumpAndSettle();
    for (var index = 0; index < 5; index++) {
      await tester.tap(find.byKey(ValueKey('bakery-pie-$index')));
      await tester.pump();
    }
    await tester.ensureVisible(find.byKey(const ValueKey('bakery-sales-done')));
    await tester.tap(find.byKey(const ValueKey('bakery-sales-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bakery-to-profit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bakery-answer-2')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Без мёда прибыль была бы 8 монет'),
      findsOneWidget,
    );
    expect(find.text('Награда: 12 монет'), findsOneWidget);
    expect(calls.where((call) => call.contains('/answer')), hasLength(1));
    expect(calls.last, contains('"selectedOptionCode":"2"'));
    expect(tester.takeException(), isNull);
  });
}
