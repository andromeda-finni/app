import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.currentStep, required this.totalSteps});

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalSteps, (index) {
            final isActive = index == currentStep - 1;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? AppColors.crimson : Colors.transparent,
                border: Border.all(
                  color: isActive ? AppColors.crimson : AppColors.fieldBorder,
                  width: 1.4,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text('$currentStep из $totalSteps', style: AppTextStyles.stepCounter),
      ],
    );
  }
}
