import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'onboarding_data.dart';
import 'widgets/fur_color_picker.dart';
import 'widgets/inline_name_field.dart';
import 'widgets/onboarding_illustration.dart';
import 'widgets/step_progress.dart';
import 'widgets/story_button.dart';

const _totalOnboardingSteps = 4;

/// Onboarding step 1 of 4 — shown when no child pet exists on this device
/// yet (no saved auth token, see core/auth_storage.dart). The child names
/// their pet and picks a fur color, told as a fairy-tale sentence.
class OnboardingStep1Screen extends StatefulWidget {
  const OnboardingStep1Screen({super.key, required this.onNext, this.initialData});

  final ValueChanged<OnboardingData> onNext;
  final OnboardingData? initialData;

  @override
  State<OnboardingStep1Screen> createState() => _OnboardingStep1ScreenState();
}

class _OnboardingStep1ScreenState extends State<OnboardingStep1Screen> {
  late final TextEditingController _nameController;
  late OnboardingData _data;

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

  bool get _canContinue => _data.petName.trim().isNotEmpty && _data.furColorId != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: Column(
        children: [
          Expanded(child: OnboardingIllustration(stepNumber: 1)),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.parchment,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StoryParagraph(
                      data: _data,
                      nameController: _nameController,
                      onNameChanged: (value) => setState(() => _data = _data.copyWith(petName: value)),
                      onFurSelected: (id) => setState(() => _data = _data.copyWith(furColorId: id)),
                    ),
                    const SizedBox(height: 24),
                    const StepProgress(currentStep: 1, totalSteps: _totalOnboardingSteps),
                    const SizedBox(height: 20),
                    StoryButton(
                      label: 'Далее',
                      onPressed: _canContinue ? () => widget.onNext(_data) : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('В', style: AppTextStyles.dropCap),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('одном государстве жил котёнок по имени', style: AppTextStyles.story),
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
                child: InlineNameField(controller: nameController, onChanged: onNameChanged),
              ),
              const TextSpan(text: '. Он был '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: FurColorPicker(selectedId: data.furColorId, onSelected: onFurSelected),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('и был очень-очень любопытен, игрив и добр.', style: AppTextStyles.story),
      ],
    );
  }
}
