import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../theme/app_theme.dart';
import 'economy_action_ui.dart';
import 'economy_actions.dart';
import 'economy_state.dart';

class EconomyScreen extends StatefulWidget {
  const EconomyScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<EconomyScreen> createState() => _EconomyScreenState();
}

class _EconomyScreenState extends State<EconomyScreen> {
  EconomyState? _economy;
  bool _loading = true;
  bool _busy = false;
  bool _confirming = false;
  String? _error;
  late final _actions = EconomyActions(widget.apiClient);
  final _sections = {
    for (final destination in EconomyDestination.values)
      destination: GlobalKey(),
  };

  void _navigate(EconomyDestination destination) {
    final target = _sections[destination]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  Widget _destination(EconomyDestination destination, Widget child) =>
      Container(key: _sections[destination], child: child);

  Future<void> _perform(
    EconomyOperation operation, {
    bool nextGoal = false,
  }) async {
    var applied = false;
    await _command(() async {
      applied = await _actions.execute(operation, (confirmation) async {
        if (!mounted) return false;
        setState(() => _confirming = true);
        try {
          return await showEconomyConfirmation(context, confirmation) &&
              mounted;
        } finally {
          if (mounted) setState(() => _confirming = false);
        }
      });
      if (applied && mounted) showEconomySuccess(context, operation.success);
    });
    if (applied && nextGoal && mounted && _economy != null) await _chooseGoal();
  }

  Future<bool> _chooseGoal() async {
    final economy = _economy!;
    if (economy.goal != null || economy.artifacts.isEmpty) return true;
    final item = await showDialog<EconomyItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выбери мечту'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'В Копилке уже ${economy.savings} монет. Они сохранятся для новой цели.',
              ),
              for (final item in economy.artifacts)
                ListTile(
                  title: Text(item.name),
                  subtitle: Text('${item.price} монет'),
                  onTap: () => Navigator.pop(context, item),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('На главный экран'),
          ),
        ],
      ),
    );
    if (item == null || !mounted) return false;
    await _selectGoal(item);
    return mounted && _economy?.goal != null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final json = await widget.apiClient.get('/economy/state');
      if (!mounted) return;
      setState(() {
        _economy = EconomyState.fromJson(json);
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = economyErrorMessage(error));
    } on FormatException {
      if (!mounted) return;
      setState(() => _error = economyContractErrorMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _command(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _load();
      if (mounted && successMessage != null) {
        showEconomySuccess(context, successMessage);
      }
    } on ApiException catch (error) {
      await _load();
      if (mounted) {
        setState(() => _error = economyErrorMessage(error));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(economyErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startDay() async {
    if (_busy || !await _chooseGoal() || !mounted) return;
    await _command(_actions.startDay);
  }

  Future<void> _confirmPlan(int need, int want, int savings) =>
      _command(() async {
        final day = _economy!.day!;
        await _actions.confirmPlan(day.id, need, want, savings);
      });

  Future<void> _buy(EconomyItem item) =>
      _perform(EconomyActions.purchase(_economy!, item));

  Future<void> _moveSavings({required bool deposit, required int amount}) =>
      _perform(EconomyActions.savings(_economy!, amount, deposit: deposit));

  Future<void> _resolveEvent() => _command(() async {
    final id = _economy!.event!['id'] as String;
    await widget.apiClient.post('/pet-events/$id/resolve');
  });

  Future<void> _closeDay() => _command(() async {
    await widget.apiClient.post('/periods/${_economy!.day!.id}/close');
  });

  Future<void> _selectGoal(EconomyItem item) =>
      _perform(EconomyActions.goal(_economy!, item));

  Future<void> _redeemGoal() =>
      _perform(EconomyActions.redeem(_economy!), nextGoal: true);

  Future<void> _openFrost(int amount) =>
      _perform(EconomyActions.openFrost(_economy!, amount));

  Future<void> _finishFrost({required bool early}) =>
      _perform(EconomyActions.finishFrost(_economy!, early: early));

  Future<void> _runQuest(Map<String, dynamic> quest) async {
    if (quest['assignment_status'] == 'COMPLETED') return;
    await _command(() async {
      var assignmentId = quest['assignment_id'] as String?;
      if (assignmentId == null) {
        final started = await widget.apiClient.post(
          '/quests/${quest['id']}/start',
        );
        assignmentId = started['assignmentId'] as String;
      }
      final step = await widget.apiClient.get(
        '/assignments/$assignmentId/steps/1',
      );
      if (!mounted) return;
      final uiSpec = step['ui_spec'] as Map<String, dynamic>? ?? const {};
      final options = (uiSpec['options'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
      final selected = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(quest['title'] as String),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(step['instruction'] as String? ?? ''),
              const SizedBox(height: 16),
              for (final option in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, option['code'] as String),
                    child: Text(option['label'] as String),
                  ),
                ),
            ],
          ),
        ),
      );
      if (selected == null) return;
      final answer = await widget.apiClient.post(
        '/assignments/$assignmentId/answer',
        body: {'stepNo': 1, 'selectedOptionCode': selected},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(answer['feedback'] as String? ?? 'Готово!')),
        );
      }
    });
  }

  Future<void> _submitTask(String id) => _command(() async {
    await widget.apiClient.post('/child/tasks/$id/submit');
  });

  Future<void> _equip(String? inventoryId) => _command(() async {
    await widget.apiClient.post(
      '/pet/equip',
      body: {'inventoryItemId': inventoryId},
    );
  });

  @override
  Widget build(BuildContext context) {
    if (_loading && _economy == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.crimson),
        ),
      );
    }
    final economy = _economy;
    if (economy == null) {
      return Scaffold(
        body: _ErrorView(
          message: _error ?? 'Не удалось загрузить экономику',
          onRetry: _load,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(economy.petName, style: AppTextStyles.screenTitle),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.crimson,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Wallets(economy: economy),
              const SizedBox(height: 16),
              _destination(
                EconomyDestination.goal,
                _GoalCard(
                  goal: economy.goal,
                  savings: economy.savings,
                  artifacts: economy.artifacts,
                  busy: _busy,
                  canRedeem: economy.day?.planConfirmed == true,
                  onSelect: _selectGoal,
                  onRedeem: _redeemGoal,
                  onNavigate: _navigate,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _Notice(text: _error!, error: true),
              ],
              const SizedBox(height: 16),
              if (economy.day == null)
                _StartDayCard(
                  dailyIncome: economy.rules.dailyIncome,
                  busy: _busy,
                  onStart: _startDay,
                )
              else if (!economy.day!.planConfirmed)
                _BudgetEditor(
                  key: ValueKey(economy.day!.id),
                  allowSavings: economy.goal != null,
                  day: economy.day!,
                  event: economy.event,
                  busy:
                      _busy ||
                      (economy.goal == null && economy.artifacts.isNotEmpty),
                  onConfirm: _confirmPlan,
                )
              else ...[
                _DayHeader(day: economy.day!),
                if (economy.event != null) ...[
                  const SizedBox(height: 12),
                  _EventCard(
                    event: economy.event!,
                    busy: _busy,
                    onPay: _resolveEvent,
                  ),
                ],
                const SizedBox(height: 12),
                _destination(
                  EconomyDestination.needs,
                  _ShopCard(
                    economy: economy,
                    items: economy.shopItems,
                    busy: _busy,
                    onBuy: _buy,
                    onNavigate: _navigate,
                  ),
                ),
                const SizedBox(height: 12),
                _destination(
                  EconomyDestination.savings,
                  _SavingsCard(
                    economy: economy,
                    onNavigate: _navigate,
                    wallet: economy.wallet,
                    savings: economy.savings,
                    busy: _busy,
                    onMove: _moveSavings,
                  ),
                ),
                const SizedBox(height: 12),
                _destination(
                  EconomyDestination.quests,
                  _QuestCard(
                    quests: economy.quests,
                    busy: _busy,
                    onRun: _runQuest,
                  ),
                ),
                if (economy.parentTasks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ParentTasksCard(
                    tasks: economy.parentTasks,
                    busy: _busy,
                    onSubmit: _submitTask,
                  ),
                ],
                const SizedBox(height: 12),
                _FrostCard(
                  economy: economy,
                  onNavigate: _navigate,
                  chest: economy.frost,
                  wallet: economy.wallet,
                  busy: _busy,
                  onOpen: _openFrost,
                  onFinish: _finishFrost,
                ),
                if (economy.inventory.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InventoryCard(
                    items: economy.inventory,
                    busy: _busy,
                    onEquip: _equip,
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _closeDay,
                  icon: const Icon(Icons.nightlight_round),
                  label: const Text('Завершить игровой день'),
                ),
              ],
              if (economy.recentDays.isNotEmpty) ...[
                const SizedBox(height: 16),
                _HistoryCard(days: economy.recentDays),
              ],
              if (_busy && !_confirming) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(color: AppColors.crimson),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.icon});

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      border: Border.all(color: AppColors.fieldBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.crimson),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(title, style: AppTextStyles.cardTitle)),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _Wallets extends StatelessWidget {
  const _Wallets({required this.economy});

  final EconomyState economy;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _Wallet(
        label: 'Кошелёк',
        amount: economy.wallet,
        icon: Icons.account_balance_wallet,
      ),
      const SizedBox(width: 8),
      _Wallet(label: 'Копилка', amount: economy.savings, icon: Icons.savings),
      const SizedBox(width: 8),
      _Wallet(label: 'Морозко', amount: economy.frozen, icon: Icons.ac_unit),
    ],
  );
}

