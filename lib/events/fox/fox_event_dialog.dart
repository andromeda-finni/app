import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../onboarding/widgets/story_button.dart';
import 'fox_event_content.dart';
import 'fox_event_dialog_controller.dart';
import 'fox_event_models.dart';
import 'fox_event_wallet.dart';

Future<FoxDialogResult> showFoxEventDialog(
  BuildContext context, {
  required FoxEventLaunch launch,
  required FoxEventWallet wallet,
  required FoxRuntimeMode mode,
  required int currentGameDay,
  required String petName,
}) async {
  final script = foxScriptById(launch.session.scriptId);
  final result = await showDialog<FoxDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => FoxEventDialog(
      script: script,
      session: launch.session,
      wallet: wallet,
      mode: mode,
      currentGameDay: currentGameDay,
      isReturnVisit: launch.isReturnVisit,
      petName: petName,
    ),
  );
  return result ?? FoxDialogResult.paused;
}

class FoxEventDialog extends StatefulWidget {
  const FoxEventDialog({
    super.key,
    required this.script,
    required this.session,
    required this.wallet,
    required this.mode,
    required this.currentGameDay,
    required this.isReturnVisit,
    this.petName = 'Грошик',
  });

  final FoxScript script;
  final FoxEventSession session;
  final FoxEventWallet wallet;
  final FoxRuntimeMode mode;
  final int currentGameDay;
  final bool isReturnVisit;
  final String petName;

  @override
  State<FoxEventDialog> createState() => _FoxEventDialogState();
}

class _FoxEventDialogState extends State<FoxEventDialog> {
  late final FoxEventDialogController _controller;
  String? _storyNodeId;
  int _storyPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = FoxEventDialogController(
      script: widget.script,
      session: widget.session,
      wallet: widget.wallet,
      mode: widget.mode,
      currentGameDay: widget.currentGameDay,
      isReturnVisit: widget.isReturnVisit,
      demoTransitionDuration:
          MediaQueryData.fromView(
            WidgetsBinding.instance.platformDispatcher.views.first,
          ).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(AppRadii.sheet),
              border: Border.all(color: AppColors.parchmentDark, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.sheet - 2),
              child: AnimatedBuilder(
                // Every wallet mutation in this flow is followed by a
                // controller notification, so the event module can depend on
                // the wallet interface without requiring it to be Listenable.
                animation: _controller,
                builder: (context, _) => Column(
                  children: [
                    _DialogHeader(
                      title: widget.script.title,
                      day: widget.currentGameDay,
                      balance: widget.wallet.balance,
                      showStoryMetadata: !_controller.showArrival,
                      onClose: _close,
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        child: _body(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_controller.showArrival) {
      return _ArrivalView(
        key: const ValueKey('arrival'),
        isReturnVisit: widget.isReturnVisit,
        mood: widget.script.node(widget.session.currentNodeId).mood,
        onContinue: _controller.continueFromArrival,
      );
    }
    if (_controller.transitioning) {
      return const _TimeTransitionView(key: ValueKey('time-transition'));
    }
    final node = _controller.node;
    if (_storyNodeId != node.id) {
      _storyNodeId = node.id;
      _storyPageIndex = 0;
    }
    return _StoryView(
      key: ValueKey(node.id),
      node: node,
      balance: widget.wallet.balance,
      busy: _controller.busy,
      errorMessage: _controller.errorMessage,
      petName: widget.petName,
      pageIndex: _storyPageIndex,
      onAdvancePage: _advanceStoryPage,
      onChoice: _select,
      onFinish: _finish,
    );
  }

  void _advanceStoryPage() {
    final lastPageIndex = _controller.node.textPages.length - 1;
    if (_storyPageIndex >= lastPageIndex) return;
    setState(() => _storyPageIndex += 1);
  }

  Future<void> _select(FoxChoice choice) async {
    final result = await _controller.select(choice);
    if (!mounted) return;
    if (result.dialogResult == FoxDialogResult.waitingForNextDay) {
      Navigator.of(context).pop(FoxDialogResult.waitingForNextDay);
    }
  }

  void _finish() => Navigator.of(context).pop(FoxDialogResult.completed);

  void _close() {
    final result = _controller.node.terminal
        ? FoxDialogResult.completed
        : FoxDialogResult.paused;
    Navigator.of(context).pop(result);
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.title,
    required this.day,
    required this.balance,
    required this.showStoryMetadata,
    required this.onClose,
  });

  final String title;
  final int day;
  final int balance;
  final bool showStoryMetadata;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.parchment,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              if (showStoryMetadata)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.eventTitle),
                      Text(
                        'Игровой день $day',
                        style: AppTextStyles.stepCounter,
                      ),
                    ],
                  ),
                )
              else
                const Spacer(),
              _CoinChip(balance: balance),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Закрыть событие',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
                color: AppColors.ink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrivalView extends StatelessWidget {
  const _ArrivalView({
    super.key,
    required this.isReturnVisit,
    required this.mood,
    required this.onContinue,
  });

  final bool isReturnVisit;
  final FoxMood mood;
  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          _FoxPortrait(mood: mood, height: 290),
          const SizedBox(height: 12),
          Text(
            isReturnVisit ? 'Лис вернулся' : 'Пришел Лис',
            textAlign: TextAlign.center,
            style: AppTextStyles.screenTitle,
          ),
          if (isReturnVisit) ...[
            const SizedBox(height: 8),
            Text(
              'Прошёл один игровой день. Посмотрим, чем закончилась история.',
              textAlign: TextAlign.center,
              style: AppTextStyles.story,
            ),
          ],
          const SizedBox(height: 20),
          StoryButton(
            label: isReturnVisit ? 'Узнать, что случилось' : 'Поговорить',
            onPressed: () => onContinue(),
          ),
        ],
      ),
    );
  }
}

