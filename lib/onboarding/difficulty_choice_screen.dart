import 'package:flutter/material.dart';

import '../core/child_difficulty.dart';
import '../theme/app_theme.dart';
import 'widgets/story_button.dart';

class DifficultyChoiceScreen extends StatelessWidget {
  const DifficultyChoiceScreen({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onContinue,
    this.isSubmitting = false,
  });

  final ChildDifficulty? selected;
  final ValueChanged<ChildDifficulty> onSelected;
  final VoidCallback? onContinue;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 62,
                    color: AppColors.crimson,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Как тебе удобнее играть?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 30,
                      height: 1.12,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Выбери темп для первой игры. Его всегда можно поменять в настройках.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.story.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 26),
                  for (final difficulty in ChildDifficulty.values) ...[
                    _DifficultyCard(
                      difficulty: difficulty,
                      selected: difficulty == selected,
                      onTap: isSubmitting ? null : () => onSelected(difficulty),
                    ),
                    if (difficulty != ChildDifficulty.values.last)
                      const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 26),
                  StoryButton(
                    label: isSubmitting ? 'Сохраняем…' : 'Продолжить',
                    onPressed: isSubmitting || selected == null
                        ? null
                        : onContinue,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({
    required this.difficulty,
    required this.selected,
    required this.onTap,
  });

  final ChildDifficulty difficulty;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${difficulty.title}. ${difficulty.description}',
      child: Material(
        color: selected ? const Color(0xFFFFF0D0) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? AppColors.crimson : AppColors.fieldBorder,
                width: selected ? 2 : 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? AppColors.crimson : AppColors.inkMuted,
                  size: 30,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        difficulty.title,
                        style: AppTextStyles.cardTitle.copyWith(fontSize: 21),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        difficulty.description,
                        style: AppTextStyles.story.copyWith(fontSize: 15),
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
