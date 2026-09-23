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
    this.isLoading = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final bool showFlourish;
  final bool isLoading;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final button = ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.crimson,
        disabledBackgroundColor: AppColors.crimson.withValues(alpha: 0.4),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: expand ? 24 : 28,
          vertical: 16,
        ),
        shape: const StadiumBorder(),
        elevation: enabled ? 3 : 0,
      ),
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showFlourish) ...[
                  const Icon(
                    Icons.eco_outlined,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                ],
                // Flexible + ellipsis: at large text-scale factors or on very
                // narrow screens, a long label (e.g. "Начать игру") shrinks
                // to fit whatever width the parent Row gives this button
                // instead of forcing a RenderFlex overflow.
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.button,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showFlourish) ...[
                  const SizedBox(width: 12),
                  Transform.flip(
                    flipX: true,
                    child: const Icon(
                      Icons.eco_outlined,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ],
              ],
            ),
    );

    final semantics = Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      // ExcludeSemantics drops the InkWell's tap action along with the rest
      // of the subtree, so without re-declaring it here the node announces
      // itself as a button that a screen reader then cannot activate.
      onTap: enabled ? onPressed : null,
      child: ExcludeSemantics(child: button),
    );

    if (!expand) return semantics;
    return SizedBox(width: double.infinity, height: 56, child: semantics);
  }
}
