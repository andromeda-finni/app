import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../minigames/quest_reward_messages.dart';
import '../../theme/app_theme.dart';
import 'goldfish_game_content.dart';
import 'goldfish_game_controller.dart';
import 'goldfish_game_models.dart';
import 'widgets/goldfish_dialogue_view.dart';
import 'widgets/goldfish_result_view.dart';
import 'widgets/goldfish_shopping_view.dart';

class GoldfishGameScreen extends StatefulWidget {
  const GoldfishGameScreen({
    super.key,
    required this.initialLevel,
    this.apiClient,
    this.petName = goldfishDefaultPetName,
    this.enableSequentialNext = true,
    this.onExit,
  });

  final GoldfishLevelId initialLevel;
  final ApiClient? apiClient;
  final String petName;
  final bool enableSequentialNext;
  final VoidCallback? onExit;

  @override
  State<GoldfishGameScreen> createState() => _GoldfishGameScreenState();
}

class _GoldfishGameScreenState extends State<GoldfishGameScreen> {
  late final GoldfishGameController _controller;
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
    _controller = GoldfishGameController(
      goldfishLevelFor(widget.initialLevel, petName: widget.petName),
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

  void _toggleOffer(GoldfishOffer offer) {
    final result = _controller.toggleOffer(offer.id);
    if (!result.changed && result.missingCoins > 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(_insufficientCoinsSnackBar(result.missingCoins));
    }
  }

  void _checkSelection() {
    final result = _controller.checkSelection();
    if (result.isSuccessful) _completeServerLevel();
  }

  Future<void> _completeServerLevel() async {
    if (_isSyncing || _serverLevelCompleted || widget.apiClient == null) return;
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
    _controller.startLevel(goldfishLevelFor(next, petName: widget.petName));
    _prepareServerLevel();
  }

  @override
  Widget build(BuildContext context) {
    final canExit = widget.onExit != null || Navigator.of(context).canPop();
    final body = switch (_controller.phase) {
      GoldfishGamePhase.intro ||
      GoldfishGamePhase.resultDialogue => GoldfishDialogueView(
        line: _controller.activeDialogue[_controller.dialoguePageIndex],
        pageIndex: _controller.dialoguePageIndex,
        pageCount: _controller.activeDialogue.length,
        onContinue: _controller.advanceDialogue,
        isResultDialogue: _controller.phase == GoldfishGamePhase.resultDialogue,
        successfulResult: _controller.result?.isSuccessful == true,
        onExit: canExit ? _exit : null,
      ),
      GoldfishGamePhase.shopping => GoldfishShoppingView(
        controller: _controller,
        onToggle: _toggleOffer,
        onCheck: _checkSelection,
        onShowHint: _showHint,
        onExit: canExit ? _exit : null,
      ),
      GoldfishGamePhase.result => GoldfishResultView(
        level: _controller.level,
        result: _controller.result!,
        selectedOffers: [
          for (final id in _controller.selectedItemIds)
            _controller.level.offerById(id),
        ],
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
        onExit: canExit ? _exit : null,
      ),
    };

    return Scaffold(backgroundColor: AppColors.canvasWarm, body: body);
  }
}

SnackBar _insufficientCoinsSnackBar(int missingCoins) {
  final amount =
      '$missingCoins ${missingCoins % 10 == 1 && missingCoins % 100 != 11 ? 'монеты' : 'монет'}';
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    margin: const EdgeInsets.all(AppSpacing.md),
    padding: EdgeInsets.zero,
    duration: const Duration(milliseconds: 2200),
    content: Semantics(
      liveRegion: true,
      excludeSemantics: true,
      label: 'Не хватает $amount. Сравни цены и выбери товар подешевле.',
      child: Container(
        key: const ValueKey('goldfish-insufficient-coins-notice'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.crimson, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: const BoxDecoration(
                color: AppColors.infoBg,
                shape: BoxShape.circle,
              ),
              child: Image.asset('assets/icons/coin.webp'),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Не хватает $amount',
                    style: AppTextStyles.cardRowLabel.copyWith(
                      color: AppColors.crimsonDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Сравни цены и выбери товар подешевле.',
                    style: AppTextStyles.supporting.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
