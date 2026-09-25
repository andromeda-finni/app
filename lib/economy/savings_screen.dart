import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../theme/app_theme.dart';
import 'economy_action_ui.dart';
import 'economy_actions.dart';
import 'economy_state.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({
    super.key,
    required this.apiClient,
    required this.onBack,
  });

  final ApiClient apiClient;
  final VoidCallback onBack;

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

  Future<void> _chooseGoal() async {
    final economy = _economy;
    if (economy == null || _busy) return;
    if (economy.goal != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Текущая цель закреплена до получения артефакта.'),
        ),
      );
      return;
    }
    final selected = await showModalBottomSheet<EconomyItem>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Выбери новую мечту', style: AppTextStyles.screenTitle),
                const SizedBox(height: 12),
                Expanded(
                  child: economy.artifacts.isEmpty
                      ? const Align(
                          alignment: Alignment.topLeft,
                          child: Text('Все доступные артефакты уже получены.'),
                        )
                      : ListView(
                          children: [
                            for (final item in economy.artifacts)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.parchment,
                                  child: Icon(
                                    Icons.auto_awesome,
                                    color: AppColors.coinGold,
                                  ),
                                ),
                                title: Text(item.name),
                                subtitle: Text('${item.price} монет'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.pop(context, item),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      await _execute(EconomyActions.goal(economy, selected));
    }
  }

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
    if (mounted) await _chooseGoal();
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
                  _Header(wallet: economy.wallet, onBack: widget.onBack),
                  const SizedBox(height: 18),
                  _GoalSection(
                    economy: economy,
                    busy: _busy,
                    onChoose: _chooseGoal,
                    onRedeem: _redeem,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MainAction(
                          label: 'Пополнить\nкопилку',
                          icon: Icons.add,
                          primary: true,
                          onTap: _dayReady && economy.goal != null
                              ? () => _moveSavings(true)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MainAction(
                          label: 'Вернуть\nиз копилки',
                          icon: Icons.remove,
                          onTap: _dayReady && economy.savings > 0
                              ? () => _moveSavings(false)
                              : null,
                        ),
                      ),
                    ],
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
                  const SizedBox(height: 18),
                  _QuickActions(
                    onDeposit: _dayReady && economy.goal != null
                        ? () => _moveSavings(true)
                        : null,
                    onWithdraw: _dayReady && economy.savings > 0
                        ? () => _moveSavings(false)
                        : null,
                    onFrost: _dayReady && economy.frost == null
                        ? _openFrost
                        : null,
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
  const _Header({required this.wallet, required this.onBack});

  final int wallet;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        onPressed: onBack,
        tooltip: 'Вернуться домой',
        icon: const Icon(Icons.arrow_back, size: 30),
      ),
      Expanded(child: Text('Копилка', style: AppTextStyles.screenTitle)),
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
            Text('$wallet монет', style: AppTextStyles.cardRowLabel),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Настройки',
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Настройки появятся позднее.')),
        ),
        icon: const Icon(Icons.settings_outlined, size: 30),
      ),
    ],
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
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Моя цель', style: AppTextStyles.screenTitle),
              ),
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
            InkWell(
              onTap: busy ? null : onChoose,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 48,
                      color: AppColors.coinGold,
                    ),
                    SizedBox(height: 8),
                    Text('Сначала выбери мечту для Копилки.'),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.canvasWarm,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 38,
                    backgroundColor: AppColors.parchment,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 36,
                      color: AppColors.coinGold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          goal['name'] as String,
                          style: AppTextStyles.sectionTitle,
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: (economy.savings / target)
                              .clamp(0, 1)
                              .toDouble(),
                          minHeight: 12,
                          borderRadius: BorderRadius.circular(999),
                          color: AppColors.leafGreen,
                          backgroundColor: AppColors.parchmentDark,
                        ),
                        const SizedBox(height: 8),
                        Text('${economy.savings} / $target монет'),
                        if (complete) ...[
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed:
                                busy || economy.day?.planConfirmed != true
                                ? null
                                : onRedeem,
                            child: const Text('Получить артефакт'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
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
    return _SectionCard(
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
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F3F8),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: chest == null
                ? Column(
                    children: [
                      const Row(
                        children: [
                          Expanded(
                            child: _FrostFact(label: 'Вклад', value: '10–50'),
                          ),
                          Expanded(
                            child: _FrostFact(label: 'Срок', value: '5 дней'),
                          ),
                          Expanded(
                            child: _FrostFact(label: 'Бонус', value: '+10%'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: busy || !dayReady ? null : onOpen,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: const Color(0xFF3D8CC4),
                        ),
                        icon: const Icon(Icons.ac_unit),
                        label: const Text('Открыть сундук'),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _FrostFact(
                              label: 'Вложено',
                              value: '${chest['principal_amount']}',
                            ),
                          ),
                          Expanded(
                            child: _FrostFact(
                              label: 'Осталось',
                              value: '${chest['days_remaining']} дн.',
                            ),
                          ),
                          Expanded(
                            child: _FrostFact(
                              label: 'Бонус',
                              value: '+${chest['bonus_amount']}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (chest['matured'] == true)
                        FilledButton(
                          onPressed: busy ? null : () => onFinish(false),
                          child: Text(
                            'Забрать ${chest['principal_amount'] + chest['bonus_amount']} монет',
                          ),
                        )
                      else
                        OutlinedButton(
                          onPressed: busy ? null : () => onFinish(true),
                          child: const Text('Вернуть сейчас без бонуса'),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FrostFact extends StatelessWidget {
  const _FrostFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: AppTextStyles.supporting),
      const SizedBox(height: 4),
      Text(value, style: AppTextStyles.sectionTitle),
    ],
  );
}

class _MainAction extends StatelessWidget {
  const _MainAction({
    required this.label,
    required this.icon,
    this.primary = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: onTap == null
        ? AppColors.parchment.withValues(alpha: 0.5)
        : primary
        ? AppColors.leafGreen
        : AppColors.parchment,
    borderRadius: BorderRadius.circular(AppRadii.lg),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.cardBg,
              foregroundColor: primary ? AppColors.leafGreen : AppColors.ink,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: primary ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({this.onDeposit, this.onWithdraw, this.onFrost});

  final VoidCallback? onDeposit;
  final VoidCallback? onWithdraw;
  final VoidCallback? onFrost;

  @override
  Widget build(BuildContext context) => _SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Быстрые действия', style: AppTextStyles.screenTitle),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            final actions = [
              _QuickAction(
                icon: Icons.add,
                title: 'Пополнить',
                caption: 'Из кошелька',
                onTap: onDeposit,
              ),
              _QuickAction(
                icon: Icons.remove,
                title: 'Вернуть',
                caption: 'В кошелёк',
                onTap: onWithdraw,
              ),
              _QuickAction(
                icon: Icons.ac_unit,
                title: 'Сундук',
                caption: 'Бонус +10%',
                onTap: onFrost,
              ),
            ];
            if (compact) {
              return Column(
                children: [
                  for (final action in actions) ...[
                    action,
                    if (action != actions.last) const SizedBox(height: 8),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  Expanded(child: actions[i]),
                  if (i < actions.length - 1) const SizedBox(width: 8),
                ],
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.caption,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.canvasWarm,
    borderRadius: BorderRadius.circular(AppRadii.md),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: icon == Icons.ac_unit
                  ? const Color(0xFFDCEFF8)
                  : AppColors.parchment,
              child: Icon(icon),
            ),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: AppTextStyles.supporting,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

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
