import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The primary onboarding action. Its label uses the readable body family;
/// decoration never competes with the action text.
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
        minimumSize: const Size(0, 54),
        padding: EdgeInsets.symmetric(horizontal: expand ? 14 : 22),
        shape: const StadiumBorder(),
        elevation: enabled ? 1 : 0,
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
                  const _ButtonFlourish(),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.button,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (showFlourish) ...[
                  const SizedBox(width: 6),
                  Transform.flip(flipX: true, child: const _ButtonFlourish()),
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
    return SizedBox(width: double.infinity, child: semantics);
  }
}

/// `arrow_left.png` has generous transparent export margins. The overflow box
/// enlarges the source inside a small fixed slot so the painted branch reads
/// at button scale without altering or duplicating the asset.
class _ButtonFlourish extends StatelessWidget {
  const _ButtonFlourish();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 18,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: 48,
          maxHeight: 32,
          child: Image.asset(
            'assets/icons/arrow_left.png',
            width: 48,
            height: 32,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
