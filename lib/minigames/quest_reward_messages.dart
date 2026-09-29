import '../core/api_client.dart';

/// Turns a refused quest start or answer into something a child can act on.
///
/// Most refusals are the economy's own rules, not a network fault, so saying
/// "check your connection" for them would send the child after the wrong fix.
String questProblemMessage(ApiException error) {
  if (error.isNetworkError) {
    return 'Нет связи с сервером. Играть можно, но награда сейчас не начислится.';
  }
  return switch (error.code) {
    'active_day_with_confirmed_plan_required' =>
      'Награда начисляется в начатый день с утверждённым планом. '
          'Начни день на главном экране и вернись к заданию.',
    'daily_quest_reward_limit_reached' =>
      'Сегодня награды за задания уже получены. Загляни завтра!',
    'quest_prerequisite_not_completed' =>
      'Сначала пройди предыдущее задание на карте.',
    'quest_difficulty_mismatch' => 'Этот уровень относится к другой настройке сложности. Вернись на карту и открой задание снова.',
    'quest_already_completed' =>
      'Это задание уже пройдено. Сейчас — тренировочный повтор без награды.',
    'earlier_steps_not_completed' =>
      'Сначала сохрани предыдущую часть задания.',
    'assignment_not_found' || 'step_not_found' =>
      'Задание на сервере обновилось. Вернись на карту и открой его снова.',
    'assignment_not_in_progress' =>
      'Этот результат уже закрыт. Вернись на карту, чтобы обновить прогресс.',
    'quest_not_found' =>
      'Это задание сейчас недоступно. Вернись на карту и обнови её.',
    'invalid_or_revoked_token' || 'missing_bearer_token' =>
      'Сессия закончилась. Вернись на главный экран и войди снова.',
    'quest_reward_is_not_an_economy_value' => 'В задании временно неверно настроена награда. Результат не потерян — попроси взрослого обновить приложение.',
    'invalid_json_response' || 'unexpected_response_shape' =>
      'Сервер ответил неполными данными. Попробуй сохранить ещё раз.',
    _ when error.statusCode >= 500 =>
      'Не получилось сохранить награду. Попробуй ещё раз чуть позже.',
    _ => 'Не получилось сохранить результат. Попробуй ещё раз.',
  };
}

/// Uses the child-facing recovery copy stored with the quest step. A valid
/// HTTP response with a recoverable educational mistake is not a server
/// failure, so it must not be presented as one.
String questRecoveryMessage(
  Map<String, dynamic> result, {
  String fallback = 'Попробуй ещё раз.',
}) {
  final feedback = result['feedback'];
  if (feedback is String && feedback.trim().isNotEmpty) {
    return feedback.trim();
  }
  return fallback;
}
