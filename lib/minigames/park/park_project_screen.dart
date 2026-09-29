import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/child_difficulty.dart';
import '../../core/pet_assets.dart';
import '../../onboarding/widgets/back_circle_button.dart';
import '../../onboarding/widgets/story_button.dart';
import '../../theme/app_theme.dart';
import 'park_project_data.dart';

class ParkProjectScreen extends StatefulWidget {
  const ParkProjectScreen({
    super.key,
    required this.difficulty,
    this.apiClient,
    this.onExit,
    this.petName = 'Питомец',
    this.furOptionId,
    this.previewState,
    this.skipFirstOfferIntro = false,
  });

  final ChildDifficulty difficulty;
  final ApiClient? apiClient;
  final VoidCallback? onExit;
  final String petName;
  final String? furOptionId;

  /// Used only by standalone visual previews. Production flows always load
  /// their authoritative state from [apiClient].
  final ParkProjectState? previewState;

  /// Lets the standalone preview and focused widget tests open the money
  /// panel directly. Production navigation leaves this false.
  final bool skipFirstOfferIntro;

  @override
  State<ParkProjectScreen> createState() => _ParkProjectScreenState();
}

enum _ParkIntroStep {
  badgerGreeting,
  petAsksAboutPark,
  badgerDescribesPark,
  petAsksWhoPays,
  badgerQuestion,
  wrongAnswerHint,
  badgerExplainsTogether,
  petAsksIfStarted,
  badgerShowsBox,
  done,
}

enum _ParkSpeaker { badger, pet }

