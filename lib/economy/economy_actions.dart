import '../core/api_client.dart';
import 'economy_action_ui.dart';
import 'economy_state.dart';

enum EconomyDestination { quests, needs, savings, goal }

class EconomyBlock {
  const EconomyBlock(this.message, this.destination);
  final String message;
  final EconomyDestination destination;
}

class EconomyOperation {
  EconomyOperation(
    this.path,
    this.confirmation,
    this.success, [
    Map<String, dynamic>? body,
  ]) : body = {
         ...?body,
         'idempotencyKey':
             'economy-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
       };
  static int _sequence = 0;
  final String path;
  final EconomyConfirmation confirmation;
  final String success;
  final Map<String, dynamic> body;
}

/// A future home screen supplies its own dialog and navigation. Rules and
/// commands do not depend on where its buttons or cards are placed.
class EconomyActions {
  EconomyActions(this.api);
  final ApiClient api;
  bool _running = false;

  Future<void> startDay() async {
    await api.post('/periods');
    await api.post('/pet-events/roll');
  }

  Future<void> confirmPlan(
    String dayId,
    int need,
    int want,
    int savings,
  ) async {
    await api.put(
      '/periods/$dayId/budget-plan',
      body: {'needAmount': need, 'wantAmount': want, 'savingsAmount': savings},
    );
    await api.post('/periods/$dayId/budget-plan/confirm');
  }

  Future<bool> execute(
    EconomyOperation operation,
    Future<bool> Function(EconomyConfirmation) confirm,
  ) async {
    if (_running) return false;
    _running = true;
    try {
      if (!await confirm(operation.confirmation)) return false;
      final body = Map<String, dynamic>.from(operation.body);
      // These endpoints have natural identifiers for replay protection.
      if (operation.path == '/goals' ||
          operation.path.contains('/redeem') ||
          operation.path.contains('/collect') ||
          operation.path.contains('/withdraw-early')) {
        body.remove('idempotencyKey');
      }
      await api.post(operation.path, body: body);
      return true;
    } finally {
      _running = false;
    }
  }

  static EconomyBlock? spendingBlock(
    EconomyState state,
    int amount, {
    bool protectReserve = true,
  }) {
    if (state.wallet < amount) {
      return EconomyBlock(
        'Не хватает ${amount - state.wallet} монет. Выполни задание.',
        EconomyDestination.quests,
      );
    }
    final reserve = state.day?.remainingReserve ?? 0;
    if (protectReserve && state.wallet - amount < reserve) {
      return EconomyBlock(
        '$reserve монет нужны на обязательные траты. Сначала позаботься о питомце.',
        EconomyDestination.needs,
      );
    }
    return null;
  }

  static EconomyOperation purchase(
    EconomyState s,
    EconomyItem item,
  ) => EconomyOperation(
    '/purchases',
    EconomyConfirmation(
      title: 'Купить ${item.name}?',
      message:
          'Цена: ${item.price} монет · ${item.kind == 'NEED' ? 'Надо' : 'Хочу'}',
      confirmLabel: 'Купить',
      details: [
        'Кошелёк: ${s.wallet} → ${s.wallet - item.price}',
        'Обязательный резерв после покупки: ${item.kind == 'NEED' ? ((s.day?.remainingReserve ?? 0) - item.price).clamp(0, s.day?.remainingReserve ?? 0) : s.day?.remainingReserve ?? 0} монет',
      ],
    ),
    'Покупка завершена: ${item.name}.',
    {'itemId': item.id},
  );

