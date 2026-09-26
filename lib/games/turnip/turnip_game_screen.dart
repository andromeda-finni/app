import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'turnip_game_content.dart';
import 'turnip_game_controller.dart';
import 'turnip_game_models.dart';
import 'widgets/turnip_intro_view.dart';
import 'widgets/turnip_playfield.dart';
import 'widgets/turnip_success_view.dart';

class TurnipGameScreen extends StatefulWidget {
  const TurnipGameScreen({
    super.key,
    required this.difficulty,
    this.petName = turnipDefaultPetName,
    this.onCompleted,
    this.onExit,
  });

  final TurnipDifficulty difficulty;
  final String petName;
  final ValueChanged<TurnipGameResult>? onCompleted;
  final VoidCallback? onExit;

  @override
  State<TurnipGameScreen> createState() => _TurnipGameScreenState();
}

class _TurnipGameScreenState extends State<TurnipGameScreen>
    with SingleTickerProviderStateMixin {
  late TurnipGameController _controller;
  late final AnimationController _shakeController;
  late final Animation<double> _shake;
  bool _completionReported = false;

  @override
  void initState() {
    super.initState();
    _controller = TurnipGameController(difficulty: widget.difficulty);
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _shake = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 8, end: -5), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -5, end: 0), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant TurnipGameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.difficulty != widget.difficulty) {
      _controller.dispose();
      _controller = TurnipGameController(difficulty: widget.difficulty);
      _completionReported = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canExit = widget.onExit != null || Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: DecoratedBox(
              decoration: const BoxDecoration(color: AppColors.canvasWarm),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => _GameHeader(
                      canExit: canExit,
                      showHint: _controller.phase == TurnipGamePhase.playing,
                      hintActive: _controller.hintVisible,
                      onExit: _exit,
                      onHint: _controller.showHint,
                    ),
                  ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _controller,
                        _shakeController,
                      ]),
                      builder: (context, _) => AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        child: _body(canExit: canExit),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body({required bool canExit}) {
    final introLines = turnipIntroLinesFor(widget.petName);
    return switch (_controller.phase) {
      TurnipGamePhase.intro => TurnipIntroView(
        key: const ValueKey('turnip-intro'),
        line: introLines[_controller.introPageIndex],
        pageIndex: _controller.introPageIndex,
        pageCount: introLines.length,
        onContinue: () =>
            _controller.advanceIntro(pageCount: introLines.length),
      ),
      TurnipGamePhase.playing => TurnipPlayfield(
        key: const ValueKey('turnip-playing'),
        controller: _controller,
        onPlace: _place,
        shakeOffset: _shake.value,
      ),
      TurnipGamePhase.pulling => const TurnipPullingView(
        key: ValueKey('turnip-pulling'),
      ),
      TurnipGamePhase.completed => TurnipSuccessView(
        key: const ValueKey('turnip-completed'),
        rewardAmount: _controller.result.rewardAmount,
        onReplay: _replay,
        onExit: canExit ? _exit : null,
      ),
    };
  }

  void _place(TurnipCharacter character) {
    final result = _controller.place(character);
    if (result == TurnipPlacementResult.rejected &&
        !MediaQuery.disableAnimationsOf(context)) {
      unawaited(_shakeController.forward(from: 0));
    }
    if (result == TurnipPlacementResult.completed) {
      unawaited(_finishPulling());
    }
  }

  Future<void> _finishPulling() async {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!reduceMotion) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
    if (!mounted || _controller.phase != TurnipGamePhase.pulling) return;
    _controller.finishPulling();
    if (!_completionReported) {
      _completionReported = true;
      widget.onCompleted?.call(_controller.result);
    }
  }

  void _replay() {
    _completionReported = false;
    _controller.restart();
  }

  void _exit() {
    if (widget.onExit case final callback?) {
      callback();
      return;
    }
    Navigator.of(context).maybePop();
  }
}

class _GameHeader extends StatelessWidget {
  const _GameHeader({
    required this.canExit,
    required this.showHint,
    required this.hintActive,
    required this.onExit,
    required this.onHint,
  });

  final bool canExit;
  final bool showHint;
  final bool hintActive;
  final VoidCallback onExit;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.parchment,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: canExit
                  ? IconButton(
                      key: const ValueKey('turnip-back'),
                      tooltip: 'Выйти из игры',
                      onPressed: onExit,
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.ink,
                    )
                  : null,
            ),
            Expanded(
              child: Text(
                'Репка',
                textAlign: TextAlign.center,
                style: AppTextStyles.eventTitle.copyWith(fontSize: 30),
              ),
            ),
            SizedBox(
              width: 56,
              child: showHint
                  ? IconButton(
                      key: const ValueKey('turnip-hint-button'),
                      tooltip: 'Показать подсказку',
                      onPressed: onHint,
                      icon: Icon(
                        hintActive
                            ? Icons.lightbulb_rounded
                            : Icons.help_outline_rounded,
                      ),
                      color: hintActive
                          ? AppColors.coinGold
                          : AppColors.crimson,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
