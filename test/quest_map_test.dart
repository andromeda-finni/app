import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/quest_map/quest_map_screen.dart';
import 'package:andromeda_app/theme/app_theme.dart';

void main() {
  Widget app() => MaterialApp(
    theme: ThemeData(fontFamily: AppFonts.family),
    home: const QuestMapScreen(),
  );

  testWidgets('shows all scenario locations on a vertically scrollable map', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quest-map-scroll')), findsOneWidget);
    expect(find.text('Репка'), findsOneWidget);
    expect(find.text('Крот с лупой'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('quest-map-scroll')),
      const Offset(0, 900),
    );
    await tester.pumpAndSettle();

    expect(find.text('Сказочный парк'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps future quests locked and reveals the current quest', (
    tester,
  ) async {
    await tester.pumpWidget(app());

    final currentCloud = tester.widget<Opacity>(
      find.byKey(const Key('quest-map-cloud-mole')),
    );
    final lockedCloud = tester.widget<Opacity>(
      find.byKey(const Key('quest-map-cloud-ivan')),
    );
    expect(currentCloud.opacity, 1);
    expect(lockedCloud.opacity, 1);

    await tester.pumpAndSettle();

    expect(
      tester.widget<Opacity>(find.byKey(const Key('quest-map-cloud-mole'))).opacity,
      0,
    );
    expect(
      tester.widget<Opacity>(find.byKey(const Key('quest-map-cloud-ivan'))).opacity,
      1,
    );
  });

  testWidgets('enables a quest only after its cloud has dispersed', (
    tester,
  ) async {
    await tester.pumpWidget(app());

    expect(
      tester
          .widget<InkResponse>(find.byKey(const Key('quest-map-action-mole')))
          .onTap,
      isNull,
    );
    expect(
      tester
          .widget<InkResponse>(find.byKey(const Key('quest-map-action-ivan')))
          .onTap,
      isNull,
    );

    await tester.pumpAndSettle();

    expect(
      tester
          .widget<InkResponse>(find.byKey(const Key('quest-map-action-mole')))
          .onTap,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('quest-map-action-mole')));
    await tester.pumpAndSettle();

    expect(find.text('Домик Земелика'), findsOneWidget);
    expect(find.text('Играть'), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('renders without overflow at ${width.toInt()} logical pixels', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('quest-map-hero')), findsOneWidget);
    });
  }
}
