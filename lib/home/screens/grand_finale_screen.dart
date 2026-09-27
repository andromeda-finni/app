import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/app_theme.dart';

typedef DiplomaShareCallback = Future<void> Function(Uint8List pngBytes);

/// The campaign ending and exportable financial-literacy diploma.
class GrandFinaleScreen extends StatefulWidget {
  const GrandFinaleScreen({
    super.key,
    required this.childName,
    required this.petName,
    required this.earnedCoins,
    required this.onFreePlay,
    this.goalName = 'Сапоги-скороходы',
    this.vigilancePercent = 100,
    this.daysOnPlan = 7,
    this.safetyBufferHelped = true,
    this.onShareDiploma,
  });

  final String childName;
  final String petName;
  final int earnedCoins;
  final String goalName;
  final int vigilancePercent;
  final int daysOnPlan;
  final bool safetyBufferHelped;
  final VoidCallback onFreePlay;

  /// Optional seam for tests or a host-specific share service. If omitted,
  /// the platform share sheet is opened with the generated PNG.
  final DiplomaShareCallback? onShareDiploma;

  @override
  State<GrandFinaleScreen> createState() => _GrandFinaleScreenState();
}

class _GrandFinaleScreenState extends State<GrandFinaleScreen> {
  final GlobalKey _diplomaKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareDiploma() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context)
        .clamp(1.5, 3.0)
        .toDouble();
    final renderBox = context.findRenderObject() as RenderBox?;
    final shareOrigin = renderBox == null
        ? null
        : renderBox.localToGlobal(Offset.zero) & renderBox.size;

    try {
      final diplomaContext = _diplomaKey.currentContext;
      if (diplomaContext == null) {
        throw StateError('Diploma is not mounted.');
      }
      await Scrollable.ensureVisible(
        diplomaContext,
        alignment: 0.08,
        duration: Duration.zero,
      );
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _diplomaKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw StateError('Diploma is not ready for capture.');
      }
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('Diploma PNG encoding failed.');
      }
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      final callback = widget.onShareDiploma;
      if (callback != null) {
        await callback(bytes);
      } else {
        await SharePlus.instance.share(
          ShareParams(
            title: 'Диплом финансовой грамотности',
            text: 'Диплом юного мастера ${widget.childName}',
            files: [XFile.fromData(bytes, mimeType: 'image/png')],
            fileNameOverrides: const ['diplom-finansovoy-gramotnosti.png'],
            sharePositionOrigin: shareOrigin,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Не удалось подготовить диплом. Попробуй ещё раз.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.forestGreen,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF173E2B), Color(0xFFF5E6C8)],
            stops: [0, 0.74],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              children: [
                const _TriumphHeader(),
                const SizedBox(height: 24),
                RepaintBoundary(
                  key: _diplomaKey,
                  child: _Diploma(
                    childName: widget.childName,
                    petName: widget.petName,
                    earnedCoins: widget.earnedCoins,
                    goalName: widget.goalName,
                    vigilancePercent: widget.vigilancePercent,
                    daysOnPlan: widget.daysOnPlan,
                    safetyBufferHelped: widget.safetyBufferHelped,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _FinaleActions(
        sharing: _sharing,
        onShare: _shareDiploma,
        onFreePlay: widget.onFreePlay,
      ),
    );
  }
}

class _TriumphHeader extends StatelessWidget {
  const _TriumphHeader();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Триумф! Ты открыл путь в Тридесятое Царство!',
      child: Column(
        children: [
          const _GoldenGateScene(),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'ТРИУМФ!',
              style: AppTextStyles.screenTitle.copyWith(
                color: const Color(0xFFFFDE84),
                fontSize: 44,
                letterSpacing: 3,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 12,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ты открыл путь в Тридесятое Царство!',
            textAlign: TextAlign.center,
            style: AppTextStyles.cardTitle.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text(
              'Продолжение — в следующих обновлениях. Следите за новостями!',
              textAlign: TextAlign.center,
            ),
            style: OutlinedButton.styleFrom(
              disabledForegroundColor: const Color(0xFFFFE5A6),
              side: const BorderSide(color: Color(0x99FFE5A6)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldenGateScene extends StatelessWidget {
  const _GoldenGateScene();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AspectRatio(
          aspectRatio: 1.75,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _GoldenGatePainter()),
              ),
              Image.asset(
                'assets/Cat/Base/playful.png',
                fit: BoxFit.contain,
                height: 190,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.pets_rounded,
                  color: Colors.white,
                  size: 120,
                ),
              ),
              const Positioned(
                bottom: 3,
                left: 0,
                right: 0,
                child: _GoldenBoots(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoldenBoots extends StatelessWidget {
  const _GoldenBoots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        2,
        (index) => Transform.rotate(
          angle: index == 0 ? -0.16 : 0.16,
          child: Container(
            width: 26,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD65C),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(9),
                topRight: Radius.circular(9),
                bottomRight: Radius.circular(12),
              ),
              border: Border.all(color: const Color(0xFF9D6813), width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0xAAFFD65C), blurRadius: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Diploma extends StatelessWidget {
  const _Diploma({
    required this.childName,
    required this.petName,
    required this.earnedCoins,
    required this.goalName,
    required this.vigilancePercent,
    required this.daysOnPlan,
    required this.safetyBufferHelped,
  });

  final String childName;
  final String petName;
  final int earnedCoins;
  final String goalName;
  final int vigilancePercent;
  final int daysOnPlan;
  final bool safetyBufferHelped;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Цифровой диплом финансовой грамотности для $childName',
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: AppTheme.gold,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFF7E2028),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
            decoration: BoxDecoration(
              color: AppTheme.parchment,
              borderRadius: BorderRadius.circular(17),
              image: const DecorationImage(
                image: AssetImage('assets/backgrounds/paper.png'),
                fit: BoxFit.cover,
                opacity: 0.23,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppTheme.gold,
                  size: 42,
                ),
                Text(
                  'ЦИФРОВОЙ ДИПЛОМ',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.screenTitle.copyWith(
                    color: const Color(0xFF7E2028),
                    letterSpacing: 1.4,
                  ),
                ),
                Text(
                  'Паспорт финансовой грамотности',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.supporting.copyWith(
                    color: AppTheme.forestGreen,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Награждается юный мастер $childName\n'
                  'и верный друг $petName',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.story.copyWith(fontSize: 19),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.gold),
                  ),
                  child: Text(
                    'Мастер Лесной Казны 1-й степени',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: AppTheme.forestGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _Achievement(
                  icon: '🪙',
                  title: 'Честно заработано',
                  value: '$earnedCoins монет в лесных квестах.',
                ),
                _Achievement(
                  icon: '🎯',
                  title: 'Главная цель',
                  value: '$goalName получены без долгов!',
                ),
                _Achievement(
                  icon: '🦊',
                  title: 'Бдительность',
                  value: '$vigilancePercent% уловок Хитрого Лиса распознано.',
                ),
                _Achievement(
                  icon: '🛡️',
                  title: 'Защита',
                  value: safetyBufferHelped
                      ? 'Подушка безопасности спасла здоровье питомца.'
                      : 'Подушка безопасности собрана на будущие приключения.',
                ),
                _Achievement(
                  icon: '📜',
                  title: 'Дисциплина',
                  value: '$daysOnPlan дней успешного следования плану.',
                ),
                const SizedBox(height: 14),
                const _DepartmentSeal(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Achievement extends StatelessWidget {
  const _Achievement({
    required this.icon,
    required this.title,
    required this.value,
  });

  final String icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppTextStyles.story.copyWith(
                  fontSize: 15.5,
                  height: 1.35,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DepartmentSeal extends StatelessWidget {
  const _DepartmentSeal();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Гербовая печать Департамента финансов города Москвы',
      child: Container(
        width: 104,
        height: 104,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF9E2731),
          border: Border.all(color: const Color(0xFF6F1720), width: 3),
          boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 7)],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_rounded,
              color: Color(0xFFFFE5B0),
              size: 30,
            ),
            SizedBox(height: 3),
            Text(
              'ДЕПФИН\nМОСКВЫ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFFFE5B0),
                fontSize: 10,
                height: 1.1,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinaleActions extends StatelessWidget {
  const _FinaleActions({
    required this.sharing,
    required this.onShare,
    required this.onFreePlay,
  });

  final bool sharing;
  final VoidCallback onShare;
  final VoidCallback onFreePlay;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.parchment,
      elevation: 18,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final share = FilledButton.icon(
              onPressed: sharing ? null : onShare,
              icon: sharing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.ios_share_rounded),
              label: const Text('Поделиться дипломом с родителями'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppTheme.forestGreen,
                foregroundColor: Colors.white,
                textStyle: AppTextStyles.button.copyWith(fontSize: 15),
              ),
            );
            final freePlay = OutlinedButton.icon(
              onPressed: onFreePlay,
              icon: const Icon(Icons.castle_rounded),
              label: const Text('Режим свободной игры / Новая глава'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: AppTheme.forestGreen,
                side: const BorderSide(color: AppTheme.forestGreen),
                textStyle: AppTextStyles.button.copyWith(
                  color: AppTheme.forestGreen,
                  fontSize: 15,
                ),
              ),
            );

            if (constraints.maxWidth >= 700) {
              return Row(
                children: [
                  Expanded(child: share),
                  const SizedBox(width: 12),
                  Expanded(child: freePlay),
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [share, const SizedBox(height: 8), freePlay],
            );
          },
        ),
      ),
    );
  }
}

class _GoldenGatePainter extends CustomPainter {
  const _GoldenGatePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.72);
    final rayPaint = Paint()
      ..color = const Color(0x44FFE09A)
      ..strokeWidth = 5;
    for (var index = 0; index < 18; index++) {
      final angle = index * math.pi * 2 / 18;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(center, center + direction * size.longestSide, rayPaint);
    }

    final gatePaint = Paint()
      ..color = const Color(0xFFFFD66A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13;
    final left = Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.14,
      size.width * 0.34,
      size.height * 0.78,
    );
    final right = Rect.fromLTWH(
      size.width * 0.54,
      size.height * 0.14,
      size.width * 0.34,
      size.height * 0.78,
    );
    canvas.drawArc(left, math.pi, math.pi, false, gatePaint);
    canvas.drawArc(right, math.pi, math.pi, false, gatePaint);
    canvas.drawLine(
      Offset(left.left, size.height),
      Offset(left.left, left.center.dy),
      gatePaint,
    );
    canvas.drawLine(
      Offset(left.right, size.height),
      Offset(left.right, left.center.dy),
      gatePaint,
    );
    canvas.drawLine(
      Offset(right.left, size.height),
      Offset(right.left, right.center.dy),
      gatePaint,
    );
    canvas.drawLine(
      Offset(right.right, size.height),
      Offset(right.right, right.center.dy),
      gatePaint,
    );
  }

  @override
  bool shouldRepaint(_GoldenGatePainter oldDelegate) => false;
}
