import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.currentStep, required this.totalSteps});

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalSteps, (index) {
            final stepNo = index + 1;
            final Color color;
            final Color borderColor;
            if (stepNo == currentStep) {
              color = AppColors.crimson;
              borderColor = AppColors.crimson;
            } else if (stepNo < currentStep) {
              color = AppColors.crimsonFaded;
              borderColor = AppColors.crimsonFaded;
            } else {
              color = Colors.transparent;
              borderColor = AppColors.fieldBorder;
            }
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: borderColor, width: 1.4),
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
