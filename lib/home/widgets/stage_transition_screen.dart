import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum StageTransitionType { newDay, petEvolution, homeEvolution }

const double _transitionSeconds = 4.6;
const double _flashStart = 0.8 / _transitionSeconds;
const double _flashPeakStart = 2.2 / _transitionSeconds;
const double _artworkSwitch = 2.45 / _transitionSeconds;
const double _flashPeakEnd = 2.7 / _transitionSeconds;
const double _revealEnd = 4 / _transitionSeconds;
const _artworkAlignment = Alignment(0, -0.28);

/// Full-screen celebration shown between game days or progression stages.
///
/// The economy mutation must happen before this route opens. This widget only
/// presents the result, so replaying an animation can never award coins twice.
class StageTransitionScreen extends StatefulWidget {
  const StageTransitionScreen({
    super.key,
    required this.beforeArtwork,
    required this.afterArtwork,
    required this.onCompleted,
    this.type = StageTransitionType.petEvolution,
    this.dailyIncome = 30,
    this.insuranceActive = false,
    this.title,
    this.message,
    this.onFanfare,
  });

  final Widget beforeArtwork;
  final Widget afterArtwork;
  final VoidCallback onCompleted;
  final StageTransitionType type;

  /// Current source-of-truth value. Prefer passing the backend value if this
  /// rule becomes dynamic.
  final int dailyIncome;
  final bool insuranceActive;
  final String? title;
  final String? message;

  /// Called once when the new artwork starts to appear. The host can connect its own
  /// sound service without coupling this reusable screen to an audio package.
  final VoidCallback? onFanfare;

  @override
  State<StageTransitionScreen> createState() => _StageTransitionScreenState();
}

