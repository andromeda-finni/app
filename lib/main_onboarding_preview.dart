import 'package:flutter/material.dart';

import 'onboarding/onboarding_guide_preview.dart';
import 'onboarding/onboarding_data.dart';
import 'theme/app_theme.dart';

/// Isolated design candidate: no accounts, API calls or wallet mutations.
void main() {
  final page = (int.tryParse(Uri.base.queryParameters['page'] ?? '') ?? 0)
      .clamp(0, 7);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: OnboardingGuidePreview(
        initialPage: page,
        initialData: page == 0
            ? null
            : OnboardingData(
                petName: 'Грошик',
                furColorId: 'FUR_GRAY',
                collarColorId: 'ACC_COLLAR_RED',
              ),
      ),
    ),
  );
}
