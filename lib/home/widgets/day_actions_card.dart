import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models/active_period.dart';
import '../models/active_pet_event.dart';

class DayActionsCard extends StatelessWidget {
  const DayActionsCard({
    super.key,
    required this.period,
    required this.event,
    required this.spendable,
    required this.busy,
    required this.onResolveEvent,
    required this.onOpenShop,
    required this.onCloseDay,
    this.error,
  });

  final ActivePeriod period;
  final ActivePetEvent? event;
  final int spendable;
  final bool busy;
  final String? error;
  final VoidCallback onResolveEvent;
  final VoidCallback onOpenShop;
  final VoidCallback onCloseDay;

  @override
  Widget build(BuildContext context) {
    final currentEvent = event;
    final confirmed = period.isConfirmed;
    final reserve = period.remainingReserve;

    late final IconData icon;
    late final String title;
    late final String message;
    late final String action;
    late final VoidCallback? onPressed;

    if (currentEvent != null) {
      icon = Icons.healing_outlined;
      title = currentEvent.title;
      message =
          '${currentEvent.description}. Для помощи нужно ${currentEvent.amountDue} монет.';
      action = 'Помочь за ${currentEvent.amountDue} монет';
      onPressed = !busy && spendable >= currentEvent.amountDue
          ? onResolveEvent
          : null;
    } else if (!confirmed) {
      return const SizedBox.shrink();
    } else if (reserve > 0) {
      icon = Icons.shopping_basket_outlined;
      title = 'Сначала позаботься о питомце';
      message = 'На обязательные покупки осталось потратить $reserve монет.';
      action = 'Открыть магазин';
      onPressed = busy ? null : onOpenShop;
    } else {
      icon = Icons.nightlight_round;
      title = 'День можно завершить';
      message = 'Обязательные траты закрыты. Итоги сохранятся в истории.';
      action = 'Завершить день';
      onPressed = busy ? null : onCloseDay;
    }

    return Container(
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
              Icon(icon, color: AppColors.crimson, size: 26),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppTextStyles.cardTitle)),
            ],
          ),
          const SizedBox(height: 10),
          Text(message, style: AppTextStyles.supporting),
          if (currentEvent != null && spendable < currentEvent.amountDue) ...[
            const SizedBox(height: 8),
            Text(
              'Не хватает ${currentEvent.amountDue - spendable} монет. Выполни задание на карте.',
              style: AppTextStyles.supporting.copyWith(
                color: AppColors.crimson,
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: AppTextStyles.supporting.copyWith(
                color: AppColors.crimson,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.crimson,
                disabledBackgroundColor: AppColors.crimson.withValues(
                  alpha: 0.35,
                ),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(action, style: AppTextStyles.button),
            ),
          ),
        ],
      ),
    );
  }
}
