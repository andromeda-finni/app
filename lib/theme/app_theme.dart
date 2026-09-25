import 'package:flutter/material.dart';

/// Shared visual foundation for the child-facing storybook experience.
/// Illustrations and drop caps carry the fairy-tale character; functional
/// text stays in a highly readable serif face.
abstract final class AppColors {
  static const canvas = Color(0xFFFFF9EF);
  static const canvasWarm = Color(0xFFFCF2E1);
  static const parchment = Color(0xFFF7EBD8);
  static const parchmentDark = Color(0xFFEAD8BA);
  static const crimson = Color(0xFFAD2B23);
  static const crimsonDark = Color(0xFF842019);
  static const crimsonFaded = Color(0xFFE5B8AF);
  static const ink = Color(0xFF352923);
  static const inkMuted = Color(0xFF75675C);
  static const fieldBorder = Color(0xFFD4C2A5);
  static const leafGreen = Color(0xFF526B45);
  static const cardBg = Color(0xFFFFFBF4);
  static const coinGold = Color(0xFFD99524);
  static const infoBg = Color(0xFFFFF1D5);
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppRadii {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const sheet = 28.0;
}

abstract final class AppFonts {
  static const body = 'PTSerif';
  static const accent = 'BaroccoInitial';
}

abstract final class AppTextStyles {
  static const TextStyle dropCap = TextStyle(
    fontFamily: AppFonts.accent,
    color: AppColors.crimson,
    fontSize: 62,
    height: 0.92,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle story = TextStyle(
    fontFamily: AppFonts.body,
    color: AppColors.ink,
    fontSize: 18,
    height: 1.45,
  );

  static const TextStyle screenTitle = TextStyle(
    fontFamily: AppFonts.body,
    color: AppColors.ink,
    fontSize: 24,
    height: 1.22,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: AppFonts.body,
    color: AppColors.ink,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle supporting = TextStyle(
    fontFamily: AppFonts.body,
    color: AppColors.inkMuted,
    fontSize: 15,
    height: 1.42,
  );

  static const TextStyle swatchLabel = TextStyle(
    fontFamily: AppFonts.body,
    color: AppColors.inkMuted,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle stepCounter = TextStyle(
    fontFamily: AppFonts.body,
    color: AppColors.inkMuted,
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle button = TextStyle(
    fontFamily: AppFonts.body,
    color: Colors.white,
    fontSize: 17,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: AppFonts.body,
    color: AppColors.ink,
    fontSize: 21,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle cardRowLabel = TextStyle(
    fontFamily: AppFonts.body,
    color: AppColors.ink,
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle navLabel = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    height: 1.1,
  );

  static const TextStyle counterValue = TextStyle(
    fontFamily: AppFonts.body,
    color: AppColors.ink,
    fontSize: 22,
    height: 1,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.crimson,
      brightness: Brightness.light,
      surface: AppColors.canvas,
    ),
    scaffoldBackgroundColor: AppColors.canvas,
    fontFamily: AppFonts.body,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.crimson,
      selectionColor: AppColors.crimsonFaded,
      selectionHandleColor: AppColors.crimson,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: TextStyle(
        fontFamily: AppFonts.body,
        color: Colors.white,
        fontSize: 15,
      ),
    ),
  );
}
