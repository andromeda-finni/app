import 'dart:convert';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/minigames/mole/mole_game_screen.dart';
import 'package:andromeda_app/minigames/mole/mole_inspection_board.dart';
import 'package:andromeda_app/onboarding/widgets/story_button.dart';
import 'package:andromeda_app/minigames/mole/mole_truth_case_view.dart';
import 'package:andromeda_app/minigames/mole/mole_truth_catalog.dart';
import 'package:andromeda_app/minigames/mole/mole_truth_controller.dart';
import 'package:andromeda_app/minigames/mole/mole_truth_models.dart';
import 'package:andromeda_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_auth_storage.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(430, 2200),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expose(WidgetTester tester, String id) async {
  final span = find.byKey(Key('mole-truth-span-$id'));
  await tester.ensureVisible(span);
  await tester.pumpAndSettle();
  await tester.tapAt(tester.getCenter(span));
  await tester.pumpAndSettle();
  await tester.tapAt(tester.getCenter(span));
  await tester.pumpAndSettle();
}

Future<void> _solveVisibleCase(WidgetTester tester) async {
  if (find.byType(MoleInspectionBoard).evaluate().isNotEmpty) {
    final board = tester.widget<MoleInspectionBoard>(
      find.byType(MoleInspectionBoard),
    );
    for (var i = 0; i < board.episode.hotspots.length; i++) {
      final hint = find.byKey(const Key('mole-hint-button'));
      await tester.ensureVisible(hint);
      await tester.pumpAndSettle();
      await tester.tap(hint);
      await tester.pumpAndSettle();
    }
    for (final question in board.episode.questions) {
      final answer = find.byKey(Key('mole-answer-${question.correctCode}'));
      await tester.ensureVisible(answer);
      await tester.pumpAndSettle();
      await tester.tap(answer);
      await tester.pumpAndSettle();
    }
    return;
  }
  final view = tester.widget<MoleTruthCaseView>(find.byType(MoleTruthCaseView));
  for (final span in view.document.tricks) {
    await _expose(tester, span.id);
  }
  final confront = find.byKey(const Key('mole-truth-confront'));
  await tester.ensureVisible(confront);
  await tester.pumpAndSettle();
  await tester.tap(confront);
  await tester.pumpAndSettle();
}

Finder _continueButton() => find.byWidgetPredicate(
  (widget) =>
      widget.key == const Key('mole-truth-continue') ||
      widget.key == const Key('mole-classic-continue'),
);

