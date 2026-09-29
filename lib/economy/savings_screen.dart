import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../theme/app_theme.dart';
import 'economy_action_ui.dart';
import 'economy_actions.dart';
import 'economy_state.dart';
import 'item_art_catalog.dart';
import 'item_artwork.dart';

String _gameDaysLabel(int value) {
  final mod100 = value % 100;
  final mod10 = value % 10;
  if (mod100 >= 11 && mod100 <= 14) return '$value игровых дней';
  if (mod10 == 1) return '$value игровой день';
  if (mod10 >= 2 && mod10 <= 4) return '$value игровых дня';
  return '$value игровых дней';
}

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({
    super.key,
    required this.apiClient,
    required this.onBack,
    required this.onChooseGoal,
    required this.onBrowseGoals,
    this.onOpenSettings,
  });

  final ApiClient apiClient;
  final VoidCallback onBack;
  final VoidCallback onChooseGoal;
  final VoidCallback onBrowseGoals;
  final VoidCallback? onOpenSettings;

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
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

  Future<void> _execute(EconomyOperation operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final applied = await _actions.execute(operation, (confirmation) async {
        if (!mounted) return false;
        return showEconomyConfirmation(context, confirmation);
      });
      if (!mounted) return;
      if (applied) {
        showEconomySuccess(context, operation.success);
        await _load();
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      final message = economyErrorMessage(error);
      setState(() => _error = message);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _dayReady => _economy?.day?.planConfirmed == true;

  Future<void> _moveSavings(bool deposit) async {
    final economy = _economy;
    if (economy == null || _busy) return;
    final reserve = economy.day?.remainingReserve ?? 0;
    final free = (economy.wallet - reserve).clamp(0, economy.wallet);
    final amount = await _chooseAmount(
      title: deposit ? 'Пополнить копилку' : 'Вернуть в кошелёк',
      hint: deposit
          ? (reserve > 0
                ? 'В кошельке ${economy.wallet} монет, из них $reserve — на еду '
                      'питомцу. Отложить можно до $free монет.'
                : 'В кошельке ${economy.wallet} монет.')
          : 'В копилке ${economy.savings} монет.',
      amounts: economy.rules.savingsTransferAmounts,
      enabled: (amount) {
        if (!_dayReady || economy.goal == null) return false;
        if (!deposit) return economy.savings >= amount;
        return EconomyActions.spendingBlock(economy, amount) == null;
      },
    );
    if (amount != null && mounted) {
      await _execute(EconomyActions.savings(economy, amount, deposit: deposit));
    }
  }

  Future<void> _openFrost() async {
    final economy = _economy;
    if (economy == null || _busy) return;
    final reserve = economy.day?.remainingReserve ?? 0;
    final amount = await _chooseAmount(
      title: 'Сколько положить в сундук?',
      hint: reserve > 0
          ? 'В кошельке ${economy.wallet} монет, $reserve из них нужны на еду.'
          : 'В кошельке ${economy.wallet} монет.',
      amounts: economy.rules.frostPrincipalOptions,
      enabled: (amount) =>
          _dayReady && EconomyActions.spendingBlock(economy, amount) == null,
    );
    if (amount != null && mounted) {
      await _execute(EconomyActions.openFrost(economy, amount));
    }
  }

  Future<int?> _chooseAmount({
    required String title,
    required String hint,
    required List<int> amounts,
    required bool Function(int amount) enabled,
  }) => showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.cardBg,
    builder: (context) {
      final anyEnabled = amounts.any(enabled);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.xxs),
              Text(hint, style: AppTextStyles.supporting),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  const perRow = 3;
                  final width =
                      (constraints.maxWidth - AppSpacing.sm * (perRow - 1)) /
                      perRow;
                  return Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final amount in amounts)
                        SizedBox(
                          width: width,
                          child: _AmountChoice(
                            amount: amount,
                            onTap: enabled(amount)
                                ? () => Navigator.pop(context, amount)
                                : null,
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (!anyEnabled) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Сейчас не хватает монет. Выполни задание или дождись '
                  'следующего дня.',
                  style: AppTextStyles.supporting.copyWith(
                    color: AppColors.crimsonDark,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  Future<void> _redeem() async {
    final economy = _economy;
    if (economy?.goal == null) return;
    await _execute(EconomyActions.redeem(economy!));
    if (mounted && _economy?.goal == null) widget.onChooseGoal();
  }

  Future<void> _finishFrost(bool early) async {
    final economy = _economy;
    if (economy?.frost == null) return;
    await _execute(EconomyActions.finishFrost(economy!, early: early));
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
        message: _error ?? 'Не удалось загрузить Копилку.',
        onRetry: _load,
      );
    }

    final hasGoal = economy.goal != null;
    final String? transferNotice = !hasGoal
        ? 'Сначала выбери мечту — тогда монеты в копилке будут копиться на неё.'
        : !_dayReady
        ? 'Переводы откроются, когда начнёшь день и утвердишь план на главном экране.'
        : null;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.crimson,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    onBack: widget.onBack,
                    onOpenSettings: widget.onOpenSettings,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _BalanceSummary(
                    savings: economy.savings,
                    wallet: economy.wallet,
                    frozen: economy.frozen,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _GoalSection(
                    economy: economy,
                    busy: _busy,
                    onChoose: hasGoal
                        ? widget.onBrowseGoals
                        : widget.onChooseGoal,
                    onRedeem: _redeem,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (transferNotice != null) ...[
                    _Notice(message: transferNotice),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  _TransferActions(
                    onDeposit: _dayReady && hasGoal && !_busy
                        ? () => _moveSavings(true)
                        : null,
                    onWithdraw: _dayReady && economy.savings > 0 && !_busy
                        ? () => _moveSavings(false)
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.supporting.copyWith(
                        color: AppColors.crimsonDark,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _SavingsHistory(entries: economy.savingsHistory),
                  const SizedBox(height: AppSpacing.xl),
                  _FrostSection(
                    economy: economy,
                    busy: _busy,
                    dayReady: _dayReady,
                    onOpen: _openFrost,
                    onFinish: _finishFrost,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, this.onOpenSettings});

  final VoidCallback onBack;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        onPressed: onBack,
        tooltip: 'Вернуться домой',
        icon: const Icon(Icons.arrow_back, size: 28),
      ),
      Expanded(child: Text('Копилка', style: AppTextStyles.screenTitle)),
      IconButton(
        tooltip: 'Настройки',
        onPressed: onOpenSettings,
        icon: const Icon(Icons.settings_outlined, size: 28),
      ),
    ],
  );
}

/// The one number this screen is about, with the other two places coins can
/// be so the child sees where every coin sits.
class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({
    required this.savings,
    required this.wallet,
    required this.frozen,
  });

  final int savings;
  final int wallet;
  final int frozen;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.6)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MergeSemantics(
          child: Row(
            children: [
              Image.asset(
                'assets/icons/pig.webp',
                width: 56,
                height: 56,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('В копилке', style: AppTextStyles.supporting),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _coins(savings),
                      style: AppTextStyles.counterValue.copyWith(
                        fontSize: 30,
                        color: AppColors.leafGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            _BalanceChip(
              icon: Image.asset(
                'assets/icons/coin.webp',
                width: 20,
                height: 20,
                excludeFromSemantics: true,
              ),
              label: 'Кошелёк',
              value: wallet,
            ),
            if (frozen > 0)
              _BalanceChip(
                icon: const Icon(
                  Icons.ac_unit,
                  size: 18,
                  color: AppColors.frostBlue,
                ),
                label: 'В сундуке',
                value: frozen,
              ),
          ],
        ),
      ],
    ),
  );
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final Widget icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs - 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Flexible(
            child: Text.rich(
              TextSpan(
                text: '$label: ',
                style: AppTextStyles.supporting,
                children: [
                  TextSpan(
                    text: _coins(value),
                    style: AppTextStyles.cardRowLabel,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _coins(int value) {
  final mod100 = value % 100;
  final mod10 = value % 10;
  if (mod100 >= 11 && mod100 <= 14) return '$value монет';
  if (mod10 == 1) return '$value монета';
  if (mod10 >= 2 && mod10 <= 4) return '$value монеты';
  return '$value монет';
}

class _GoalSection extends StatelessWidget {
  const _GoalSection({
    required this.economy,
    required this.busy,
    required this.onChoose,
    required this.onRedeem,
  });

  final EconomyState economy;
  final bool busy;
  final VoidCallback onChoose;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final goal = economy.goal;
    final target = (goal?['target_amount'] as num?)?.toInt() ?? 0;
    final complete = target > 0 && economy.savings >= target;
    final goalImage = _goalImageAsset(goal, economy.artifacts);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Моя цель', style: AppTextStyles.sectionTitle),
            ),
            if (goal != null)
              TextButton.icon(
                onPressed: busy ? null : onChoose,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.crimsonDark,
                ),
                label: const Text('Все цели'),
                icon: const Icon(Icons.chevron_right),
                iconAlignment: IconAlignment.end,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (goal == null)
          _EmptyGoalCard(onChoose: busy ? null : onChoose)
        else
          _ActiveGoalCard(
            goal: goal,
            savings: economy.savings,
            target: target,
            complete: complete,
            imageAsset: goalImage,
            onRedeem: busy || economy.day?.planConfirmed != true
                ? null
                : onRedeem,
          ),
      ],
    );
  }
}

String? _goalImageAsset(
  Map<String, dynamic>? goal,
  List<EconomyItem> artifacts,
) {
  final direct = goal?['image_asset'] ?? goal?['imageAsset'];
  if (direct is String && direct.trim().isNotEmpty) return direct;
  final targetId = goal?['target_item_id'];
  for (final artifact in artifacts) {
    if (artifact.id == targetId && artifact.imageAsset != null) {
      return artifact.imageAsset;
    }
  }
  return targetId is String ? localItemArtwork[targetId] : null;
}

BoxDecoration _goalDecoration() => BoxDecoration(
  gradient: const LinearGradient(
    colors: [AppColors.goalSurface, AppColors.goalSurfaceDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  borderRadius: BorderRadius.circular(AppRadii.lg),
  border: Border.all(color: AppColors.goalBorder),
);

class _EmptyGoalCard extends StatelessWidget {
  const _EmptyGoalCard({this.onChoose});

  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: _goalDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: ItemArtwork(size: 88)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Выбери мечту',
          textAlign: TextAlign.center,
          style: AppTextStyles.cardTitle,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Артефакт из сказки, на который будешь копить. Монеты из копилки '
          'пойдут к нему.',
          textAlign: TextAlign.center,
          style: AppTextStyles.supporting,
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: onChoose,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.crimson,
            minimumSize: const Size.fromHeight(52),
            textStyle: AppTextStyles.button,
          ),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Выбрать мечту'),
        ),
      ],
    ),
  );
}

