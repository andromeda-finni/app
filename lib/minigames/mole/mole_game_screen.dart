import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../onboarding/widgets/back_circle_button.dart';
import '../../onboarding/widgets/story_button.dart';
import '../../theme/app_theme.dart';
import '../quest_reward_messages.dart';
import 'mole_game_data.dart';
import 'mole_inspection_board.dart';
import 'mole_truth_case_view.dart';
import 'mole_truth_catalog.dart';
import 'mole_truth_models.dart';

class MoleGameScreen extends StatefulWidget {
  const MoleGameScreen({super.key, this.apiClient});

  /// When omitted, the game works as a local training session. The production
  /// home screen passes its authenticated client so completion can be recorded
  /// and the quest reward can be credited by the server.
  final ApiClient? apiClient;

  @override
  State<MoleGameScreen> createState() => _MoleGameScreenState();
}

class _MoleGameScreenState extends State<MoleGameScreen> {
  int _runSeed = 0;
  late List<MoleTruthCase> _truthRun = buildMoleTruthRun(_runSeed);
  int _promisedReward = kMoleQuestReward;
  var _caseRevision = 0;
  var _episodeIndex = 0;
  var _questionIndex = 0;
  var _wrongAttempts = 0;
  var _foundHotspots = <int>{};
  var _episodeSolved = false;
  var _showFinal = false;
  var _isStarting = false;
  var _isSyncing = false;
  String? _feedback;
  String? _assignmentId;
  String? _syncNote;
  int? _rewardAmount;
  int? _balanceAfter;
  bool _serverQuestCompleted = false;

  MoleEpisode get _episode => moleEpisodes[_episodeIndex];
  MoleTruthCase get _truthCase => _truthRun[_episodeIndex];
  bool get _isTruthCase => !moleClassicSteps(_runSeed).contains(_episodeIndex);

  @override
  void initState() {
    super.initState();
    if (widget.apiClient != null) {
      _startServerQuest();
    }
  }

