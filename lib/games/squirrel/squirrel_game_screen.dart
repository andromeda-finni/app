import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../minigames/quest_reward_messages.dart';
import '../../theme/app_theme.dart';
import 'squirrel_game_content.dart';
import 'squirrel_game_models.dart';
import 'squirrel_level_controller.dart';

enum _SquirrelPhase { intro, starting, playing, between, outcome, lesson }

class SquirrelGameScreen extends StatefulWidget {
  const SquirrelGameScreen({
    super.key,
    required this.difficulty,
    this.petName = squirrelDefaultPetName,
    this.apiClient,
    this.questId,
    this.demoLevel,
    this.isDemo = false,
    this.onCompleted,
    this.onExit,
  });

  final SquirrelDifficulty difficulty;
  final String petName;
  final ApiClient? apiClient;
  final String? questId;
  final SquirrelLevel? demoLevel;
  final bool isDemo;
  final ValueChanged<SquirrelGameResult>? onCompleted;
  final VoidCallback? onExit;

  @override
  State<SquirrelGameScreen> createState() => _SquirrelGameScreenState();
}

class _SquirrelGameScreenState extends State<SquirrelGameScreen> {
  _SquirrelPhase _phase = _SquirrelPhase.intro;
  int _dialoguePage = 0;
  int _levelIndex = 0;
  late SquirrelLevelController _level;
  String? _assignmentId;
  String? _syncNote;
  int? _grantedReward;
  bool _claiming = false;
  bool _outcomeSuccess = false;

  List<SquirrelLevel> get _levels =>
      widget.demoLevel == null ? widget.difficulty.levels : [widget.demoLevel!];

  @override
  void initState() {
    super.initState();
    _level = SquirrelLevelController(level: _levels.first);
  }

