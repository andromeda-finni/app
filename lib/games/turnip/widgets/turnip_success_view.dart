import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../turnip_game_content.dart';

class TurnipPullingView extends StatelessWidget {
  const TurnipPullingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/games/turnip/garden_background.png',
          fit: BoxFit.cover,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.canvasWarm.withValues(alpha: 0.18),
                AppColors.canvasWarm.withValues(alpha: 0.52),
              ],
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: AspectRatio(
                aspectRatio: 1,
                child: Semantics(
                  image: true,
                  label: 'Все герои вместе тянут репку',
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.cardBg.withValues(alpha: 0.92),
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x38000000),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/games/turnip/team_pulling.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TurnipSuccessView extends StatelessWidget {
  const TurnipSuccessView({
    super.key,
    required this.rewardAmount,
    required this.onReplay,
    this.onExit,
  });

  final int rewardAmount;
  final VoidCallback onReplay;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvasWarm,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 620;
          return Column(
            children: [
              Expanded(
                child: Semantics(
                  image: true,
                  label: 'Счастливые герои рядом с вытащенной репкой',
                  child: Image.asset(
                    'assets/games/turnip/success_harvest.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    alignment: const Alignment(0, -0.18),
                  ),
                ),
              ),
              Material(
                color: AppColors.cardBg,
                elevation: 8,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    compact ? AppSpacing.sm : AppSpacing.lg,
                    AppSpacing.lg,
                    compact ? AppSpacing.sm : AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Репка вытащена!',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.screenTitle.copyWith(
                          color: AppColors.crimsonDark,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        turnipSuccessText,
                        textAlign: TextAlign.center,
                        style: compact
                            ? AppTextStyles.supporting.copyWith(
                                color: AppColors.ink,
                              )
                            : AppTextStyles.story,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Semantics(
                        label: 'Награда: $rewardAmount монет',
                        child: ExcludeSemantics(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.infoBg,
                              borderRadius: BorderRadius.circular(AppRadii.lg),
                              border: Border.all(color: AppColors.coinGold),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/icons/coin.png',
                                  width: 24,
                                  height: 24,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  'Награда: $rewardAmount монет',
                                  style: AppTextStyles.cardRowLabel.copyWith(
                                    color: AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              key: const ValueKey('turnip-replay'),
                              onPressed: onReplay,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                foregroundColor: AppColors.crimsonDark,
                                side: const BorderSide(
                                  color: AppColors.crimson,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                'Ещё раз',
                                style: AppTextStyles.cardRowLabel.copyWith(
                                  color: AppColors.crimsonDark,
                                ),
                              ),
                            ),
                          ),
                          if (onExit != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: ElevatedButton(
                                key: const ValueKey('turnip-exit'),
                                onPressed: onExit,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 52),
                                  backgroundColor: AppColors.crimson,
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                ),
                                child: Text(
                                  'На карту',
                                  style: AppTextStyles.button,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
