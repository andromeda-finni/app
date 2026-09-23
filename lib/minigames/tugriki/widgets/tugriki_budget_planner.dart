import 'package:flutter/material.dart';

import '../../../onboarding/widgets/story_button.dart';
import '../../../theme/app_theme.dart';
import '../tugriki_game_data.dart';

class TugrikiBudgetPlanner extends StatefulWidget {
  const TugrikiBudgetPlanner({
    super.key,
    required this.onComplete,
  });

  final void Function(int totalTugriki, int totalCoins, int change) onComplete;

  @override
  State<TugrikiBudgetPlanner> createState() => _TugrikiBudgetPlannerState();
}

class _TugrikiBudgetPlannerState extends State<TugrikiBudgetPlanner> {
  static const int kTotalBudgetCoins = 20;

  final List<MarketGood> _availableGoods = const [
    MarketCatalog.soup,
    MarketCatalog.juice,
    MarketCatalog.fruits,
    MarketCatalog.pie,
  ];

  final Set<String> _selectedGoodIds = <String>{};

  int get _totalTugriki {
    var sum = 0;
    for (final good in _availableGoods) {
      if (_selectedGoodIds.contains(good.id)) {
        sum += good.priceTugriki;
      }
    }
    return sum;
  }

  int get _totalCoins => _totalTugriki * kExchangeRate;
  int get _remainingCoins => kTotalBudgetCoins - _totalCoins;
  bool get _isOverBudget => _totalCoins > kTotalBudgetCoins;
  bool get _canAfford => _selectedGoodIds.isNotEmpty && !_isOverBudget;

  void _toggleGood(MarketGood good) {
    setState(() {
      if (_selectedGoodIds.contains(good.id)) {
        _selectedGoodIds.remove(good.id);
      } else {
        _selectedGoodIds.add(good.id);
      }
    });
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Шапка бюджета
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.parchmentDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset(TugrikiAssets.foreignMoneyBag, width: 34, height: 34),
                    const SizedBox(width: 8),
                    const Text(
                      'Бюджет друга:',
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Image.asset(TugrikiAssets.homeCoin, width: 22, height: 22),
                    const SizedBox(width: 4),
                    Text(
                      '$kTotalBudgetCoins монет',
                      style: const TextStyle(
                        fontFamily: AppFonts.family,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.crimsonDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Выбери товары для покупки (нажми, чтобы положить в корзину):',
            style: TextStyle(
              fontFamily: AppFonts.family,
              fontSize: 15,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 10),

          // Список товаров
          for (final good in _availableGoods) ...[
            _GoodSelectionRow(
              good: good,
              isSelected: _selectedGoodIds.contains(good.id),
              onTap: () => _toggleGood(good),
            ),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 12),

          // Калькулятор и статус корзины
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isOverBudget
                  ? AppColors.crimson.withValues(alpha: 0.1)
                  : (_canAfford
                      ? AppColors.leafGreen.withValues(alpha: 0.1)
                      : AppColors.parchment),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isOverBudget
                    ? AppColors.crimson
                    : (_canAfford ? AppColors.leafGreen : AppColors.fieldBorder),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Стоимость корзины:',
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      '$_totalTugriki тугриков = $_totalCoins монет',
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isOverBudget ? AppColors.crimson : AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Останется монет:',
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      '$_remainingCoins монет',
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _remainingCoins < 0
                            ? AppColors.crimson
                            : AppColors.leafGreen,
                      ),
                    ),
                  ],
                ),
                if (_isOverBudget) ...[
                  const SizedBox(height: 8),
                  Text(
                    '⚠️ Не хватает ${-_remainingCoins} монет! Убери какой-нибудь товар из корзины.',
                    style: const TextStyle(
                      fontFamily: AppFonts.family,
                      fontSize: 13,
                      color: AppColors.crimson,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          StoryButton(
            label: _canAfford
                ? 'Купить и помочь другу'
                : (_isOverBudget ? 'Превышен бюджет' : 'Выбери товары'),
            expand: true,
            onPressed: _canAfford
                ? () => widget.onComplete(_totalTugriki, _totalCoins, _remainingCoins)
                : null,
          ),
        ],
      ),
    );
  }
}

class _GoodSelectionRow extends StatelessWidget {
  const _GoodSelectionRow({
    required this.good,
    required this.isSelected,
    required this.onTap,
  });

  final MarketGood good;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.parchmentDark
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.crimson : AppColors.fieldBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              activeColor: AppColors.crimson,
              onChanged: (_) => onTap(),
            ),
            Text(
              good.iconEmoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    good.name,
                    style: const TextStyle(
                      fontFamily: AppFonts.family,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    '${good.priceTugriki} тугрика × 2 = ${good.priceCoins} монет',
                    style: const TextStyle(
                      fontFamily: AppFonts.family,
                      fontSize: 13,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.parchment,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: Row(
                children: [
                  Image.asset(TugrikiAssets.foreignMoneyFront, width: 18, height: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${good.priceTugriki}',
                    style: const TextStyle(
                      fontFamily: AppFonts.family,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.crimson,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
