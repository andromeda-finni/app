import 'package:flutter/material.dart';

/// Shared responsive shell for every onboarding screen: a top area
/// (illustration, or on step 3 the tutorial card) sized as a fraction of
/// the viewport, and a bottom area (the parchment content card) below it.
///
/// Deliberately NOT `Column(children: [Expanded(top), bottom])`: that
/// pattern only works while `bottom`'s natural height fits in whatever's
/// left after `top` — once text scale, a long label, or a small device
/// (320x568) makes `bottom` taller than that, `top` has nowhere left to
/// shrink to and the Column overflows. Here `top` gets a fixed fraction of
/// the viewport and the whole page scrolls if `bottom` still doesn't fit
/// below it — there's always a working escape hatch instead of a hard
/// overflow, and it composes correctly with the keyboard opening (which
/// simply shrinks the available height the same way).
class OnboardingScrollLayout extends StatelessWidget {
  const OnboardingScrollLayout({
    super.key,
    required this.top,
    required this.bottom,
    this.topHeightFraction = 0.52,
    this.minTopHeight = 180,
    this.sizeTopToFraction = true,
  });

  final Widget top;
  final Widget bottom;
  final double topHeightFraction;
  final double minTopHeight;

  /// True (default) for purely decorative tops (the illustration): it's
  /// given a fixed fraction of the viewport regardless of its own content.
  /// False for a top that has real content with its own height needs (the
  /// step-3 tutorial card) — forcing that into a fraction can demand less
  /// room than its content needs on a short device and overflow internally;
  /// sizing it naturally and letting the whole page scroll instead avoids
  /// that no matter how little vertical room is available.
  final bool sizeTopToFraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final topWidget = sizeTopToFraction
            ? SizedBox(
                height: (constraints.maxHeight * topHeightFraction).clamp(
                  minTopHeight,
                  constraints.maxHeight,
                ),
                child: top,
              )
            : top;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [topWidget, bottom],
            ),
          ),
        );
      },
    );
  }
}
