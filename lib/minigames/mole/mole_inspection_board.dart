import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'mole_game_data.dart';

class MoleInspectionBoard extends StatefulWidget {
  const MoleInspectionBoard({
    super.key,
    required this.episode,
    required this.foundHotspots,
    required this.onHotspotFound,
  });

  final MoleEpisode episode;
  final Set<int> foundHotspots;
  final ValueChanged<int> onHotspotFound;

  @override
  State<MoleInspectionBoard> createState() => _MoleInspectionBoardState();
}

class _MoleInspectionBoardState extends State<MoleInspectionBoard> {
  Offset? _lensCenter;
  int? _activeHotspot;

  @override
  void didUpdateWidget(covariant MoleInspectionBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episode.id != widget.episode.id) {
      _lensCenter = null;
      _activeHotspot = null;
    }
  }

  void _moveLens(Offset localPosition, Size size) {
    final center = Offset(
      localPosition.dx.clamp(48, size.width - 48),
      localPosition.dy.clamp(48, size.height - 48),
    );

    int? nearest;
    var nearestDistance = double.infinity;
    for (var i = 0; i < widget.episode.hotspots.length; i++) {
      final point = widget.episode.hotspots[i].position;
      final hotspot = Offset(point.dx * size.width, point.dy * size.height);
      final distance = (hotspot - center).distance;
      if (distance < nearestDistance) {
        nearest = i;
        nearestDistance = distance;
      }
    }

    final hitRadius = math.min(size.width, size.height) * 0.19;
    final active = nearestDistance <= hitRadius ? nearest : null;
    setState(() {
      _lensCenter = center;
      _activeHotspot = active;
    });
    if (active != null && !widget.foundHotspots.contains(active)) {
      widget.onHotspotFound(active);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Область проверки. Найдено ${widget.foundHotspots.length} из ${widget.episode.hotspots.length} деталей.',
      child: AspectRatio(
        aspectRatio: 1.08,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final center =
                _lensCenter ?? Offset(size.width * 0.28, size.height * 0.32);
            return GestureDetector(
              key: const Key('mole-inspection-board'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _moveLens(details.localPosition, size),
              onPanStart: (details) => _moveLens(details.localPosition, size),
              onPanUpdate: (details) => _moveLens(details.localPosition, size),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    Positioned.fill(child: _Document(episode: widget.episode)),
                    for (var i = 0; i < widget.episode.hotspots.length; i++)
                      if (widget.foundHotspots.contains(i))
                        _FoundMarker(
                          left: widget.episode.hotspots[i].position.dx * size.width - 12,
                          top: widget.episode.hotspots[i].position.dy * size.height - 12,
                          label: widget.episode.hotspots[i].label,
                        ),
                    Positioned(
                      left: center.dx - 54,
                      top: center.dy - 54,
                      child: IgnorePointer(
                        child: _Lens(
                          detail: _activeHotspot == null
                              ? null
                              : widget.episode.hotspots[_activeHotspot!],
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
}

class _Document extends StatelessWidget {
  const _Document({required this.episode});

  final MoleEpisode episode;

  @override
  Widget build(BuildContext context) {
    if (episode.boardKind == MoleBoardKind.advertisement) {
      return DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFBBD6A4)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(MoleAssets.scroll, fit: BoxFit.contain),
            Padding(
              padding: const EdgeInsets.fromLTRB(58, 48, 58, 52),
              child: Column(
                children: [
                  Text(
                    episode.boardTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    episode.boardSubtitle,
                    style: AppTextStyles.counterValue.copyWith(
                      color: AppColors.crimson,
                      fontSize: 20,
                    ),
                  ),
                  Expanded(
                    child: Image.asset(episode.itemAsset, fit: BoxFit.contain),
                  ),
                  Text(
                    'Подробные условия напечатаны внизу',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.swatchLabel.copyWith(
                      color: AppColors.ink.withValues(alpha: 0.20),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF8EFD9)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 24, 26, 18),
        child: Column(
          children: [
            Text(
              episode.boardTitle,
              style: AppTextStyles.cardTitle.copyWith(fontSize: 21),
            ),
            Text(episode.boardSubtitle, style: AppTextStyles.swatchLabel),
            const Divider(height: 22, color: AppColors.fieldBorder),
            for (var i = 0; i < episode.receiptLines.length; i++) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      episode.receiptLines[i].label,
                      style: AppTextStyles.cardRowLabel.copyWith(
                        fontSize: i == episode.receiptLines.length - 1 ? 17 : 14,
                        fontWeight: i == episode.receiptLines.length - 1
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    '${episode.receiptLines[i].amount}',
                    style: AppTextStyles.counterValue.copyWith(fontSize: 15),
                  ),
                  const SizedBox(width: 4),
                  Image.asset('assets/icons/coin.png', width: 17, height: 17),
                ],
              ),
              if (i != episode.receiptLines.length - 1)
                const Divider(height: 12, color: Color(0xFFDFD1B9)),
            ],
            const Spacer(),
            Text(
              'Спасибо за покупку',
              style: AppTextStyles.swatchLabel.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _Lens extends StatelessWidget {
  const _Lens({required this.detail});

  final MoleHotspot? detail;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          Container(
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFFCED),
              border: Border.all(color: const Color(0xFFB78122), width: 4),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 9, offset: Offset(0, 4)),
              ],
            ),
            child: Center(
              child: Text(
                detail?.detail ?? 'Ищи\nмелкий\nтекст',
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.fade,
                style: AppTextStyles.swatchLabel.copyWith(
                  color: detail == null ? AppColors.inkMuted : AppColors.ink,
                  fontSize: detail == null ? 11 : 9,
                  height: 1.05,
                  fontWeight: detail == null ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Image.asset(MoleAssets.magnifier, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _FoundMarker extends StatelessWidget {
  const _FoundMarker({required this.left, required this.top, required this.label});

  final double left;
  final double top;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Semantics(
        label: label,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.leafGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 17),
        ),
      ),
    );
  }
}
