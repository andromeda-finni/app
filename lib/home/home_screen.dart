import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/pet_assets.dart';
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
  const HomeScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _LoadState _state = _LoadState.loading;
  Pet? _pet;
  ActivePeriod? _period;
  Map<String, int> _wallets = const {};

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
        _state = _LoadState.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _LoadState.error);
    }
  }

  Future<void> _startPeriod() async {
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
                  'Не получилось загрузить Грошика — проверьте подключение к интернету.',
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
          period: _period,
          spendable: _wallets['SPENDABLE'] ?? 0,
          savings: _wallets['SAVINGS'] ?? 0,
          onRefresh: _load,
          onConfirmPlan: _confirmPlan,
          onStartPeriod: _startPeriod,
        );
    }
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.pet,
    required this.period,
    required this.spendable,
    required this.savings,
    required this.onRefresh,
    required this.onConfirmPlan,
    required this.onStartPeriod,
  });

  final Pet pet;
  final ActivePeriod? period;
  final int spendable;
  final int savings;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int, int, int) onConfirmPlan;
  final Future<void> Function() onStartPeriod;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.crimson,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Header(pet: pet, spendable: spendable, savings: savings),
          const SizedBox(height: 8),
          _PetPortrait(pet: pet),
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
                color: const Color(0xFF3E8ED0),
                value: pet.health,
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
    required this.spendable,
    required this.savings,
  });

  final Pet pet;
  final int spendable;
  final int savings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