  @override
  void dispose() {
    _level.dispose();
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
            child: Column(
              children: [
                _SquirrelHeader(canExit: canExit, onExit: _exit),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                    child: _body(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    return switch (_phase) {
      _SquirrelPhase.intro => _SquirrelDialogue(
        key: const ValueKey('squirrel-intro'),
        background: 'assets/games/squirrel/home_background.png',
        squirrel: 'assets/games/squirrel/squirrel_friendly.png',
        lines: _firstLevelIntroLines,
        page: _dialoguePage,
        finalButton: 'Помочь Белочке!',
        onContinue: _advanceIntro,
      ),
      _SquirrelPhase.starting => _LoadingView(note: _syncNote),
      _SquirrelPhase.playing => AnimatedBuilder(
        key: ValueKey('squirrel-level-${_level.level.name}'),
        animation: _level,
        builder: (context, _) => _SquirrelPlayfield(
          controller: _level,
          levelNumber: _levelIndex + 1,
          levelCount: _levels.length,
          onChanged: _checkLevelEnd,
        ),
      ),
      _SquirrelPhase.between => _SquirrelDialogue(
        key: ValueKey('squirrel-between-${_levels[_levelIndex + 1].name}'),
        background: 'assets/games/squirrel/home_background.png',
        squirrel: 'assets/games/squirrel/squirrel_friendly.png',
        lines: squirrelIntroLinesFor(
          _levels[_levelIndex + 1],
          widget.petName,
          introduce: false,
        ),
        page: _dialoguePage,
        finalButton: 'Продолжить покупки',
        onContinue: _advanceBetween,
      ),
      _SquirrelPhase.outcome => _SquirrelDialogue(
        key: ValueKey('squirrel-outcome-$_outcomeSuccess'),
        background: 'assets/games/squirrel/home_background.png',
        squirrel: _outcomeSuccess
            ? 'assets/games/squirrel/squirrel_friendly.png'
            : 'assets/games/squirrel/squirrel_sad.png',
        lines: _outcomeLines,
        page: _dialoguePage,
        finalButton: 'Что важно запомнить',
        onContinue: _advanceOutcome,
      ),
      _SquirrelPhase.lesson => _SquirrelLessonCard(
        key: ValueKey('squirrel-lesson-${_level.level.name}'),
        message: squirrelLessonFor(_level.level),
        success: _outcomeSuccess,
        note: _syncNote,
        busy: _claiming,
        actionLabel: _outcomeSuccess
            ? _grantedReward == null
                  ? 'Забрать +${widget.difficulty.rewardAmount} 🪙'
                  : 'Готово'
            : 'Переиграть',
        onContinue: _finishLesson,
      ),
    };
  }

  List<String> get _outcomeLines => _outcomeSuccess
      ? squirrelPositiveLinesFor(_level.level)
      : squirrelNegativeLinesFor(_level.level);

  List<String> get _firstLevelIntroLines => squirrelIntroLinesFor(
    _levels.first,
    widget.petName,
    introduce: squirrelLevelIntroducesCharacter(_levels.first),
  );

  void _advanceIntro() {
    final lines = _firstLevelIntroLines;
    if (_dialoguePage < lines.length - 1) {
      setState(() => _dialoguePage++);
      return;
    }
    _startGame();
  }

  Future<void> _startGame() async {
    setState(() {
      _phase = _SquirrelPhase.starting;
      _syncNote = null;
    });
    if (!widget.isDemo && widget.apiClient != null) {
      try {
        final started = await widget.apiClient!.post(
          '/quests/${widget.questId ?? widget.difficulty.questId}/start',
        );
        _assignmentId = started['assignmentId'] as String?;
      } on ApiException catch (error) {
        _syncNote =
            '${questProblemMessage(error)} Можно потренироваться без награды.';
      }
    }
    if (!mounted) return;
    setState(() => _phase = _SquirrelPhase.playing);
  }

  void _checkLevelEnd() {
    if (!_level.finished) return;
    if (!_level.success) {
      setState(() {
        _outcomeSuccess = false;
        _dialoguePage = 0;
        _phase = _SquirrelPhase.outcome;
      });
      return;
    }
    if (_levelIndex < _levels.length - 1) {
      setState(() {
        _dialoguePage = 0;
        _phase = _SquirrelPhase.between;
      });
      return;
    }
    setState(() {
      _outcomeSuccess = true;
      _dialoguePage = 0;
      _phase = _SquirrelPhase.outcome;
    });
  }

  void _nextLevel() {
    _level.dispose();
    setState(() {
      _levelIndex++;
      _level = SquirrelLevelController(level: _levels[_levelIndex]);
      _phase = _SquirrelPhase.playing;
    });
  }

  void _advanceBetween() {
    final lines = squirrelIntroLinesFor(
      _levels[_levelIndex + 1],
      widget.petName,
      introduce: false,
    );
    if (_dialoguePage < lines.length - 1) {
      setState(() => _dialoguePage++);
      return;
    }
    _nextLevel();
  }

  void _advanceOutcome() {
    final lines = _outcomeLines;
    if (_dialoguePage < lines.length - 1) {
      setState(() => _dialoguePage++);
      return;
    }
    setState(() => _phase = _SquirrelPhase.lesson);
  }

  Future<void> _finishLesson() async {
    if (!_outcomeSuccess) {
      _level.dispose();
      setState(() {
        _level = SquirrelLevelController(level: _levels[_levelIndex]);
        _dialoguePage = 0;
        _syncNote = null;
        _phase = _SquirrelPhase.playing;
      });
      return;
    }
    if (_grantedReward != null || widget.isDemo || _assignmentId == null) {
      _reportAndExit(rewardGranted: _grantedReward != null);
      return;
    }
    setState(() => _claiming = true);
    try {
      final result = await widget.apiClient!.post(
        '/assignments/$_assignmentId/answer',
        body: const {'stepNo': 1, 'selectedOptionCode': 'VERIFIED'},
      );
      if (!mounted) return;
      setState(() {
        _grantedReward =
            (result['rewardAmount'] as num?)?.toInt() ??
            widget.difficulty.rewardAmount;
        _syncNote = '+$_grantedReward монет начислено в кошелёк!';
        _claiming = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _syncNote = questProblemMessage(error);
        _claiming = false;
      });
    }
  }

  void _reportAndExit({required bool rewardGranted}) {
    widget.onCompleted?.call(
      SquirrelGameResult(
        difficulty: widget.difficulty,
        rewardAmount: _grantedReward ?? widget.difficulty.rewardAmount,
        rewardGranted: rewardGranted,
      ),
    );
    _exit();
  }

  void _exit() {
    if (widget.onExit case final callback?) {
      callback();
    } else {
      Navigator.of(context).maybePop();
    }
  }
}

class _SquirrelHeader extends StatelessWidget {
  const _SquirrelHeader({required this.canExit, required this.onExit});

  final bool canExit;
  final VoidCallback onExit;

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
                      tooltip: 'Выйти из игры',
                      onPressed: onExit,
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  : null,
            ),
            Expanded(
              child: Text(
                'Запасы Белочки',
                textAlign: TextAlign.center,
                style: AppTextStyles.eventTitle.copyWith(fontSize: 27),
              ),
            ),
            const SizedBox(width: 56),
          ],
        ),
      ),
    );
  }
}

