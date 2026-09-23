import 'package:flutter/material.dart';

/// Colors and text styles for the storybook/fairy-tale visual style used in
/// onboarding — a warm parchment card under a painted illustration, with a
/// deep red accent for the drop cap, progress dot and primary button.
abstract final class AppColors {
  static const parchment = Color(0xFFF3E8D6);
  static const parchmentDark = Color(0xFFE8DABF);
  static const skyTop = Color(0xFFBFE3F2);
  static const skyBottom = Color(0xFFEAF6EC);
  static const crimson = Color(0xFFA3271F);
  static const crimsonDark = Color(0xFF7E1E18);
  static const crimsonFaded = Color(0xFFD9AFA6);
  static const ink = Color(0xFF3B2F27);
  static const inkMuted = Color(0xFF8A7C6C);
  static const fieldBorder = Color(0xFFC9B79B);
  static const leafGreen = Color(0xFF4C6B3C);
  static const cardBg = Color(0xFFFBF4E7);
}

// Bundled as a local asset (pubspec.yaml `fonts:`), not fetched at runtime via
// the google_fonts package — that package downloads font files from
// fonts.gstatic.com on first use, which fails (and silently falls back to
// the system font) on a device with no network on first launch. Confirmed
// on a real Android emulator run with no internet access.
//
// One family across every screen, so the storybook voice stays consistent;
// weight and size carry the hierarchy instead of a second typeface.
abstract final class AppFonts {
  static const family = 'Monomakh';
}

const _fontFamily = AppFonts.family;

abstract final class AppTextStyles {
  static const TextStyle dropCap = TextStyle(
    fontFamily: _fontFamily,
    color: AppColors.crimson,
    fontSize: 64,
    height: 1,
    fontWeight: FontWeight.w400,
  );

  // Monomakh runs wider than the previous serif at the same point size, so
  // the story size comes down a little to keep the reference's line breaks.
  static const TextStyle story = TextStyle(
    fontFamily: _fontFamily,
    color: AppColors.ink,
    fontSize: 17,
    height: 1.4,
  );

  static const TextStyle swatchLabel = TextStyle(
    fontFamily: _fontFamily,
    color: AppColors.inkMuted,
    fontSize: 13,
  );

  static const TextStyle stepCounter = TextStyle(
    fontFamily: _fontFamily,
    color: AppColors.inkMuted,
    fontSize: 14,
  );

  static const TextStyle button = TextStyle(
    fontFamily: _fontFamily,
    color: Colors.white,
    fontSize: 20,
    letterSpacing: 0.5,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: _fontFamily,
    color: AppColors.ink,
    fontSize: 22,
  );

  static const TextStyle cardRowLabel = TextStyle(
    fontFamily: _fontFamily,
    color: AppColors.ink,
    fontSize: 16,
  );

  static const TextStyle counterValue = TextStyle(
    fontFamily: _fontFamily,
    color: AppColors.ink,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );
}
