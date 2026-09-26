import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../tugriki_game_data.dart';

class TugrikiRateVisualizer extends StatefulWidget {
  const TugrikiRateVisualizer({super.key, this.compact = false});

  final bool compact;

  @override
  State<TugrikiRateVisualizer> createState() => _TugrikiRateVisualizerState();
}

class _TugrikiRateVisualizerState extends State<TugrikiRateVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.parchmentDark.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.fieldBorder, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(TugrikiAssets.foreignMoneyFront, width: 26, height: 26),
            const SizedBox(width: 6),
            const Text(
              '1 тугрик =',
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 6),
            Image.asset(TugrikiAssets.homeCoin, width: 22, height: 22),
            Image.asset(TugrikiAssets.homeCoin, width: 22, height: 22),
            const SizedBox(width: 4),
            const Text(
              '2 монетки',
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.crimson,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.crimson.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'КУРС ОБМЕНА ВАЛЮТ',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 15,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 2 монетки
              Column(
                children: [
                  Row(
                    children: [
                      Image.asset(
                        TugrikiAssets.homeCoin,
                        width: 44,
                        height: 44,
                      ),
                      const SizedBox(width: 4),
                      Image.asset(
                        TugrikiAssets.homeCoin,
                        width: 44,
                        height: 44,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '2 монетки',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                  const Text(
                    '(наши деньги)',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 13,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Icon(
                      Icons.swap_horiz_rounded,
                      size: 36,
                      color: AppColors.crimson,
                    ),
                    Text(
                      'равны',
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 13,
                        color: AppColors.crimson,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // 1 тугрик
              Column(
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Image.asset(
                      TugrikiAssets.foreignMoneyFront,
                      width: 50,
                      height: 50,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '1 тугрик',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.crimson,
                    ),
                  ),
                  const Text(
                    '(чужая валюта)',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 13,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
