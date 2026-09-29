import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/child_difficulty.dart';
import '../core/pet_assets.dart';
import '../games/goldfish/goldfish_game_models.dart';
import '../games/goldfish/goldfish_game_screen.dart';
import '../games/ivan/ivan_game_models.dart';
import '../games/ivan/ivan_game_screen.dart';
import '../games/turnip/turnip_game_models.dart';
import '../games/turnip/turnip_game_screen.dart';
import '../minigames/bakery/bakery_game_screen.dart';
import '../minigames/mole/mole_game_screen.dart';
import '../minigames/park/park_project_screen.dart';
import '../minigames/tugriki/tugriki_game_screen.dart';
import '../pet/pet_energy_status.dart';
import '../theme/app_theme.dart';
import 'quest_map_data.dart';

class QuestMapScreen extends StatefulWidget {
  const QuestMapScreen({
    super.key,
    this.apiClient,
    this.showBack = true,
    this.initialUnlockedIndex = 0,
    this.difficulty = ChildDifficulty.beginner,
    this.enableAmbientSceneMotion = true,
  });

  /// Source of progress and the server every launched game reports to.
  /// Without it (previews, widget tests) the map stays at
  /// [initialUnlockedIndex] and games run as practice.
  final ApiClient? apiClient;

  /// False when the map is a tab root and there is nowhere to go back to.
  final bool showBack;

  final int initialUnlockedIndex;
  final ChildDifficulty difficulty;

  /// Allows deterministic screenshots and tests while production keeps the
  /// current story scene gently alive. System reduced-motion still wins.
  final bool enableAmbientSceneMotion;

  @override
  State<QuestMapScreen> createState() => _QuestMapScreenState();
}

