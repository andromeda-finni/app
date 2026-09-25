import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../onboarding/widgets/back_circle_button.dart';
import '../../onboarding/widgets/story_button.dart';
import '../../theme/app_theme.dart';
import '../quest_reward_messages.dart';
import 'mole_game_data.dart';
import 'mole_inspection_board.dart';

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

  MoleEpisode get _episode => moleEpisodes[_episodeIndex];

  @override
  void initState() {
    super.initState();
    if (widget.apiClient == null) {
      _syncNote = 'Тренировочный режим: результат не меняет кошелёк.';
    } else {
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
      setState(() {
        _assignmentId = result['assignmentId'] as String?;
        _syncNote = result['resumed'] == true
            ? 'Продолжаем задание с того места, где ты остановился.'
            : reward == null
            ? 'Задание начато.'
            : 'Задание начато. За все пять проверок — $reward монет.';
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
    if (_isSyncing || _isStarting) return;
    if (_assignmentId != null) {
      setState(() {
        _isSyncing = true;
        _syncNote = 'Сохраняем результат…';
      });
      try {
        final result = await widget.apiClient!.post(
          '/assignments/$_assignmentId/answer',
          body: {'stepNo': _episodeIndex + 1, 'selectedOptionCode': 'VERIFIED'},
        );
        if (!mounted) return;
        if (result['outcome'] != 'SUCCESS') {
          setState(
            () => _syncNote = 'Сервер не принял результат. Попробуй ещё раз.',
          );
          return;
        }
        if (result['questCompleted'] == true) {
          _rewardAmount = result['rewardAmount'] as int?;
          _balanceAfter = result['balanceAfter'] as int?;
        }
        setState(() => _syncNote = 'Результат сохранён.');
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
                  child: _showFinal
                      ? _buildFinal(context)
                      : _buildEpisode(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
        ),
        const SizedBox(height: 12),
        _StoryScene(text: _episode.intro),
        const SizedBox(height: 16),
        if (_episode.supportAssets.isNotEmpty) ...[
          _PurchaseStrip(assets: _episode.supportAssets),
          const SizedBox(height: 12),
        ],
        Text(
          allFound ? 'Все детали найдены' : 'Проведи лупой по объявлению',
          style: AppTextStyles.cardTitle.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 6),
        Text(
          allFound
              ? 'Теперь ответь на вопрос. Ошибка ничего не отнимает — можно попробовать ещё раз.'
              : 'Ищи бледные строки и подозрительные суммы. Можно нажать в нужное место или двигать лупу пальцем.',
          style: AppTextStyles.story.copyWith(fontSize: 15),
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
          'Все секреты найдены!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.body,
            color: AppColors.ink,
            fontSize: 30,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ты проверил объявления, пересчитал чеки и помог Земелику не переплатить.',
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
                reward == null ? 'Тренировка завершена' : '+$reward монет',
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
              ] else if (reward == null) ...[
                const SizedBox(height: 6),
                Text(
                  _assignmentId == null
                      ? 'Награда не начисляется без активного задания на сервере.'
                      : 'Результат игры сохранён.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.swatchLabel,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        StoryButton(
          label: 'Вернуться домой',
          showFlourish: true,
          onPressed: () => Navigator.of(context).pop(),
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
  });

  final int current;
  final int total;
  final String title;

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
          width: 44,
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
      ],
    );
  }
}

class _StoryScene extends StatelessWidget {
  const _StoryScene({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
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
                      child: Text(
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
