import 'package:flutter/material.dart';

import '../games/turnip/turnip_game_models.dart';
import '../games/turnip/turnip_game_screen.dart';
import '../theme/app_theme.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({
    super.key,
    required this.turnipDifficulty,
    this.petName = 'Грошик',
  });

  final TurnipDifficulty turnipDifficulty;
  final String petName;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvas,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          Text('Карта приключений', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Помогай жителям сказочного города и узнавай, как устроены деньги.',
            style: AppTextStyles.supporting,
          ),
          const SizedBox(height: AppSpacing.xl),
          _TurnipGameCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => TurnipGameScreen(
                  difficulty: turnipDifficulty,
                  petName: petName,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnipGameCard extends StatelessWidget {
  const _TurnipGameCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Открыть мини-игру Репка',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          key: const ValueKey('turnip-game-card'),
          color: AppColors.cardBg,
          elevation: 2,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 210,
                  child: Image.asset(
                    'assets/games/turnip/team_pulling.png',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Репка', style: AppTextStyles.cardTitle),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Собери помощников и помоги Дедушке вытащить большую репку.',
                              style: AppTextStyles.supporting,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.crimson,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