class _TimeTransitionView extends StatelessWidget {
  const _TimeTransitionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wb_twilight_rounded,
              size: 64,
              color: AppColors.coinGold,
            ),
            const SizedBox(height: 20),
            Text(
              'Наступил следующий игровой день...',
              textAlign: TextAlign.center,
              style: AppTextStyles.screenTitle,
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryView extends StatelessWidget {
  const _StoryView({
    super.key,
    required this.node,
    required this.balance,
    required this.busy,
    required this.errorMessage,
    required this.petName,
    required this.pageIndex,
    required this.onAdvancePage,
    required this.onChoice,
    required this.onFinish,
  });

  final FoxStoryNode node;
  final int balance;
  final bool busy;
  final String? errorMessage;
  final String petName;
  final int pageIndex;
  final VoidCallback onAdvancePage;
  final ValueChanged<FoxChoice> onChoice;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight = constraints.maxHeight < 580 ? 150.0 : 205.0;
        final pages = node.textPages;
        final hasMorePages = pageIndex < pages.length - 1;
        final content = SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FoxPortrait(mood: node.mood, height: imageHeight),
              const SizedBox(height: 8),
              Text(
                _withPetName(node.speaker, petName),
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: Text(
                  _withPetName(pages[pageIndex], petName),
                  key: ValueKey('${node.id}:$pageIndex'),
                  style: AppTextStyles.story,
                ),
              ),
              if (!hasMorePages && node.groshikFeedback != null) ...[
                const SizedBox(height: 16),
                _FeedbackCard(node: node, petName: petName),
              ],
              if (!hasMorePages && errorMessage != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    errorMessage!,
                    style: AppTextStyles.supporting.copyWith(
                      color: AppColors.crimsonDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (hasMorePages)
                _ContinueHint(
                  currentPage: pageIndex + 1,
                  totalPages: pages.length,
                )
              else if (node.terminal)
                StoryButton(label: 'Понятно', onPressed: onFinish)
              else
                for (final choice in node.choices) ...[
                  _FoxChoiceButton(
                    choice: choice,
                    enabled:
                        !busy &&
                        (choice.coinDelta >= 0 || balance >= -choice.coinDelta),
                    onPressed: () => onChoice(choice),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        );
        if (!hasMorePages) return content;
        return Semantics(
          button: true,
          label: 'Показать следующую реплику Лиса',
          onTap: onAdvancePage,
          child: GestureDetector(
            key: const ValueKey('fox-story-continue'),
            behavior: HitTestBehavior.opaque,
            onTap: onAdvancePage,
            child: content,
          ),
        );
      },
    );
  }
}

class _ContinueHint extends StatelessWidget {
  const _ContinueHint({required this.currentPage, required this.totalPages});

  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              'Нажми, чтобы продолжить',
              textAlign: TextAlign.center,
              style: AppTextStyles.supporting.copyWith(
                color: AppColors.crimsonDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.touch_app_outlined,
            color: AppColors.crimsonDark,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text('$currentPage/$totalPages', style: AppTextStyles.stepCounter),
        ],
      ),
    );
  }
}

class _FoxChoiceButton extends StatelessWidget {
  const _FoxChoiceButton({
    required this.choice,
    required this.enabled,
    required this.onPressed,
  });

  final FoxChoice choice;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: choice.label,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.canvasWarm,
          disabledForegroundColor: AppColors.inkMuted,
          disabledBackgroundColor: AppColors.parchment,
          minimumSize: const Size(double.infinity, 56),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: const BorderSide(color: AppColors.fieldBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
        child: Text(
          choice.label,
          style: AppTextStyles.story.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.node, required this.petName});

  final FoxStoryNode node;
  final String petName;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background) = switch (node.outcomeTone) {
      FoxOutcomeTone.positive => (
        Icons.check_circle_outline_rounded,
        AppColors.leafGreen,
        const Color(0xFFEAF1E4),
      ),
      FoxOutcomeTone.caution => (
        Icons.lightbulb_outline_rounded,
        AppColors.crimsonDark,
        AppColors.infoBg,
      ),
      FoxOutcomeTone.neutral => (
        Icons.chat_bubble_outline_rounded,
        AppColors.inkMuted,
        AppColors.canvasWarm,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(petName, style: AppTextStyles.sectionTitle),
                const SizedBox(height: 4),
                Text(
                  _withPetName(node.groshikFeedback!, petName),
                  style: AppTextStyles.story,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FoxPortrait extends StatelessWidget {
  const _FoxPortrait({required this.mood, required this.height});

  final FoxMood mood;
  final double height;

  @override
  Widget build(BuildContext context) {
    final imageSize = height * 1.9;
    return Semantics(
      image: true,
      label: mood == FoxMood.sly ? 'Лис говорит хитро' : 'Лис говорит спокойно',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minWidth: imageSize,
            maxWidth: imageSize,
            minHeight: imageSize,
            maxHeight: imageSize,
            child: Image.asset(
              mood == FoxMood.sly
                  ? 'assets/Fox/fox_sly.png'
                  : 'assets/Fox/fox_friendly.png',
              width: imageSize,
              height: imageSize,
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
            ),
          ),
        ),
      ),
    );
  }
}

String _withPetName(String text, String petName) =>
    text.replaceAll('{petName}', petName);

class _CoinChip extends StatelessWidget {
  const _CoinChip({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Баланс: $balance монет',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icons/coin.png',
              width: 24,
              height: 24,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 6),
            Text('$balance', style: AppTextStyles.counterValue),
          ],
        ),
      ),
    );
  }
}
