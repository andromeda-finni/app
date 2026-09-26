import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../economy/economy_action_ui.dart';
import '../economy/economy_actions.dart';
import '../economy/economy_state.dart';
import '../theme/app_theme.dart';
import 'widgets/artifact_product_card.dart';

enum StoreMode { normal, selectGoal, browseGoals }

class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    required this.apiClient,
    required this.mode,
    required this.onBack,
    required this.onGoalSelected,
  });

  final ApiClient apiClient;
  final StoreMode mode;
  final VoidCallback onBack;
  final VoidCallback onGoalSelected;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  EconomyState? _economy;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  late final EconomyActions _actions = EconomyActions(widget.apiClient);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ShopScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final json = await widget.apiClient.get('/economy/state');
      if (!mounted) return;
      setState(() {
        _economy = EconomyState.fromJson(json);
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = economyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _execute(EconomyOperation operation) async {
    if (_busy) return false;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final applied = await _actions.execute(operation, (confirmation) async {
        if (!mounted) return false;
        return showEconomyConfirmation(context, confirmation);
      });
      if (!mounted) return false;
      if (applied) {
        showEconomySuccess(context, operation.success);
        await _load();
      }
      return applied;
    } on ApiException catch (error) {
      if (!mounted) return false;
      final message = economyErrorMessage(error);
      setState(() => _error = message);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buy(EconomyItem item) async {
    final economy = _economy;
    if (economy == null) return;
    await _execute(EconomyActions.purchase(economy, item));
  }

  Future<void> _selectGoal(EconomyItem item) async {
    final economy = _economy;
    if (economy == null || economy.goal != null) return;
    final selected = await _execute(EconomyActions.goal(economy, item));
    if (selected && mounted) widget.onGoalSelected();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _economy == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.crimson),
      );
    }
    final economy = _economy;
    if (economy == null) {
      return _ErrorView(
        message: _error ?? 'Не удалось загрузить магазин.',
        onRetry: _load,
      );
    }

    final goalOnly = widget.mode != StoreMode.normal;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.crimson,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _Header(
            wallet: economy.wallet,
            title: goalOnly ? 'Выбор мечты' : 'Магазин',
            onBack: widget.onBack,
          ),
          const SizedBox(height: 18),
          if (widget.mode == StoreMode.selectGoal)
            const _MessageCard(
              icon: Icons.flag_outlined,
              title: 'Сначала выбери мечту',
              message: 'Покупки временно скрыты. Выбери артефакт, на который будешь копить.',
            )
          else if (widget.mode == StoreMode.browseGoals)
            const _MessageCard(
              icon: Icons.visibility_outlined,
              title: 'Каталог целей',
              message: 'Можно посмотреть другие мечты, но текущая цель закреплена до получения.',
            ),
          if (goalOnly) ...[
            const SizedBox(height: 16),
            _GoalCatalog(
              economy: economy,
              mode: widget.mode,
              busy: _busy,
              onSelect: _selectGoal,
            ),
          ] else ...[
            if (economy.day?.planConfirmed != true) ...[
              const _MessageCard(
                icon: Icons.schedule_outlined,
                title: 'Покупки пока закрыты',
                message: 'Сначала начни игровой день и утверди план.',
              ),
              const SizedBox(height: 16),
            ],
            _PurchaseCatalog(
              title: 'Надо',
              subtitle: 'Еда, лечение и обязательные расходы',
              icon: Icons.favorite_outline,
              items: economy.shopItems
                  .where((item) => item.kind == 'NEED')
                  .toList(),
              economy: economy,
              busy: _busy,
              onBuy: _buy,
            ),
            const SizedBox(height: 16),
            _PurchaseCatalog(
              title: 'Хочу',
              subtitle: 'Игрушки, сладости и необязательные покупки',
              icon: Icons.toys_outlined,
              items: economy.shopItems
                  .where((item) => item.kind == 'WANT')
                  .toList(),
              economy: economy,
              busy: _busy,
              onBuy: _buy,
            ),
            const SizedBox(height: 16),
            _GoalCatalog(
              economy: economy,
              mode: StoreMode.normal,
              busy: _busy,
              onSelect: _selectGoal,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTextStyles.supporting.copyWith(
                color: AppColors.crimson,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.wallet,
    required this.title,
    required this.onBack,
  });

  final int wallet;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        onPressed: onBack,
        tooltip: 'Назад',
        icon: const Icon(Icons.arrow_back, size: 30),
      ),
      Expanded(child: Text(title, style: AppTextStyles.screenTitle)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icons/coin.png', width: 24, height: 24),
            const SizedBox(width: 6),
            Text('$wallet', style: AppTextStyles.cardRowLabel),
          ],
        ),
      ),
    ],
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => _Card(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.crimson, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.sectionTitle),
              const SizedBox(height: 4),
              Text(message, style: AppTextStyles.supporting),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PurchaseCatalog extends StatelessWidget {
  const _PurchaseCatalog({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    required this.economy,
    required this.busy,
    required this.onBuy,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<EconomyItem> items;
  final EconomyState economy;
  final bool busy;
  final ValueChanged<EconomyItem> onBuy;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(title: title, subtitle: subtitle, icon: icon),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text(
            'В этом разделе пока нет товаров.',
            style: AppTextStyles.supporting,
          )
        else
          for (final item in items)
            _PurchaseRow(
              item: item,
              economy: economy,
              busy: busy,
              onBuy: onBuy,
            ),
      ],
    ),
  );
}

