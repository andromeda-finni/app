import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'onboarding_data.dart';
import 'onboarding_step1_screen.dart';
import 'onboarding_step2_screen.dart';
import 'onboarding_step3_screen.dart';
import 'onboarding_step4_screen.dart';

/// Hosts the 4-step onboarding as a simple push/pop navigation stack, so
/// "back" always returns to the same still-alive previous step (nothing
/// entered is lost). [onFinished] fires with the fully collected data once
/// the child taps "Начать игру" on step 4.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onFinished});

  final ValueChanged<OnboardingData> onFinished;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  OnboardingData _data = OnboardingData();

  @override
  Widget build(BuildContext context) {
    return OnboardingStep1Screen(
      initialData: _data,
      onNext: (data) {
        setState(() => _data = data);
        Navigator.of(context).push(MaterialPageRoute(builder: _buildStep2));
      },
    );
  }

  Widget _buildStep2(BuildContext context) {
    return OnboardingStep2Screen(
      onBack: () => Navigator.of(context).pop(),
      onNext: () => Navigator.of(context).push(MaterialPageRoute(builder: _buildStep3)),
    );
  }

  Widget _buildStep3(BuildContext context) {
    return OnboardingStep3Screen(
      initialData: _data,
      onBack: () => Navigator.of(context).pop(),
      onNext: (data) {
        setState(() => _data = data);
        Navigator.of(context).push(MaterialPageRoute(builder: _buildStep4));
      },
    );
  }

  Widget _buildStep4(BuildContext context) {
    return OnboardingStep4Screen(
      onBack: () => Navigator.of(context).pop(),
      onFinish: () => widget.onFinished(_data),
    );
  }
}

/// Placeholder shown after onboarding finishes, until account creation +
/// the real pet home screen are wired up (see backend/README.md — creating
/// a child account currently requires a parent invite code, which isn't
/// part of this 4-step flow yet; that ordering is still an open question).
class OnboardingCompletePlaceholder extends StatelessWidget {
  const OnboardingCompletePlaceholder({super.key, required this.data});

  final OnboardingData data;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Онбординг завершён!\n\n'
            'Питомец: ${data.petName} (${data.furColorId})\n'
            'Конфеты: ${data.candyAmount}, Другие вещи: ${data.otherAmount}, Копилка: ${data.piggyAmount}\n\n'
            'Дальше — создание аккаунта и сохранение токена (см. заметку в onboarding_flow.dart).',
            textAlign: TextAlign.center,
            style: AppTextStyles.story,
          ),
        ),
      ),
    );
  }
}
