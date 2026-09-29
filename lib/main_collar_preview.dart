import 'package:flutter/material.dart';

import 'onboarding/onboarding_collar_screen.dart';
import 'onboarding/onboarding_data.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const CollarPreviewApp());
}

class CollarPreviewApp extends StatelessWidget {
  const CollarPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: OnboardingCollarScreen(
        initialData: OnboardingData(
          petName: 'Грошик',
          furColorId: 'FUR_GRAY',
        ),
        onBack: (_) {},
        onNext: (_) async {},
      ),
    );
  }
}
