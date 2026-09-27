import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../economy/economy_state.dart';
import '../theme/app_theme.dart';
import 'insurance_service.dart';

const insurancePrice = 5;

class InsuranceScreen extends StatefulWidget {
  const InsuranceScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends State<InsuranceScreen>
    with SingleTickerProviderStateMixin {
  late final InsuranceService _service = InsuranceService(widget.apiClient);
  late final AnimationController _auraController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  EconomyState? _economy;
  String? _error;
  bool _loading = true;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _auraController
        ..stop()
        ..value = 0.5;
    } else if (!_auraController.isAnimating) {
      _auraController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _auraController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final json = await widget.apiClient.get('/economy/state');
      if (!mounted) return;
      setState(() {
        _economy = EconomyState.fromJson(json);
        _error = null;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _error = 'Не удалось узнать состояние защиты.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buy() async {
    final economy = _economy;
    final plan = economy?.currentPlan;
    if (economy == null || _buying || economy.isInsuredForNextDay) return;
    if (plan?.planConfirmed != true) {
      _showMessage('Сначала утверди план на сегодняшний день.');
      return;
    }
    if (economy.wallet < insurancePrice) {
      _showMessage(
        'Не хватает ${insurancePrice - economy.wallet} монет. Выполни задание и возвращайся.',
      );
      return;
    }

    final exceedsPlan = plan!.actualNeed + insurancePrice > plan.need;
    if (exceedsPlan) {
      final confirmed = await _confirmPlanOverrun();
      if (confirmed != true || !mounted) return;
    }

    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _buying = true;
      _error = null;
    });
    try {
      final purchased = await _service.purchaseInsurance();
      if (!purchased || !mounted) return;
      await _load();
      if (mounted) {
        _showMessage('Защита на следующий игровой день активна.');
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'insurance_already_purchased_for_next_day' =>
          'Защита на завтра уже действует.',
        'insufficient_funds' =>
          'Монет уже не хватает. Обнови баланс и попробуй снова.',
        _ => 'Не удалось купить защиту. Попробуй ещё раз.',
      };
      setState(() => _error = message);
      _showMessage(message);
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<bool?> _confirmPlanOverrun() => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.cardBg,
      icon: const Icon(Icons.info_outline, color: AppColors.amber, size: 34),
      title: const Text('Покупка выше плана'),
      content: const Text(
        'Это превысит запланированные траты на «Надо». Всё равно купить?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Не сейчас'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.forestDeep),
          child: const Text('Всё равно купить'),
        ),
      ],
    ),
  );

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final economy = _economy;
    return Scaffold(
      backgroundColor: AppColors.parchmentLight,
      appBar: AppBar(
        backgroundColor: AppColors.parchmentLight,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        title: const Text('Стол подорожника'),
        actions: [
          if (economy != null)
            Semantics(
              label: 'В кошельке ${economy.wallet} монет',
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: _BalancePill(wallet: economy.wallet),
              ),
            ),
        ],
      ),
      body: _loading && economy == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.forestDeep),
            )
          : economy == null
          ? _LoadError(message: _error, onRetry: _load)
          : RefreshIndicator(
              color: AppColors.forestDeep,
              onRefresh: _load,
              child: _Content(
                economy: economy,
                auraController: _auraController,
                buying: _buying,
                error: _error,
                onBuy: _buy,
              ),
            ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.economy,
    required this.auraController,
    required this.buying,
    required this.error,
    required this.onBuy,
  });

  final EconomyState economy;
  final Animation<double> auraController;
  final bool buying;
  final String? error;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = economy.isInsuredForNextDay;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        _PlantainArtwork(animation: auraController, active: active),
        const SizedBox(height: AppSpacing.lg),
        _ProtectionCard(active: active, petName: economy.petName),
        const SizedBox(height: AppSpacing.md),
        const _OracleCard(),
        const SizedBox(height: AppSpacing.md),
        _PriceCard(wallet: economy.wallet),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          button: true,
          enabled: !active && !buying,
          label: active
              ? 'Защита на завтра уже действует'
              : 'Купить защиту на завтра за 5 монет',
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              key: const Key('insurance-purchase'),
              onPressed: active || buying ? null : onBuy,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forestDeep,
                disabledBackgroundColor: active
                    ? AppColors.protectionTint
                    : theme.disabledColor.withValues(alpha: 0.18),
                disabledForegroundColor: active
                    ? AppColors.forestDeep
                    : theme.disabledColor,
                side: active
                    ? const BorderSide(color: AppColors.forestDeep)
                    : null,
              ),
              icon: buying
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(active ? Icons.check : Icons.shield_outlined),
              label: Text(
                active
                    ? 'Защита на завтра уже действует'
                    : 'Купить защиту на завтра за 5 🪙',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          button: true,
          label: 'Вернуться в магазин без покупки',
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(active),
            child: const Text('Пройти мимо / Вернуться в магазин'),
          ),
        ),
      ],
    );
  }
}