class _Wallet extends StatelessWidget {
  const _Wallet({
    required this.label,
    required this.amount,
    required this.icon,
  });

  final String label;
  final int amount;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.coinGold),
          const SizedBox(height: 4),
          Text('$amount', style: AppTextStyles.counterValue),
          Text(
            label,
            style: AppTextStyles.stepCounter,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _StartDayCard extends StatelessWidget {
  const _StartDayCard({
    required this.dailyIncome,
    required this.busy,
    required this.onStart,
  });
  final int dailyIncome;
  final bool busy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Новый игровой день',
    icon: Icons.wb_sunny_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Утром в Кошелёк поступят $dailyIncome монет. Затем составь план дня.',
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy ? null : onStart,
          child: const Text('Начать день'),
        ),
      ],
    ),
  );
}

class _BudgetEditor extends StatefulWidget {
  const _BudgetEditor({
    super.key,
    required this.day,
    required this.event,
    required this.busy,
    required this.onConfirm,
    required this.allowSavings,
  });
  final bool allowSavings;

  final EconomyDay day;
  final Map<String, dynamic>? event;
  final bool busy;
  final Future<void> Function(int, int, int) onConfirm;

  @override
  State<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<_BudgetEditor> {
  late int need;
  late int want;
  late int savings;

  @override
  void initState() {
    super.initState();
    final existing = widget.day.need + widget.day.want + widget.day.savings;
    if (existing == widget.day.available) {
      need = widget.day.need;
      want = widget.day.want;
      savings = widget.day.savings;
    } else {
      need = widget.day.requiredNeed;
      want = (widget.day.available - need).clamp(0, 5);
      savings = widget.day.available - need - want;
    }
    if (!widget.allowSavings) {
      want += savings;
      savings = 0;
    }
  }

  int get total => need + want + savings;

  void move(String bucket, int delta) {
    setState(() {
      switch (bucket) {
        case 'need':
          need = (need + delta).clamp(0, widget.day.available);
        case 'want':
          want = (want + delta).clamp(0, widget.day.available);
        case 'savings':
          savings = (savings + delta).clamp(0, widget.day.available);
      }
    });
  }

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'План дня ${widget.day.sequence}',
    icon: Icons.edit_note,
    child: Column(
      children: [
        if (widget.event != null)
          _Notice(
            text:
                '${widget.event!['title']}: потребуется ${widget.event!['amount_due']} монет.',
          ),
        _BudgetRow(
          label: 'Надо',
          value: need,
          onChange: (delta) => move('need', delta),
        ),
        _BudgetRow(
          label: 'Хочу',
          value: want,
          onChange: (delta) => move('want', delta),
        ),
        _BudgetRow(
          label: 'Цель',
          value: savings,
          enabled: widget.allowSavings,
          onChange: (delta) => move('savings', delta),
        ),
        const SizedBox(height: 8),
        Text(
          total == widget.day.available
              ? 'Распределено: $total из ${widget.day.available}'
              : 'Нужно распределить ещё ${widget.day.available - total}',
          style: AppTextStyles.supporting,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed:
                widget.busy ||
                    total != widget.day.available ||
                    need < widget.day.requiredNeed
                ? null
                : () => widget.onConfirm(need, want, savings),
            child: const Text('Утвердить план'),
          ),
        ),
      ],
    ),
  );
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.label,
    required this.value,
    required this.onChange,
    this.enabled = true,
  });
  final bool enabled;
  final String label;
  final int value;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: AppTextStyles.cardRowLabel)),
      IconButton(
        onPressed: enabled ? () => onChange(-1) : null,
        icon: const Icon(Icons.remove_circle_outline),
      ),
      SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.center)),
      IconButton(
        onPressed: enabled ? () => onChange(1) : null,
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});
  final EconomyDay day;

  @override
  Widget build(BuildContext context) => _Notice(
    text:
        'Неделя ${day.week}, день ${day.dayOfWeek}. План: надо ${day.need}, хочу ${day.want}, цель ${day.savings}.',
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.busy,
    required this.onPay,
  });
  final Map<String, dynamic> event;
  final bool busy;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) => _Panel(
    title: event['title'] as String,
    icon: Icons.warning_amber,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(event['description'] as String),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: busy ? null : onPay,
          child: Text('Оплатить ${event['amount_due']} монет из Кошелька'),
        ),
      ],
    ),
  );
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.items,
    required this.busy,
    required this.onBuy,
    required this.economy,
    required this.onNavigate,
  });
  final EconomyState economy;
  final ValueChanged<EconomyDestination> onNavigate;
  final List<EconomyItem> items;
  final bool busy;
  final ValueChanged<EconomyItem> onBuy;

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Траты дня',
    icon: Icons.storefront,
    child: Column(
      children: [
        for (final item in items) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.name),
            subtitle: Text(item.kind == 'NEED' ? 'Надо' : 'Хочу'),
            trailing: OutlinedButton(
              onPressed:
                  busy || EconomyActions.purchaseBlock(economy, item) != null
                  ? null
                  : () => onBuy(item),
              child: Text('${item.price} монет'),
            ),
          ),
          _BlockHint(
            block: EconomyActions.purchaseBlock(economy, item),
            onNavigate: onNavigate,
          ),
        ],
      ],
    ),
  );
}

