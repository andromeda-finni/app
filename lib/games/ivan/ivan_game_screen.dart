import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../minigames/quest_reward_messages.dart';
import '../../theme/app_theme.dart';
import 'ivan_game_content.dart';
import 'ivan_game_controller.dart';
import 'ivan_game_models.dart';
import 'widgets/ivan_intro_view.dart';
import 'widgets/ivan_result_view.dart';
import 'widgets/ivan_shopping_view.dart';

class IvanGameScreen extends StatefulWidget {
  const IvanGameScreen({
    super.key,
    required this.initialLevel,
    this.apiClient,
    this.petName = ivanDefaultPetName,
    this.enableSequentialNext = true,
    this.onExit,
  });

  final IvanLevelId initialLevel;
  final ApiClient? apiClient;
  final String petName;
  final bool enableSequentialNext;
  final VoidCallback? onExit;

  @override
  State<IvanGameScreen> createState() => _IvanGameScreenState();
}

class _IvanGameScreenState extends State<IvanGameScreen> {
  late final IvanGameController _controller;
  String? _assignmentId;
  int? _rewardAmount;
  String? _statusNote;
  bool _isSyncing = false;
  bool _serverLevelCompleted = false;
  bool _rewardWasAlreadyGranted = false;
  Future<void>? _startFuture;

  @override
  void initState() {
    super.initState();
    _controller = IvanGameController(
      ivanLevelFor(widget.initialLevel, petName: widget.petName),
    )..addListener(_refresh);
    _prepareServerLevel();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _prepareServerLevel() {
    _assignmentId = null;
    _rewardAmount = null;
    _rewardWasAlreadyGranted = false;
    _serverLevelCompleted = false;
    if (widget.apiClient == null) {
      _statusNote =
          'Деморежим: награда ${_controller.level.reward} монет не начисляется.';
      _startFuture = null;
    } else {
      _statusNote = null;
      _startFuture = _startServerLevel();
    }
  }

  Future<void> _startServerLevel() async {
    try {
      final response = await widget.apiClient!.post(
        '/quests/${_controller.level.questId}/start',
      );
      if (!mounted) return;
      setState(() {
        if (response['completed'] == true) {
          _serverLevelCompleted = true;
          _rewardWasAlreadyGranted = true;
          _rewardAmount = (response['rewardAmount'] as num?)?.toInt();
          _statusNote =
              'Награда за этот уровень уже получена. Сейчас это тренировка.';
        } else {
          _assignmentId = response['assignmentId'] as String?;
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _statusNote = questProblemMessage(error));
    }
  }

  void _checkSelection() {
    final result = _controller.checkSelection();
    if (result.isSuccessful) _completeServerLevel();
  }

  Future<void> _completeServerLevel() async {
    if (_isSyncing || _serverLevelCompleted) return;
    if (widget.apiClient == null) return;
    await _startFuture;
    if (!mounted || _serverLevelCompleted) return;
    if (_assignmentId == null) {
      _startFuture = _startServerLevel();
      await _startFuture;
    }
    if (!mounted || _assignmentId == null || _serverLevelCompleted) return;

    setState(() => _isSyncing = true);
    try {
      final selected = _controller.selectedItemIds.toList()..sort();
      final response = await widget.apiClient!.post(
        '/assignments/$_assignmentId/answer',
        body: {'stepNo': 1, 'selectedOptionCode': selected.join(',')},
      );
      if (!mounted) return;
      setState(() {
        if (response['questCompleted'] == true) {
          _serverLevelCompleted = true;
          _assignmentId = null;
          _rewardAmount = (response['rewardAmount'] as num?)?.toInt();
          _rewardWasAlreadyGranted = response['rewardAlreadyGranted'] == true;
          _statusNote = null;
        } else {
          _statusNote = questRecoveryMessage(response);
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _statusNote = questProblemMessage(error));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showHint() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBg,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                size: 42,
                color: AppColors.coinGold,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Подсказка', style: AppTextStyles.screenTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _controller.level.hintText,
                textAlign: TextAlign.center,
                style: AppTextStyles.story,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exit() {
    if (widget.onExit != null) {
      widget.onExit!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _startNextLevel() {
    final next = _controller.level.id.next;
    if (next == null) return;
    _controller.startLevel(ivanLevelFor(next, petName: widget.petName));
    _prepareServerLevel();
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_controller.phase) {
      IvanGamePhase.intro => IvanIntroView(
        line: _controller.level.introLines[_controller.introPageIndex],
        pageIndex: _controller.introPageIndex,
        pageCount: _controller.level.introLines.length,
        onContinue: _controller.advanceIntro,
        onExit: widget.onExit != null || Navigator.of(context).canPop()
            ? _exit
            : null,
      ),
      IvanGamePhase.shopping => IvanShoppingView(
        controller: _controller,
        onCheck: _checkSelection,
        onShowHint: _showHint,
        onExit: widget.onExit != null || Navigator.of(context).canPop()
            ? _exit
            : null,
      ),
      IvanGamePhase.result => IvanResultView(
        level: _controller.level,
        result: _controller.result!,
        rewardAmount: _rewardAmount,
        statusNote: _statusNote,
        isSyncing: _isSyncing,
        rewardWasAlreadyGranted: _rewardWasAlreadyGranted,
        onRevise: _controller.reviseSelection,
        onReplay: _controller.replay,
        onRetrySync:
            widget.apiClient != null && !_serverLevelCompleted && !_isSyncing
            ? _completeServerLevel
            : null,
        onNextLevel:
            widget.enableSequentialNext &&
                _controller.level.id.next != null &&
                !_isSyncing &&
                (widget.apiClient == null || _serverLevelCompleted)
            ? _startNextLevel
            : null,
        onExit: widget.onExit != null || Navigator.of(context).canPop()
            ? _exit
            : null,
      ),
    };

    return Scaffold(backgroundColor: AppColors.canvasWarm, body: body);
  }
}
