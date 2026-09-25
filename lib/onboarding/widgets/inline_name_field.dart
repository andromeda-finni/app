import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Full-width pet-name field sized for a comfortable mobile touch target.
class InlineNameField extends StatelessWidget {
  const InlineNameField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        maxLength: 24,
        style: AppTextStyles.story,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          hintText: 'Например, Грошик',
          hintStyle: AppTextStyles.story.copyWith(color: AppColors.inkMuted),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.6),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            borderSide: const BorderSide(color: AppColors.fieldBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            borderSide: const BorderSide(color: AppColors.fieldBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            borderSide: const BorderSide(color: AppColors.crimson, width: 1.5),
          ),
        ),
      ),
    );
  }
}
