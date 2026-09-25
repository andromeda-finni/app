import 'package:flutter/material.dart';

import '../core/api_client.dart';

/// User-facing description of an economy operation before it reaches the
/// server. The server remains the source of truth for every balance change.
final class EconomyConfirmation {
  const EconomyConfirmation({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.details = const [],
  });

  final String title;
  final String message;
  final String confirmLabel;
  final List<String> details;
}

Future<bool> showEconomyConfirmation(
  BuildContext context,
  EconomyConfirmation confirmation,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(confirmation.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(confirmation.message),
            if (confirmation.details.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final detail in confirmation.details) ...[
                Text(detail),
                const SizedBox(height: 6),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmation.confirmLabel),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

String economyErrorMessage(ApiException error) => switch (error.code) {
  'financial_goal_required' =>
    'Сначала выбери мечту, на которую будешь копить.',
  'goal_change_not_allowed' =>
    'Выбранную мечту нельзя сменить до получения артефакта.',
  'artifact_already_owned' =>
    'Этот артефакт у тебя уже есть. Выбери другую мечту.',
  'chest_already_matured_use_collect' =>
    'Сундук уже созрел! Забери монеты вместе с бонусом.',
  'chest_not_matured_yet' =>
    'Сундук ещё не созрел. Дождись срока или открой без бонуса.',
  'active_chest_not_found' => 'Сундук уже закрыт. Баланс обновлён.',
  'achieved_goal_not_found' =>
    'Цель уже изменилась. Проверь обновлённое состояние.',
  'required_need_not_covered' =>
    'Сначала оплати обязательные траты из раздела «Надо».',
  'active_event_must_be_resolved' =>
    'Перед завершением дня нужно решить случайное событие.',
  'food_reserve_is_unavailable_for_wants' ||
  'food_reserve_is_unavailable_for_frost' ||
  'food_reserve_is_unavailable_for_savings' =>
    'Эти монеты пока нужны для обязательных трат.',
  'insufficient_funds' => 'Не хватает монет для этого действия.',
  'active_day_with_confirmed_plan_required' =>
    'Сначала начни игровой день и утверди план.',
  'daily_quest_reward_limit_reached' =>
    'Лимит наград за квесты на сегодня уже достигнут.',
  'idempotency_conflict' =>
    'Операция уже обрабатывается. Обнови экран и проверь баланс.',
  'unauthorized' => 'Сессия закончилась. Войди в приложение снова.',
  'standard_profile_required' => 'Экономика работает только в обычном профиле.',
  'network_error' => 'Нет связи с сервером. Проверь подключение и обнови баланс перед повтором операции.',
  _ => 'Не получилось выполнить действие. Обнови экран и проверь состояние.',
};

void showEconomySuccess(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
