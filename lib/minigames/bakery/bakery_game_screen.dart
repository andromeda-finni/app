import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/child_difficulty.dart';
import '../../onboarding/widgets/back_circle_button.dart';
import '../../onboarding/widgets/story_button.dart';
import '../../theme/app_theme.dart';
import '../quest_reward_messages.dart';
import 'bakery_game_data.dart';

class BakeryGameScreen extends StatefulWidget {
  const BakeryGameScreen({
    super.key,
    required this.difficulty,
    this.apiClient,
    this.onExit,
  });

  final ChildDifficulty difficulty;
  final ApiClient? apiClient;
  final VoidCallback? onExit;

  @override
  State<BakeryGameScreen> createState() => _BakeryGameScreenState();
}

class _BakeryGameScreenState extends State<BakeryGameScreen> {
  late final BakeryGameState game = BakeryGameState(
    difficulty: widget.difficulty,
  );
  String? _assignmentId;
  String? _feedback;
  int? _rewardAmount;
  bool _serverQuestCompleted = false;
  bool _saving = false;
  Future<void>? _startFuture;

  @override
  void initState() {
    super.initState();
    if (widget.apiClient != null) _startFuture = _startQuest();
  }

  Future<void> _startQuest() async {
    try {
      final result = await widget.apiClient!.post(
        '/quests/$kBakeryQuestId/start',
      );
      if (!mounted) return;
      setState(() {
        _assignmentId = result['assignmentId'] as String?;
        _rewardAmount = (result['rewardAmount'] as num?)?.toInt();
        _serverQuestCompleted = result['completed'] == true;
        if (_serverQuestCompleted) {
          _feedback = 'Ты уже получил награду. Можно сыграть ещё раз.';
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _feedback = questProblemMessage(error));
    }
  }

  Future<void> _saveResult() async {
    if (widget.apiClient == null) {
      setState(() => _feedback = 'Сейчас играем без награды.');
      return;
    }
    await _startFuture;
    if (!mounted || _serverQuestCompleted) return;
    if (_assignmentId == null) {
      _startFuture = _startQuest();
      await _startFuture;
    }
    if (!mounted || _assignmentId == null || _serverQuestCompleted) return;
    setState(() => _saving = true);
    try {
      final result = await widget.apiClient!.post(
        '/assignments/$_assignmentId/answer',
        body: {'stepNo': 1, 'selectedOptionCode': '${game.profit}'},
      );
      if (!mounted) return;
      setState(() {
        if (result['questCompleted'] == true) {
          _serverQuestCompleted = true;
          _rewardAmount = (result['rewardAmount'] as num?)?.toInt();
          _feedback = null;
        } else {
          _feedback = questRecoveryMessage(result);
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _feedback = questProblemMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _exit() {
    if (widget.onExit != null) {
      widget.onExit!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _go(BakeryStage stage) => setState(() {
    game.stage = stage;
    _feedback = null;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            label: 'Уютная сказочная пекарня',
            image: true,
            child: Image.asset(BakeryAssets.background, fit: BoxFit.cover),
          ),
          const ColoredBox(color: Color(0x59241912)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      BackCircleButton(onPressed: _exit),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatusPill(
                          stage: game.stage,
                          reward: _rewardAmount ?? game.reward,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: KeyedSubtree(
                      key: ValueKey(game.stage),
                      child: _stageContent(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageContent() => switch (game.stage) {
    BakeryStage.intro => _intro(),
    BakeryStage.shopping => _shopping(),
    BakeryStage.remainderQuiz => _remainderQuiz(),
    BakeryStage.cooking => _cooking(),
    BakeryStage.selling => _selling(),
    BakeryStage.revenueLesson => _revenueLesson(),
    BakeryStage.profitQuiz => _profitQuiz(),
    BakeryStage.complete => _complete(),
  };

  Widget _intro() => _SceneLayout(
    characterAsset: BakeryAssets.bakerHappy,
    characterLabel: 'Пекарь приветливо машет рукой',
    child: _PaperPanel(
      title: 'Пирожки для ярмарки',
      text: 'У Пекаря 20 монет. Купи продукты, испеки пирожки и помоги ему заработать.',
      footer: StoryButton(
        key: const ValueKey('bakery-start'),
        label: 'Открыть рецепт',
        onPressed: () => _go(BakeryStage.shopping),
      ),
    ),
  );

  Future<void> _toggleIngredient(BakeryIngredient item) async {
    if (item != BakeryIngredient.honey || game.basket.contains(item)) {
      setState(() {
        game.toggleBasket(item);
        _feedback = null;
      });
      return;
    }

    final takeHoney = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: const Text('Берём мёд?', style: AppTextStyles.screenTitle),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ты уверен? Посмотри на рецепт ещё раз.',
              style: AppTextStyles.story,
            ),
            SizedBox(height: AppSpacing.md),
            _RecipeReminder(),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        actions: [
          TextButton(
            key: const ValueKey('bakery-honey-remove'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Убрать мёд'),
          ),
          ElevatedButton(
            key: const ValueKey('bakery-honey-keep'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(112, 48),
              backgroundColor: AppColors.crimson,
              foregroundColor: Colors.white,
            ),
            child: const Text('Да, беру'),
          ),
        ],
      ),
    );
    if (!mounted || takeHoney != true) return;
    setState(() {
      game.basket.add(BakeryIngredient.honey);
      _feedback = null;
    });
  }

  Widget _shopping() => _ScrollablePanel(
    title: 'Купи продукты',
    subtitle: 'Рецепт: мука, ягоды и масло. Выбери, что купить.',
    header: _MoneySummary(
      values: {
        'Было': game.startingCash,
        'В корзине': game.basketTotal,
        'Останется': game.cashAfterShopping,
      },
    ),
    children: [
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: MediaQuery.sizeOf(context).width < 600 ? 2 : 4,
        mainAxisExtent: 170,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        children: [
          for (final item in BakeryIngredient.values)
            _IngredientCard(
              item: item,
              selected: game.basket.contains(item),
              onTap: () => _toggleIngredient(item),
            ),
        ],
      ),
      if (_feedback != null) _FeedbackCard(message: _feedback!),
      StoryButton(
        key: const ValueKey('bakery-buy'),
        label: game.hasRecipe ? 'Купить продукты' : 'Проверь рецепт',
        onPressed: game.hasRecipe ? () => _go(BakeryStage.remainderQuiz) : null,
      ),
    ],
  );

  Widget _remainderQuiz() {
    final correct = game.cashAfterShopping;
    return _QuestionPanel(
      title: 'Считаем сдачу',
      question:
          'Было ${game.startingCash} монет. Покупки стоят ${game.basketTotal}. Сколько монет осталось?',
      equation: '${game.startingCash} − ${game.basketTotal} = ?',
      options: <int>{
        correct,
        game.basketTotal,
        game.startingCash + game.basketTotal,
      }.toList()..sort(),
      feedback: _feedback,
      hint: game.remainderMistakes >= 1
          ? 'Из 20 монет убери ${game.basketTotal}. Сколько останется?'
          : null,
      onAnswer: (answer) => setState(() {
        if (!game.answerRemainder(answer)) {
          _feedback = 'Попробуй ещё раз. Из 20 вычти цену покупок.';
        } else {
          _feedback = null;
        }
      }),
    );
  }

  Widget _cooking() {
    final available = BakeryIngredient.values
        .where((item) => item.requiredForRecipe)
        .toList();
    return _ScrollablePanel(
      title: 'Замеси тесто',
      subtitle: 'Нажимай на продукты и добавляй их в миску.',
      header: Semantics(
        label: 'В миске ${game.addedToBowl.length} продукта из 3',
        child: SizedBox(
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(BakeryAssets.bowl, height: 140),
              if (game.addedToBowl.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 22),
                  width: 86,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8C98A),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${game.addedToBowl.length}/3',
                    style: AppTextStyles.counterValue,
                  ),
                ),
            ],
          ),
        ),
      ),
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final item in available)
              _IngredientChip(
                item: item,
                added: game.addedToBowl.contains(item),
                onTap: () => setState(() => game.addToBowl(item)),
              ),
          ],
        ),
        StoryButton(
          key: const ValueKey('bakery-bake'),
          label: game.cookingComplete
              ? 'Поставить в печь'
              : 'Добавь все продукты',
          onPressed: game.cookingComplete
              ? () => _go(BakeryStage.selling)
              : null,
        ),
      ],
    );
  }

  Widget _selling() => _ScrollablePanel(
    title: 'Ярмарка началась',
    subtitle: game.difficulty == ChildDifficulty.advanced
        ? 'Есть 6 пирожков, а покупателей 5. Продай каждому по одному.'
        : 'Есть 5 пирожков. Каждый стоит 4 монеты.',
    header: _MoneySummary(
      values: {'Продано': game.soldCount, 'В кассе': game.soldCount * 4},
    ),
    children: [
      Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (var index = 0; index < game.piesBaked; index++)
            Semantics(
              button: index == game.soldCount && game.soldCount < 5,
              label: index < game.soldCount
                  ? 'Пирожок ${index + 1} продан'
                  : index >= 5
                  ? 'Пирожок остался непроданным'
                  : 'Продать пирожок ${index + 1} за 4 монеты',
              child: InkWell(
                key: ValueKey('bakery-pie-$index'),
                onTap: index == game.soldCount && game.soldCount < 5
                    ? () => setState(() => game.soldCount += 1)
                    : null,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: AnimatedOpacity(
                  opacity: index < game.soldCount ? 0.3 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: Image.asset(BakeryAssets.pie, width: 74, height: 74),
                ),
              ),
            ),
        ],
      ),
      if (game.soldCount == 5 && game.unsoldCount > 0)
        const _FeedbackCard(
          message: 'Один пирожок остался. За него нам не заплатили.',
        ),
      StoryButton(
        key: const ValueKey('bakery-sales-done'),
        label: game.soldCount == 5 ? 'Посчитать выручку' : 'Продай 5 пирожков',
        onPressed: game.soldCount == 5
            ? () => _go(BakeryStage.revenueLesson)
            : null,
      ),
    ],
  );

