import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../onboarding/widgets/back_circle_button.dart';
import '../../onboarding/widgets/story_button.dart';
import '../../theme/app_theme.dart';
import 'tugriki_game_data.dart';

/// Шаги интерактивной визуальной новеллы «Тугрики» (в стиле «Клуба романтики»)
enum NovelStep {
  s1SparrowIntro,       // Воробей на ярмарке (один в кадре): цены в тугриках!
  s2GroshikEnters,      // Появляется Грошик: объясняет про валюту и курс
  s3ExchangeRateDemo,   // Наглядная анимация курса: 2 монетки = 1 тугрик
  s4BunOrder,           // Уровень 1: Воробей хочет булочку за 6 тугриков
  s5BunCoinDrop,        // Интерактивный лоток: раскладываем по 2 монетки в 6 ячеек
  s6BunEnjoy,           // Радостный Воробей с булочкой: 6 x 2 = 12 монет
  s7LunchMenu,          // Уровень 2: Меню обеда (Суп 4 + Сок 2 + Булочка 3)
  s8LunchConvert,       // Интерактивное сложение и перевод: 9 x 2 = 18 монет
  s9LunchSuccess,       // Обед оплачен, Воробей сыт
  s10BudgetIntro,       // Уровень 3: Грошик показывает бюджет 20 монет
  s11BudgetInteractive, // Интерактивный подбор покупок в лоток с живой сдачей
  s12Victory,           // Финал: правило о валютах, +20 монет награда
}

class TugrikiGameScreen extends StatefulWidget {
  const TugrikiGameScreen({
    super.key,
    this.apiClient,
    this.onExit,
  });

  final ApiClient? apiClient;
  final VoidCallback? onExit;

  @override
  State<TugrikiGameScreen> createState() => _TugrikiGameScreenState();
}

