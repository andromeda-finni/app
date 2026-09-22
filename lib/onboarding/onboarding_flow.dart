import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'onboarding_data.dart';
import 'onboarding_step1_screen.dart';

/// Hosts the 4-step onboarding. Only step 1 is implemented; steps 2-4 are a
/// placeholder so the "Далее" flow has somewhere to go without crashing.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

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
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _ComingSoonStep(step: 2)),
        );
      },
    );
  }
}

class _ComingSoonStep extends StatelessWidget {
  const _ComingSoonStep({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: Center(
        child: Text('Шаг $step из 4 — скоро', style: AppTextStyles.story),
      ),
    );
  }
}