class _SavingsCard extends StatelessWidget {
  const _SavingsCard({
    required this.wallet,
    required this.savings,
    required this.busy,
    required this.onMove,
    required this.economy,
    required this.onNavigate,
  });
  final EconomyState economy;
  final ValueChanged<EconomyDestination> onNavigate;
  EconomyBlock? depositBlock(int amount) => economy.goal == null
      ? const EconomyBlock(
          'Сначала выбери мечту для накоплений.',
          EconomyDestination.goal,
        )
      : EconomyActions.spendingBlock(economy, amount);

  final int wallet;
  final int savings;
  final bool busy;
  final Future<void> Function({required bool deposit, required int amount})
  onMove;

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Копилка',
    icon: Icons.savings_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Переводы между Кошельком и Копилкой не считаются доходом или расходом.',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final amount in economy.rules.savingsTransferAmounts) ...[
              OutlinedButton(
                onPressed: busy || depositBlock(amount) != null
                    ? null
                    : () => onMove(deposit: true, amount: amount),
                child: Text('Отложить $amount'),
              ),
              _BlockHint(block: depositBlock(amount), onNavigate: onNavigate),
            ],
            for (final amount in economy.rules.savingsTransferAmounts) ...[
              TextButton(
                onPressed: busy || savings < amount
                    ? null
                    : () => onMove(deposit: false, amount: amount),
                child: Text('Вернуть $amount'),
              ),
              if (savings < amount)
                Text(
                  'Для возврата $amount монет в Копилке не хватает ${amount - savings}.',
                ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quests,
    required this.busy,
    required this.onRun,
  });
  final List<Map<String, dynamic>> quests;
  final bool busy;
  final ValueChanged<Map<String, dynamic>> onRun;

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Квесты',
    icon: Icons.map_outlined,
    child: Column(
      children: [
        for (final quest in quests)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(quest['title'] as String),
            subtitle: Text('Награда: ${quest['reward_amount']} монет'),
            trailing: quest['assignment_status'] == 'COMPLETED'
                ? const Icon(Icons.check_circle, color: AppColors.leafGreen)
                : OutlinedButton(
                    onPressed: busy ? null : () => onRun(quest),
                    child: const Text('Пройти'),
                  ),
          ),
      ],
    ),
  );
}