class _ActiveGoalCard extends StatelessWidget {
  const _ActiveGoalCard({
    required this.goal,
    required this.savings,
    required this.target,
    required this.complete,
    required this.imageAsset,
    this.onRedeem,
  });

  final Map<String, dynamic> goal;
  final int savings;
  final int target;
  final bool complete;
  final String? imageAsset;
  final VoidCallback? onRedeem;

  @override
  Widget build(BuildContext context) {
    final name = goal['name'] as String? ?? 'Моя мечта';
    final remaining = target > savings ? target - savings : 0;
    final progress = target <= 0 ? 0.0 : (savings / target).clamp(0.0, 1.0);
    final percent = (progress * 100).floor();
    final artwork = ItemArtwork(
      itemId: goal['target_item_id'] as String?,
      imageAsset: imageAsset,
      semanticLabel: name,
      size: 96,
    );
    final caption = Text(
      complete
          ? 'Цель накоплена! Можно забрать артефакт.'
          : 'Осталось накопить ${_coins(remaining)}',
      style: AppTextStyles.supporting.copyWith(
        color: complete ? AppColors.leafGreen : AppColors.inkMuted,
        fontWeight: complete ? FontWeight.w700 : FontWeight.w400,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _goalDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stack =
                  constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3;
              final title = Column(
                crossAxisAlignment: stack
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    textAlign: stack ? TextAlign.center : TextAlign.start,
                    style: AppTextStyles.sectionTitle,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  caption,
                ],
              );
              if (stack) {
                return Column(
                  children: [
                    artwork,
                    const SizedBox(height: AppSpacing.sm),
                    title,
                  ],
                );
              }
              return Row(
                children: [
                  artwork,
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: title),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            label:
                'Накоплено $savings из $target монет, $percent процентов цели',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: '$savings',
                          style: AppTextStyles.counterValue,
                          children: [
                            TextSpan(
                              text: ' из $target монет',
                              style: AppTextStyles.supporting,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '$percent%',
                      style: AppTextStyles.cardRowLabel.copyWith(
                        color: AppColors.leafGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progress),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 14,
                      color: AppColors.leafGreen,
                      backgroundColor: AppColors.progressTrack,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (complete) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRedeem,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.leafGreen,
                minimumSize: const Size.fromHeight(52),
                textStyle: AppTextStyles.button,
              ),
              icon: const Icon(Icons.redeem),
              label: const Text('Получить артефакт'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.infoBg,
      borderRadius: BorderRadius.circular(AppRadii.md),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: AppColors.coinGold, size: 22),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.supporting.copyWith(color: AppColors.ink),
          ),
        ),
      ],
    ),
  );
}

