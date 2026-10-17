import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/pet_assets.dart';
import '../home/models/pet.dart';

/// A resizable storybook mirror. Its caps keep their size as the summary grows,
/// so larger text never stretches the ornament or clips the financial content.
class DaySummaryMirror extends StatelessWidget {
  const DaySummaryMirror({super.key, required this.child, this.pet});

  final Widget child;
  final Pet? pet;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _MirrorShadowPainter(),
    foregroundPainter: const _MirrorFramePainter(),
    child: ClipPath(
      clipper: const _MirrorClipper(),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE3F0ED), Color(0xFFA9C9D1), Color(0xFFD6E6E4)],
            stops: [0, 0.48, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: const _GlassPainter()),
              ),
            ),
            Padding(
              // Keep cards clear of both the inner frame stroke and the feet:
              // the lower 90 pixels belong to the narrowing ornamental cap.
              padding: const EdgeInsets.fromLTRB(36, 54, 36, 90),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PetReflection(pet: pet),
                  const SizedBox(height: 8),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PetReflection extends StatelessWidget {
  const _PetReflection({required this.pet});

  final Pet? pet;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Отражение питомца ${pet?.name ?? 'Грошик'} в зеркале',
    child: ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 650),
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(
          opacity: value * 0.9,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: child,
          ),
        ),
        child: SizedBox(
          height: 142,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 155,
                height: 136,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xAAFFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0, 0.65, 1],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: 200,
                    child: Transform.flip(
                      flipX: true,
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Color(0x2473A8BD),
                          BlendMode.srcATop,
                        ),
                        child: Image.asset(
                          pet?.assetPath ?? kBaseCatAsset,
                          key: const Key('day-summary-pet-reflection'),
                          height: 200,
                          width: 160,
                          fit: BoxFit.contain,
                          alignment: Alignment.topCenter,
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
    ),
  );
}

// Each side has a shoulder, a small outward lobe and a curved foot. Most of
// the height belongs to straight sides to keep the two columns readable.
Path _mirrorPath(Size size) {
  final w = size.width;
  final h = size.height;
  return Path()
    ..moveTo(w * 0.5, 5)
    ..cubicTo(w * 0.55, 25, w * 0.61, 5, w * 0.64, 31)
    ..cubicTo(w * 0.69, 22, w * 0.72, 34, w * 0.73, 43)
    ..cubicTo(w * 0.88, 38, w - 8, 63, w - 17, 102)
    ..cubicTo(w - 3, 114, w - 3, 135, w - 13, 151)
    ..cubicTo(w - 19, 190, w - 13, h - 134, w - 15, h - 105)
    ..cubicTo(w - 3, h - 82, w - 12, h - 65, w - 27, h - 66)
    ..cubicTo(w - 21, h - 30, w * 0.69, h - 36, w * 0.62, h - 28)
    ..cubicTo(w * 0.57, h - 25, w * 0.57, h - 10, w * 0.5, h - 5)
    ..cubicTo(w * 0.43, h - 10, w * 0.43, h - 25, w * 0.38, h - 28)
    ..cubicTo(w * 0.31, h - 36, 21, h - 30, 27, h - 66)
    ..cubicTo(12, h - 65, 3, h - 82, 15, h - 105)
    ..cubicTo(13, h - 134, 19, 190, 13, 151)
    ..cubicTo(3, 135, 3, 114, 17, 102)
    ..cubicTo(8, 63, w * 0.12, 38, w * 0.27, 43)
    ..cubicTo(w * 0.28, 34, w * 0.31, 22, w * 0.36, 31)
    ..cubicTo(w * 0.39, 5, w * 0.45, 25, w * 0.5, 5)
    ..close();
}

class _MirrorClipper extends CustomClipper<Path> {
  const _MirrorClipper();

  @override
  Path getClip(Size size) => _mirrorPath(size);

  @override
  bool shouldReclip(_MirrorClipper oldClipper) => false;
}

class _MirrorShadowPainter extends CustomPainter {
  const _MirrorShadowPainter();

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawShadow(_mirrorPath(size), const Color(0x664E351B), 10, false);

  @override
  bool shouldRepaint(_MirrorShadowPainter oldDelegate) => false;
}

class _MirrorFramePainter extends CustomPainter {
  const _MirrorFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = _mirrorPath(size);
    final bounds = Offset.zero & size;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..color = const Color(0xFF90642D),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE9A8),
            Color(0xFFBC843A),
            Color(0xFFF4D68C),
            Color(0xFFA76E2A),
            Color(0xFFEAC67E),
          ],
          stops: [0, 0.28, 0.48, 0.76, 1],
        ).createShader(bounds),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFEABD),
    );
    // Small engravings sit inside the caps, clear of the live content.
    final engraving = Paint()
      ..color = const Color(0xFFB98948)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final bottom in [false, true]) {
      canvas.save();
      canvas.translate(size.width / 2, bottom ? size.height - 30 : 32);
      if (bottom) canvas.scale(1, -1);
      final scroll = Path()
        ..moveTo(-30, 5)
        ..cubicTo(-15, 10, -10, -7, 0, -10)
        ..cubicTo(10, -7, 15, 10, 30, 5);
      canvas.drawPath(scroll, engraving);
      canvas.drawOval(
        const Rect.fromLTWH(-3, -5, 6, 10),
        Paint()..color = const Color(0xFFA4773C),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_MirrorFramePainter oldDelegate) => false;
}

class _GlassPainter extends CustomPainter {
  const _GlassPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Wide translucent streaks read as glass without a costly backdrop blur.
    canvas.save();
    canvas.translate(size.width * 0.18, 0);
    canvas.rotate(math.pi / 7);
    canvas.drawRect(
      Rect.fromLTWH(0, -size.height * 0.2, 24, size.height * 1.4),
      Paint()..color = const Color(0x24FFFFFF),
    );
    canvas.drawRect(
      Rect.fromLTWH(35, -size.height * 0.2, 7, size.height * 1.4),
      Paint()..color = const Color(0x30FFFFFF),
    );
    canvas.restore();

    for (final (x, y, radius) in [
      (0.21, 0.17, 6.0),
      (0.79, 0.24, 8.0),
      (0.73, 0.12, 3.5),
    ]) {
      final center = Offset(size.width * x, size.height * y);
      final sparkle = Path()
        ..moveTo(center.dx, center.dy - radius)
        ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
        ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
        ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
        ..quadraticBezierTo(
          center.dx,
          center.dy,
          center.dx,
          center.dy - radius,
        );
      canvas.drawPath(sparkle, Paint()..color = const Color(0xCFFFFFFF));
    }
  }

  @override
  bool shouldRepaint(_GlassPainter oldDelegate) => false;
}