class _ParentTasksCard extends StatelessWidget {
  const _ParentTasksCard({
    required this.tasks,
    required this.busy,
    required this.onSubmit,
  });
  final List<Map<String, dynamic>> tasks;
  final bool busy;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Родительские дела',
    icon: Icons.family_restroom,
    child: Column(
      children: [
        for (final task in tasks)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(task['title'] as String),
            subtitle: Text(
              '${task['reward_amount']} монет · ${task['status']}',
            ),
            trailing:
                task['status'] == 'AVAILABLE' || task['status'] == 'IN_PROGRESS'
                ? OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => onSubmit(task['id'] as String),
                    child: const Text('Готово'),
                  )
                : null,
          ),
      ],
    ),
  );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.savings,
    required this.artifacts,
    required this.busy,
    required this.onSelect,
    required this.onRedeem,
    required this.canRedeem,
    required this.onNavigate,
  });
  final bool canRedeem;
  final ValueChanged<EconomyDestination> onNavigate;
  final Map<String, dynamic>? goal;
  final int savings;
  final List<EconomyItem> artifacts;
  final bool busy;
  final ValueChanged<EconomyItem> onSelect;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Финансовая цель',
    icon: Icons.flag_outlined,
    child: goal == null
        ? Column(
            children: [
              Text(
                artifacts.isEmpty
                    ? 'Все доступные артефакты уже получены!'
                    : 'Выбери мечту перед планированием дня. В Копилке: $savings монет. Цель нельзя сменить до получения.',
              ),
              for (final item in artifacts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  trailing: OutlinedButton(
                    onPressed: busy ? null : () => onSelect(item),
                    child: Text('${item.price}'),
                  ),
                ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(goal!['name'] as String, style: AppTextStyles.sectionTitle),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (savings / (goal!['target_amount'] as num))
                    .clamp(0, 1)
                    .toDouble(),
                color: AppColors.leafGreen,
                backgroundColor: AppColors.parchmentDark,
              ),
              const SizedBox(height: 6),
              Text('$savings из ${goal!['target_amount']} монет'),
              const SizedBox(height: 10),
              const Text(
                'Эта мечта остаётся выбранной до получения артефакта.',
              ),
              FilledButton(
                onPressed:
                    busy ||
                        !canRedeem ||
                        savings < (goal!['target_amount'] as num)
                    ? null
                    : onRedeem,
                child: const Text('Получить артефакт'),
              ),
              if (!canRedeem) const Text('Сначала начни день и утверди план.'),
              if (canRedeem && savings < (goal!['target_amount'] as num))
                _BlockHint(
                  block: EconomyBlock(
                    'До мечты не хватает ${(goal!['target_amount'] as num) - savings} монет. Пополни Копилку.',
                    EconomyDestination.savings,
                  ),
                  onNavigate: onNavigate,
                ),
            ],
          ),
  );
}

