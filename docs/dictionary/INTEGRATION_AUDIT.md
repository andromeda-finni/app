# Все точки подключения словарика

Дата: 18.10.2026. Основа: `main @ 06f48c5`. Рабочая ветка: `codex/dictionary-quest-highlights`.

Использован существующий каталог из 50 терминов. Добавлены 63 точки вывода через `DictionaryText` в 21 файле экранов. Точка вывода — место в коде, а не отдельное слово: она может показывать много реплик и уровней. Если финансовых слов в тексте нет, компонент возвращает обычный `Text`.

## Все 63 точки

### Репка — lib/games/turnip/widgets/turnip_intro_view.dart

1. **№ 1** — Реплики знакомства — line.text. В текущих репликах финансовых терминов нет. [Код, строка 99](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/games/turnip/widgets/turnip_intro_view.dart:99).

### Репка — lib/games/turnip/widgets/turnip_playfield.dart

1. **№ 2** — Текст задания — turnipTaskText. Сейчас это «Перетащи помощников к Дедушке», совпадений нет. [Код, строка 142](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/games/turnip/widgets/turnip_playfield.dart:142).
2. **№ 3** — Подсказки и обратная связь — text в _FeedbackCard. Текущие подсказки о порядке героев, совпадений нет. [Код, строка 194](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/games/turnip/widgets/turnip_playfield.dart:194).

### Репка — lib/games/turnip/widgets/turnip_success_view.dart

1. **№ 4** — Итог — turnipSuccessText: в рассказе о продаже урожая подсвечиваются «монеты» и «покупки». [Код, строка 141](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/games/turnip/widgets/turnip_success_view.dart:141).

### Крот — lib/minigames/mole/mole_game_screen.dart

1. **№ 5** — Название текущей проверки — title в _ProgressHeader. [Код, строка 582](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/mole/mole_game_screen.dart:582).
2. **№ 6** — Реплика Крота внутри облачка — text в _StoryScene. [Код, строка 686](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/mole/mole_game_screen.dart:686).
3. **№ 7** — Та же реплика отдельным текстом при крупном шрифте — второй вариант _StoryScene. [Код, строка 710](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/mole/mole_game_screen.dart:710).
4. **№ 8** — Формулировка вопроса — question.prompt. [Код, строка 770](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/mole/mole_game_screen.dart:770).
5. **№ 9** — Обратная связь после ответа — text в _FeedbackCard. [Код, строка 838](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/mole/mole_game_screen.dart:838).
6. **№ 10** — Текст завершённой проверки — text в _SolvedCard. [Код, строка 869](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/mole/mole_game_screen.dart:869).
7. **№ 11** — Сообщение о сохранении или награде — text в _SyncNote. Подсветка появляется только при наличии термина в сообщении. [Код, строка 907](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/mole/mole_game_screen.dart:907).

### Крот — lib/minigames/mole/mole_truth_case_view.dart

1. **№ 12** — Подсказка к документу — document.hint. [Код, строка 115](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/mole/mole_truth_case_view.dart:115).
2. **№ 13** — Итоговый заголовок: «Чек исправлен!», «Условие акции найдено!» и другие варианты. [Код, строка 153](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/mole/mole_truth_case_view.dart:153).
3. **№ 14** — Пояснение после проверки документа: итог покупки, неподходящий товар или условия. [Код, строка 196](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/mole/mole_truth_case_view.dart:196).
4. **№ 15** — Объяснение обнаруженной подмены — span.explanation. [Код, строка 229](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/mole/mole_truth_case_view.dart:229).
5. **№ 16** — Ответ продавца после решения — document.sellerReply. [Код, строка 238](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/mole/mole_truth_case_view.dart:238).

### Иван — lib/games/ivan/ivan_game_screen.dart

1. **№ 17** — Подсказка выбранного уровня — _controller.level.hintText. [Код, строка 170](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/games/ivan/ivan_game_screen.dart:170).

### Иван — lib/games/ivan/widgets/ivan_intro_view.dart

1. **№ 18** — Реплики перед покупками — line.text. [Код, строка 126](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/games/ivan/widgets/ivan_intro_view.dart:126).

### Иван — lib/games/ivan/widgets/ivan_shopping_view.dart

1. **№ 19** — Формулировка задачи на сборы — level.taskText. [Код, строка 184](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/games/ivan/widgets/ivan_shopping_view.dart:184).

### Иван — lib/games/ivan/widgets/ivan_result_view.dart

