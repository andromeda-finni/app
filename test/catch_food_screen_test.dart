import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/minigames/catch_food/catch_food_board.dart';
import 'package:andromeda_app/minigames/catch_food/catch_food_controller.dart';
import 'package:andromeda_app/minigames/catch_food/catch_food_models.dart';
import 'package:andromeda_app/minigames/catch_food/catch_food_screen.dart';
import 'package:andromeda_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_auth_storage.dart';
import 'support/pump_catch_food.dart';

const _captureKey = Key('catch-food-capture');

Finder _imageAsset(WidgetTester tester, String path) => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == path,
);
const _config = {
  'energyCost': 20,
  'durationMs': 60000,
  'maxMisses': 3,
  'travelMs': 2400,
  'firstSpawnMs': 600,
  'initialSpawnMs': 1300,
  'minimumSpawnMs': 700,
  'catchWindowMs': 180,
  'spoiledFoodPercent': 20,
};

Map<String, dynamic> _info([
  int energy = 100,
  int spoiledFoodPercent = 20,
  String? furOptionId,
]) => {
  'config': {..._config, 'spoiledFoodPercent': spoiledFoodPercent},
  'pet': {'energy_level': energy, 'fur_option_id': furOptionId},
  'bestScore': 7,
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Server {
  int starts = 0;
  int finishes = 0;
  int energy = 100;
  int spoiledFoodPercent = 20;
  String? furOptionId;
  String? startFurOptionId;
  bool failStart = false;
  bool failFinish = false;
  final List<String> startKeys = [];
  final List<String> finishBodies = [];

  Future<http.Response> call(http.Request request) async {
    if (request.method == 'GET') {
      return _json(_info(energy, spoiledFoodPercent, furOptionId));
    }
    if (request.url.path.endsWith('/start')) {
      starts++;
      final id = (jsonDecode(request.body) as Map)['sessionId'] as String;
      startKeys.add(id);
      if (failStart) {
        failStart = false;
        throw http.ClientException('offline');
      }
      energy -= 20;
      return _json({
        ..._info(energy, spoiledFoodPercent, startFurOptionId ?? furOptionId),
        'session': {'id': id, 'energyCost': 20, 'finished': false},
      });
    }
    if (request.url.path.endsWith('/finish')) {
      finishes++;
      finishBodies.add(request.body);
      if (failFinish) {
        failFinish = false;
        throw http.ClientException('offline');
      }
      return _json({'bestScore': 7});
    }
    throw StateError('Unexpected request ${request.url.path}');
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Server server, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: CatchFoodScreen(
          apiClient: ApiClient(
            httpClient: MockClient(server.call),
            authStorage: FakeAuthStorage(initialToken: 'test'),
            baseUrl: 'http://test',
          ),
          onSound: (_) {},
        ),
      ),
    ),
  );
  await pumpCatchFoodReady(tester);
}

