import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andromeda_app/economy/coin_amount_input.dart';

/// A minimal "−  value  +" editor wired like the real coin editors.
class _Harness extends StatefulWidget {
  const _Harness({required this.max});

  final int max;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int value = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TappableCoinAmount(
          key: const Key('amount'),
          value: value,
          semanticLabel: 'Сумма',
          style: const TextStyle(fontSize: 20),
          onTap: () async {
            final typed = await showCoinAmountDialog(
              context,
              title: 'Сколько?',
              initial: value,
              min: 0,
              max: widget.max,
            );
            if (typed != null) setState(() => value = typed);
          },
        ),
        HoldToRepeat(
          onStep: value < widget.max ? () => setState(() => value++) : null,
          child: IconButton(
            key: const Key('plus'),
            onPressed: value < widget.max
                ? () => setState(() => value++)
                : null,
            icon: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

Future<_HarnessState> _pump(WidgetTester tester, {int max = 30}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: _Harness(max: max)),
    ),
  );
  return tester.state<_HarnessState>(find.byType(_Harness));
}

void main() {
  testWidgets('a tap adds exactly one coin', (tester) async {
    final state = await _pump(tester);
    await tester.tap(find.byKey(const Key('plus')));
    await tester.pump();
    expect(state.value, 1);
  });

  testWidgets(
    'holding keeps adding, faster over time, and stops at the limit',
    (tester) async {
      final state = await _pump(tester, max: 30);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('plus'))),
      );

      await tester.pump(const Duration(milliseconds: 400));
      final afterHoldStarts = state.value;
      expect(afterHoldStarts, greaterThanOrEqualTo(1));

      // Slow start: about three coins in the first second.
      await tester.pump(const Duration(seconds: 1));
      final firstSecond = state.value - afterHoldStarts;
      expect(firstSecond, 3);

      // Held longer, the same second adds many more.
      await tester.pump(const Duration(seconds: 1));
      final before = state.value;
      await tester.pump(const Duration(seconds: 1));
      expect(state.value - before, greaterThan(firstSecond * 2));

      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(state.value, 30);

      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
      expect(state.value, 30);
    },
  );

  testWidgets('releasing stops the repeat', (tester) async {
    final state = await _pump(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('plus'))),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await gesture.up();
    await tester.pump();
    final released = state.value;
    await tester.pump(const Duration(seconds: 2));
    expect(state.value, released);
    expect(released, lessThan(30));
  });

  testWidgets('typing an amount respects the limit', (tester) async {
    final state = await _pump(tester, max: 30);
    await tester.tap(find.byKey(const Key('amount')));
    await tester.pumpAndSettle();
    expect(find.text('От 0 до 30 монет'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('coin-amount-field')), '45');
    await tester.pump();
    expect(find.text('Можно не больше 30'), findsOneWidget);
    final done = tester.widget<FilledButton>(
      find.byKey(const Key('coin-amount-done')),
    );
    expect(done.onPressed, isNull);

    await tester.enterText(find.byKey(const Key('coin-amount-field')), '12');
    await tester.pump();
    await tester.tap(find.byKey(const Key('coin-amount-done')));
    await tester.pumpAndSettle();
    expect(state.value, 12);
  });

  testWidgets('cancelling the dialog keeps the amount', (tester) async {
    final state = await _pump(tester);
    await tester.tap(find.byKey(const Key('amount')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('coin-amount-field')), '7');
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(state.value, 0);
  });
}
