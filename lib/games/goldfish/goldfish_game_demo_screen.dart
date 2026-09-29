import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'goldfish_game_models.dart';
import 'goldfish_game_screen.dart';

class GoldfishGameDemoScreen extends StatelessWidget {
  const GoldfishGameDemoScreen({super.key, this.petName = 'Лучик'});

  final String petName;

  @override
  Widget build(BuildContext context) {
    const levels = [
      GoldfishLevelId.normalOne,
      GoldfishLevelId.normalTwo,
      GoldfishLevelId.hardOne,
      GoldfishLevelId.hardTwo,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Демо · Золотая рыбка'),
        backgroundColor: AppColors.parchment,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: levels.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final level = levels[index];
          return Card(
            color: AppColors.cardBg,
            child: ListTile(
              contentPadding: const EdgeInsets.all(AppSpacing.md),
              title: Text(_title(level), style: AppTextStyles.sectionTitle),
              subtitle: Text(
                '${level.difficulty.title} · награда ${level.reward} монет',
                style: AppTextStyles.supporting,
              ),
              trailing: const Icon(Icons.play_arrow_rounded),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (gameContext) => GoldfishGameScreen(
                    initialLevel: level,
                    petName: petName,
                    enableSequentialNext: false,
                    onExit: () => Navigator.of(gameContext).pop(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _title(GoldfishLevelId level) => switch (level) {
    GoldfishLevelId.normalOne => 'Нормальный 1 · Самое необходимое',
    GoldfishLevelId.normalTwo => 'Нормальный 2 · Готовимся к холодам',
    GoldfishLevelId.hardOne => 'Сложный 1 · Красиво или разумно?',
    GoldfishLevelId.hardTwo => 'Сложный 2 · Домик и запас',
  };
}
