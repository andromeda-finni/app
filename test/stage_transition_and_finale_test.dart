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

  testWidgets('reduced motion immediately reveals transition result', (
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
    await tester.pump();

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

    await tester.pump(const Duration(milliseconds: 2250));
    await tester.pump(const Duration(milliseconds: 500));

    expect(fanfareCount, 1);
  });

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
