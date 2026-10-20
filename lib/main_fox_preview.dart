import 'package:flutter/material.dart';

import 'core/large_text.dart';
import 'home/pet_home_screen.dart';
import 'theme/app_theme.dart';

/// Isolated story preview: flutter run -t lib/main_fox_preview.dart.
/// The normal application never routes through this entry point.
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Грошик · просмотр историй Лиса',
      theme: AppTheme.light,
      builder: LargeTextScope.builder,
      home: const PetHomeScreen(),
    ),
  );
}
