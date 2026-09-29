import 'package:flutter/material.dart';

import 'core/child_difficulty.dart';
import 'minigames/bakery/bakery_game_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const BakeryGameScreen(difficulty: ChildDifficulty.beginner),
    ),
  );
}
