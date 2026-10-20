import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'onboarding_data.dart';
import 'widgets/collar_color_picker.dart';
import 'widgets/fur_color_picker.dart';
import 'widgets/onboarding_paper_background.dart';
import 'widgets/onboarding_scene.dart';
import 'widgets/tutorial_budget_card.dart';

/// Local, session-only candidate. Deliberately separate from OnboardingFlow:
/// approval must precede integration with its four server checkpoints.
class OnboardingGuidePreview extends StatefulWidget {
  const OnboardingGuidePreview({
    super.key,
    this.initialPage = 0,
    this.initialData,
  }) : assert(initialPage >= 0 && initialPage < 8);

  final int initialPage;
  final OnboardingData? initialData;

  @override
  State<OnboardingGuidePreview> createState() => _OnboardingGuidePreviewState();
}

class _OnboardingGuidePreviewState extends State<OnboardingGuidePreview> {
  final _name = TextEditingController();
  final _scroll = ScrollController();
  var _data = OnboardingData();
  var _page = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _data = widget.initialData?.copyWith() ?? OnboardingData();
    _name.text = _data.petName;
  }

  static const _titles = [
    'Давай знакомиться',
    'Теперь вы — команда',
    'На всё ли хватит?',
    'Слова-помощники',
    'Твой первый бюджет',
    'Твой день',
    'Город ждёт тебя',
    'Силы для приключений',
  ];

  String get _pet => _data.petName.trim();
  bool get _canNext => switch (_page) {
    0 =>
      _pet.isNotEmpty &&
          _data.furColorId != null &&
          _data.collarColorId != null,
    4 => _data.budgetPracticed && _data.unallocated == 0,
    _ => true,
  };

  @override
  void dispose() {
    _name.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _go(int page) {
    FocusScope.of(context).unfocus();
    setState(() => _page = page);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _explain(String title, String text) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvasWarm,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTextStyles.eventTitle),
              const SizedBox(height: 16),
              Text(text, style: AppTextStyles.story),
              const SizedBox(height: 24),
              _GuideButton(
                label: 'Понятно',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.canvas,
    body: OnboardingPaperBackground(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ГРОШИК · ПРОБНЫЙ ОНБОРДИНГ',
                          style: AppTextStyles.stepCounter,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _finished ? 'Просмотр' : '${_page + 1} / 8',
                        style: AppTextStyles.stepCounter,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_page != 4 && _page != 6) _scene(context),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _finished
                                    ? 'Приключение начинается!'
                                    : _titles[_page],
                                style: AppTextStyles.eventTitle.copyWith(
                                  fontSize: 30,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ...(_finished ? _ending() : _content()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _scene(BuildContext context) => SizedBox(
    height: (MediaQuery.sizeOf(context).height * .31).clamp(160.0, 300.0),
    child: OnboardingScene(
      background: _page == 2
          ? 'assets/backgrounds/shop.webp'
          : 'assets/backgrounds/town.webp',
      cat: catAssetForFur(
        _data.furColorId,
        collarColorId: _data.collarColorId,
        happy: _page == 1 || _finished,
      ),
      catHeightFraction: .65,
      catAlignment: const Alignment(0, .12),
    ),
  );

  List<Widget> _content() => switch (_page) {
    0 => [
      _text(
        'У каждой большой истории есть маленький герой. Создай своего котёнка.',
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _name,
        maxLength: 32,
        textCapitalization: TextCapitalization.words,
        onChanged: (value) =>
            setState(() => _data = _data.copyWith(petName: value)),
        decoration: InputDecoration(
          labelText: 'Как его зовут?',
          hintText: 'Имя котёнка',
          filled: true,
          fillColor: AppColors.cardBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Text('Цвет шёрстки', style: AppTextStyles.sectionTitle),
      FurColorPicker(
        selectedId: _data.furColorId,
        onSelected: (id) =>
            setState(() => _data = _data.copyWith(furColorId: id)),
      ),
      const SizedBox(height: 16),
      const Text('Цвет ошейника', style: AppTextStyles.sectionTitle),
      CollarColorPicker(
        selectedId: _data.collarColorId,
        onSelected: (id) =>
            setState(() => _data = _data.copyWith(collarColorId: id)),
      ),
      const SizedBox(height: 8),
      const Text(
        'Шёрстка останется прежней. Имя и ошейник можно будет изменить в настройках питомца.',
        style: AppTextStyles.supporting,
      ),
    ],
    1 => [
      _text(
        'Это $_pet. Вместе вы будете заботиться о доме, помогать соседям и учиться обращаться с монетами.',
      ),
      const SizedBox(height: 20),
      _note(
        Icons.favorite_outline,
        'Не обязательно знать всё сразу',
        'Пробуй, задавай вопросы и находи своё решение.',
      ),
    ],
    2 => [
      _text(
        'Однажды $_pet заглянул в Чудо-лавку и потратил все монеты на конфеты.',
      ),
      const SizedBox(height: 16),
      _note(
        Icons.shopping_bag_outlined,
        'А что осталось на нужное?',
        'На полезные покупки и будущую мечту монет уже не хватило. Давай попробуем сначала составить план.',
      ),
    ],
    3 => [
      _text(
        'Иногда в историях встречаются новые слова. Словарик поможет разобраться.',
      ),
      const SizedBox(height: 20),
      _note(
        Icons.menu_book_outlined,
        'Попробуй открыть слово',
        '$_pet хочет купить нужные вещи и оставить монеты на потом. Давай составим…',
      ),
      const SizedBox(height: 8),
      Semantics(
        button: true,
        label: 'Бюджет. Открыть объяснение слова',
        onTap: _openBudgetWord,
        child: ExcludeSemantics(
          child: GestureDetector(
            onDoubleTap: _openBudgetWord,
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.goalSurfaceDeep,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.goalBorder),
              ),
              child: const Text('бюджет', style: AppTextStyles.cardTitle),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Дважды нажми на выделенное слово.',
        textAlign: TextAlign.center,
        style: AppTextStyles.supporting,
      ),
      TextButton(
        onPressed: _openBudgetWord,
        child: const Text('Открыть объяснение'),
      ),
      const Text(
        'Знакомые слова можно будет перечитать в словарике.',
        style: AppTextStyles.supporting,
      ),
    ],
    4 => [
      _text(
        'У тебя 10 учебных монет. Реши, сколько оставить на нужное, на радость и на мечту.',
      ),
      const SizedBox(height: 16),
      Semantics(
        liveRegion: true,
        child: Text(
          _data.unallocated == 0
              ? 'Все монеты распределены. Проверь свой план.'
              : 'Осталось распределить: ${_data.unallocated}',
          style: AppTextStyles.sectionTitle,
        ),
      ),
      const SizedBox(height: 20),
      TutorialBudgetCard(
        data: _data,
        onChanged: (next) =>
            setState(() => _data = next.copyWith(budgetPracticed: true)),
      ),
    ],
    5 => [
      _text('Большое приключение складывается из маленьких решений.'),
      const SizedBox(height: 20),
      _note(
        Icons.pie_chart_outline,
        'Составь план',
        'Реши, на что потратить монеты и сколько отложить.',
      ),
      _note(
        Icons.favorite_outline,
        'Позаботься о $_pet',
        'Следи за сытостью, радостью и здоровьем питомца.',
      ),
      _note(
        Icons.explore_outlined,
        'Загляни к соседям',
        'На карте тебя ждут просьбы и задания.',
      ),
      _note(
        Icons.nights_stay_outlined,
        'Посмотри на итоги',
        'Подумай, что удалось и что попробуешь в следующий раз.',
      ),
    ],
    6 => [
      _text(
        'На карте живут твои соседи. Нажми на персонажа, чтобы узнать его просьбу.',
      ),
      const SizedBox(height: 20),
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            SizedBox(
              height: 310,
              width: double.infinity,
              child: Image.asset(
                'assets/map/quest_map_squirrel.webp',
                fit: BoxFit.cover,
                alignment: const Alignment(0, .0),
                excludeFromSemantics: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.crimson,
                  minimumSize: const Size(48, 54),
                ),
                onPressed: () => _explain(
                  'Просьба Белочки',
                  '«Привет, $_pet! Помоги выбрать хорошие продукты в магазине».\n\n'
                      'Это пример знакомства с заданием. Саму игру здесь не запускаем.',
                ),
                icon: const CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.cardBg,
                  child: Text(
                    '1',
                    style: TextStyle(color: AppColors.crimsonDark),
                  ),
                ),
                label: const Text('Узнать просьбу'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Так может выглядеть отметка о новой просьбе. Здесь показан пример будущего оформления карты.',
        style: AppTextStyles.supporting,
      ),
    ],
    _ => [
      _text('Для заданий нужны силы. Их запас показывает энергия.'),
      const SizedBox(height: 20),
      _note(
        Icons.bolt_outlined,
        'Силы возвращаются',
        'Энергия восстанавливается со временем. Если её мало, можно сделать перерыв и вернуться позже.',
      ),
      _note(
        Icons.menu_book_outlined,
        'Подсказки рядом',
        'Незнакомое слово можно посмотреть в словарике. А в заданиях с вопросительным знаком — открыть подсказку.',
      ),
    ],
  };

  void _openBudgetWord() => _explain(
    'Бюджет',
    'Это план: сколько у тебя монет и на что ты собираешься их потратить. '
        'План помогает учесть нужное и оставить что-нибудь на потом.',
  );

  List<Widget> _ending() => [
    _text('Вы с $_pet готовы исследовать город.'),
    const SizedBox(height: 20),
    _note(
      Icons.check_circle_outline,
      'Это локальный просмотр',
      'Новый онбординг пока не подключён к профилю. Имя, внешний вид и учебный план живут только в этом просмотре '
          'и сбросятся при обновлении страницы. Настоящие монеты не меняются.',
    ),
  ];

  Widget _footer() => Container(
    decoration: const BoxDecoration(
      color: AppColors.canvasWarm,
      border: Border(top: BorderSide(color: AppColors.parchmentDark)),
    ),
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_finished) ...[
          LinearProgressIndicator(
            value: (_page + 1) / 8,
            minHeight: 3,
            color: AppColors.crimson,
            backgroundColor: AppColors.parchmentDark,
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            if (_page > 0 && !_finished) ...[
              IconButton(
                tooltip: 'Назад',
                onPressed: () => _go(_page - 1),
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: _GuideButton(
                label: _finished
                    ? 'Посмотреть ещё раз'
                    : _page == 7
                    ? 'Начать приключение'
                    : _page == 0
                    ? 'Познакомиться'
                    : _page == 4
                    ? 'Сохранить учебный план'
                    : 'Дальше',
                onPressed: !_canNext
                    ? null
                    : () {
                        if (_finished) {
                          setState(() => _finished = false);
                          _go(0);
                        } else if (_page == 7) {
                          setState(() => _finished = true);
                          if (_scroll.hasClients) _scroll.jumpTo(0);
                        } else {
                          _go(_page + 1);
                        }
                      },
              ),
            ),
          ],
        ),
        if (!_finished && _page != 0 && _page != 4 && _page != 7)
          TextButton(
            onPressed: () => _go(_page < 4 ? 4 : 7),
            child: const Text('Пропустить объяснения'),
          ),
      ],
    ),
  );

  Widget _text(String text) => Text(text, style: AppTextStyles.story);

  Widget _note(IconData icon, String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 28, color: AppColors.crimson),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.sectionTitle),
              const SizedBox(height: 6),
              Text(text, style: AppTextStyles.story),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Unlike the old story action, this wraps at large accessibility text sizes.
class _GuideButton extends StatelessWidget {
  const _GuideButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.crimson,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.parchmentDark,
      disabledForegroundColor: AppColors.inkMuted,
      minimumSize: const Size(double.infinity, 54),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sheet),
      ),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    ),
  );
}
