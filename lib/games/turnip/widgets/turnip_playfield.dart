import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../turnip_game_content.dart';
import '../turnip_game_controller.dart';
import '../turnip_game_models.dart';

class TurnipPlayfield extends StatelessWidget {
  const TurnipPlayfield({
    super.key,
    required this.controller,
    required this.onPlace,
    this.shakeOffset = 0,
  });

  final TurnipGameController controller;
  final ValueChanged<TurnipCharacter> onPlace;
  final double shakeOffset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth.clamp(280.0, 720.0);
        final chainSize = ((contentWidth - 60) / 6).clamp(42.0, 76.0);
        final pieceSize = ((contentWidth - 70) / 5).clamp(48.0, 74.0);

        return DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.canvasWarm),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/games/turnip/garden_background.png',
                fit: BoxFit.cover,
                alignment: const Alignment(-0.25, 0),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.45, 1],
                    colors: [
                      Color(0x55FFF9EF),
                      Colors.transparent,
                      Color(0x99000000),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  children: [
                    _TaskCard(controller: controller),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      child: controller.lastRejectedCharacter != null
                          ? _FeedbackCard(
                              key: ValueKey('turnip-wrong-order'),
                              icon: controller.hintVisible
                                  ? Icons.lightbulb_outline_rounded
                                  : Icons.refresh_rounded,
                              text: controller.hintVisible
                                  ? '$turnipWrongOrderText\n$turnipHintText'
                                  : turnipWrongOrderText,
                              color: AppColors.crimsonDark,
                            )
                          : controller.hintVisible
                          ? const _FeedbackCard(
                              key: ValueKey('turnip-hint'),
                              icon: Icons.lightbulb_outline_rounded,
                              text: turnipHintText,
                              color: AppColors.leafGreen,
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('turnip-no-feedback'),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _ChainTarget(
                      controller: controller,
                      slotSize: chainSize,
                      onPlace: onPlace,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Transform.translate(
                      offset: Offset(shakeOffset, 0),
                      child: _CharacterTray(
                        controller: controller,
                        pieceSize: pieceSize,
                        onPlace: onPlace,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.controller});

  final TurnipGameController controller;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label:
          '$turnipTaskText. В цепочке ${controller.placedCharacters.length} из ${TurnipCharacter.values.length} помощников.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.cardBg.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.parchmentDark),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.groups_2_outlined,
                color: AppColors.crimson,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  turnipTaskText,
                  style: AppTextStyles.cardRowLabel,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${controller.placedCharacters.length}/${TurnipCharacter.values.length}',
                style: AppTextStyles.counterValue.copyWith(fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBg.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: color.withValues(alpha: 0.65)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: AppTextStyles.supporting.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChainTarget extends StatelessWidget {
  const _ChainTarget({
    required this.controller,
    required this.slotSize,
    required this.onPlace,
  });

  final TurnipGameController controller;
  final double slotSize;
  final ValueChanged<TurnipCharacter> onPlace;

  @override
  Widget build(BuildContext context) {
    final placed = controller.placedCharacters;
    final chainDescription = placed.isEmpty
        ? 'Дедушка ждёт помощников'
        : 'Дедушка, ${placed.map((item) => item.label).join(', ')}';

    return Semantics(
      label: 'Цепочка: $chainDescription',
      child: DragTarget<TurnipCharacter>(
        key: const ValueKey('turnip-chain-target'),
        onWillAcceptWithDetails: (details) => !placed.contains(details.data),
        onAcceptWithDetails: (details) => onPlace(details.data),
        builder: (context, candidates, rejected) {
          final active = candidates.isNotEmpty;
          return AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.infoBg.withValues(alpha: 0.98)
                  : AppColors.cardBg.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(
                color: active ? AppColors.coinGold : AppColors.parchmentDark,
                width: active ? 3 : 2,
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ChainSlot(
                  size: slotSize,
                  label: 'Дедушка',
                  assetPath: 'assets/games/turnip/grandpa_pulling.png',
                  filled: true,
                ),
                for (
                  var index = 0;
                  index < TurnipCharacter.values.length;
                  index++
                )
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: index < placed.length
                        ? _ChainSlot(
                            key: ValueKey('turnip-chain-${placed[index].name}'),
                            size: slotSize,
                            label: placed[index].label,
                            assetPath: placed[index].assetPath,
                            filled: true,
                          )
                        : _ChainSlot(
                            size: slotSize,
                            label: 'Свободное место ${index + 1}',
                            number: index + 1,
                            filled: false,
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

class _ChainSlot extends StatelessWidget {
  const _ChainSlot({
    super.key,
    required this.size,
    required this.label,
    required this.filled,
    this.assetPath,
    this.number,
  });

  final double size;
  final String label;
  final bool filled;
  final String? assetPath;
  final int? number;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      image: filled,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled
              ? AppColors.canvasWarm.withValues(alpha: 0.78)
              : AppColors.parchmentDark.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(
            color: filled ? AppColors.leafGreen : AppColors.fieldBorder,
            width: filled ? 2 : 1.5,
          ),
        ),
        child: assetPath != null
            ? Padding(
                padding: const EdgeInsets.all(2),
                child: Image.asset(assetPath!, fit: BoxFit.contain),
              )
            : Center(
                child: Text(
                  '$number',
                  style: AppTextStyles.swatchLabel.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
      ),
    );
  }
}

class _CharacterTray extends StatelessWidget {
  const _CharacterTray({
    required this.controller,
    required this.pieceSize,
    required this.onPlace,
  });

  final TurnipGameController controller;
  final double pieceSize;
  final ValueChanged<TurnipCharacter> onPlace;

  @override
  Widget build(BuildContext context) {
    final available = controller.trayCharacters
        .where((character) => !controller.placedCharacters.contains(character))
        .toList(growable: false);

    return Container(
      key: const ValueKey('turnip-character-tray'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.parchmentDark, width: 2),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.xxs,
        runSpacing: AppSpacing.xxs,
        children: [
          for (final character in available)
            _CharacterPiece(
              key: ValueKey('turnip-piece-${character.name}'),
              character: character,
              size: pieceSize,
              onPlace: () => onPlace(character),
            ),
        ],
      ),
    );
  }
}

class _CharacterPiece extends StatelessWidget {
  const _CharacterPiece({
    super.key,
    required this.character,
    required this.size,
    required this.onPlace,
  });

  final TurnipCharacter character;
  final double size;
  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context) {
    final piece = _PieceImage(character: character, size: size);
    return Semantics(
      button: true,
      label:
          '${character.label}. Перетащи или нажми, чтобы добавить в цепочку.',
      onTap: onPlace,
      child: ExcludeSemantics(
        child: Draggable<TurnipCharacter>(
          data: character,
          feedback: Material(
            color: Colors.transparent,
            child: _PieceImage(character: character, size: size * 1.08),
          ),
          childWhenDragging: Opacity(opacity: 0.28, child: piece),
          child: InkWell(
            onTap: onPlace,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: piece,
          ),
        ),
      ),
    );
  }
}

class _PieceImage extends StatelessWidget {
  const _PieceImage({required this.character, required this.size});

  final TurnipCharacter character;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.canvasWarm,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Image.asset(character.assetPath, fit: BoxFit.contain),
    );
  }
}
