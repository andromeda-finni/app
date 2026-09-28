import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../day_summary/day_summary.dart';
import '../day_summary/day_summary_screen.dart';
import '../events/pet_event_dialog.dart';
import '../events/pet_event_indicator.dart';
import '../events/pet_event_models.dart';
import '../services/pet_event_service.dart';
import '../theme/app_theme.dart';
import 'models/home_economy_state.dart';
import 'pet_care_screen.dart';
import 'widgets/budget_plan_card.dart';
import 'widgets/coin_distribution_sheet.dart';
import 'widgets/dream_card.dart';
import 'widgets/pet_name_header.dart';
import 'widgets/pet_scene.dart';
import 'widgets/parent_tasks_card.dart';

enum _LoadState { loading, ready, error }

/// The game-day home. Pet care intentionally lives on [PetCareScreen].
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.apiClient,
    this.onChooseGoal,
    this.onOpenShop,
    this.onOpenQuests,
    this.onOpenSettings,
    this.onOpenInsurance,
    this.onPlanningRequiredChanged,
    this.refreshSignal = 0,
  });

  final ApiClient apiClient;
  final VoidCallback? onChooseGoal;
  final VoidCallback? onOpenShop;
  final VoidCallback? onOpenQuests;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenInsurance;
  final ValueChanged<bool>? onPlanningRequiredChanged;
  final int refreshSignal;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PetEventService _eventService = PetEventService(widget.apiClient);
  _LoadState _loadState = _LoadState.loading;
  HomeEconomyState? _data;
  bool _offline = false;
  bool _busy = false;
  bool _eventDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _load(showLoader: false);
    }
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader && _data == null) {
      setState(() => _loadState = _LoadState.loading);
    }
    try {
      final json = await widget.apiClient.get('/economy/state');
      final next = HomeEconomyState.fromJson(json);
      if (!mounted) return;
      setState(() {
        _data = next;
        _offline = false;
        _loadState = _LoadState.ready;
      });
      widget.onPlanningRequiredChanged?.call(
        next.activeDay != null && !next.activeDay!.isConfirmed,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_data == null) {
          _loadState = _LoadState.error;
        } else {
          _offline = true;
        }
      });
    }
  }

  Future<void> _rename(String name) async {
    final current = _data;
    if (current == null) return;
    final body = <String, dynamic>{
      'petName': name,
      'furOptionId': current.pet.furOptionId,
      if (current.pet.accessoryOptionId != null)
        'accessoryOptionId': current.pet.accessoryOptionId,
    };
    await widget.apiClient.put('/pet', body: body);
    if (!mounted) return;
    setState(
      () => _data = current.copyWith(pet: current.pet.copyWith(name: name)),
    );
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startDay() => _runMutation(() async {
    if (_data?.activeGoal == null) {
      widget.onChooseGoal?.call();
      return;
    }
    final response = await widget.apiClient.post('/periods');
    await _load(showLoader: false);
    if (!mounted) return;
    _showArtifactEffects(response['artifactEffects']);
    final insuranceNotice = response['insuranceNotice'] as String?;
    if (insuranceNotice != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(insuranceNotice)));
    }
    if (_data?.activeEvent != null) await _openEvent();
  });

  Future<HomeEconomyState> _equipArtifact(ArtifactItem item) async {
    await widget.apiClient.post(
      '/pet/equip',
      body: {'inventoryItemId': item.equipped ? null : item.id},
    );
    await _load(showLoader: false);
    return _data!;
  }

  Future<HomeEconomyState> _repairArtifact(ArtifactItem item) async {
    await widget.apiClient.post('/inventory/${item.id}/repair');
    await _load(showLoader: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«${item.name}» снова в полном порядке!')),
      );
    }
    return _data!;
  }

  void _showArtifactEffects(Object? rawEffects) {
    if (!mounted || rawEffects is! List || rawEffects.isEmpty) return;
    final first = rawEffects.first;
    if (first is! Map) return;
    final effectCode = first['effectCode'] as String?;
    final message = switch (effectCode) {
      'MAGIC_REMAINDER' => 'Кошель-самотряс: +2 монеты!',
      'NOURISHING_HOME' => 'Скатерть сохранила сытость питомца.',
      'COST_FORESIGHT' => 'Блюдечко показало прогноз затрат.',
      'SECOND_CHANCE' => 'Живая вода защитила питомца!',
      _ => 'Сработала способность артефакта!',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: AppColors.coinGold),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  PetEventOccurrence? _activeEvent(HomeEconomyState data) {
    final json = data.activeEvent;
    if (json == null) return null;
    try {
      return PetEventOccurrence.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  Future<void> _openEvent({PetEventOccurrence? event}) async {
    final data = _data;
    final active = event ?? (data == null ? null : _activeEvent(data));
    if (data == null || active == null || _eventDialogOpen || !mounted) return;
    _eventDialogOpen = true;
    try {
      final result = await showPetEventDialog(
        context,
        event: active,
        petName: data.pet.name,
        spendable: data.spendable,
        onResolve: () => _eventService.resolve(active.id),
      );
      if (!mounted || result == null) return;
      if (result.action == PetEventDialogAction.openQuests) {
        widget.onOpenQuests?.call();
      } else {
        await _load(showLoader: false);
      }
    } finally {
      _eventDialogOpen = false;
    }
  }

  Future<void> _confirmPlan(int need, int want, int savings) async {
    final day = _data?.activeDay;
    if (day == null) return;
    await widget.apiClient.put(
      '/periods/${day.id}/budget-plan',
      body: {'needAmount': need, 'wantAmount': want, 'savingsAmount': savings},
    );
    await widget.apiClient.post('/periods/${day.id}/budget-plan/confirm');
    await _load(showLoader: false);
  }

  Future<void> _transferSavings(String action, int amount) =>
      _runMutation(() async {
        final idempotencyKey =
            'home-$action-${DateTime.now().microsecondsSinceEpoch}-$amount';
        await widget.apiClient.post(
          '/savings/$action',
          body: {'amount': amount, 'idempotencyKey': idempotencyKey},
        );
        await _load(showLoader: false);
      });

  Future<void> _redeemGoal() => _runMutation(() async {
    final goal = _data?.activeGoal;
    if (goal == null || goal.id.isEmpty || !goal.canRedeem) return;
    await widget.apiClient.post('/goals/${goal.id}/redeem');
    await _load(showLoader: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('«${goal.name}» добавлен в коллекцию!'),
        action: SnackBarAction(label: 'Открыть', onPressed: _openCare),
      ),
    );
  });

  Future<void> _closeDay() async {
    try {
      await _runMutation(() async {
        final day = _data?.activeDay;
        if (day == null || !day.isConfirmed) return;
        final response = await widget.apiClient.post(
          '/periods/${day.id}/close',
        );
        DaySummary? summary;
        try {
          summary = DaySummary.fromJson(response);
        } on FormatException {
          summary = null;
        }
        await _load(showLoader: false);
        _showArtifactEffects(response['artifactEffects']);
        if (!mounted || summary == null) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (routeContext) => DaySummaryScreen(
              summary: summary!,
              onContinue: () => Navigator.of(routeContext).pop(),
            ),
          ),
        );
      });
    } catch (_) {
      if (mounted) {
        _showError('Не получилось завершить день. Попробуй ещё раз.');
      }
    }
  }

  Future<void> _submitParentTask(String assignmentId) => _runMutation(() async {
    await widget.apiClient.post('/child/tasks/$assignmentId/submit');
    await _load(showLoader: false);
  });

  Future<void> _openCare() async {
    final data = _data;
    if (data == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PetCareScreen(
          state: data,
          onRename: _rename,
          onRefresh: () async {
            await _load(showLoader: false);
            return _data!;
          },
          onOpenInsurance: widget.onOpenInsurance ?? () {},
          onOpenEvent: _openEvent,
          onEquipArtifact: _equipArtifact,
          onRepairArtifact: _repairArtifact,
        ),
      ),
    );
    if (mounted) await _load(showLoader: false);
  }

  Future<void> _openPlan() async {
    final data = _data;
    if (data == null) return;
    if (data.activeDay == null) {
      try {
        await _startDay();
      } catch (_) {
        if (!mounted) return;
        _showError('Не получилось начать игровой день. Попробуй ещё раз.');
      }
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            22,
            16,
            20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: BudgetPlanCard(
                period: data.activeDay,
                onStartPeriod: _startDay,
                onConfirm: (need, want, savings) async {
                  await _confirmPlan(need, want, savings);
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDistribution() async {
    final data = _data;
    final day = data?.activeDay;
    if (data == null) return;
    if (day == null || !day.isConfirmed) {
      _showError('Сначала составь и утверди план на сегодня.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      builder: (_) => CoinDistributionSheet(
        spendable: data.spendable,
        savings: data.savings,
        protectedReserve: day.remainingReserve,
        goal: data.activeGoal,
        onDeposit: (amount) => _transferSavings('deposit', amount),
        onWithdraw: (amount) => _transferSavings('withdraw', amount),
        onRedeem:
            data.activeGoal?.canRedeem == true && data.activeGoal!.id.isNotEmpty
            ? _redeemGoal
            : null,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSettings() {
    if (widget.onOpenSettings != null) {
      widget.onOpenSettings!.call();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Настройки', style: AppTextStyles.screenTitle),
              const SizedBox(height: 12),
              Text(
                'Сложность, звук и крупный текст появятся здесь в следующем модуле.',
                style: AppTextStyles.story,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProgress() {
    final data = _data;
    if (data == null) return;
    final goal = data.activeGoal;
    final hint = data.activeDay == null
        ? 'Начни новый игровой день и распредели 30 монет.'
        : !data.activeDay!.isConfirmed
        ? 'Сначала распредели монеты на сегодня.'
        : 'План готов. Оставь 10 монет на еду питомца.';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Прогресс и подсказка', style: AppTextStyles.screenTitle),
              const SizedBox(height: 14),
              Text(
                'Питомец: стадия ${data.pet.evolutionStage} из 3',
                style: AppTextStyles.cardRowLabel,
              ),
              if (goal != null) ...[
                const SizedBox(height: 8),
                Text(
                  'До мечты «${goal.name}» осталось ${goal.remainingAmount} монет.',
                  style: AppTextStyles.story,
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Text(hint, style: AppTextStyles.story),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (_loadState) {
      _LoadState.loading => const _LoadingView(),
      _LoadState.error => _ErrorView(onRetry: _load),
      _LoadState.ready => _HomeContent(
        data: _data!,
        offline: _offline,
        busy: _busy,
        onRefresh: () => _load(showLoader: false),
        onRename: _rename,
        onSettings: _showSettings,
        onOpenCare: _openCare,
        onOpenGoal: widget.onChooseGoal ?? _showProgress,
        onOpenShop: widget.onOpenShop ?? _showProgress,
        onOpenPlan: _openPlan,
        onOpenDistribution: _openDistribution,
        onCloseDay: _closeDay,
        onProgress: _showProgress,
        onOpenEvent: _openEvent,
        onSubmitParentTask: _submitParentTask,
      ),
    };
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.data,
    required this.offline,
    required this.busy,
    required this.onRefresh,
    required this.onRename,
    required this.onSettings,
    required this.onOpenCare,
    required this.onOpenGoal,
    required this.onOpenShop,
    required this.onOpenPlan,
    required this.onOpenDistribution,
    required this.onCloseDay,
    required this.onProgress,
    required this.onOpenEvent,
    required this.onSubmitParentTask,
  });

  final HomeEconomyState data;
  final bool offline;
  final bool busy;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String) onRename;
  final VoidCallback onSettings;
  final VoidCallback onOpenCare;
  final VoidCallback onOpenGoal;
  final VoidCallback onOpenShop;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenDistribution;
  final VoidCallback onCloseDay;
  final VoidCallback onProgress;
  final VoidCallback onOpenEvent;
  final ValueChanged<String> onSubmitParentTask;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final sceneHeight = (width * 0.95).clamp(310.0, 470.0);
    final day = data.activeDay;
    PetEventOccurrence? activeEvent;
    if (data.activeEvent != null) {
      try {
        activeEvent = PetEventOccurrence.fromJson(data.activeEvent!);
      } on FormatException {
        activeEvent = null;
      }
    }
    final planLabel = day == null
        ? 'Начать новый игровой день'
        : day.isConfirmed
        ? 'План на сегодня'
        : 'Составить план';

    return RefreshIndicator(
      color: AppColors.crimson,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          key: const Key('home-settings'),
                          tooltip: 'Настройки',
                          onPressed: onSettings,
                          icon: const Icon(Icons.settings_rounded),
                          color: AppColors.crimson,
                        ),
                      ),
                      const Spacer(),
                      _CoinPill(
                        spendable: data.spendable,
                        savings: data.savings,
                      ),
                    ],
                  ),
                  if (offline) const _OfflineBanner(),
                  Text('Доброе утро,', style: AppTextStyles.supporting),
                  PetNameHeader(pet: data.pet, onRename: onRename),
                  const SizedBox(height: 10),
                  PetScene(
                    key: const Key('home-pet-scene'),
                    pet: data.pet,
                    backgroundAsset: 'assets/backgrounds/home_room.png',
                    height: sceneHeight,
                    petHeightFactor: 0.68,
                    heroTag: 'home-pet',
                  ),
                  if (activeEvent != null) ...[
                    const SizedBox(height: 10),
                    PetEventBanner(
                      event: activeEvent,
                      petName: data.pet.name,
                      onPressed: onOpenEvent,
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      key: const Key('open-pet-care'),
                      onPressed: onOpenCare,
                      icon: const Icon(Icons.pets_rounded),
                      label: const Text('Забота о питомце'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.crimson,
                        side: const BorderSide(color: AppColors.crimson),
                        shape: const StadiumBorder(),
                        textStyle: AppTextStyles.cardRowLabel,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DreamCard(goal: data.activeGoal, onTap: onOpenGoal),
                  const SizedBox(height: 16),
                  _PlanButton(
                    label: planLabel,
                    busy: busy,
                    pulse: day != null && !day.isConfirmed,
                    onPressed: busy ? null : onOpenPlan,
                  ),
                  if (day != null && !day.isConfirmed) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Сначала распредели монеты — после этого откроются карта и магазин.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.swatchLabel.copyWith(
                        color: AppColors.crimson,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 66,
                    child: OutlinedButton(
                      key: const Key('distribute-earned-coins'),
                      onPressed: busy ? null : onOpenDistribution,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.crimson,
                        backgroundColor: AppColors.infoBg,
                        side: const BorderSide(color: AppColors.coinGold),
                        shape: const StadiumBorder(),
                        textStyle: AppTextStyles.button.copyWith(
                          color: AppColors.crimson,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.savings_rounded),
                          SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Распределить заработанные монеты',
                              maxLines: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stack = constraints.maxWidth < 430;
                      final finish = _QuickAction(
                        key: const Key('finish-day'),
                        icon: Icons.nights_stay_rounded,
                        label: 'Завершить день',
                        onTap:
                            day?.isConfirmed == true &&
                                day?.remainingReserve == 0 &&
                                !busy
                            ? onCloseDay
                            : null,
                      );
                      const gap = SizedBox(width: 12, height: 12);
                      final progress = _QuickAction(
                        key: const Key('show-progress'),
                        icon: Icons.lightbulb_rounded,
                        label: 'Прогресс и подсказка',
                        onTap: onProgress,
                      );
                      return stack
                          ? Column(children: [finish, gap, progress])
                          : Row(
                              children: [
                                Expanded(child: finish),
                                gap,
                                Expanded(child: progress),
                              ],
                            );
                    },
                  ),
                  if (day?.isConfirmed == true &&
                      day!.remainingReserve > 0) ...[
                    const SizedBox(height: 12),
                    _QuickAction(
                      key: const Key('open-shop-for-needs'),
                      icon: Icons.shopping_basket_outlined,
                      label:
                          'Открыть магазин · осталось ${day.remainingReserve} монет на обязательные покупки',
                      onTap: busy ? null : onOpenShop,
                    ),
                  ],
                  if (data.parentTasks.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ParentTasksCard(
                      tasks: data.parentTasks,
                      busy: busy,
                      onSubmit: onSubmitParentTask,
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

class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.spendable, required this.savings});

  final int spendable;
  final int savings;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Доступно $spendable монет. В копилке $savings монет.',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
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
            const SizedBox(width: 5),
            Text('$spendable', style: AppTextStyles.counterValue),
            Container(
              width: 1,
              height: 25,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: AppColors.fieldBorder,
            ),
            Image.asset('assets/icons/chest.png', width: 26, height: 26),
            const SizedBox(width: 5),
            Text('$savings', style: AppTextStyles.counterValue),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, textAlign: TextAlign.center),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.crimson,
          disabledForegroundColor: AppColors.inkMuted.withValues(alpha: 0.45),
          side: BorderSide(
            color: onTap == null
                ? AppColors.fieldBorder
                : AppColors.crimsonFaded,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: AppTextStyles.cardRowLabel,
        ),
      ),
    );
  }
}

class _PlanButton extends StatefulWidget {
  const _PlanButton({
    required this.label,
    required this.busy,
    required this.pulse,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final bool pulse;
  final VoidCallback? onPressed;

  @override
  State<_PlanButton> createState() => _PlanButtonState();
}

class _PlanButtonState extends State<_PlanButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    lowerBound: 0,
    upperBound: 1,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _PlanButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.pulse && widget.pulse) _started = false;
    _startIfNeeded();
  }

  void _startIfNeeded() {
    if (_started || !widget.pulse || MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _started = true;
    _controller.repeat(reverse: true, count: 3);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Transform.scale(scale: 1 + (_controller.value * 0.018), child: child),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: FilledButton.icon(
          key: const Key('open-budget-plan'),
          onPressed: widget.onPressed,
          icon: widget.busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.assignment_rounded),
          label: Text(widget.label),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.crimson,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.crimsonFaded,
            shape: const StadiumBorder(),
            textStyle: AppTextStyles.button,
          ),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: const Text(
        'Нет связи. Показываем последние загруженные данные.',
        textAlign: TextAlign.center,
        style: AppTextStyles.swatchLabel,
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.canvas,
      child: Center(child: CircularProgressIndicator(color: AppColors.crimson)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvas,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 58,
                color: AppColors.crimson,
              ),
              const SizedBox(height: 14),
              Text(
                'Не получилось загрузить домик. Проверь подключение к интернету.',
                textAlign: TextAlign.center,
                style: AppTextStyles.story,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.crimson,
                  ),
                  child: const Text('Повторить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