class _PlantainArtwork extends StatelessWidget {
  const _PlantainArtwork({required this.animation, required this.active});

  final Animation<double> animation;
  final bool active;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Светящийся лист подорожника в защитном щите',
    child: SizedBox(
      height: 190,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final value = animation.value;
          return Transform.translate(
            offset: Offset(0, -4 * value),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 154 + value * 10,
                  height: 154 + value * 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.amber.withValues(alpha: 0.08),
                    border: Border.all(
                      color: AppColors.amber.withValues(
                        alpha: active ? 0.75 : 0.38,
                      ),
                      width: 5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.amber.withValues(
                          alpha: 0.12 + value * 0.12,
                        ),
                        blurRadius: 24,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.shield_outlined,
                  size: 142,
                  color: AppColors.amber.withValues(alpha: 0.68),
                ),
                Image.asset('assets/icons/leaf.png', width: 105, height: 105),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _ProtectionCard extends StatelessWidget {
  const _ProtectionCard({required this.active, required this.petName});

  final bool active;
  final String petName;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: active ? 'Защита активна на завтра' : 'На завтра защиты нет',
    child: _StoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusBadge(active: active),
          const SizedBox(height: AppSpacing.md),
          const Text('Защита на завтра', style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.sm),
          _FactRow(
            icon: Icons.check_circle,
            color: AppColors.forestDeep,
            text:
                'Со страховкой: если $petName завтра простудится, уход оплатит защита, а здоровье останется 100%.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _FactRow(
            icon: Icons.radio_button_unchecked,
            color: AppColors.inkMuted,
            text: 'Без страховки: если случится неприятность, придётся экстренно потратить 10–15 монет на лекарства.',
          ),
        ],
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: active ? AppColors.protectionTint : AppColors.neutralTint,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.shield : Icons.warning_amber_rounded,
            size: 19,
            color: active ? AppColors.forestDeep : AppColors.inkMuted,
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Защита активна' : 'Без защиты',
            style: AppTextStyles.cardRowLabel.copyWith(
              color: active ? AppColors.forestDeep : AppColors.inkMuted,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(text, style: AppTextStyles.story.copyWith(fontSize: 16)),
      ),
    ],
  );
}

class _OracleCard extends StatelessWidget {
  const _OracleCard();

  @override
  Widget build(BuildContext context) => _StoryCard(
    color: AppColors.infoBg,
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.cloud_outlined, color: AppColors.amber, size: 28),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Синоптики леса обещают прохладный день с дождём — защита может пригодиться!',
            style: AppTextStyles.story,
          ),
        ),
      ],
    ),
  );
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.wallet});

  final int wallet;

  @override
  Widget build(BuildContext context) => _StoryCard(
    child: Row(
      children: [
        const Icon(Icons.local_offer_outlined, color: AppColors.forestDeep),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Цена: 5 🪙', style: AppTextStyles.cardTitle),
              Text('Категория «Надо»', style: AppTextStyles.supporting),
            ],
          ),
        ),
        Text(
          'Останется\n${(wallet - insurancePrice).clamp(0, wallet)} 🪙',
          textAlign: TextAlign.right,
          style: AppTextStyles.cardRowLabel,
        ),
      ],
    ),
  );
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.child, this.color = AppColors.cardBg});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    color: color,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      side: const BorderSide(color: AppColors.fieldBorder),
    ),
    child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: child),
  );
}

class _BalancePill extends StatelessWidget {
  const _BalancePill({required this.wallet});

  final int wallet;

  @override
  Widget build(BuildContext context) => Center(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icons/coin.png', width: 22, height: 22),
            const SizedBox(width: 5),
            Text('$wallet монет', style: AppTextStyles.cardRowLabel),
          ],
        ),
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message ?? 'Не удалось загрузить экран.'),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    ),
  );
}
