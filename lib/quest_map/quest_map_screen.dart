import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/pet_assets.dart';
import '../minigames/mole/mole_game_screen.dart';
import '../minigames/tugriki/tugriki_game_screen.dart';
import '../theme/app_theme.dart';
import 'quest_map_data.dart';

class QuestMapScreen extends StatefulWidget {
  const QuestMapScreen({
    super.key,
    this.apiClient,
    this.initialUnlockedIndex = 1,
    this.showBack = true,
  });

  final ApiClient? apiClient;

  /// False when the map is a tab root and there is nowhere to go back to.
  final bool showBack;

  /// Starting position before server progress arrives, and the only position
  /// when there is no [apiClient] (previews and widget tests).
  final int initialUnlockedIndex;

  @override
  State<QuestMapScreen> createState() => _QuestMapScreenState();
}

class _QuestMapScreenState extends State<QuestMapScreen>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController = ScrollController();
  late final AnimationController _journeyController =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1450),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _revealComplete = true);
        }
      });

  late int _unlockedIndex;
  // Neutral until the server answers: the child names the pet themselves.
  String _petName = 'Питомец';
  String? _furOptionId;
  bool _motionStarted = false;
  bool _revealComplete = false;

  @override
  void initState() {
    super.initState();
    _unlockedIndex = widget.initialUnlockedIndex
        .clamp(0, questMapNodes.length - 1)
        .toInt();
    if (widget.apiClient != null) _loadProgress();
  }

  /// Progress lives on the server as completed quest assignments, so it
  /// survives restarts and matches the rewards actually paid.
  Future<void> _loadProgress() async {
    try {
      final economy = await widget.apiClient!.get('/economy/state');
      final completed = <String>{
        for (final quest in (economy['quests'] as List? ?? const []))
          if (quest is Map && quest['assignment_status'] == 'COMPLETED')
            quest['id'] as String,
      };
      final pet = economy['pet'] as Map?;
      final name = pet?['pet_name'];
      final fur = pet?['fur_option_id'];
      if (!mounted) return;
      setState(() {
        _unlockedIndex = unlockedIndexFor(completed);
        if (name is String && name.trim().isNotEmpty) _petName = name;
        if (fur is String) _furOptionId = fur;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    } on ApiException {
      // The map still works from its starting position; each game reports its
      // own connection problems when the child actually plays.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionStarted) return;
    _motionStarted = true;

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _journeyController.value = 1;
      _revealComplete = true;
    } else {
      _journeyController.forward();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void dispose() {
    _journeyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;
    final viewport = _scrollController.position.viewportDimension;
    final nodeY = questMapNodes[_unlockedIndex].y;
    final target = (nodeY - viewport * 0.48)
        .clamp(0.0, _scrollController.position.maxScrollExtent)
        .toDouble();
    _scrollController.jumpTo(target);
  }

  Future<void> _openQuest(QuestMapNodeData node) async {
    final canPlay = node.id == 'mole' || node.id == 'tugriki';
    final shouldPlay = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.fieldBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(node.emoji, style: const TextStyle(fontSize: 42)),
              const SizedBox(height: 8),
              Text(
                node.title,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                node.location,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 15,
                  color: AppColors.crimson,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                node.description,
                style: AppTextStyles.story.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 20),
              if (canPlay)
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.crimson,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    'Играть',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.fieldBorder),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Сценарий готов · мини-игра появится позже',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: AppFonts.body, fontSize: 15),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || shouldPlay != true) return;

    if (node.id == 'mole') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MoleGameScreen(apiClient: widget.apiClient),
        ),
      );
    } else if (node.id == 'tugriki') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (gameContext) => TugrikiGameScreen(
            apiClient: widget.apiClient,
            petName: _petName,
            onExit: () => Navigator.of(gameContext).pop(),
          ),
        ),
      );
    }
    // A finished game may have completed its quest and opened the next node.
    if (mounted && widget.apiClient != null) await _loadProgress();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCDE7F1),
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final mapWidth = math.min(constraints.maxWidth, 560.0);
                return SingleChildScrollView(
                  key: const Key('quest-map-scroll'),
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Center(
                    child: SizedBox(
                      width: mapWidth,
                      height: kQuestMapHeight,
                      child: AnimatedBuilder(
                        animation: _journeyController,
                        builder: (context, _) {
                          final animationValue = _journeyController.value;
                          final journeyValue = Curves.easeInOutCubic.transform(
                            (animationValue / 0.68).clamp(0.0, 1.0).toDouble(),
                          );
                          final revealValue = Curves.easeOut.transform(
                            ((animationValue - 0.68) / 0.32)
                                .clamp(0.0, 1.0)
                                .toDouble(),
                          );

                          return _QuestMapCanvas(
                            width: mapWidth,
                            unlockedIndex: _unlockedIndex,
                            petName: _petName,
                            // The walker on the path is the child's own pet,
                            // in the coat they picked during onboarding.
                            heroAsset: catAsset(furOptionId: _furOptionId),
                            journeyValue: journeyValue,
                            revealValue: revealValue,
                            revealComplete: _revealComplete,
                            onNodeTap: _openQuest,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _MapHeader(
              openedCount: _unlockedIndex + 1,
              totalCount: questMapNodes.length,
              onBack: widget.showBack
                  ? () => Navigator.of(context).maybePop()
                  : null,
            ),
          ),
          Positioned(
            right: 16,
            bottom: 18 + MediaQuery.paddingOf(context).bottom,
            child: _ScrollHint(
              onPressed: _scrollToCurrent,
              label: questMapNodes[_unlockedIndex].title,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestMapCanvas extends StatelessWidget {
  const _QuestMapCanvas({
    required this.width,
    required this.unlockedIndex,
    required this.petName,
    required this.heroAsset,
    required this.journeyValue,
    required this.revealValue,
    required this.revealComplete,
    required this.onNodeTap,
  });

  final double width;
  final int unlockedIndex;
  final String petName;
  final String heroAsset;
  final double journeyValue;
  final double revealValue;
  final bool revealComplete;
  final ValueChanged<QuestMapNodeData> onNodeTap;

  Offset _point(QuestMapNodeData node) => Offset(node.x * width, node.y);

  @override
  Widget build(BuildContext context) {
    final previousIndex = unlockedIndex > 0 ? unlockedIndex - 1 : 0;
    final heroPoint = Offset.lerp(
      _point(questMapNodes[previousIndex]),
      _point(questMapNodes[unlockedIndex]),
      journeyValue,
    )!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _MapLandscapePainter(
              nodes: questMapNodes.map(_point).toList(),
              unlockedIndex: unlockedIndex,
            ),
          ),
        ),
        for (var i = 0; i < questMapNodes.length; i++)
          _positionNode(
            i,
            cloudFade: i == unlockedIndex
                ? (revealComplete ? 0.0 : 1 - revealValue)
                : null,
          ),
        Positioned(
          left: (heroPoint.dx - 34).clamp(6.0, width - 74).toDouble(),
          top: heroPoint.dy + 76,
          child: IgnorePointer(
            child: Semantics(
              label:
                  '$petName идёт к заданию ${questMapNodes[unlockedIndex].title}',
              image: true,
              child: Container(
                key: const Key('quest-map-hero'),
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Color(0xEFFFF8E9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 9,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(heroAsset, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _positionNode(int index, {double? cloudFade}) {
    final node = questMapNodes[index];
    final state = questMapNodeState(index, unlockedIndex);
    final left = (node.x * width - 66).clamp(8.0, width - 140).toDouble();
    final isCurrentRevealing = index == unlockedIndex && !revealComplete;

    return Positioned(
      left: left,
      top: node.y - 66,
      child: _QuestMapNode(
        key: Key('quest-map-node-${node.id}'),
        node: node,
        state: state,
        cloudOpacity: cloudFade ?? (state == QuestMapNodeState.locked ? 1 : 0),
        enabled: state != QuestMapNodeState.locked && !isCurrentRevealing,
        onTap: () => onNodeTap(node),
      ),
    );
  }
}

class _QuestMapNode extends StatelessWidget {
  const _QuestMapNode({
    super.key,
    required this.node,
    required this.state,
    required this.cloudOpacity,
    required this.enabled,
    required this.onTap,
  });

  final QuestMapNodeData node;
  final QuestMapNodeState state;
  final double cloudOpacity;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = state == QuestMapNodeState.completed;
    final current = state == QuestMapNodeState.current;
    final statusText = switch (state) {
      QuestMapNodeState.completed => 'пройдено',
      QuestMapNodeState.current => 'доступно',
      QuestMapNodeState.locked => 'закрыто облаками',
    };

    return Semantics(
      button: enabled,
      enabled: enabled,
      label: '${node.title}, ${node.location}, $statusText',
      child: SizedBox(
        width: 132,
        height: 148,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              child: Material(
                color: Colors.transparent,
                child: InkResponse(
                  key: Key('quest-map-action-${node.id}'),
                  onTap: enabled ? onTap : null,
                  radius: 48,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: current
                          ? const Color(0xFFFFE3A1)
                          : completed
                          ? const Color(0xFFE6F0D9)
                          : const Color(0xFFE2DFD5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: current
                            ? AppColors.crimson
                            : completed
                            ? AppColors.leafGreen
                            : AppColors.inkMuted,
                        width: current ? 4 : 2.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: node.assetPath == null
                        ? Text(
                            node.emoji,
                            style: TextStyle(
                              fontSize: 38,
                              color: state == QuestMapNodeState.locked
                                  ? Colors.black38
                                  : null,
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(8),
                            child: Image.asset(
                              node.assetPath!,
                              fit: BoxFit.contain,
                              opacity: state == QuestMapNodeState.locked
                                  ? const AlwaysStoppedAnimation(0.42)
                                  : null,
                            ),
                          ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 76,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xF7FFF8E9),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.fieldBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x24000000),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  node.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 15,
                    height: 1.05,
                    fontWeight: FontWeight.bold,
                    color: state == QuestMapNodeState.locked
                        ? AppColors.inkMuted
                        : AppColors.ink,
                  ),
                ),
              ),
            ),
            if (completed)
              const Positioned(
                right: 16,
                top: -2,
                child: _StatusMedallion(
                  icon: Icons.check_rounded,
                  color: AppColors.leafGreen,
                ),
              ),
            if (current)
              const Positioned(
                right: 12,
                top: -4,
                child: _StatusMedallion(
                  icon: Icons.star_rounded,
                  color: AppColors.crimson,
                ),
              ),
            Positioned(
              left: -24,
              right: -24,
              top: -16,
              height: 116,
              child: IgnorePointer(
                ignoring: cloudOpacity < 0.95,
                child: Opacity(
                  key: Key('quest-map-cloud-${node.id}'),
                  opacity: cloudOpacity.clamp(0.0, 1.0).toDouble(),
                  child: _CloudCover(
                    showLock: state == QuestMapNodeState.locked,
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

class _StatusMedallion extends StatelessWidget {
  const _StatusMedallion({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, color: Colors.white, size: 19),
    );
  }
}

class _CloudCover extends StatelessWidget {
  const _CloudCover({required this.showLock});

  final bool showLock;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: CustomPaint(painter: _CloudPainter())),
        if (showLock)
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xCC5C5149),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
      ],
    );
  }
}

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = const Color(0x24000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final cloud = Paint()..color = const Color(0xF2FFFDF7);
    final edge = Paint()
      ..color = const Color(0xFFD7D3C9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final centers = <Offset>[
      Offset(size.width * 0.18, size.height * 0.61),
      Offset(size.width * 0.34, size.height * 0.43),
      Offset(size.width * 0.52, size.height * 0.54),
      Offset(size.width * 0.68, size.height * 0.38),
      Offset(size.width * 0.84, size.height * 0.60),
    ];
    final radii = <double>[31, 39, 42, 35, 29];

    for (var i = 0; i < centers.length; i++) {
      canvas.drawCircle(centers[i] + const Offset(0, 5), radii[i], shadow);
    }
    for (var i = 0; i < centers.length; i++) {
      canvas.drawCircle(centers[i], radii[i], cloud);
      canvas.drawCircle(centers[i], radii[i], edge);
    }
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) => false;
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({
    required this.openedCount,
    required this.totalCount,
    required this.onBack,
  });

  final int openedCount;
  final int totalCount;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xF4FFF8E9),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.fieldBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2B000000),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    tooltip: 'Назад',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.ink,
                  )
                else
                  const SizedBox(width: 12),
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
                          fontSize: 21,
                          height: 1,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Поднимайся по тропе и открывай новые истории',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.body,
                          fontSize: 12,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.crimson,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '$openedCount / $totalCount',
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrollHint extends StatelessWidget {
  const _ScrollHint({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Вернуться к текущему заданию $label',
      child: FloatingActionButton.small(
        heroTag: 'quest-map-current',
        tooltip: 'Текущее задание: $label',
        onPressed: onPressed,
        backgroundColor: AppColors.crimson,
        foregroundColor: Colors.white,
        child: const Icon(Icons.my_location_rounded),
      ),
    );
  }
}

class _MapLandscapePainter extends CustomPainter {
  const _MapLandscapePainter({
    required this.nodes,
    required this.unlockedIndex,
  });

  final List<Offset> nodes;
  final int unlockedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFBDE2F2), Color(0xFFDDF0D4), Color(0xFF8FC36A)],
        stops: [0, 0.48, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    _paintHills(canvas, size);
    _paintRiver(canvas, size);
    _paintRoute(canvas);
    _paintTrees(canvas, size);
    _paintLandmarks(canvas, size);
  }

  void _paintHills(Canvas canvas, Size size) {
    final far = Paint()..color = const Color(0xFF8EBC75);
    final near = Paint()..color = const Color(0xFF72A956);
    final farPath = Path()
      ..moveTo(0, 430)
      ..quadraticBezierTo(size.width * 0.30, 250, size.width * 0.56, 420)
      ..quadraticBezierTo(size.width * 0.78, 540, size.width, 360)
      ..lineTo(size.width, 820)
      ..lineTo(0, 820)
      ..close();
    canvas.drawPath(farPath, far);

    final nearPath = Path()
      ..moveTo(0, 690)
      ..quadraticBezierTo(size.width * 0.28, 520, size.width * 0.52, 720)
      ..quadraticBezierTo(size.width * 0.75, 850, size.width, 640)
      ..lineTo(size.width, 1180)
      ..lineTo(0, 1180)
      ..close();
    canvas.drawPath(nearPath, near);
  }

  void _paintRiver(Canvas canvas, Size size) {
    final river = Path()
      ..moveTo(size.width * 0.92, 1060)
      ..cubicTo(
        size.width * 0.48,
        1170,
        size.width * 0.75,
        1450,
        size.width * 0.10,
        1510,
      )
      ..cubicTo(
        size.width * 0.55,
        1570,
        size.width * 0.42,
        1770,
        size.width * 0.98,
        1840,
      );
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xAA8DD7E8)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(34.0, size.width * 0.10),
    );
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0x99E7FAFF)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4,
    );
  }

  void _paintRoute(Canvas canvas) {
    final route = Path()..moveTo(nodes.first.dx, nodes.first.dy);
    for (var i = 1; i < nodes.length; i++) {
      final previous = nodes[i - 1];
      final next = nodes[i];
      final middleY = (previous.dy + next.dy) / 2;
      route.cubicTo(previous.dx, middleY, next.dx, middleY, next.dx, next.dy);
    }

    canvas.drawPath(
      route,
      Paint()
        ..color = const Color(0xFFE9C88E)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 22,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = const Color(0xFFC99758)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2,
    );

    if (unlockedIndex > 0) {
      final opened = Path()..moveTo(nodes.first.dx, nodes.first.dy);
      for (var i = 1; i <= unlockedIndex; i++) {
        final previous = nodes[i - 1];
        final next = nodes[i];
        final middleY = (previous.dy + next.dy) / 2;
        opened.cubicTo(
          previous.dx,
          middleY,
          next.dx,
          middleY,
          next.dx,
          next.dy,
        );
      }
      canvas.drawPath(
        opened,
        Paint()
          ..color = const Color(0xBFA3271F)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 5,
      );
    }
  }

  void _paintTrees(Canvas canvas, Size size) {
    final trunk = Paint()..color = const Color(0xFF7B5835);
    final crown = Paint()..color = const Color(0xFF3F783D);
    final crownLight = Paint()..color = const Color(0xFF5F934C);
    for (var i = 0; i < 34; i++) {
      final side = i.isEven ? 0.06 : 0.90;
      final jitter = ((i * 37) % 9) / 100;
      final x = size.width * (side + (i.isEven ? jitter : -jitter));
      final y = 130.0 + i * 63;
      final scale = 0.72 + (i % 4) * 0.08;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, y + 19 * scale),
          width: 7 * scale,
          height: 30 * scale,
        ),
        trunk,
      );
      canvas.drawCircle(Offset(x, y), 22 * scale, crown);
      canvas.drawCircle(
        Offset(x - 9 * scale, y - 9 * scale),
        15 * scale,
        crownLight,
      );
    }
  }

  void _paintLandmarks(Canvas canvas, Size size) {
    final building = Paint()..color = const Color(0xFFE3A65F);
    final roof = Paint()..color = const Color(0xFF9B3E2E);
    final dark = Paint()..color = const Color(0xFF594439);
    for (final point in [
      Offset(size.width * 0.80, 2165),
      Offset(size.width * 0.17, 1885),
      Offset(size.width * 0.82, 835),
      Offset(size.width * 0.18, 575),
      Offset(size.width * 0.18, 300),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: point, width: 62, height: 48),
          const Radius.circular(7),
        ),
        building,
      );
      final roofPath = Path()
        ..moveTo(point.dx - 39, point.dy - 22)
        ..lineTo(point.dx, point.dy - 55)
        ..lineTo(point.dx + 39, point.dy - 22)
        ..close();
      canvas.drawPath(roofPath, roof);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(point.dx, point.dy + 10),
          width: 14,
          height: 28,
        ),
        dark,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapLandscapePainter oldDelegate) =>
      oldDelegate.unlockedIndex != unlockedIndex;
}
