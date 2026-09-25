import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../onboarding/widgets/back_circle_button.dart';
import '../theme/app_theme.dart';

enum ChildDifficulty { beginner, advanced }

class ChildSettingsSnapshot {
  const ChildSettingsSnapshot({
    this.difficulty = ChildDifficulty.beginner,
    this.sound = true,
    this.music = true,
    this.largeText = false,
  });

  final ChildDifficulty difficulty;
  final bool sound;
  final bool music;
  final bool largeText;

  ChildSettingsSnapshot copyWith({
    ChildDifficulty? difficulty,
    bool? sound,
    bool? music,
    bool? largeText,
  }) => ChildSettingsSnapshot(
    difficulty: difficulty ?? this.difficulty,
    sound: sound ?? this.sound,
    music: music ?? this.music,
    largeText: largeText ?? this.largeText,
  );
}

class ChildSettingsScreen extends StatefulWidget {
  const ChildSettingsScreen({
    super.key,
    required this.childCode,
    required this.initialSettings,
    required this.onSettingsChanged,
    required this.onSwitchAudience,
  });

  final String childCode;
  final ChildSettingsSnapshot initialSettings;
  final ValueChanged<ChildSettingsSnapshot> onSettingsChanged;
  final VoidCallback onSwitchAudience;

  @override
  State<ChildSettingsScreen> createState() => _ChildSettingsScreenState();
}

class _ChildSettingsScreenState extends State<ChildSettingsScreen> {
  late ChildSettingsSnapshot _settings = widget.initialSettings;

  void _update(ChildSettingsSnapshot next) {
    setState(() => _settings = next);
    widget.onSettingsChanged(next);
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.childCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('ID ребёнка скопирован')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              children: [
                Row(
                  children: [
                    BackCircleButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Настройки',
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 28,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _Section(
                  title: 'Профиль ребёнка',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'ID для подключения родителя',
                        style: TextStyle(color: AppColors.inkMuted),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              widget.childCode,
                              style: const TextStyle(
                                fontSize: 22,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Скопировать ID',
                            onPressed: _copyCode,
                            icon: const Icon(Icons.copy_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Передайте этот ID родителю. Он увидит учебный прогресс и темы для повторения.',
                        style: TextStyle(
                          height: 1.35,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Section(
                  title: 'Обучение',
                  child: DropdownButtonFormField<ChildDifficulty>(
                    initialValue: _settings.difficulty,
                    decoration: const InputDecoration(
                      labelText: 'Сложность заданий',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ChildDifficulty.beginner,
                        child: Text('Начинающий · больше подсказок'),
                      ),
                      DropdownMenuItem(
                        value: ChildDifficulty.advanced,
                        child: Text('Продвинутый · больше условий'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _update(_settings.copyWith(difficulty: value));
                      }
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _Section(
                  title: 'Приложение',
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Звуки'),
                        value: _settings.sound,
                        onChanged: (value) =>
                            _update(_settings.copyWith(sound: value)),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Музыка'),
                        value: _settings.music,
                        onChanged: (value) =>
                            _update(_settings.copyWith(music: value)),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Крупный текст'),
                        subtitle: const Text(
                          'Увеличивает текст в учебных экранах',
                        ),
                        value: _settings.largeText,
                        onChanged: (value) =>
                            _update(_settings.copyWith(largeText: value)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: widget.onSwitchAudience,
                  icon: const Icon(Icons.switch_account_outlined),
                  label: const Text('Сменить пользователя'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: const BorderSide(color: AppColors.fieldBorder),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.cardTitle.copyWith(fontSize: 20)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