1. **№ 20** — Объяснение успеха или ошибки — level.successText / _failureText. [Код, строка 117](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/games/ivan/widgets/ivan_result_view.dart:117).
2. **№ 21** — Обучающий вывод «Что важно запомнить» — ivanLearningText. [Код, строка 149](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/games/ivan/widgets/ivan_result_view.dart:149).

### Золотая рыбка — lib/games/goldfish/goldfish_game_screen.dart

1. **№ 22** — Подсказка уровня — _controller.level.hintText. [Код, строка 178](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/games/goldfish/goldfish_game_screen.dart:178).
2. **№ 23** — Подсказка при нехватке денег — «Сравни цены и выбери товар подешевле.» [Код, строка 315](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/games/goldfish/goldfish_game_screen.dart:315).

### Золотая рыбка — lib/games/goldfish/widgets/goldfish_dialogue_view.dart

1. **№ 24** — Текущая реплика — line.text: вступление и диалоги результата, включая ветви нехватки бюджета, потребностей и запаса. [Код, строка 145](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/games/goldfish/widgets/goldfish_dialogue_view.dart:145).

### Золотая рыбка — lib/games/goldfish/widgets/goldfish_shopping_view.dart

1. **№ 25** — Текст задачи над магазином — level.taskText. [Код, строка 181](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/games/goldfish/widgets/goldfish_shopping_view.dart:181).

### Золотая рыбка — lib/games/goldfish/widgets/goldfish_result_view.dart

1. **№ 26** — Обучающий вывод уровня — level.learningText. [Код, строка 189](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/games/goldfish/widgets/goldfish_result_view.dart:189).

### Белочка — lib/games/squirrel/squirrel_game_screen.dart

1. **№ 27** — Реплики знакомства и результата — lines[page]. Контекстное исключение reserve: продуктовые «запасы» не открывают карточку денежного запаса. [Код, строка 445](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/games/squirrel/squirrel_game_screen.dart:445).
2. **№ 28** — Текст памятки покупателя — message в _SquirrelLessonCard. [Код, строка 588](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/games/squirrel/squirrel_game_screen.dart:588).
3. **№ 29** — Инструкция текущего режима — level.instruction. [Код, строка 813](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/games/squirrel/squirrel_game_screen.dart:813).

### Пекарня — lib/minigames/bakery/bakery_game_screen.dart

1. **№ 30** — Заголовок бумажной карточки — title в _PaperPanel, включая «Считаем сдачу» и «Считаем прибыль». [Код, строка 659](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/bakery/bakery_game_screen.dart:659).
2. **№ 31** — Основной текст карточки — text: вступление, покупки, вопросы, объяснение выручки и итог. [Код, строка 661](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/bakery/bakery_game_screen.dart:661).
3. **№ 32** — Подписи сумм — ключ и значение в _MoneySummary, в том числе выручка и расходы, когда эти подписи используются. [Код, строка 821](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/bakery/bakery_game_screen.dart:821).
4. **№ 33** — Формула вопроса — equation. Чистая арифметическая запись без термина остаётся обычным текстом. [Код, строка 866](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/bakery/bakery_game_screen.dart:866).
5. **№ 34** — Подсказки и сообщения после ответа — message в _FeedbackCard. [Код, строка 911](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/bakery/bakery_game_screen.dart:911).

### Тугрики — lib/minigames/tugriki/tugriki_game_screen.dart

1. **№ 35** — Все реплики Воробья и питомца — dialogueText. Вместо ручного выделения одного «бюджет» используются совпадения каталога. [Код, строка 919](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/tugriki/tugriki_game_screen.dart:919).
2. **№ 36** — Подпись «Раскладываем по 2 монетки:». [Код, строка 944](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/tugriki/tugriki_game_screen.dart:944).
3. **№ 37** — Пояснение «2 + 2 + 2 + 2 + 2 + 2 = 12 монеток (6 × 2 = 12)». [Код, строка 1032](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/tugriki/tugriki_game_screen.dart:1032).
4. **№ 38** — Подпись «Складываем тугрики за обед:». [Код, строка 1072](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/tugriki/tugriki_game_screen.dart:1072).
5. **№ 39** — Строка результата «= 9 тугриков». [Код, строка 1096](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/tugriki/tugriki_game_screen.dart:1096).
6. **№ 40** — Объяснение «Курс 1 к 2: значит 9 тугриков × 2 = 18 монеток». [Код, строка 1109](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/tugriki/tugriki_game_screen.dart:1109).
7. **№ 41** — Подпись интерактивного бюджета «Кошелек: 20 монет». [Код, строка 1143](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/tugriki/tugriki_game_screen.dart:1143).
8. **№ 42** — Остаток: «Сдача: … монет» / «Не хватает: … монет». [Код, строка 1152](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/tugriki/tugriki_game_screen.dart:1152).
9. **№ 43** — Предупреждение «Превышен бюджет на … монет! Убери один товар.». [Код, строка 1203](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/tugriki/tugriki_game_screen.dart:1203).
10. **№ 44** — Финальный вывод о деньгах другой страны, курсе и валюте. [Код, строка 1244](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/tugriki/tugriki_game_screen.dart:1244).

