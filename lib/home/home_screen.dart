import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../events/pet_event_dialog.dart';
import '../events/pet_event_indicator.dart';
import '../events/pet_event_models.dart';
import '../services/pet_event_service.dart';
import '../theme/app_theme.dart';
import 'models/home_economy_state.dart';
import 'pet_care_screen.dart';
import 'widgets/budget_plan_card.dart';
import 'widgets/dream_card.dart';
import 'widgets/pet_name_header.dart';
import 'widgets/pet_scene.dart';

enum _LoadState { loading, ready, error }

/// The game-day home. Pet care intentionally lives on [PetCareScreen].
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.apiClient,
    this.onOpenShop,
    this.onOpenQuests,
    this.onOpenSettings,
    this.onOpenInsurance,
    this.onPlanningRequiredChanged,
  });

  final ApiClient apiClient;
  final VoidCallback? onOpenShop;
  final VoidCallback? onOpenQuests;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenInsurance;
  final ValueChanged<bool>? onPlanningRequiredChanged;

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
      widget.onOpenShop?.call();
      return;
    }
    await widget.apiClient.post('/periods');
    PetEventRollResult? roll;
    Object? rollError;
    try {
      roll = await _eventService.roll();
    } catch (error) {
      rollError = error;
    }
    await _load(showLoader: false);
    if (!mounted) return;
    if (rollError != null) {
      _showError(
        'День начался, но событие не удалось проверить. Обнови экран чуть позже.',
      );
    } else if (roll?.insuranceNotice != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(roll!.insuranceNotice!)));
    }
    if (roll?.event != null) await _openEvent(event: roll!.event);
  });

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

  Future<void> _closeDay() async {
    try {
      await _runMutation(() async {
        final day = _data?.activeDay;
        if (day == null || !day.isConfirmed) return;
        final response = await widget.apiClient.post(
          '/periods/${day.id}/close',
        );
        final feedback = response['feedback'] as String?;
        await _load(showLoader: false);
        if (!mounted || feedback == null) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(feedback)));
      });
    } catch (_) {
      if (mounted) {
        _showError('Не получилось завершить день. Попробуй ещё раз.');
      }
    }
  }

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
        onOpenGoal: widget.onOpenShop ?? _showProgress,
        onOpenPlan: _openPlan,
        onCloseDay: _closeDay,
        onProgress: _showProgress,
        onOpenEvent: _openEvent,
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
    required this.onOpenPlan,
    required this.onCloseDay,
    required this.onProgress,
    required this.onOpenEvent,
  });

  final HomeEconomyState data;
  final bool offline;
  final bool busy;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String) onRename;
  final VoidCallback onSettings;
  final VoidCallback onOpenCare;
  final VoidCallback onOpenGoal;
  final VoidCallback onOpenPlan;
  final VoidCallback onCloseDay;
  final VoidCallback onProgress;
  final VoidCallback onOpenEvent;

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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stack = constraints.maxWidth < 430;
                      final finish = _QuickAction(
                        key: const Key('finish-day'),
                        icon: Icons.nights_stay_rounded,
                        label: 'Завершить день',
                        onTap: day?.isConfirmed == true && !busy
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