  Widget _revenueLesson() => _SceneLayout(
    characterAsset: BakeryAssets.bakerThinking,
    characterLabel: 'Пекарь задумался о выручке',
    child: _PaperPanel(
      title: 'Сколько мы получили?',
      text:
          'Покупатели дали нам 5 × 4 = ${game.revenue} монет. Это выручка. Но мы тратили деньги на продукты.',
      footer: StoryButton(
        key: const ValueKey('bakery-to-profit'),
        label: 'Посчитать прибыль',
        onPressed: () => _go(BakeryStage.profitQuiz),
      ),
    ),
  );

  Widget _profitQuiz() {
    final correct = game.profit;
    return _QuestionPanel(
      title: 'Считаем прибыль',
      question:
          'Мы получили ${game.revenue} монет и потратили ${game.basketTotal}. Сколько заработали?',
      equation: '${game.revenue} − ${game.basketTotal} = ?',
      options: <int>{correct, game.basketTotal, game.revenue}.toList()..sort(),
      feedback: _feedback,
      hint: game.profitMistakes >= 1
          ? 'Из полученных денег вычти все траты.'
          : null,
      onAnswer: (answer) {
        final correctAnswer = game.answerProfit(answer);
        setState(() {
          _feedback = correctAnswer
              ? null
              : 'Попробуй ещё раз. Сначала вычти деньги за продукты.';
        });
        if (correctAnswer) _saveResult();
      },
    );
  }

