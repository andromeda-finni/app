import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../ivan_game_content.dart';
import '../ivan_game_controller.dart';
import '../ivan_game_models.dart';

class IvanShoppingView extends StatelessWidget {
  const IvanShoppingView({
    super.key,
    required this.controller,
    required this.onCheck,
    required this.onShowHint,
    this.onExit,
  });

  final IvanGameController controller;
  final VoidCallback onCheck;
  final VoidCallback onShowHint;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final level = controller.level;
    final selected = controller.selectedItemIds;
    final remaining = controller.remaining;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          IvanAssets.shopBackground,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
        ColoredBox(color: AppColors.canvasWarm.withValues(alpha: 0.18)),
        SafeArea(
          child: Column(
            children: [
              _GameHeader(
                level: level,
                spent: controller.spent,
                remaining: remaining,
                onShowHint: onShowHint,
                onExit: onExit,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 760
                        ? 4
                        : constraints.maxWidth >= 500
                        ? 3
                        : 2;
                    final ratio = constraints.maxWidth < 360 ? 0.72 : 0.78;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: 0.32,
                              child: Image.asset(
                                IvanAssets.stall,
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                              ),
                            ),
                          ),
                        ),
                        GridView.builder(
                          key: const ValueKey('ivan-product-grid'),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.sm,
                            AppSpacing.sm,
                            AppSpacing.sm,
                            AppSpacing.md,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: AppSpacing.xs,
                                mainAxisSpacing: AppSpacing.xs,
                                childAspectRatio: ratio,
                              ),
                          itemCount: level.items.length,
                          itemBuilder: (context, index) {
                            final item = level.items[index];
                            return _ProductCard(
                              item: item,
                              selected: selected.contains(item.id),
                              onToggle: () => controller.toggleItem(item.id),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
              _BackpackPanel(
                level: level,
                selectedItemIds: selected,
                remaining: remaining,
                onDrop: (item) {
                  if (!selected.contains(item.id)) {
                    controller.toggleItem(item.id);
                  }
                },
                onCheck: onCheck,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GameHeader extends StatelessWidget {
  const _GameHeader({
    required this.level,
    required this.spent,
    required this.remaining,
    required this.onShowHint,
    this.onExit,
  });

  final IvanLevelConfig level;
  final int spent;
  final int remaining;
  final VoidCallback onShowHint;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final over = remaining < 0;
    return Material(
      color: AppColors.parchment.withValues(alpha: 0.97),
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
                    color: AppColors.ink,
                  ),
                Expanded(
                  child: Text(
                    level.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.eventTitle,
                  ),
                ),
                IconButton(
                  key: const ValueKey('ivan-hint-button'),
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
            Text(
              level.taskText,
              textAlign: TextAlign.center,
              style: AppTextStyles.supporting.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xxs,
              children: [
                _MoneyLabel(label: 'Бюджет', value: level.budget),
                _MoneyLabel(label: 'Потрачено', value: spent),
                _MoneyLabel(
                  label: over ? 'Не хватает' : 'Осталось',
                  value: remaining.abs(),
                  warning: over,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyLabel extends StatelessWidget {
  const _MoneyLabel({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final int value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value монет',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: warning ? const Color(0xFFFFE2DD) : AppColors.cardBg,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: warning ? AppColors.crimson : AppColors.coinGold,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/icons/coin.webp', width: 20, height: 20),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                '$label: $value',
                style: AppTextStyles.swatchLabel.copyWith(
                  color: warning ? AppColors.crimsonDark : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.item,
    required this.selected,
    required this.onToggle,
  });

  final IvanItem item;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final card = Semantics(
      button: true,
      selected: selected,
      label:
          '${item.name}, ${item.price} монет. ${selected ? 'В рюкзаке' : 'Добавить в рюкзак'}',
      onTap: onToggle,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? const Color(0xFFFFF0CE) : AppColors.cardBg,
          elevation: selected ? 7 : 3,
          borderRadius: BorderRadius.circular(AppRadii.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('ivan-item-${item.id}'),
            onTap: onToggle,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(
                  color: selected
                      ? AppColors.leafGreen
                      : item.isMagic
                      ? AppColors.coinGold
                      : AppColors.fieldBorder,
                  width: selected ? 3 : 1.5,
                ),
              ),
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          item.assetPath,
                          fit: BoxFit.contain,
                          semanticLabel: item.name,
                        ),
                        if (item.isMagic)
                          const Align(
                            alignment: Alignment.topRight,
                            child: Icon(
                              Icons.auto_awesome,
                              color: AppColors.coinGold,
                              size: 22,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    item.name,
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
                        '${item.price}',
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

    return Draggable<IvanItem>(
      data: item,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 130, height: 160, child: card),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}

class _BackpackPanel extends StatelessWidget {
  const _BackpackPanel({
    required this.level,
    required this.selectedItemIds,
    required this.remaining,
    required this.onDrop,
    required this.onCheck,
  });

  final IvanLevelConfig level;
  final Set<String> selectedItemIds;
  final int remaining;
  final ValueChanged<IvanItem> onDrop;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final names = [for (final id in selectedItemIds) level.itemById(id).name];
    return Material(
      color: AppColors.cardBg.withValues(alpha: 0.98),
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            DragTarget<IvanItem>(
              onAcceptWithDetails: (details) => onDrop(details.data),
              builder: (context, candidate, rejected) => Container(
                key: const ValueKey('ivan-backpack-target'),
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: candidate.isNotEmpty
                      ? AppColors.infoBg
                      : AppColors.parchment,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: candidate.isNotEmpty
                        ? AppColors.leafGreen
                        : AppColors.fieldBorder,
                    width: 2,
                  ),
                ),
                child: Image.asset(
                  IvanAssets.backpack,
                  fit: BoxFit.contain,
                  semanticLabel: 'Рюкзак с выбранными товарами',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    names.isEmpty
                        ? 'Рюкзак пока пуст'
                        : 'В рюкзаке: ${names.join(', ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.supporting.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                  if (selectedItemIds.isNotEmpty)
                    Text(
                      'Нажми на карточку ещё раз, чтобы вернуть товар.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.stepCounter,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton(
              key: const ValueKey('ivan-check-selection'),
              onPressed: selectedItemIds.isEmpty ? null : onCheck,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(104, 52),
                backgroundColor: AppColors.crimson,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.crimsonFaded,
                shape: const StadiumBorder(),
              ),
              child: Text('В путь', style: AppTextStyles.button),
            ),
          ],
        ),
      ),
    );
  }
}
