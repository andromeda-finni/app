import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/pet_assets.dart';
import '../day_summary/day_summary.dart';
import '../day_summary/day_summary_screen.dart';
import '../economy/economy_action_ui.dart';
import '../theme/app_theme.dart';
import 'home_tour.dart';
import 'models/active_period.dart';
import 'models/active_pet_event.dart';
import 'models/artifact.dart';
import 'models/pet.dart';
import 'models/parent_task.dart';
import 'models/recent_day.dart';
import 'widgets/budget_plan_card.dart';
import 'widgets/collection_card.dart';
import 'widgets/day_actions_card.dart';
import 'widgets/pet_stats_card.dart';
import 'widgets/recent_days_card.dart';
import 'widgets/parent_tasks_card.dart';

enum _LoadState { loading, ready, error }

/// The pet's home: who they are, how they are doing, what money there is and
/// what the plan for it is.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.apiClient,
    required this.onChooseGoal,
    required this.onOpenShop,
    this.onOpenSettings,
    this.tourTargets,
    this.onTourReady,
  });

  final ApiClient apiClient;
  final VoidCallback onChooseGoal;
  final VoidCallback onOpenShop;

  final VoidCallback? onOpenSettings;
  final HomeTourTargets? tourTargets;
  final VoidCallback? onTourReady;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _LoadState _state = _LoadState.loading;
  Pet? _pet;
  ActivePeriod? _period;
  ActivePetEvent? _event;
  List<ParentTask> _parentTasks = const [];
  List<Artifact> _artifacts = const [];
  List<RecentDay> _recentDays = const [];
  Map<String, int> _wallets = const {};
  bool _hasGoal = false;
  bool _dayActionBusy = false;
  String? _dayActionError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      // The current backend exposes one read model for all child-facing
      // economy state. Reading it once also keeps the balance and active day
      // consistent with each other while the screen appears.
      final economy = await widget.apiClient.get('/economy/state');
      final petJson = Map<String, dynamic>.from(
        economy['pet'] as Map? ?? const {},
      );
      final walletJson = Map<String, dynamic>.from(
        economy['wallets'] as Map? ?? const {},
      );
      final dayValue = economy['activeDay'];
      final periodJson = dayValue is Map
          ? Map<String, dynamic>.from(dayValue)
          : null;
      final eventValue = economy['activeEvent'];
      final eventJson = eventValue is Map
          ? Map<String, dynamic>.from(eventValue)
          : null;
      final pet = Pet.fromJson(petJson);
      final parentTasksValue = economy['parentTasks'];
      if (parentTasksValue is! List) {
        throw const FormatException('parentTasks must be a list');
      }
      final parentTasks = parentTasksValue
          .map((value) {
            if (value is! Map) {
              throw const FormatException('parent task must be an object');
            }
            return ParentTask.fromJson(Map<String, dynamic>.from(value));
          })
          .toList(growable: false);
      final inventoryValue = economy['inventory'];
      final recentDaysValue = economy['recentDays'];
      if (inventoryValue is! List || recentDaysValue is! List) {
        throw const FormatException('inventory and recentDays must be lists');
      }
      final artifacts = inventoryValue
          .map(
            (value) =>
                Artifact.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(growable: false);
      final recentDays = recentDaysValue
          .map(
            (value) =>
                RecentDay.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(growable: false);
      final wallets = {
        for (final entry in walletJson.entries)
          entry.key: (entry.value as num?)?.toInt() ?? 0,
      };

      if (!mounted) return;
      setState(() {
        _pet = pet;
        _wallets = wallets;
        _period = periodJson == null ? null : ActivePeriod.fromJson(periodJson);
        _event = eventJson == null ? null : ActivePetEvent.fromJson(eventJson);
        _parentTasks = parentTasks;
        _artifacts = artifacts;
        _recentDays = recentDays;
        _hasGoal = economy['activeGoal'] is Map;
        _state = _LoadState.ready;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onTourReady?.call();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _LoadState.error);
    }
  }

  Future<void> _startPeriod() async {
    if (!_hasGoal) {
      widget.onChooseGoal();
      return;
    }
    await widget.apiClient.post('/periods');
    await _load();
  }

  Future<void> _confirmPlan(int need, int want, int savings) async {
    final period = _period;
    if (period == null) return;
    await widget.apiClient.put(
      '/periods/${period.id}/budget-plan',
      body: {'needAmount': need, 'wantAmount': want, 'savingsAmount': savings},
    );
    await widget.apiClient.post('/periods/${period.id}/budget-plan/confirm');
    await _load();
  }

  Future<void> _runDayAction(Future<void> Function() action) async {
    if (_dayActionBusy) return;
    setState(() {
      _dayActionBusy = true;
      _dayActionError = null;
    });
    try {
      await action();
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _dayActionError = economyErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _dayActionBusy = false);
    }
  }

  Future<void> _resolveEvent() {
    final event = _event;
    if (event == null) return Future.value();
    return _runDayAction(
      () => widget.apiClient.post('/pet-events/${event.id}/resolve'),
    );
  }

  Future<void> _closeDay() {
    final period = _period;
    if (period == null) return Future.value();
    return _runDayAction(() async {
      final response = await widget.apiClient.post(
        '/periods/${period.id}/close',
      );
      final DaySummary summary;
      try {
        summary = DaySummary.fromJson(response);
      } on FormatException {
        // The day is already closed on the server; home reloads either way,
        // so a malformed summary only skips the mirror screen.
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (routeContext) => DaySummaryScreen(
            summary: summary,
            onContinue: () => Navigator.of(routeContext).pop(),
          ),
        ),
      );
    });
  }

  Future<void> _submitParentTask(String assignmentId) => _runDayAction(
    () => widget.apiClient.post('/child/tasks/$assignmentId/submit'),
  );

  Future<void> _equipArtifact(String? inventoryId) => _runDayAction(
    () => widget.apiClient.post(
      '/pet/equip',
      body: {'inventoryItemId': inventoryId},
    ),
  );

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.crimson),
        );
      case _LoadState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Не получилось загрузить питомца — проверьте подключение к интернету.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.story,
                ),
                const SizedBox(height: 16),
                TextButton(onPressed: _load, child: const Text('Повторить')),
              ],
            ),
          ),
        );
      case _LoadState.ready:
        return _Content(
          pet: _pet!,
          onOpenSettings: widget.onOpenSettings,
          period: _period,
          event: _event,
          parentTasks: _parentTasks,
          artifacts: _artifacts,
          recentDays: _recentDays,
          spendable: _wallets['SPENDABLE'] ?? 0,
          savings: _wallets['SAVINGS'] ?? 0,
          onRefresh: _load,
          onConfirmPlan: _confirmPlan,
          onStartPeriod: _startPeriod,
          onOpenShop: widget.onOpenShop,
          dayActionBusy: _dayActionBusy,
          dayActionError: _dayActionError,
          onResolveEvent: _resolveEvent,
          onCloseDay: _closeDay,
          onSubmitParentTask: _submitParentTask,
          onEquipArtifact: _equipArtifact,
          tourTargets: widget.tourTargets,
        );
    }
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.pet,
    this.onOpenSettings,
    required this.period,
    required this.event,
    required this.parentTasks,
    required this.artifacts,
    required this.recentDays,
    required this.spendable,
    required this.savings,
    required this.onRefresh,
    required this.onConfirmPlan,
    required this.onStartPeriod,
    required this.onOpenShop,
    required this.dayActionBusy,
    required this.onResolveEvent,
    required this.onCloseDay,
    required this.onSubmitParentTask,
    required this.onEquipArtifact,
    this.dayActionError,
    this.tourTargets,
  });

  final Pet pet;
  final VoidCallback? onOpenSettings;
  final ActivePeriod? period;
  final ActivePetEvent? event;
  final List<ParentTask> parentTasks;
  final List<Artifact> artifacts;
  final List<RecentDay> recentDays;
  final int spendable;
  final int savings;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int, int, int) onConfirmPlan;
  final Future<void> Function() onStartPeriod;
  final VoidCallback onOpenShop;
  final bool dayActionBusy;
  final String? dayActionError;
  final VoidCallback onResolveEvent;
  final VoidCallback onCloseDay;
  final ValueChanged<String> onSubmitParentTask;
  final ValueChanged<String?> onEquipArtifact;
  final HomeTourTargets? tourTargets;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.crimson,
      onRefresh: onRefresh,
      child: ListView(
        controller: tourTargets?.scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Header(
            pet: pet,
            spendable: spendable,
            savings: savings,
            onOpenSettings: onOpenSettings,
            tourTargets: tourTargets,
          ),
          const SizedBox(height: 8),
          KeyedSubtree(
            key: tourTargets?.pet,
            child: _PetPortrait(pet: pet),
          ),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: tourTargets?.stats,
            child: PetStatsCard(
              stats: [
                PetStat(
                  label: 'Сытость',
                  icon: Icons.restaurant,
                  color: AppColors.leafGreen,
                  value: pet.satiety,
                ),
                PetStat(
                  label: 'Радость',
                  icon: Icons.sentiment_satisfied_alt,
                  color: const Color(0xFFD9A038),
                  value: pet.joy,
                ),
                PetStat(
                  label: 'Здоровье',
                  icon: Icons.favorite,
                  color: const Color(0xFF3E8ED0),
                  value: pet.health,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          KeyedSubtree(
            key: tourTargets?.plan,
            child: BudgetPlanCard(
              period: period,
              onConfirm: onConfirmPlan,
              onStartPeriod: onStartPeriod,
            ),
          ),
          if (period != null) ...[
            const SizedBox(height: 14),
            KeyedSubtree(
              key: tourTargets?.event,
              child: DayActionsCard(
                period: period!,
                event: event,
                spendable: spendable,
                busy: dayActionBusy,
                error: dayActionError,
                onResolveEvent: onResolveEvent,
                onOpenShop: onOpenShop,
                onCloseDay: onCloseDay,
              ),
            ),
          ],
          if (parentTasks.isNotEmpty) ...[
            const SizedBox(height: 14),
            ParentTasksCard(
              tasks: parentTasks,
              busy: dayActionBusy,
              onSubmit: onSubmitParentTask,
            ),
          ],
          const SizedBox(height: 14),
          CollectionCard(
            items: artifacts,
            busy: dayActionBusy,
            onEquip: onEquipArtifact,
          ),
          if (recentDays.isNotEmpty) ...[
            const SizedBox(height: 14),
            RecentDaysCard(days: recentDays),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.pet,
    this.onOpenSettings,
    required this.spendable,
    required this.savings,
    this.tourTargets,
  });

  final Pet pet;
  final VoidCallback? onOpenSettings;
  final int spendable;
  final int savings;
  final HomeTourTargets? tourTargets;

  @override
  Widget build(BuildContext context) {
    final settings = onOpenSettings == null
        ? null
        : KeyedSubtree(
            key: tourTargets?.settings,
            child: IconButton(
              tooltip: 'Настройки',
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              color: AppColors.ink,
            ),
          );
    final wallet = KeyedSubtree(
      key: tourTargets?.wallet,
      child: _CoinPill(spendable: spendable, savings: savings),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledBody = MediaQuery.textScalerOf(context).scale(16);
        final stackControls = constraints.maxWidth < 360 && scaledBody > 24;
        return Column(
          children: [
            if (stackControls) ...[
              if (settings != null)
                Align(alignment: Alignment.centerLeft, child: settings),
              Align(alignment: Alignment.centerRight, child: wallet),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Takes the slot the reference gives a back button: the
                  // home tab is a root, so settings are useful here.
                  settings ?? const SizedBox.shrink(),
                  const Spacer(),
                  wallet,
                ],
              ),
            KeyedSubtree(
              key: tourTargets?.identity,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/icons/leaf.webp',
                        width: 26,
                        height: 26,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          pet.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.dropCap.copyWith(fontSize: 34),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Transform.flip(
                        flipX: true,
                        child: Image.asset(
                          'assets/icons/leaf.webp',
                          width: 26,
                          height: 26,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.fieldBorder.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Text(
                      'Стадия ${pet.evolutionStage} из ${Pet.maxStage} · ${pet.stageName}',
                      style: AppTextStyles.swatchLabel.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
      label: 'Монет на руках: $spendable. В копилке: $savings',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.fieldBorder.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icons/coin.webp', width: 22, height: 22),
            const SizedBox(width: 6),
            Text('$spendable', style: AppTextStyles.counterValue),
            const SizedBox(width: 10),
            Image.asset('assets/icons/pig.webp', width: 22, height: 22),
            const SizedBox(width: 6),
            Text('$savings', style: AppTextStyles.counterValue),
          ],
        ),
      ),
    );
  }
}

class _PetPortrait extends StatelessWidget {
  const _PetPortrait({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Питомец ${pet.name}, ${_moodWord(pet)}',
      image: true,
      child: SizedBox(
        height: 260,
        // Keyed by the asset so a mood change cross-fades instead of snapping.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Image.asset(
            pet.assetPath,
            key: ValueKey(pet.assetPath),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

String _moodWord(Pet pet) => switch (pet.mood) {
  PetMood.happy => 'довольный',
  PetMood.sad => 'грустный',
  PetMood.sleep => 'уставший',
  PetMood.fully => 'сытый',
  PetMood.base => 'спокойный',
};
