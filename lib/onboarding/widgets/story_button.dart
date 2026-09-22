import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class StoryButton extends StatelessWidget {
  const StoryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.crimson,
          disabledBackgroundColor: AppColors.crimson.withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          elevation: enabled ? 3 : 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco_outlined, color: Colors.white70, size: 18),
            const SizedBox(width: 12),
            Text(label, style: AppTextStyles.button),
            const SizedBox(width: 12),
            Transform.flip(
              flipX: true,
              child: const Icon(Icons.eco_outlined, color: Colors.white70, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
