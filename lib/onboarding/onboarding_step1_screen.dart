import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'onboarding_data.dart';
import 'widgets/fur_color_picker.dart';
import 'widgets/inline_name_field.dart';
import 'widgets/onboarding_fixed_layout.dart';
import 'widgets/onboarding_scene.dart';
import 'widgets/step_progress.dart';
import 'widgets/story_button.dart';

const _totalOnboardingSteps = 4;

/// Onboarding step 1 of 4 — shown when no pet exists yet for this account
/// (see main.dart's startup gate). The child names their pet and picks a
/// fur color, told as a fairy-tale sentence. Tapping "Далее" awaits
/// [onNext], which creates the account/pet server-side (see
/// onboarding_flow.dart) — this screen owns the loading/error UI for that
/// call so a network failure never silently eats the tap.
class OnboardingStep1Screen extends StatefulWidget {
  const OnboardingStep1Screen({
    super.key,
    required this.onNext,
    this.initialData,
  });

  final Future<void> Function(OnboardingData data) onNext;
  final OnboardingData? initialData;

  @override
  State<OnboardingStep1Screen> createState() => _OnboardingStep1ScreenState();
}

class _OnboardingStep1ScreenState extends State<OnboardingStep1Screen> {
  late final TextEditingController _nameController;
  late OnboardingData _data;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData ?? OnboardingData();
    _nameController = TextEditingController(text: _data.petName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      _data.petName.trim().isNotEmpty &&
      _data.furColorId != null &&
      !_submitting;

  Future<void> _handleNext() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await widget.onNext(_data);
      // On success the parent navigates away; this widget may already be
      // gone by the time we'd otherwise clear `_submitting` below.
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Не получилось сохранить питомца. Проверьте связь и попробуйте ещё раз.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: OnboardingFixedLayout(
        topMinFraction: 0.44,
        top: OnboardingScene(
          background: 'assets/backgrounds/town.png',
          // Base pose until a colour is chosen, then the cat in that coat —
          // the child sees the pet they are describing take shape as they
          // fill the sentence in.
          cat: catAssetForFur(_data.furColorId),
        ),
        bottom: Container(
          decoration: const BoxDecoration(
            color: AppColors.parchment,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StoryParagraph(
                    data: _data,
                    nameController: _nameController,
                    onNameChanged: (value) =>
                        setState(() => _data = _data.copyWith(petName: value)),
                    onFurSelected: (id) =>
                        setState(() => _data = _data.copyWith(furColorId: id)),
                  ),
                  const SizedBox(height: 14),
                  const StepProgress(
                    currentStep: 1,
                    totalSteps: _totalOnboardingSteps,
                  ),
                  const SizedBox(height: 12),
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.swatchLabel.copyWith(
                        color: AppColors.crimson,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  StoryButton(
                    label: 'Далее',
                    showFlourish: true,
                    isLoading: _submitting,
                    onPressed: _canContinue ? _handleNext : null,
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

class _StoryParagraph extends StatelessWidget {
  const _StoryParagraph({
    required this.data,
    required this.nameController,
    required this.onNameChanged,
    required this.onFurSelected,
  });

  final OnboardingData data;
  final TextEditingController nameController;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onFurSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('В', style: AppTextStyles.dropCap),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'одном государстве жил котёнок по имени',
                style: AppTextStyles.story,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            style: AppTextStyles.story,
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: InlineNameField(
                  controller: nameController,
                  onChanged: onNameChanged,
                ),
              ),
              const TextSpan(text: '. Он был '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: FurColorPicker(
                  selectedId: data.furColorId,
                  onSelected: onFurSelected,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'и был очень-очень любопытен, игрив и добр.',
          style: AppTextStyles.story,
        ),
      ],
    );
  }
}