class _SquirrelDialogue extends StatelessWidget {
  const _SquirrelDialogue({
    super.key,
    required this.background,
    required this.squirrel,
    required this.lines,
    required this.page,
    required this.finalButton,
    required this.onContinue,
  });

  final String background;
  final String squirrel;
  final List<String> lines;
  final int page;
  final String finalButton;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final last = page == lines.length - 1;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(background, fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x12000000), Color(0x52000000)],
            ),
          ),
        ),
        Positioned(
          left: -36,
          right: -36,
          top: 8,
          bottom: 112,
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Image.asset(
                squirrel,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onContinue,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                decoration: BoxDecoration(
                  color: const Color(0xF8FFF9EE),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.fieldBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x38000000),
                      blurRadius: 14,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Белочка:',
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.crimson,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      lines[page],
                      style: AppTextStyles.story.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 14),
                    if (last)
                      ElevatedButton(
                        key: const ValueKey('squirrel-dialogue-action'),
                        onPressed: onContinue,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: AppColors.crimson,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          finalButton,
                          style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Text(
                            '${page + 1} / ${lines.length}',
                            style: const TextStyle(
                              fontFamily: AppFonts.body,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Нажми, чтобы продолжить  ›',
                            style: TextStyle(
                              fontFamily: AppFonts.body,
                              fontWeight: FontWeight.bold,
                              color: AppColors.crimson,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({this.note});
  final String? note;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: AppColors.crimson),
        const SizedBox(height: 18),
        Text(note ?? 'Открываем Магазин…', style: AppTextStyles.story),
      ],
    ),
  );
}

class _SquirrelLessonCard extends StatelessWidget {
  const _SquirrelLessonCard({
    super.key,
    required this.message,
    required this.success,
    required this.actionLabel,
    required this.onContinue,
    this.note,
    this.busy = false,
  });