  Widget _complete() => _SceneLayout(
    characterAsset: BakeryAssets.bakerWithPies,
    characterLabel: 'Довольный пекарь держит поднос с пирожками',
    child: _PaperPanel(
      title: 'Ярмарка удалась!',
      text: game.boughtHoney
          ? 'Ты купил мёд за 6 монет, но для пирожков он не пригодился. Траты выросли до ${game.basketTotal} монет.\n\n${game.revenue} − ${game.basketTotal} = ${game.profit}. Прибыль — ${game.profit} монеты. Без мёда прибыль была бы 8 монет.'
          : 'Мы получили ${game.revenue} монет и потратили ${game.basketTotal}.\n\n${game.revenue} − ${game.basketTotal} = ${game.profit}. Прибыль — ${game.profit} монет. Теперь в кошельке ${game.finalWallet} монет.',
      extra: _feedback == null
          ? _RewardLine(
              saving: _saving,
              reward: _serverQuestCompleted ? _rewardAmount : null,
            )
          : _FeedbackCard(message: _feedback!),
      footer: Column(
        children: [
          if (_feedback != null &&
              widget.apiClient != null &&
              !_serverQuestCompleted)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: StoryButton(
                label: 'Попробовать сохранить ещё раз',
                onPressed: _saving ? null : _saveResult,
                isLoading: _saving,
              ),
            ),
          StoryButton(
            key: const ValueKey('bakery-finish'),
            label: 'Вернуться на карту',
            onPressed: _saving ? null : _exit,
          ),
        ],
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.stage, required this.reward});

  final BakeryStage stage;
  final int reward;

  @override
  Widget build(BuildContext context) {
    final step = (stage.index + 1).clamp(1, BakeryStage.values.length);
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Пекарня · $step/${BakeryStage.values.length}',
              style: AppTextStyles.cardRowLabel,
            ),
          ),
          Image.asset(BakeryAssets.coin, width: 24, height: 24),
          const SizedBox(width: AppSpacing.xxs),
          Text('+$reward', style: AppTextStyles.cardRowLabel),
        ],
      ),
    );
  }
}

class _SceneLayout extends StatelessWidget {
  const _SceneLayout({
    required this.characterAsset,
    required this.characterLabel,
    required this.child,
  });

