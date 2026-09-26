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
    final amount = await _chooseAmount(
      title: deposit ? 'Пополнить копилку' : 'Вернуть в кошелёк',
      amounts: const [5, 10],
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
    final amount = await _chooseAmount(
      title: 'Сколько положить в сундук?',
      amounts: const [10, 20, 30, 40, 50],
      enabled: (amount) =>
          _dayReady && EconomyActions.spendingBlock(economy, amount) == null,
    );
    if (amount != null && mounted) {
      await _execute(EconomyActions.openFrost(economy, amount));
    }
  }

  Future<int?> _chooseAmount({
    required String title,
    required List<int> amounts,
    required bool Function(int amount) enabled,
  }) => showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTextStyles.sectionTitle),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final amount in amounts)
                  SizedBox(
                    width: 92,
                    child: OutlinedButton(
                      onPressed: enabled(amount)
                          ? () => Navigator.pop(context, amount)
                          : null,
                      child: Text('$amount монет'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
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

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.crimson,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    wallet: economy.wallet,
                    onBack: widget.onBack,
                    onOpenSettings: widget.onOpenSettings,
                  ),
                  const SizedBox(height: 18),
                  _GoalSection(
                    economy: economy,
                    busy: _busy,
                    onChoose: economy.goal == null
                        ? widget.onChooseGoal
                        : widget.onBrowseGoals,
                    onRedeem: _redeem,
                  ),
                  const SizedBox(height: 14),
                  _SavingsPrimaryAction(
                    onTap: _dayReady && economy.goal != null
                        ? () => _moveSavings(true)
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _SavingsReturnAction(
                    onTap: _dayReady && economy.savings > 0
                        ? () => _moveSavings(false)
                        : null,
                  ),
                  if (!_dayReady) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Переводы станут доступны после начала дня и подтверждения плана.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.supporting,
                    ),
                  ],
                  const SizedBox(height: 18),
                  _FrostSection(
                    economy: economy,
                    busy: _busy,
                    dayReady: _dayReady,
                    onOpen: _openFrost,
                    onFinish: _finishFrost,
                  ),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.wallet,
    required this.onBack,
    this.onOpenSettings,
  });

  final VoidCallback? onOpenSettings;

  final int wallet;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth < 360 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.15;
      final navigation = Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Вернуться домой',
            icon: const Icon(Icons.arrow_back, size: 30),
          ),
          Expanded(child: Text('Копилка', style: AppTextStyles.screenTitle)),
          if (!compact) _WalletPill(wallet: wallet),
          IconButton(
            tooltip: 'Настройки',
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined, size: 30),
          ),
        ],
      );
      if (!compact) return navigation;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          navigation,
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _WalletPill(wallet: wallet),
          ),
        ],
      );
    },
  );
}

class _WalletPill extends StatelessWidget {
  const _WalletPill({required this.wallet});

  final int wallet;

  @override
  Widget build(BuildContext context) => Container(
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
        Text('$wallet монет', style: AppTextStyles.cardRowLabel),
      ],
    ),
  );
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
            Expanded(child: Text('Моя цель', style: AppTextStyles.screenTitle)),
            TextButton.icon(
              onPressed: busy ? null : onChoose,
              label: Text(goal == null ? 'Выбрать' : 'Все цели'),
              icon: const Icon(Icons.chevron_right),
              iconAlignment: IconAlignment.end,
            ),
          ],
        ),
        const SizedBox(height: 8),
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

class _EmptyGoalCard extends StatelessWidget {
  const _EmptyGoalCard({this.onChoose});

  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFF0D2),
    borderRadius: BorderRadius.circular(AppRadii.lg),
    child: InkWell(
      onTap: onChoose,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const ItemArtwork(size: 92),
            const SizedBox(height: 12),
            Text(
              'Сначала выбери мечту для Копилки',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
          ],
        ),
      ),
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
    final remaining = target > savings ? target - savings : 0;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          goal['name'] as String? ?? 'Моя мечта',
          style: AppTextStyles.cardTitle,
        ),
        const SizedBox(height: 14),
        LinearProgressIndicator(
          value: target <= 0 ? 0 : (savings / target).clamp(0, 1).toDouble(),
          minHeight: 12,
          borderRadius: BorderRadius.circular(999),
          color: AppColors.leafGreen,
          backgroundColor: const Color(0xFFEAD7B5),
        ),
        const SizedBox(height: 8),
        Text('$savings / $target монет', style: AppTextStyles.counterValue),
        const SizedBox(height: 4),
        Text(
          complete ? 'Цель накоплена!' : 'Осталось накопить $remaining монет',
          style: AppTextStyles.supporting,
        ),
        if (complete) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRedeem,
            child: const Text('Получить артефакт'),
          ),
        ],
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4DC), Color(0xFFFFE9BD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: const Color(0xFFEBCB91)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack =
              constraints.maxWidth < 330 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.2;
          if (stack) {
            return Column(
              children: [
                ItemArtwork(
                  itemId: goal['target_item_id'] as String?,
                  imageAsset: imageAsset,
                  semanticLabel: goal['name'] as String?,
                  size: 128,
                ),
                const SizedBox(height: 16),
                details,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ItemArtwork(
                itemId: goal['target_item_id'] as String?,
                imageAsset: imageAsset,
                semanticLabel: goal['name'] as String?,
                size: 132,
              ),
              const SizedBox(width: 18),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF4FBFF), Color(0xFFDDEFF9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: const Color(0xFFC8E0EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFDCEFF8),
                child: Icon(Icons.ac_unit, color: Color(0xFF337AAA)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Сундук Морозко', style: AppTextStyles.sectionTitle),
                    Text(
                      'Сохраняй монеты и получай бонус!',
                      style: AppTextStyles.supporting,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          const SizedBox(height: 10),
          _FrostBody(
            chest: chest,
            busy: busy,
            dayReady: dayReady,
            onOpen: onOpen,
            onFinish: onFinish,
          ),
        ],
      ),
    );
  }
}

class _FrostBody extends StatelessWidget {
  const _FrostBody({
    required this.chest,
    required this.busy,
    required this.dayReady,
    required this.onOpen,
    required this.onFinish,
  });

  final Map<String, dynamic>? chest;
  final bool busy;
  final bool dayReady;
  final VoidCallback onOpen;
  final Future<void> Function(bool early) onFinish;

  @override
  Widget build(BuildContext context) {
    final data = chest;
    final details = data == null
        ? _ClosedFrostDetails(enabled: !busy && dayReady, onOpen: onOpen)
        : _OpenFrostDetails(chest: data, busy: busy, onFinish: onFinish);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 330 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.2;
        final art = Image.asset(
          'assets/images/morozko_chest.png',
          fit: BoxFit.contain,
          semanticLabel: 'Синий зимний сундук Морозко',
        );
        if (stack) {
          return Column(
            children: [
              SizedBox(height: 180, child: art),
              const SizedBox(height: 8),
              details,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 5, child: art),
            const SizedBox(width: 12),
            Expanded(flex: 6, child: details),
          ],
        );
      },
    );
  }
}

