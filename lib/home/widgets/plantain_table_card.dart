import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class PlantainTableCard extends StatelessWidget {
  const PlantainTableCard({
    super.key,
    required this.activeEvent,
    required this.activeInsurance,
    required this.onOpenInsurance,
    required this.onOpenEvent,
  });

  final Map<String, dynamic>? activeEvent;
  final Map<String, dynamic>? activeInsurance;
  final VoidCallback onOpenInsurance;
  final VoidCallback onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final event = activeEvent;
    final amount = (event?['amount_due'] as num?)?.toInt();
    final insured = activeInsurance != null;
    return Material(
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: const BorderSide(color: AppColors.fieldBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            minTileHeight: 68,
            leading: Image.asset(
              'assets/icons/leaf_small.png',
              width: 44,
              height: 44,
            ),
            title: Text('Стол подорожника', style: AppTextStyles.cardTitle),
            subtitle: Text(
              event == null
                  ? insured
                        ? 'Подорожник уже защищает следующий игровой день.'
                        : 'Подготовь подорожник для защиты следующего дня.'
                  : '${event['title'] ?? 'Питомцу нужна помощь'}${amount == null ? '' : ' · $amount монет'}',
              style: AppTextStyles.supporting,
            ),
            trailing: const Icon(Icons.chevron_right_rounded, size: 30),
            onTap: event == null ? onOpenInsurance : onOpenEvent,
          ),
          Container(
            height: 18,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF9A6037), Color(0xFF704126)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
