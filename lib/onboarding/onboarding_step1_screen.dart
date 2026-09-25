import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'onboarding_data.dart';
import 'widgets/drop_cap_story.dart';
import 'widgets/fur_color_picker.dart';
import 'widgets/inline_name_field.dart';
import 'widgets/onboarding_paper_background.dart';
import 'widgets/onboarding_scene.dart';
import 'widgets/step_progress.dart';
import 'widgets/story_button.dart';

const _totalOnboardingSteps = 4;

/// Onboarding step 1 of 4. The child names their pet and picks a fur color,
/// told as a fairy-tale sentence. Tapping "Далее" awaits [onNext], which
/// creates or updates the pet server-side (see onboarding_flow.dart) — this
/// screen owns the loading/error UI so a network failure never silently eats
/// the tap.
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
      backgroundColor: AppColors.canvas,
      body: OnboardingPaperBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sceneHeight = (constraints.maxHeight * 0.42).clamp(
              240.0,
              410.0,
            );
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: sceneHeight,
                          child: OnboardingScene(
                            background: 'assets/backgrounds/town.png',
                            foreground:
                                'assets/backgrounds/meadow_foreground.png',
                            // Base pose until a colour is chosen, then the cat
                            // in that coat so the choice is reflected at once.
                            cat: catAssetForFur(_data.furColorId),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.lg,
                            AppSpacing.xl,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _StoryParagraph(
                                data: _data,
                                nameController: _nameController,
                                onNameChanged: (value) => setState(
                                  () => _data = _data.copyWith(petName: value),
                                ),
                                onFurSelected: (id) => setState(
                                  () => _data = _data.copyWith(furColorId: id),
                                ),
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.swatchLabel.copyWith(
                                    color: AppColors.crimson,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const StepProgress(
                          currentStep: 1,
                          totalSteps: _totalOnboardingSteps,
                        ),
                        const SizedBox(height: AppSpacing.sm),
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
              ],
            );
          },
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
        const DropCapStory(
          dropCap: 'В',
          firstLine: 'одном сказочном городе жил добрый и любопытный котёнок.',
          rest: '',
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Как его зовут?', style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.xs),
        InlineNameField(controller: nameController, onChanged: onNameChanged),
        const SizedBox(height: AppSpacing.lg),
        Text('Выбери цвет шёрстки', style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Питомец сразу появится в выбранном образе.',
          style: AppTextStyles.supporting,
        ),
        const SizedBox(height: AppSpacing.sm),
        FurColorPicker(selectedId: data.furColorId, onSelected: onFurSelected),
      ],
    );
  }
}
