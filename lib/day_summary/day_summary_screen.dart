import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'day_summary.dart';

class DaySummaryScreen extends StatelessWidget {
  const DaySummaryScreen({
    super.key,
    required this.summary,
    required this.onContinue,
  });

  final DaySummary summary;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.parchment,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
            child: Column(
              children: [
                _FairytaleTitle(dayNumber: summary.sequenceNo),
                const SizedBox(height: 20),
                _Mirror(summary: summary),
                const SizedBox(height: 18),
                _FeedbackCard(summary: summary),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.crimson,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      elevation: 2,
                    ),
                    child: Text('Продолжить', style: AppTextStyles.button),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FairytaleTitle extends StatelessWidget {
  const _FairytaleTitle({required this.dayNumber});

  final int dayNumber;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/icons/leaf.png', width: 25, height: 25),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              'Свет мой, зеркальце, скажи…',
              textAlign: TextAlign.center,
              style: AppTextStyles.eventTitle.copyWith(fontSize: 28),
            ),
          ),
          const SizedBox(width: 9),
          Transform.flip(
            flipX: true,
            child: Image.asset('assets/icons/leaf.png', width: 25, height: 25),
          ),
        ],
      ),
      const SizedBox(height: 7),
      Text(
        dayNumber > 0
            ? 'Вот каким получился день $dayNumber'
            : 'Вот каким получился день',
        style: AppTextStyles.supporting,
      ),
    ],
  );
}

class _Mirror extends StatelessWidget {
  const _Mirror({required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Итоги дня. Заработано ${summary.earnedAmount} монет. План и фактические траты.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(42),
          gradient: const LinearGradient(
            colors: [Color(0xFFD4A64A), Color(0xFFF3DC92), Color(0xFFB77A24)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(37),
          child: Stack(
            children: [
              const Positioned.fill(child: _CloudedGlass()),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 22, 14, 24),
                child: Column(
                  children: [
                    _EarnedMedallion(amount: summary.earnedAmount),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _AmountsColumn(
                            title: 'Планировали',
                            amounts: summary.plan,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _AmountsColumn(
                            title: 'Получилось',
                            amounts: summary.actual,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloudedGlass extends StatelessWidget {
  const _CloudedGlass();

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFB8D9E5), Color(0xFF7EAEC2), Color(0xFFAED0DA)],
            ),
          ),
        ),
      ),
      Positioned(
        left: -35,
        top: 35,
        child: _Haze(size: 170, color: Colors.white.withValues(alpha: 0.24)),
      ),
      Positioned(
        right: -25,
        bottom: 10,
        child: _Haze(
          size: 150,
          color: const Color(0xFFDDEEF3).withValues(alpha: 0.28),
        ),
      ),
      Positioned.fill(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: ColoredBox(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
    ],
  );
}

class _Haze extends StatelessWidget {
  const _Haze({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _EarnedMedallion extends StatelessWidget {
  const _EarnedMedallion({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.cardBg.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFD4A64A), width: 1.5),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Заработано',
            style: AppTextStyles.swatchLabel.copyWith(color: AppColors.ink),
          ),
          const SizedBox(width: 8),
          Image.asset('assets/icons/coin.png', width: 23, height: 23),
          const SizedBox(width: 5),
          Text('$amount', style: AppTextStyles.counterValue),
        ],
      ),
    ),
  );
}

class _AmountsColumn extends StatelessWidget {
  const _AmountsColumn({required this.title, required this.amounts});

  final String title;
  final DaySummaryAmounts amounts;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        textAlign: TextAlign.center,
        style: AppTextStyles.sectionTitle.copyWith(
          color: AppColors.crimsonDark,
        ),
      ),
      const SizedBox(height: 12),
      _AmountLine(label: 'Надо', hint: 'еда и лечение', amount: amounts.need),
      const SizedBox(height: 11),
      _AmountLine(
        label: 'Хочу',
        hint: 'игрушки и сладости',
        amount: amounts.want,
      ),
      const SizedBox(height: 11),
      _AmountLine(label: 'Копилка', hint: 'на мечту', amount: amounts.savings),
    ],
  );
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({
    required this.label,
    required this.hint,
    required this.amount,
  });

  final String label;
  final String hint;
  final int amount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.36),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(
          label,
          style: AppTextStyles.cardRowLabel,
          textAlign: TextAlign.center,
        ),
        Text(
          hint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.stepCounter.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icons/coin.png', width: 19, height: 19),
            const SizedBox(width: 5),
            Text(
              '$amount',
              style: AppTextStyles.counterValue.copyWith(fontSize: 20),
            ),
          ],
        ),
      ],
    ),
  );
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final accent = summary.planFollowed
        ? AppColors.leafGreen
        : AppColors.crimson;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Column(
        children: [
          Icon(
            summary.planFollowed ? Icons.auto_awesome : Icons.favorite_outline,
            color: accent,
            size: 28,
          ),
          const SizedBox(height: 9),
          Text(
            summary.feedback,
            textAlign: TextAlign.center,
            style: AppTextStyles.story.copyWith(fontWeight: FontWeight.w700),
          ),
          if (summary.recommendations.isNotEmpty) ...[
            const SizedBox(height: 11),
            Text(
              summary.recommendations.first,
              textAlign: TextAlign.center,
              style: AppTextStyles.supporting,
            ),
          ],
        ],
      ),
    );
  }
}
