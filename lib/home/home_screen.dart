import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../day_summary/day_summary.dart';
import '../day_summary/day_summary_screen.dart';
import '../events/pet_event_dialog.dart';
import '../events/pet_event_indicator.dart';
import '../events/pet_event_models.dart';
import '../pet/pet_energy_status.dart';
import '../services/pet_event_service.dart';
import '../theme/app_theme.dart';
import 'home_tour.dart';
import 'models/home_economy_state.dart';
import 'models/pet.dart';
import 'models/recent_day.dart';
import 'pet_care_screen.dart';
import 'widgets/budget_plan_card.dart';
import 'widgets/coin_distribution_sheet.dart';
import 'widgets/dream_card.dart';
import 'widgets/home_side_panel.dart';
import 'widgets/pet_name_header.dart';
import 'widgets/pet_scene.dart';
import 'widgets/parent_tasks_card.dart';
import 'widgets/recent_days_card.dart';

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
    this.onOpenMenu,
    this.onOpenInsurance,
    this.onPlanningRequiredChanged,
    this.isActive = true,
    this.refreshSignal = 0,
    this.focusPlan = false,
    this.tourTargets,
    this.onTourReady,
  });

  final ApiClient apiClient;
  final VoidCallback? onChooseGoal;
  final VoidCallback? onOpenShop;
  final VoidCallback? onOpenQuests;
  final VoidCallback? onOpenSettings;
  final ValueChanged<BuildContext>? onOpenMenu;
  final VoidCallback? onOpenInsurance;
  final ValueChanged<bool>? onPlanningRequiredChanged;

  /// False while another tab or the first-run home tour is visible.
  final bool isActive;
  final int refreshSignal;

  /// Opens the day plan as soon as the home loads — used when another tab
  /// (e.g. a closed shop) sends the child here to plan first.
  final bool focusPlan;

  /// Anchors for the first-run home tour; null when no tour is shown.
  final HomeTourTargets? tourTargets;

  /// Called once the home has real content the tour can point at.
  final VoidCallback? onTourReady;

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
  String? _presentedEventId;
  List<RecentDay> _recentDays = const [];
  bool _planFocused = false;
  PetEnergyStatus _energy = const PetEnergyStatus.full();
  Timer? _energyTicker;
  DateTime? _nextEnergyRefreshAttempt;
  bool _isRecoveringEnergy = false;

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
    } else if (!oldWidget.isActive && widget.isActive) {
      _scheduleHomeDialogs();
    }
  }

  @override
  void dispose() {
    _energyTicker?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader && _data == null) {
      setState(() => _loadState = _LoadState.loading);
    }
    try {
      final json = await widget.apiClient.get('/economy/state');
      final next = HomeEconomyState.fromJson(json);
      final petJson = Map<String, dynamic>.from(
        json['pet'] as Map? ?? const {},
      );
      final energy = PetEnergyStatus.fromJson(petJson);
      final recentDaysValue = json['recentDays'];
      final recentDays = recentDaysValue is List
          ? recentDaysValue
                .map(
                  (value) => RecentDay.fromJson(
                    Map<String, dynamic>.from(value as Map),
                  ),
                )
                .toList(growable: false)
          : const <RecentDay>[];
      if (!mounted) return;
      setState(() {
        _data = next;
        _energy = energy;
        _recentDays = recentDays;
        _offline = false;
        _loadState = _LoadState.ready;
      });
      _syncEnergyTicker();
      widget.onPlanningRequiredChanged?.call(
        next.activeDay != null && !next.activeDay!.isConfirmed,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onTourReady?.call();
      });
      _scheduleHomeDialogs();
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

  void _scheduleHomeDialogs() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          !widget.isActive ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final data = _data;
      final event = data == null ? null : _activeEvent(data);
      if (event != null && event.id != _presentedEventId) {
        await _openEvent(event: event);
      }
      if (!mounted ||
          !widget.isActive ||
          !widget.focusPlan ||
          _planFocused ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      _planFocused = true;
      await _openPlan();
    });
  }

  void _syncEnergyTicker() {
    _energyTicker?.cancel();
    if (!_energy.isRecovering) return;
    _energyTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      final now = DateTime.now();
      final mayRefresh =
          _nextEnergyRefreshAttempt == null ||
          !now.isBefore(_nextEnergyRefreshAttempt!);
      if (_energy.nextTickIsDue(now) && mayRefresh) {
        _nextEnergyRefreshAttempt = now.add(const Duration(seconds: 10));
        unawaited(_refreshPetEnergy());
      }
    });
  }

  Future<void> _refreshPetEnergy() async {
    try {
      final json = await widget.apiClient.get('/pet');
      if (!mounted) return;
      final current = _data;
      setState(() {
        if (current != null) {
          _data = current.copyWith(pet: Pet.fromJson(json));
        }
        _energy = PetEnergyStatus.fromJson(json);
        _nextEnergyRefreshAttempt = null;
      });
      _syncEnergyTicker();
    } on ApiException {
      // Keep the server-derived countdown visible and retry on a later tick.
    }
  }

  Future<void> _recoverEnergyNow() async {
    if (_isRecoveringEnergy) return;
    setState(() => _isRecoveringEnergy = true);
    try {
      final json = await widget.apiClient.post('/pet/recover-energy');
      if (!mounted) return;
      final current = _data;
      setState(() {
        if (current != null) {
          _data = current.copyWith(pet: Pet.fromJson(json));
        }
        _energy = PetEnergyStatus.fromJson(json);
      });
      _syncEnergyTicker();
    } on ApiException {
      if (!mounted) return;
      _showError('Не получилось восстановить энергию.');
    } finally {
      if (mounted) setState(() => _isRecoveringEnergy = false);
    }
  }

  /// Stroking is a small bonus: when it fails, the purr still plays and the
  /// pet simply keeps its current joy.
  Future<HomeEconomyState?> _strokePet() async {
    try {
      final json = await widget.apiClient.post('/pet/stroke');
      final current = _data;
      if (!mounted || current == null) return null;
      final next = current.copyWith(pet: Pet.fromJson(json));
      setState(() {
        _data = next;
        _energy = PetEnergyStatus.fromJson(json);
      });
      return next;
    } on ApiException {
      return null;
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

  Future<HomeEconomyState> _useArtifact(ArtifactItem item) async {
    await widget.apiClient.post('/inventory/${item.id}/use');
    await _load(showLoader: false);
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
    _presentedEventId = active.id;
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
          onStroke: _strokePet,
          onRefresh: () async {
            await _load(showLoader: false);
            return _data!;
          },
          onOpenInsurance: widget.onOpenInsurance ?? () {},
          onOpenEvent: _openEvent,
          onEquipArtifact: _equipArtifact,
          onRepairArtifact: _repairArtifact,
          onUseArtifact: _useArtifact,
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
        energy: _energy,
        isRecoveringEnergy: _isRecoveringEnergy,
        onRecoverEnergy: _recoverEnergyNow,
        offline: _offline,
        busy: _busy,
        onRefresh: () => _load(showLoader: false),
        onRename: _rename,
        onSettings: _showSettings,
        onOpenMenu: widget.onOpenMenu,
        onOpenCare: _openCare,
        onOpenGoal: widget.onChooseGoal ?? _showProgress,
        onOpenShop: widget.onOpenShop ?? _showProgress,
        onOpenPlan: _openPlan,
        onOpenDistribution: _openDistribution,
        onCloseDay: _closeDay,
        onProgress: _showProgress,
        onOpenEvent: _openEvent,
        onSubmitParentTask: _submitParentTask,
        onStroke: () => unawaited(_strokePet()),
        recentDays: _recentDays,
        tourTargets: widget.tourTargets,
      ),
    };
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.data,
    required this.energy,
    required this.isRecoveringEnergy,
    required this.onRecoverEnergy,
    required this.recentDays,
    this.tourTargets,
    required this.offline,
    required this.busy,
    required this.onRefresh,
    required this.onRename,
    required this.onSettings,
    this.onOpenMenu,
    required this.onOpenCare,
    required this.onOpenGoal,
    required this.onOpenShop,
    required this.onOpenPlan,
    required this.onOpenDistribution,
    required this.onCloseDay,
    required this.onProgress,
    required this.onOpenEvent,
    required this.onSubmitParentTask,
    required this.onStroke,
  });

  final HomeEconomyState data;
  final PetEnergyStatus energy;
  final bool isRecoveringEnergy;
  final VoidCallback onRecoverEnergy;
  final List<RecentDay> recentDays;
  final HomeTourTargets? tourTargets;
  final bool offline;
  final bool busy;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String) onRename;
  final VoidCallback onSettings;
  final ValueChanged<BuildContext>? onOpenMenu;
  final VoidCallback onOpenCare;
  final VoidCallback onOpenGoal;
  final VoidCallback onOpenShop;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenDistribution;
  final VoidCallback onCloseDay;
  final VoidCallback onProgress;
  final VoidCallback onOpenEvent;
  final ValueChanged<String> onSubmitParentTask;
  final VoidCallback onStroke;

  @override
  Widget build(BuildContext context) {
    final day = data.activeDay;
    PetEventOccurrence? activeEvent;
    if (data.activeEvent != null) {
      try {
        activeEvent = PetEventOccurrence.fromJson(data.activeEvent!);
      } on FormatException {
        activeEvent = null;
      }
    }
    final planNeeded = day != null && !day.isConfirmed;
    final planLabel = day == null
        ? 'Начать новый игровой день'
        : day.isConfirmed
        ? 'План на сегодня'
        : 'Составить план';
    final panel = HomeSidePanel(
      actions: [
        HomePanelAction(
          key: const Key('open-pet-care'),
          // The tour's "stats" step: the pet's gauges live behind this
          // button on the pet care screen.
          tourKey: tourTargets?.stats,
          icon: Icons.pets_rounded,
          color: AppColors.leafGreen,
          label: 'Забота о питомце',
          onTap: onOpenCare,
        ),
        HomePanelAction(
          key: const Key('distribute-earned-coins'),
          // Coins, not a piggy: the piggy already means the Копилка tab.
          icon: Icons.toll_rounded,
          color: AppColors.coinGold,
          label: 'Распределить заработанные монеты',
          onTap: busy ? null : onOpenDistribution,
        ),
        HomePanelAction(
          key: const Key('open-budget-plan'),
          tourKey: tourTargets?.plan,
          icon: day == null ? Icons.wb_sunny_rounded : Icons.checklist_rounded,
          color: AppColors.crimson,
          label: planLabel,
          attention: day == null || planNeeded,
          busy: busy,
          onTap: busy ? null : onOpenPlan,
        ),
        HomePanelAction(
          key: const Key('show-progress'),
          icon: Icons.lightbulb_rounded,
          color: AppColors.frostBlue,
          label: 'Прогресс и подсказка',
          onTap: onProgress,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, viewport) {
        // The room fills the first screen under the name; the dream and the
        // rest of the day start right below it.
        final sceneHeight = (viewport.maxHeight - 150).clamp(380.0, 680.0);
        return RefreshIndicator(
          color: AppColors.crimson,
          onRefresh: onRefresh,
          child: ListView(
            controller: tourTargets?.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  key: tourTargets?.settings,
                                  width: 48,
                                  height: 48,
                                  child: IconButton(
                                    key: const Key('home-settings'),
                                    tooltip: onOpenMenu == null
                                        ? 'Настройки'
                                        : 'Меню',
                                    onPressed: onOpenMenu == null
                                        ? onSettings
                                        : () => onOpenMenu!(context),
                                    icon: Icon(
                                      onOpenMenu == null
                                          ? Icons.settings_rounded
                                          : Icons.menu_rounded,
                                    ),
                                    color: AppColors.crimson,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: KeyedSubtree(
                                      key: tourTargets?.wallet,
                                      child: _CoinPill(
                                        spendable: data.spendable,
                                        savings: data.savings,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (offline) const _OfflineBanner(),
                            Text(
                              'Доброе утро,',
                              style: AppTextStyles.supporting,
                            ),
                            KeyedSubtree(
                              key: tourTargets?.identity,
                              child: PetNameHeader(
                                pet: data.pet,
                                onRename: onRename,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Stack(
                          children: [
                            KeyedSubtree(
                              key: tourTargets?.pet,
                              child: PetScene(
                                key: const Key('home-pet-scene'),
                                pet: data.pet,
                                backgroundAsset:
                                    'assets/backgrounds/home_room.webp',
                                height: sceneHeight,
                                petHeightFactor: 0.7,
                                // Keeps the cat clear of the panel.
                                petShiftX: 24,
                                heroTag: 'home-pet',
                                onStroke: onStroke,
                              ),
                            ),
                            Positioned(left: 10, top: 12, child: panel),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            if (planNeeded) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Сначала распредели монеты — нажми на красную '
                                'кнопку со списком. После этого откроются '
                                'карта и магазин.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.swatchLabel.copyWith(
                                  color: AppColors.crimson,
                                ),
                              ),
                            ],
                            if (energy.isRecovering) ...[
                              const SizedBox(height: 10),
                              _EnergyRecoveryNotice(
                                energy: energy,
                                isBusy: isRecoveringEnergy,
                                onRecover: onRecoverEnergy,
                              ),
                            ],
                            if (activeEvent != null) ...[
                              const SizedBox(height: 10),
                              KeyedSubtree(
                                key: tourTargets?.event,
                                child: PetEventBanner(
                                  event: activeEvent,
                                  petName: data.pet.name,
                                  onPressed: onOpenEvent,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            DreamCard(goal: data.activeGoal, onTap: onOpenGoal),
                            const SizedBox(height: 14),
                            _QuickAction(
                              key: const Key('finish-day'),
                              icon: Icons.nights_stay_rounded,
                              label: 'Завершить день',
                              onTap:
                                  day?.isConfirmed == true &&
                                      day?.remainingReserve == 0 &&
                                      !busy
                                  ? onCloseDay
                                  : null,
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
                            if (recentDays.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              RecentDaysCard(days: recentDays),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EnergyRecoveryNotice extends StatelessWidget {
  const _EnergyRecoveryNotice({
    required this.energy,
    required this.isBusy,
    required this.onRecover,
  });

  final PetEnergyStatus energy;
  final bool isBusy;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    final next = formatEnergyCountdown(energy.untilNextTick());
    final full = formatEnergyCountdown(energy.untilFull());
    return Semantics(
      label:
          'Энергия питомца ${energy.level} из ${energy.maxEnergy}. '
          'Следующее восстановление через $next. Полностью через $full.',
      child: Container(
        key: const Key('pet-energy-recovery'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: energy.blocksActivities
                ? AppColors.crimson.withValues(alpha: 0.5)
                : AppColors.fieldBorder.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            Icon(
              energy.blocksActivities
                  ? Icons.bedtime_rounded
                  : Icons.bolt_rounded,
              color: energy.blocksActivities
                  ? AppColors.crimson
                  : AppColors.leafGreen,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                energy.blocksActivities
                    ? 'Питомец отдыхает · +${energy.energyPerTick} через $next'
                    : 'Энергия ${energy.level}/${energy.maxEnergy} · полностью через $full',
                style: AppTextStyles.swatchLabel.copyWith(color: AppColors.ink),
              ),
            ),
            if (energy.isDemo) ...[
              const SizedBox(width: 8),
              IconButton(
                key: const Key('demo-recover-energy'),
                tooltip: 'Восстановить энергию',
                onPressed: isBusy ? null : onRecover,
                icon: isBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ],
        ),
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
        // Wraps the savings group under the coins on a narrow phone with
        // large text instead of pushing past the screen edge.
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/icons/coin.webp', width: 24, height: 24),
                const SizedBox(width: 5),
                Text('$spendable', style: AppTextStyles.counterValue),
              ],
            ),
            Container(width: 1, height: 25, color: AppColors.fieldBorder),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/icons/chest.webp', width: 26, height: 26),
                const SizedBox(width: 5),
                Text('$savings', style: AppTextStyles.counterValue),
              ],
            ),
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