void main() {
  test(
    'five checks mix two classic tasks and three lenses without a selector',
    () {
      final seen = <int>{};
      for (var seed = 0; seed < 5; seed++) {
        final classic = moleClassicSteps(seed);
        expect(classic, hasLength(2));
        expect(classic.every((step) => step >= 0 && step < 5), isTrue);
        seen.addAll(classic);
      }
      expect(seen, {0, 1, 2, 3, 4});
    },
  );
  test('generated amounts keep Russian singular and plural forms', () {
    expect([1, 2, 5, 11, 14, 21, 22, 25].map(moleCoinAmount), [
      '1 монета',
      '2 монеты',
      '5 монет',
      '11 монет',
      '14 монет',
      '21 монета',
      '22 монеты',
      '25 монет',
    ]);
  });
  test('twenty distinct documents preserve five validated lesson results', () {
    expect(moleTruthCatalog, hasLength(20));
    expect(moleTruthCatalog.map((item) => item.id).toSet(), hasLength(20));
    const codes = ['12', '9', 'ask', '19', 'seller'];
    for (var step = 1; step <= 5; step++) {
      final family = moleTruthCatalog.where((item) => item.stepNo == step);
      expect(family, hasLength(4));
      for (final document in family) {
        expect(document.serverAnswerCode, codes[step - 1]);
        expect(document.fairTotal, lessThan(document.billedTotal));
        expect(document.tricks, isNotEmpty);
        expect(
          document.spans.map((span) => span.id).toSet().length,
          document.spans.length,
        );
        for (final span in document.tricks) {
          expect(span.printedDescription, isNot(span.truthDescription));
          expect(span.explanation, isNotEmpty);
          expect(span.kind, isNotNull);
        }
      }
    }
    expect(
      moleTruthCatalog
          .where((item) => item.stepNo == 1)
          .every((item) => item.fairTotal == 12),
      isTrue,
    );
    expect(
      moleTruthCatalog
          .where((item) => item.stepNo == 4)
          .every((item) => item.fairTotal == 17),
      isTrue,
    );
  });

  test(
    'receipt totals account for hidden fees and free packaging starts at zero',
    () {
      for (final document in moleTruthCatalog.where(
        (item) => item.documentKind == MoleTruthDocumentKind.receipt,
      )) {
        final total = document.spans.last;
        expect(total.printed, 'ИТОГО', reason: document.id);
        expect(total.truth ?? total.printed, 'ИТОГО', reason: document.id);
        expect(int.parse(total.value!), document.billedTotal);
        final entries = document.spans.where(
          (span) => span != total && span.value != null,
        );
        var actualSum = 0;
        for (final entry in entries) {
          actualSum += (entry.truthValue ?? entry.value!)
              .split('+')
              .map((part) => int.parse(part.trim()))
              .reduce((a, b) => a + b);
          if (entry.printed.contains('подарок')) {
            expect(entry.value, '0', reason: document.id);
            expect(int.parse(entry.truthValue!), greaterThan(0));
          }
        }
        expect(
          actualSum,
          int.parse(total.truthValue ?? total.value!),
          reason: document.id,
        );
        if (document.stepNo == 4) {
          final wrap = document.spans.firstWhere((span) => span.id == 'wrap');
          expect(wrap.value, '0');
          expect(wrap.truthValue, '2');
          expect(actualSum, 19);
          expect(actualSum - int.parse(wrap.truthValue!), document.fairTotal);
        }
      }
    },
  );

  test('offers and product labels use their own document format', () {
    for (final offer in moleTruthCatalog.where((item) => item.stepNo == 2)) {
      expect(offer.documentKind, MoleTruthDocumentKind.advertisement);
      expect(offer.spans.every((span) => span.value == null), isTrue);
      expect(
        offer.spans.last.truth,
        contains(moleCoinAmount(offer.billedTotal)),
      );
      expect(offer.fairTotal, 9);
    }
    final label = moleTruthCatalog.firstWhere(
      (item) => item.id == 'agreement-2',
    );
    expect(label.documentKind, MoleTruthDocumentKind.productLabel);
    expect(label.tricks, hasLength(1));
    expect(label.spans.any((span) => span.id == 'signature'), isFalse);
    expect(label.tricks.single.truth, contains('сахарный сироп'));
  });

  test(
    'assignment seeds reproduce a run and generate different investigations',
    () {
      final seed = moleTruthSeed('assignment-123');
      expect(
        buildMoleTruthRun(seed).map((item) => item.id),
        buildMoleTruthRun(seed).map((item) => item.id),
      );
      final seen = <String>{};
      for (var seed = 0; seed < 100; seed++) {
        final run = buildMoleTruthRun(seed);
        expect(run.map((item) => item.stepNo), [1, 2, 3, 4, 5]);
        seen.addAll(run.map((item) => item.id));
      }
      expect(seen, hasLength(20));
    },
  );

  test(
    'inspection, confirmation and confrontation are separate and idempotent',
    () {
      final controller = MoleTruthController(moleTruthCatalog.first);
      addTearDown(controller.dispose);
      expect(
        controller.confirm('delivery'),
        MoleTruthConfirmation.inspectFirst,
      );
      expect(controller.confront(), isFalse);
      controller.inspect('buyer');
      expect(controller.confirm('buyer'), MoleTruthConfirmation.honest);
      expect(controller.exposedIds, isEmpty);
      controller.inspect('delivery');
      expect(controller.exposedIds, isEmpty);
      expect(controller.confirm('delivery'), MoleTruthConfirmation.found);
      expect(
        controller.confirm('delivery'),
        MoleTruthConfirmation.alreadyFound,
      );
      expect(controller.exposedIds, {'delivery'});
      expect(controller.confront(), isTrue);
      expect(controller.confront(), isFalse);
      expect(controller.confirm('delivery'), MoleTruthConfirmation.closed);
    },
  );

  testWidgets('scanning reveals text but only a tap fixes a trick', (
    tester,
  ) async {
    var solved = 0;
    await _pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: MoleTruthCaseView(
            document: moleTruthCatalog.first,
            onSolved: () => solved++,
          ),
        ),
      ),
    );
    final target = find.byKey(const Key('mole-truth-span-delivery'));
    final point = tester.getCenter(target);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('mole-truth-lens-drag'))),
    );
    await gesture.moveTo(point);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Найдено 0/1'), findsOneWidget);
    expect(solved, 0);
    expect(
      tester
          .widget<StoryButton>(find.byKey(const Key('mole-truth-confront')))
          .onPressed,
      isNull,
    );

    await tester.tapAt(tester.getCenter(target));
    await tester.pumpAndSettle();
    expect(find.text('Найдено 1/1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mole-truth-confront')));
    await tester.pumpAndSettle();
    expect(solved, 1);
    expect(find.byKey(const Key('mole-truth-verdict')), findsOneWidget);
    expect(find.text('12 монет'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hint does not collect evidence or finish the case', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: MoleTruthCaseView(
            document: moleTruthCatalog.first,
            onSolved: () {},
          ),
        ),
      ),
    );
    final hint = find.byKey(const Key('mole-truth-hint'));
    try {
      expect(
        tester.getSemantics(hint).flagsCollection.isEnabled.toBoolOrNull(),
        isTrue,
      );
    } finally {
      semantics.dispose();
    }
    await tester.tap(hint);
    await tester.pumpAndSettle();
    expect(find.text(moleTruthCatalog.first.hint), findsOneWidget);
    expect(find.text('Найдено 0/1'), findsOneWidget);
    expect(
      tester
          .widget<StoryButton>(find.byKey(const Key('mole-truth-confront')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('both tricks are required before a receipt can be disputed', (
    tester,
  ) async {
    final document = moleTruthCatalog.firstWhere((item) => item.stepNo == 4);
    await _pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: MoleTruthCaseView(document: document, onSolved: () {}),
        ),
      ),
    );
    await _expose(tester, 'wrap');
    expect(
      tester
          .widget<StoryButton>(find.byKey(const Key('mole-truth-confront')))
          .onPressed,
      isNull,
    );
    await _expose(tester, 'total');
    expect(
      tester
          .widget<StoryButton>(find.byKey(const Key('mole-truth-confront')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('keyboard focus inspects text and Enter fixes the trick', (
    tester,
  ) async {
    await _pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: MoleTruthCaseView(
            document: moleTruthCatalog.first,
            onSolved: () {},
          ),
        ),
      ),
    );
    Focus.of(tester.element(find.byKey(const Key('mole-truth-span-delivery'))))
        .requestFocus();
    await tester.pumpAndSettle();
    expect(find.text('Найдено 0/1'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Найдено 1/1'), findsOneWidget);
  });

  testWidgets('a narrow phone with doubled text has no overflow', (
    tester,
  ) async {
    await _pump(
      tester,
      const MoleGameScreen(),
      size: const Size(320, 568),
      textScale: 2,
    );
    expect(find.text('ПРОВЕРКА 1 ИЗ 5'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(MoleInspectionBoard), 180);
    expect(find.byType(SegmentedButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all twenty documents keep separate semantics and fit enlarged text',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final document in moleTruthCatalog) {
          await _pump(
            tester,
            Scaffold(
              body: SingleChildScrollView(
                child: MoleTruthCaseView(
                  key: ValueKey(document.id),
                  document: document,
                  onSolved: () {},
                ),
              ),
            ),
            size: const Size(320, 568),
            textScale: 2,
          );
          for (final span in document.spans) {
            final node = tester.getSemantics(
              find.byKey(Key('mole-truth-span-${span.id}')),
            );
            expect(node.label, span.printedDescription);
          }
          expect(tester.takeException(), isNull, reason: document.id);
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('dragging paper outside the glass scrolls the page', (
    tester,
  ) async {
    await _pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: MoleTruthCaseView(
            document: moleTruthCatalog.first,
            onSolved: () {},
          ),
        ),
      ),
      size: const Size(360, 450),
    );
    final board = find.byKey(const Key('mole-truth-board'));
    await tester.ensureVisible(board);
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final before = position.pixels;
    await tester.dragFrom(
      tester.getTopLeft(board) + const Offset(24, 32),
      const Offset(0, 80),
    );
    await tester.pumpAndSettle();
    expect(position.pixels, lessThan(before));
    expect(find.text('Найдено 0/1'), findsOneWidget);
  });

  testWidgets(
    'the new mode resumes a stable case without exposing the archive',
    (tester) async {
      const assignment = 'assignment-resumed';
      final seed = moleTruthSeed(assignment);
      final nextStep =
          List.generate(
            5,
            (index) => index,
          ).firstWhere((index) => !moleClassicSteps(seed).contains(index)) +
          1;
      final api = ApiClient(
        baseUrl: 'http://test',
        authStorage: FakeAuthStorage(initialToken: 't'),
        httpClient: MockClient(
          (_) async => _json({
            'assignmentId': assignment,
            'resumed': true,
            'nextStepNo': nextStep,
          }),
        ),
      );
      await _pump(tester, MoleGameScreen(apiClient: api));
      final view = tester.widget<MoleTruthCaseView>(
        find.byType(MoleTruthCaseView),
      );
      expect(view.document.id, buildMoleTruthRun(seed)[nextStep - 1].id);
      expect(find.text('ПРОВЕРКА $nextStep ИЗ 5'), findsOneWidget);
      expect(find.byKey(const Key('mole-truth-archive')), findsNothing);
    },
  );

  testWidgets(
    'a failed start can be retried without playing an unsynced rewarded run',
    (tester) async {
      var starts = 0;
      final api = ApiClient(
        baseUrl: 'http://test',
        authStorage: FakeAuthStorage(initialToken: 't'),
        httpClient: MockClient((_) async {
          starts++;
          return starts == 1
              ? _json({'error': 'unavailable'}, 503)
              : _json({'assignmentId': 'assignment-retry', 'nextStepNo': 1});
        }),
      );
      await _pump(tester, MoleGameScreen(apiClient: api));
      expect(find.byType(MoleTruthCaseView), findsNothing);
      await tester.tap(find.byKey(const Key('mole-truth-start-retry')));
      await tester.pumpAndSettle();
      expect(starts, 2);
      expect(
        find.byType(MoleInspectionBoard).evaluate().length +
            find.byType(MoleTruthCaseView).evaluate().length,
        1,
      );
    },
  );

  testWidgets(
    'five verdicts use the existing server results and replay earns no second reward',
    (tester) async {
      final answers = <Map<String, dynamic>>[];
      var starts = 0;
      final api = ApiClient(
        baseUrl: 'http://test',
        authStorage: FakeAuthStorage(initialToken: 't'),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/start')) {
            starts++;
            return _json({
              'assignmentId': 'assignment-game',
              'nextStepNo': 1,
              'rewardAmount': 20,
            });
          }
          answers.add(jsonDecode(request.body) as Map<String, dynamic>);
          return _json({
            'outcome': 'SUCCESS',
            'questCompleted': answers.length == 5,
            if (answers.length == 5) 'rewardAmount': 20,
            if (answers.length == 5) 'balanceAfter': 80,
          });
        }),
      );
      await _pump(tester, MoleGameScreen(apiClient: api));
      for (var step = 1; step <= 5; step++) {
        await _solveVisibleCase(tester);
        final next = _continueButton();
        await tester.ensureVisible(next);
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(answers.map((body) => body['stepNo']), [1, 2, 3, 4, 5]);
      expect(answers.map((body) => body['selectedOptionCode']), [
        '12',
        '9',
        'ask',
        '19',
        'seller',
      ]);
      expect(find.text('+20 монет'), findsOneWidget);
      expect(find.text('Теперь в кошельке 80 монет'), findsOneWidget);

      await tester.tap(find.byKey(const Key('mole-truth-new-run')));
      await tester.pumpAndSettle();
      await _solveVisibleCase(tester);
      await tester.ensureVisible(_continueButton());
      await tester.tap(_continueButton());
      await tester.pumpAndSettle();
      expect(starts, 1);
      expect(answers, hasLength(5));
      expect(find.byKey(const Key('mole-truth-archive')), findsNothing);
    },
  );
}
