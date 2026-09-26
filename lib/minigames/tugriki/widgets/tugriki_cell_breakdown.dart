import 'package:flutter/material.dart';

import '../../../onboarding/widgets/story_button.dart';
import '../../../theme/app_theme.dart';
import '../tugriki_game_data.dart';

class TugrikiCellBreakdown extends StatefulWidget {
  const TugrikiCellBreakdown({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  State<TugrikiCellBreakdown> createState() => _TugrikiCellBreakdownState();
}

class _TugrikiCellBreakdownState extends State<TugrikiCellBreakdown> {
  // 6 ячеек: false = пустая, true = заполнена 2 монетками
  final List<bool> _cells = List.filled(6, false);

  int get _filledCount => _cells.where((c) => c).length;
  bool get _isAllFilled => _filledCount == 6;

  void _fillNext() {
    final nextIndex = _cells.indexOf(false);
    if (nextIndex != -1) {
      setState(() {
        _cells[nextIndex] = true;
      });
    }
  }

  void _fillCell(int index) {
    if (!_cells[index]) {
      setState(() {
        _cells[index] = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.fieldBorder, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F3B2F27),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Image.asset(TugrikiAssets.catStriped, width: 44, height: 44),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'За один тугрик нужны две монетки. Давай разложим монетки по 6 тугрикам!',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 15,
                      color: AppColors.ink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Сетка из 6 ячеек (3x2)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.15,
              ),
              itemBuilder: (context, index) {
                final isFilled = _cells[index];
                return InkWell(
                  onTap: () => _fillCell(index),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isFilled
                          ? AppColors.parchmentDark
                          : AppColors.parchment.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isFilled
                            ? AppColors.crimson
                            : AppColors.fieldBorder,
                        width: isFilled ? 2.0 : 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Тугрик ${index + 1}',
                          style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 12,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (isFilled)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                TugrikiAssets.homeCoin,
                                width: 22,
                                height: 22,
                              ),
                              const SizedBox(width: 2),
                              Image.asset(
                                TugrikiAssets.homeCoin,
                                width: 22,
                                height: 22,
                              ),
                            ],
                          )
                        else
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.touch_app_outlined,
                                size: 20,
                                color: AppColors.crimsonFaded,
                              ),
                              SizedBox(width: 2),
                              Text(
                                '+2',
                                style: TextStyle(
                                  fontFamily: AppFonts.body,
                                  fontSize: 13,
                                  color: AppColors.inkMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        Text(
                          isFilled ? '= 2 монетки' : 'нажми сюда',
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 11,
                            fontWeight: isFilled
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isFilled
                                ? AppColors.crimsonDark
                                : AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            if (!_isAllFilled) ...[
              TextButton.icon(
                onPressed: _fillNext,
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.crimson,
                ),
                label: Text(
                  'Положить 2 монетки в ячейку ($_filledCount/6)',
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 16,
                    color: AppColors.crimson,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.leafGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.leafGreen, width: 1.5),
                ),
                child: const Column(
                  children: [
                    Text(
                      '2 + 2 + 2 + 2 + 2 + 2 = 12',
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.leafGreen,
                        letterSpacing: 1.1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Шесть тугриков — это ровно двенадцать монеток!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 14,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              StoryButton(
                label: 'Попробовать ещё раз',
                expand: true,
                onPressed: widget.onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