  Future<void> _startServerQuest() async {
    setState(() => _isStarting = true);
    try {
      final result = await widget.apiClient!.post(
        '/quests/$kMoleQuestId/start',
      );
      if (!mounted) return;
      final reward = (result['rewardAmount'] as num?)?.toInt();
      if (reward != null && reward > 0) _promisedReward = reward;
      if (result['completed'] == true) {
        setState(() {
          _serverQuestCompleted = true;
          _assignmentId = null;
          _syncNote = 'Награда уже получена.';
        });
        return;
      }
      final nextStep = ((result['nextStepNo'] as num?)?.toInt() ?? 1).clamp(
        1,
        moleEpisodes.length,
      );
      setState(() {
        _assignmentId = result['assignmentId'] as String?;
        if (_assignmentId != null) {
          _runSeed = moleTruthSeed(_assignmentId!);
          _truthRun = buildMoleTruthRun(_runSeed);
          _caseRevision++;
        }
        _episodeIndex = nextStep - 1;
        _questionIndex = 0;
        _wrongAttempts = 0;
        _foundHotspots = <int>{};
        _episodeSolved = false;
        _feedback = null;
        _syncNote = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _syncNote = questProblemMessage(error));
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _found(int index) {
    if (_foundHotspots.contains(index)) return;
    setState(() {
      _foundHotspots = {..._foundHotspots, index};
      final hotspot = _episode.hotspots[index];
      _feedback = '${hotspot.label}: ${hotspot.detail}';
    });
  }

  void _showHint() {
    for (var i = 0; i < _episode.hotspots.length; i++) {
      if (!_foundHotspots.contains(i)) {
        _found(i);
        return;
      }
    }
  }

  void _answer(MoleAnswer answer) {
    if (_episodeSolved) return;
    final question = _episode.questions[_questionIndex];
    if (answer.code != question.correctCode) {
      setState(() {
        _wrongAttempts++;
        _feedback = question.recoveryFeedback;
      });
      return;
    }

    if (_questionIndex < _episode.questions.length - 1) {
      setState(() {
        _questionIndex++;
        _wrongAttempts = 0;
        _feedback = question.successFeedback;
      });
      return;
    }

    setState(() {
      _episodeSolved = true;
      _feedback = question.successFeedback;
    });
  }

  Future<void> _continueAfterEpisode() async {
    if (!_episodeSolved || _isSyncing || _isStarting) return;
    if (widget.apiClient != null &&
        _assignmentId == null &&
        !_serverQuestCompleted) {
      await _startServerQuest();
      if (!mounted || _assignmentId == null) return;
    }
    if (_assignmentId != null) {
      setState(() {
        _isSyncing = true;
        _syncNote = 'Сохраняем результат…';
      });
      try {
        final result = await widget.apiClient!.post(
          '/assignments/$_assignmentId/answer',
          body: {
            'stepNo': _episodeIndex + 1,
            'selectedOptionCode': _isTruthCase
                ? _truthCase.serverAnswerCode
                : _episode.questions.last.correctCode,
          },
        );
        if (!mounted) return;
        if (result['outcome'] != 'SUCCESS') {
          setState(() => _syncNote = questRecoveryMessage(result));
          return;
        }
        if (_episodeIndex == moleEpisodes.length - 1 &&
            result['questCompleted'] != true) {
          setState(
            () =>
                _syncNote = 'Не удалось подтвердить награду. Попробуй ещё раз.',
          );
          return;
        }
        if (result['questCompleted'] == true) {
          _rewardAmount = (result['rewardAmount'] as num?)?.toInt();
          _balanceAfter = (result['balanceAfter'] as num?)?.toInt();
          _serverQuestCompleted = true;
          _assignmentId = null;
        }
        setState(() => _syncNote = null);
      } on ApiException catch (error) {
        if (!mounted) return;
        setState(() => _syncNote = questProblemMessage(error));
        return;
      } finally {
        if (mounted) setState(() => _isSyncing = false);
      }
    }

    if (!mounted) return;
    if (_episodeIndex == moleEpisodes.length - 1) {
      setState(() => _showFinal = true);
      return;
    }

    setState(() {
      _episodeIndex++;
      _questionIndex = 0;
      _wrongAttempts = 0;
      _foundHotspots = <int>{};
      _episodeSolved = false;
      _feedback = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _isStarting
                      ? const Center(child: CircularProgressIndicator())
                      : widget.apiClient != null &&
                            _assignmentId == null &&
                            !_serverQuestCompleted
                      ? _buildStartError()
                      : _showFinal
                      ? _buildFinal(context)
                      : _isTruthCase
                      ? _buildTruthEpisode()
                      : _buildEpisode(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTruthEpisode() => ListView(
    key: ValueKey('truth-${_truthCase.id}-$_caseRevision'),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
    children: [
      _ProgressHeader(
        current: _episodeIndex + 1,
        total: moleEpisodes.length,
        title: _truthCase.title,
        reward: _promisedReward,
      ),
      const SizedBox(height: 12),
      _StoryScene(text: _truthCase.intro),
      if (_truthCase.purchaseAssets.isNotEmpty) ...[
        const SizedBox(height: 12),
        _PurchaseStrip(assets: _truthCase.purchaseAssets),
      ],
      const SizedBox(height: 16),
      MoleTruthCaseView(
        key: ValueKey('${_truthCase.id}-$_caseRevision'),
        document: _truthCase,
        onSolved: () => setState(() => _episodeSolved = true),
      ),
      if (_episodeSolved) ...[
        const SizedBox(height: 12),
        StoryButton(
          key: const Key('mole-truth-continue'),
          label: _episodeIndex == moleEpisodes.length - 1
              ? 'Завершить проверку'
              : 'Следующая проверка',
          onPressed: _isStarting || _isSyncing ? null : _continueAfterEpisode,
          isLoading: _isSyncing,
        ),
      ],
      if (_syncNote != null) ...[
        const SizedBox(height: 12),
        _SyncNote(text: _syncNote!, loading: _isStarting),
      ],
    ],
  );

  Widget _buildStartError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _syncNote ?? 'Не получилось открыть задание.',
            style: AppTextStyles.story,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          StoryButton(
            key: const Key('mole-truth-start-retry'),
            label: 'Попробовать ещё раз',
            onPressed: _startServerQuest,
          ),
        ],
      ),
    ),
  );

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(
          bottom: BorderSide(color: AppColors.fieldBorder, width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          BackCircleButton(onPressed: () => Navigator.of(context).maybePop()),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Осторожно, мелкий шрифт',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.leafGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search, size: 16, color: AppColors.leafGreen),
                SizedBox(width: 4),
                Text(
                  'Земелик',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.leafGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisode(BuildContext context) {
    final allFound = _foundHotspots.length == _episode.hotspots.length;
    return ListView(
      key: ValueKey(_episode.id),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        _ProgressHeader(
          current: _episodeIndex + 1,
          total: moleEpisodes.length,
          title: _episode.title,
          reward: _promisedReward,
        ),
        const SizedBox(height: 12),
        _StoryScene(
          text: switch (_episodeIndex) {
            0 => 'Мешок зерна — 8 монет. Проверь, сколько стоит доставка.',
            1 => 'Мне нужен один фонарь. Проверь условия акции.',
            2 => 'Я взял зерно, фонарь и верёвку. Всё ли верно в чеке?',
            3 => 'Упаковку я не просил. Проверь строки и итог.',
            _ => 'Я взял плед, верёвку и ключ. Найди две ошибки.',
          },
        ),
        const SizedBox(height: 16),
        if (_episode.supportAssets.isNotEmpty) ...[
          _PurchaseStrip(assets: _episode.supportAssets),
          const SizedBox(height: 12),
        ],
        Text(
          allFound ? 'Проверь свой ответ' : 'Проведи лупой по документу',
          style: AppTextStyles.cardTitle.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: MoleInspectionBoard(
              episode: _episode,
              foundHotspots: _foundHotspots,
              onHotspotFound: _found,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                'Найдено ${_foundHotspots.length} из ${_episode.hotspots.length}',
                style: AppTextStyles.stepCounter,
              ),
            ),
            TextButton.icon(
              key: const Key('mole-hint-button'),
              onPressed: allFound ? null : _showHint,
              icon: const Icon(Icons.help_outline),
              label: const Text('Подсказка'),
            ),
          ],
        ),
        if (_feedback != null) ...[
          const SizedBox(height: 4),
          _FeedbackCard(
            text: _feedback!,
            positive: _episodeSolved || _wrongAttempts == 0,
          ),
        ],
        const SizedBox(height: 12),
        if (allFound && !_episodeSolved)
          _QuestionCard(
            question: _episode.questions[_questionIndex],
            onAnswer: _answer,
            showExtraHint: _wrongAttempts >= 2,
          ),
        if (_episodeSolved) ...[
          _SolvedCard(text: _episode.successText),
          const SizedBox(height: 12),
          StoryButton(
            key: const Key('mole-classic-continue'),
            label: _episodeIndex == moleEpisodes.length - 1
                ? 'Завершить проверку'
                : 'Следующая проверка',
            onPressed: _isStarting || _isSyncing ? null : _continueAfterEpisode,
            isLoading: _isSyncing,
            showFlourish: _episodeIndex == moleEpisodes.length - 1,
          ),
        ],
        if (_syncNote != null) ...[
          const SizedBox(height: 12),
          _SyncNote(text: _syncNote!, loading: _isStarting),
        ],
      ],
    );
  }

  Widget _buildFinal(BuildContext context) {
    final reward = _rewardAmount;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        const Text(
          'Все пять проверок готовы!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.body,
            color: AppColors.ink,
            fontSize: 30,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Земелик не переплатит. Отличная работа!',
          textAlign: TextAlign.center,
          style: AppTextStyles.story,
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(MoleAssets.chest, fit: BoxFit.contain),
              Positioned(
                right: 18,
                top: 16,
                child: Image.asset(MoleAssets.key, width: 100, height: 100),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: Column(
            children: [
              Text(
                reward == null
                    ? _serverQuestCompleted
                          ? 'Награда уже получена'
                          : 'За пять проверок — $_promisedReward монет'
                    : '+$reward монет',
                style: AppTextStyles.cardTitle.copyWith(
                  color: reward == null ? AppColors.ink : AppColors.crimson,
                  fontSize: 25,
                ),
              ),
              if (_balanceAfter != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Теперь в кошельке $_balanceAfter монет',
                  style: AppTextStyles.story.copyWith(fontSize: 15),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        StoryButton(
          label: 'Вернуться домой',
          showFlourish: true,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('mole-truth-new-run'),
          onPressed: () => setState(() {
            _runSeed++;
            _truthRun = buildMoleTruthRun(_runSeed);
            _episodeIndex = 0;
            _questionIndex = 0;
            _foundHotspots = <int>{};
            _episodeSolved = false;
            _showFinal = false;
            _rewardAmount = null;
            _balanceAfter = null;
            _caseRevision++;
            _syncNote = _serverQuestCompleted ? 'Награда уже получена.' : null;
          }),
          icon: const Icon(Icons.find_in_page_outlined),
          label: const Text('Ещё пять проверок'),
        ),
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.current,
    required this.total,
    required this.title,
    this.reward,
  });

  final int current;
  final int total;
  final String title;
  final int? reward;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ПРОВЕРКА $current ИЗ $total',
                style: AppTextStyles.stepCounter,
              ),
              const SizedBox(height: 2),
              Text(title, style: AppTextStyles.cardTitle),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: MediaQuery.textScalerOf(context).scale(60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: current / total,
                      strokeWidth: 5,
                      color: AppColors.leafGreen,
                      backgroundColor: AppColors.parchmentDark,
                    ),
                    Text('$current', style: AppTextStyles.counterValue),
                  ],
                ),
              ),
              if (reward != null) ...[
                const SizedBox(height: 6),
                Semantics(
                  label: 'Награда за пять проверок: $reward монет',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/icons/coin.webp',
                        width: 16,
                        height: 16,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$reward',
                        style: AppTextStyles.swatchLabel.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StoryScene extends StatelessWidget {
  const _StoryScene({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(13) > 18;
    final scene = AspectRatio(
      aspectRatio: 1.65,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(MoleAssets.shop, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.transparent, Color(0xB8FFF8E8)],
                  stops: [0.25, 0.62],
                ),
              ),
            ),
            Align(
              alignment: const Alignment(-0.82, 1),
              child: FractionallySizedBox(
                widthFactor: 0.43,
                heightFactor: 0.95,
                child: Image.asset(MoleAssets.zemelik, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              left: MediaQuery.sizeOf(context).width < 350 ? 118 : 142,
              right: 12,
              top: 20,
              bottom: 20,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(MoleAssets.dialogue, fit: BoxFit.fill),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 20, 20),
                    child: Center(
                      child: largeText
                          ? const Icon(Icons.receipt_long, color: AppColors.ink)
                          : Text(
                              text,
                              maxLines: 7,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.story.copyWith(
                                fontSize: 13,
                                height: 1.25,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        scene,
        if (largeText) ...[
          const SizedBox(height: 10),
          Text(text, style: AppTextStyles.story),
        ],
      ],
    );
  }
}

class _PurchaseStrip extends StatelessWidget {
  const _PurchaseStrip({required this.assets});

  final List<String> assets;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Покупки Крота',
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          children: [
            Text('Покупки:', style: AppTextStyles.swatchLabel),
            const SizedBox(width: 8),
            for (final asset in assets)
              Expanded(child: Image.asset(asset, fit: BoxFit.contain)),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.onAnswer,
    required this.showExtraHint,
  });

  final MoleQuestion question;
  final ValueChanged<MoleAnswer> onAnswer;
  final bool showExtraHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question.prompt,
            style: AppTextStyles.cardTitle.copyWith(fontSize: 20),
          ),
          if (showExtraHint) ...[
            const SizedBox(height: 8),
            Text(
              'Подсказка: используй только найденные через лупу условия.',
              style: AppTextStyles.swatchLabel.copyWith(
                color: AppColors.crimson,
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final answer in question.answers) ...[
            OutlinedButton(
              key: Key('mole-answer-${answer.code}'),
              onPressed: () => onAnswer(answer),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.fieldBorder),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                answer.label,
                style: AppTextStyles.story.copyWith(fontSize: 15),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.text, required this.positive});

  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: positive ? const Color(0xFFE4EBD8) : const Color(0xFFF4DFD3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              positive ? Icons.check_circle_outline : Icons.lightbulb_outline,
              color: positive ? AppColors.leafGreen : AppColors.crimson,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.story.copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SolvedCard extends StatelessWidget {
  const _SolvedCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE4EBD8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.leafGreen.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: AppColors.leafGreen, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.story.copyWith(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncNote extends StatelessWidget {
  const _SyncNote({required this.text, required this.loading});

  final String text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.crimson,
            ),
          )
        else
          const Icon(
            Icons.cloud_done_outlined,
            size: 18,
            color: AppColors.inkMuted,
          ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppTextStyles.swatchLabel)),
      ],
    );
  }
}
