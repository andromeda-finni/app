import 'package:flutter/material.dart';

import '../events/fox/fox_event_dialog.dart';
import '../events/fox/fox_event_engine.dart';
import '../events/fox/fox_event_models.dart';
import '../events/fox/fox_event_wallet.dart';
import '../onboarding/widgets/story_button.dart';
import '../theme/app_theme.dart';

/// Temporary whole-app integration point for random Fox events.
///
/// The screen owns only an in-memory clock and wallet. The event engine itself
/// is independent of this UI and can later be driven by the real home screen,
/// persisted game day and economy without changing the scenario graph.
class PetHomeScreen extends StatefulWidget {
  const PetHomeScreen({
    super.key,
    this.petName = 'Грошик',
    @visibleForTesting this.engine,
    @visibleForTesting this.wallet,
  });

  final String petName;
  final FoxRandomEventEngine? engine;
  final InMemoryFoxEventWallet? wallet;

  @override
  State<PetHomeScreen> createState() => _PetHomeScreenState();
}

class _PetHomeScreenState extends State<PetHomeScreen> {
  late final FoxRandomEventEngine _engine =
      widget.engine ?? FoxRandomEventEngine();
  late final InMemoryFoxEventWallet _wallet =
      widget.wallet ?? InMemoryFoxEventWallet();
  late final bool _ownsEngine = widget.engine == null;
  late final bool _ownsWallet = widget.wallet == null;
  bool _openingEvent = false;

  @override
  void dispose() {
    if (_ownsEngine) _engine.dispose();
    if (_ownsWallet) _wallet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_engine, _wallet]),
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/backgrounds/town.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              excludeFromSemantics: true,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x22000000), Color(0x99000000)],
                  stops: [0.35, 1],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - AppSpacing.xxl,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _HomeStatusBar(
                          day: _engine.gameDay,
                          balance: _wallet.balance,
                        ),
                        SizedBox(
                          height: constraints.maxHeight < 700 ? 32 : 180,
                        ),
                        _EventControlCard(
                          engine: _engine,
                          openingEvent: _openingEvent,
                          onNextDay: _startNextDay,
                          onResume: _resumeConversation,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startNextDay() async {
    if (_openingEvent) return;
    final launch = _engine.startNextDay(
      forceEvent: _engine.mode == FoxRuntimeMode.demo,
    );
    if (launch == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сегодня Лис не пришёл.')));
      return;
    }
    await _openEvent(launch);
  }

  Future<void> _resumeConversation() async {
    if (_openingEvent) return;
    final launch = _engine.resumeConversation();
    if (launch != null) await _openEvent(launch);
  }

  Future<void> _openEvent(FoxEventLaunch launch) async {
    setState(() => _openingEvent = true);
    final result = await showFoxEventDialog(
      context,
      launch: launch,
      wallet: _wallet,
      mode: _engine.mode,
      currentGameDay: _engine.gameDay,
      petName: widget.petName,
    );
    _engine.acceptDialogResult(result);
    if (!mounted) return;
    setState(() => _openingEvent = false);
    if (result == FoxDialogResult.waitingForNextDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Продолжение появится через один игровой день.'),
        ),
      );
    }
  }
}

class _HomeStatusBar extends StatelessWidget {
  const _HomeStatusBar({required this.day, required this.balance});

  final int day;
  final int balance;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runAlignment: WrapAlignment.spaceBetween,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _StatusChip(icon: Icons.calendar_today_rounded, label: 'День $day'),
        _StatusChip(asset: 'assets/icons/coin.png', label: '$balance монет'),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({this.icon, this.asset, required this.label});

  final IconData? icon;
  final String? asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.parchmentDark),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (asset != null)
            Image.asset(asset!, width: 22, height: 22)
          else
            Icon(icon, size: 19, color: AppColors.crimsonDark),
          const SizedBox(width: 7),
          Text(label, style: AppTextStyles.cardRowLabel),
        ],
      ),
    );
  }
}

class _EventControlCard extends StatelessWidget {
  const _EventControlCard({
    required this.engine,
    required this.openingEvent,
    required this.onNextDay,
    required this.onResume,
  });

  final FoxRandomEventEngine engine;
  final bool openingEvent;
  final VoidCallback onNextDay;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final locked = engine.session != null;
    final waiting = engine.isWaitingForReturn;
    final paused = engine.hasPausedConversation;
    final helper = waiting
        ? 'Лис вернётся, когда наступит следующий игровой день.'
        : engine.mode == FoxRuntimeMode.demo
        ? 'Событие запускается сразу, а ожидание следующего дня проматывается.'
        : 'Каждый новый день Лис может прийти случайно. Шанс события — 25%.';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(AppRadii.sheet),
        border: Border.all(color: AppColors.parchmentDark, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Случайные события', style: AppTextStyles.screenTitle),
          const SizedBox(height: 4),
          Text(helper, style: AppTextStyles.supporting),
          const SizedBox(height: AppSpacing.md),
          Text('Режим времени', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.xs),
          _OptionRow<FoxRuntimeMode>(
            values: FoxRuntimeMode.values,
            selected: engine.mode,
            label: (value) => value.label,
            onSelected: locked ? null : engine.setMode,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Сложность', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.xs),
          _OptionRow<FoxAgeGroup>(
            values: FoxAgeGroup.values,
            selected: engine.ageGroup,
            label: (value) => value.label,
            onSelected: locked ? null : engine.setAgeGroup,
          ),
          const SizedBox(height: AppSpacing.lg),
          StoryButton(
            label: paused
                ? 'Продолжить разговор с Лисом'
                : waiting
                ? 'Начать следующий игровой день'
                : 'Начать новый игровой день',
            onPressed: openingEvent
                ? null
                : paused
                ? onResume
                : onNextDay,
            isLoading: openingEvent,
          ),
        ],
      ),
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(label(value)),
            selected: value == selected,
            onSelected: onSelected == null
                ? null
                : (isSelected) {
                    if (isSelected) onSelected!(value);
                  },
            selectedColor: AppColors.parchmentDark,
            backgroundColor: AppColors.canvasWarm,
            side: BorderSide(
              color: value == selected
                  ? AppColors.crimson
                  : AppColors.fieldBorder,
            ),
            labelStyle: AppTextStyles.supporting.copyWith(
              color: AppColors.ink,
              fontWeight: value == selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
      ],
    );
  }
}
