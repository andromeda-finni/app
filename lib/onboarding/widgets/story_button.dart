import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// The red pill button used to advance onboarding. Step 1 uses a full-width
/// version with leaf flourishes; steps 2-4 sit next to a back button and
/// hug their label instead (flourishes only on the very first/last step,
/// matching the reference designs).
class StoryButton extends StatelessWidget {
  const StoryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
    this.showFlourish = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final bool showFlourish;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.crimson,
        disabledBackgroundColor: AppColors.crimson.withValues(alpha: 0.4),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: expand ? 24 : 28, vertical: 16),
        shape: const StadiumBorder(),
        elevation: enabled ? 3 : 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showFlourish) ...[
            const Icon(Icons.eco_outlined, color: Colors.white70, size: 18),
            const SizedBox(width: 12),
          ],
          Text(label, style: AppTextStyles.button),
          if (showFlourish) ...[
            const SizedBox(width: 12),
            Transform.flip(
              flipX: true,
              child: const Icon(Icons.eco_outlined, color: Colors.white70, size: 18),
            ),
          ],
        ],
      ),
    );

    if (!expand) return button;
    return SizedBox(width: double.infinity, height: 56, child: button);
  }
}