class _ParkProjectScreenState extends State<ParkProjectScreen>
    with SingleTickerProviderStateMixin {
  ParkProjectState? _state;
  String? _error;
  bool _saving = false;
  int _requestNumber = 0;
  late _ParkIntroStep _introStep = widget.skipFirstOfferIntro
      ? _ParkIntroStep.done
      : _ParkIntroStep.badgerGreeting;
  late final AnimationController _coinFlightController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _coinFlightController.dispose();
    super.dispose();
  }

  String _idempotencyKey(String action) =>
      'park-$action-${DateTime.now().microsecondsSinceEpoch}-${_requestNumber++}';

  Future<void> _load() async {
    if (widget.previewState case final preview?) {
      setState(() => _state = preview);
      return;
    }
    if (widget.apiClient == null) {
      setState(() {
        _state = const ParkProjectState(
          stage: 'FIRST_OFFER',
          scene: 'FIRST_OFFER',
          targetAmount: 100,
          collectedAmount: 80,
          offerAmount: 20,
          spendableBalance: 75,
          availableToContribute: 75,
          canContribute: true,
          childContribution: 0,
          completed: false,
        );
      });
      return;
    }
    setState(() => _error = null);
    try {
      final json = await widget.apiClient!.get('/park-project');
      if (!mounted) return;
      setState(() => _state = ParkProjectState.fromJson(json));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    }
  }

  Future<void> _decide(String decision) async {
    final current = _state;
    if (current == null || !current.hasOffer || _saving) return;
    if (widget.apiClient == null) {
      setState(() => _saving = true);
      final nextState = ParkProjectState(
        stage: decision == 'CONTRIBUTE' ? 'FUNDED' : 'WAITING_SECOND',
        scene: decision == 'CONTRIBUTE' ? 'FUNDED' : 'WAITING_SECOND',
        targetAmount: 100,
        collectedAmount: decision == 'CONTRIBUTE' ? 100 : 80,
        spendableBalance:
            current.spendableBalance -
            (decision == 'CONTRIBUTE' ? current.offerAmount! : 0),
        availableToContribute:
            current.availableToContribute -
            (decision == 'CONTRIBUTE' ? current.offerAmount! : 0),
        canContribute: false,
        childContribution: decision == 'CONTRIBUTE' ? current.offerAmount! : 0,
        completed: false,
        daysToNextStage: 1,
      );
      if (decision == 'CONTRIBUTE' &&
          !MediaQuery.disableAnimationsOf(context)) {
        await _coinFlightController.forward(from: 0);
        if (!mounted) return;
      }
      setState(() {
        _state = nextState;
        _saving = false;
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final json = await widget.apiClient!.post(
        '/park-project/decision',
        body: {
          'offer': current.offerCode,
          'decision': decision,
          'idempotencyKey': _idempotencyKey('decision'),
        },
      );
      if (!mounted) return;
      final nextState = ParkProjectState.fromJson(json);
      if (decision == 'CONTRIBUTE' &&
          !MediaQuery.disableAnimationsOf(context)) {
        await _coinFlightController.forward(from: 0);
        if (!mounted) return;
      }
      setState(() => _state = nextState);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
      if (error.code == 'park_offer_changed') await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _complete() async {
    if (widget.apiClient == null) {
      _exit();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final json = await widget.apiClient!.post(
        '/park-project/complete',
        body: {'idempotencyKey': _idempotencyKey('complete')},
      );
      if (!mounted) return;
      setState(() => _state = ParkProjectState.fromJson(json));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _messageFor(ApiException error) => switch (error.code) {
    'park_contribution_would_use_need_reserve' =>
      'Эти монеты нужны для важных покупок. Можно выбрать «Не сейчас».',
    'park_quest_locked' => 'Сначала закончи приключение с тугриками.',
    'park_not_open_yet' => 'Парк ещё строят. Загляни после следующего дня.',
    _ when error.isNetworkError =>
      'Не удалось связаться с сервером. Проверь интернет и попробуй ещё раз.',
    _ => 'Что-то не получилось. Попробуй ещё раз.',
  };

  void _exit() {
    if (widget.onExit != null) {
      widget.onExit!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  String get _petName {
    final name = widget.petName.trim();
    return name.isEmpty ? 'Питомец' : name;
  }

  bool _isShowingIntro(ParkProjectState? state) =>
      state?.stage == 'FIRST_OFFER' && _introStep != _ParkIntroStep.done;

  void _goToIntroStep(_ParkIntroStep step) {
    setState(() => _introStep = step);
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final backgroundAsset = ParkAssets.backgroundFor(state?.scene ?? '');
    final showingIntro = _isShowingIntro(state);
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 320),
            child: Semantics(
              key: ValueKey(backgroundAsset),
              image: true,
              label: ParkAssets.backgroundLabelFor(state?.scene ?? ''),
              child: Image.asset(backgroundAsset, fit: BoxFit.cover),
            ),
          ),
          ColoredBox(
            color: switch (state?.scene) {
              'BUILDING' || 'ALMOST_READY' || 'OPEN' => const Color(0x26241912),
              _ => const Color(0x40241912),
            },
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      BackCircleButton(onPressed: _exit),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatusPill(
                          text: state == null
                              ? 'Парк Барсука'
                              : showingIntro
                              ? 'Знакомство с Барсуком'
                              : _statusText(state),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: state == null
                      ? _loadingOrError()
                      : _Scene(
                          state: state,
                          introSpeaker: showingIntro
                              ? _introSpeaker(_introStep)
                              : null,
                          furOptionId: widget.furOptionId,
                          child: _content(state),
                        ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _coinFlightController,
                builder: (context, _) => _coinFlightController.isAnimating
                    ? _CoinFlight(progress: _coinFlightController.value)
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingOrError() => Center(
    child: Container(
      margin: const EdgeInsets.all(AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: _error == null
          ? const CircularProgressIndicator(color: AppColors.crimson)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.story,
                ),
                const SizedBox(height: AppSpacing.md),
                StoryButton(label: 'Попробовать ещё раз', onPressed: _load),
              ],
            ),
    ),
  );

  String _statusText(ParkProjectState state) => switch (state.scene) {
    'FIRST_OFFER' || 'SECOND_OFFER' => 'Собираем на парк',
    'WAITING_SECOND' || 'WAITING_COMMUNITY' => 'Ждём новостей',
    'FUNDED' => 'Деньги собраны',
    'BUILDING' => 'Парк строится',
    'ALMOST_READY' => 'Почти готово',
    'OPEN' => 'Парк открыт',
    _ => 'Парк Барсука',
  };

  Widget _content(ParkProjectState state) {
    if (_isShowingIntro(state)) return _introPanel();
    if (state.hasOffer) return _offer(state);
    return switch (state.scene) {
      'WAITING_SECOND' => _messagePanel(
        title: 'Сбор продолжается',
        text: 'Ничего страшного. Барсук попросит помощи у других жителей. Загляни после следующего игрового дня.',
        icon: Icons.groups_rounded,
      ),
      'WAITING_COMMUNITY' => _messagePanel(
        title: 'Жители помогут',
        text: 'Ты решил не добавлять монеты. Другие жители закончат сбор после следующего игрового дня.',
        icon: Icons.diversity_3_rounded,
      ),
      'FUNDED' => _messagePanel(
        title: 'Все 100 монет собраны!',
        text: state.childContribution > 0
            ? 'Спасибо за помощь. Теперь жители начнут строить парк.'
            : 'Жители собрали нужную сумму. Теперь начнётся стройка.',
        icon: Icons.check_circle_rounded,
      ),
      'BUILDING' => _messagePanel(
        title: 'Парк строится',
        text: 'Рабочие делают дорожки и ставят скамейки. Осталось ещё немного.',
        icon: Icons.construction_rounded,
      ),
      'ALMOST_READY' => _messagePanel(
        title: 'Почти готово!',
        text: 'Дорожки готовы, деревья посажены. После следующего игрового дня парк откроется.',
        icon: Icons.park_rounded,
      ),
      'OPEN' => _openPanel(state),
      _ => _messagePanel(
        title: 'Есть новости',
        text: 'Загляни после следующего игрового дня.',
        icon: Icons.schedule_rounded,
      ),
    };
  }

  _ParkSpeaker _introSpeaker(_ParkIntroStep step) => switch (step) {
    _ParkIntroStep.petAsksAboutPark ||
    _ParkIntroStep.petAsksWhoPays ||
    _ParkIntroStep.petAsksIfStarted => _ParkSpeaker.pet,
    _ => _ParkSpeaker.badger,
  };

  Widget _introPanel() => switch (_introStep) {
    _ParkIntroStep.badgerGreeting => _speechPanel(
      speaker: 'Барсук',
      text: 'Привет, $_petName! Я Барсук. Жители хотят построить здесь парк.',
      buttonText: 'Какой парк?',
      onPressed: () => _goToIntroStep(_ParkIntroStep.petAsksAboutPark),
    ),
    _ParkIntroStep.petAsksAboutPark => _speechPanel(
      speaker: _petName,
      text: 'А что будет в парке?',
      buttonText: 'Слушать',
      onPressed: () => _goToIntroStep(_ParkIntroStep.badgerDescribesPark),
    ),
    _ParkIntroStep.badgerDescribesPark => _speechPanel(
      speaker: 'Барсук',
      text: 'Карусели, горки, колесо обозрения и другие аттракционы. В парк смогут приходить все жители.',
      buttonText: 'А кто заплатит?',
      onPressed: () => _goToIntroStep(_ParkIntroStep.petAsksWhoPays),
    ),
    _ParkIntroStep.petAsksWhoPays => _speechPanel(
      speaker: _petName,
      text: 'А кто заплатит за парк?',
      buttonText: 'Слушать',
      onPressed: () => _goToIntroStep(_ParkIntroStep.badgerQuestion),
    ),
    _ParkIntroStep.badgerQuestion => _introQuestionPanel(),
    _ParkIntroStep.wrongAnswerHint => _speechPanel(
      speaker: 'Барсук',
      text: 'Одному будет слишком дорого. Подумай: что могут сделать много жителей?',
      buttonText: 'Попробовать ещё раз',
      onPressed: () => _goToIntroStep(_ParkIntroStep.badgerQuestion),
    ),
    _ParkIntroStep.badgerExplainsTogether => _speechPanel(
      speaker: 'Барсук',
      text: 'Точно! Кто-то добавит немного, кто-то побольше. Вместе жители смогут собрать нужную сумму.',
      buttonText: 'Спросить про сбор',
      onPressed: () => _goToIntroStep(_ParkIntroStep.petAsksIfStarted),
    ),
    _ParkIntroStep.petAsksIfStarted => _speechPanel(
      speaker: _petName,
      text: 'Жители уже начали собирать монеты?',
      buttonText: 'Слушать',
      onPressed: () => _goToIntroStep(_ParkIntroStep.badgerShowsBox),
    ),
    _ParkIntroStep.badgerShowsBox => _speechPanel(
      speaker: 'Барсук',
      text: 'Да. Пойдём, покажу нашу копилку.',
      buttonText: 'Посмотреть копилку',
      buttonKey: const ValueKey('park-show-collection'),
      onPressed: () => _goToIntroStep(_ParkIntroStep.done),
    ),
    _ParkIntroStep.done => const SizedBox.shrink(),
  };

  Widget _speechPanel({
    required String speaker,
    required String text,
    required String buttonText,
    required VoidCallback onPressed,
    Key? buttonKey,
  }) => _PaperPanel(
    children: [
      _SpeakerLabel(name: speaker),
      const SizedBox(height: AppSpacing.sm),
      Text(text, style: AppTextStyles.story),
      const SizedBox(height: AppSpacing.lg),
      StoryButton(key: buttonKey, label: buttonText, onPressed: onPressed),
    ],
  );

  Widget _introQuestionPanel() => _PaperPanel(
    children: [
      const _SpeakerLabel(name: 'Барсук'),
      const SizedBox(height: AppSpacing.sm),
      const Text(
        'Парк стоит дорого. Одному жителю столько не собрать. Как жители могут построить его вместе?',
        style: AppTextStyles.story,
      ),
      const SizedBox(height: AppSpacing.lg),
      _ChoiceButton(
        key: const ValueKey('park-answer-together'),
        label: 'Сложить монеты вместе',
        onPressed: () => _goToIntroStep(_ParkIntroStep.badgerExplainsTogether),
      ),
      const SizedBox(height: AppSpacing.sm),
      _ChoiceButton(
        key: const ValueKey('park-answer-one-person'),
        label: 'Пусть заплатит один житель',
        onPressed: () => _goToIntroStep(_ParkIntroStep.wrongAnswerHint),
      ),
    ],
  );

  Widget _offer(ParkProjectState state) => _PaperPanel(
    children: [
      Text(
        state.stage == 'FIRST_OFFER'
            ? 'Поможем построить парк?'
            : 'До парка осталось совсем немного',
        style: AppTextStyles.screenTitle,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        state.stage == 'FIRST_OFFER'
            ? 'Жители хотят парк с дорожками, деревьями и скамейками.'
            : 'Другие жители уже добавили монеты. Не хватает только ${state.offerAmount}.',
        style: AppTextStyles.story,
      ),
      const SizedBox(height: AppSpacing.md),
      _ParkProgress(state: state),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_rounded,
            color: AppColors.coinGold,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'В кошельке: ${state.spendableBalance} монет',
              style: AppTextStyles.cardRowLabel,
            ),
          ),
        ],
      ),
      if (!state.canContribute) ...[
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Сначала оставь монеты на важные покупки. Можно выбрать «Не сейчас».',
          style: AppTextStyles.supporting,
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: AppSpacing.sm),
        _ErrorCard(message: _error!),
      ],
      const SizedBox(height: AppSpacing.lg),
      StoryButton(
        key: const ValueKey('park-contribute'),
        label: _saving ? 'Сохраняем…' : 'Добавить ${state.offerAmount} монет',
        onPressed: state.canContribute && !_saving
            ? () => _decide('CONTRIBUTE')
            : null,
      ),
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton(
        key: const ValueKey('park-decline'),
        onPressed: _saving ? null : () => _decide('DECLINE'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.fieldBorder, width: 1.5),
          shape: const StadiumBorder(),
          textStyle: AppTextStyles.button.copyWith(color: AppColors.ink),
        ),
        child: const Text('Не сейчас'),
      ),
    ],
  );

  Widget _messagePanel({
    required String title,
    required String text,
    required IconData icon,
  }) => _PaperPanel(
    children: [
      Icon(icon, size: 52, color: AppColors.leafGreen),
      const SizedBox(height: AppSpacing.sm),
      Text(
        title,
        textAlign: TextAlign.center,
        style: AppTextStyles.screenTitle,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(text, textAlign: TextAlign.center, style: AppTextStyles.story),
      if (_error != null) ...[
        const SizedBox(height: AppSpacing.md),
        _ErrorCard(message: _error!),
      ],
      const SizedBox(height: AppSpacing.lg),
      StoryButton(label: 'Вернуться на карту', onPressed: _exit),
    ],
  );

  Widget _openPanel(ParkProjectState state) => _PaperPanel(
    children: [
      const Icon(
        Icons.celebration_rounded,
        size: 52,
        color: AppColors.coinGold,
      ),
      const SizedBox(height: AppSpacing.sm),
      const Text(
        'Парк открыт!',
        textAlign: TextAlign.center,
        style: AppTextStyles.screenTitle,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        state.childContribution > 0
            ? 'Теперь здесь могут гулять все жители. Твои монеты помогли сделать общее место.'
            : 'Теперь здесь могут гулять все жители. Парк открыт для каждого.',
        textAlign: TextAlign.center,
        style: AppTextStyles.story,
      ),
      if (widget.difficulty == ChildDifficulty.advanced) ...[
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Так же работают налоги: жители понемногу складывают деньги на то, чем пользуются все.',
          textAlign: TextAlign.center,
          style: AppTextStyles.supporting,
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: AppSpacing.md),
        _ErrorCard(message: _error!),
      ],
      const SizedBox(height: AppSpacing.lg),
      StoryButton(
        key: const ValueKey('park-complete'),
        label: state.completed ? 'Вернуться на карту' : 'Закончить квест',
        onPressed: _saving
            ? null
            : state.completed
            ? _exit
            : _complete,
      ),
    ],
  );
}

class _Scene extends StatelessWidget {
  const _Scene({
    required this.state,
    required this.child,
    required this.introSpeaker,
    required this.furOptionId,
  });

  final ParkProjectState state;
  final Widget child;
  final _ParkSpeaker? introSpeaker;
  final String? furOptionId;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      children: [
        if (introSpeaker == _ParkSpeaker.badger ||
            (introSpeaker == null &&
                (state.scene == 'FIRST_OFFER' ||
                    state.scene == 'SECOND_OFFER')))
          Positioned(
            left: -constraints.maxWidth * 0.10,
            bottom: constraints.maxHeight * 0.28,
            width: math.min(constraints.maxWidth * 0.66, 360),
            child: Semantics(
              image: true,
              label: 'Добрый Барсук рассказывает о парке',
              child: Image.asset(ParkAssets.badger),
            ),
          ),
        if (introSpeaker == _ParkSpeaker.pet)
          Positioned(
            right: -constraints.maxWidth * 0.02,
            bottom: constraints.maxHeight * 0.29,
            width: math.min(constraints.maxWidth * 0.48, 250),
            child: Semantics(
              image: true,
              label: 'Питомец разговаривает с Барсуком',
              child: Image.asset(catAsset(furOptionId: furOptionId)),
            ),
          ),
        if (introSpeaker == null &&
            (state.scene == 'FIRST_OFFER' || state.scene == 'SECOND_OFFER'))
          Positioned(
            right: -constraints.maxWidth * 0.07,
            bottom: constraints.maxHeight * 0.31,
            width: math.min(constraints.maxWidth * 0.46, 260),
            child: Semantics(
              image: true,
              label: 'Шкатулка для общих монет',
              child: Image.asset(ParkAssets.donationBox),
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              180,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: child,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SpeakerLabel extends StatelessWidget {
  const _SpeakerLabel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.leafGreen.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(name, style: AppTextStyles.cardRowLabel),
    ),
  );
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.ink,
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      side: const BorderSide(color: AppColors.fieldBorder, width: 1.5),
      shape: const StadiumBorder(),
      textStyle: AppTextStyles.button.copyWith(color: AppColors.ink),
    ),
    child: Text(label, textAlign: TextAlign.center),
  );
}

class _CoinFlight extends StatelessWidget {
  const _CoinFlight({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      children: [
        for (var index = 0; index < 3; index++) _buildCoin(constraints, index),
      ],
    ),
  );

  Widget _buildCoin(BoxConstraints constraints, int index) {
    final coinProgress = _coinProgress(index);
    final position = _coinPosition(constraints, coinProgress, index);
    return Positioned(
      left: position.dx - 14,
      top: position.dy - 14,
      width: 28,
      height: 28,
      child: Opacity(
        opacity: (1 - (coinProgress - 0.72).clamp(0.0, 0.28) / 0.28).clamp(
          0.0,
          1.0,
        ),
        child: Image.asset('assets/icons/coin.webp'),
      ),
    );
  }

  double _coinProgress(int index) =>
      ((progress - index * 0.12) / 0.76).clamp(0.0, 1.0);

  Offset _coinPosition(
    BoxConstraints constraints,
    double coinProgress,
    int index,
  ) {
    final eased = Curves.easeInOutCubic.transform(coinProgress);
    final start = Offset(
      constraints.maxWidth * (0.42 + index * 0.07),
      constraints.maxHeight * 0.79,
    );
    final end = Offset(
      constraints.maxWidth * 0.78,
      constraints.maxHeight * 0.43,
    );
    final line = Offset.lerp(start, end, eased)!;
    final arc = math.sin(math.pi * eased) * (34 + index * 7);
    return Offset(line.dx, line.dy - arc);
  }
}

class _PaperPanel extends StatelessWidget {
  const _PaperPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.cardBg.withValues(alpha: 0.97),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      border: Border.all(color: AppColors.parchmentDark, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55352923),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _ParkProgress extends StatelessWidget {
  const _ParkProgress({required this.state});

  final ParkProjectState state;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Собрано ${state.collectedAmount} из ${state.targetAmount} монет',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              flex: 2,
              child: Text('Собрано', style: AppTextStyles.cardRowLabel),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              flex: 3,
              child: Text(
                '${state.collectedAmount} из ${state.targetAmount}',
                textAlign: TextAlign.right,
                style: AppTextStyles.counterValue,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: state.collectedAmount / state.targetAmount,
            minHeight: 14,
            backgroundColor: AppColors.parchmentDark,
            color: AppColors.leafGreen,
          ),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 52),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.cardBg.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.parchmentDark, width: 2),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.sectionTitle,
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: const Color(0xFFF8DED8),
      borderRadius: BorderRadius.circular(AppRadii.sm),
    ),
    child: Text(
      message,
      style: AppTextStyles.supporting.copyWith(color: AppColors.crimsonDark),
    ),
  );
}
