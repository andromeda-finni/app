import 'package:flutter/material.dart';

import 'games/goldfish/goldfish_game_demo_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const GoldfishGameDemoScreen(),
    ),
  );
}
