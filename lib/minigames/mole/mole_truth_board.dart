import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'mole_truth_models.dart';

/// The document is laid out once per width/text-scale change. Pointer movement
/// repaints only the lens; neither the page nor TextPainters are rebuilt.
class MoleTruthBoard extends StatefulWidget {
  const MoleTruthBoard({
    super.key,
    required this.document,
    required this.exposedIds,
    required this.onInspect,
    required this.onConfirm,
    this.enabled = true,
  });

  final MoleTruthCase document;
  final Set<String> exposedIds;
  final ValueChanged<String?> onInspect;
  final ValueChanged<String> onConfirm;
  final bool enabled;

  @override
  State<MoleTruthBoard> createState() => _MoleTruthBoardState();
}

class _MoleTruthBoardState extends State<MoleTruthBoard>
    with SingleTickerProviderStateMixin {
  final _lens = ValueNotifier<Offset>(Offset.zero);
  late final AnimationController _ink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  _DocumentLayout? _layout;
  String? _hoveredId;
  double _radius = 66;
  bool _reducedMotion = false;
  DateTime? _lastHaptic;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.of(context).disableAnimations;
    if (_reducedMotion) _ink.stop();
  }

  @override
  void dispose() {
    _layout?.dispose();
    _lens.dispose();
    _ink.dispose();
    super.dispose();
  }

  void _move(Offset point) {
    final layout = _layout;
    if (!widget.enabled || layout == null) return;
    _lens.value = Offset(
      point.dx.clamp(_radius * 0.5, layout.width - _radius * 0.5),
      point.dy.clamp(_radius * 0.5, layout.height - _radius * 0.5),
    );
    final slot = layout.at(_lens.value);
    final id = slot?.span.id;
    if (id == _hoveredId) return;
    _hoveredId = id;
    widget.onInspect(id);
    if (slot?.span.isTrick == true && !widget.exposedIds.contains(id)) {
      final now = DateTime.now();
      if (_lastHaptic == null ||
          now.difference(_lastHaptic!) > const Duration(milliseconds: 160)) {
        _lastHaptic = now;
        unawaited(HapticFeedback.selectionClick());
      }
      if (!_reducedMotion) _ink.forward(from: 0);
    } else {
      _ink.stop();
    }
  }

  void _activate(_TruthSlot slot) {
    if (!widget.enabled) return;
    if (_hoveredId != slot.span.id) {
      _move(slot.rect.center);
    } else {
      widget.onConfirm(slot.span.id);
    }
  }

  void _tap(Offset position) {
    if (!widget.enabled) return;
    final center = _lens.value;
    if ((position - center).distance <= _radius - 6) {
      // The truth layer is optically enlarged around the lens center.
      final sourcePoint = center + (position - center) / 1.08;
      final slot = _layout?.at(sourcePoint);
      if (slot != null) {
        _hoveredId = slot.span.id;
        widget.onInspect(slot.span.id);
        widget.onConfirm(slot.span.id);
        return;
      }
    }
    _move(position);
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    _radius = (66 * (scaler.scale(18) / 18).clamp(1, 1.4));
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final previous = _layout;
        if (previous == null ||
            previous.width != width ||
            previous.scaler != scaler ||
            previous.direction != direction ||
            previous.document != widget.document) {
          final next = _DocumentLayout(
            widget.document,
            width,
            scaler,
            direction,
          );
          _layout = next;
          _lens.value = Offset(
            width * 0.40,
            math.min(next.headerHeight + 28, next.height - 40),
          );
          previous?.dispose();
          _hoveredId = null;
        }
        final layout = _layout!;
        return ClipPath(
          clipper: _MolePaperClipper(widget.document.documentKind),
          child: SizedBox(
            key: const Key('mole-truth-board'),
            height: layout.height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _tap(details.localPosition),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _DocumentPainter(layout, widget.exposedIds),
                      ),
                    ),
                  ),
                  if (widget.enabled)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _LensPainter(
                              layout,
                              _lens,
                              _ink,
                              widget.exposedIds,
                              _radius,
                              _reducedMotion,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Painted text retains real, keyboard-focusable semantics.
                  // Enter once examines a clause; Enter again fixes the trick.
                  for (final slot in layout.slots)
                    Positioned.fromRect(
                      rect: slot.rect,
                      child: FocusableActionDetector(
                        enabled: widget.enabled,
                        onFocusChange: (focused) {
                          if (focused) _move(slot.rect.center);
                        },
                        shortcuts: const {
                          SingleActivator(LogicalKeyboardKey.enter):
                              ActivateIntent(),
                          SingleActivator(LogicalKeyboardKey.space):
                              ActivateIntent(),
                        },
                        actions: {
                          ActivateIntent: CallbackAction<ActivateIntent>(
                            onInvoke: (_) {
                              _activate(slot);
                              return null;
                            },
                          ),
                        },
                        child: ValueListenableBuilder<Offset>(
                          valueListenable: _lens,
                          builder: (context, center, child) {
                            final inspected = _hoveredId == slot.span.id;
                            final exposed = widget.exposedIds.contains(
                              slot.span.id,
                            );
                            return Semantics(
                              key: Key('mole-truth-span-${slot.span.id}'),
                              container: true,
                              explicitChildNodes: true,
                              button: widget.enabled,
                              label: exposed || inspected
                                  ? slot.span.truthDescription
                                  : slot.span.printedDescription,
                              value: exposed ? 'Уловка зафиксирована' : null,
                              hint: inspected
                                  ? 'Нажми, чтобы зафиксировать расхождение'
                                  : 'Нажми, чтобы осмотреть строку через линзу',
                              onTap: widget.enabled
                                  ? () => _activate(slot)
                                  : null,
                              child: const SizedBox.expand(),
                            );
                          },
                        ),
                      ),
                    ),
                  // Only the glass captures drag gestures. The rest of the
                  // document remains a normal vertical scrolling surface.
                  if (widget.enabled)
                    ValueListenableBuilder<Offset>(
                      valueListenable: _lens,
                      builder: (context, center, child) => Positioned(
                        left: center.dx - _radius,
                        top: center.dy - _radius,
                        width: _radius * 2,
                        height: _radius * 2,
                        child: ClipOval(
                          key: const Key('mole-truth-lens-drag'),
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanStart: (details) => _move(
                              _lens.value +
                                  details.localPosition -
                                  Offset(_radius, _radius),
                            ),
                            onPanUpdate: (details) =>
                                _move(_lens.value + details.delta),
                            child: const SizedBox.expand(),
                          ),
                        ),
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

class _TruthSlot {
  _TruthSlot(
    this.span,
    this.rect,
    this.printed,
    this.truth,
    this.value,
    this.truthValue,
  );
  final MoleTruthSpan span;
  final Rect rect;
  final TextPainter printed;
  final TextPainter truth;
  final TextPainter value;
  final TextPainter truthValue;

  Offset get origin => Offset(rect.left + 8, rect.top + 8);

  void paint(Canvas canvas, {required bool revealed}) {
    (revealed ? truth : printed).paint(canvas, origin);
    final amount = revealed ? truthValue : value;
    amount.paint(canvas, Offset(rect.right - 8 - amount.width, rect.top + 8));
  }
}

class _DocumentLayout {
  _DocumentLayout(this.document, this.width, this.scaler, this.direction) {
    final available = math.max(1.0, width - 32);
    heading = _text(
      document.documentTitle,
      AppColors.ink,
      available - 16,
      fontSize: 20,
      bold: true,
    );
    brand = _text(
      switch (document.documentKind) {
        MoleTruthDocumentKind.receipt => 'ЛЕСНАЯ ЛАВКА · ЦЕНЫ В МОНЕТАХ',
        MoleTruthDocumentKind.advertisement => 'АКЦИЯ ЛЕСНОЙ ЛАВКИ',
        MoleTruthDocumentKind.contract => 'ЛАВКА ЛИСА · ПЕРЕД ПОДПИСЬЮ',
        MoleTruthDocumentKind.productLabel => 'ПРОВЕРЬ СОСТАВ',
      },
      AppColors.inkMuted,
      available - 16,
      fontSize: 11,
    );
    footer = _text(
      'Спасибо за покупку',
      AppColors.inkMuted,
      available - 16,
      fontSize: 12,
    );
    headerHeight = 20 + brand.height + 8 + heading.height + 18;
    var y = headerHeight;
    for (final line in document.lines) {
      // Each semantic clause gets a stable slot. Reserve the larger of both
      // text heights; revealing longer copy can never push the next line.
      for (final span in line.spans) {
        final hasValue = span.value != null || span.truthValue != null;
        final amountWidth = hasValue ? available * 0.34 : 0.0;
        final labelWidth = available - 16 - amountWidth - (hasValue ? 12 : 0);
        final headline = !isReceipt && slots.isEmpty;
        final printed = _text(
          span.printed,
          AppColors.ink,
          labelWidth,
          fontSize: headline ? 20 : 16,
          bold: headline,
        );
        final truth = _text(
          span.truth ?? span.printed,
          span.isTrick ? AppColors.crimsonDark : AppColors.ink,
          labelWidth,
          fontSize: headline ? 20 : 16,
          bold: headline,
        );
        final value = _text(
          span.value ?? '',
          AppColors.ink,
          math.max(1, amountWidth),
          bold: true,
        );
        final truthValue = _text(
          span.truthValue ?? span.value ?? '',
          span.isTrick ? AppColors.crimsonDark : AppColors.ink,
          math.max(1, amountWidth),
          bold: true,
        );
        final height = math.max(
          48.0,
          [
                printed.height,
                truth.height,
                value.height,
                truthValue.height,
              ].reduce(math.max) +
              16,
        );
        slots.add(
          _TruthSlot(
            span,
            Rect.fromLTWH(16, y, available, height),
            printed,
            truth,
            value,
            truthValue,
          ),
        );
        y += height + 8;
      }
    }
    footerTop = y + 8;
    height = math.max(160, isReceipt ? footerTop + footer.height + 20 : y + 16);
  }

  final MoleTruthCase document;
  final double width;
  final TextScaler scaler;
  final TextDirection direction;
  final List<_TruthSlot> slots = [];
  late final double height;
  late final double headerHeight;
  late final double footerTop;
  late final TextPainter heading;
  late final TextPainter brand;
  late final TextPainter footer;
  bool get isReceipt => document.documentKind == MoleTruthDocumentKind.receipt;
  Color get paperColor => switch (document.documentKind) {
    MoleTruthDocumentKind.receipt => const Color(0xFFF8EFD9),
    MoleTruthDocumentKind.advertisement => const Color(0xFFE5EBCF),
    MoleTruthDocumentKind.contract => const Color(0xFFF4E7CC),
    MoleTruthDocumentKind.productLabel => const Color(0xFFFFF9EB),
  };

  TextPainter _text(
    String text,
    Color color,
    double maxWidth, {
    double fontSize = 16,
    bool bold = false,
  }) => TextPainter(
    text: TextSpan(
      text: text,
      style: AppTextStyles.story.copyWith(
        fontSize: fontSize,
        height: 1.3,
        color: color,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      ),
    ),
    textScaler: scaler,
    textDirection: direction,
  )..layout(maxWidth: maxWidth);

  void paintHeader(Canvas canvas) {
    brand.paint(canvas, Offset((width - brand.width) / 2, 18));
    heading.paint(
      canvas,
      Offset((width - heading.width) / 2, 26 + brand.height),
    );
    if (!isReceipt) return;
    final divider = Paint()
      ..color = AppColors.fieldBorder
      ..strokeWidth = 1;
    for (var x = 24.0; x < width - 24; x += 8) {
      canvas.drawLine(
        Offset(x, headerHeight - 10),
        Offset(math.min(x + 4, width - 24), headerHeight - 10),
        divider,
      );
    }
  }

  void paintFooter(Canvas canvas) {
    if (!isReceipt) return;
    footer.paint(canvas, Offset((width - footer.width) / 2, footerTop));
  }

  _TruthSlot? at(Offset point) {
    for (final slot in slots) {
      if (slot.rect.contains(point)) return slot;
    }
    return null;
  }

  void dispose() {
    heading.dispose();
    brand.dispose();
    footer.dispose();
    for (final slot in slots) {
      slot.printed.dispose();
      slot.truth.dispose();
      slot.value.dispose();
      slot.truthValue.dispose();
    }
  }
}

class _DocumentPainter extends CustomPainter {
  _DocumentPainter(this.layout, this.exposed);
  final _DocumentLayout layout;
  final Set<String> exposed;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = layout.paperColor);
    if (!layout.isReceipt) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(8),
          const Radius.circular(10),
        ),
        Paint()
          ..color = AppColors.fieldBorder
          ..style = PaintingStyle.stroke,
      );
    }
    layout.paintHeader(canvas);
    for (final slot in layout.slots) {
      final found = exposed.contains(slot.span.id);
      if (found) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(slot.rect, const Radius.circular(8)),
          Paint()..color = AppColors.protectionTint,
        );
      }
      slot.paint(canvas, revealed: found);
      if (layout.isReceipt || found) {
        canvas.drawLine(
          Offset(24, slot.rect.bottom + 3),
          Offset(size.width - 24, slot.rect.bottom + 3),
          Paint()
            ..color = found ? AppColors.leafGreen : AppColors.fieldBorder
            ..strokeWidth = found ? 2 : 0.6,
        );
      }
    }
    layout.paintFooter(canvas);
  }

  @override
  bool shouldRepaint(covariant _DocumentPainter oldDelegate) =>
      oldDelegate.layout != layout || !setEquals(oldDelegate.exposed, exposed);
}

