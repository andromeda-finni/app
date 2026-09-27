import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/pet_assets.dart';
import '../events/pet_event_dialog.dart';
import '../events/pet_event_indicator.dart';
import '../events/pet_event_models.dart';
import '../services/pet_event_service.dart';
import '../theme/app_theme.dart';
import 'models/active_period.dart';
import 'models/pet.dart';
import 'widgets/budget_plan_card.dart';
import 'widgets/collection_card.dart';
import 'widgets/pet_stats_card.dart';

enum _LoadState { loading, ready, error }

/// The pet's home: who they are, how they are doing, what money there is and
/// what the plan for it is.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.apiClient,
    required this.onChooseGoal,
    this.onOpenQuests,
    this.onOpenSettings,
    this.onOpenInsurance,
  });

  final ApiClient apiClient;
  final VoidCallback onChooseGoal;
  final VoidCallback? onOpenQuests;

  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenInsurance;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PetEventService _eventService = PetEventService(widget.apiClient);
  _LoadState _state = _LoadState.loading;
  Pet? _pet;
  ActivePeriod? _period;
  PetEventOccurrence? _activeEvent;
  Map<String, int> _wallets = const {};
  bool _hasGoal = false;
  bool _eventDialogOpen = false;

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
      final responses = await Future.wait<Object?>([
        widget.apiClient.get('/economy/state'),
        // This endpoint is intentionally read independently of economy/state:
        // an unresolved occurrence must be restored on every cold start.
        _eventService.getActive(),
      ]);
      final economy = responses[0] as Map<String, dynamic>;
      final activeEvent = responses[1] as PetEventOccurrence?;
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
      final pet = Pet.fromJson(petJson);
      final wallets = {
        for (final entry in walletJson.entries)
          entry.key: (entry.value as num?)?.toInt() ?? 0,
      };

      if (!mounted) return;
      setState(() {
        _pet = pet;
        _wallets = wallets;
        _period = periodJson == null ? null : ActivePeriod.fromJson(periodJson);
        _activeEvent = activeEvent;
        _hasGoal = economy['activeGoal'] is Map;
        _state = _LoadState.ready;
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
    PetEventRollResult? rollResult;
    var rollFailed = false;
    try {
      rollResult = await _eventService.roll();
    } catch (_) {
      // The day already exists, so always refresh it even when the optional
      // random-event check is temporarily unavailable.
      rollFailed = true;
    }
    await _load();
    if (!mounted) return;
    if (rollFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('День начался, но событие пока не удалось проверить.'),
        ),
      );
    } else if (rollResult?.insuranceNotice case final String notice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(notice), duration: const Duration(seconds: 5)),
      );
    } else if (rollResult?.event != null) {
      await _openEvent();
    }
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

  Future<void> _openEvent() async {
    final event = _activeEvent;
    final pet = _pet;
    if (event == null || pet == null || _eventDialogOpen) return;
    _eventDialogOpen = true;
    final result = await showPetEventDialog(
      context,
      event: event,
      petName: pet.name,
      spendable: _wallets['SPENDABLE'] ?? 0,
      onResolve: () => _eventService.resolve(event.id),
    );
    _eventDialogOpen = false;
    if (!mounted || result == null) return;
    switch (result.action) {
      case PetEventDialogAction.resolved:
        final resolution = result.resolution;
        if (resolution == null) return;
        setState(() {
          _pet = pet.copyWith(health: resolution.healthLevel);
          _wallets = {..._wallets, 'SPENDABLE': resolution.spendableBalance};
          _activeEvent = null;
        });
        break;
      case PetEventDialogAction.openQuests:
        widget.onOpenQuests?.call();
        break;
    }
  }

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
          onOpenInsurance: widget.onOpenInsurance,
          period: _period,
          activeEvent: _activeEvent,
          spendable: _wallets['SPENDABLE'] ?? 0,
          savings: _wallets['SAVINGS'] ?? 0,
          onRefresh: _load,
          onConfirmPlan: _confirmPlan,
          onStartPeriod: _startPeriod,
          onOpenEvent: _openEvent,
        );
    }
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.pet,
    this.onOpenSettings,
    this.onOpenInsurance,
    required this.period,
    required this.activeEvent,
    required this.spendable,
    required this.savings,
    required this.onRefresh,
    required this.onConfirmPlan,
    required this.onStartPeriod,
    required this.onOpenEvent,
  });

  final Pet pet;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenInsurance;
  final ActivePeriod? period;
  final PetEventOccurrence? activeEvent;
  final int spendable;
  final int savings;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int, int, int) onConfirmPlan;
  final Future<void> Function() onStartPeriod;
  final VoidCallback onOpenEvent;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.crimson,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Header(
            pet: pet,
            spendable: spendable,
            savings: savings,
            onOpenSettings: onOpenSettings,
          ),
          const SizedBox(height: 8),
          _PetPortrait(
            pet: pet,
            hasActiveEvent: activeEvent != null,
            onOpenEvent: onOpenEvent,
          ),
          if (activeEvent != null) ...[
            const SizedBox(height: 10),
            PetEventBanner(event: activeEvent!, petName: pet.name, onPressed: onOpenEvent),
          ],
          const SizedBox(height: 16),
          PetStatsCard(
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
                color: activeEvent == null
                    ? const Color(0xFF3E8ED0)
                    : const Color(0xFFE39422),
                value: pet.health,
                onTap: onOpenInsurance,
              ),
            ],
          ),
          const SizedBox(height: 14),
          BudgetPlanCard(
            period: period,
            onConfirm: onConfirmPlan,
            onStartPeriod: onStartPeriod,
          ),
          const SizedBox(height: 14),
          const CollectionCard(),
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
  });

  final Pet pet;
  final VoidCallback? onOpenSettings;
  final int spendable;
  final int savings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Takes the slot the reference gives a back button: the home tab
            // is a root, so the useful action here is the child's settings.
            if (onOpenSettings != null)
              IconButton(
                tooltip: 'Настройки',
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
                color: AppColors.ink,
              ),
            const Spacer(),
            _CoinPill(spendable: spendable, savings: savings),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icons/leaf.png', width: 26, height: 26),
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
                'assets/icons/leaf.png',
                width: 26,
                height: 26,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.fieldBorder.withValues(alpha: 0.7),
            ),
          ),
          child: Text(
            'Стадия ${pet.evolutionStage} из ${Pet.maxStage} · ${pet.stageName}',
            style: AppTextStyles.swatchLabel.copyWith(color: AppColors.ink),
          ),
        ),
      ],
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
            Image.asset('assets/icons/coin.png', width: 22, height: 22),
            const SizedBox(width: 6),
            Text('$spendable', style: AppTextStyles.counterValue),
            const SizedBox(width: 10),
            Image.asset('assets/icons/pig.png', width: 22, height: 22),
            const SizedBox(width: 6),
            Text('$savings', style: AppTextStyles.counterValue),
          ],
        ),
      ),
    );
  }
}

class _PetPortrait extends StatelessWidget {
  const _PetPortrait({
    required this.pet,
    required this.hasActiveEvent,
    required this.onOpenEvent,
  });

  final Pet pet;
  final bool hasActiveEvent;
  final VoidCallback onOpenEvent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Питомец ${pet.name}, ${_moodWord(pet)}',
      image: true,
      child: SizedBox(
        height: 260,
        // Keyed by the asset so a mood change cross-fades instead of snapping.
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Image.asset(
                pet.assetPath,
                key: ValueKey(pet.assetPath),
                fit: BoxFit.contain,
              ),
            ),
            if (hasActiveEvent) ...[
              Positioned(
                top: 34,
                right: 54,
                child: Transform.rotate(
                  angle: -0.25,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8D1C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF968B7D)),
                    ),
                    child: const Icon(
                      Icons.healing_rounded,
                      color: Color(0xFF6F665B),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 32,
                bottom: 28,
                child: PetEventIndicator(petName: pet.name, onPressed: onOpenEvent),
              ),
            ],
          ],
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