class _ClosedFrostDetails extends StatelessWidget {
  const _ClosedFrostDetails({required this.enabled, required this.onOpen});

  final bool enabled;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        children: [
          _FrostFact(label: 'Вклад', value: '10–50'),
          _FrostFact(label: 'Срок', value: '5 дней'),
          _FrostFact(label: 'Бонус', value: '+10%'),
        ],
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: enabled ? onOpen : null,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: const Color(0xFF337FB4),
        ),
        icon: const Icon(Icons.ac_unit),
        label: const Text('Открыть сундук'),
      ),
    ],
  );
}

class _OpenFrostDetails extends StatelessWidget {
  const _OpenFrostDetails({
    required this.chest,
    required this.busy,
    required this.onFinish,
  });

  final Map<String, dynamic> chest;
  final bool busy;
  final Future<void> Function(bool early) onFinish;

  @override
  Widget build(BuildContext context) {
    final principal = (chest['principal_amount'] as num?)?.toInt() ?? 0;
    final bonus = (chest['bonus_amount'] as num?)?.toInt() ?? 0;
    final completed = (chest['completed_days'] as num?)?.toInt() ?? 0;
    final remaining = (chest['days_remaining'] as num?)?.toInt() ?? 0;
    final matured = chest['matured'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          matured ? 'Сундук готов!' : 'Сундук закрыт',
          style: AppTextStyles.cardTitle,
        ),
        Text('$principal монет внутри', style: AppTextStyles.supporting),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var day = 0; day < 5; day++) _FrostDay(done: day < completed),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          matured
              ? 'Можно забрать с бонусом'
              : 'Осталось ${_gameDaysLabel(remaining)}',
          style: AppTextStyles.supporting,
        ),
        const Divider(height: 22),
        Text(
          'Получишь в конце: ${principal + bonus} монет',
          style: AppTextStyles.cardRowLabel.copyWith(
            color: AppColors.leafGreen,
          ),
        ),
        const SizedBox(height: 14),
        if (matured)
          FilledButton(
            onPressed: busy ? null : () => onFinish(false),
            child: Text('Забрать ${principal + bonus} монет'),
          )
        else
          OutlinedButton(
            onPressed: busy ? null : () => onFinish(true),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.crimson,
              minimumSize: const Size.fromHeight(48),
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
      color: done ? const Color(0xFF4A9BCB) : const Color(0xFFD1E3EE),
    ),
    child: Icon(
      Icons.ac_unit,
      size: 19,
      color: done ? Colors.white : const Color(0xFF9AB8C9),
    ),
  );
}

class _FrostFact extends StatelessWidget {
  const _FrostFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: AppTextStyles.supporting),
      const SizedBox(height: 4),
      Text(value, style: AppTextStyles.sectionTitle),
    ],
  );
}

class _SavingsPrimaryAction extends StatelessWidget {
  const _SavingsPrimaryAction({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: onTap == null
        ? AppColors.leafGreen.withValues(alpha: 0.42)
        : AppColors.leafGreen,
    borderRadius: BorderRadius.circular(AppRadii.lg),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.leafGreen,
              child: Icon(Icons.add),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Пополнить копилку',
                textAlign: TextAlign.center,
                style: AppTextStyles.cardTitle.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SavingsReturnAction extends StatelessWidget {
  const _SavingsReturnAction({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      foregroundColor: AppColors.inkMuted,
      side: const BorderSide(color: AppColors.fieldBorder),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
    ),
    icon: const Icon(Icons.undo),
    label: const Text('Вернуть монеты из копилки'),
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
