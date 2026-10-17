// Local visual preview; never imported by the production entry point.
// flutter run -d chrome -t tool/preview_day_summary.dart
// Optional URL parameters: ?fur=red|white|striped&success=true&largeText=true
import 'package:flutter/material.dart';

import 'package:andromeda_app/day_summary/day_summary.dart';
import 'package:andromeda_app/day_summary/day_summary_screen.dart';
import 'package:andromeda_app/home/models/pet.dart';
import 'package:andromeda_app/theme/app_theme.dart';

void main() {
  final params = Uri.base.queryParameters;
  final success = params['success'] == 'true';
  final fur = switch (params['fur']) {
    'red' => 'FUR_ORANGE',
    'white' => 'FUR_WHITE',
    _ => 'FUR_GRAY',
  };
  final summary = DaySummary(
    periodId: 'local-mirror-preview',
    sequenceNo: 4,
    earnedAmount: 42,
    plan: const DaySummaryAmounts(need: 10, want: 5, savings: 15),
    actual: DaySummaryAmounts(
      need: success ? 10 : 0,
      want: success ? 5 : 15,
      savings: 15,
    ),
    needCovered: success,
    planFollowed: success,
    feedback: success
        ? 'Ты молодец! Сегодня получилось позаботиться о Грошике и своей мечте.'
        : 'Сегодня план и действия немного разошлись. Завтра попробуем ещё раз!',
    recommendations: success
        ? const []
        : const ['Сначала закрой обязательные траты на питомца.'],
  );
  runApp(
    MaterialApp(
      title: 'Грошик · Волшебное зеркало',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(params['largeText'] == 'true' ? 2 : 1),
        ),
        child: ColoredBox(
          color: AppColors.parchmentDark,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: child,
            ),
          ),
        ),
      ),
      home: Builder(
        builder: (context) => DaySummaryScreen(
          summary: summary,
          pet: Pet(
            name: 'Грошик',
            furOptionId: fur,
            accessoryOptionId: null,
            satiety: 65,
            joy: 75,
            health: 100,
            evolutionStage: 1,
          ),
          onContinue: () => ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Просмотр завершён'))),
        ),
      ),
    ),
  );
}
