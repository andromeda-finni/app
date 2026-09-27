import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../economy/economy_action_ui.dart';
import '../economy/economy_actions.dart';
import '../economy/economy_state.dart';
import '../economy/item_art_catalog.dart';
import '../economy/item_artwork.dart';
import '../theme/app_theme.dart';
import 'widgets/artifact_product_card.dart';
import 'widgets/shop_category_card.dart';

enum StoreMode { normal, selectGoal, browseGoals }

enum _ShopCategory { needs, wants, dreams }

extension on _ShopCategory {
  String get title => switch (this) {
    _ShopCategory.needs => 'Надо',
    _ShopCategory.wants => 'Хочу',
    _ShopCategory.dreams => 'Мечты',
  };

  String get subtitle => switch (this) {
    _ShopCategory.needs => 'Еда и забота',
    _ShopCategory.wants => 'Для радости',
    _ShopCategory.dreams => 'Большие цели',
  };

  String get catalogSubtitle => switch (this) {
    _ShopCategory.needs => 'То, что помогает питомцу быть сытым и здоровым',
    _ShopCategory.wants => 'Игрушки и угощения для радости питомца',
    _ShopCategory.dreams => 'Большие цели, на которые интересно копить',
  };

  String get artwork => switch (this) {
    _ShopCategory.needs => 'assets/icons/bowl.webp',
    _ShopCategory.wants => 'assets/icons/ball.webp',
    _ShopCategory.dreams => 'assets/images/artifacts/saucer.webp',
  };

  String get plaqueAsset => switch (this) {
    _ShopCategory.needs => 'assets/shop/category_needs-v2.webp',
    _ShopCategory.wants => 'assets/shop/category_wants-v2.webp',
    _ShopCategory.dreams => 'assets/shop/category_dreams-v2.webp',
  };
}

