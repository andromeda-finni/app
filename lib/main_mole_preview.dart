import 'package:flutter/material.dart';

import 'minigames/mole/mole_game_screen.dart';
import 'theme/app_theme.dart';

/// Browser-friendly local preview that opens the mini-game immediately.
///
/// Run with:
/// `flutter run -d web-server -t lib/main_mole_preview.dart --web-port 8767`
void main() {
  runApp(
    MaterialApp(
      title: 'Грошик — Крот, версия 0.3',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.crimson),
        scaffoldBackgroundColor: AppColors.parchment,
        fontFamily: AppFonts.family,
      ),
      home: const MoleGameScreen(),
    ),
  );
}