class _TugrikiGameScreenState extends State<TugrikiGameScreen>
    with SingleTickerProviderStateMixin {
  NovelStep _step = NovelStep.s1SparrowIntro;

  // Интерактивный набор монет для булочки (Уровень 1)
  int _bunPairsFilled = 0; // от 0 до 6

  // Интерактивный бюджет (Уровень 3)
  static const int kTotalBudget = 20;
  final Set<String> _selectedGoodIds = {'soup', 'juice'}; // по умолчанию Суп (8м) + Сок (4м) = 12м
  int _spentCoins = 0;
  int _changeCoins = 0;

  String? _assignmentId;
  String? _syncNote;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.apiClient == null) {
      _syncNote = 'Тренировка: монетки начисляются в игре.';
    } else {
      _startServerQuest();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startServerQuest() async {
    try {
      final res = await widget.apiClient!.post('/quests/$kTugrikiQuestId/start');
      if (!mounted) return;
      setState(() {
        _assignmentId = res['assignmentId'] as String?;
        _syncNote = 'Квест начат! Награда: $kTugrikiReward монет.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syncNote = 'Автономный режим: играем локально.';
      });
    }
  }

  Future<void> _completeServerQuest() async {
    if (widget.apiClient == null || _assignmentId == null) return;
    try {
      await widget.apiClient!.post('/assignments/$_assignmentId/complete');
    } catch (_) {}
  }

  void _nextStep() {
    setState(() {
      switch (_step) {
        case NovelStep.s1SparrowIntro:
          _step = NovelStep.s2GroshikEnters;
          break;
        case NovelStep.s2GroshikEnters:
          _step = NovelStep.s3ExchangeRateDemo;
          break;
        case NovelStep.s3ExchangeRateDemo:
          _step = NovelStep.s4BunOrder;
          break;
        case NovelStep.s4BunOrder:
          _step = NovelStep.s5BunCoinDrop;
          break;
        case NovelStep.s5BunCoinDrop:
          _step = NovelStep.s6BunEnjoy;
          break;
        case NovelStep.s6BunEnjoy:
          _step = NovelStep.s7LunchMenu;
          break;
        case NovelStep.s7LunchMenu:
          _step = NovelStep.s8LunchConvert;
          break;
        case NovelStep.s8LunchConvert:
          _step = NovelStep.s9LunchSuccess;
          break;
        case NovelStep.s9LunchSuccess:
          _step = NovelStep.s10BudgetIntro;
          break;
        case NovelStep.s10BudgetIntro:
          _step = NovelStep.s11BudgetInteractive;
          break;
        case NovelStep.s11BudgetInteractive:
          _step = NovelStep.s12Victory;
          _completeServerQuest();
          break;
        case NovelStep.s12Victory:
          _exit();
          break;
      }
    });
  }

  void _exit() {
    if (widget.onExit != null) {
      widget.onExit!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  // Расчеты бюджета для Уровня 3
  final List<MarketGood> _budgetGoods = const [
    MarketCatalog.soup,
    MarketCatalog.juice,
    MarketCatalog.fruits,
    MarketCatalog.pie,
  ];

  int get _budgetTotalTugriki => _budgetGoods
      .where((g) => _selectedGoodIds.contains(g.id))
      .fold(0, (sum, g) => sum + g.priceTugriki);

  int get _budgetTotalCoins => _budgetTotalTugriki * kExchangeRate;
  int get _budgetRemainingCoins => kTotalBudget - _budgetTotalCoins;
  bool get _budgetIsOver => _budgetTotalCoins > kTotalBudget;
  bool get _budgetCanBuy => _selectedGoodIds.isNotEmpty && !_budgetIsOver;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                // 1. Верхняя компактная плашка со статусом курса и выходом
                _buildTopBar(),

                // 2. 2/3 ЭКРАНА: СЦЕНА В СТИЛЕ «КЛУБА РОМАНТИКИ»
                Expanded(
                  flex: 66, // Ровно 2/3 экрана (66%)
                  child: _buildRomanceClubScene(),
                ),

                // 3. 1/3 ЭКРАНА: ДИАЛОГ И ДЕТСКИЕ ИНТЕРАКТИВНЫЕ ДЕЙСТВИЯ (34%)
                Expanded(
                  flex: 34,
                  child: _buildRomanceClubDialogArea(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(bottom: BorderSide(color: AppColors.fieldBorder, width: 1.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          BackCircleButton(onPressed: _exit),
          // Карточка курса
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.parchmentDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.fieldBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(TugrikiAssets.foreignMoneyFront, width: 20, height: 20),
                const SizedBox(width: 4),
                const Text(
                  '1 тугрик = ',
                  style: TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                Image.asset(TugrikiAssets.homeCoin, width: 16, height: 16),
                const SizedBox(width: 2),
                Image.asset(TugrikiAssets.homeCoin, width: 16, height: 16),
                const SizedBox(width: 4),
                const Text(
                  '2 монетки',
                  style: TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.crimson,
                  ),
                ),
              ],
            ),
          ),
          // Метка этапа
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.crimson.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _getStageBadgeLabel(),
              style: const TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.crimsonDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStageBadgeLabel() {
    switch (_step) {
      case NovelStep.s1SparrowIntro:
      case NovelStep.s2GroshikEnters:
      case NovelStep.s3ExchangeRateDemo:
        return 'Знакомство';
      case NovelStep.s4BunOrder:
      case NovelStep.s5BunCoinDrop:
      case NovelStep.s6BunEnjoy:
        return 'Булочка 6т';
      case NovelStep.s7LunchMenu:
      case NovelStep.s8LunchConvert:
      case NovelStep.s9LunchSuccess:
        return 'Обед 9т';
      case NovelStep.s10BudgetIntro:
      case NovelStep.s11BudgetInteractive:
        return 'Бюджет 20м';
      case NovelStep.s12Victory:
        return 'Победа!';
    }
  }

  /// 2/3 ЭКРАНА: ПОЛНОЦЕННАЯ СЦЕНА В СТИЛЕ «КЛУБА РОМАНТИКИ»
  /// Персонажи появляются по очереди, анимированно выходят на передний план,
  /// говорят по тапу. Картинка square.png кадрируется правильно, без искажений.
  Widget _buildRomanceClubScene() {
    final bool showGroshik = _step != NovelStep.s1SparrowIntro;
    final bool isSparrowSpeaking = _step == NovelStep.s1SparrowIntro ||
        _step == NovelStep.s4BunOrder ||
        _step == NovelStep.s6BunEnjoy ||
        _step == NovelStep.s7LunchMenu ||
        _step == NovelStep.s9LunchSuccess ||
        _step == NovelStep.s12Victory;

    final bool isSparrowHappy = _step == NovelStep.s6BunEnjoy ||
        _step == NovelStep.s9LunchSuccess ||
        _step == NovelStep.s12Victory;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final width = constraints.maxWidth;
        final charHeight = height * 0.72; // Высота персонажей пропорциональна сцене

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // Тап по сцене продвигает сюжет в диалоговых шагах
            if (_step == NovelStep.s1SparrowIntro ||
                _step == NovelStep.s2GroshikEnters ||
                _step == NovelStep.s3ExchangeRateDemo ||
                _step == NovelStep.s4BunOrder ||
                _step == NovelStep.s6BunEnjoy ||
                _step == NovelStep.s7LunchMenu ||
                _step == NovelStep.s9LunchSuccess ||
                _step == NovelStep.s10BudgetIntro) {
              _nextStep();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Фон площади: вертикальная иллюстрация square.png с верхней центровкой
              ClipRect(
                child: Image.asset(
                  TugrikiAssets.square,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),

              // Легкая атмосферная тень снизу для контраста персонажей
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.02),
                        Colors.black.withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                ),
              ),

              // ПЕРСОНАЖ 1: КОТ ГРОШИК (Появляется со шага 2 слева)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                left: showGroshik ? 8 : -220,
                bottom: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: showGroshik ? (!isSparrowSpeaking ? 1.0 : 0.68) : 0.0,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 300),
                    scale: (!isSparrowSpeaking && showGroshik) ? 1.04 : 0.94,
                    alignment: Alignment.bottomLeft,
                    child: Image.asset(
                      TugrikiAssets.catStriped,
                      height: charHeight * 0.92,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // ПЕРСОНАЖ 2: ДРУГ ВОРОБЕЙ (Справа на переднем плане)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                right: 8,
                bottom: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isSparrowSpeaking ? 1.0 : 0.68,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 300),
                    scale: isSparrowSpeaking ? 1.04 : 0.94,
                    alignment: Alignment.bottomRight,
                    child: Image.asset(
                      isSparrowHappy
                          ? TugrikiAssets.vorobeyHappy
                          : TugrikiAssets.vorobeyNormal,
                      height: charHeight,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // ОВЕРЛЕЙ 1: АНИМАЦИЯ ПРЕВРАЩЕНИЯ ВАЛЮТЫ (Шаг 3)
              if (_step == NovelStep.s3ExchangeRateDemo)
                Center(
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.crimson, width: 2.2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(TugrikiAssets.homeCoin, width: 44, height: 44),
                              const SizedBox(width: 4),
                              Image.asset(TugrikiAssets.homeCoin, width: 44, height: 44),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Icon(Icons.arrow_forward_rounded, color: AppColors.crimson, size: 30),
                              ),
                              Image.asset(TugrikiAssets.foreignMoneyFront, width: 50, height: 50),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '2 монетки = 1 тугрик',
                            style: TextStyle(
                              fontFamily: AppFonts.family,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.crimsonDark,
                            ),
                          ),
                          const Text(
                            'Курс обмена на всей ярмарке!',
                            style: TextStyle(
                              fontFamily: AppFonts.family,
                              fontSize: 13,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ОВЕРЛЕЙ 2: ПРИЛАВОК БУЛОЧНИКА (Шаги 4, 5, 6)
              if (_step == NovelStep.s4BunOrder ||
                  _step == NovelStep.s5BunCoinDrop ||
                  _step == NovelStep.s6BunEnjoy)
                Positioned(
                  top: 14,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.fieldBorder, width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Text('🥐', style: TextStyle(fontSize: 34)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Свежая ярмарочная булочка',
                                style: TextStyle(
                                  fontFamily: AppFonts.family,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                'Цена: 6 тугриков',
                                style: TextStyle(
                                  fontFamily: AppFonts.family,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.crimson,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Image.asset(TugrikiAssets.foreignMoneyFront, width: 28, height: 28),
                      ],
                    ),
                  ),
                ),

              // ОВЕРЛЕЙ 3: МЕНЮ ОБЕДА (Шаги 7, 8, 9)
              if (_step == NovelStep.s7LunchMenu ||
                  _step == NovelStep.s8LunchConvert ||
                  _step == NovelStep.s9LunchSuccess)
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.fieldBorder, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDishBadge('🍲 Суп', '4 тугр.'),
                        const Text('+', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        _buildDishBadge('🧃 Сок', '2 тугр.'),
                        const Text('+', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        _buildDishBadge('🥐 Булочка', '3 тугр.'),
                        const Text('=', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        _buildDishBadge('Всего', '9 тугр.', isHighlight: true),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDishBadge(String title, String price, {bool isHighlight = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(fontFamily: AppFonts.family, fontSize: 12),
        ),
        Text(
          price,
          style: TextStyle(
            fontFamily: AppFonts.family,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isHighlight ? AppColors.crimson : AppColors.ink,
          ),
        ),
      ],
    );
  }

  /// 1/3 ЭКРАНА: ДИАЛОГ И ИНТЕРАКТИВНОЕ ДЕЙСТВИЕ
  Widget _buildRomanceClubDialogArea() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Color(0x28000000), blurRadius: 14, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: _buildDialogueOrActionContent(),
        ),
      ),
    );
  }

  Widget _buildDialogueOrActionContent() {
    switch (_step) {
      // 1. Вступление Воробья
      case NovelStep.s1SparrowIntro:
        return _buildRomanceSpeechCard(
          speakerName: 'Друг Воробей',
          isSparrow: true,
          dialogueText:
              'Грошик, посмотри вокруг! Мы на ярмарке в соседнем государстве. Но здесь на всех прилавках цены в тугриках, а у меня с собой только монетки!',
          actionText: 'Ответить Воробью ➔',
          onAction: _nextStep,
        );

      // 2. Вступление Грошика
      case NovelStep.s2GroshikEnters:
        return _buildRomanceSpeechCard(
          speakerName: 'Кот Грошик',
          isSparrow: false,
          dialogueText:
              'Не переживай, друг! В другой стране свои деньги, но их легко пересчитать. Смотри на курс: за 1 тугрик нужно отдать 2 монетки!',
          actionText: 'Посмотреть курс ➔',
          onAction: _nextStep,
        );

      // 3. Демонстрация курса
      case NovelStep.s3ExchangeRateDemo:
        return _buildRomanceSpeechCard(
          speakerName: 'Друг Воробей',
          isSparrow: true,
          dialogueText:
              'Ага! Значит, 1 тугрик = 2 монетки. Давай скорее пойдём к булочнику, я ужасно проголодался!',
          actionText: 'Пойти к прилавку 🥐',
          onAction: _nextStep,
        );

      // 4. Заказ булочки
      case NovelStep.s4BunOrder:
        return _buildRomanceSpeechCard(
          speakerName: 'Друг Воробей',
          isSparrow: true,
          dialogueText:
              'Булочка стоит 6 тугриков. Помоги мне отсчитать монетки! Нам нужно положить по 2 монетки на каждый тугрик.',
          actionText: 'Отсчитать монетки (+2) ➔',
          onAction: _nextStep,
        );

      // 5. Интерактивный набор монет для булочки (без скучных квизов!)
      case NovelStep.s5BunCoinDrop:
        return _buildV1InteractiveCoinCells();

      // 6. Воробей ест булочку
      case NovelStep.s6BunEnjoy:
        return _buildRomanceSpeechCard(
          speakerName: 'Друг Воробей',
          isSparrow: true,
          dialogueText:
              'Ура-а-а! 12 монеток превратились в 6 тугриков, и тёплая булочка у меня в руках! Это было так понятно!',
          actionText: 'Взять целый обед 🍲',
          onAction: _nextStep,
        );

      // 7. Меню обеда
      case NovelStep.s7LunchMenu:
        return _buildRomanceSpeechCard(
          speakerName: 'Друг Воробей',
          isSparrow: true,
          dialogueText:
              'Давай закажем обед: Суп (4) + Сок (2) + Булочка (3). Всего 9 тугриков! Сколько монеток нужно обменять по курсу 1:2?',
          actionText: 'Рассчитать сумму ➔',
          onAction: _nextStep,
        );

      // 8. Интерактивный пересчет обеда
      case NovelStep.s8LunchConvert:
        return _buildV2InteractiveLunchConvert();

      // 9. Обед оплачен
      case NovelStep.s9LunchSuccess:
        return _buildRomanceSpeechCard(
          speakerName: 'Друг Воробей',
          isSparrow: true,
          dialogueText:
              'Вкуснотища! 9 тугриков умножили на 2 — получилось ровно 18 монеток. Обед куплен!',
          actionText: 'К покупкам по бюджету ➔',
          onAction: _nextStep,
        );

      // 10. Вступление к бюджету
      case NovelStep.s10BudgetIntro:
        return _buildRomanceSpeechCard(
          speakerName: 'Кот Грошик',
          isSparrow: false,
          dialogueText:
              'У нас в кошельке осталось ровно 20 монеток. Выбирай покупки с умом, чтобы хватило денег и осталась сдача!',
          actionText: 'Выбрать товары в лоток ➔',
          onAction: _nextStep,
        );

      // 11. Интерактивный лоток бюджета 20 монет
      case NovelStep.s11BudgetInteractive:
        return _buildV3InteractiveBudgetTray();

      // 12. Финал и награда
      case NovelStep.s12Victory:
        return _buildFinalVictoryCard();
    }
  }

  /// Карточка речи персонажа в стиле «Клуба романтики»
  Widget _buildRomanceSpeechCard({
    required String speakerName,
    required bool isSparrow,
    required String dialogueText,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Имя персонажа
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSparrow
                        ? AppColors.crimson.withValues(alpha: 0.15)
                        : AppColors.leafGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    speakerName,
                    style: TextStyle(
                      fontFamily: AppFonts.family,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSparrow ? AppColors.crimson : AppColors.leafGreen,
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  '▼ Нажми для продолжения',
                  style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Текст реплики
            Text(
              dialogueText,
              style: const TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 15.5,
                height: 1.35,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        StoryButton(
          label: actionText,
          showFlourish: true,
          onPressed: onAction,
        ),
      ],
    );
  }

  /// ВАРИАНТ 1: НАГЛЯДНЫЙ ТАКТИЛЬНЫЙ НАБОР МОНЕТ В 6 ЯЧЕЕК (БЕЗ ТЕСТОВ И КВИЗОВ)
  Widget _buildV1InteractiveCoinCells() {
    final currentCoins = _bunPairsFilled * 2;
    final bool isDone = _bunPairsFilled >= 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Раскладываем по 2 монетки:',
                  style: TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  '$currentCoins / 12 монет',
                  style: const TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.crimson,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 6 ячеек (по тапу на ячейку или на общую кнопку)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (idx) {
                final isFilled = idx < _bunPairsFilled;
                return GestureDetector(
                  onTap: () {
                    if (!isFilled && idx == _bunPairsFilled) {
                      setState(() => _bunPairsFilled++);
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isFilled ? AppColors.parchmentDark : AppColors.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isFilled ? AppColors.crimson : AppColors.fieldBorder,
                        width: isFilled ? 2 : 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${idx + 1}т',
                          style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
                        ),
                        if (isFilled)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(TugrikiAssets.homeCoin, width: 14, height: 14),
                              Image.asset(TugrikiAssets.homeCoin, width: 14, height: 14),
                            ],
                          )
                        else
                          const Icon(Icons.add_circle_outline, size: 18, color: AppColors.crimsonFaded),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            if (isDone)
              const Center(
                child: Text(
                  '2 + 2 + 2 + 2 + 2 + 2 = 12 монеток (6 × 2 = 12)',
                  style: TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.leafGreen,
                  ),
                ),
              ),
          ],
        ),
        if (!isDone)
          StoryButton(
            label: 'Положить 2 монетки в ячейку (${_bunPairsFilled + 1}/6)',
            onPressed: () {
              setState(() => _bunPairsFilled++);
            },
          )
        else
          StoryButton(
            label: 'Купить булочку за 12 монет! 🥐',
            showFlourish: true,
            onPressed: () {
              setState(() => _step = NovelStep.s6BunEnjoy);
            },
          ),
      ],
    );
  }

  /// ВАРИАНТ 2: ИНТЕРАКТИВНОЕ СЛОЖЕНИЕ И ПЕРЕВОД ВАЛЮТЫ (БЕЗ КВИЗОВ)
  Widget _buildV2InteractiveLunchConvert() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Складываем тугрики за обед:',
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.parchmentDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('4 (суп) + 2 (сок) + 3 (булочка)', style: TextStyle(fontSize: 13.5)),
                  Text(
                    '= 9 тугриков',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.crimson),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Курс 1 к 2: значит 9 тугриков × 2 = 18 монеток',
                style: TextStyle(
                  fontFamily: AppFonts.family,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
        StoryButton(
          label: 'Обменять 18 монет и оплатить обед 🍲',
          showFlourish: true,
          onPressed: () {
            setState(() => _step = NovelStep.s9LunchSuccess);
          },
        ),
      ],
    );
  }

  /// ВАРИАНТ 3: ИНТЕРАКТИВНЫЙ БЮДЖЕТНЫЙ ЛОТОК (20 МОНЕТ)
  Widget _buildV3InteractiveBudgetTray() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Кошелек: 20 монет',
                style: TextStyle(
                  fontFamily: AppFonts.family,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              Text(
                _budgetRemainingCoins >= 0
                    ? 'Сдача: $_budgetRemainingCoins монет'
                    : 'Не хватает: ${-_budgetRemainingCoins} монет',
                style: TextStyle(
                  fontFamily: AppFonts.family,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _budgetRemainingCoins < 0 ? AppColors.crimson : AppColors.leafGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Карточки товаров
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _budgetGoods.map((good) {
              final isSel = _selectedGoodIds.contains(good.id);
              return FilterChip(
                label: Text('${good.iconEmoji} ${good.name} (${good.priceTugriki}т = ${good.priceCoins}м)'),
                selected: isSel,
                selectedColor: AppColors.parchmentDark,
                checkmarkColor: AppColors.crimson,
                labelStyle: TextStyle(
                  fontFamily: AppFonts.family,
                  fontSize: 12.5,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  color: isSel ? AppColors.crimsonDark : AppColors.ink,
                ),
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedGoodIds.add(good.id);
                    } else {
                      _selectedGoodIds.remove(good.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          if (_budgetIsOver)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '⚠️ Превышен бюджет на ${-_budgetRemainingCoins} монет! Убери один товар.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.crimson,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          StoryButton(
            label: _budgetCanBuy
                ? 'Купить за $_budgetTotalCoins монет (сдача: $_budgetRemainingCoins)'
                : (_budgetIsOver ? 'Превышен бюджет (нужно < 20)' : 'Выбери товары'),
            onPressed: _budgetCanBuy
                ? () {
                    setState(() {
                      _spentCoins = _budgetTotalCoins;
                      _changeCoins = _budgetRemainingCoins;
                    });
                    _nextStep();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  /// ФИНАЛ: ПОБЕДНАЯ КАРТОЧКА С ВЫВОДОМ ПО СЦЕНАРИЮ
  Widget _buildFinalVictoryCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🎉 Урок финансовой грамотности пройден!',
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: AppColors.crimsonDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '«В другой стране могут использоваться другие деньги. Курс показывает, сколько одной валюты нужно для другой.»',
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 13.5,
                fontStyle: FontStyle.italic,
                height: 1.3,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Image.asset(TugrikiAssets.homeCoin, width: 22, height: 22),
                const SizedBox(width: 6),
                const Text(
                  '+20 монет начислено в кошелёк питомца!',
                  style: TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.leafGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
        StoryButton(
          label: 'Вернуться в домик Финни',
          showFlourish: true,
          onPressed: _exit,
        ),
      ],
    );
  }
}
