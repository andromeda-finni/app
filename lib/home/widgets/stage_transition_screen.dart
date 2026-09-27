import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum StageTransitionType { newDay, petEvolution, homeEvolution }

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

  /// Called once when the confetti burst starts. The host can connect its own
  /// sound service without coupling this reusable screen to an audio package.
  final VoidCallback? onFanfare;

  @override
  State<StageTransitionScreen> createState() => _StageTransitionScreenState();
}

class _StageTransitionScreenState extends State<StageTransitionScreen>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 3400);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  )..addListener(_handleTimeline);

  bool _started = false;
  bool _fanfarePlayed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  void _handleTimeline() {
    if (!_fanfarePlayed && _controller.value >= 2.2 / 3.4) {
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
          final focus = Curves.easeOut.transform(
            _interval(progress, 0, 0.8 / 3.4),
          );
          final magic = _interval(progress, 0.8 / 3.4, 2.2 / 3.4);
          final burst = _interval(progress, 2.2 / 3.4, 3 / 3.4);
          final card = Curves.easeOutBack.transform(
            _interval(progress, 3 / 3.4, 1),
          );

          return Semantics(
            label: 'Праздничный переход. $_title',
            liveRegion: progress == 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
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
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Align(
                            alignment: const Alignment(0, -0.28),
                            child: SizedBox.square(
                              dimension: artSize,
                              child: _TransformationArtwork(
                                progress: progress,
                                beforeArtwork: widget.beforeArtwork,
                                afterArtwork: widget.afterArtwork,
                              ),
                            ),
                          ),
                          if (magic > 0 && magic < 1)
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _MagicSpiralPainter(progress: magic),
                              ),
                            ),
                          if (burst > 0)
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _CelebrationPainter(progress: burst),
                              ),
                            ),
                          if (card > 0)
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Transform.translate(
                                offset: Offset(0, 38 * (1 - card)),
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
    required this.beforeArtwork,
    required this.afterArtwork,
  });

  final double progress;
  final Widget beforeArtwork;
  final Widget afterArtwork;

  @override
  Widget build(BuildContext context) {
    final magic = _interval(progress, 0.8 / 3.4, 2.2 / 3.4);
    final switchProgress = Curves.easeInOut.transform(
      _interval(magic, 0.35, 0.75),
    );
    final lift = math.sin(magic * math.pi);

    return Transform.translate(
      offset: Offset(0, -18 * lift),
      child: Transform.scale(
        scale: 1 + (0.15 * lift),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.34 * lift),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.72 * lift),
                    blurRadius: 44 * lift,
                    spreadRadius: 12 * lift,
                  ),
                ],
              ),
            ),
            Opacity(opacity: 1 - switchProgress, child: beforeArtwork),
            Opacity(opacity: switchProgress, child: afterArtwork),
          ],
        ),
      ),
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
                      'Вперёд, к новым открытиям! 🚀',
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

class _MagicSpiralPainter extends CustomPainter {
  const _MagicSpiralPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.41);
    for (var index = 0; index < 28; index++) {
      final phase = (index / 28 + progress * 1.6) * math.pi * 2;
      final radius = 42 + index * 3.7;
      final squash = 0.48 + 0.12 * math.sin(progress * math.pi);
      final position =
          center +
          Offset(math.cos(phase) * radius, math.sin(phase) * radius * squash);
      final sparkle = 2.5 + (index % 4) * 1.2;
      canvas.drawCircle(
        position,
        sparkle,
        Paint()
          ..color = (index.isEven ? AppTheme.gold : const Color(0xFF65D6A2))
              .withValues(
                alpha: 0.45 + 0.45 * math.sin((index + 1) * 0.7).abs(),
              ),
      );
    }
  }

  @override
  bool shouldRepaint(_MagicSpiralPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _CelebrationPainter extends CustomPainter {
  const _CelebrationPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.4);
    for (var index = 0; index < 42; index++) {
      final angle = (index / 42) * math.pi * 2;
      final speed = 90 + (index % 7) * 23;
      final gravity = 120 * progress * progress;
      final point =
          origin +
          Offset(
            math.cos(angle) * speed * progress,
            math.sin(angle) * speed * progress + gravity,
          );
      final color = switch (index % 3) {
        0 => AppTheme.gold,
        1 => const Color(0xFF6CCB9C),
        _ => const Color(0xFFB72E3C),
      };
      final paint = Paint()
        ..color = color.withValues(alpha: 1 - 0.35 * progress);
      if (index % 5 == 0) {
        canvas.drawCircle(point, 7, paint);
        canvas.drawCircle(point, 4, Paint()..color = const Color(0xFFFFE49A));
      } else {
        canvas.save();
        canvas.translate(point.dx, point.dy);
        canvas.rotate(angle + progress * math.pi * 3);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-3, -7, 6, 14),
            const Radius.circular(2),
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
