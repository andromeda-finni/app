import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'quest_map_data.dart';

class QuestMapScreen extends StatefulWidget {
  const QuestMapScreen({super.key, this.onOpenQuest});

  /// Allows the map to stay independent from game modules that may live on
  /// another feature branch. The host app can connect destinations later.
  final ValueChanged<QuestMapDestination>? onOpenQuest;

  @override
  State<QuestMapScreen> createState() => _QuestMapScreenState();
}

class _QuestMapScreenState extends State<QuestMapScreen>
    with TickerProviderStateMixin {
  static const _mapAsset = 'assets/map/quest_map_scenarios_v03.png';
  static const _catAsset = 'assets/Cat/Base/playful.png';
  static const _sourceWidth = 821.0;
  static const _sourceHeight = 1915.0;

  final _scrollController = ScrollController();
  late final AnimationController _catController = AnimationController(
    vsync: this,
  )..addListener(_followCat);
  late final AnimationController _questPulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 880),
  );

  Animation<Offset>? _catAnimation;
  Offset _catPosition = questMapPath.first;
  int _currentPathIndex = 0;
  int _movementVersion = 0;
  double _renderedMapHeight = 0;
  double _viewportHeight = 0;
  String? _hoveredNodeId;
  String? _selectedNodeId;
  String? _arrivedNodeId;
  bool _catFacesRight = true;
  bool _didJumpToStart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToStart());
  }

  @override
  void dispose() {
    _catController.dispose();
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
    _scrollController.jumpTo(maxExtent);
  }

  void _followCat() {
    final animation = _catAnimation;
    if (animation == null || !_scrollController.hasClients) return;

    final mapY = animation.value.dy * _renderedMapHeight;
    final desiredOffset = (mapY - _viewportHeight * 0.56)
        .clamp(0.0, _scrollController.position.maxScrollExtent)
        .toDouble();
    if ((_scrollController.offset - desiredOffset).abs() > 0.75) {
      _scrollController.jumpTo(desiredOffset);
    }
  }

  Future<void> _selectNode(QuestMapNode node) async {
    final version = ++_movementVersion;
    final currentPosition = _catAnimation?.value ?? _catPosition;
    _catController.stop();

    final closestIndex = _nearestPathIndex(currentPosition);
    final route = _routeBetween(currentPosition, closestIndex, node.pathIndex);
    final totalDistance = _routeDistance(route);
    final durationMs = (620 + totalDistance * 1900).clamp(620, 2450).round();

    setState(() {
      _selectedNodeId = node.id;
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
    _questPulseController.repeat(reverse: true);

    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (mounted && version == _movementVersion) {
      await _showNode(node);
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

  Future<void> _showNode(QuestMapNode node) async {
    final shouldOpen = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x663B2F27),
      builder: (context) => _QuestDetailsSheet(
        node: node,
        canOpen: widget.onOpenQuest != null,
      ),
    );

    if (shouldOpen != true || !mounted) return;
    final onOpenQuest = widget.onOpenQuest;
    if (onOpenQuest != null) {
      onOpenQuest(node.destination);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Мини-игра готова к подключению к этому квесту.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Column(
          children: [
            _MapHeader(onBack: () => Navigator.of(context).maybePop()),
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

                  return ScrollConfiguration(
                    behavior: const _MapScrollBehavior(),
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      trackVisibility: constraints.maxWidth >= 600,
                      interactive: true,
                      thickness: constraints.maxWidth >= 600 ? 8 : 5,
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
                                  _buildHeroArea(node, mapWidth, mapHeight),
                                _buildMovingCat(mapWidth, mapHeight),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroArea(QuestMapNode node, double mapWidth, double mapHeight) {
    final bounds = node.heroBounds;
    final isHovered = _hoveredNodeId == node.id;
    final isSelected = _selectedNodeId == node.id;
    final isArrived = _arrivedNodeId == node.id;
    final showLabel = isHovered || isSelected;

    return Positioned(
      left: bounds.left / _sourceWidth * mapWidth,
      top: bounds.top / _sourceHeight * mapHeight,
      width: bounds.width / _sourceWidth * mapWidth,
      height: bounds.height / _sourceHeight * mapHeight,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '${node.character}. ${node.title}',
        hint: 'Нажмите, чтобы подойти и узнать о квесте',
        child: AnimatedBuilder(
          animation: _questPulseController,
          builder: (context, _) {
            final pulse = isArrived ? _questPulseController.value : 0.0;
            const gold = Color(0xFFE2A52E);
            final active = isHovered || isSelected;
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
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: gold.withValues(
                            alpha: isSelected
                                ? 0.12 + pulse * 0.05
                                : (isHovered ? 0.09 : 0.025),
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: gold.withValues(
                              alpha: isSelected
                                  ? 0.84 + pulse * 0.14
                                  : (isHovered ? 0.74 : 0.34),
                            ),
                            width: isSelected
                                ? 3.0 + pulse
                                : (isHovered ? 2.6 : 1.5),
                          ),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: gold.withValues(
                                      alpha: 0.20 + pulse * 0.12,
                                    ),
                                    blurRadius: 10 + pulse * 7,
                                    spreadRadius: pulse * 2,
                                  ),
                                ]
                              : const [],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 140),
                            opacity: showLabel ? 1 : 0,
                            child: Transform.translate(
                              offset: const Offset(0, -10),
                              child: _MapNodeLabel(node: node),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMovingCat(double mapWidth, double mapHeight) {
    return AnimatedBuilder(
      animation: _catController,
      builder: (context, child) {
        final position = _catAnimation?.value ?? _catPosition;
        final catSize = (mapWidth * 0.165).clamp(58.0, 116.0).toDouble();
        return Positioned(
          key: const Key('quest-map-kitten'),
          left: position.dx * mapWidth - catSize / 2,
          top: position.dy * mapHeight - catSize * 0.78,
          width: catSize,
          height: catSize,
          child: IgnorePointer(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(_catFacesRight ? 0 : math.pi),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    bottom: 3,
                    child: Container(
                      width: catSize * 0.68,
                      height: catSize * 0.20,
                      decoration: BoxDecoration(
                        color: const Color(0x663B2F27),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Image.asset(
                    _catAsset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
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

class _MapNodeLabel extends StatelessWidget {
  const _MapNodeLabel({required this.node});

  final QuestMapNode node;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE2A52E);
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x443B2F27),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        node.isPlayable && node.showPlayAction
            ? '${node.labelOnMap} · Играть'
            : node.labelOnMap,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppFonts.body,
          color: AppColors.ink,
          fontWeight: FontWeight.bold,
          fontSize: 13,
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
  const _MapHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBg,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 10),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Назад',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: AppColors.ink,
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Карта приключений',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      color: AppColors.ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 21,
                    ),
                  ),
                  Text(
                    'Нажми на героя — путь начинается снизу',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      color: AppColors.inkMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.parchment,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: const Text(
                '2 игры готовы',
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  color: AppColors.leafGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestDetailsSheet extends StatelessWidget {
  const _QuestDetailsSheet({required this.node, required this.canOpen});

  final QuestMapNode node;
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
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
                        decoration: const BoxDecoration(
                          color: AppColors.crimson,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 25,
                        ),
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
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final topic in node.topics)
                        Chip(
                          label: Text(topic),
                          backgroundColor: AppColors.parchment,
                          side: const BorderSide(color: AppColors.fieldBorder),
                          labelStyle: const TextStyle(
                            fontFamily: AppFonts.body,
                            color: AppColors.ink,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (node.isPlayable)
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
                        canOpen ? 'Играть' : 'Подготовлено к подключению',
                        style: TextStyle(
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
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.construction_rounded,
                            color: AppColors.inkMuted,
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Сценарий готов к разработке',
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




