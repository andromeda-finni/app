import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A continuous UI surface, not a tall bitmap with tiny text. The original
/// parchment supplies grain; a world-space outline moves with the document.
class InfinitePaper extends StatefulWidget {
  const InfinitePaper({
    super.key,
    required this.controller,
    required this.child,
  });
  final ScrollController controller;
  final Widget child;

  @override
  State<InfinitePaper> createState() => _InfinitePaperState();
}

class _InfinitePaperState extends State<InfinitePaper> {
  ui.Image? _texture;

  @override
  void initState() {
    super.initState();
    _loadTexture();
  }

  Future<void> _loadTexture() async {
    try {
      final bytes = await rootBundle.load(
        'assets/dictionary/dictionary-scroll.png',
      );
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _texture = frame.image);
    } catch (_) {
      // The painted paper remains readable if an illustration cannot load.
    }
  }

  @override
  void dispose() {
    _texture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedBuilder(
      animation: widget.controller,
      child: widget.child,
      builder: (context, child) => CustomPaint(
        painter: _PaperPainter(
          offset: widget.controller.hasClients ? widget.controller.offset : 0,
          texture: _texture,
        ),
        child: child,
      ),
    ),
  );
}

class _PaperPainter extends CustomPainter {
  const _PaperPainter({required this.offset, required this.texture});
  final double offset;
  final ui.Image? texture;

  double _edge(double y, double phase) =>
      math.sin((y + offset + phase) / 57) * 2.6 +
      math.sin((y + offset + phase) / 17) * 1.1;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()..moveTo(13 + _edge(-24, 0), -24);
    for (double y = -24; y <= size.height + 32; y += 8) {
      outline.lineTo(13 + _edge(y, 0), y);
    }
    for (double y = size.height + 32; y >= -24; y -= 8) {
      outline.lineTo(size.width - 13 + _edge(y, 140), y);
    }
    outline.close();
    canvas.drawShadow(outline, const Color(0x663C2510), 12, false);
    canvas.drawPath(
      outline,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFE2BC7F),
            Color(0xFFF7E5BE),
            Color(0xFFFBECCF),
            Color(0xFFE6C691),
          ],
          stops: [0, 0.10, 0.86, 1],
        ).createShader(Offset.zero & size),
    );
    canvas.save();
    canvas.clipPath(outline);
    final image = texture;
    if (image != null) {
      // Crop only the blank interior at paint time: the finite artwork's top
      // and bottom rolls never get repeated inside the endless ribbon.
      final source = Rect.fromLTRB(
        image.width * 0.24,
        image.height * 0.20,
        image.width * 0.80,
        image.height * 0.77,
      );
      final drift = (offset % 500) * 0.12;
      canvas.drawImageRect(
        image,
        source,
        Rect.fromLTWH(0, -160 - drift, size.width, size.height + 380),
        Paint()..color = const Color(0xBFFFFFFF),
      );
    }
    canvas.restore();
    canvas.drawPath(
      outline,
      Paint()
        ..color = const Color(0xFF987246)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawPath(
      outline,
      Paint()
        ..color = const Color(0x3380542A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant _PaperPainter oldDelegate) =>
      oldDelegate.offset != offset || oldDelegate.texture != texture;
}
