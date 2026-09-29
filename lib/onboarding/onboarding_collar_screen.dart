import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'onboarding_data.dart';
import 'widgets/collar_color_picker.dart';
import 'widgets/fur_color_picker.dart';
import 'widgets/onboarding_scene.dart';
import 'widgets/onboarding_step_scaffold.dart';

/// The second visual onboarding screen. It is part of creating the pet rather
/// than a new server-side tutorial milestone, so existing progress remains
/// compatible while the selected collar is still persisted in `/pet`.
class OnboardingCollarScreen extends StatefulWidget {
  const OnboardingCollarScreen({
    super.key,
    required this.initialData,
    required this.onBack,
    required this.onNext,
  });

  final OnboardingData initialData;
  final ValueChanged<OnboardingData> onBack;
  final Future<void> Function(OnboardingData data) onNext;

  @override
  State<OnboardingCollarScreen> createState() => _OnboardingCollarScreenState();
}

class _OnboardingCollarScreenState extends State<OnboardingCollarScreen> {
  late OnboardingData _data = widget.initialData;
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _continue() async {
    if (_data.collarColorId == null || _submitting) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await widget.onNext(_data);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Не получилось сохранить ошейник. Проверьте связь и попробуйте ещё раз.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedName = _data.petName.trim();
    final petName = savedName.isEmpty ? 'Котёнок' : savedName;
    return OnboardingStepScaffold(
      stepNumber: 2,
      topMinFraction: 0.50,
      top: OnboardingScene(
        background: 'assets/backgrounds/town.webp',
        foreground: 'assets/backgrounds/meadow_foreground.webp',
        cat: catAssetForFur(
          _data.furColorId,
          collarColorId: _data.collarColorId,
        ),
        catAlignment: const Alignment(0.1, 0.88),
        catHeightFraction: 0.58,
      ),
      onBack: () => widget.onBack(_data),
      onNext: _continue,
      nextLabel: 'Далее',
      nextLoading: _submitting,
      nextEnabled: _data.collarColorId != null && !_submitting,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Выбери ошейник', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$petName будет носить его в игре. Нажми на цвет — ошейник сразу изменится.',
            style: AppTextStyles.supporting,
          ),
          const SizedBox(height: AppSpacing.md),
          CollarColorPicker(
            selectedId: _data.collarColorId,
            onSelected: (id) =>
                setState(() => _data = _data.copyWith(collarColorId: id)),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage!,
              style: AppTextStyles.swatchLabel.copyWith(
                color: AppColors.crimson,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