class _QuestMapScreenState extends State<QuestMapScreen>
    with TickerProviderStateMixin {
  static const _mapAsset = 'assets/map/quest_map_scenarios_v05_clean.webp';
  static const _sourceWidth = 821.0;
  static const _sourceHeight = 1916.0;

  final _scrollController = ScrollController();
  late final AnimationController _catController = AnimationController(
    vsync: this,
  )..addListener(_followCat);
  late final AnimationController _catReactionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  late final AnimationController _questPulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  Animation<Offset>? _catAnimation;
  late Offset _catPosition;
  late int _currentPathIndex;
  final Set<String> _completedQuestIds = {};
  final Set<String> _inProgressQuestIds = {};
  final Map<String, int> _rewardAmounts = {};
  String? _parkScene;
  // Neutral until the server answers: the child names the pet themselves.
  String _petName = 'Питомец';
  String? _furOptionId;
  PetEnergyStatus _energy = const PetEnergyStatus.full();
  int _movementVersion = 0;
  double _renderedMapHeight = 0;
  double _viewportHeight = 0;
  String? _hoveredNodeId;
  String? _selectedNodeId;
  String? _arrivedNodeId;
  bool _catFacesRight = true;
  bool _didJumpToStart = false;
  bool _hasLoadedProgress = false;
  bool _isLoadingProgress = false;
  String? _progressError;

  @override
  void initState() {
    super.initState();
    final previewIndex = widget.initialUnlockedIndex
        .clamp(0, questMapNodes.length - 1)
        .toInt();
    for (var index = 0; index < previewIndex; index++) {
      final questId = questMapNodes[index].destination.questId;
      if (questId != null) _completedQuestIds.add(questId);
    }
    _isLoadingProgress = widget.apiClient != null;
    _placeCatAtCurrent();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToStart());
    if (widget.apiClient != null) _loadProgress();
  }

  void _placeCatAtCurrent() {
    final node = questMapNodes[catNodeIndexFor(_completedQuestIds)];
    _catPosition = node.catStop;
    _currentPathIndex = node.pathIndex;
    _arrivedNodeId = node.id;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !widget.enableAmbientSceneMotion) {
      _questPulseController
        ..stop()
        ..value = 0;
    } else if (!_questPulseController.isAnimating) {
      _questPulseController.repeat();
    }
  }

  /// Progress lives on the server as completed quest assignments, so it
  /// survives restarts and matches the rewards actually paid.
  Future<void> _loadProgress() async {
    if (widget.apiClient == null) return;
    setState(() {
      _isLoadingProgress = true;
      _progressError = null;
    });
    try {
      final economy = await widget.apiClient!.get('/economy/state');
      final completed = <String>{
        for (final quest in (economy['quests'] as List? ?? const []))
          if (quest is Map && quest['assignment_status'] == 'COMPLETED')
            quest['id'] as String,
      };
      final inProgress = <String>{
        for (final quest in (economy['quests'] as List? ?? const []))
          if (quest is Map && quest['assignment_status'] == 'IN_PROGRESS')
            quest['id'] as String,
      };
      final rewards = <String, int>{
        for (final quest in (economy['quests'] as List? ?? const []))
          if (quest is Map &&
              quest['id'] is String &&
              quest['reward_amount'] is num)
            quest['id'] as String: (quest['reward_amount'] as num).toInt(),
      };
      final pet = economy['pet'] as Map?;
      final name = pet?['pet_name'];
      final fur = pet?['fur_option_id'];
      String? parkScene;
      if (completed.contains('Q_TUGRIKI_CURRENCY')) {
        try {
          final park = await widget.apiClient!.get('/park-project');
          parkScene = park['scene'] as String?;
        } on ApiException {
          // Keep the rewarded quest path usable when this optional story
          // status cannot be refreshed yet.
        }
      }
      final energy = pet == null
          ? const PetEnergyStatus.full()
          : PetEnergyStatus.fromJson(Map<String, dynamic>.from(pet));
      if (!mounted) return;
      final previousCatIndex = catNodeIndexFor(_completedQuestIds);
      final nextCatIndex = catNodeIndexFor(completed);
      final shouldMove = _hasLoadedProgress && nextCatIndex != previousCatIndex;
      setState(() {
        if (name is String && name.trim().isNotEmpty) _petName = name;
        if (fur is String) _furOptionId = fur;
        _energy = energy;
        _completedQuestIds
          ..clear()
          ..addAll(completed);
        _inProgressQuestIds
          ..clear()
          ..addAll(inProgress);
        _rewardAmounts
          ..clear()
          ..addAll(rewards);
        _parkScene = parkScene;
        if (!shouldMove) {
          _placeCatAtCurrent();
          _didJumpToStart = false;
        }
        _hasLoadedProgress = true;
        _isLoadingProgress = false;
        _progressError = null;
      });
      if (shouldMove) {
        await _moveCatTo(nextCatIndex);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToStart());
      }
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _isLoadingProgress = false;
        _progressError = 'Не удалось загрузить прогресс карты';
      });
    }
  }

  QuestMapNodeState _stateFor(QuestMapNode node) =>
      stateForQuestMapNode(node, _completedQuestIds);

  /// The server quest this node will start next: multi-level tracks point at
  /// their next level for the child's difficulty.
  String? _questIdFor(QuestMapNode node) => switch (node.destination) {
    QuestMapDestination.ivan => nextIvanLevel(
      completedQuestIds: _completedQuestIds,
      preferredDifficulty: widget.difficulty == ChildDifficulty.advanced
          ? IvanDifficulty.hard
          : IvanDifficulty.easy,
    ).questId,
    QuestMapDestination.goldfish => nextGoldfishLevel(
      completedQuestIds: _completedQuestIds,
      preferredDifficulty: widget.difficulty == ChildDifficulty.advanced
          ? GoldfishDifficulty.hard
          : GoldfishDifficulty.normal,
    ).questId,
    _ => node.destination.questId,
  };

  /// Only amounts the server reported; nothing is promised before it answers.
  int? _rewardFor(QuestMapNode node) => _rewardAmounts[_questIdFor(node)];

  bool _inProgress(QuestMapNode node) =>
      _inProgressQuestIds.contains(_questIdFor(node));

  String? get _parkStatusText => switch (_parkScene) {
    'FIRST_OFFER' || 'SECOND_OFFER' => 'Есть просьба',
    'WAITING_SECOND' || 'WAITING_COMMUNITY' => 'Ждём новостей',
    'FUNDED' || 'BUILDING' => 'Парк строится',
    'ALMOST_READY' => 'Почти готово',
    'OPEN' => 'Парк открыт',
    _ => null,
  };

  String get _headerProgressLabel {
    final currentIndex = currentPlayableNodeIndex(_completedQuestIds);
    if (currentIndex != null) {
      return 'Квест №${questMapNodes[currentIndex].order}';
    }
    final completed = completedPlayableQuestCount(_completedQuestIds);
    return '$completed квеста пройдено';
  }

  String _unlockMessage(QuestMapNode node) {
    if (!node.isPlayable) return 'Глава в разработке';
    final currentIndex = currentPlayableNodeIndex(_completedQuestIds);
    if (currentIndex == null) return 'Все доступные задания пройдены';
    final current = questMapNodes[currentIndex];
    return 'Откроется после квеста ${current.order} «${current.title}»';
  }

  @override
  void dispose() {
    _catController.dispose();
    _catReactionController.dispose();
    _questPulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToStart() {
    if (!mounted || _didJumpToStart) return;
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToStart());
      return;
    }
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToStart());
      return;
    }
    _didJumpToStart = true;
    final catY = _catPosition.dy * _renderedMapHeight;
    _scrollController.jumpTo(
      (catY - _viewportHeight * 0.58).clamp(0.0, maxExtent).toDouble(),
    );
  }

  void _followCat() {
    final animation = _catAnimation;
    if (animation == null || !_scrollController.hasClients) return;

    final mapY = animation.value.dy * _renderedMapHeight;
    final desiredOffset = (mapY - _viewportHeight * 0.58)
        .clamp(0.0, _scrollController.position.maxScrollExtent)
        .toDouble();
    if ((_scrollController.offset - desiredOffset).abs() > 0.75) {
      _scrollController.jumpTo(desiredOffset);
    }
  }

  Future<void> _selectNode(QuestMapNode node) async {
    final state = _stateFor(node);
    setState(() => _selectedNodeId = null);

    if (state == QuestMapNodeState.current ||
        state == QuestMapNodeState.completed) {
      await _moveCatTo(questMapNodes.indexOf(node));
    }
    if (!mounted) return;
    setState(() => _selectedNodeId = node.id);
    if (!MediaQuery.disableAnimationsOf(context) &&
        widget.enableAmbientSceneMotion) {
      _questPulseController.repeat();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealPrompt(node));
  }

  void _revealPrompt(QuestMapNode node) {
    if (!mounted || !_scrollController.hasClients) return;
    final placeBelow = node.nodeCenter.dy < 0.14;
    final promptTop = placeBelow
        ? node.nodeCenter.dy * _renderedMapHeight + 58
        : node.nodeCenter.dy * _renderedMapHeight - 210;
    final desiredOffset = (promptTop - 24)
        .clamp(0.0, _scrollController.position.maxScrollExtent)
        .toDouble();
    if (MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(desiredOffset);
      return;
    }
    _scrollController.animateTo(
      desiredOffset,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _moveCatTo(int nodeIndex) async {
    final version = ++_movementVersion;
    final node = questMapNodes[nodeIndex];
    final currentPosition = _catAnimation?.value ?? _catPosition;
    _catController.stop();
    // animateTo(1) leaves the controller completed. A new route must start at
    // zero, otherwise every trip after the first renders at its destination
    // immediately and looks like a teleport.
    _catAnimation = null;
    _catController.value = 0;

    if ((currentPosition - node.catStop).distance < 0.004) {
      if (!MediaQuery.disableAnimationsOf(context)) {
        await _catReactionController.forward(from: 0);
        if (!mounted || version != _movementVersion) return;
      }
      setState(() {
        _catPosition = node.catStop;
        _currentPathIndex = node.pathIndex;
        _catAnimation = null;
        _arrivedNodeId = node.id;
      });
      return;
    }

    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() {
        _catPosition = node.catStop;
        _currentPathIndex = node.pathIndex;
        _catAnimation = null;
        _arrivedNodeId = node.id;
      });
      _didJumpToStart = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToStart());
      return;
    }

    final closestIndex = _nearestPathIndex(currentPosition);
    final route = _routeBetween(currentPosition, closestIndex, node.pathIndex);
    if ((route.last - node.catStop).distance > 0.001) {
      route.add(node.catStop);
    }
    final totalDistance = _routeDistance(route);
    final durationMs = (620 + totalDistance * 1900).clamp(620, 2450).round();

    setState(() {
      _arrivedNodeId = null;
      _catFacesRight =
          node.catFacesRight ?? node.catStop.dx >= currentPosition.dx;
      _catAnimation = _routeTween(route).animate(_catController);
    });
    _questPulseController
      ..stop()
      ..reset();
    try {
      await _catController.animateTo(
        1,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.easeInOutCubic,
      );
    } on TickerCanceled {
      return;
    }

    if (!mounted || version != _movementVersion) return;
    setState(() {
      _catPosition = node.catStop;
      _currentPathIndex = node.pathIndex;
      _catAnimation = null;
      _arrivedNodeId = node.id;
    });
    if (!MediaQuery.disableAnimationsOf(context) &&
        widget.enableAmbientSceneMotion) {
      _questPulseController.repeat();
    }
  }

  int _nearestPathIndex(Offset position) {
    var nearest = _currentPathIndex;
    var nearestDistance = double.infinity;
    for (var index = 0; index < questMapPath.length; index++) {
      final distance = (questMapPath[index] - position).distanceSquared;
      if (distance < nearestDistance) {
        nearest = index;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  List<Offset> _routeBetween(Offset from, int fromIndex, int toIndex) {
    final route = <Offset>[from];
    if (toIndex > fromIndex) {
      for (var index = fromIndex + 1; index <= toIndex; index++) {
        route.add(questMapPath[index]);
      }
    } else if (toIndex < fromIndex) {
      for (var index = fromIndex - 1; index >= toIndex; index--) {
        route.add(questMapPath[index]);
      }
    }
    if (route.length == 1 || route.last != questMapPath[toIndex]) {
      route.add(questMapPath[toIndex]);
    }
    return route;
  }

  double _routeDistance(List<Offset> route) {
    var distance = 0.0;
    for (var index = 1; index < route.length; index++) {
      distance += (route[index] - route[index - 1]).distance;
    }
    return distance;
  }

  TweenSequence<Offset> _routeTween(List<Offset> route) {
    final distances = <double>[];
    var totalDistance = 0.0;
    for (var index = 1; index < route.length; index++) {
      final distance = math.max(
        (route[index] - route[index - 1]).distance,
        0.001,
      );
      distances.add(distance);
      totalDistance += distance;
    }

    return TweenSequence<Offset>([
      for (var index = 1; index < route.length; index++)
        TweenSequenceItem(
          tween: Tween<Offset>(begin: route[index - 1], end: route[index]),
          weight: distances[index - 1] / totalDistance,
        ),
    ]);
  }

  Future<void> _launchNode(QuestMapNode node) async {
    setState(() => _selectedNodeId = null);
    if (_stateFor(node) == QuestMapNodeState.current &&
        !await _ensureActivityEnergy()) {
      return;
    }
    await _launch(node.destination);
    // A finished game may have completed its quest and opened the next node.
    if (mounted && widget.apiClient != null) await _loadProgress();
  }

  Future<bool> _ensureActivityEnergy() async {
    if (widget.apiClient == null) return true;
    try {
      final pet = await widget.apiClient!.get('/pet');
      if (!mounted) return false;
      setState(() => _energy = PetEnergyStatus.fromJson(pet));
    } on ApiException {
      // The start endpoint repeats the check atomically. If this lightweight
      // refresh fails, let it produce the authoritative child-facing error.
      return true;
    }
    if (!_energy.blocksActivities) return true;
    if (!mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('energy-blocked-dialog'),
        title: Text('$_petName отдыхает'),
        content: Text(
          'Для нового квеста нужно ${_energy.activityCost} энергии. '
          'Сейчас у $_petName ${_energy.level}.\n\n'
          'Следующие +${_energy.energyPerTick}: '
          '${formatEnergyCountdown(_energy.untilNextTick())}. '
          'Можно немного подождать или покормить питомца в магазине.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Хорошо'),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _showNodeDetails(QuestMapNode node) async {
    final shouldOpen = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x663B2F27),
      builder: (context) => _QuestDetailsSheet(
        node: node,
        state: _stateFor(node),
        unlockMessage: _unlockMessage(node),
        rewardAmount: _rewardFor(node),
        isInProgress: _inProgress(node),
        parkStatus: node.destination == QuestMapDestination.badger
            ? _parkStatusText
            : null,
      ),
    );
    if (shouldOpen == true && mounted) await _launchNode(node);
  }

  Future<void> _launch(QuestMapDestination destination) {
    final navigator = Navigator.of(context);
    return switch (destination) {
      QuestMapDestination.turnip => navigator.push<void>(
        MaterialPageRoute(
          builder: (gameContext) => TurnipGameScreen(
            difficulty: widget.difficulty == ChildDifficulty.advanced
                ? TurnipDifficulty.hard
                : TurnipDifficulty.normal,
            apiClient: widget.apiClient,
            petName: _petName,
            onExit: () => Navigator.of(gameContext).pop(),
          ),
        ),
      ),
      QuestMapDestination.mole => navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => MoleGameScreen(apiClient: widget.apiClient),
        ),
      ),
      QuestMapDestination.bakery => navigator.push<void>(
        MaterialPageRoute(
          builder: (gameContext) => BakeryGameScreen(
            difficulty: widget.difficulty,
            apiClient: widget.apiClient,
            onExit: () => Navigator.of(gameContext).pop(),
          ),
        ),
      ),
      QuestMapDestination.ivan => navigator.push<void>(
        MaterialPageRoute(
          builder: (gameContext) => IvanGameScreen(
            initialLevel: nextIvanLevel(
              completedQuestIds: _completedQuestIds,
              preferredDifficulty: widget.difficulty == ChildDifficulty.advanced
                  ? IvanDifficulty.hard
                  : IvanDifficulty.easy,
            ),
            apiClient: widget.apiClient,
            petName: _petName,
            onExit: () => Navigator.of(gameContext).pop(),
          ),
        ),
      ),
      QuestMapDestination.goldfish => navigator.push<void>(
        MaterialPageRoute(
          builder: (gameContext) => GoldfishGameScreen(
            initialLevel: nextGoldfishLevel(
              completedQuestIds: _completedQuestIds,
              preferredDifficulty: widget.difficulty == ChildDifficulty.advanced
                  ? GoldfishDifficulty.hard
                  : GoldfishDifficulty.normal,
            ),
            apiClient: widget.apiClient,
            petName: _petName,
            onExit: () => Navigator.of(gameContext).pop(),
          ),
        ),
      ),
      QuestMapDestination.tugriki => navigator.push<void>(
        MaterialPageRoute(
          builder: (gameContext) => TugrikiGameScreen(
            apiClient: widget.apiClient,
            petName: _petName,
            furOptionId: _furOptionId,
            onExit: () => Navigator.of(gameContext).pop(),
          ),
        ),
      ),
      QuestMapDestination.badger => navigator.push<void>(
        MaterialPageRoute(
          builder: (gameContext) => ParkProjectScreen(
            difficulty: widget.difficulty,
            apiClient: widget.apiClient,
            petName: _petName,
            furOptionId: _furOptionId,
            onExit: () => Navigator.of(gameContext).pop(),
          ),
        ),
      ),
      QuestMapDestination.upcoming => Future.value(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Column(
          children: [
            _MapHeader(
              onBack: widget.showBack
                  ? () => Navigator.of(context).maybePop()
                  : null,
              progressLabel: _headerProgressLabel,
            ),
            if (_hasLoadedProgress &&
                completedPlayableQuestCount(_completedQuestIds) ==
                    playableQuestCount)
              const _MapStatusBanner(
                key: Key('map-complete-banner'),
                icon: Icons.celebration_rounded,
                text: 'Все доступные задания пройдены',
                color: AppColors.leafGreen,
              )
            else if (_progressError != null && _hasLoadedProgress)
              _MapStatusBanner(
                icon: Icons.cloud_off_rounded,
                text: 'Показан сохранённый прогресс',
                color: AppColors.crimson,
                actionLabel: 'Повторить',
                onAction: _loadProgress,
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final mapWidth = math.min(constraints.maxWidth, _sourceWidth);
                  final mapHeight = mapWidth * _sourceHeight / _sourceWidth;
                  _renderedMapHeight = mapHeight;
                  _viewportHeight = constraints.maxHeight;

                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _jumpToStart(),
                  );

                  final map = ScrollConfiguration(
                    behavior: const _MapScrollBehavior(),
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: constraints.maxWidth >= 600,
                      trackVisibility: constraints.maxWidth >= 600,
                      interactive: constraints.maxWidth >= 600,
                      thickness: 8,
                      radius: const Radius.circular(8),
                      child: SingleChildScrollView(
                        key: const Key('quest-map-scroll'),
                        controller: _scrollController,
                        physics: const ClampingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: mapWidth,
                            height: mapHeight,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: Image.asset(
                                    _mapAsset,
                                    fit: BoxFit.fill,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                                for (final node in questMapNodes)
                                  if (node.id ==
                                      (_selectedNodeId ?? _arrivedNodeId))
                                    _buildSceneHighlight(
                                      node,
                                      mapWidth,
                                      mapHeight,
                                    ),
                                for (final node in questMapNodes)
                                  _buildQuestNode(node, mapWidth, mapHeight),
                                _buildMovingCat(mapWidth, mapHeight),
                                if (_selectedNodeId case final selectedId?)
                                  _buildQuestPrompt(
                                    questMapNodes.firstWhere(
                                      (node) => node.id == selectedId,
                                    ),
                                    mapWidth,
                                    mapHeight,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                  if (_isLoadingProgress && !_hasLoadedProgress) {
                    return Stack(
                      children: [
                        IgnorePointer(child: map),
                        const Positioned.fill(
                          child: _MapProgressOverlay.loading(),
                        ),
                      ],
                    );
                  }
                  if (_progressError != null && !_hasLoadedProgress) {
                    return Stack(
                      children: [
                        IgnorePointer(child: map),
                        Positioned.fill(
                          child: _MapProgressOverlay.error(
                            onRetry: _loadProgress,
                          ),
                        ),
                      ],
                    );
                  }
                  return map;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSceneHighlight(
    QuestMapNode node,
    double mapWidth,
    double mapHeight,
  ) {
    final sourceScale = mapWidth / _sourceWidth;
    final size = (76 * sourceScale).clamp(40.0, 76.0).toDouble();
    return Positioned(
      key: Key('quest-scene-highlight-${node.id}'),
      left: node.sceneEffectAnchor.dx * mapWidth - size / 2,
      top: node.sceneEffectAnchor.dy * mapHeight - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _questPulseController,
          builder: (context, _) {
            final value = _questPulseController.value;
            final pulse = 1 - (value * 2 - 1).abs();
            return _QuestSceneHighlight(effect: node.sceneEffect, pulse: pulse);
          },
        ),
      ),
    );
  }

  Widget _buildQuestNode(QuestMapNode node, double mapWidth, double mapHeight) {
    final isHovered = _hoveredNodeId == node.id;
    final isSelected = _selectedNodeId == node.id;
    final isArrived = _arrivedNodeId == node.id;
    final state = _stateFor(node);
    final isCurrent = state == QuestMapNodeState.current;
    final sourceScale = mapWidth / _sourceWidth;
    final paintedWidth = (node.order == 8 ? 124.0 : 180.0) * sourceScale;
    final paintedHeight = (node.order == 8 ? 132.0 : 112.0) * sourceScale;
    final nodeWidth = math.max(104.0, paintedWidth);
    final nodeHeight = math.max(72.0, paintedHeight);

    return Positioned(
      left: node.nodeCenter.dx * mapWidth - nodeWidth / 2,
      top: node.nodeCenter.dy * mapHeight - nodeHeight / 2,
      width: nodeWidth,
      height: nodeHeight,
      child: Semantics(
        button: true,
        selected: isSelected,
        label:
            'Квест ${node.order}. ${node.title}. ${state.semanticLabel}'
            '${isArrived ? '. Кот здесь' : ''}',
        hint: isArrived
            ? 'Кот находится на этой площадке'
            : isCurrent
            ? 'Нажмите, чтобы открыть текущий квест'
            : 'Нажмите, чтобы узнать подробности',
        child: AnimatedBuilder(
          animation: _questPulseController,
          builder: (context, _) {
            final pulseValue = _questPulseController.value;
            final pulse = isArrived ? 1 - (pulseValue * 2 - 1).abs() : 0.0;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hoveredNodeId = node.id),
              onExit: (_) {
                if (_hoveredNodeId == node.id) {
                  setState(() => _hoveredNodeId = null);
                }
              },
              child: GestureDetector(
                key: Key('quest-map-hero-${node.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _selectNode(node),
                child: _QuestMarker(
                  node: node,
                  state: state,
                  pulse: pulse,
                  occupied: isArrived,
                  emphasized: isSelected || isHovered,
                  sourceScale: sourceScale,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuestPrompt(
    QuestMapNode node,
    double mapWidth,
    double mapHeight,
  ) {
    final state = _stateFor(node);
    final width = math.min(276.0, math.max(220.0, mapWidth * 0.54));
    final nodeX = node.nodeCenter.dx * mapWidth;
    final sceneX = node.sceneEffectAnchor.dx * mapWidth;
    final rawLeft = sceneX >= nodeX ? nodeX - width - 34 : nodeX + 34;
    final left = rawLeft.clamp(16.0, mapWidth - width - 16).toDouble();
    final pointerOffset = (nodeX - left).clamp(28.0, width - 28).toDouble();
    final placeBelow = node.nodeCenter.dy < 0.14;
    final top = placeBelow
        ? node.nodeCenter.dy * mapHeight + 58
        : node.nodeCenter.dy * mapHeight - 210;
    final reward = _rewardFor(node);
    final isInProgress = _inProgress(node);

    return Positioned(
      key: Key('quest-prompt-${node.id}'),
      left: left,
      top: top.clamp(12.0, mapHeight - 190).toDouble(),
      width: width,
      child: _QuestWorldPrompt(
        node: node,
        state: state,
        rewardAmount: reward,
        isInProgress: isInProgress,
        unlockMessage: _unlockMessage(node),
        pointerOnTop: placeBelow,
        pointerOffset: pointerOffset,
        onDetails: () => _showNodeDetails(node),
        onDismiss: () => setState(() => _selectedNodeId = null),
        onPlay:
            state == QuestMapNodeState.current ||
                state == QuestMapNodeState.completed
            ? () => _launchNode(node)
            : null,
      ),
    );
  }

  Widget _buildMovingCat(double mapWidth, double mapHeight) {
    return AnimatedBuilder(
      animation: Listenable.merge([_catController, _catReactionController]),
      builder: (context, child) {
        final position = _catAnimation?.value ?? _catPosition;
        final walking = _catAnimation != null && _catController.isAnimating;
        final catSize = (mapWidth * (walking ? 0.18 : 0.19))
            .clamp(walking ? 74.0 : 82.0, 112.0)
            .toDouble();
        final gait = walking
            ? math.sin(_catController.value * math.pi * 10)
            : 0.0;
        final reaction = walking
            ? 0.0
            : math.sin(_catReactionController.value * math.pi);
        final lift = walking
            ? gait.abs() * catSize * 0.025
            : reaction * catSize * 0.055;
        final tilt = walking
            ? gait * 0.018
            : math.sin(_catReactionController.value * math.pi * 2) * 0.018;
        return Positioned(
          key: const Key('quest-map-cat'),
          left: position.dx * mapWidth - catSize / 2,
          top: position.dy * mapHeight - catSize - lift,
          width: catSize,
          height: catSize,
          child: IgnorePointer(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateY(_catFacesRight ? 0 : math.pi)
                ..rotateZ(tilt),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    bottom: catSize * 0.012,
                    child: Container(
                      width: catSize * (walking ? 0.54 : 0.48),
                      height: catSize * 0.08,
                      decoration: BoxDecoration(
                        color: const Color(0x73342A23),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x4D342A23),
                            blurRadius: 5,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: catSize * 0.028),
                    child: Image.asset(
                      walking
                          ? catWalkingAsset(furOptionId: _furOptionId)
                          : catMapIdleAsset(furOptionId: _furOptionId),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

extension on QuestMapNodeState {
  String get semanticLabel => switch (this) {
    QuestMapNodeState.completed => 'Пройдено',
    QuestMapNodeState.current => 'Текущий квест',
    QuestMapNodeState.locked => 'Пока закрыто',
    QuestMapNodeState.comingSoon => 'Глава в разработке',
  };
}

class _QuestSceneHighlight extends StatelessWidget {
  const _QuestSceneHighlight({required this.effect, required this.pulse});

  final QuestSceneEffect effect;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final color = switch (effect) {
      QuestSceneEffect.turnipGlow => const Color(0xFFFFD55B),
      QuestSceneEffect.lensGlint => const Color(0xFFE6F5FF),
      QuestSceneEffect.compassGlint => const Color(0xFFFFC84B),
      QuestSceneEffect.waterGlint => const Color(0xFFFFD975),
      QuestSceneEffect.fireflies => const Color(0xFFFFD45C),
      QuestSceneEffect.ovenLight => const Color(0xFFFFA43B),
      QuestSceneEffect.coinGlint => const Color(0xFFFFD65B),
      QuestSceneEffect.jarGlint => const Color(0xFFFFD76D),
    };
    final opacity = 0.18 + pulse * 0.22;

    if (effect == QuestSceneEffect.fireflies) {
      return Stack(
        children: [
          _FireflyDot(
            alignment: const Alignment(-0.72, -0.18),
            color: color,
            opacity: opacity,
          ),
          _FireflyDot(
            alignment: const Alignment(0.12, -0.72),
            color: color,
            opacity: 0.16 + pulse * 0.28,
          ),
          _FireflyDot(
            alignment: const Alignment(0.70, 0.12),
            color: color,
            opacity: 0.22 + pulse * 0.18,
          ),
          _FireflyDot(
            alignment: const Alignment(-0.08, 0.66),
            color: color,
            opacity: 0.14 + pulse * 0.24,
          ),
        ],
      );
    }

    final hasSparkle = switch (effect) {
      QuestSceneEffect.lensGlint ||
      QuestSceneEffect.compassGlint ||
      QuestSceneEffect.coinGlint ||
      QuestSceneEffect.jarGlint => true,
      _ => false,
    };

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: opacity),
                  color.withValues(alpha: opacity * 0.32),
                  Colors.transparent,
                ],
                stops: const [0, 0.34, 1],
              ),
            ),
          ),
        ),
        if (hasSparkle)
          Transform.scale(
            scale: 0.82 + pulse * 0.24,
            child: Opacity(
              opacity: 0.14 + pulse * 0.64,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: color,
                shadows: [Shadow(color: color, blurRadius: 4 + pulse * 4)],
              ),
            ),
          ),
      ],
    );
  }
}

class _FireflyDot extends StatelessWidget {
  const _FireflyDot({
    required this.alignment,
    required this.color,
    required this.opacity,
  });

  final Alignment alignment;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: color.withValues(alpha: opacity.clamp(0.0, 1.0).toDouble()),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: opacity * 0.76),
              blurRadius: 7,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestMarker extends StatelessWidget {
  const _QuestMarker({
    required this.node,
    required this.state,
    required this.pulse,
    required this.occupied,
    required this.emphasized,
    required this.sourceScale,
  });

  final QuestMapNode node;
  final QuestMapNodeState state;
  final double pulse;
  final bool occupied;
  final bool emphasized;
  final double sourceScale;

  @override
  Widget build(BuildContext context) {
    final locked =
        state == QuestMapNodeState.locked ||
        state == QuestMapNodeState.comingSoon;
    final current = state == QuestMapNodeState.current;
    final completed = state == QuestMapNodeState.completed;
    final markerWidth = occupied
        ? math.max(92.0, 168.0 * sourceScale)
        : switch (state) {
            QuestMapNodeState.current => math.max(76.0, 136.0 * sourceScale),
            QuestMapNodeState.completed => math.max(70.0, 120.0 * sourceScale),
            QuestMapNodeState.locked ||
            QuestMapNodeState.comingSoon => math.max(62.0, 108.0 * sourceScale),
          };
    final markerHeight = markerWidth / 1.9;
    final numberSize = occupied
        ? 20.0
        : switch (state) {
            QuestMapNodeState.current => 19.0,
            QuestMapNodeState.completed => 18.0,
            QuestMapNodeState.locked || QuestMapNodeState.comingSoon => 17.0,
          };
    final stateIconSize = occupied
        ? 19.0
        : current
        ? 18.0
        : completed
        ? 17.0
        : 16.0;
    final scale = emphasized ? 1.035 : 1.0;
    final numberColor = switch (state) {
      QuestMapNodeState.current => const Color(0xFF6D320A),
      QuestMapNodeState.completed => const Color(0xFF214F34),
      QuestMapNodeState.locked ||
      QuestMapNodeState.comingSoon => const Color(0xFF5F584F),
    };
    final statusIcon = switch (state) {
      QuestMapNodeState.current => Icons.play_arrow_rounded,
      QuestMapNodeState.completed => Icons.check_rounded,
      QuestMapNodeState.locked ||
      QuestMapNodeState.comingSoon => Icons.lock_rounded,
    };
    final statusLabel = switch (state) {
      QuestMapNodeState.current => 'Текущий квест',
      QuestMapNodeState.completed => 'Пройдено',
      QuestMapNodeState.locked || QuestMapNodeState.comingSoon => 'Закрыто',
    };
    final statusColor = switch (state) {
      QuestMapNodeState.current => const Color(0xFFA94A1F),
      QuestMapNodeState.completed => const Color(0xFF2F6B45),
      QuestMapNodeState.locked ||
      QuestMapNodeState.comingSoon => const Color(0xFF554E46),
    };

    return AnimatedScale(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      scale: scale,
      child: Center(
        child: SizedBox(
          width: markerWidth,
          height: markerHeight,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (occupied || current)
                Container(
                  width: markerWidth * (occupied ? 0.92 : 0.78),
                  height: markerHeight * (occupied ? 0.66 : 0.48),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFC84B).withValues(
                          alpha: occupied
                              ? 0.52 + pulse * 0.18
                              : 0.30 + pulse * 0.08,
                        ),
                        blurRadius: occupied ? 8 + pulse * 4 : 5 + pulse * 2,
                        spreadRadius: occupied ? 2.0 : 1.0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: markerWidth,
                height: markerHeight,
                child: Opacity(
                  opacity: locked
                      ? 0.76
                      : completed
                      ? 0.94
                      : 1,
                  child: Image.asset(
                    'assets/map/checkpoint_road_v2.webp',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    color: locked ? const Color(0x22554E46) : null,
                    colorBlendMode: locked ? BlendMode.multiply : null,
                  ),
                ),
              ),
              if (!occupied) ...[
                Positioned(
                  child: Transform.translate(
                    offset: Offset(-markerWidth * 0.07, -markerHeight * 0.03),
                    child: MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: const TextScaler.linear(1)),
                      child: Text(
                        '${node.order}',
                        style: TextStyle(
                          fontFamily: AppFonts.body,
                          color: numberColor,
                          fontWeight: FontWeight.bold,
                          fontSize: numberSize,
                          height: 1,
                          shadows: const [
                            Shadow(color: Color(0xE6FFF8E9), blurRadius: 2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: markerWidth * 0.12,
                  top: (markerHeight - stateIconSize) / 2,
                  child: Semantics(
                    label: statusLabel,
                    child: Icon(
                      statusIcon,
                      size: stateIconSize,
                      color: statusColor,
                      shadows: const [
                        Shadow(color: Color(0xE6FFF8E9), blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestWorldPrompt extends StatelessWidget {
  const _QuestWorldPrompt({
    required this.node,
    required this.state,
    required this.rewardAmount,
    required this.isInProgress,
    required this.unlockMessage,
    required this.pointerOnTop,
    required this.pointerOffset,
    required this.onDetails,
    required this.onDismiss,
    required this.onPlay,
  });

  final QuestMapNode node;
  final QuestMapNodeState state;
  final int? rewardAmount;
  final bool isInProgress;
  final String unlockMessage;
  final bool pointerOnTop;
  final double pointerOffset;
  final VoidCallback onDetails;
  final VoidCallback onDismiss;
  final VoidCallback? onPlay;

  String get _message => switch (state) {
    QuestMapNodeState.current =>
      isInProgress ? 'Продолжи приключение.' : 'Новое приключение уже ждёт.',
    QuestMapNodeState.completed =>
      'Можно пройти ещё раз для тренировки — без повторной награды.',
    QuestMapNodeState.locked => unlockMessage,
    QuestMapNodeState.comingSoon =>
      'Глава в разработке. Скоро здесь появится новая история.',
  };

  String get _actionLabel => switch (state) {
    QuestMapNodeState.completed => 'Играть ещё раз',
    QuestMapNodeState.current => isInProgress ? 'Продолжить' : 'Начать',
    QuestMapNodeState.locked || QuestMapNodeState.comingSoon => '',
  };

  @override
  Widget build(BuildContext context) {
    final reward = rewardAmount;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.94, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: value, child: child),
      ),
      child: Semantics(
        liveRegion: true,
        container: true,
        label: '${node.title}. $_message',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: AppColors.cardBg,
              elevation: 8,
              shadowColor: const Color(0x663B2F27),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: state == QuestMapNodeState.current
                        ? const Color(0xFFD99B28)
                        : AppColors.fieldBorder,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            node.title,
                            style: const TextStyle(
                              fontFamily: AppFonts.body,
                              color: AppColors.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.15,
                            ),
                          ),
                        ),
                        IconButton(
                          key: Key('details-${node.id}'),
                          tooltip: 'Подробнее',
                          onPressed: onDetails,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                          ),
                        ),
                        IconButton(
                          key: Key('dismiss-prompt-${node.id}'),
                          tooltip: 'Закрыть',
                          onPressed: onDismiss,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded, size: 21),
                        ),
                      ],
                    ),
                    Text(
                      _message,
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        color: AppColors.inkMuted,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                    if (state == QuestMapNodeState.current &&
                        reward != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Image.asset(
                            'assets/icons/coin.webp',
                            width: 22,
                            height: 22,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              '$reward монет за прохождение',
                              style: const TextStyle(
                                fontFamily: AppFonts.body,
                                color: AppColors.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (onPlay != null) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        key: Key('play-${node.id}'),
                        onPressed: onPlay,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.crimson,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          _actionLabel,
                          style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              left: pointerOffset - 7,
              top: pointerOnTop ? -7 : null,
              bottom: pointerOnTop ? null : -7,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    border: Border(
                      left: BorderSide(
                        color: state == QuestMapNodeState.current
                            ? const Color(0xFFD99B28)
                            : AppColors.fieldBorder,
                      ),
                      top: BorderSide(
                        color: state == QuestMapNodeState.current
                            ? const Color(0xFFD99B28)
                            : AppColors.fieldBorder,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapScrollBehavior extends MaterialScrollBehavior {
  const _MapScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.onBack, required this.progressLabel});

  final VoidCallback? onBack;
  final String progressLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBg,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 9, 16, 9),
        child: Row(
          children: [
            if (onBack case final back?) ...[
              IconButton(
                tooltip: 'Назад',
                onPressed: back,
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppColors.ink,
              ),
              const SizedBox(width: 4),
            ] else
              const SizedBox(width: 12),
            Expanded(
              child: Text(
                MediaQuery.sizeOf(context).width < 360
                    ? 'Карта'
                    : 'Карта приключений',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  color: AppColors.ink,
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.parchment,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: 1.2),
                ),
                child: Text(
                  progressLabel,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    color: AppColors.crimson,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapStatusBanner extends StatelessWidget {
  const _MapStatusBanner({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: color.withValues(alpha: 0.10),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppFonts.body,
                color: AppColors.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    ),
  );
}

class _MapProgressOverlay extends StatelessWidget {
  const _MapProgressOverlay.loading() : isLoading = true, onRetry = null;

  const _MapProgressOverlay.error({required this.onRetry}) : isLoading = false;

  final bool isLoading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.parchment.withValues(alpha: 0.88),
    child: Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const CircularProgressIndicator()
            else
              const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.crimson,
                size: 34,
              ),
            const SizedBox(height: 14),
            Text(
              isLoading
                  ? 'Загружаем прогресс…'
                  : 'Не удалось загрузить прогресс карты',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppFonts.body,
                color: AppColors.ink,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            if (!isLoading) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                key: const Key('retry-map-progress'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _TopicPill extends StatelessWidget {
  const _TopicPill({required this.topic});

  final String topic;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Тема: $topic',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.parchment,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Text(
          topic,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            color: AppColors.ink,
          ),
        ),
      ),
    ),
  );
}

class _QuestDetailsSheet extends StatelessWidget {
  const _QuestDetailsSheet({
    required this.node,
    required this.state,
    required this.unlockMessage,
    required this.rewardAmount,
    required this.isInProgress,
    this.parkStatus,
  });

  final QuestMapNode node;
  final QuestMapNodeState state;
  final String unlockMessage;
  final int? rewardAmount;
  final bool isInProgress;

  /// Current step of the Барсук park story, when known.
  final String? parkStatus;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final completed = state == QuestMapNodeState.completed;
    final current = state == QuestMapNodeState.current;
    final locked = state == QuestMapNodeState.locked;
    final comingSoon = state == QuestMapNodeState.comingSoon;
    final reward = rewardAmount;
    final statusColor = completed
        ? AppColors.leafGreen
        : current
        ? const Color(0xFFD58B12)
        : AppColors.inkMuted;
    final statusIcon = completed
        ? Icons.check_rounded
        : current
        ? Icons.play_arrow_rounded
        : comingSoon
        ? Icons.construction_rounded
        : Icons.lock_rounded;
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 620,
            maxHeight: screenHeight * 0.62,
          ),
          child: Material(
            color: AppColors.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.fieldBorder,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(statusIcon, color: Colors.white, size: 25),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              node.title,
                              style: const TextStyle(
                                fontFamily: AppFonts.body,
                                color: AppColors.ink,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                            Text(
                              node.character,
                              style: const TextStyle(
                                fontFamily: AppFonts.body,
                                color: AppColors.crimson,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    node.description,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      color: AppColors.ink,
                      fontSize: 16,
                      height: 1.35,
                    ),
                  ),
                  if (parkStatus case final status?) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        key: const Key('park-status'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.infoBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.coinGold),
                        ),
                        child: Text(status, style: AppTextStyles.cardRowLabel),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final topic in node.topics) _TopicPill(topic: topic),
                    ],
                  ),
                  if (node.isPlayable && reward != null) ...[
                    const SizedBox(height: 14),
                    Semantics(
                      label: completed
                          ? 'Награда $reward монет уже получена'
                          : 'Награда за прохождение $reward монет',
                      child: ExcludeSemantics(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4C8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE7A51F)),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/icons/coin.webp',
                                width: 28,
                                height: 28,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  completed
                                      ? '$reward монет уже получено · повтор без награды'
                                      : '$reward монет за прохождение',
                                  style: const TextStyle(
                                    fontFamily: AppFonts.body,
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (node.isPlayable && (current || completed))
                    ElevatedButton.icon(
                      key: Key('play-${node.id}'),
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.crimson,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        completed
                            ? 'Играть ещё раз'
                            : isInProgress
                            ? 'Продолжить'
                            : 'Начать',
                        style: const TextStyle(
                          fontFamily: AppFonts.body,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.parchment,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.fieldBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            locked
                                ? Icons.lock_rounded
                                : Icons.construction_rounded,
                            color: AppColors.inkMuted,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              locked ? unlockMessage : 'Глава в разработке',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: AppFonts.body,
                                color: AppColors.inkMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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
}