class _PurchaseRow extends StatelessWidget {
  const _PurchaseRow({
    required this.item,
    required this.economy,
    required this.busy,
    required this.onBuy,
  });

  final EconomyItem item;
  final EconomyState economy;
  final bool busy;
  final ValueChanged<EconomyItem> onBuy;

  @override
  Widget build(BuildContext context) {
    final dayMissing = economy.day?.planConfirmed != true;
    final block = dayMissing
        ? null
        : EconomyActions.spendingBlock(
            economy,
            item.price,
            protectReserve: item.kind != 'NEED',
          );
    final enabled = !busy && !dayMissing && block == null;
    final reason = dayMissing ? 'Сначала утверди план дня.' : block?.message;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: item.kind == 'NEED'
                ? const Color(0xFFE7F1E1)
                : AppColors.parchment,
            child: Icon(
              item.kind == 'NEED' ? Icons.restaurant : Icons.redeem_outlined,
              color: item.kind == 'NEED'
                  ? AppColors.leafGreen
                  : AppColors.crimson,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTextStyles.cardRowLabel),
                if (reason != null)
                  Text(reason, style: AppTextStyles.supporting),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: enabled ? () => onBuy(item) : null,
            child: Text('${item.price} монет'),
          ),
        ],
      ),
    );
  }
}

class _GoalCatalog extends StatelessWidget {
  const _GoalCatalog({
    required this.economy,
    required this.mode,
    required this.busy,
    required this.onSelect,
  });

  final EconomyState economy;
  final StoreMode mode;
  final bool busy;
  final ValueChanged<EconomyItem> onSelect;

  @override
  Widget build(BuildContext context) {
    final activeId = economy.goal?['target_item_id'] as String?;
    final ownedIds = economy.inventory
        .map((row) => row['item_id'])
        .whereType<String>()
        .toSet();
    final availableArtifacts = economy.artifacts
        .where((item) => !ownedIds.contains(item.id))
        .toList();
    final canSelect =
        !busy && economy.goal == null && mode != StoreMode.browseGoals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(
          title: 'Мечты',
          subtitle: 'Выбери артефакт и копи на него в Копилке',
          icon: Icons.auto_awesome,
        ),
        const SizedBox(height: 14),
        if (availableArtifacts.isEmpty)
          const _EmptyArtifactCatalog()
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 600;
              final cardWidth = twoColumns
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final item in availableArtifacts)
                    SizedBox(
                      width: cardWidth,
                      child: ArtifactProductCard(
                        item: item,
                        state: item.id == activeId
                            ? ArtifactProductState.selected
                            : canSelect
                            ? ArtifactProductState.available
                            : ArtifactProductState.locked,
                        onSelect: canSelect ? () => onSelect(item) : null,
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _EmptyArtifactCatalog extends StatelessWidget {
  const _EmptyArtifactCatalog();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      border: Border.all(color: AppColors.fieldBorder),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.emoji_events_outlined,
          size: 48,
          color: AppColors.coinGold,
        ),
        const SizedBox(height: 10),
        Text(
          'Все доступные артефакты уже получены.',
          textAlign: TextAlign.center,
          style: AppTextStyles.sectionTitle,
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.crimson, size: 28),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.screenTitle),
            Text(subtitle, style: AppTextStyles.supporting),
          ],
        ),
      ),
    ],
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.65)),
    ),
    child: child,
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    ),
  );
}
