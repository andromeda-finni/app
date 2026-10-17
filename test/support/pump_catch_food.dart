import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Native WebP decoding runs outside the fake test clock. Wait for the real
/// decoder between frames instead of advancing a spinner for ten fake minutes.
Future<void> pumpCatchFoodReady(WidgetTester tester) async {
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (find.byKey(const Key('catch-food-start')).evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  fail('Catch-food instructions did not become ready');
}

Future<void> loadCatchFoodCaptureFonts() async {
  if (!const bool.fromEnvironment('CATCH_FOOD_CAPTURE')) return;
  final body = FontLoader('PTSerif')
    ..addFont(rootBundle.load('assets/fonts/PTSerif-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/PTSerif-Bold.ttf'));
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await Future.wait([body.load(), icons.load()]);
}
