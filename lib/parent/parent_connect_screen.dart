import 'package:flutter/material.dart';

import '../onboarding/widgets/back_circle_button.dart';
import '../onboarding/widgets/story_button.dart';
import '../theme/app_theme.dart';
import 'parent_dashboard_screen.dart';

class ParentConnectScreen extends StatefulWidget {
  const ParentConnectScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<ParentConnectScreen> createState() => _ParentConnectScreenState();
}

class _ParentConnectScreenState extends State<ParentConnectScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _connect() {
    final code = _controller.text.trim().toUpperCase();
    if (code.replaceAll('-', '').length < 8) {
      setState(
        () => _error = 'Проверьте ID: в нём должно быть не меньше 8 знаков.',
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParentDashboardScreen(
          childCode: code,
          onExitToRoleChoice: () {
            Navigator.of(context).pop();
            widget.onBack();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: BackCircleButton(onPressed: widget.onBack),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Подключите профиль ребёнка',
                    style: TextStyle(
                      fontFamily: AppFonts.family,
                      fontSize: 30,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Попросите ребёнка открыть профиль. Уникальный ID находится в разделе «Настройки».',
                    style: AppTextStyles.story.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.fieldBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'ID ребёнка',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('parent-child-code-field'),
                          controller: _controller,
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          decoration: InputDecoration(
                            hintText: 'Например, GR-A12B-34CD',
                            errorText: _error,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.65),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.fieldBorder,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _connect(),
                        ),
                        const SizedBox(height: 16),
                        StoryButton(
                          label: 'Открыть кабинет',
                          onPressed: _connect,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.parchmentDark,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Пока нет ID? Вернитесь к выбору режима. Кабинет можно подключить позже.',
                      style: AppTextStyles.story.copyWith(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: widget.onBack,
                    child: const Text('Вернуться в первое меню'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