class _LensPainter extends CustomPainter {
  _LensPainter(
    this.layout,
    this.lens,
    this.ink,
    this.exposed,
    this.radius,
    this.reducedMotion,
  ) : super(repaint: Listenable.merge([lens, ink]));

  final _DocumentLayout layout;
  final ValueNotifier<Offset> lens;
  final Animation<double> ink;
  final Set<String> exposed;
  final double radius;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final center = lens.value;
    final active = layout.at(center);
    final suspicious =
        active?.span.isTrick == true && !exposed.contains(active?.span.id);
    final circle = Rect.fromCircle(center: center, radius: radius);
    canvas.drawShadow(Path()..addOval(circle), Colors.black26, 5, true);
    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.parchmentLight,
    );
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.08);
    canvas.translate(-center.dx, -center.dy);
    layout.paintHeader(canvas);
    for (final slot in layout.slots) {
      if (!slot.rect.overlaps(circle.inflate(16))) continue;
      if (slot.span.isTrick) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(slot.rect, const Radius.circular(8)),
          Paint()..color = AppColors.goalSurfaceDeep,
        );
      }
      canvas.save();
      if (suspicious && slot == active && !reducedMotion) {
        canvas.translate(math.sin(ink.value * math.pi * 2) * 0.4, 0);
      }
      slot.paint(canvas, revealed: true);
      canvas.restore();
    }
    layout.paintFooter(canvas);
    canvas.restore();
    canvas.drawCircle(
      center,
      radius - 4,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            AppColors.coinGold.withValues(alpha: 0.20),
          ],
          stops: const [0.78, 1],
        ).createShader(circle),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = suspicious ? AppColors.crimson : AppColors.coinGold,
    );
    canvas.drawArc(
      circle.deflate(9),
      -2.5,
      0.8,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final handleStart = center + Offset(radius * 0.70, radius * 0.70);
    final handleEnd = center + Offset(radius * 1.04, radius * 1.04);
    canvas.drawLine(
      handleStart,
      handleEnd,
      Paint()
        ..color = AppColors.inkMuted
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LensPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.radius != radius ||
      oldDelegate.reducedMotion != reducedMotion ||
      !setEquals(oldDelegate.exposed, exposed);
}

class _MolePaperClipper extends CustomClipper<Path> {
  const _MolePaperClipper(this.kind);
  final MoleTruthDocumentKind kind;

  @override
  Path getClip(Size size) {
    if (kind != MoleTruthDocumentKind.receipt) {
      return Path()..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
      );
    }
    final path = Path()..moveTo(0, 6);
    for (var x = 0.0; x < size.width; x += 12) {
      path.lineTo(math.min(x + 6, size.width), 0);
      path.lineTo(math.min(x + 12, size.width), 6);
    }
    path.lineTo(size.width, size.height - 6);
    for (var x = size.width; x > 0; x -= 12) {
      path.lineTo(math.max(x - 6, 0), size.height);
      path.lineTo(math.max(x - 12, 0), size.height - 6);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant _MolePaperClipper oldClipper) =>
      oldClipper.kind != kind;
}
