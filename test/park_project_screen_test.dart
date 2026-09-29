import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/core/child_difficulty.dart';
import 'package:andromeda_app/minigames/park/park_project_data.dart';
import 'package:andromeda_app/minigames/park/park_project_screen.dart';
import 'package:andromeda_app/onboarding/widgets/story_button.dart';
import 'package:andromeda_app/theme/app_theme.dart';

import 'support/fake_auth_storage.dart';

Map<String, dynamic> _offer({bool canContribute = true}) => {
  'stage': 'FIRST_OFFER',
  'scene': 'FIRST_OFFER',
  'targetAmount': 100,
  'collectedAmount': 80,
  'offerAmount': 20,
  'spendableBalance': 75,
  'availableToContribute': canContribute ? 75 : 10,
  'canContribute': canContribute,
  'childContribution': 0,
  'completed': false,
  'daysToNextStage': null,
};

Widget _screen(
  http.Client client, {
  bool skipIntro = false,
  String petName = 'Мурзик',
  String? furOptionId,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: ParkProjectScreen(
    difficulty: ChildDifficulty.beginner,
    petName: petName,
    furOptionId: furOptionId,
    skipFirstOfferIntro: skipIntro,
    apiClient: ApiClient(
      httpClient: client,
      authStorage: FakeAuthStorage(initialToken: 'tok'),
      baseUrl: 'http://test',
    ),
  ),
);

void main() {
  test('each construction stage has its own authored background', () {
    expect(ParkAssets.backgroundFor('BUILDING'), ParkAssets.parkBuilding);
    expect(
      ParkAssets.backgroundFor('ALMOST_READY'),
      ParkAssets.parkAlmostReady,
    );
    expect(ParkAssets.backgroundFor('OPEN'), ParkAssets.parkOpen);
    expect(ParkAssets.backgroundFor('FIRST_OFFER'), ParkAssets.background);
  });

  testWidgets('long question stays usable on a short narrow screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    final client = MockClient(
      (_) async => http.Response(jsonEncode(_offer()), 200),
    );

    await tester.pumpWidget(
      _screen(client, textScaler: const TextScaler.linear(2)),
    );
    await tester.pumpAndSettle();

    for (final label in [
      'Какой парк?',
      'Слушать',
      'А кто заплатит?',
      'Слушать',
    ]) {
      final button = find.text(label);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const ValueKey('park-answer-together')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('park-answer-one-person')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('introduces the park before showing money', (tester) async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode(_offer()), 200),
    );

    await tester.pumpWidget(
      _screen(client, petName: 'Мурзик', furOptionId: 'FUR_ORANGE'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Знакомство с Барсуком'), findsOneWidget);
    expect(find.textContaining('Привет, Мурзик!'), findsOneWidget);
    expect(find.text('80 из 100'), findsNothing);
    expect(find.byKey(const ValueKey('park-contribute')), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/minigames/park/badger.webp',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Какой парк?'));
    await tester.pumpAndSettle();
    expect(find.text('Мурзик'), findsOneWidget);
    expect(find.text('А что будет в парке?'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/Cat/Red_collar/base/red.webp',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Слушать'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Карусели, горки'), findsOneWidget);

    await tester.tap(find.text('А кто заплатит?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Слушать'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('park-answer-one-person')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Одному будет слишком дорого'), findsOneWidget);
    expect(find.text('80 из 100'), findsNothing);

    await tester.tap(find.text('Попробовать ещё раз'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('park-answer-together')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Вместе жители смогут'), findsOneWidget);

    await tester.tap(find.text('Спросить про сбор'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Слушать'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('park-show-collection')));
    await tester.pumpAndSettle();

    expect(find.text('Собираем на парк'), findsOneWidget);
    expect(find.text('80 из 100'), findsOneWidget);
    expect(find.byKey(const ValueKey('park-contribute')), findsOneWidget);
  });

  testWidgets('shows a neutral choice and saves a contribution', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response(jsonEncode(_offer()), 200);
      }
      return http.Response(
        jsonEncode({
          ..._offer(),
          'stage': 'FUNDED',
          'scene': 'FUNDED',
          'collectedAmount': 100,
          'offerAmount': null,
          'spendableBalance': 55,
          'availableToContribute': 55,
          'canContribute': false,
          'childContribution': 20,
          'daysToNextStage': 1,
        }),
        200,
      );
    });

    await tester.pumpWidget(_screen(client, skipIntro: true));
    await tester.pumpAndSettle();

    expect(find.text('Собрано'), findsOneWidget);
    expect(find.text('80 из 100'), findsOneWidget);
    expect(find.text('Добавить 20 монет'), findsOneWidget);
    expect(find.text('Не сейчас'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('park-contribute')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/icons/coin.webp',
      ),
      findsNWidgets(3),
    );
    await tester.pumpAndSettle();

    expect(find.text('Все 100 монет собраны!'), findsOneWidget);
    final saved = requests.last;
    expect(saved.url.path, '/park-project/decision');
    final body = jsonDecode(saved.body) as Map<String, dynamic>;
    expect(body['offer'], 'FIRST');
    expect(body['decision'], 'CONTRIBUTE');
    expect(body['idempotencyKey'], isA<String>());
  });

  for (final scene in ['BUILDING', 'ALMOST_READY', 'OPEN']) {
    testWidgets('$scene displays its matching park illustration', (
      tester,
    ) async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            ..._offer(),
            'stage': scene == 'OPEN' ? 'COMPLETE' : 'FUNDED',
            'scene': scene,
            'collectedAmount': 100,
            'offerAmount': null,
            'canContribute': false,
            'completed': scene == 'OPEN',
          }),
          200,
        ),
      );
      await tester.pumpWidget(_screen(client));
      await tester.pumpAndSettle();

      final expected = ParkAssets.backgroundFor(scene);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == expected,
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('protects important money without hiding the decline choice', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode(_offer(canContribute: false)), 200),
    );
    await tester.pumpWidget(_screen(client, skipIntro: true));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<StoryButton>(find.byKey(const ValueKey('park-contribute')))
          .onPressed,
      isNull,
    );
    expect(find.byKey(const ValueKey('park-decline')), findsOneWidget);
    expect(find.textContaining('важные покупки'), findsOneWidget);
  });

  for (final width in [320.0, 412.0]) {
    testWidgets('fits ${width.toInt()} px without overflow', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 700);
      addTearDown(tester.view.reset);
      final client = MockClient(
        (_) async => http.Response(jsonEncode(_offer()), 200),
      );

      await tester.pumpWidget(_screen(client));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