class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    required this.apiClient,
    required this.mode,
    required this.onBack,
    required this.onGoalSelected,
    required this.onOpenPlan,
    required this.onOpenQuests,
  });

  final ApiClient apiClient;
  final StoreMode mode;
  final VoidCallback onBack;
  final VoidCallback onGoalSelected;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenQuests;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  EconomyState? _economy;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  String? _pendingPurchaseId;
  _ShopCategory? _category;
  late final EconomyActions _actions = EconomyActions(widget.apiClient);

  @override
  void initState() {
    super.initState();
    _category = widget.mode == StoreMode.normal ? null : _ShopCategory.dreams;
    _load();
  }

  @override
  void didUpdateWidget(ShopScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _category = widget.mode == StoreMode.normal ? null : _ShopCategory.dreams;
      _load();
    }
  }

  void _openCategory(_ShopCategory category) {
    setState(() => _category = category);
  }

  void _goBack() {
    if (widget.mode == StoreMode.normal && _category != null) {
      setState(() => _category = null);
      return;
    }
    widget.onBack();
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
    } on FormatException {
      if (!mounted) return;
      setState(() => _error = economyContractErrorMessage);
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
    if (economy == null || _busy) return;
    setState(() => _error = null);
    try {
      final result = await _actions.executeWithResult(
        EconomyActions.purchase(economy, item),
        (confirmation) async {
          if (!mounted) return false;
          final confirmed = await showEconomyConfirmation(
            context,
            confirmation,
          );
          if (confirmed && mounted) {
            setState(() {
              _busy = true;
              _pendingPurchaseId = item.id;
            });
          }
          return confirmed;
        },
      );
      if (!mounted || result == null) return;
      await _load();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pendingPurchaseId = null;
      });
      await _showPurchaseResult(
        context,
        item: item,
        result: result,
        balanceBefore: economy.wallet,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final message = economyErrorMessage(error);
      setState(() => _error = message);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pendingPurchaseId = null;
        });
      }
    }
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

    return _ShopBackdrop(
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.crimson,
        child: ListView(
          key: ValueKey('shop-${_category?.name ?? 'categories'}'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: [
            _ShopTopBar(wallet: economy.wallet, onBack: _goBack),
            const SizedBox(height: AppSpacing.xs),
            _ShopTitleSign(title: _category?.title ?? 'Магазин'),
            const SizedBox(height: AppSpacing.xs),
            if (_category == null) ...[
              const _ShelfPrompt(),
              const SizedBox(height: AppSpacing.xs),
              _ShopCategoryMenu(onSelected: _openCategory),
            ] else
              _CatalogWidth(
                child: _CategoryContent(
                  category: _category!,
                  economy: economy,
                  mode: widget.mode,
                  busy: _busy,
                  pendingPurchaseId: _pendingPurchaseId,
                  onBuy: _buy,
                  onSelectGoal: _selectGoal,
                  onOpenPlan: widget.onOpenPlan,
                  onOpenQuests: widget.onOpenQuests,
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _MessageCard(
                icon: Icons.error_outline,
                title: 'Не получилось обновить магазин',
                message: _error!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _showPurchaseResult(
  BuildContext context, {
  required EconomyItem item,
  required Map<String, dynamic> result,
  required int balanceBefore,
}) {
  final balanceAfter = (result['balanceAfter'] as num?)?.toInt();
  final pet = result['pet'] is Map
      ? Map<String, dynamic>.from(result['pet'] as Map)
      : const <String, dynamic>{};
  final energyAfter = (pet['energy_level'] as num?)?.toInt();
  final joyAfter = (pet['joy_level'] as num?)?.toInt();
  final impulsive = result['impulsive'] == true;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppRadii.sheet),
          border: Border.all(color: const Color(0xFFD9AF70)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductArtwork(item: item),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Покупка готова', style: AppTextStyles.cardTitle),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(item.name, style: AppTextStyles.supporting),
                    ],
                  ),
                ),
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.leafGreen,
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (balanceAfter != null)
              _ResultLine(
                icon: Icons.account_balance_wallet_outlined,
                text: 'Монеты: $balanceBefore → $balanceAfter',
              ),
            if (energyAfter != null)
              _ResultLine(
                icon: Icons.restaurant_rounded,
                text: 'Сытость питомца теперь $energyAfter из 100',
              ),
            if (joyAfter != null)
              _ResultLine(
                icon: Icons.sentiment_satisfied_alt_rounded,
                text: 'Радость питомца теперь $joyAfter из 100',
              ),
            if (impulsive) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Покупка прошла, но часть запланированного «Надо» ещё не выполнена. Сначала позаботься о нужном — так питомец получит больше пользы.',
                style: AppTextStyles.supporting.copyWith(
                  color: AppColors.crimsonDark,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => Navigator.pop(sheetContext),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: AppColors.crimson,
              ),
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: AppColors.leafGreen),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(text, style: AppTextStyles.cardRowLabel)),
      ],
    ),
  );
}

Future<void> _showArtifactDetails(
  BuildContext context, {
  required EconomyItem item,
  required int savedAmount,
  required bool selected,
}) {
  final benefit = resolveArtifactBenefitDescription(item.id);
  final missing = (item.price - savedAmount).clamp(0, item.price);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.cardBg,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ItemArtwork(
                itemId: item.id,
                imageAsset: item.imageAsset,
                semanticLabel: item.name,
                size: 150,
                backgroundColor: const Color(0xFFFFEBC0),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              item.name,
              textAlign: TextAlign.center,
              style: AppTextStyles.cardTitle,
            ),
            const SizedBox(height: AppSpacing.md),
            _ResultLine(
              icon: Icons.savings_outlined,
              text: selected
                  ? missing == 0
                        ? 'Нужная сумма уже собрана'
                        : 'В Копилке $savedAmount, осталось $missing монет'
                  : 'Чтобы получить предмет, накопи ${item.price} монет',
            ),
            const SizedBox(height: AppSpacing.xs),
            _ResultLine(
              icon: Icons.auto_awesome_outlined,
              text: benefit ?? 'Это сказочный предмет для коллекции питомца. Его можно получить, когда в Копилке собрана вся стоимость.',
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () => Navigator.pop(sheetContext),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Понятно'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShopBackdrop extends StatelessWidget {
  const _ShopBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        'assets/minigames/mole/shop.webp',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.medium,
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x12000000), Color(0x00FFFFFF), Color(0x1F4B250D)],
          ),
        ),
      ),
      child,
    ],
  );
}

