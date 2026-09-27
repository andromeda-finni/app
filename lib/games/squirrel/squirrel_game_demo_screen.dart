import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'squirrel_game_models.dart';
import 'squirrel_game_screen.dart';

class SquirrelGameDemoScreen extends StatelessWidget {
  const SquirrelGameDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries =
        <
          ({
            String title,
            String description,
            SquirrelDifficulty difficulty,
            SquirrelLevel? level,
          })
        >[
          (
            title: 'Вся обычная версия',
            description: 'Сортировка и поиск хорошего товара · награда 10',
            difficulty: SquirrelDifficulty.normal,
            level: null,
          ),
          (
            title: 'Вся сложная версия',
            description: 'Конвейер и осмотр товара · награда 12',
            difficulty: SquirrelDifficulty.hard,
            level: null,
          ),
          (
            title: 'Только «Сортировка»',
            description: 'Без таймера: купить или отказаться',
            difficulty: SquirrelDifficulty.normal,
            level: SquirrelLevel.sorting,
          ),
          (
            title: 'Только «Найди хороший»',
            description: 'Один свежий товар среди трёх',
            difficulty: SquirrelDifficulty.normal,
            level: SquirrelLevel.findOdd,
          ),
          (
            title: 'Только «Лесной конвейер»',
            description: 'Перетаскивание, скорость и бюджет',
            difficulty: SquirrelDifficulty.hard,
            level: SquirrelLevel.conveyor,
          ),
          (
            title: 'Только «Кот в мешке»',
            description: 'Осмотр товара с другой стороны',
            difficulty: SquirrelDifficulty.hard,
            level: SquirrelLevel.inspect,
          ),
        ];
    return Scaffold(
      backgroundColor: AppColors.canvasWarm,
      appBar: AppBar(
        title: Text(
          'Демо · Запасы Белочки',
          style: AppTextStyles.eventTitle.copyWith(fontSize: 24),
        ),
        centerTitle: true,
        backgroundColor: AppColors.parchment,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Card(
            color: AppColors.cardBg,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              leading: CircleAvatar(
                backgroundColor: entry.difficulty == SquirrelDifficulty.normal
                    ? const Color(0xFFE6F0D9)
                    : const Color(0xFFFFE3A1),
                child: Icon(
                  entry.level == null
                      ? Icons.route_rounded
                      : Icons.sports_esports_rounded,
                  color: AppColors.crimson,
                ),
              ),
              title: Text(
                entry.title,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Text(
                entry.description,
                style: const TextStyle(fontFamily: AppFonts.body),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SquirrelGameScreen(
                    difficulty: entry.difficulty,
                    demoLevel: entry.level,
                    isDemo: true,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
