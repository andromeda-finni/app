import 'dart:typed_data';

import 'package:andromeda_app/home/screens/grand_finale_screen.dart';
import 'package:andromeda_app/home/widgets/stage_transition_screen.dart';
import 'package:andromeda_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget transitionApp({
    required VoidCallback onCompleted,
    VoidCallback? onFanfare,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 640),
          disableAnimations: disableAnimations,
        ),
        child: StageTransitionScreen(
          type: StageTransitionType.newDay,
          beforeArtwork: const Icon(
            Icons.pets_outlined,
            color: Colors.white,
            size: 130,
          ),
          afterArtwork: const Icon(
            Icons.pets_rounded,
            color: Colors.white,
            size: 150,
          ),
          onCompleted: onCompleted,
          onFanfare: onFanfare,
        ),
      ),
    );
  }

  testWidgets('reduced motion dissolves without a flash within 600 ms', (
    tester,
  ) async {
    var completed = false;
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      transitionApp(
        disableAnimations: true,
        onCompleted: () => completed = true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('stage-transition-flash')))
          .opacity,
      0,
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('stage-transition-after')))
          .opacity,
      inExclusiveRange(0, 1),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Доброе утро, Финни!'), findsOneWidget);
    expect(find.textContaining('+30 монет'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Вперёд, к новым открытиям! 🚀'));
    expect(completed, isTrue);
  });

  testWidgets('transition fires fanfare once at the celebration burst', (
    tester,
  ) async {
    var fanfareCount = 0;
    await tester.pumpWidget(
      transitionApp(onCompleted: () {}, onFanfare: () => fanfareCount++),
    );

    await tester.pump(const Duration(milliseconds: 2600));
    expect(fanfareCount, 0);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 1000));

    expect(fanfareCount, 1);
  });

  testWidgets('artwork changes only while the white flash covers it', (
    tester,
  ) async {
    await tester.pumpWidget(transitionApp(onCompleted: () {}));

    Opacity opacity(String key) => tester.widget<Opacity>(find.byKey(Key(key)));

    expect(opacity('stage-transition-before').opacity, 1);
    expect(opacity('stage-transition-after').opacity, 0);

    await tester.pump(const Duration(milliseconds: 2400));

    expect(opacity('stage-transition-flash').opacity, 1);
    expect(opacity('stage-transition-before').opacity, 1);
    expect(opacity('stage-transition-after').opacity, 0);

    await tester.pump(const Duration(milliseconds: 100));

    expect(opacity('stage-transition-flash').opacity, 1);
    expect(opacity('stage-transition-before').opacity, 0);
    expect(opacity('stage-transition-after').opacity, 1);

    await tester.pump(const Duration(milliseconds: 1500));

    expect(opacity('stage-transition-flash').opacity, 0);
    expect(opacity('stage-transition-after').opacity, 1);
  });

  testWidgets('transition finishes in 4.6 seconds and waits for continue', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(transitionApp(onCompleted: () => completed++));
    await tester.pump(const Duration(milliseconds: 3999));

    expect(find.text('Вперёд, к новым открытиям! 🚀'), findsNothing);
    expect(completed, 0);

    await tester.pump(const Duration(milliseconds: 601));

    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('Вперёд, к новым открытиям! 🚀'), findsOneWidget);
    expect(completed, 0);
    await tester.tap(find.text('Вперёд, к новым открытиям! 🚀'));
    expect(completed, 1);
  });

  for (final size in [const Size(320, 568), const Size(1024, 900)]) {
    testWidgets('transition fits ${size.width} x ${size.height}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(transitionApp(onCompleted: () {}));

      for (final elapsed in [800, 1650, 1550, 600]) {
        await tester.pump(Duration(milliseconds: elapsed));
        expect(tester.takeException(), isNull);
      }

      expect(find.text('Вперёд, к новым открытиям! 🚀'), findsOneWidget);
    });
  }

  testWidgets('finale is responsive and exports a non-empty PNG', (
    tester,
  ) async {
    Uint8List? sharedBytes;
    var freePlayOpened = false;
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GrandFinaleScreen(
          childName: 'Маша',
          petName: 'Финни',
          earnedCoins: 240,
          onFreePlay: () => freePlayOpened = true,
          onShareDiploma: (bytes) async => sharedBytes = bytes,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('ТРИУМФ!'), findsOneWidget);
    expect(find.textContaining('Мастер Лесной Казны'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Поделиться дипломом с родителями'));
    await tester.pump();
    for (var attempt = 0; attempt < 20 && sharedBytes == null; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(sharedBytes, isNotNull);
    expect(sharedBytes, isNotEmpty);

    await tester.tap(find.text('Режим свободной игры / Новая глава'));
    expect(freePlayOpened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finale actions use a horizontal tablet layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GrandFinaleScreen(
          childName: 'Александра',
          petName: 'Финни',
          earnedCoins: 999,
          onFreePlay: () {},
          onShareDiploma: (_) async {},
        ),
      ),
    );
    await tester.pump();

    final shareCenter = tester.getCenter(
      find.text('Поделиться дипломом с родителями'),
    );
    final freePlayCenter = tester.getCenter(
      find.text('Режим свободной игры / Новая глава'),
    );
    expect((shareCenter.dy - freePlayCenter.dy).abs(), lessThan(2));
    expect(tester.takeException(), isNull);
  });
}