Future<void> _start(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('catch-food-start')));
  await tester.tap(find.byKey(const Key('catch-food-start')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 32));
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CATCH_FOOD_CAPTURE')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('docs/minigames/catch-food/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCatchFoodCaptureFonts);
  for (final entry in [
    ('FUR_GRAY', CatchFoodCoat.striped),
    ('FUR_ORANGE', CatchFoodCoat.orange),
    ('FUR_WHITE', CatchFoodCoat.white),
  ]) {
    testWidgets(
      '${entry.$1} follows the pet through instructions, every bowl and result',
      (tester) async {
        final server = _Server()..furOptionId = entry.$1;
        await _pump(tester, server);
        expect(_imageAsset(tester, entry.$2.catAsset('idle')), findsOneWidget);
        await _start(tester);
        final board = tester.widget<CatchFoodBoard>(
          find.byType(CatchFoodBoard),
        );
        expect(board.coat, entry.$2);
        for (final lane in CatchLane.values) {
          await tester.tap(find.byKey(Key('catch-control-${lane.assetName}')));
          await tester.pump();
          expect(
            _imageAsset(tester, entry.$2.catAsset('catch_${lane.assetName}')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
        await _capture(tester, '${entry.$2.name}-gameplay');
        await tester.tap(find.byKey(const Key('catch-food-pause')));
        await tester.pump();
        await tester.tap(find.text('Завершить попытку'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Завершить'));
        await tester.pumpAndSettle();
        expect(_imageAsset(tester, entry.$2.catAsset('miss')), findsOneWidget);
        expect(server.starts, 1);
        expect(server.finishes, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('a changed coat in the start response is loaded before play', (
    tester,
  ) async {
    final server = _Server()
      ..furOptionId = 'FUR_ORANGE'
      ..startFurOptionId = 'FUR_WHITE';
    await _pump(tester, server);
    await _start(tester);
    for (
      var i = 0;
      i < 150 && find.byType(CatchFoodBoard).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      tester.widget<CatchFoodBoard>(find.byType(CatchFoodBoard)).coat,
      CatchFoodCoat.white,
    );
    expect(server.starts, 1);
    await tester.tap(find.byKey(const Key('catch-food-pause')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'instructions show the cost and never charge before explicit start',
    (tester) async {
      final server = _Server();
      await _pump(tester, server);
      expect(find.text('Играть · −20 сытости'), findsOneWidget);
      expect(find.text('Рыбку — лови'), findsOneWidget);
      expect(find.text('С крестиком — пропускай'), findsOneWidget);
      expect(
        find.textContaining('пойманный испорченный корм — ошибка'),
        findsOneWidget,
      );
      expect(server.starts, 0);
      expect(server.energy, 100);
      await _capture(tester, 'intro');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed start retries with the same key and only then opens gameplay',
    (tester) async {
      final server = _Server()..failStart = true;
      await _pump(tester, server);
      await _start(tester);
      expect(
        find.text('Нет связи с сервером. Попробуй ещё раз.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('catch-control-upper_left')), findsNothing);
      await _start(tester);
      expect(server.startKeys, hasLength(2));
      expect(server.startKeys[0], server.startKeys[1]);
      expect(server.energy, 80);
      expect(find.byKey(const Key('catch-control-upper_left')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'controls switch poses; pause freezes the clock; background never auto-resumes',
    (tester) async {
      final server = _Server();
      await _pump(tester, server);
      await _start(tester);
      await tester.tap(find.byKey(const Key('catch-control-upper_right')));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('catch-pose-upper_right')), findsOneWidget);
      await _capture(tester, 'gameplay');
      await tester.tap(find.byKey(const Key('catch-food-pause')));
      await tester.pump();
      final before = tester
          .widget<Text>(find.textContaining('с · Рекорд'))
          .data;
      await tester.pump(const Duration(seconds: 30));
      expect(
        tester.widget<Text>(find.textContaining('с · Рекорд')).data,
        before,
      );
      expect(find.text('Корм и время остановлены.'), findsOneWidget);
      await _capture(tester, 'pause');
      await tester.tap(find.byKey(const Key('catch-food-resume')));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Корм и время остановлены.'), findsOneWidget);
      expect(server.starts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'spoiled sprites are distinct and catching one explains the error',
    (tester) async {
      final server = _Server()..spoiledFoodPercent = 100;
      await _pump(tester, server);
      await _start(tester);
      await tester.pump(const Duration(milliseconds: 600));
      final game = tester
          .widget<CatchFoodBoard>(find.byType(CatchFoodBoard))
          .controller;
      await tester.tap(
        find.byKey(Key('catch-control-${game.pieces.first.lane.assetName}')),
      );
      await tester.pump(const Duration(milliseconds: 2400));
      expect(game.score, 1);
      final spoiled = game.pieces.first;
      expect(spoiled.kind, FoodKind.spoiled);
      final sprite = tester.widget<Image>(
        find.descendant(
          of: find.byKey(ValueKey('food-${spoiled.id}')),
          matching: find.byType(Image),
        ),
      );
      expect(
        (sprite.image as AssetImage).assetName,
        endsWith('/food_spoiled.webp'),
      );
      await _capture(tester, 'spoiled-food');
      await tester.tap(
        find.byKey(Key('catch-control-${spoiled.lane.assetName}')),
      );
      await tester.pump(
        Duration(
          microseconds:
              spoiled.spawnUs +
              game.config.travelMs * 1000 -
              game.elapsedUs +
              16000,
        ),
      );
      expect(game.misses, 1);
      expect(game.score, 1);
      expect(
        find.byKey(const Key('catch-food-spoiled-warning')),
        findsOneWidget,
      );
      await _capture(tester, 'spoiled-catch');
      await tester.tap(find.byKey(const Key('catch-food-pause')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a failed result save retries identical data without restarting or charging',
    (tester) async {
      final server = _Server()..failFinish = true;
      await _pump(tester, server);
      await _start(tester);
      await tester.tap(find.byKey(const Key('catch-food-pause')));
      await tester.pump();
      await tester.tap(find.text('Завершить попытку'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Завершить'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Результат пока не сохранён.'),
        findsOneWidget,
      );
      final retry = find.byKey(const Key('catch-food-retry-save'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(server.finishes, 2);
      expect(server.finishBodies[0], server.finishBodies[1]);
      expect(server.starts, 1);
      expect(server.energy, 80);
      expect(find.text('Результат сохранён'), findsOneWidget);
      await _capture(tester, 'result');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'insufficient satiety disables start and does not create a session',
    (tester) async {
      final server = _Server()..energy = 0;
      await _pump(tester, server);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('catch-food-start')),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Проверить сытость'), findsOneWidget);
      expect(server.starts, 0);
    },
  );

  testWidgets('portrait gameplay fits a small screen with large text', (
    tester,
  ) async {
    final server = _Server();
    await _pump(tester, server, size: const Size(320, 640), scale: 1.5);
    await _start(tester);
    expect(find.byKey(const Key('catch-control-lower_right')), findsOneWidget);
    await _capture(tester, 'small-screen');
    expect(tester.takeException(), isNull);
  });
}