class _TransferActions extends StatelessWidget {
  const _TransferActions({this.onDeposit, this.onWithdraw});

  final VoidCallback? onDeposit;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final deposit = FilledButton.icon(
      onPressed: onDeposit,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.leafGreen,
        minimumSize: const Size.fromHeight(52),
        textStyle: AppTextStyles.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      icon: const Icon(Icons.add),
      label: const Text('Пополнить'),
    );
    final withdraw = OutlinedButton.icon(
      onPressed: onWithdraw,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(52),
        textStyle: AppTextStyles.button,
        side: const BorderSide(color: AppColors.fieldBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      icon: const Icon(Icons.undo),
      label: const Text('Вернуть'),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              deposit,
              const SizedBox(height: AppSpacing.xs),
              withdraw,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: deposit),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: withdraw),
          ],
        );
      },
    );
  }
}

class _AmountChoice extends StatelessWidget {
  const _AmountChoice({required this.amount, this.onTap});

  final int amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final available = onTap != null;
    return Semantics(
      hint: available ? null : 'Сейчас недоступно',
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          disabledForegroundColor: AppColors.inkMuted.withValues(alpha: 0.55),
          backgroundColor: available ? AppColors.goalSurface : null,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          textStyle: AppTextStyles.cardRowLabel,
          side: BorderSide(
            color: available
                ? AppColors.goalBorder
                : AppColors.fieldBorder.withValues(alpha: 0.5),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!available) ...[
              const Icon(Icons.lock_outline, size: 16),
              const SizedBox(width: AppSpacing.xxs),
            ],
            Flexible(child: Text(_coins(amount), maxLines: 1, softWrap: false)),
          ],
        ),
      ),
    );
  }
}