### Барсук / парк — lib/minigames/park/park_project_screen.dart

1. **№ 45** — Реплики Барсука и питомца — text в _speechPanel. [Код, строка 468](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/park/park_project_screen.dart:468).
2. **№ 46** — Описание первого или второго предложения помочь парку — state.stage. [Код, строка 506](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/park/park_project_screen.dart:506).
3. **№ 47** — Предупреждение «Сначала оставь монеты на важные покупки…». [Код, строка 532](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/park/park_project_screen.dart:532).
4. **№ 48** — Основной текст новостей о сборе и строительстве — text в _messagePanel. [Код, строка 579](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/park/park_project_screen.dart:579).
5. **№ 49** — Рассказ при открытии парка — вариант по state.childContribution. [Код, строка 607](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/park/park_project_screen.dart:607).
6. **№ 50** — Объяснение на высокой сложности — «Так же работают налоги: жители понемногу складывают деньги…». [Код, строка 616](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/park/park_project_screen.dart:616).
7. **№ 51** — Текст верхней плашки состояния — text в _StatusPill; при отсутствии терминов остаётся обычным текстом. [Код, строка 917](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/minigames/park/park_project_screen.dart:917).

### Лис — lib/events/fox/fox_event_dialog.dart

1. **№ 52** — Текущая страница реплики — pages[pageIndex], с подстановкой имени питомца. [Код, строка 377](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/events/fox/fox_event_dialog.dart:377).
2. **№ 53** — Обратная связь питомца — node.groshikFeedback, также с подстановкой имени. [Код, строка 562](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/events/fox/fox_event_dialog.dart:562).

### Карта — lib/map/quest_map_screen.dart

1. **№ 54** — Заголовок всплывающей карточки квеста — node.title. [Код, строка 1403](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/map/quest_map_screen.dart:1403).
2. **№ 55** — Каждая тема квеста — topic в _TopicPill. [Код, строка 1729](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/map/quest_map_screen.dart:1729).
3. **№ 56** — Название квеста в подробном описании — node.title. [Код, строка 1827](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/map/quest_map_screen.dart:1827).
4. **№ 57** — Описание квеста в подробной карточке — node.description. [Код, строка 1856](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/map/quest_map_screen.dart:1856).

### Копилка и сундук — lib/economy/savings_screen.dart

1. **№ 58** — Пояснение в окне выбора суммы — hint. Используется при переводах в копилку, возврате в кошелёк и открытии сундука. [Код, строка 171](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/economy/savings_screen.dart:171).
2. **№ 59** — Объяснение пустой цели: «Артефакт из сказки… Монеты из копилки пойдут к нему.». [Код, строка 596](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/economy/savings_screen.dart:596).
3. **№ 60** — Описание сундука: «Заморозь монеты… вернутся с бонусом» / «Монеты заморожены…». [Код, строка 1081](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/economy/savings_screen.dart:1081).
4. **№ 61** — Подпись суммы прибавки — «+… бонус». [Код, строка 1214](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/economy/savings_screen.dart:1214).
5. **№ 62** — Сообщение о сроке — «Срок вышел — можно забирать с бонусом.» / оставшиеся дни. [Код, строка 1236](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/economy/savings_screen.dart:1236).

### Страховка — lib/insurance/insurance_screen.dart

1. **№ 63** — Текст каждой строки сравнения _FactRow: варианты «Со страховкой…» и «Без страховки…», включая упомянутые монеты и проценты. [Код, строка 443](C:/Users/Pavel/Documents/Codex/2026-09-16/senior-ux-ui-wireflow-1-5/andromeda-dictionary-quests/lib/insurance/insurance_screen.dart:443).

## Общий механизм

