import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/minigames/tugriki/tugriki_game_data.dart';
import 'package:andromeda_app/minigames/tugriki/widgets/tugriki_cell_breakdown.dart';
import 'package:andromeda_app/minigames/tugriki/widgets/tugriki_rate_visualizer.dart';

void main() {
  group('Tugriki game logic and math', () {
    test('Exchange rate is strictly 1 tugrik = 2 coins', () {
      expect(kExchangeRate, 2);
    });

    test('Market catalog goods prices and conversion', () {
      expect(MarketCatalog.bun.priceTugriki, 6);
      expect(MarketCatalog.bun.priceCoins, 12);

      expect(MarketCatalog.soup.priceTugriki, 4);
      expect(MarketCatalog.soup.priceCoins, 8);

      expect(MarketCatalog.juice.priceTugriki, 2);
      expect(MarketCatalog.juice.priceCoins, 4);

      expect(MarketCatalog.bunVariant2.priceTugriki, 3);
      expect(MarketCatalog.bunVariant2.priceCoins, 6);

      expect(MarketCatalog.fruits.priceTugriki, 3);
      expect(MarketCatalog.fruits.priceCoins, 6);

      expect(MarketCatalog.pie.priceTugriki, 2);
      expect(MarketCatalog.pie.priceCoins, 4);
    });

    test('Variant 2 sum: 4 + 2 + 3 = 9 tugriks -> 18 coins', () {
      final totalTugriki = MarketCatalog.soup.priceTugriki +
          MarketCatalog.juice.priceTugriki +
          MarketCatalog.bunVariant2.priceTugriki;
      expect(totalTugriki, 9);
      final totalCoins = totalTugriki * kExchangeRate;
      expect(totalCoins, 18);
    });

    test('Variant 3 budget calculation: 20 coins limit', () {
      const budget = 20;
      // Soup (4) + Juice (2) + Fruits (3) = 9 tugriks = 18 coins
      final selection = [
        MarketCatalog.soup,
        MarketCatalog.juice,
        MarketCatalog.fruits,
      ];
      final totalTugriki = selection.fold<int>(0, (sum, g) => sum + g.priceTugriki);
      final totalCoins = totalTugriki * kExchangeRate;
      final change = budget - totalCoins;

      expect(totalTugriki, 9);
      expect(totalCoins, 18);
      expect(change, 2);
      expect(totalCoins <= budget, isTrue);
    });

    test('Variant 3 budget overflow detection', () {
      const budget = 20;
      // All 4 items: Soup (4) + Juice (2) + Fruits (3) + Pie (2) = 11 tugriks = 22 coins
      final allItems = [
        MarketCatalog.soup,
        MarketCatalog.juice,
        MarketCatalog.fruits,
        MarketCatalog.pie,
      ];
      final totalTugriki = allItems.fold<int>(0, (sum, g) => sum + g.priceTugriki);
      final totalCoins = totalTugriki * kExchangeRate;

      expect(totalTugriki, 11);
      expect(totalCoins, 22);
      expect(totalCoins > budget, isTrue);
    });
  });

  group('Tugriki widgets tests', () {
    testWidgets('TugrikiRateVisualizer renders exchange rate', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TugrikiRateVisualizer(compact: true),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('1 тугрик'), findsOneWidget);
      expect(find.textContaining('2 монетки'), findsOneWidget);
    });

    testWidgets('TugrikiCellBreakdown interactive filling to 12 coins formula', (tester) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TugrikiCellBreakdown(
              onRetry: () => retried = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially shows button to add coins
      final addButton = find.textContaining('Положить 2 монетки');
      expect(addButton, findsOneWidget);

      // Tap 6 times to fill all 6 cells
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.textContaining('Положить 2 монетки'));
        await tester.pump();
      }

      // Now the formula is displayed
      expect(find.text('2 + 2 + 2 + 2 + 2 + 2 = 12'), findsOneWidget);
      final retryButton = find.text('Попробовать ещё раз');
      expect(retryButton, findsOneWidget);
      await tester.ensureVisible(retryButton);
      await tester.tap(retryButton);
      await tester.pump();
      expect(retried, isTrue);
    });
  });
}
