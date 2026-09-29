import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../goldfish_game_content.dart';
import '../goldfish_game_controller.dart';
import '../goldfish_game_models.dart';

class GoldfishShoppingView extends StatelessWidget {
  const GoldfishShoppingView({
    super.key,
    required this.controller,
    required this.onToggle,
    required this.onCheck,
    required this.onShowHint,
    this.onExit,
  });

  final GoldfishGameController controller;
  final ValueChanged<GoldfishOffer> onToggle;
  final VoidCallback onCheck;
  final VoidCallback onShowHint;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          GoldfishAssets.homeBeforePortrait,
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        ColoredBox(color: AppColors.canvasWarm.withValues(alpha: 0.22)),
        SafeArea(
          child: Column(
            children: [
              _Header(
                controller: controller,
                onShowHint: onShowHint,
                onExit: onExit,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 720;
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _StorePane(
                              controller: controller,
                              onToggle: onToggle,
                            ),
                          ),
                          SizedBox(
                            width: 310,
                            child: _HomePane(
                              controller: controller,
                              onToggle: onToggle,
                              onCheck: onCheck,
                              wide: true,
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Expanded(
                          child: _StorePane(
                            controller: controller,
                            onToggle: onToggle,
                          ),
                        ),
                        _HomePane(
                          controller: controller,
                          onToggle: onToggle,
                          onCheck: onCheck,
                          wide: false,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.onShowHint,
    this.onExit,
  });

  final GoldfishGameController controller;
  final VoidCallback onShowHint;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final level = controller.level;
    return Material(
      color: AppColors.parchment.withValues(alpha: 0.98),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (onExit != null)
                  IconButton(
                    onPressed: onExit,
                    tooltip: 'Назад на карту',
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Expanded(
                  child: Text(
                    level.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.eventTitle,
                  ),
                ),
                IconButton(
                  key: const ValueKey('goldfish-hint-button'),
                  onPressed: onShowHint,
                  tooltip: 'Подсказка',
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  icon: const Icon(Icons.help_outline_rounded),
                  color: AppColors.crimsonDark,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: _Counter(label: 'Бюджет', value: level.budget),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _Counter(label: 'Потрачено', value: controller.spent),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _Counter(
                    label: level.minimumReserve > 0
                        ? 'Осталось ≥ ${level.minimumReserve}'
                        : 'Осталось',
                    value: controller.remaining,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(level.taskText, style: AppTextStyles.supporting),
            ),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xs,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      border: Border.all(color: AppColors.fieldBorder),
    ),
    child: Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.stepCounter,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icons/coin.webp', width: 20, height: 20),
            const SizedBox(width: AppSpacing.xxs),
            Text('$value', style: AppTextStyles.counterValue),
          ],
        ),
      ],
    ),
  );
}

class _StorePane extends StatelessWidget {
  const _StorePane({required this.controller, required this.onToggle});

