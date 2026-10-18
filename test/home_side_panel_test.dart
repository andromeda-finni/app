import 'package:andromeda_app/home/widgets/home_side_panel.dart';
import 'package:andromeda_app/theme/wax_seal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final style in HomePanelStyle.values) {
    testWidgets('$style keeps actions accessible and disables busy actions', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeSidePanel(
              style: style,
              actions: [
                HomePanelAction(
                  key: const Key('care'),
                  icon: Icons.pets_rounded,
                  color: Colors.green,
                  label: 'Забота о питомце',
                  onTap: () => taps++,
                ),
                HomePanelAction(
                  key: const Key('busy'),
                  icon: Icons.checklist_rounded,
                  color: Colors.red,
                  label: 'План сохраняется',
                  busy: true,
                  onTap: () => taps++,
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        find.byType(WaxSeal),
        style == HomePanelStyle.waxSeal ? findsNWidgets(2) : findsNothing,
      );
      expect(find.byTooltip('Забота о питомце'), findsOneWidget);
      expect(find.bySemanticsLabel('Забота о питомце'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byKey(const Key('care')));
      await tester.tap(find.byKey(const Key('busy')));
      expect(taps, 1);

      if (style == HomePanelStyle.classic) {
        final decorations = tester.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byKey(const Key('care')),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect(
          decorations.any(
            (widget) =>
                widget.decoration is BoxDecoration &&
                ((widget.decoration as BoxDecoration).gradient?.colors.contains(
                      Colors.green,
                    ) ??
                    false),
          ),
          isTrue,
        );
      }
    });
  }
}
