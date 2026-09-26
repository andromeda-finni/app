import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../turnip_game_models.dart';

class TurnipIntroView extends StatelessWidget {
  const TurnipIntroView({
    super.key,
    required this.line,
    required this.pageIndex,
    required this.pageCount,
    required this.onContinue,
  });

  final TurnipStoryLine line;
  final int pageIndex;
  final int pageCount;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final isLastPage = pageIndex == pageCount - 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 560;
        final portraitSize = (constraints.maxWidth * 1.18).clamp(360.0, 560.0);
        return DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.canvasWarm),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/games/turnip/garden_background.png',
                      fit: BoxFit.cover,
                      alignment: const Alignment(-0.35, 0),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x44000000)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: (constraints.maxWidth - portraitSize) / 2,
                      bottom: -portraitSize * (compact ? 0.36 : 0.32),
                      width: portraitSize,
                      height: portraitSize,
                      child: Image.asset(
                        'assets/games/turnip/grandpa_sad.png',
                        key: const ValueKey('turnip-intro-grandpa-portrait'),
                        fit: BoxFit.contain,
                        semanticLabel: 'Крупный портрет грустного Дедушки',
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: AppColors.cardBg,
                elevation: 8,
                child: InkWell(
                  key: const ValueKey('turnip-intro-continue-area'),
                  onTap: onContinue,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      compact ? AppSpacing.xs : AppSpacing.lg,
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
                        Text(line.text, style: AppTextStyles.story),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            key: const ValueKey('turnip-intro-continue'),
                            onPressed: onContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.crimson,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              isLastPage ? 'Помочь' : 'Дальше',
                              style: AppTextStyles.button,
                            ),
                          ),
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