/// Shows how the savings balance got to where it is, newest first.
class _SavingsHistory extends StatelessWidget {
  const _SavingsHistory({required this.entries});

  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Как менялась копилка', style: AppTextStyles.sectionTitle),
      const SizedBox(height: AppSpacing.xs),
      Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: AppColors.fieldBorder.withValues(alpha: 0.6),
          ),
        ),
        child: entries.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Пока пусто. Здесь появятся монеты, которые ты отложишь или '
                  'вернёшь.',
                  style: AppTextStyles.supporting,
                ),
              )
            : Column(
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        indent: AppSpacing.md,
                        endIndent: AppSpacing.md,
                      ),
                    _HistoryRow(entry: entries[i]),
                  ],
                ],
              ),
      ),
    ],
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final Map<String, dynamic> entry;

  String get _label => switch (entry['event_type']) {
    'SAVINGS_DEPOSIT' when entry['from_plan'] == true =>
      'Отложено по плану дня',
    'SAVINGS_DEPOSIT' => 'Пополнение копилки',
    'SAVINGS_WITHDRAWAL' => 'Возвращено в кошелёк',
    'GOAL_REDEMPTION' => 'Обмен на артефакт',
    _ => 'Изменение копилки',
  };

  @override
  Widget build(BuildContext context) {
    final delta = (entry['delta_amount'] as num?)?.toInt() ?? 0;
    final after = (entry['balance_after'] as num?)?.toInt() ?? 0;
    final income = delta > 0;
    final color = income ? AppColors.leafGreen : AppColors.crimsonDark;
    final when = _formatWhen(entry['occurred_at']);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                income ? Icons.south_west : Icons.north_east,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_label, style: AppTextStyles.cardRowLabel),
                  if (when != null)
                    Text(when, style: AppTextStyles.stepCounter),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${income ? '+' : '−'}${delta.abs()}',
                  style: AppTextStyles.cardRowLabel.copyWith(color: color),
                ),
                Text('итого $after', style: AppTextStyles.stepCounter),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String? _formatWhen(Object? raw) {
  if (raw is! String) return null;
  final time = DateTime.tryParse(raw)?.toLocal();
  if (time == null) return null;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(time.day)}.${two(time.month)} в ${two(time.hour)}:${two(time.minute)}';
}

class _FrostSection extends StatelessWidget {
  const _FrostSection({
    required this.economy,
    required this.busy,
    required this.dayReady,
    required this.onOpen,
    required this.onFinish,
  });

  final EconomyState economy;
  final bool busy;
  final bool dayReady;
  final VoidCallback onOpen;
  final Future<void> Function(bool early) onFinish;

