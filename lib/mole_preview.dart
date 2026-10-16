import 'package:flutter/material.dart';

import 'minigames/mole/mole_game_screen.dart';
import 'theme/app_theme.dart';

/// Local visual review of the actual game widgets, without account or backend.
void main() => runApp(
  MaterialApp(
    title: 'Крот · Линза правды',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const MoleGameScreen(),
  ),
);