class _FrostCard extends StatelessWidget {
  const _FrostCard({
    required this.chest,
    required this.wallet,
    required this.busy,
    required this.onOpen,
    required this.onFinish,
    required this.economy,
    required this.onNavigate,
  });
  final EconomyState economy;
  final ValueChanged<EconomyDestination> onNavigate;
  final Map<String, dynamic>? chest;
  final int wallet;
  final bool busy;
  final ValueChanged<int> onOpen;
  final Future<void> Function({required bool early}) onFinish;

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Сундук Морозко',
    icon: Icons.ac_unit,
    child: chest == null
        ? Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Положи монеты на ${economy.rules.frostDays} завершённых дней '
                'и получи сумму с бонусом ${economy.rules.frostBonusPercent}% '
                'в Кошелёк. Раньше срока — без бонуса.',
              ),
              for (final amount in economy.rules.frostPrincipalOptions) ...[
                OutlinedButton(
                  onPressed:
                      busy ||
                          EconomyActions.spendingBlock(economy, amount) != null
                      ? null
                      : () => onOpen(amount),
                  child: Text(
                    '$amount → ${amount + economy.rules.frostBonusFor(amount)}',
                  ),
                ),
                _BlockHint(
                  block: EconomyActions.spendingBlock(economy, amount),
                  onNavigate: onNavigate,
                ),
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Внутри ${chest!['principal_amount']} монет. Осталось дней: ${chest!['days_remaining']}.',
              ),
              const SizedBox(height: 10),
              if (chest!['matured'] == true)
                FilledButton(
                  onPressed: busy ? null : () => onFinish(early: false),
                  child: Text(
                    'Забрать ${chest!['principal_amount'] + chest!['bonus_amount']}',
                  ),
                )
              else
                TextButton(
                  onPressed: busy ? null : () => onFinish(early: true),
                  child: const Text('Открыть раньше без бонуса'),
                ),
            ],
          ),
  );
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.items,
    required this.busy,
    required this.onEquip,
  });
  final List<Map<String, dynamic>> items;
  final bool busy;
  final ValueChanged<String?> onEquip;

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Артефакты',
    icon: Icons.auto_awesome,
    child: Column(
      children: [
        for (final item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item['name'] as String),
            trailing: item['equipped'] == true
                ? TextButton(
                    onPressed: busy ? null : () => onEquip(null),
                    child: const Text('Снять'),
                  )
                : OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => onEquip(item['id'] as String),
                    child: const Text('Надеть'),
                  ),
          ),
      ],
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.days});
  final List<Map<String, dynamic>> days;

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Последние дни',
    icon: Icons.history,
    child: Column(
      children: [
        for (final day in days)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              day['plan_followed'] == true
                  ? Icons.check_circle
                  : Icons.tips_and_updates,
              color: day['plan_followed'] == true
                  ? AppColors.leafGreen
                  : AppColors.coinGold,
            ),
            title: Text('Неделя ${day['week']}, день ${day['dayOfWeek']}'),
            subtitle: Text(day['feedback_text'] as String),
          ),
      ],
    ),
  );
}

class _BlockHint extends StatelessWidget {
  const _BlockHint({required this.block, required this.onNavigate});
  final EconomyBlock? block;
  final ValueChanged<EconomyDestination> onNavigate;
  @override
  Widget build(BuildContext context) {
    final reason = block;
    if (reason == null) return const SizedBox.shrink();
    final label = switch (reason.destination) {
      EconomyDestination.quests => 'К заданиям',
      EconomyDestination.needs => 'К обязательным покупкам',
      EconomyDestination.savings => 'К Копилке',
      EconomyDestination.goal => 'Выбрать мечту',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(reason.message),
        TextButton(
          onPressed: () => onNavigate(reason.destination),
          child: Text(label),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: error ? AppColors.crimsonFaded : AppColors.infoBg,
      borderRadius: BorderRadius.circular(AppRadii.sm),
    ),
    child: Text(text, style: AppTextStyles.supporting),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.story,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    ),
  );
}
