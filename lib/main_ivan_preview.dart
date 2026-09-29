import 'package:flutter/material.dart';

import 'games/ivan/ivan_game_screen.dart';
import 'games/ivan/ivan_game_models.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const _IvanPreviewApp());
}

class _IvanPreviewApp extends StatelessWidget {
  const _IvanPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _IvanPreviewMenu(),
    );
  }
}

class _IvanPreviewMenu extends StatelessWidget {
  const _IvanPreviewMenu();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Просмотр игры Ивана-царевича')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Этот выбор существует только для проверки. В приложении уровень определяется настройкой ребёнка и прогрессом.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            for (final level in IvanLevelId.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => IvanGameScreen(
                        initialLevel: level,
                        petName: 'Грошик',
                        enableSequentialNext: false,
                        onExit: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${level.difficulty == IvanDifficulty.easy ? 'Простой' : 'Сложный'} уровень ${level.sequence} · награда ${level.difficulty.reward}',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
