import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A small rounded text field meant to sit inline inside the story sentence
/// (via a WidgetSpan) — "...котёнок по имени [_________]."
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
      width: 148,
      height: 40,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        maxLength: 24,
        style: AppTextStyles.story.copyWith(fontSize: 17),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          hintText: 'Введи имя',
          hintStyle: AppTextStyles.story.copyWith(
            fontSize: 16,
            color: AppColors.inkMuted,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.6),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.fieldBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.fieldBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.crimson, width: 1.5),
          ),
        ),
      ),
    );
  }
}
