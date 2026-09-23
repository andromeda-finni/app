import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/onboarding/widgets/onboarding_scene.dart';
import 'package:andromeda_app/theme/app_theme.dart';

void main() {
  testWidgets('render scene transition for visual inspection', (tester) async {
    tester.view.physicalSize = const Size(824, 1100);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const previewKey = Key('scene-transition-preview');
    await tester.pumpWidget(
      const MaterialApp(
        home: RepaintBoundary(
          key: previewKey,
          child: ColoredBox(
            color: AppColors.canvas,
            child: Column(
              children: [
                SizedBox(
                  height: 390,
                  child: OnboardingScene(
                    background: 'assets/backgrounds/town.png',
                    foreground: 'assets/backgrounds/meadow_foreground.png',
                    cat: 'assets/Cat/Red_collar/base/red.png',
                  ),
                ),
                Expanded(child: ColoredBox(color: AppColors.canvas)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(previewKey),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      '/private/tmp/scene-transition-preview.png',
    ).writeAsBytesSync(data!.buffer.asUint8List());
  });
}
