import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../goldfish_game_content.dart';
import '../goldfish_game_models.dart';

class GoldfishDialogueView extends StatelessWidget {
  const GoldfishDialogueView({
    super.key,
    required this.line,
    required this.pageIndex,
    required this.pageCount,
    required this.onContinue,
    required this.isResultDialogue,
    required this.successfulResult,
    this.onExit,
  });

  final GoldfishStoryLine line;
  final int pageIndex;
  final int pageCount;
  final VoidCallback onContinue;
  final bool isResultDialogue;
  final bool successfulResult;
  final VoidCallback? onExit;

  String get _speakerName => switch (line.speaker) {
    GoldfishSpeaker.grandma => 'Бабушка',
    GoldfishSpeaker.grandpa => 'Дедушка',
    GoldfishSpeaker.goldfish => 'Золотая рыбка',
  };

  String get _speakerAsset => switch (line.speaker) {
    GoldfishSpeaker.grandma => GoldfishAssets.grandma,
    GoldfishSpeaker.grandpa => GoldfishAssets.grandpa,
    GoldfishSpeaker.goldfish => GoldfishAssets.goldfish,
  };

  @override
  Widget build(BuildContext context) {
    final isLast = pageIndex == pageCount - 1;
    final showRenovatedHome = isResultDialogue && successfulResult;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 650;
        return ColoredBox(
          color: AppColors.canvasWarm,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      showRenovatedHome
                          ? GoldfishAssets.homeAfterPortrait
                          : GoldfishAssets.homeBeforePortrait,
                      key: ValueKey(
                        showRenovatedHome
                            ? 'goldfish-home-renovated'
                            : 'goldfish-home-needs-repair',
                      ),
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x08000000), Color(0x5E000000)],
                        ),
                      ),
                    ),
                    if (onExit != null)
                      Positioned(
                        left: AppSpacing.xs,
                        top: AppSpacing.xs,
                        child: Material(
                          color: AppColors.cardBg.withValues(alpha: 0.92),
                          shape: const CircleBorder(),
                          child: IconButton(
                            onPressed: onExit,
                            tooltip: 'Назад на карту',
                            constraints: const BoxConstraints.tightFor(
                              width: 48,
                              height: 48,
                            ),
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: ClipRect(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _SpeakerPortrait(
                            key: ValueKey(line.speaker),
                            speaker: line.speaker,
                            assetPath: _speakerAsset,
                            compact: compact,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: AppColors.cardBg,
                elevation: 10,
                child: InkWell(
                  key: const ValueKey('goldfish-dialogue-continue'),
                  onTap: onContinue,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      compact ? AppSpacing.sm : AppSpacing.lg,
                      AppSpacing.lg,
                      compact ? AppSpacing.sm : AppSpacing.xl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$_speakerName:',
                                style: AppTextStyles.sectionTitle.copyWith(
                                  color: AppColors.crimsonDark,
                                ),
                              ),
                            ),
                            Text(
                              '${pageIndex + 1}/$pageCount',
                              style: AppTextStyles.stepCounter,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          line.text,
                          style: compact
                              ? AppTextStyles.supporting.copyWith(
                                  color: AppColors.ink,
                                  fontSize: 16,
                                )
                              : AppTextStyles.story,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                isLast
                                    ? isResultDialogue
                                          ? 'Посмотреть результат'
                                          : 'Начать покупки'
                                    : 'Нажми, чтобы продолжить',
                                textAlign: TextAlign.end,
                                style: AppTextStyles.cardRowLabel.copyWith(
                                  color: AppColors.crimsonDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: AppColors.crimsonDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SpeakerPortrait extends StatelessWidget {
  const _SpeakerPortrait({
    super.key,
    required this.speaker,
    required this.assetPath,
    required this.compact,
  });

  final GoldfishSpeaker speaker;
  final String assetPath;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isFish = speaker == GoldfishSpeaker.goldfish;
    if (isFish) {
      return Align(
        alignment: const Alignment(0.05, 0.14),
        child: FractionallySizedBox(
          widthFactor: compact ? 0.84 : 0.92,
          child: Semantics(
            image: true,
            label: 'Золотая рыбка говорит',
            child: Image.asset(assetPath, fit: BoxFit.contain),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // The source portraits include the whole body. Dialogue scenes use a
        // closer, waist-up crop so the speaker remains expressive on narrow
        // phones instead of shrinking to a small full-body figure.
        final portraitHeight = constraints.maxHeight * (compact ? 1.32 : 1.42);
        return Align(
          alignment: Alignment.bottomCenter,
          child: OverflowBox(
            maxWidth: constraints.maxWidth * 2,
            maxHeight: constraints.maxHeight * 1.7,
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: Offset(0, portraitHeight * 0.40),
              child: Semantics(
                image: true,
                label: speaker == GoldfishSpeaker.grandma
                    ? 'Бабушка говорит'
                    : 'Дедушка говорит',
                child: Image.asset(
                  assetPath,
                  height: portraitHeight,
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
