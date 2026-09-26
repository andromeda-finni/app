import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'turnip_game_models.dart';
import 'turnip_game_screen.dart';

class TurnipGameDemoScreen extends StatelessWidget {
  const TurnipGameDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasWarm,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              shrinkWrap: true,
              children: [
                Text(
                  'Демо игры «Репка»',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.screenTitle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Выберите версию для проверки. В основном приложении она задаётся заранее.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.supporting,
                ),
                const SizedBox(height: AppSpacing.xl),
                _DemoVersionCard(
                  key: const ValueKey('turnip-demo-normal'),
                  title: 'Попроще',
                  description: 'Помощников можно поставить в любом порядке. Награда — 10 монет.',
                  icon: Icons.auto_awesome_rounded,
                  onTap: () => _open(context, TurnipDifficulty.normal),
                ),
                const SizedBox(height: AppSpacing.md),
                _DemoVersionCard(
                  key: const ValueKey('turnip-demo-hard'),
                  title: 'Посложнее',
                  description: 'Помощников нужно поставить в правильном сказочном порядке. Награда — 12 монет.',
                  icon: Icons.psychology_alt_rounded,
                  onTap: () => _open(context, TurnipDifficulty.hard),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, TurnipDifficulty difficulty) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            TurnipGameScreen(difficulty: difficulty, petName: 'Грошик'),
      ),
    );
  }
}

class _DemoVersionCard extends StatelessWidget {
  const _DemoVersionCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBg,
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.infoBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.crimson, size: 30),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.cardTitle),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(description, style: AppTextStyles.supporting),
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
      ),
    );
  }
}
