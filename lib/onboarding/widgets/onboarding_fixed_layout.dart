import 'package:flutter/material.dart';

/// Shared shell for every onboarding screen: an illustration (or, on step 3,
/// the tutorial scroll) above a parchment card, with no scrolling anywhere —
/// one screen is one page, exactly as the reference screens are drawn.
///
/// "No scroll" and "never overflow" are only compatible if something gives
/// when the content is taller than the viewport, so two things do:
///
/// * [top] sits in an `Expanded`, so it surrenders its height first — a
///   taller card eats into the illustration rather than off the screen.
/// * the card is then hard-capped at `1 - topMinFraction` of the viewport and
///   wrapped in a scale-down `FittedBox`. Once even that cap is not enough
///   (a 320x568 screen at 1.3x text scale, or the keyboard halving the
///   available height) the whole card shrinks proportionally instead of
///   clipping. Shrinking keeps every block on screen and readable, which a
///   `Column` alone cannot promise.
class OnboardingFixedLayout extends StatelessWidget {
  const OnboardingFixedLayout({
    super.key,
    required this.top,
    required this.bottom,
    this.topMinFraction = 0.30,
  });

  final Widget top;
  final Widget bottom;

  /// Share of the viewport the illustration keeps no matter how tall the card
  /// wants to be. Raise it for a screen whose `top` is the real content (step
  /// 3's budget scroll) rather than decoration.
  final double topMinFraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: top),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * (1 - topMinFraction),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomCenter,
                child: SizedBox(width: constraints.maxWidth, child: bottom),
              ),
            ),
          ],
        );
      },
    );
  }
}
