import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const ink = Color(0xFF3B2F27);
  static const inkMuted = Color(0xFF8A7C6C);
  static const fieldBorder = Color(0xFFC9B79B);
}

abstract final class AppTextStyles {
  static TextStyle dropCap = GoogleFonts.yesevaOne(
    color: AppColors.crimson,
    fontSize: 64,
    height: 1,
    fontWeight: FontWeight.w400,
  );

  static TextStyle story = GoogleFonts.ptSerif(
    color: AppColors.ink,
    fontSize: 19,
    height: 1.45,
  );

  static TextStyle swatchLabel = GoogleFonts.ptSerif(
    color: AppColors.inkMuted,
    fontSize: 13,
  );

  static TextStyle stepCounter = GoogleFonts.ptSerif(
    color: AppColors.inkMuted,
    fontSize: 14,
  );

  static TextStyle button = GoogleFonts.yesevaOne(
    color: Colors.white,
    fontSize: 20,
    letterSpacing: 0.5,
  );
}