  static EconomyOperation savings(
    EconomyState s,
    int amount, {
    required bool deposit,
  }) {
    final after = s.savings + (deposit ? amount : -amount);
    final target = (s.goal?['target_amount'] as num?)?.toInt();
    final missingBefore = target == null
        ? 0
        : (target - s.savings).clamp(0, target);
    final missingAfter = target == null ? 0 : (target - after).clamp(0, target);
    return EconomyOperation(
      '/savings/${deposit ? 'deposit' : 'withdraw'}',
      EconomyConfirmation(
        title: deposit ? 'Пополнить копилку?' : 'Вернуть деньги из Копилки?',
        message: deposit
            ? 'Перевести $amount монет на мечту?'
            : 'Вернуть $amount монет в Кошелёк?',
        confirmLabel: deposit ? 'Отложить $amount' : 'Вернуть $amount',
        details: [
          'Кошелёк: ${s.wallet} → ${s.wallet + (deposit ? -amount : amount)}',
          'Копилка: ${s.savings} → $after',
          if (target != null) 'До цели останется: $missingAfter монет',
          if (!deposit && missingAfter > missingBefore)
            'Цель отдалится на ${missingAfter - missingBefore} монет.',
          if (deposit)
            'Обязательный резерв: ${s.day?.remainingReserve ?? 0} монет',
        ],
      ),
      deposit
          ? '$amount монет добавлено в Копилку.'
          : '$amount монет возвращено в Кошелёк.',
      {'amount': amount},
    );
  }

  static EconomyOperation goal(EconomyState s, EconomyItem item) =>
      EconomyOperation(
        '/goals',
        EconomyConfirmation(
          title: 'Выбрать мечту?',
          message: '${item.name} · ${item.price} монет',
          confirmLabel: 'Выбрать',
          details: [
            'Уже в Копилке: ${s.savings} монет',
            'Цель нельзя сменить до получения артефакта.',
          ],
        ),
        'Мечта выбрана: ${item.name}.',
        {'targetItemId': item.id},
      );

  static EconomyOperation redeem(EconomyState s) {
    final goal = s.goal!;
    final price = (goal['target_amount'] as num).toInt();
    return EconomyOperation(
      '/goals/${goal['id']}/redeem',
      EconomyConfirmation(
        title: 'Получить артефакт?',
        message: '${goal['name']} · $price монет',
        confirmLabel: 'Получить',
        details: [
          'Копилка: ${s.savings} → ${s.savings - price}',
          'Артефакт появится в инвентаре.',
          'После получения выбери следующую мечту. Остаток сохранится.',
        ],
      ),
      'Артефакт добавлен в инвентарь.',
    );
  }

  static EconomyOperation openFrost(EconomyState s, int amount) =>
      EconomyOperation(
        '/frost-chests',
        EconomyConfirmation(
          title: 'Положить в Сундук Морозко?',
          message: '$amount монет на 5 завершённых игровых дней.',
          confirmLabel: 'Положить',
          details: [
            'Кошелёк: ${s.wallet} → ${s.wallet - amount}',
            'После срока в Кошелёк вернётся ${amount + amount ~/ 10} монет.',
            'При досрочном открытии вернётся только вложенная сумма.',
          ],
        ),
        'Монеты помещены в Сундук Морозко.',
        {'principalAmount': amount},
      );

  static EconomyOperation finishFrost(EconomyState s, {required bool early}) {
    final chest = s.frost!;
    final principal = (chest['principal_amount'] as num).toInt();
    final bonus = (chest['bonus_amount'] as num).toInt();
    final total = principal + (early ? 0 : bonus);
    return EconomyOperation(
      '/frost-chests/${chest['id']}/${early ? 'withdraw-early' : 'collect'}',
      EconomyConfirmation(
        title: early ? 'Открыть раньше срока?' : 'Забрать монеты?',
        message: 'В Кошелёк вернётся $total монет.',
        confirmLabel: early ? 'Вернуть без бонуса' : 'Забрать',
        details: [
          'Вложено: $principal монет',
          if (early)
            'Прошло дней: ${chest['completed_days']}. Осталось: ${chest['days_remaining']}.',
          if (early)
            'При открытии сейчас ты не получишь бонус $bonus монет (10%).',
          'Кошелёк: ${s.wallet} → ${s.wallet + total}',
        ],
      ),
      '$total монет возвращено в Кошелёк.',
    );
  }
}
