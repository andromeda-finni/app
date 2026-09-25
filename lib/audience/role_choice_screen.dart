import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RoleChoiceScreen extends StatelessWidget {
  const RoleChoiceScreen({
    super.key,
    required this.onChildSelected,
    required this.onParentSelected,
  });

  final VoidCallback onChildSelected;
  final VoidCallback onParentSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.fieldBorder,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.pets_rounded,
                      size: 58,
                      color: AppColors.crimson,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Кто сегодня открывает «Грошик»?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 30,
                      height: 1.1,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Выбери свой раздел. Вернуться к этому экрану можно из настроек.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.story.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 28),
                  _RoleCard(
                    key: const Key('role-child'),
                    icon: Icons.pets_rounded,
                    title: 'Я ребёнок',
                    description: 'Игры, питомец, задания и награды за финансовые навыки.',
                    onTap: onChildSelected,
                  ),
                  const SizedBox(height: 14),
                  _RoleCard(
                    key: const Key('role-parent'),
                    icon: Icons.family_restroom_rounded,
                    title: 'Я родитель',
                    description: 'Прогресс ребёнка, темы для повторения и история действий.',
                    onTap: onParentSelected,
                    parent: true,
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.parent = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool parent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: parent ? AppColors.cardBg : AppColors.crimson,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: parent ? AppColors.fieldBorder : AppColors.crimsonDark,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 38,
                color: parent ? AppColors.leafGreen : Colors.white,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.cardTitle.copyWith(
                        color: parent ? AppColors.ink : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTextStyles.story.copyWith(
                        fontSize: 14,
                        color: parent ? AppColors.inkMuted : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: parent ? AppColors.inkMuted : Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
