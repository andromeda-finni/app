import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../economy/economy_action_ui.dart';
import '../theme/app_theme.dart';
import 'day_summary.dart';
import 'day_summary_screen.dart';

class DayEndAction extends StatefulWidget {
  const DayEndAction({
    super.key,
    required this.apiClient,
    required this.periodId,
    required this.onCompleted,
  });

  final ApiClient apiClient;
  final String periodId;
  final Future<void> Function() onCompleted;

  @override
  State<DayEndAction> createState() => _DayEndActionState();
}

class _DayEndActionState extends State<DayEndAction> {
  bool _busy = false;
  String? _error;

  Future<void> _closeDay() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.apiClient.post(
        '/periods/${widget.periodId}/close',
      );
      final summary = DaySummary.fromJson(response);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (routeContext) => DaySummaryScreen(
            summary: summary,
            onContinue: () => Navigator.of(routeContext).pop(),
          ),
        ),
      );
      if (mounted) await widget.onCompleted();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = economyErrorMessage(error));
    } on FormatException {
      if (mounted) {
        setState(
          () => _error = 'День завершён, но итог не загрузился. Нажми ещё раз, чтобы восстановить его.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.nightlight_round,
              color: AppColors.crimson,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('Итоги дня', style: AppTextStyles.cardTitle)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Загляни в волшебное зеркало и сравни план с тем, как прошёл день.',
          style: AppTextStyles.supporting,
        ),
        if (_error != null) ...[
          const SizedBox(height: 9),
          Text(
            _error!,
            style: AppTextStyles.swatchLabel.copyWith(color: AppColors.crimson),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _busy ? null : _closeDay,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.crimson,
              disabledBackgroundColor: AppColors.crimson.withValues(
                alpha: 0.35,
              ),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text('Завершить день', style: AppTextStyles.button),
          ),
        ),
      ],
    ),
  );
}
