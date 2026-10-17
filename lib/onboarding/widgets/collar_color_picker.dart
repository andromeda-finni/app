import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Free collar choices shared by onboarding and the pet identity editor.
class CollarColorPicker extends StatelessWidget {
  const CollarColorPicker({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  final String? selectedId;
  final ValueChanged<String> onSelected;

  static const options = [
    (id: 'ACC_COLLAR_RED', label: 'красный', color: Color(0xFFB62C28)),
    (id: 'ACC_COLLAR_GREEN', label: 'зелёный', color: Color(0xFF4E713D)),
    (id: 'ACC_COLLAR_BLUE', label: 'синий', color: Color(0xFF2768A8)),
  ];

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final option in options)
        Expanded(
          child: Semantics(
            button: true,
            selected: selectedId == option.id,
            label: 'Цвет ошейника: ${option.label}',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.md),
              onTap: () => onSelected(option.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: option.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedId == option.id
                              ? AppColors.crimsonDark
                              : AppColors.parchmentDark,
                          width: selectedId == option.id ? 3 : 1,
                        ),
                      ),
                      child: selectedId == option.id
                          ? const Icon(Icons.check_rounded, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      option.label,
                      style: AppTextStyles.swatchLabel,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
