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
    'quest_already_completed' =>
      'Это задание уже пройдено. Сейчас — тренировочный повтор без награды.',
    _ => 'Сервер не принял результат. Попробуй ещё раз чуть позже.',
  };
}
