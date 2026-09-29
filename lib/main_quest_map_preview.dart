import 'package:flutter/material.dart';

import 'map/quest_map_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const QuestMapPreviewApp());
}

class QuestMapPreviewApp extends StatelessWidget {
  const QuestMapPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Грошик · карта приключений',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.crimson),
        fontFamily: AppFonts.body,
      ),
      // Representative review state: one quest completed, the second current.
      home: const QuestMapScreen(showBack: false, initialUnlockedIndex: 1),
    );
  }
}
