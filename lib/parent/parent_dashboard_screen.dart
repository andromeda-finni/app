import 'package:flutter/material.dart';

import '../onboarding/widgets/back_circle_button.dart';
import '../theme/app_theme.dart';

class ParentDashboardScreen extends StatelessWidget {
  const ParentDashboardScreen({
    super.key,
    required this.childCode,
    required this.onExitToRoleChoice,
  });

  final String childCode;
  final VoidCallback onExitToRoleChoice;

  static const _events =
      <({String time, String title, String detail, bool attention})>[
        (
          time: 'Сегодня · 18:40',
          title: 'Проверка мелкого шрифта завершена',
          detail:
              '4 из 5 ситуаций решены с первой попытки. Тема усвоена уверенно.',
          attention: false,
        ),
        (
          time: 'Сегодня · 17:55',
          title: 'Тема «Вклады и проценты»',
          detail: 'Два ответа подряд выбраны после подсказки. Рекомендуется повторение.',
          attention: true,
        ),
        (
          time: 'Вчера · 19:10',
          title: 'План покупок',
          detail: 'Ребёнок сохранил 6 монет из 20 и не превысил бюджет.',
          attention: false,
        ),
        (
          time: 'Вчера · 18:32',
          title: 'Иностранная валюта',
          detail: 'Курс применён правильно в 3 из 3 заданий.',
          attention: false,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1EEE8),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(onBack: () => Navigator.of(context).pop()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(
                        'Профиль ребёнка · $childCode',
                        style: AppTextStyles.swatchLabel,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Грошик: учебный прогресс',
                        style: TextStyle(
                          fontFamily: AppFonts.family,
                          fontSize: 28,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Row(
                        children: [
                          Expanded(
                            child: _Metric(label: 'Занятий', value: '8'),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _Metric(label: 'Тем усвоено', value: '4'),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _Metric(
                              label: 'Нужен повтор',
                              value: '1',
                              alert: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _AttentionCard(),
                      const SizedBox(height: 22),
                      const Text(
                        'Последние действия',
                        style: TextStyle(
                          fontFamily: AppFonts.family,
                          fontSize: 22,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final event in _events) _ActivityTile(event: event),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: onExitToRoleChoice,
                        icon: const Icon(Icons.switch_account_outlined),
                        label: const Text('Выйти к выбору пользователя'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.fieldBorder),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          BackCircleButton(onPressed: onBack),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Кабинет родителя',
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.ink,
              ),
            ),
          ),
          const _DemoBadge(),
        ],
      ),
    );
  }
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.parchmentDark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'ПРОТОТИП',
        style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.alert = false});

  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alert ? AppColors.crimsonFaded : const Color(0xFFD9D2C6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: alert ? AppColors.crimson : AppColors.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2E4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2A970), width: 1.5),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.priority_high_rounded, color: AppColors.crimson),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Надо разобрать эту тему ещё раз',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Ребёнок пока не понимает значение вкладов. В двух заданиях ответ был найден только после подсказки.',
                  style: TextStyle(height: 1.35, color: AppColors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.event});

  final ({String time, String title, String detail, bool attention}) event;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: event.attention ? AppColors.crimson : AppColors.leafGreen,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.time,
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 4),
          Text(
            event.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            event.detail,
            style: const TextStyle(height: 1.35, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}
