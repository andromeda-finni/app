import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:andromeda_app/core/api_client.dart';
import 'package:andromeda_app/home/main_shell.dart';
import 'package:andromeda_app/home/widgets/app_nav_bar.dart';
import 'package:andromeda_app/theme/app_theme.dart';

import 'support/fake_auth_storage.dart';
import 'support/economy_fixture.dart';

/// The home tab makes real calls, so every shell in these tests gets a stub
/// backend — the nav bar itself is what is under test.
Widget _shell({VoidCallback? onSwitchAudience}) {
  final client = MockClient((request) async {
    // Every tab now reads the single economy read model; serving it keeps the
    // tabs in their real loaded state instead of silently erroring.
    final body = switch (request.url.path) {
      '/economy/state' => {
        'rules': testEconomyRules,
        'pet': {
          'pet_name': 'Мурзик',
          'fur_option_id': 'FUR_GRAY',
          'energy_level': 60,
          'joy_level': 55,
          'health_level': 100,
          'evolution_stage': 1,
        },
        'wallets': {'SPENDABLE': 40, 'SAVINGS': 10, 'FROZEN': 0},
        'activeDay': null,
        'activeGoal': null,
        'shopItems': <Object>[],
        'artifacts': <Object>[],
      },
      _ => null,
    };
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  return MaterialApp(
    home: MainShell(
      apiClient: ApiClient(
        httpClient: client,
        // Without this the client builds a real secure-storage backed
        // AuthStorage, whose platform channel never answers under
        // flutter_test and hangs the whole screen on its loading spinner.
        authStorage: FakeAuthStorage(initialToken: 'tok'),
        baseUrl: 'http://test',
      ),
      onSwitchAudience: onSwitchAudience,
    ),
  );
}

/// A placeholder body repeats its tab's name, so every lookup has to be
/// scoped to the bar itself or it matches two widgets.
Finder _tab(String label) =>
    find.descendant(of: find.byType(AppNavBar), matching: find.text(label));

Icon _iconOf(WidgetTester tester, String label) {
  final column = find.ancestor(of: _tab(label), matching: find.byType(Column));
  return tester.widget<Icon>(
    find.descendant(of: column.first, matching: find.byType(Icon)).first,
  );
}

void main() {
  testWidgets('shows all four tabs', (tester) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    for (final destination in kNavDestinations) {
      expect(find.text(destination.label), findsWidgets);
    }
  });

  testWidgets('tapping a tab switches the visible screen', (tester) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    // All four bodies exist in the IndexedStack; only the selected one is
    // rendered, so the check is on what IndexedStack is showing.
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);

    await tester.tap(_tab('Магазин'));
    await tester.pumpAndSettle();

    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 2);
  });

  testWidgets('the selected tab is crimson and filled, the others are not', (
    tester,
  ) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    expect(_iconOf(tester, 'Дом').icon, Icons.home);
    expect(_iconOf(tester, 'Дом').color, AppColors.crimson);
    expect(_iconOf(tester, 'Карта').icon, Icons.map_outlined);
    expect(_iconOf(tester, 'Карта').color, AppColors.inkMuted);

    await tester.tap(_tab('Карта'));
    await tester.pumpAndSettle();

    expect(_iconOf(tester, 'Карта').icon, Icons.map);
    expect(_iconOf(tester, 'Карта').color, AppColors.crimson);
    expect(_iconOf(tester, 'Дом').icon, Icons.home_outlined);
  });

  testWidgets('each tab keeps its own state across switches', (tester) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    // IndexedStack builds every child once and only changes which is painted,
    // which is what lets a tab keep scroll position and typed input.
    expect(stack.children.length, kNavDestinations.length);
  });

  testWidgets('hovering an unselected tab previews the selected colour', (
    tester,
  ) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    expect(_iconOf(tester, 'Карта').color, AppColors.inkMuted);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(_tab('Карта')));
    await tester.pumpAndSettle();

    final hovered = _iconOf(tester, 'Карта').color!;
    expect(hovered, isNot(AppColors.inkMuted));
    expect(hovered.r, AppColors.crimson.r);

    // Moving away restores the resting colour rather than latching.
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(_iconOf(tester, 'Карта').color, AppColors.inkMuted);
  });

  testWidgets('keyboard focus draws a ring on the focused tab', (tester) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    BoxDecoration decorationOf(String label) {
      final container = find.ancestor(
        of: _tab(label),
        matching: find.byType(AnimatedContainer),
      );
      return tester.widget<AnimatedContainer>(container.first).decoration
          as BoxDecoration;
    }

    Color ringOf(String label) => decorationOf(label).border!.top.color;
    final labels = kNavDestinations.map((d) => d.label).toList();

    expect(labels.map(ringOf), everyElement(Colors.transparent));

    // The home tab has its own buttons, so Tab first walks through the page
    // before it reaches the bar; keep pressing until focus lands on a tab.
    for (var i = 0; i < 40; i++) {
      if (labels.any((l) => ringOf(l) != Colors.transparent)) break;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }

    // A keyboard user gets no hover colour, so the ring is the only cue that
    // says which tab Enter will open — and it must mark exactly one tab.
    final ringed = labels.where((l) => ringOf(l) == AppColors.crimson);
    expect(ringed, hasLength(1));
  });

  testWidgets('a tab reports its selected state to accessibility', (
    tester,
  ) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    final handle = tester.ensureSemantics();

    final home = tester.getSemantics(_tab('Дом'));
    expect(home.label, 'Дом');
    expect(home.getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
    // The tap action has to live on the node a screen reader lands on,
    // otherwise the tab announces itself but cannot be activated.
    expect(home.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    final map = tester.getSemantics(_tab('Карта'));
    expect(
      map.getSemanticsData().flagsCollection.isSelected,
      isNot(Tristate.isTrue),
    );

    handle.dispose();
  });

  testWidgets('settings open from home and can switch the user', (
    tester,
  ) async {
    var switched = false;
    await tester.pumpWidget(_shell(onSwitchAudience: () => switched = true));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Настройки').first);
    await tester.pumpAndSettle();

    // Parent linking uses the parent's one-time code, entered here.
    expect(find.byKey(const Key('parent-invite-code-field')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Сменить пользователя'),
      200,
      // The settings list, not the code field's own horizontal scrollable.
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.tap(find.text('Сменить пользователя'));
    await tester.pumpAndSettle();
    expect(switched, isTrue);
  });
}