  final GoldfishGameController controller;
  final ValueChanged<GoldfishOffer> onToggle;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.canvas.withValues(alpha: 0.94),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700
            ? 4
            : constraints.maxWidth >= 480
            ? 3
            : 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Text('Магазин', style: AppTextStyles.sectionTitle),
            ),
            Expanded(
              child: GridView.builder(
                key: const ValueKey('goldfish-product-grid'),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSpacing.xs,
                  mainAxisSpacing: AppSpacing.xs,
                  childAspectRatio: constraints.maxWidth < 360 ? 0.70 : 0.76,
                ),
                itemCount: controller.level.offers.length,
                itemBuilder: (context, index) {
                  final offer = controller.level.offers[index];
                  return _ProductCard(
                    offer: offer,
                    selected: controller.selectedItemIds.contains(offer.id),
                    onToggle: () => onToggle(offer),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.offer,
    required this.selected,
    required this.onToggle,
  });

  final GoldfishOffer offer;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final card = Semantics(
      button: true,
      selected: selected,
      label:
          '${offer.name}, ${offer.price} монет. ${selected ? 'Выбрано' : 'Добавить для домика'}',
      onTap: onToggle,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? const Color(0xFFFFF0CE) : AppColors.cardBg,
          elevation: selected ? 7 : 2,
          borderRadius: BorderRadius.circular(AppRadii.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('goldfish-item-${offer.id}'),
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(
                  color: selected
                      ? AppColors.leafGreen
                      : offer.decorative
                      ? AppColors.coinGold
                      : AppColors.fieldBorder,
                  width: selected ? 3 : 1.5,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          offer.assetPath,
                          fit: BoxFit.contain,
                          semanticLabel: offer.name,
                        ),
                        if (selected)
                          const Align(
                            alignment: Alignment.topRight,
                            child: Icon(
                              Icons.check_circle,
                              color: AppColors.leafGreen,
                              size: 24,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    offer.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.swatchLabel.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/icons/coin.webp',
                        width: 20,
                        height: 20,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        '${offer.price}',
                        style: AppTextStyles.cardRowLabel.copyWith(
                          color: AppColors.crimsonDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Draggable<GoldfishOffer>(
      data: offer,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 132, height: 168, child: card),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}

class _HomePane extends StatelessWidget {
  const _HomePane({
    required this.controller,
    required this.onToggle,
    required this.onCheck,
    required this.wide,
  });

  final GoldfishGameController controller;
  final ValueChanged<GoldfishOffer> onToggle;
  final VoidCallback onCheck;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final selected = [
      for (final id in controller.selectedItemIds)
        controller.level.offerById(id),
    ];
    final selectedItems = selected.isEmpty
        ? Center(
            child: Text(
              'Перетащи или нажми на товар',
              textAlign: TextAlign.center,
              style: AppTextStyles.supporting,
            ),
          )
        : SingleChildScrollView(
            scrollDirection: wide ? Axis.vertical : Axis.horizontal,
            child: wide
                ? Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final offer in selected)
                        _SelectedItem(
                          offer: offer,
                          onRemove: () => onToggle(offer),
                        ),
                    ],
                  )
                : Row(
                    children: [
                      for (final offer in selected) ...[
                        _SelectedItem(
                          offer: offer,
                          onRemove: () => onToggle(offer),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                    ],
                  ),
          );
    return DragTarget<GoldfishOffer>(
      onAcceptWithDetails: (details) {
        if (!controller.selectedItemIds.contains(details.data.id)) {
          onToggle(details.data);
        }
      },
      builder: (context, candidates, rejected) => Material(
        key: const ValueKey('goldfish-home-target'),
        color: candidates.isNotEmpty
            ? AppColors.infoBg
            : AppColors.cardBg.withValues(alpha: 0.98),
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.home_rounded, color: AppColors.crimsonDark),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Для домика',
                      style: AppTextStyles.sectionTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              if (wide)
                Expanded(child: selectedItems)
              else ...[
                SizedBox(height: 70, child: selectedItems),
                const SizedBox(height: AppSpacing.xs),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const ValueKey('goldfish-check-selection'),
                  onPressed: selected.isEmpty ? null : onCheck,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    backgroundColor: AppColors.crimson,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.crimsonFaded,
                    shape: const StadiumBorder(),
                  ),
                  child: Text('Закончить покупки', style: AppTextStyles.button),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedItem extends StatelessWidget {
  const _SelectedItem({required this.offer, required this.onRemove});

  final GoldfishOffer offer;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Убрать ${offer.name}',
    child: InkWell(
      onTap: onRemove,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        width: 64,
        height: 64,
        padding: const EdgeInsets.all(AppSpacing.xxs),
        decoration: BoxDecoration(
          color: AppColors.parchment,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: AppColors.leafGreen, width: 2),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(offer.assetPath, fit: BoxFit.contain),
            const Align(
              alignment: Alignment.topRight,
              child: Icon(Icons.close, size: 18, color: AppColors.crimsonDark),
            ),
          ],
        ),
      ),
    ),
  );
}