  final String message;
  final bool success;
  final String actionLabel;
  final VoidCallback onContinue;
  final String? note;
  final bool busy;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        'assets/games/squirrel/home_background.png',
        fit: BoxFit.cover,
      ),
      const ColoredBox(color: Color(0x61000000)),
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9EC),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.fieldBorder, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4A000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE7B5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    success ? Icons.visibility_rounded : Icons.search_rounded,
                    size: 36,
                    color: AppColors.crimson,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Памятка внимательного покупателя',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.eventTitle.copyWith(fontSize: 27),
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.story.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2D8),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Сначала проверь товар — потом плати.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.leafGreen,
                    ),
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    note!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      color: AppColors.leafGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  key: const ValueKey('squirrel-lesson-action'),
                  onPressed: busy ? null : onContinue,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.crimson,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  child: busy
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          actionLabel,
                          style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _SquirrelPlayfield extends StatelessWidget {
  const _SquirrelPlayfield({
    required this.controller,
    required this.levelNumber,
    required this.levelCount,
    required this.onChanged,
  });

  final SquirrelLevelController controller;
  final int levelNumber;
  final int levelCount;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/games/squirrel/shop_background.png',
          fit: BoxFit.cover,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Color(0x12000000), Color(0x77000000)],
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 30,
              ),
              child: Column(
                children: [
                  _StatusBar(
                    budget: controller.budget,
                    level: controller.level,
                    levelNumber: levelNumber,
                    levelCount: levelCount,
                  ),
                  const SizedBox(height: 10),
                  _InstructionCard(level: controller.level),
                  const SizedBox(height: 14),
                  switch (controller.level) {
                    SquirrelLevel.sorting => _SortingLevel(
                      controller: controller,
                      onChanged: onChanged,
                    ),
                    SquirrelLevel.findOdd => _FindOddLevel(
                      controller: controller,
                      onChanged: onChanged,
                    ),
                    SquirrelLevel.conveyor => _ConveyorLevel(
                      controller: controller,
                      onChanged: onChanged,
                    ),
                    SquirrelLevel.inspect => _InspectLevel(
                      controller: controller,
                      onChanged: onChanged,
                    ),
                  },
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.budget,
    required this.level,
    required this.levelNumber,
    required this.levelCount,
  });
  final int budget;
  final SquirrelLevel level;
  final int levelNumber;
  final int levelCount;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _GlassChip(
        icon: Icons.account_balance_wallet_rounded,
        text: '$budget 🪙',
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _GlassChip(icon: Icons.storefront_rounded, text: level.title),
      ),
      if (levelCount > 1) ...[
        const SizedBox(width: 8),
        _GlassChip(icon: Icons.flag_rounded, text: '$levelNumber/$levelCount'),
      ],
    ],
  );
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 44),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xF4FFF8E9),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.fieldBorder),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19, color: AppColors.crimson),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

class _InstructionCard extends StatelessWidget {
  const _InstructionCard({required this.level});
  final SquirrelLevel level;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xEFFFF9EC),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      level.instruction,
      textAlign: TextAlign.center,
      style: AppTextStyles.story.copyWith(fontSize: 16),
    ),
  );
}

class _SortingLevel extends StatelessWidget {
  const _SortingLevel({required this.controller, required this.onChanged});
  final SquirrelLevelController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final product = controller.current!;
    return Column(
      children: [
        _ProductCard(product: product, size: 245, showPrice: true),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  controller.decideSorting(buy: false);
                  onChanged();
                },
                style: _rejectButtonStyle,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Отказаться'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: controller.budget >= product.price
                    ? () {
                        controller.decideSorting(buy: true);
                        onChanged();
                      }
                    : null,
                style: _buyButtonStyle,
                icon: const Icon(Icons.shopping_basket_rounded),
                label: const Text('Купить'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FindOddLevel extends StatelessWidget {
  const _FindOddLevel({required this.controller, required this.onChanged});
  final SquirrelLevelController controller;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        'Покупка ${controller.step + 1} из 3',
        style: const TextStyle(
          fontFamily: AppFonts.body,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < controller.choices.length; i++)
            Semantics(
              button: true,
              label: 'Товар ${i + 1}',
              child: InkWell(
                key: ValueKey('find-odd-$i'),
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  controller.chooseFindOdd(controller.choices[i]);
                  onChanged();
                },
                child: _ProductCard(product: controller.choices[i], size: 142),
              ),
            ),
        ],
      ),
    ],
  );
}

class _ConveyorLevel extends StatefulWidget {
  const _ConveyorLevel({required this.controller, required this.onChanged});
  final SquirrelLevelController controller;
  final VoidCallback onChanged;
  @override
  State<_ConveyorLevel> createState() => _ConveyorLevelState();
}

