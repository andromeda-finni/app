import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/economy/item_art_catalog.dart';
import 'package:andromeda_app/home/main_shell.dart';
import 'package:andromeda_app/shop/widgets/artifact_product_card.dart';

import 'support/fake_auth_storage.dart';
import 'support/economy_fixture.dart';

http.Response _jsonResponse(Object? body, [int statusCode = 200]) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _state({required bool withGoal}) => {
  'rules': testEconomyRules,
  'pet': {
    'pet_name': 'Грошик',
    'fur_option_id': 'FUR_GRAY',
    'energy_level': 100,
    'joy_level': 50,
    'evolution_stage': 1,
  },
  'wallets': {'SPENDABLE': 30, 'SAVINGS': 0, 'FROZEN': 0},
  'activeDay': {
    'id': 'day-1',
    'sequence_no': 1,
    'budget_plan_status': 'CONFIRMED',
    'available_amount': 30,
    'required_need_amount': 10,
    'remaining_reserve': 10,
    'need_amount': 10,
    'want_amount': 10,
    'savings_amount': 10,
  },
  'activeEvent': null,
  'activeGoal': withGoal
      ? {
          'id': 'goal-1',
          'target_item_id': 'boots',
          'name': 'Сапоги-скороходы',
          'target_amount': 150,
          'status': 'ACTIVE',
        }
      : null,
  'activeFrostChest': null,
  'shopItems': [
    {'id': 'food', 'name': 'Полезный обед', 'kind': 'NEED', 'price': 6},
    {'id': 'ball', 'name': 'Мячик', 'kind': 'WANT', 'price': 8},
  ],
  'artifacts': [
    {
      'id': 'saucer',
      'name': 'Серебряное блюдечко',
      'price': 80,
      'rarity': 'RARE',
    },
    {
      'id': 'vial',
      'name': 'Склянка с живой водой',
      'price': 90,
      'rarity': 'RARE',
    },
    {
      'id': 'tablecloth',
      'name': 'Скатерть-самобранка',
      'price': 105,
      'rarity': 'EPIC',
    },
    {
      'id': 'horseshoe',
      'name': 'Золотая подкова',
      'price': 120,
      'rarity': 'EPIC',
    },
    {'id': 'shield', 'name': 'Богатырский щит', 'price': 130, 'rarity': 'EPIC'},
    {
      'id': 'purse',
      'name': 'Кошель-самотряс',
      'price': 140,
      'rarity': 'LEGENDARY',
    },
    {
      'id': 'boots',
      'name': 'Сапоги-скороходы',
      'price': 150,
      'rarity': 'LEGENDARY',
    },
  ],
  'inventory': <Object>[],
  'quests': <Object>[],
  'parentTasks': <Object>[],
  'recentTransactions': <Object>[],
  'recentDays': <Object>[],
};