class _StageTransitionScreenState extends State<StageTransitionScreen>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 4600);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  )..addListener(_handleTimeline);

  bool _started = false;
  bool _fanfarePlayed = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_started) {
      final motionChanged = reduceMotion != _reduceMotion;
      _reduceMotion = reduceMotion;
      if (motionChanged) _controller.value = 1;
      return;
    }
    _started = true;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _controller.duration = const Duration(milliseconds: 600);
    }
    _controller.forward();
  }

  void _handleTimeline() {
    final revealAt = _reduceMotion ? 0.5 : _flashPeakEnd;
    if (!_fanfarePlayed && _controller.value >= revealAt) {
      _fanfarePlayed = true;
      widget.onFanfare?.call();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTimeline)
      ..dispose();
    super.dispose();
  }

  String get _title =>
      widget.title ??
      switch (widget.type) {
        StageTransitionType.newDay => 'Доброе утро, Финни!',
        StageTransitionType.petEvolution => 'Поздравляем! Финни повзрослел!',
        StageTransitionType.homeEvolution => 'Домик стал теплее!',
      };

  String get _message =>
      widget.message ??
      switch (widget.type) {
        StageTransitionType.newDay =>
          'Новый игровой день начался. В кошельке +${widget.dailyIncome} монет.',
        StageTransitionType.petEvolution =>
          'Новая ступень взросления открывает путь к новым квестам!',
        StageTransitionType.homeEvolution => 'Три дня разумного бюджета превратили лесной шалаш в расписной терем!',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10241D),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          final reduceMotion = _reduceMotion;
          final focus = reduceMotion
              ? 1.0
              : Curves.easeOut.transform(_interval(progress, 0, _flashStart));
          final card = reduceMotion
              ? _interval(progress, 0.5, 1)
              : Curves.easeOutBack.transform(
                  _interval(progress, _revealEnd, 1),
                );

          return Semantics(
            label: 'Праздничный переход. $_title',
            liveRegion: progress == 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.type == StageTransitionType.petEvolution)
                  Image.asset(
                    'assets/backgrounds/home_room.webp',
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  )
                else
                  CustomPaint(
                    painter: _DawnPainter(
                      progress: widget.type == StageTransitionType.newDay
                          ? progress
                          : 0.72,
                    ),
                  ),
                BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 5 * focus,
                    sigmaY: 5 * focus,
                  ),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.18 * focus),
                  ),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final artSize = math.min(
                        constraints.maxWidth * 0.72,
                        constraints.maxHeight * 0.47,
                      );
                      final artCenter = _artworkAlignment
                          .inscribe(
                            Size.square(artSize),
                            Offset.zero & constraints.biggest,
                          )
                          .center;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Align(
                            alignment: _artworkAlignment,
                            child: SizedBox.square(
                              dimension: artSize,
                              child: _TransformationArtwork(
                                progress: progress,
                                reduceMotion: reduceMotion,
                                beforeArtwork: widget.beforeArtwork,
                                afterArtwork: widget.afterArtwork,
                              ),
                            ),
                          ),
                          if (!reduceMotion && progress < _revealEnd)
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _MagicStarsPainter(
                                  progress: progress,
                                  center: artCenter,
                                  artworkSize: artSize,
                                ),
                              ),
                            ),
                          if (card > 0)
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  reduceMotion ? 0 : 38 * (1 - card),
                                ),
                                child: Opacity(
                                  opacity: card.clamp(0, 1),
                                  child: _RewardCard(
                                    title: _title,
                                    message: _message,
                                    showDayDetails:
                                        widget.type ==
                                        StageTransitionType.newDay,
                                    dailyIncome: widget.dailyIncome,
                                    insuranceActive: widget.insuranceActive,
                                    onCompleted: widget.onCompleted,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

double _interval(double value, double begin, double end) {
  return ((value - begin) / (end - begin)).clamp(0, 1);
}

class _TransformationArtwork extends StatelessWidget {
  const _TransformationArtwork({
    required this.progress,
    required this.reduceMotion,
    required this.beforeArtwork,
    required this.afterArtwork,
  });

  final double progress;
  final bool reduceMotion;
  final Widget beforeArtwork;
  final Widget afterArtwork;

  @override
  Widget build(BuildContext context) {
    final flashRise = Curves.easeInCubic.transform(
      _interval(progress, _flashStart, _flashPeakStart),
    );
    final flashFall = Curves.easeOutCubic.transform(
      _interval(progress, _flashPeakEnd, _revealEnd),
    );
    final flashOpacity = reduceMotion
        ? 0.0
        : progress < _flashPeakEnd
        ? flashRise
        : 1 - flashFall;
    final switchProgress = reduceMotion
        ? Curves.easeInOut.transform(progress)
        : progress >= _artworkSwitch
        ? 1.0
        : 0.0;
    final reveal = Curves.easeOut.transform(
      _interval(progress, _flashPeakEnd, _revealEnd),
    );
    final afterScale = reveal < 0.65
        ? 0.96 + (0.07 * reveal / 0.65)
        : 1.03 - (0.03 * (reveal - 0.65) / 0.35);
    final flashScale = 0.18 + 1.27 * Curves.easeOutCubic.transform(flashRise);

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        Opacity(
          key: const Key('stage-transition-before'),
          opacity: 1 - switchProgress,
          child: IgnorePointer(
            child: ExcludeSemantics(
              excluding: switchProgress >= 0.5,
              child: beforeArtwork,
            ),
          ),
        ),
        Opacity(
          key: const Key('stage-transition-after'),
          opacity: switchProgress,
          child: IgnorePointer(
            child: ExcludeSemantics(
              excluding: switchProgress < 0.5,
              child: Transform.scale(
                scale: reduceMotion ? 1 : afterScale,
                child: afterArtwork,
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: Opacity(
            key: const Key('stage-transition-flash'),
            opacity: flashOpacity.clamp(0, 1),
            child: Transform.scale(
              scale: flashScale,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.92),
                      blurRadius: 54,
                      spreadRadius: 24,
                    ),
                    BoxShadow(
                      color: AppTheme.gold.withValues(alpha: 0.34),
                      blurRadius: 82,
                      spreadRadius: 34,
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

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.title,
    required this.message,
    required this.showDayDetails,
    required this.dailyIncome,
    required this.insuranceActive,
    required this.onCompleted,
  });

  final String title;
  final String message;
  final bool showDayDetails;
  final int dailyIncome;
  final bool insuranceActive;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Material(
          color: AppTheme.parchment,
          elevation: 14,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(24),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: AppTheme.forestGreen,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.story.copyWith(fontSize: 16),
                ),
                if (showDayDetails) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusChip(
                        icon: Icons.monetization_on_rounded,
                        label: '+$dailyIncome монет',
                      ),
                      _StatusChip(
                        icon: insuranceActive
                            ? Icons.health_and_safety_rounded
                            : Icons.eco_rounded,
                        label: insuranceActive
                            ? 'Подорожник защищает'
                            : 'Подорожник проверен',
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onCompleted,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      backgroundColor: AppTheme.forestGreen,
                      foregroundColor: Colors.white,
                      textStyle: AppTextStyles.button.copyWith(fontSize: 16),
                    ),
                    child: const Text(
                      'Вперёд, к новым открытиям!',
                      textAlign: TextAlign.center,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppTheme.gold),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.swatchLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _DawnPainter extends CustomPainter {
  const _DawnPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final dawn = Curves.easeInOut.transform(progress.clamp(0, 1));
    final top = Color.lerp(
      const Color(0xFF071B30),
      const Color(0xFF8FD3E8),
      dawn,
    )!;
    final bottom = Color.lerp(
      const Color(0xFF18352A),
      const Color(0xFFFFD78C),
      dawn,
    )!;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(Offset.zero & size),
    );

    final sunCenter = Offset(
      size.width * 0.78,
      size.height * (0.62 - dawn * 0.34),
    );
    canvas.drawCircle(
      sunCenter,
      30 + 12 * dawn,
      Paint()..color = const Color(0xFFFFE3A1).withValues(alpha: dawn),
    );

    final forest = Path()..moveTo(0, size.height);
    for (var index = 0; index <= 12; index++) {
      final x = size.width * index / 12;
      final peak = size.height * (0.54 + 0.1 * math.sin(index * 2.1));
      forest
        ..lineTo(x, peak)
        ..lineTo(x + size.width / 24, size.height * 0.74);
    }
    forest
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      forest,
      Paint()..color = AppTheme.forestGreen.withValues(alpha: 0.86),
    );
  }

  @override
  bool shouldRepaint(_DawnPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MagicStarsPainter extends CustomPainter {
  const _MagicStarsPainter({
    required this.progress,
    required this.center,
    required this.artworkSize,
  });

  final double progress;
  final Offset center;
  final double artworkSize;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = artworkSize / 260;
    final entrance = Curves.easeOut.transform(
      _interval(progress, 0, _flashStart),
    );
    final gather = Curves.easeInOut.transform(
      _interval(progress, 0, _flashPeakStart),
    );
    final burst = Curves.easeOutCubic.transform(
      _interval(progress, _flashPeakEnd, _revealEnd),
    );
    final fade = 1 - _interval(progress, 3.55 / _transitionSeconds, _revealEnd);

    for (var index = 0; index < 30; index++) {
      final baseAngle = index / 30 * math.pi * 2;
      final gatheredRadius = 46.0 + (index % 4) * 7;
      final startingRadius = 128.0 + (index % 6) * 16;
      final endingRadius = 190.0 + (index % 7) * 18;
      final radius = burst > 0
          ? _lerp(gatheredRadius, endingRadius, burst)
          : _lerp(startingRadius, gatheredRadius, gather);
      final angle =
          baseAngle +
          gather * math.pi * 1.35 +
          burst * (index.isEven ? 0.5 : -0.4);
      final point =
          center +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius * 0.68) *
              scale;
      final twinkle =
          0.62 + 0.38 * math.sin(index * 1.7 + progress * math.pi * 9).abs();
      final starRadius = 3.5 + (index % 5) * 0.9;
      final color = index % 3 == 0 ? Colors.white : const Color(0xFFFFD978);

      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle + progress * math.pi * 2);
      canvas.drawPath(
        _starPath(starRadius),
        Paint()..color = color.withValues(alpha: entrance * fade * twinkle),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_MagicStarsPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.center != center ||
      oldDelegate.artworkSize != artworkSize;
}

double _lerp(double begin, double end, double progress) =>
    begin + (end - begin) * progress;

Path _starPath(double radius) {
  final inner = radius * 0.28;
  return Path()
    ..moveTo(0, -radius)
    ..lineTo(inner, -inner)
    ..lineTo(radius, 0)
    ..lineTo(inner, inner)
    ..lineTo(0, radius)
    ..lineTo(-inner, inner)
    ..lineTo(-radius, 0)
    ..lineTo(-inner, -inner)
    ..close();
}
