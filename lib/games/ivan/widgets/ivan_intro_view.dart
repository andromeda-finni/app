import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../ivan_game_content.dart';
import '../ivan_game_models.dart';

class IvanIntroView extends StatelessWidget {
  const IvanIntroView({
    super.key,
    required this.line,
    required this.pageIndex,
    required this.pageCount,
    required this.onContinue,
    this.onExit,
  });

  final IvanStoryLine line;
  final int pageIndex;
  final int pageCount;
  final VoidCallback onContinue;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final isLast = pageIndex == pageCount - 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 610;
        final portraitWidth = (constraints.maxWidth * 1.2).clamp(0.0, 620.0);
        return ColoredBox(
          color: AppColors.canvasWarm,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      IvanAssets.shopBackground,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x11000000), Color(0x66000000)],
                        ),
                      ),
                    ),
                    if (onExit != null)
                      Positioned(
                        left: AppSpacing.xs,
                        top: AppSpacing.xs,
                        child: Material(
                          color: AppColors.cardBg.withValues(alpha: 0.9),
                          shape: const CircleBorder(),
                          child: IconButton(
                            onPressed: onExit,
                            tooltip: 'Назад на карту',
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minWidth: 0,
                        maxWidth: portraitWidth,
                        child: Semantics(
                          image: true,
                          label:
                              'Поясной портрет Ивана-царевича во время диалога',
                          child: SizedBox(
                            width: portraitWidth,
                            child: Image.asset(
                              IvanAssets.ivan,
                              key: const ValueKey('ivan-dialogue-portrait'),
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.topCenter,
                            ),
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
                  key: const ValueKey('ivan-intro-continue-area'),
                  onTap: onContinue,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      compact ? AppSpacing.sm : AppSpacing.lg,
                      AppSpacing.lg,
                      compact ? AppSpacing.sm : AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                line.speaker,
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
                            Text(
                              isLast ? 'Помочь Ивану' : 'Продолжить',
                              style: AppTextStyles.cardRowLabel.copyWith(
                                color: AppColors.crimsonDark,
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