Future<void> _pumpShell(WidgetTester tester, MockClient client) async {
  final auth = FakeAuthStorage(initialToken: 'token');
  await tester.pumpWidget(
    MaterialApp(
      home: MainShell(
        apiClient: ApiClient(
          httpClient: client,
          authStorage: auth,
          baseUrl: 'http://test',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('local catalog covers every seeded artifact', () {
    const artifactIds = {
      'saucer',
      'vial',
      'tablecloth',
      'horseshoe',
      'shield',
      'purse',
      'boots',
    };
    expect(localItemArtwork.keys.toSet(), artifactIds);
    expect(localArtifactBenefitDescriptions.keys.toSet(), artifactIds);
    expect(
      localArtifactBenefitDescriptions.values,
      everyElement(isNot(isEmpty)),
    );
    expect(localPurchaseArtwork['FOOD_APPLE'], contains('apple'));
    expect(localPurchaseArtwork['FOOD_CARROT'], contains('carrot'));
    expect(localPurchaseArtwork['PET_MEAL'], contains('bowl'));
  });

  testWidgets('every catalog artwork is bundled and can be loaded', (
    tester,
  ) async {
    for (final assetPath in {
      ...localItemArtwork.values,
      ...localPurchaseArtwork.values,
    }) {
      final bytes = await rootBundle.load(assetPath);
      expect(bytes.lengthInBytes, greaterThan(0), reason: assetPath);
    }
  });

  testWidgets('shop scene assets are bundled and can be loaded', (
    tester,
  ) async {
    for (final assetPath in const [
      'assets/minigames/mole/shop.webp',
      'assets/shop/category_needs-v2.webp',
      'assets/shop/category_wants-v2.webp',
      'assets/shop/category_dreams-v2.webp',
      'assets/shop/title_sign.webp',
    ]) {
      final bytes = await rootBundle.load(assetPath);
      expect(bytes.lengthInBytes, greaterThan(0), reason: assetPath);
    }
  });

  testWidgets('store has no overflow on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = _state(withGoal: true);
    await _pumpShell(
      tester,
      MockClient(
        (request) async => _jsonResponse(
          request.url.path == '/pet-events/active' ? null : data,
        ),
      ),
    );

    await tester.tap(find.text('Магазин'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Надо'), findsOneWidget);
    expect(find.text('Хочу'), findsOneWidget);
    expect(find.text('Мечты'), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-category-needs')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-category-wants')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-category-dreams')), findsOneWidget);
  });

  testWidgets('category plaques reflow with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = _state(withGoal: true);
    final auth = FakeAuthStorage(initialToken: 'token');
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: MainShell(
          apiClient: ApiClient(
            httpClient: MockClient((request) async => _jsonResponse(data)),
            authStorage: auth,
            baseUrl: 'http://test',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Магазин'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Еда и забота'), findsOneWidget);
    expect(find.text('Для радости'), findsOneWidget);
    expect(find.text('Большие цели'), findsOneWidget);
  });

  testWidgets('shop menu and product catalog support 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = _state(withGoal: true);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: MainShell(
          apiClient: ApiClient(
            httpClient: MockClient((request) async => _jsonResponse(data)),
            authStorage: FakeAuthStorage(initialToken: 'token'),
            baseUrl: 'http://test',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Магазин'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('shop-category-needs')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Полезный обед'), findsOneWidget);
    expect(find.text('Купить за 6'), findsOneWidget);
  });

  testWidgets('savings art and Frost status fit a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = _state(withGoal: true);
    (data['artifacts'] as List<dynamic>).firstWhere(
      (item) => item['id'] == 'boots',
    )['image_asset'] = 'assets/images/morozko_chest.webp';
    data['activeFrostChest'] = {
      'id': 'frost-1',
      'principal_amount': 10,
      'bonus_amount': 1,
      'completed_days': 1,
      'days_remaining': 4,
      'matured': false,
    };
    await _pumpShell(
      tester,
      MockClient(
        (request) async => _jsonResponse(
          request.url.path == '/pet-events/active' ? null : data,
        ),
      ),
    );

    await tester.tap(find.text('Копилка'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Сапоги-скороходы'), findsOneWidget);
    expect(find.text('Внутри 10 монет'), findsOneWidget);
    expect(find.text('Осталось 4 игровых дня'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/morozko_chest.webp',
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('an unplanned day keeps the shop closed and leads to the plan', (
    tester,
  ) async {
    final data = _state(withGoal: true);
    (data['activeDay'] as Map<String, dynamic>)['budget_plan_status'] = 'DRAFT';
    await _pumpShell(
      tester,
      MockClient((request) async => _jsonResponse(data)),
    );

    await tester.tap(find.text('Магазин'));
    await tester.pumpAndSettle();

    // One explanation, and the shop itself stays closed behind it.
    expect(find.text('Сначала составим план'), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-category-needs')), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Составить план'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Сначала составим план'), findsNothing);
    expect(find.text('Утвердить план'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starting the first day routes to goal selection in the store', (
    tester,
  ) async {
    final data = _state(withGoal: false)..['activeDay'] = null;
    var mutationCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return _jsonResponse(
          request.url.path == '/pet-events/active' ? null : data,
        );
      }
      mutationCalls++;
      return _jsonResponse({});
    });
    await _pumpShell(tester, client);

    final startDay = find.byKey(const Key('open-budget-plan'));
    await tester.ensureVisible(startDay);
    await tester.pumpAndSettle();
    await tester.tap(startDay);
    await tester.pumpAndSettle();

    expect(mutationCalls, 0);
    expect(find.text('Магазин'), findsWidgets);
    expect(find.text('Сначала выбери мечту'), findsOneWidget);
    expect(find.text('Полезный обед'), findsNothing);
  });

  testWidgets('goal selection goes through the store and returns to savings', (
    tester,
  ) async {
    var data = _state(withGoal: false);
    var goalCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return _jsonResponse(
          request.url.path == '/pet-events/active' ? null : data,
        );
      }
      expect(request.url.path, '/goals');
      goalCalls++;
      data = _state(withGoal: true);
      return _jsonResponse({'id': 'goal-1', 'targetAmount': 150}, 201);
    });
    await _pumpShell(tester, client);

    await tester.tap(find.text('Копилка'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Выбрать мечту'));
    await tester.tap(find.text('Выбрать мечту'));
    await tester.pumpAndSettle();

    expect(find.text('Магазин'), findsWidgets);
    expect(
      find.text(
        'Покупки временно скрыты. Выбери артефакт, на который будешь копить.',
      ),
      findsOneWidget,
    );
    expect(find.text('Полезный обед'), findsNothing);
    expect(find.text('Мячик'), findsNothing);

    final bootsCard = find.byKey(const ValueKey('artifact-card-boots'));
    final chooseBoots = find.descendant(
      of: bootsCard,
      matching: find.widgetWithText(FilledButton, 'Копить на это'),
    );
    await tester.scrollUntilVisible(
      chooseBoots,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(chooseBoots);
    await tester.pumpAndSettle();
    expect(goalCalls, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Выбрать'));
    await tester.pumpAndSettle();

    expect(goalCalls, 1);
    expect(find.text('Моя цель'), findsOneWidget);
    expect(find.text('Сапоги-скороходы'), findsOneWidget);
  });

  testWidgets('active goal is selected and the other artifacts are locked', (
    tester,
  ) async {
    final data = _state(withGoal: true);
    await _pumpShell(
      tester,
      MockClient((request) async => _jsonResponse(data)),
    );

    await tester.tap(find.text('Магазин'));
    await tester.pumpAndSettle();
    final dreamsCategory = find.byKey(const ValueKey('shop-category-dreams'));
    await tester.ensureVisible(dreamsCategory);
    await tester.pumpAndSettle();
    await tester.tap(dreamsCategory);
    await tester.pumpAndSettle();
    final bootsCard = find.byKey(const ValueKey('artifact-card-boots'));
    await tester.scrollUntilVisible(
      bootsCard,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: bootsCard, matching: find.text('Моя цель')),
      findsOneWidget,
    );
    expect(
      find.text('Твоя цель — наверху. Следи, сколько уже накоплено'),
      findsOneWidget,
    );
    final orderedIds = tester
        .widgetList<ArtifactProductCard>(find.byType(ArtifactProductCard))
        .map((card) => card.item.id)
        .toList();
    expect(orderedIds.first, 'boots');
    expect(find.text('Сначала заверши текущую цель'), findsWidgets);
    expect(find.text('Накоплено 0 · осталось 150 монет'), findsOneWidget);
  });

  testWidgets('an owned artifact is removed from the goal catalog', (
    tester,
  ) async {
    final data = _state(withGoal: false);
    data['artifacts'] = [
      {
        'id': 'shield',
        'name': 'Богатырский щит',
        'price': 130,
        'rarity': 'EPIC',
      },
    ];
    data['inventory'] = [
      {'id': 'inventory-1', 'item_id': 'shield'},
    ];
    await _pumpShell(
      tester,
      MockClient((request) async => _jsonResponse(data)),
    );

    await tester.tap(find.text('Магазин'));
    await tester.pumpAndSettle();
    final dreamsCategory = find.byKey(const ValueKey('shop-category-dreams'));
    await tester.ensureVisible(dreamsCategory);
    await tester.pumpAndSettle();
    await tester.tap(dreamsCategory);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Все доступные артефакты уже получены.'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byKey(const ValueKey('artifact-card-shield')), findsNothing);
    expect(find.text('Все доступные артефакты уже получены.'), findsOneWidget);
  });

  testWidgets('artifact cards reflow at 320px with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = _state(withGoal: false);
    data['artifacts'] = [
      (data['artifacts'] as List<dynamic>).firstWhere(
        (item) => item['id'] == 'boots',
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: MainShell(
          apiClient: ApiClient(
            httpClient: MockClient((request) async => _jsonResponse(data)),
            authStorage: FakeAuthStorage(initialToken: 'token'),
            baseUrl: 'http://test',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Копилка'));
    await tester.pumpAndSettle();
    // At 320x568 with enlarged text the call to action sits under the nav
    // bar; this test is about the store cards, so press it directly.
    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Выбрать мечту'),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Мечты'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final firstCard = find.byKey(const ValueKey('artifact-card-boots'));
    await tester.ensureVisible(firstCard);
    final bootsTitle = find.descendant(
      of: firstCard,
      matching: find.text('Сапоги-скороходы'),
    );
    await tester.drag(
      find.byKey(const ValueKey('shop-dreams')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(bootsTitle);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(firstCard, findsOneWidget);
    expect(
      // Tapping the title opens the artifact details with its real effect.
      find.text('Пока надеты, открывают четвёртое задание за день.'),
      findsOneWidget,
    );
  });

  testWidgets('ordinary store purchase requires explicit confirmation', (
    tester,
  ) async {
    final data = _state(withGoal: true);
    var purchaseCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return _jsonResponse(
          request.url.path == '/pet-events/active' ? null : data,
        );
      }
      expect(request.url.path, '/purchases');
      purchaseCalls++;
      return _jsonResponse({
        'balanceAfter': 22,
        'impulsive': false,
        'pet': {'energy_level': 100, 'joy_level': 70},
      }, 201);
    });
    await _pumpShell(tester, client);

    await tester.tap(find.text('Магазин'));
    await tester.pumpAndSettle();
    expect(find.text('Надо'), findsOneWidget);
    expect(find.text('Хочу'), findsOneWidget);
    final wantsCategory = find.byKey(const ValueKey('shop-category-wants'));
    await tester.ensureVisible(wantsCategory);
    await tester.pumpAndSettle();
    await tester.tap(wantsCategory);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Купить за 8'));
    await tester.pumpAndSettle();
    expect(purchaseCalls, 0);
    expect(find.text('Купить Мячик?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(purchaseCalls, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Купить за 8'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Купить'));
    await tester.pumpAndSettle();
    expect(purchaseCalls, 1);
    expect(find.text('Покупка готова'), findsOneWidget);
    expect(find.text('Монеты: 30 → 22'), findsOneWidget);
    expect(find.text('Радость питомца теперь 70 из 100'), findsOneWidget);
  });

  testWidgets('insufficient coins route the child to the quest map', (
    tester,
  ) async {
    // The painted map loops its scene animations while visible; like a
    // phone with reduced motion, the test asks for a still map to settle.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final data = _state(withGoal: true);
    data['wallets'] = {'SPENDABLE': 0, 'SAVINGS': 0, 'FROZEN': 0};
    await _pumpShell(
      tester,
      MockClient((request) async => _jsonResponse(data)),
    );

    await tester.tap(find.text('Магазин'));
    await tester.pumpAndSettle();
    final wantsCategory = find.byKey(const ValueKey('shop-category-wants'));
    await tester.ensureVisible(wantsCategory);
    await tester.pumpAndSettle();
    await tester.tap(wantsCategory);
    await tester.pumpAndSettle();

    expect(find.text('Не хватает 8 монет. Выполни задание.'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Найти монеты на карте'),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quest-map-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unpaid pet event reserve cannot be spent in the store', (
    tester,
  ) async {
    final data = _state(withGoal: true);
    data['wallets'] = {'SPENDABLE': 20, 'SAVINGS': 0, 'FROZEN': 0};
    data['activeEvent'] = {
      'id': 'event-1',
      'title': 'Питомец заболел',
      'description': 'Нужно купить лекарство',
      'amount_due': 20,
    };
    await _pumpShell(
      tester,
      MockClient((request) async => _jsonResponse(data)),
    );

    await tester.tap(find.text('Магазин'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shop-category-needs')));
    await tester.pumpAndSettle();

    final mealButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Сначала обязательные траты'),
    );
    expect(mealButton.onPressed, isNull);
    expect(
      find.text(
        '20 монет нужны на обязательные траты. Сначала позаботься о питомце.',
      ),
      findsOneWidget,
    );
  });
}