- `lib/dictionary/dictionary_terms.dart`: явные формы всех 50 терминов, регистр, е/ё, границы слов, проценты после числа; приоритет составных выражений.
- `lib/dictionary/dictionary_text.dart`: подсветка каждого совпадения, двойное нажатие, определение нужного слова, клавиатура, действия экранного диктора, сохранение метрик текста, один цикл свечения, уменьшенное движение, контекстные исключения.
- `lib/dictionary/dictionary_scope.dart`: один контроллер прогресса профиля и исходные параметры текста для маршрутов, диалогов и нижних листов.
- `lib/home/main_shell.dart`: общий контекст словарика в оболочке и на маршруте страховки; остановка анимаций скрытой копилки.
- `lib/map/quest_map_screen.dart`: передача того же контекста в подробную карточку и во все восемь игровых маршрутов.
- `lib/minigames/tugriki/tugriki_game_screen.dart`: удалены ручной поиск подстроки «бюджет», отдельный обработчик только этого слова и флаг `explainBudget`.

## Как распознаются слова

- «монета», «монет», «монеток» ведут в одну карточку.
- «кошелёк» и «кошелек» считаются одним словом; исходное написание сохраняется.
- «полная цена» / «полная стоимость» ведут в «Полная стоимость».
- «городской бюджет», «общие деньги», «возврат долга», «сравнение цен», «курс обмена» обрабатываются целиком, если совпали с предусмотренной формой.
- «страхование» ведёт в «Страховка»; «займ» и «взаймы» — в «Заём»; «траты» — в «Расходы».
- Знак процента распознаётся после числа: 10%, 5 %.
- «долгий», «ценник», «чеканить» не дают ложного совпадения.
- Общие слова «надо», «хочу», «защита» не подсвечиваются автоматически как финансовые термины.
- У Белочки исключены продуктовые «запасы»; денежный «запас» в других сценах доступен.

## Что пока остаётся обычным текстом

Подсветка не установлена глобально на каждый `Text`. Кнопки ответа и покупки, подписи на карточках перетаскиваемых товаров и скрытые строки документов под лупой сохраняют игровое действие. Названия валют и «Бюджет 20м» в верхней панели Тугриков, ряд денежных счётчиков, заголовок «Копилка», ценники магазина и тексты онбординга также не были подключены этой правкой. Обнаруженные подмены у Крота объясняются уже в подключённом тексте после нахождения.

## Проверки и документация

- `test/dictionary_terms_test.dart` — названия и формы всех 50 терминов, составные выражения, границы, е/ё и исходные позиции.
- `test/dictionary_text_test.dart` — выбор определения, защита от перелистывания, клавиатура, смена реплики, диалоги/листы, 320 px и 200% текста, завершение свечения, реальная сцена Рыбки и исключение продуктовых запасов Белочки.
- `test/dictionary_widget_test.dart` — обновлена проверка настоящего сюжета Тугриков.
- `test/quest_map_test.dart` — проверка передачи одного профиля во все восемь квестов.
- `docs/dictionary/README.md` — правила и границы интеграции.
- `docs/dictionary/WORD_INVENTORY.md` — сохранены исторические источники 50 слов, добавлена отметка о текущем подключении.

## Каталог, использованный для распознавания

| Термин | ID |
| --- | --- |
| Деньги | `money` |
| Монета | `coin` |
| Кошелёк | `wallet` |
| Копилка | `piggy_bank` |
| Бюджет | `budget` |
| Доход | `income` |
| Расходы | `expenses` |
| Накопления | `savings` |
| Цель | `goal` |
| Потребность | `need` |
| Желание | `want` |
| Экономия | `economy` |
| Запас | `reserve` |
| Резерв | `required_reserve` |
| Баланс | `balance` |
| Цена | `price` |
| Стоимость | `cost` |
| Полная стоимость | `total_cost` |
| Покупка | `purchase` |
| Товар | `product` |
| Услуга | `service` |
| Сдача | `change` |
| Остаток | `remainder` |
| Скидка | `discount` |
| Акция | `promotion` |
| Чек | `receipt` |
| Доставка | `delivery` |
| Сравнение цен | `compare_prices` |
| Выручка | `revenue` |
| Прибыль | `profit` |
| Валюта | `currency` |
| Курс | `exchange_rate` |
| Обмен | `exchange` |
| Тугрик | `tugrik` |
| Заём | `loan` |
| Долг | `debt` |
| Возврат долга | `repayment` |
| Риск | `risk` |
| Кредит | `credit` |
| Аренда | `rental` |
| Подписка | `subscription` |
| Сделка | `deal` |
| Страховка | `insurance` |
| Общие деньги | `public_money` |
| Вклад | `contribution` |
| Городской бюджет | `city_budget` |
| Налоги | `taxes` |
| Процент | `percent` |
| Бонус | `bonus` |
| Срок | `term` |