class _ConveyorLevelState extends State<_ConveyorLevel> {
  final _random = Random();
  late List<SquirrelProduct> _visible;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _shuffle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
      _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
        if (mounted && !widget.controller.finished) setState(_shuffle);
      });
    });
  }

  void _shuffle() => _visible = [...squirrelProducts]..shuffle(_random);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _take(SquirrelProduct product) {
    widget.controller.takeFromConveyor(product);
    widget.onChanged();
    if (mounted && !widget.controller.finished) setState(_shuffle);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xE3FFF8E8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              for (final entry in SquirrelLevelController.conveyorGoal.entries)
                Text(
                  '${_kindEmoji(entry.key)} ${widget.controller.goodCounts[entry.key]}/${entry.value}',
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 164,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF86542D),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF4D2F1B), width: 3),
          ),
          child: ClipRect(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final product in _visible.take(3))
                  Draggable<SquirrelProduct>(
                    data: product,
                    feedback: Material(
                      color: Colors.transparent,
                      child: _ProductCard(product: product, size: 124),
                    ),
                    childWhenDragging: const SizedBox(width: 108, height: 130),
                    child: InkWell(
                      onTap: () => _take(product),
                      child: _ProductCard(product: product, size: 118),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Корзина для выбранных товаров',
          child: DragTarget<SquirrelProduct>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) => _take(details.data),
            builder: (context, candidates, rejected) => AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 210,
              height: 155,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: candidates.isEmpty
                    ? const Color(0xEFFFF9EC)
                    : const Color(0xFFE1F2C9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: candidates.isEmpty
                      ? AppColors.fieldBorder
                      : AppColors.leafGreen,
                  width: 3,
                ),
              ),
              child: Image.asset(
                'assets/games/squirrel/basket.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InspectLevel extends StatelessWidget {
  const _InspectLevel({required this.controller, required this.onChanged});
  final SquirrelLevelController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final product = controller.current!;
    final shown = controller.inspected
        ? product
        : squirrelProduct(product.kind, SquirrelProductQuality.good);
    return Column(
      children: [
        Semantics(
          button: !controller.inspected,
          label: controller.inspected
              ? 'Товар осмотрен'
              : 'Повернуть и осмотреть товар',
          child: InkWell(
            onTap: controller.inspected ? null : controller.inspectCurrent,
            borderRadius: BorderRadius.circular(24),
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: _ProductCard(
                key: ValueKey('${product.id}-${controller.inspected}'),
                product: shown,
                size: 250,
                showPrice: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          controller.inspected
              ? 'Теперь видно настоящее качество'
              : 'Нажми на товар, чтобы повернуть',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.inspected
                    ? () {
                        controller.decideInspected(buy: false);
                        onChanged();
                      }
                    : null,
                style: _rejectButtonStyle,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Отказаться'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    controller.inspected && controller.budget >= product.price
                    ? () {
                        controller.decideInspected(buy: true);
                        onChanged();
                      }
                    : null,
                style: _buyButtonStyle,
                icon: const Icon(Icons.shopping_basket_rounded),
                label: const Text('Купить'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    super.key,
    required this.product,
    required this.size,
    this.showPrice = false,
  });
  final SquirrelProduct product;
  final double size;
  final bool showPrice;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xF5FFF8E9),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.fieldBorder),
      boxShadow: const [
        BoxShadow(
          color: Color(0x28000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(product.assetPath, fit: BoxFit.contain),
        ),
        if (showPrice)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.parchment,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '${product.price} 🪙',
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

String _kindEmoji(SquirrelProductKind kind) => switch (kind) {
  SquirrelProductKind.mushroom => '🍄',
  SquirrelProductKind.berry => '🍓',
  SquirrelProductKind.nut => '🌰',
};

final ButtonStyle _rejectButtonStyle = OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(52),
  backgroundColor: const Color(0xF7FFF9EE),
  foregroundColor: AppColors.crimson,
  side: const BorderSide(color: AppColors.crimson, width: 2),
  shape: const StadiumBorder(),
  textStyle: const TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  ),
);

final ButtonStyle _buyButtonStyle = ElevatedButton.styleFrom(
  minimumSize: const Size.fromHeight(52),
  backgroundColor: AppColors.crimson,
  foregroundColor: Colors.white,
  disabledBackgroundColor: const Color(0xFFD9D2C5),
  disabledForegroundColor: AppColors.inkMuted,
  shape: const StadiumBorder(),
  textStyle: const TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  ),
);