class _ShopTopBar extends StatelessWidget {
  const _ShopTopBar({required this.wallet, required this.onBack});

  final int wallet;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Material(
        color: AppColors.cardBg.withValues(alpha: 0.94),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onBack,
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
        ),
      ),
      Semantics(
        label: 'В кошельке $wallet монет',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBg.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF9A5A1F), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/icons/coin.webp', width: 26, height: 26),
              const SizedBox(width: AppSpacing.xs),
              Text('$wallet', style: AppTextStyles.cardRowLabel),
            ],
          ),
        ),
      ),
    ],
  );
}

class _ShopTitleSign extends StatelessWidget {
  const _ShopTitleSign({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Center(
    child: FractionallySizedBox(
      widthFactor: 0.64,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: AspectRatio(
          aspectRatio: 2206 / 713,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: Image.asset(
                  'assets/shop/title_sign.webp',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 6,
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.screenTitle.copyWith(
                      color: const Color(0xFF451C08),
                      fontSize: 22,
                      shadows: const [
                        Shadow(color: Color(0x44FFFFFF), offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ShopCategoryMenu extends StatelessWidget {
  const _ShopCategoryMenu({required this.onSelected});

  final ValueChanged<_ShopCategory> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _CategoryMenuWidth(
        child: ShopCategoryCard(
          key: const ValueKey('shop-category-needs'),
          title: _ShopCategory.needs.title,
          subtitle: _ShopCategory.needs.subtitle,
          semanticLabel: 'Открыть раздел Надо: еда и забота',
          plaqueAsset: _ShopCategory.needs.plaqueAsset,
          onTap: () => onSelected(_ShopCategory.needs),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      _CategoryMenuWidth(
        child: ShopCategoryCard(
          key: const ValueKey('shop-category-wants'),
          title: _ShopCategory.wants.title,
          subtitle: _ShopCategory.wants.subtitle,
          semanticLabel: 'Открыть раздел Хочу: для радости',
          plaqueAsset: _ShopCategory.wants.plaqueAsset,
          onTap: () => onSelected(_ShopCategory.wants),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      _CategoryMenuWidth(
        child: ShopCategoryCard(
          key: const ValueKey('shop-category-dreams'),
          title: _ShopCategory.dreams.title,
          subtitle: _ShopCategory.dreams.subtitle,
          semanticLabel: 'Открыть раздел Мечты: большие цели',
          plaqueAsset: _ShopCategory.dreams.plaqueAsset,
          onTap: () => onSelected(_ShopCategory.dreams),
        ),
      ),
    ],
  );
}

class _ShelfPrompt extends StatelessWidget {
  const _ShelfPrompt();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Выбери полку',
        style: AppTextStyles.swatchLabel.copyWith(color: AppColors.ink),
      ),
    ),
  );
}

class _CategoryMenuWidth extends StatelessWidget {
  const _CategoryMenuWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: child,
    ),
  );
}

class _CatalogWidth extends StatelessWidget {
  const _CatalogWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: child,
    ),
  );
}

class _CategoryContent extends StatelessWidget {
  const _CategoryContent({
    required this.category,
    required this.economy,
    required this.mode,
    required this.busy,
    required this.pendingPurchaseId,
    required this.onBuy,
    required this.onSelectGoal,
    required this.onOpenPlan,
    required this.onOpenQuests,
  });

  final _ShopCategory category;
  final EconomyState economy;
  final StoreMode mode;
  final bool busy;
  final String? pendingPurchaseId;
  final ValueChanged<EconomyItem> onBuy;
  final ValueChanged<EconomyItem> onSelectGoal;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenQuests;

  @override
  Widget build(BuildContext context) {
    final dayNotReady = economy.day?.planConfirmed != true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mode == StoreMode.selectGoal) ...[
          const _MessageCard(
            icon: Icons.flag_outlined,
            title: 'Сначала выбери мечту',
            message: 'Покупки временно скрыты. Выбери артефакт, на который будешь копить.',
          ),
          const SizedBox(height: AppSpacing.md),
        ] else if (mode == StoreMode.browseGoals) ...[
          const _MessageCard(
            icon: Icons.visibility_outlined,
            title: 'Каталог целей',
            message: 'Можно посмотреть другие мечты, но текущая цель закреплена до получения.',
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (category != _ShopCategory.dreams && dayNotReady) ...[
          _MessageCard(
            icon: Icons.schedule_outlined,
            title: economy.day == null
                ? 'Сначала начни игровой день'
                : 'Сначала составь план дня',
            message: economy.day == null
                ? 'На главном экране начни день и распредели монеты — тогда покупки откроются.'
                : 'Распредели все монеты и подтверди свой план — тогда покупки откроются.',
            actionLabel: economy.day == null
                ? 'Начать и составить план'
                : 'Составить план',
            onAction: onOpenPlan,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        switch (category) {
          _ShopCategory.needs => _PurchaseCatalog(
            category: category,
            items: economy.shopItems
                .where((item) => item.kind == 'NEED')
                .toList(),
            economy: economy,
            busy: busy,
            pendingPurchaseId: pendingPurchaseId,
            onBuy: onBuy,
            onOpenQuests: onOpenQuests,
          ),
          _ShopCategory.wants => _PurchaseCatalog(
            category: category,
            items: economy.shopItems
                .where((item) => item.kind == 'WANT')
                .toList(),
            economy: economy,
            busy: busy,
            pendingPurchaseId: pendingPurchaseId,
            onBuy: onBuy,
            onOpenQuests: onOpenQuests,
          ),
          _ShopCategory.dreams => _Card(
            child: _GoalCatalog(
              economy: economy,
              mode: mode,
              busy: busy,
              onSelect: onSelectGoal,
            ),
          ),
        },
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

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
              if (actionLabel case final label?) ...[
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.crimson,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(label),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _PurchaseCatalog extends StatelessWidget {
  const _PurchaseCatalog({
    required this.category,
    required this.items,
    required this.economy,
    required this.busy,
    required this.pendingPurchaseId,
    required this.onBuy,
    required this.onOpenQuests,
  });

  final _ShopCategory category;
  final List<EconomyItem> items;
  final EconomyState economy;
  final bool busy;
  final String? pendingPurchaseId;
  final ValueChanged<EconomyItem> onBuy;
  final VoidCallback onOpenQuests;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(
          subtitle: category.catalogSubtitle,
          artwork: category.artwork,
        ),
        const SizedBox(height: AppSpacing.md),
        if (items.isEmpty)
          Text(
            'В этом разделе пока нет товаров.',
            style: AppTextStyles.supporting,
          )
        else
          for (var index = 0; index < items.length; index++) ...[
            _PurchaseRow(
              item: items[index],
              economy: economy,
              busy: busy,
              loading: pendingPurchaseId == items[index].id,
              onBuy: onBuy,
              onOpenQuests: onOpenQuests,
            ),
            if (index != items.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
      ],
    ),
  );
}

class _PurchaseRow extends StatelessWidget {
  const _PurchaseRow({
    required this.item,
    required this.economy,
    required this.busy,
    required this.loading,
    required this.onBuy,
    required this.onOpenQuests,
  });

  final EconomyItem item;
  final EconomyState economy;
  final bool busy;
  final bool loading;
  final ValueChanged<EconomyItem> onBuy;
  final VoidCallback onOpenQuests;

  @override
  Widget build(BuildContext context) {
    final dayMissing = economy.day?.planConfirmed != true;
    final block = dayMissing
        ? null
        : EconomyActions.purchaseBlock(economy, item);
    final enabled = !busy && !dayMissing && block == null;
    final needsCoins = block?.destination == EconomyDestination.quests;
    final blockedByReserve = block != null && !needsCoins;
    final reason = dayMissing ? null : block?.message;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E9).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: const Color(0x99D9AF70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductArtwork(item: item),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: AppTextStyles.cardRowLabel),
                    if (item.energyDelta > 0 || item.joyDelta > 0) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        [
                          if (item.energyDelta > 0)
                            'Сытость питомца: +${item.energyDelta}',
                          if (item.joyDelta > 0)
                            'Радость питомца: +${item.joyDelta}',
                        ].join(' · '),
                        style: AppTextStyles.supporting.copyWith(
                          color: AppColors.leafGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (reason != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(reason, style: AppTextStyles.supporting),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: enabled
                ? () => onBuy(item)
                : needsCoins && !busy
                ? onOpenQuests
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: AppColors.crimson,
              disabledBackgroundColor: const Color(0xFFE4D7C2),
              disabledForegroundColor: AppColors.inkMuted,
            ),
            icon: loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    dayMissing
                        ? Icons.lock_outline_rounded
                        : needsCoins
                        ? Icons.map_outlined
                        : blockedByReserve
                        ? Icons.lock_outline_rounded
                        : Icons.shopping_basket_outlined,
                  ),
            label: Text(
              dayMissing
                  ? 'Откроется после плана'
                  : loading
                  ? 'Покупаем…'
                  : needsCoins
                  ? 'Найти монеты на карте'
                  : blockedByReserve
                  ? 'Сначала обязательные траты'
                  : 'Купить за ${item.price}',
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductArtwork extends StatelessWidget {
  const _ProductArtwork({required this.item});

  final EconomyItem item;

  @override
  Widget build(BuildContext context) {
    final asset = resolvePurchaseArtwork(item.id);
    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDC7),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD9AF70)),
      ),
      child: asset == null
          ? Icon(
              item.kind == 'NEED' ? Icons.restaurant : Icons.redeem_outlined,
              size: 32,
              color: item.kind == 'NEED'
                  ? AppColors.leafGreen
                  : AppColors.crimson,
            )
          : Image.asset(asset, fit: BoxFit.contain),
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
    final orderedArtifacts = activeId == null
        ? availableArtifacts
        : [
            ...availableArtifacts.where((item) => item.id == activeId),
            ...availableArtifacts.where((item) => item.id != activeId),
          ];
    final activeItem = orderedArtifacts
        .where((item) => item.id == activeId)
        .firstOrNull;
    final canChoose = economy.goal == null && mode != StoreMode.browseGoals;
    final canSelect = !busy && canChoose;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(
          subtitle: activeId == null
              ? 'Выбери одну сказочную вещь, на которую будешь копить'
              : 'Твоя цель — наверху. Следи, сколько уже накоплено',
          artwork:
              resolveItemArtwork(
                itemId: activeItem?.id,
                imageAsset: activeItem?.imageAsset,
              ) ??
              'assets/images/artifacts/saucer.webp',
        ),
        const SizedBox(height: 14),
        if (orderedArtifacts.isEmpty)
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
                  for (final item in orderedArtifacts)
                    SizedBox(
                      width: cardWidth,
                      child: ArtifactProductCard(
                        item: item,
                        state: item.id == activeId
                            ? ArtifactProductState.selected
                            : canChoose
                            ? ArtifactProductState.available
                            : ArtifactProductState.locked,
                        savedAmount: economy.savings,
                        onDetails: () => _showArtifactDetails(
                          context,
                          item: item,
                          savedAmount: economy.savings,
                          selected: item.id == activeId,
                        ),
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
  const _SectionHeading({required this.subtitle, required this.artwork});

  final String subtitle;
  final String artwork;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 60,
        height: 60,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBC0),
          shape: BoxShape.circle,
        ),
        child: Image.asset(artwork, fit: BoxFit.contain),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: AppTextStyles.sectionTitle.copyWith(
                color: const Color(0xFF4A210B),
              ),
            ),
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
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF6E1), Color(0xFFF4D8A4)],
      ),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      border: Border.all(color: const Color(0xBFA95F22)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x293A1B08),
          blurRadius: 6,
          offset: Offset(0, 3),
        ),
      ],
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
