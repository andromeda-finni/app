import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/game_audio_service.dart';
import '../../pet/pet_energy_status.dart';
import '../../theme/app_theme.dart';
import 'catch_food_board.dart';
import 'catch_food_controller.dart';
import 'catch_food_models.dart';
import 'catch_food_service.dart';

class CatchFoodScreen extends StatefulWidget {
  const CatchFoodScreen({super.key, required this.apiClient, this.onSound});

  final ApiClient apiClient;
  final ValueChanged<GameSound>? onSound;

  @override
  State<CatchFoodScreen> createState() => _CatchFoodScreenState();
}

class _CatchFoodScreenState extends State<CatchFoodScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _service = CatchFoodService(widget.apiClient);
  late final Ticker _ticker;
  CatchFoodInfo? _info;
  CatchFoodController? _game;
  CatchFoodResult? _result;
  Duration? _lastTick;
  String? _sessionId;
  String? _error;
  String? _saveError;
  bool _loading = true;
  bool _starting = false;
  bool _saving = false;
  bool _saved = false;
  bool _artReady = false;
  bool _warmingArt = false;
  bool _foreground = true;
  bool _exitDialogOpen = false;
  int _chargedCost = 0;
  int _previousBest = 0;
  int _bestScore = 0;

  bool get _playing => _game?.phase == CatchFoodPhase.playing;
  bool get _paused => _game?.phase == CatchFoodPhase.paused;
  bool get _canPop => !_starting && (!_playing && !_paused);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_tick);
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_artReady && !_warmingArt) unawaited(_warmArt());
  }

  Future<void> _warmArt() async {
    _warmingArt = true;
    Object? failure;
    final assets = [
      'pantry_background',
      'food_fish',
      'food_spoiled',
      'food_crumbs',
      'catch_sparkle',
      'cat_idle',
      'cat_happy',
      'cat_miss',
      'cat_tired',
      for (final lane in CatchLane.values) ...[
        'cat_catch_${lane.assetName}',
        'chute_${lane.assetName}',
      ],
    ];
    await Future.wait(
      assets.map(
        (name) => precacheImage(
          AssetImage('$catchFoodAssetRoot/$name.webp'),
          context,
          onError: (error, stack) => failure = error,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _warmingArt = false;
      _artReady = failure == null;
      if (failure != null) _error = 'Не удалось загрузить картинки игры.';
    });
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final info = await _service.load();
      if (!mounted) return;
      setState(() {
        _info = info;
        _bestScore = info.bestScore;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _problem(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _start() async {
    if (_starting || _saving || !_artReady || _info == null) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    _sessionId ??= CatchFoodService.newSessionId();
    try {
      final attempt = await _service.start(_sessionId!);
      if (!mounted) return;
      final game = CatchFoodController(config: attempt.info.config)..start();
      if (!_foreground) game.pause();
      setState(() {
        _info = attempt.info;
        _previousBest = attempt.info.bestScore;
        _bestScore = attempt.info.bestScore;
        _chargedCost = attempt.energyCost;
        _result = attempt.finishedResult;
        _saved = attempt.finishedResult != null;
        _saveError = null;
        _game = attempt.finishedResult == null ? game : null;
      });
      if (_playing) _runTicker();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _problem(error));
      if (error is ApiException && error.code == 'pet_energy_insufficient') {
        try {
          final info = await _service.load();
          if (mounted) setState(() => _info = info);
        } catch (_) {
          // Keep the actual start failure visible; no local energy deduction.
        }
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _runTicker() {
    _lastTick = null;
    if (!_ticker.isActive) _ticker.start();
  }

  void _tick(Duration timestamp) {
    final game = _game;
    if (!mounted || game == null || !_playing) return;
    final previous = _lastTick;
    _lastTick = timestamp;
    if (previous == null) return;
    final score = game.score;
    final misses = game.misses;
    setState(() => game.advance(timestamp - previous));
    if (game.score != score) _sound(GameSound.itemPlaced);
    if (game.misses != misses) _sound(GameSound.tryAgain);
    if (game.phase == CatchFoodPhase.finished) {
      _ticker.stop();
      unawaited(_complete());
    }
  }

  void _sound(GameSound sound) {
    if (widget.onSound != null) {
      widget.onSound!(sound);
    } else {
      unawaited(GameAudioService.instance.play(sound));
    }
  }

  void _select(CatchLane lane) {
    if (_playing) setState(() => _game!.select(lane));
  }

  void _pause() {
    if (!_playing) return;
    _ticker.stop();
    _lastTick = null;
    setState(() => _game!.pause());
  }

  void _resume() {
    if (!_paused || !_foreground) return;
    setState(() => _game!.resume());
    _runTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _pause();
  }

  Future<void> _complete() async {
    if (_result != null || _game == null) return;
    _ticker.stop();
    setState(() => _result = _game!.result);
    await _save();
  }

  Future<void> _save() async {
    if (_saving || _saved || _result == null || _sessionId == null) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final best = await _service.finish(_sessionId!, _result!);
      if (mounted) {
        setState(() {
          _bestScore = best;
          _saved = true;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _saveError = _problem(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _again() async {
    if (!_saved || _starting) return;
    setState(() {
      _sessionId = null;
      _game = null;
      _result = null;
      _saved = false;
      _chargedCost = 0;
    });
    await _start();
  }

  Future<void> _confirmLeave() async {
    if (_starting || _exitDialogOpen) return;
    if (_canPop) {
      Navigator.of(context).pop();
      return;
    }
    _pause();
    _exitDialogOpen = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершить попытку?'),
        content: const Text(
          'Сохраним пойманный корм в счёте. Сытость за начатую попытку уже потрачена.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Остаться'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (!mounted || leave != true) return;
    _game!.stop();
    await _complete();
  }

  String _problem(Object error) {
    if (error is ApiException) {
      if (error.code == 'pet_energy_insufficient') {
        return 'Не хватает сытости. Покорми питомца или дай ему отдохнуть.';
      }
      if (error.statusCode == 401) return 'Нужно снова войти в приложение.';
      if (error.isNetworkError) {
        return 'Нет связи с сервером. Попробуй ещё раз.';
      }
    }
    return 'Не удалось получить данные игры. Попробуй ещё раз.';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return PopScope<void>(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyQ): () =>
              _select(CatchLane.upperLeft),
          const SingleActivator(LogicalKeyboardKey.keyA): () =>
              _select(CatchLane.lowerLeft),
          const SingleActivator(LogicalKeyboardKey.keyP): () =>
              _select(CatchLane.upperRight),
          const SingleActivator(LogicalKeyboardKey.keyL): () =>
              _select(CatchLane.lowerRight),
          const SingleActivator(LogicalKeyboardKey.space): () =>
              _paused ? _resume() : _pause(),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: AppColors.canvas,
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Назад',
                          onPressed: _starting ? null : _confirmLeave,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(
                          child: Text(
                            'Лови корм',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.screenTitle,
                          ),
                        ),
                        IconButton(
                          key: const Key('catch-food-pause'),
                          tooltip: _paused ? 'Продолжить' : 'Пауза',
                          onPressed: _playing
                              ? _pause
                              : _paused
                              ? _resume
                              : null,
                          icon: Icon(
                            _paused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _result != null
                        ? _resultView()
                        : game != null
                        ? _playView(game)
                        : _introView(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _introView() {
    final info = _info;
    if (_loading || (!_artReady && _error == null)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (info == null || !_artReady) {
      return _PagePanel(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 44,
            color: AppColors.crimson,
          ),
          Text(
            _error ?? 'Не удалось открыть игру.',
            textAlign: TextAlign.center,
          ),
          _ActionButton(
            label: 'Повторить',
            onPressed: () {
              if (!_artReady) unawaited(_warmArt());
              unawaited(_load());
            },
          ),
        ],
      );
    }
    final canStart = info.energy.level >= info.config.energyCost;
    return _PagePanel(
      children: [
        Image.asset(
          '$catchFoodAssetRoot/cat_idle.webp',
          height: 200,
          excludeFromSemantics: true,
        ),
        Text(
          'Подставляй миску',
          style: AppTextStyles.screenTitle,
          textAlign: TextAlign.center,
        ),
        const Text(
          'Корм катится с четырёх сторон. Нажимай на нужную стрелку и успевай поймать его миской.',
          textAlign: TextAlign.center,
        ),
        const _FoodLegend(),
        Text(
          'Пропущенная рыбка или пойманный испорченный корм — ошибка. ${info.config.maxMisses} ошибки завершают попытку. Через ${info.config.durationMs ~/ 1000} секунд кот устанет.',
          textAlign: TextAlign.center,
          style: AppTextStyles.supporting,
        ),
        Text(
          'Сытость ${info.energy.level}/${info.energy.maxEnergy} · Рекорд $_bestScore',
          textAlign: TextAlign.center,
        ),
        const Text(
          'Корм в игре — это очки, а не еда для питомца.',
          textAlign: TextAlign.center,
          style: AppTextStyles.swatchLabel,
        ),
        if (_error != null)
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.crimson),
          ),
        _ActionButton(
          buttonKey: const Key('catch-food-start'),
          label: _starting
              ? 'Начинаем…'
              : 'Играть · −${info.config.energyCost} сытости',
          onPressed: !_starting && canStart ? _start : null,
        ),
        if (!canStart) ...[
          const Text(
            'Покорми питомца или дай ему отдохнуть.',
            textAlign: TextAlign.center,
          ),
          if (info.energy.isRecovering)
            Text(
              'Восстановится через ${formatEnergyCountdown(info.energy.untilNextTick())}',
              textAlign: TextAlign.center,
            ),
          TextButton(onPressed: _load, child: const Text('Проверить сытость')),
        ],
      ],
    );
  }

  Widget _playView(CatchFoodController game) => Column(
    children: [
      _GameStatus(
        game: game,
        satiety: _info!.energy.level,
        bestScore: _bestScore,
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CatchFoodBoard(controller: game),
              if (game.elapsedUs - game.lastSpoiledCatchUs < 1000000)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: IgnorePointer(
                    child: Material(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Испорченный корм! Его нужно пропускать',
                          key: Key('catch-food-spoiled-warning'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.crimson),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_paused)
                ColoredBox(
                  color: AppColors.ink.withValues(alpha: .42),
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Card(
                        color: AppColors.cardBg,
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Пауза', style: AppTextStyles.screenTitle),
                              const SizedBox(height: 10),
                              const Text(
                                'Корм и время остановлены.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              _ActionButton(
                                buttonKey: const Key('catch-food-resume'),
                                label: 'Продолжить',
                                onPressed: _resume,
                              ),
                              TextButton(
                                onPressed: _confirmLeave,
                                child: const Text('Завершить попытку'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      _ControlPad(
        selected: game.selected,
        enabled: _playing,
        onSelect: _select,
      ),
    ],
  );

  Widget _resultView() {
    final result = _result!;
    final newBest = result.score > _previousBest;
    final tired = result.reason == CatchFoodFinish.tired;
    final cat = tired
        ? 'tired'
        : newBest
        ? 'happy'
        : 'miss';
    final enough = _info!.energy.level >= _info!.config.energyCost;
    return _PagePanel(
      children: [
        Image.asset(
          '$catchFoodAssetRoot/cat_$cat.webp',
          height: 200,
          excludeFromSemantics: true,
        ),
        Text(
          tired
              ? 'Кот устал. Пора передохнуть'
              : newBest
              ? 'Новый рекорд!'
              : 'Попробуем ещё?',
          style: AppTextStyles.screenTitle,
          textAlign: TextAlign.center,
        ),
        Text(
          'Поймано ${result.score}',
          key: const Key('catch-food-result'),
          style: AppTextStyles.sectionTitle,
        ),
        Text(
          'Рекорд $_bestScore · Ошибки ${result.misses}',
          textAlign: TextAlign.center,
        ),
        Text('Потрачено сытости: $_chargedCost', textAlign: TextAlign.center),
        if (_saving) const Text('Сохраняем результат…'),
        if (_saved)
          const Text('Результат сохранён', style: AppTextStyles.supporting),
        if (_saveError != null) ...[
          Text(
            'Результат пока не сохранён. $_saveError',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.crimson),
          ),
          _ActionButton(
            buttonKey: const Key('catch-food-retry-save'),
            label: 'Повторить сохранение',
            onPressed: _saving ? null : _save,
          ),
        ],
        if (_saved && enough)
          _ActionButton(
            label: 'Ещё раз · −${_info!.config.energyCost} сытости',
            onPressed: _again,
          ),
        if (_saved && !enough)
          const Text(
            'Для новой попытки нужно восстановить сытость.',
            textAlign: TextAlign.center,
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Домой'),
        ),
      ],
    );
  }
}

class _PagePanel extends StatelessWidget {
  const _PagePanel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (constraints.maxHeight - 32).clamp(0, double.infinity),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              children[i],
            ],
          ],
        ),
      ),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    this.buttonKey,
    required this.label,
    required this.onPressed,
  });
  final Key? buttonKey;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      key: buttonKey,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.crimson,
        foregroundColor: AppColors.cardBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        textStyle: AppTextStyles.button,
      ),
      onPressed: onPressed,
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

class _GameStatus extends StatelessWidget {
  const _GameStatus({
    required this.game,
    required this.satiety,
    required this.bestScore,
  });
  final CatchFoodController game;
  final int satiety;
  final int bestScore;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Поймано ${game.score}',
                key: const Key('catch-food-score'),
                style: AppTextStyles.sectionTitle,
              ),
            ),
            Semantics(
              label: 'Ошибки ${game.misses} из ${game.config.maxMisses}',
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < game.config.maxMisses; i++)
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Icon(
                          i < game.misses
                              ? Icons.close_rounded
                              : Icons.circle_outlined,
                          size: 20,
                          color: i < game.misses
                              ? AppColors.crimson
                              : AppColors.fieldBorder,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 18,
          runSpacing: 4,
          children: [
            Text('Сытость $satiety', style: AppTextStyles.swatchLabel),
            Text(
              game.fatigue >= 2 / 3 ? 'Устаёт' : 'Бодр',
              style: AppTextStyles.swatchLabel.copyWith(
                color: AppColors.leafGreen,
              ),
            ),
            Text(
              '${game.remainingSeconds} с · Рекорд $bestScore',
              style: AppTextStyles.swatchLabel,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Semantics(
          label: 'Время до отдыха',
          value: '${game.remainingSeconds} секунд',
          child: LinearProgressIndicator(
            value: 1 - game.fatigue,
            minHeight: 4,
            color: AppColors.leafGreen,
            backgroundColor: AppColors.parchmentDark,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        const _FoodLegend(),
      ],
    ),
  );
}

class _FoodLegend extends StatelessWidget {
  const _FoodLegend();

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 16,
    runSpacing: 4,
    children: [
      for (final entry in [
        ('fish', 'Рыбку — лови'),
        ('spoiled', 'С крестиком — пропускай'),
      ])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              '$catchFoodAssetRoot/food_${entry.$1}.webp',
              width: 26,
              height: 26,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 4),
            Flexible(child: Text(entry.$2, style: AppTextStyles.swatchLabel)),
          ],
        ),
    ],
  );
}

class _ControlPad extends StatelessWidget {
  const _ControlPad({
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });
  final CatchLane selected;
  final bool enabled;
  final ValueChanged<CatchLane> onSelect;

  Widget _button(CatchLane lane, IconData icon) => Semantics(
    selected: lane == selected,
    child: SizedBox(
      width: 82,
      height: 62,
      child: IconButton.filledTonal(
        key: ValueKey('catch-control-${lane.assetName}'),
        tooltip: lane.label,
        style: IconButton.styleFrom(
          backgroundColor: lane == selected
              ? AppColors.crimson
              : AppColors.parchment,
          foregroundColor: lane == selected ? AppColors.cardBg : AppColors.ink,
          side: const BorderSide(color: AppColors.fieldBorder),
        ),
        iconSize: 34,
        icon: Icon(
          icon,
          color: !enabled
              ? AppColors.inkMuted
              : lane == selected
              ? AppColors.cardBg
              : AppColors.ink,
        ),
        onPressed: enabled ? () => onSelect(lane) : null,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
    child: Row(
      children: [
        Column(
          children: [
            _button(CatchLane.upperLeft, Icons.north_west_rounded),
            const SizedBox(height: 8),
            _button(CatchLane.lowerLeft, Icons.south_west_rounded),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Подставляй\nмиску',
                textAlign: TextAlign.center,
                softWrap: false,
                style: AppTextStyles.swatchLabel,
              ),
            ),
          ),
        ),
        Column(
          children: [
            _button(CatchLane.upperRight, Icons.north_east_rounded),
            const SizedBox(height: 8),
            _button(CatchLane.lowerRight, Icons.south_east_rounded),
          ],
        ),
      ],
    ),
  );
}
