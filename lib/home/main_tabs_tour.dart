import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'home_tour.dart';

/// Measurable anchors owned by the three tab screens introduced after Home.
class MainTabsTourTargets {
  final mapHeader = GlobalKey(debugLabel: 'main-tour-map-header');
  final mapViewport = GlobalKey(debugLabel: 'main-tour-map-viewport');
  final mapCurrentQuest = GlobalKey(debugLabel: 'main-tour-map-current-quest');

  final shopWallet = GlobalKey(debugLabel: 'main-tour-shop-wallet');
  final shopCategories = GlobalKey(debugLabel: 'main-tour-shop-categories');
  final shopScrollController = ScrollController();

  final savingsBalance = GlobalKey(debugLabel: 'main-tour-savings-balance');
  final savingsGoal = GlobalKey(debugLabel: 'main-tour-savings-goal');
  final savingsTransfers = GlobalKey(debugLabel: 'main-tour-savings-transfers');
  final savingsFrost = GlobalKey(debugLabel: 'main-tour-savings-frost');
  final savingsScrollController = ScrollController();

  int tabForStep(int step) => switch (step) {
    0 || 1 => 1,
    2 || 3 => 2,
    _ => 3,
  };

  Iterable<GlobalKey> keysForStep(int step) => switch (step) {
    0 => [mapHeader, mapViewport],
    1 => [mapCurrentQuest],
    2 => [shopWallet],
    3 => [shopCategories],
    4 => [savingsBalance, savingsGoal],
    5 => [savingsTransfers],
    _ => [savingsFrost],
  };

  ScrollController? scrollControllerForStep(int step) => switch (step) {
    2 || 3 => shopScrollController,
    4 || 5 || 6 => savingsScrollController,
    _ => null,
  };

  GlobalKey? scrollTargetForStep(int step) => switch (step) {
    2 => shopWallet,
    3 => shopCategories,
    4 => savingsBalance,
    5 => savingsTransfers,
    6 => savingsFrost,
    _ => null,
  };

  void dispose() {
    shopScrollController.dispose();
    savingsScrollController.dispose();
  }
}

class MainTabsTourOverlay extends StatelessWidget {
  const MainTabsTourOverlay({
    super.key,
    required this.step,
    required this.spotlights,
    required this.busy,
    required this.onNext,
    required this.onBack,
    this.error,
  });

  static const stepCount = 7;

  final int step;
  final List<Rect> spotlights;
  final bool busy;
  final String? error;
  final VoidCallback onNext;
  final VoidCallback onBack;

  static const _titles = [
    'Карта приключений',
    'Как начать задание',
    'Монеты в магазине',
    'Три полки',
    'Мечта и накопления',
    'Переложить монеты',
    'Сундук Морозко',
  ];

  static const _messages = [
    'На карте задания идут по дорожке. Наверху видно, сколько приключений уже '
        'пройдено. Карту можно прокручивать вверх и вниз.',
    'Яркий герой — твоё следующее задание. Нажми на него, чтобы узнать награду '
        'и начать игру. Закрытые герои откроются по порядку.',
    'Здесь видно, сколько монет можно потратить. После покупки кошелёк '
        'уменьшится, поэтому сначала сверяйся со своим планом.',
    'На полке «Надо» лежит полезное для питомца, на «Хочу» — покупки для '
        'радости, а в «Мечтах» — артефакты, на которые можно копить.',
    'Копилка показывает все накопленные монеты и выбранную мечту. Полоса на '
        'карточке подсказывает, сколько ещё осталось собрать.',
    'Кнопка «Пополнить» переносит свободные монеты из кошелька в копилку. '
        '«Вернуть» отправляет их обратно, но отдаляет мечту.',
    'В Сундуке Морозко монеты лежат несколько игровых дней и возвращаются с '
        'бонусом. Забрать раньше можно, но тогда бонуса не будет.',
  ];

  @override
  Widget build(BuildContext context) {
    final last = step == stepCount - 1;
    final targetCenter = spotlights.isEmpty
        ? null
        : spotlights.map((rect) => rect.center.dy).reduce((a, b) => a + b) /
              spotlights.length;
    final screenMiddle = MediaQuery.sizeOf(context).height / 2;
    final alignment = targetCenter != null && targetCenter > screenMiddle
        ? Alignment.topCenter
        : Alignment.bottomCenter;

    return GuidedTourOverlay(
      stepLabel: 'ЗНАКОМСТВО С РАЗДЕЛАМИ · ${step + 1} / $stepCount',
      semanticLabel: 'Знакомство с разделами, шаг ${step + 1} из $stepCount',
      title: _titles[step],
      message: _messages[step],
      spotlights: spotlights,
      busy: busy,
      error: error,
      onNext: onNext,
      onBack: step > 0 ? onBack : null,
      nextLabel: last ? 'Понятно — в домик' : 'Далее',
      blockerKey: const Key('main-tabs-tour-blocker'),
      backKey: const Key('main-tabs-tour-back'),
      nextKey: const Key('main-tabs-tour-next'),
      errorKey: const Key('main-tabs-tour-error'),
      alignment: alignment,
      bottomInset: step <= 3 ? 102 : AppSpacing.md,
    );
  }
}
