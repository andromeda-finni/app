import 'package:flutter/material.dart';

import '../core/api_client.dart';
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
    this.apiClient,
    required this.initialSettings,
    required this.onSettingsChanged,
    required this.onSwitchAudience,
  });

  /// Talks to the server for the parent link; null only in isolated tests.
  final ApiClient? apiClient;
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
                  title: 'Родитель',
                  child: _ParentLinkSection(apiClient: widget.apiClient),
                ),
                const SizedBox(height: 14),
                _Section(
                  title: 'Обучение',
                  child: DropdownButtonFormField<ChildDifficulty>(
                    initialValue: _settings.difficulty,
                    // Without isExpanded the field sizes to its longest label
                    // and overflows the card instead of wrapping inside it.
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Сложность заданий',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ChildDifficulty.beginner,
                        child: Text(
                          'Начинающий · больше подсказок',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: ChildDifficulty.advanced,
                        child: Text(
                          'Продвинутый · больше условий',
                          overflow: TextOverflow.ellipsis,
                        ),
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
    // The card colour lives on a Material rather than a DecoratedBox: the
    // switches and tiles inside paint their ink on the nearest Material, and a
    // coloured box in between would hide every tap highlight.
    return Material(
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.fieldBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTextStyles.cardTitle.copyWith(fontSize: 20)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Links this child to a parent: the parent gets a one-time code in their
/// cabinet and the child enters it here. Status always comes from the server.
class _ParentLinkSection extends StatefulWidget {
  const _ParentLinkSection({required this.apiClient});

  final ApiClient? apiClient;

  @override
  State<_ParentLinkSection> createState() => _ParentLinkSectionState();
}

class _ParentLinkSectionState extends State<_ParentLinkSection> {
  final _controller = TextEditingController();
  bool? _linked;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final api = widget.apiClient;
    if (api == null) return;
    try {
      final status = await api.get('/child/parent-link');
      if (mounted) setState(() => _linked = status['linked'] == true);
    } on ApiException {
      if (mounted) {
        setState(() => _message = 'Не удалось проверить подключение.');
      }
    }
  }

  Future<void> _redeem() async {
    final api = widget.apiClient;
    // Parents may read the code with a hyphen or spaces; only letters and
    // digits are part of it.
    final code = _controller.text.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    if (api == null || code.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await api.post('/child/parent-link/redeem', body: {'inviteCode': code});
      if (!mounted) return;
      setState(() {
        _linked = true;
        _controller.clear();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(
        () => _message = switch (error.code) {
          'invite_code_invalid_or_expired' =>
            'Код не подошёл или устарел. Попроси родителя получить новый.',
          'already_linked_to_this_parent' => 'Этот родитель уже подключён.',
          _ when error.isNetworkError =>
            'Нет связи с сервером. Попробуй ещё раз.',
          _ => 'Не получилось подключить. Попробуй ещё раз.',
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_linked == true) {
      return const Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.leafGreen),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Родитель подключён и видит твой прогресс.',
              style: TextStyle(color: AppColors.ink),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Попроси родителя открыть «Кабинет родителя» и получить код. '
          'Введи его здесь — и он сможет следить за твоими успехами.',
          style: TextStyle(height: 1.35, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('parent-invite-code-field'),
          controller: _controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Код от родителя',
            hintText: 'Например, 6B9B-EBHW',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _redeem(),
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!, style: const TextStyle(color: AppColors.crimson)),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _redeem,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.crimson,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text('Подключить родителя'),
        ),
      ],
    );
  }
}
