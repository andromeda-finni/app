import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/main.dart';

void main() {
  testWidgets('parent can enter a child ID and open the progress skeleton', (
    tester,
  ) async {
    await tester.pumpWidget(const GroshikApp());
    await tester.pumpAndSettle();

    expect(find.text('Я ребёнок'), findsOneWidget);
    expect(find.text('Я родитель'), findsOneWidget);

    await tester.tap(find.byKey(const Key('role-parent')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('parent-child-code-field')),
      'GR-A12B-34CD',
    );
    await tester.tap(find.text('Открыть кабинет'));
    await tester.pumpAndSettle();

    expect(find.text('Грошик: учебный прогресс'), findsOneWidget);
    expect(find.text('Надо разобрать эту тему ещё раз'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