  final String characterAsset;
  final String characterLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Semantics(
                image: true,
                label: characterLabel,
                child: Image.asset(
                  characterAsset,
                  height: constraints.maxHeight < 600 ? 220 : 330,
                  fit: BoxFit.contain,
                ),
              ),
              Transform.translate(offset: const Offset(0, -12), child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScrollablePanel extends StatelessWidget {
  const _ScrollablePanel({
    required this.title,
    required this.subtitle,
    required this.children,
    this.header,
  });

  final String title;
  final String subtitle;
  final Widget? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      child: _PaperPanel(
        title: title,
        text: subtitle,
        extra: Column(
          children: [
            if (header != null) ...[
              header!,
              const SizedBox(height: AppSpacing.md),
            ],
            ...children.expand(
              (child) => [child, const SizedBox(height: AppSpacing.md)],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperPanel extends StatelessWidget {
  const _PaperPanel({
    required this.title,
    required this.text,
    this.extra,
    this.footer,
  });

  final String title;
  final String text;
  final Widget? extra;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 720),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.parchmentDark, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.screenTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(text, style: AppTextStyles.story),
          if (extra != null) ...[const SizedBox(height: AppSpacing.md), extra!],
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.lg),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _RecipeReminder extends StatelessWidget {
  const _RecipeReminder();

  @override
  Widget build(BuildContext context) {
    const recipe = [
      BakeryIngredient.flour,
      BakeryIngredient.berries,
      BakeryIngredient.butter,
    ];
    return Semantics(
      label: 'В рецепте мука, ягоды и масло',
      child: ExcludeSemantics(
        child: Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final item in recipe)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                child: Text(item.title, style: AppTextStyles.cardRowLabel),
              ),
          ],
        ),
      ),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final BakeryIngredient item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${item.title}, ${item.price} монет',
      child: Material(
        color: selected ? AppColors.infoBg : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          key: ValueKey('bakery-item-${item.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: selected ? AppColors.crimson : AppColors.fieldBorder,
                width: selected ? 3 : 1,
              ),
            ),
            child: Column(
              children: [
                Expanded(child: Image.asset(item.asset, fit: BoxFit.contain)),
                Text(item.title, style: AppTextStyles.cardRowLabel),
                Text('${item.price} монет', style: AppTextStyles.supporting),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IngredientChip extends StatelessWidget {
  const _IngredientChip({
    required this.item,
    required this.added,
    required this.onTap,
  });

  final BakeryIngredient item;
  final bool added;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: !added,
      label: added
          ? '${item.title} уже в миске'
          : 'Добавить ${item.title} в миску',
      child: Material(
        color: added ? AppColors.parchmentDark : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          key: ValueKey('bakery-cook-${item.name}'),
          onTap: added ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: SizedBox(
            width: 96,
            height: 112,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(item.asset, width: 68, height: 68),
                Text(added ? 'Добавлено' : item.title),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoneySummary extends StatelessWidget {
  const _MoneySummary({required this.values});

  final Map<String, int> values;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final entry in values.entries)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(
              '${entry.key}: ${entry.value}',
              style: AppTextStyles.cardRowLabel,
            ),
          ),
      ],
    );
  }
}

class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({
    required this.title,
    required this.question,
    required this.equation,
    required this.options,
    required this.onAnswer,
    this.feedback,
    this.hint,
  });

  final String title;
  final String question;
  final String equation;
  final List<int> options;
  final ValueChanged<int> onAnswer;
  final String? feedback;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: _PaperPanel(
        title: title,
        text: question,
        extra: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Text(
                equation,
                textAlign: TextAlign.center,
                style: AppTextStyles.screenTitle.copyWith(fontSize: 30),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final option in options)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: StoryButton(
                  key: ValueKey('bakery-answer-$option'),
                  label: '$option монет',
                  onPressed: () => onAnswer(option),
                ),
              ),
            if (feedback != null) _FeedbackCard(message: feedback!),
            if (hint != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _FeedbackCard(message: hint!, isHint: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.message, this.isHint = false});

  final String message;
  final bool isHint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isHint ? AppColors.infoBg : AppColors.crimsonFaded,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Text(
          message,
          style: AppTextStyles.supporting.copyWith(color: AppColors.ink),
        ),
      ),
    );
  }
}

class _RewardLine extends StatelessWidget {
  const _RewardLine({required this.saving, required this.reward});

  final bool saving;
  final int? reward;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (saving)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        else
          Image.asset(BakeryAssets.coin, width: 30, height: 30),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            saving
                ? 'Сохраняем результат…'
                : reward == null
                ? 'Результат сохранён в тренировке'
                : 'Награда: $reward монет',
            style: AppTextStyles.cardRowLabel,
          ),
        ),
      ],
    );
  }
}
