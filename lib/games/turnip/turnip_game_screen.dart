import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/game_audio_service.dart';
import '../../minigames/quest_reward_messages.dart';
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
    this.apiClient,
    this.petName = turnipDefaultPetName,
    this.onCompleted,
    this.onExit,
  });

  final TurnipDifficulty difficulty;

  /// Server the harvest is reported to. Without one the game is practice
  /// only and says so instead of showing a reward.
  final ApiClient? apiClient;
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
  String? _assignmentId;
  int? _rewardAmount;
  String? _syncNote;
  bool _isSyncing = false;
  bool _serverQuestCompleted = false;
  bool _rewardWasAlreadyGranted = false;
  Future<void>? _startFuture;

  @override
  void initState() {
    super.initState();
    _controller = TurnipGameController(difficulty: widget.difficulty);
    if (widget.apiClient == null) {
      _syncNote = 'Тренировочный режим: результат не меняет кошелёк.';
    } else {
      _startFuture = _startServerQuest();
    }
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
        rewardAmount: _rewardAmount,
        statusNote: _syncNote,
        isSyncing: _isSyncing,
        rewardWasAlreadyGranted: _rewardWasAlreadyGranted,
        onReplay: _replay,
        onRetry:
            widget.apiClient != null && !_serverQuestCompleted && !_isSyncing
            ? _submitHarvest
            : null,
        onExit: canExit ? _exit : null,
      ),
    };
  }

  void _place(TurnipCharacter character) {
    final result = _controller.place(character);
    unawaited(
      GameAudioService.instance.play(
        result == TurnipPlacementResult.rejected
            ? GameSound.tryAgain
            : GameSound.itemPlaced,
      ),
    );
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
    unawaited(GameAudioService.instance.play(GameSound.successReward));
    if (!_completionReported) {
      _completionReported = true;
      widget.onCompleted?.call(_controller.result);
      unawaited(_submitHarvest());
    }
  }

  Future<void> _startServerQuest() async {
    try {
      final result = await widget.apiClient!.post(
        '/quests/$turnipQuestId/start',
      );
      if (!mounted) return;
      setState(() {
        if (result['completed'] == true) {
          _serverQuestCompleted = true;
          _assignmentId = null;
          _syncNote =
              'Награда за это задание уже получена. Сейчас это тренировка.';
        } else {
          _assignmentId = result['assignmentId'] as String?;
          _syncNote = null;
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _syncNote = questProblemMessage(error));
    }
  }

  /// The harvest is the quest's only step; the server verifies it and pays
  /// the reward once.
  Future<void> _submitHarvest() async {
    if (_isSyncing || widget.apiClient == null || _serverQuestCompleted) return;
    await _startFuture;
    if (!mounted || _serverQuestCompleted) return;
    if (_assignmentId == null) {
      _startFuture = _startServerQuest();
      await _startFuture;
    }
    final assignmentId = _assignmentId;
    if (!mounted || assignmentId == null || _serverQuestCompleted) return;
    setState(() {
      _isSyncing = true;
      _syncNote = 'Сохраняем результат…';
    });
    try {
      final result = await widget.apiClient!.post(
        '/assignments/$assignmentId/answer',
        body: {
          'stepNo': 1,
          'selectedOptionCode': TurnipCharacter.values
              .map((character) => character.serverCode)
              .join(','),
        },
      );
      if (!mounted) return;
      setState(() {
        if (result['questCompleted'] == true) {
          _assignmentId = null;
          _rewardAmount = (result['rewardAmount'] as num?)?.toInt();
          _rewardWasAlreadyGranted = result['rewardAlreadyGranted'] == true;
          _serverQuestCompleted = true;
          _syncNote = null;
        } else {
          _syncNote = questRecoveryMessage(result);
        }
      });
      if (result['questCompleted'] == true &&
          result['rewardAlreadyGranted'] != true) {
        unawaited(GameAudioService.instance.play(GameSound.coinsMultiple));
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _syncNote = questProblemMessage(error));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _replay() {
    _completionReported = false;
    if (_rewardAmount != null) {
      // The quest is complete on the server; replays are practice.
      _rewardAmount = null;
      _syncNote = questProblemMessage(
        ApiException(409, 'quest_already_completed'),
      );
    }
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