  @override
  Widget build(BuildContext context) {
    final chest = economy.frost;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.frostSurface, AppColors.frostSurfaceDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.frostBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: Image.asset(
                  'assets/images/morozko_chest.webp',
                  fit: BoxFit.contain,
                  semanticLabel: 'Синий зимний сундук Морозко',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Сундук Морозко', style: AppTextStyles.sectionTitle),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      chest == null
                          ? 'Заморозь монеты на несколько дней — вернутся с бонусом.'
                          : 'Монеты заморожены и ждут своего дня.',
                      style: AppTextStyles.supporting,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (chest == null)
            _ClosedFrostDetails(
              rules: economy.rules,
              enabled: !busy && dayReady,
              dayReady: dayReady,
              onOpen: onOpen,
            )
          else
            _OpenFrostDetails(
              chest: chest,
              rules: economy.rules,
              busy: busy,
              onFinish: onFinish,
            ),
        ],
      ),
    );
  }
}

class _ClosedFrostDetails extends StatelessWidget {
  const _ClosedFrostDetails({
    required this.rules,
    required this.enabled,
    required this.dayReady,
    required this.onOpen,
  });

  final EconomyRules rules;
  final bool enabled;
  final bool dayReady;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _FrostFact(
              value: '${rules.frostMinimum}–${rules.frostMaximum}',
              label: 'монет вклад',
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _FrostFact(
              value: '${rules.frostDays}',
              label: _gameDaysLabel(rules.frostDays)
                  .split(' ')
                  .skip(1)
                  .join(' '),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _FrostFact(
              value: '+${rules.frostBonusPercent}%',
              label: 'бонус',
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      FilledButton.icon(
        onPressed: enabled ? onOpen : null,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: AppColors.frostBlue,
          textStyle: AppTextStyles.button,
        ),
        icon: const Icon(Icons.ac_unit),
        label: const Text('Открыть сундук'),
      ),
      if (!dayReady) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Сундук можно открыть после начала дня.',
          textAlign: TextAlign.center,
          style: AppTextStyles.stepCounter,
        ),
      ],
    ],
  );
}

class _OpenFrostDetails extends StatelessWidget {
  const _OpenFrostDetails({
    required this.chest,
    required this.rules,
    required this.busy,
    required this.onFinish,
  });

  final Map<String, dynamic> chest;
  final EconomyRules rules;
  final bool busy;
  final Future<void> Function(bool early) onFinish;

  @override
  Widget build(BuildContext context) {
    final principal = (chest['principal_amount'] as num?)?.toInt() ?? 0;
    final bonus = (chest['bonus_amount'] as num?)?.toInt() ?? 0;
    final completed = (chest['completed_days'] as num?)?.toInt() ?? 0;
    final remaining = (chest['days_remaining'] as num?)?.toInt() ?? 0;
    final maturityDays =
        (chest['maturity_days'] as num?)?.toInt() ?? rules.frostDays;
    final matured = chest['matured'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                matured ? 'Сундук готов!' : 'Внутри ${_coins(principal)}',
                style: AppTextStyles.cardTitle,
              ),
            ),
            Text(
              '+$bonus бонус',
              style: AppTextStyles.cardRowLabel.copyWith(
                color: AppColors.frostBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: 'Прошло $completed из $maturityDays игровых дней',
          excludeSemantics: true,
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (var day = 0; day < maturityDays; day++)
                _FrostDay(done: day < completed),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          matured
              ? 'Срок вышел — можно забирать с бонусом.'
              : 'Осталось ${_gameDaysLabel(remaining)}',
          style: AppTextStyles.supporting,
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Text(
            'В конце вернётся ${_coins(principal + bonus)}',
            style: AppTextStyles.cardRowLabel.copyWith(
              color: AppColors.leafGreen,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (matured)
          FilledButton(
            onPressed: busy ? null : () => onFinish(false),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.frostBlue,
              textStyle: AppTextStyles.button,
            ),
            child: Text('Забрать ${_coins(principal + bonus)}'),
          )
        else
          OutlinedButton(
            onPressed: busy ? null : () => onFinish(true),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.crimsonDark,
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: AppColors.crimsonFaded),
            ),
            child: const Text('Вернуть сейчас без бонуса'),
          ),
      ],
    );
  }
}

class _FrostDay extends StatelessWidget {
  const _FrostDay({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: done ? AppColors.frostDone : AppColors.frostIdle,
    ),
    child: Icon(
      Icons.ac_unit,
      size: 19,
      color: done ? Colors.white : AppColors.frostIdleIcon,
    ),
  );
}

class _FrostFact extends StatelessWidget {
  const _FrostFact({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: AppTextStyles.sectionTitle.copyWith(
              color: AppColors.frostBlue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.stepCounter,
          ),
        ],
      ),
    ),
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
