import 'fox_event_models.dart';

const kFoxScripts = <FoxScript>[
  _youngerIntroduction,
  _youngerTreasure,
  _youngerBoots,
  _olderHoneyBusiness,
  _olderUrgentSecret,
];

FoxScript foxScriptById(String id) =>
    kFoxScripts.firstWhere((script) => script.id == id);

List<FoxScript> foxScriptsFor(FoxAgeGroup ageGroup) => kFoxScripts
    .where((script) => script.ageGroup == ageGroup)
    .toList(growable: false);

const _youngerIntroduction = FoxScript(
  id: 'fox_younger_introduction',
  title: 'Знакомство',
  ageGroup: FoxAgeGroup.younger,
  initialNodeId: 'start',
  nodes: {
    'start': FoxStoryNode(
      id: 'start',
      speaker: 'Лис',
      text:
          'Привет! Я Лис. Живу неподалёку. Рад познакомиться! Иногда я '
          'прихожу к друзьям за советом, а иногда и за помощью. Вот и сегодня '
          'мне нужна помощь. Одолжишь мне 10 монет до завтра?',
      mood: FoxMood.friendly,
      choices: [
        FoxChoice(
          id: 'give_now',
          label: 'Хорошо, держи.',
          nextNodeId: 'gave_without_questions',
          coinDelta: -10,
        ),
        FoxChoice(
          id: 'refuse_now',
          label: 'Нет, не хочу.',
          nextNodeId: 'refused_without_questions',
        ),
        FoxChoice(
          id: 'ask_purpose',
          label: 'А зачем тебе деньги?',
          nextNodeId: 'purpose',
        ),
      ],
    ),
    'gave_without_questions': FoxStoryNode(
      id: 'gave_without_questions',
      speaker: 'Лис',
      text: 'Ого, спасибо! Ты настоящий друг! Завтра всё верну!',
      mood: FoxMood.friendly,
      choices: [
        FoxChoice(
          id: 'wait',
          label: 'Ждать до завтра',
          nextNodeId: 'returned_without_questions',
        ),
      ],
    ),
    'returned_without_questions': FoxStoryNode(
      id: 'returned_without_questions',
      speaker: 'Лис',
      text: 'Привет! Вот твои 10 монет, спасибо!',
      mood: FoxMood.friendly,
      waitUntilNextGameDay: true,
      coinDeltaOnEnter: 10,
      terminal: true,
      outcomeTone: FoxOutcomeTone.neutral,
      groshikFeedback:
          'Ура, Лис вернул наши монетки. Но давать деньги, не задавая '
          'вопросов, опасно: он мог их не вернуть. В следующий раз давай '
          'сначала спросим, зачем они ему нужны.',
    ),
    'refused_without_questions': FoxStoryNode(
      id: 'refused_without_questions',
      speaker: 'Лис',
      text:
          'Эх, жаль. Ну ладно, ничего страшного! Пойду спрошу у Медведя. '
          'До встречи!',
      mood: FoxMood.friendly,
      terminal: true,
      outcomeTone: FoxOutcomeTone.neutral,
      groshikFeedback:
          'Мы сохранили наши монетки. Говорить «нет» нормально. Но, может '
          'быть, у Лиса была хорошая идея для заработка? В следующий раз '
          'можно спросить, для чего ему деньги.',
    ),
    'purpose': FoxStoryNode(
      id: 'purpose',
      speaker: 'Лис',
      text: 'Хочу купить крепкую корзинку и собрать много ягод в лесу.',
      mood: FoxMood.friendly,
      choices: [
        FoxChoice(
          id: 'ask_repayment',
          label: 'А как ты вернёшь мне деньги?',
          nextNodeId: 'repayment_plan',
        ),
        FoxChoice(
          id: 'give_after_purpose',
          label: 'Хорошо, держи 10 монет.',
          nextNodeId: 'gave_after_purpose',
          coinDelta: -10,
        ),
        FoxChoice(
          id: 'refuse_after_purpose',
          label: 'Нет, я лучше не буду давать.',
          nextNodeId: 'refused_after_plan',
        ),
      ],
    ),
    'repayment_plan': FoxStoryNode(
      id: 'repayment_plan',
      speaker: 'Лис',
      text: 'Продам ягоды пекарю и верну тебе 10 монет.',
      mood: FoxMood.friendly,
      choices: [
        FoxChoice(
          id: 'give_after_questions',
          label: 'Дать 10 монет',
          nextNodeId: 'gave_after_questions',
          coinDelta: -10,
        ),
        FoxChoice(
          id: 'refuse_after_questions',
          label: 'Не давать',
          nextNodeId: 'refused_after_plan',
        ),
      ],
    ),
    'gave_after_purpose': FoxStoryNode(
      id: 'gave_after_purpose',
      speaker: 'Лис',
      text: 'Ура! Спасибо, друг! Побежал за ягодами!',
      mood: FoxMood.friendly,
      choices: [
        FoxChoice(
          id: 'wait',
          label: 'Ждать до завтра',
          nextNodeId: 'returned_after_purpose',
        ),
      ],
    ),
    'returned_after_purpose': FoxStoryNode(
      id: 'returned_after_purpose',
      speaker: 'Лис',
      text: 'Привет! Вот твои 10 монет, спасибо!',
      mood: FoxMood.friendly,
      waitUntilNextGameDay: true,
      coinDeltaOnEnter: 10,
      terminal: true,
      outcomeTone: FoxOutcomeTone.neutral,
      groshikFeedback:
          'Мы узнали, зачем Лису деньги, и это здорово. Но стоило ещё '
          'уточнить, как именно он планирует вернуть долг.',
    ),
    'gave_after_questions': FoxStoryNode(
      id: 'gave_after_questions',
      speaker: 'Лис',
      text: 'Спасибо! Побежал за корзинкой!',
      mood: FoxMood.friendly,
      choices: [
        FoxChoice(
          id: 'wait',
          label: 'Ждать до завтра',
          nextNodeId: 'returned_after_questions',
        ),
      ],
    ),
    'returned_after_questions': FoxStoryNode(
      id: 'returned_after_questions',
      speaker: 'Лис',
      text: 'Привет! Вот твои 10 монет, спасибо!',
      mood: FoxMood.friendly,
      waitUntilNextGameDay: true,
      coinDeltaOnEnter: 10,
      terminal: true,
      outcomeTone: FoxOutcomeTone.positive,
      groshikFeedback:
          'Хорошо, что ты узнал, откуда Лис возьмёт деньги, чтобы их '
          'вернуть. У него есть чёткий план. Ты поступил очень мудро!',
    ),
    'refused_after_plan': FoxStoryNode(
      id: 'refused_after_plan',
      speaker: 'Лис',
      text: 'Понимаю. Ничего страшного, попробую накопить на корзинку сам!',
      mood: FoxMood.friendly,
      terminal: true,
      outcomeTone: FoxOutcomeTone.positive,
      groshikFeedback:
          'План Лиса звучал интересно, но ты хозяин своих монеток. Если ты '
          'пока не готов давать в долг, лучше не рисковать. Ты всё сделал '
          'правильно!',
    ),
  },
);

const _youngerTreasure = FoxScript(
  id: 'fox_younger_treasure',
  title: 'Клад',
  ageGroup: FoxAgeGroup.younger,
  initialNodeId: 'start',
  nodes: {
    'start': FoxStoryNode(
      id: 'start',
      speaker: 'Лис',
      text:
          'Привет ещё раз! У меня появилась отличная идея. Одолжи мне 20 '
          'монет, а завтра я верну тебе 100!',
      mood: FoxMood.sly,
      choices: [
        FoxChoice(
          id: 'give_now',
          label: 'Держи.',
          nextNodeId: 'gave_without_questions',
          coinDelta: -20,
        ),
        FoxChoice(
          id: 'refuse_now',
          label: 'Нет.',
          nextNodeId: 'refused_without_questions',
        ),
        FoxChoice(
          id: 'ask_source',
          label: 'Откуда у тебя будет 100 монет?',
          nextNodeId: 'treasure_idea',
        ),
      ],
    ),
    'gave_without_questions': FoxStoryNode(
      id: 'gave_without_questions',
      speaker: 'Лис',
      text: 'Ого, вот это да! Жди меня завтра с горой золота!',
      mood: FoxMood.sly,
      choices: [
        FoxChoice(
          id: 'wait',
          label: 'Ждать до завтра',
          nextNodeId: 'lost_without_questions',
        ),
      ],
    ),
    'lost_without_questions': FoxStoryNode(
      id: 'lost_without_questions',
      speaker: 'Лис',
      text:
          'Прости... У меня не получилось вернуть деньги. Моя идея не '
          'сработала.',
      mood: FoxMood.friendly,
      waitUntilNextGameDay: true,
      terminal: true,
      outcomeTone: FoxOutcomeTone.caution,
      groshikFeedback:
          'Мы потеряли наши монетки. Если кто-то обещает огромные деньги '
          'просто так, лучше сначала узнать, в чём его идея.',
    ),
    'refused_without_questions': FoxStoryNode(
      id: 'refused_without_questions',
      speaker: 'Лис',
      text:
          'Эх, упускаешь такую выгоду! Ну ладно, пойду искать удачу в '
          'другом месте.',
      mood: FoxMood.sly,
      terminal: true,
      outcomeTone: FoxOutcomeTone.positive,
      groshikFeedback:
          'Мы сохранили наши монетки. Если кто-то обещает огромные деньги '
          'просто так, лучше отказаться. Но полезно спросить, в чём идея.',
    ),
    'treasure_idea': FoxStoryNode(
      id: 'treasure_idea',
      speaker: 'Лис',
      text: 'Я найду клад!',
      mood: FoxMood.sly,
      choices: [
        FoxChoice(
          id: 'ask_location',
          label: 'Ты знаешь, где он?',
          nextNodeId: 'no_plan',
        ),
      ],
    ),
    'no_plan': FoxStoryNode(
      id: 'no_plan',
      speaker: 'Лис',
      text: 'Нет... но вдруг повезёт!',
      mood: FoxMood.sly,
      choices: [
        FoxChoice(
          id: 'give_after_questions',
          label: 'Дать 20 монет',
          nextNodeId: 'gave_after_questions',
          coinDelta: -20,
        ),
        FoxChoice(
          id: 'refuse_after_questions',
          label: 'Не давать',
          nextNodeId: 'refused_after_questions',
        ),
      ],
    ),
    'gave_after_questions': FoxStoryNode(
      id: 'gave_after_questions',
      speaker: 'Лис',
      text: 'Спасибо! Я обязательно его найду, вот увидишь!',
      mood: FoxMood.sly,
      choices: [
        FoxChoice(
          id: 'wait',
          label: 'Ждать до завтра',
          nextNodeId: 'lost_after_questions',
        ),
      ],
    ),
    'lost_after_questions': FoxStoryNode(
      id: 'lost_after_questions',
      speaker: 'Лис',
      text:
          'Прости... Мне не повезло. Я копал весь день, но клада там нет. '
          'Твои монетки пропали.',
      mood: FoxMood.friendly,
      waitUntilNextGameDay: true,
      terminal: true,
      outcomeTone: FoxOutcomeTone.caution,
      groshikFeedback:
          'Клад Лис не нашёл, поэтому деньги вернуть не смог. Удача — не '
          'источник возврата денег. Давать в долг без настоящего плана '
          'очень опасно.',
    ),
    'refused_after_questions': FoxStoryNode(
      id: 'refused_after_questions',
      speaker: 'Лис',
      text: 'Жаль, что ты в меня не веришь. Пойду копать сам...',
      mood: FoxMood.friendly,
      terminal: true,
      outcomeTone: FoxOutcomeTone.positive,
      groshikFeedback:
          'Ты заметил, что у Лиса нет настоящего плана. Надеяться на удачу '
          'при возврате долга — плохая идея. Наши монетки в безопасности!',
    ),
  },
);

const _youngerBoots = FoxScript(
  id: 'fox_younger_boots',
  title: 'Красивые сапоги',
  ageGroup: FoxAgeGroup.younger,
  initialNodeId: 'start',
  nodes: {
    'start': FoxStoryNode(
      id: 'start',
      speaker: 'Лис',
      text:
          'Привет! Представляешь, я увидел очень красивые сапоги в магазине! '
          'Но мне на них не хватает совсем немного. Одолжишь мне 15 монет?',
      mood: FoxMood.friendly,
      choices: [
        FoxChoice(
          id: 'give_now',
          label: 'Конечно.',
          nextNodeId: 'gave_without_questions',
          coinDelta: -15,
        ),
        FoxChoice(
          id: 'refuse_now',
          label: 'Нет.',
          nextNodeId: 'refused_without_questions',
        ),
        FoxChoice(
          id: 'ask_need',
          label: 'А тебе они правда нужны?',
          nextNodeId: 'old_boots',
        ),
      ],
    ),
    'gave_without_questions': FoxStoryNode(
      id: 'gave_without_questions',
      speaker: 'Лис',
      text: 'Ура! Я куплю новые сапожки!',
      mood: FoxMood.friendly,
      choices: [
        FoxChoice(
          id: 'wait',
          label: 'Ждать до завтра',
          nextNodeId: 'lost_without_questions',
        ),
      ],
    ),
    'lost_without_questions': FoxStoryNode(
      id: 'lost_without_questions',
      speaker: 'Лис',
      text:
          'Прости... Деньги я потратил на сапоги, а заработать новые пока '
          'не успел. Вернуть долг не могу.',
      mood: FoxMood.friendly,
      waitUntilNextGameDay: true,
      terminal: true,
      outcomeTone: FoxOutcomeTone.caution,
      groshikFeedback:
          'Лис купил сапоги, но долг не вернул. Желание и необходимость — '
          'не одно и то же. Если покупка не так уж нужна, а плана возврата '
          'нет, лучше не спешить.',
    ),
    'refused_without_questions': FoxStoryNode(
      id: 'refused_without_questions',
      speaker: 'Лис',
      text: 'Эх, жаль. Придётся ходить в старых. Они ещё крепкие.',
      mood: FoxMood.friendly,
      terminal: true,
      outcomeTone: FoxOutcomeTone.positive,
      groshikFeedback:
          'Мы сохранили монетки. Отказывать нормально. Тем более Лис не '
          'сказал, как будет возвращать долг.',
    ),
    'old_boots': FoxStoryNode(
      id: 'old_boots',
      speaker: 'Лис',
      text: 'Ну... старые ещё хорошие. Просто эти гораздо красивее.',
      mood: FoxMood.friendly,
      choices: [
        FoxChoice(
          id: 'ask_repayment',
          label: 'А чем будешь возвращать долг?',
          nextNodeId: 'no_repayment_plan',
        ),
      ],
    ),
    'no_repayment_plan': FoxStoryNode(
      id: 'no_repayment_plan',
      speaker: 'Лис',
      text: 'Пока не знаю. Потом что-нибудь придумаю.',
      mood: FoxMood.sly,
      choices: [
        FoxChoice(
          id: 'give_after_questions',
          label: 'Дать 15 монет',
          nextNodeId: 'gave_after_questions',
          coinDelta: -15,
        ),
        FoxChoice(
          id: 'refuse_after_questions',
          label: 'Не давать',
          nextNodeId: 'refused_after_questions',
        ),
      ],
    ),
    'gave_after_questions': FoxStoryNode(
      id: 'gave_after_questions',
      speaker: 'Лис',
      text: 'Спасибо! Пойду скорее их куплю!',
      mood: FoxMood.friendly,
      choices: [
        FoxChoice(
          id: 'wait',
          label: 'Ждать до завтра',
          nextNodeId: 'lost_after_questions',
        ),
      ],
    ),
    'lost_after_questions': FoxStoryNode(
      id: 'lost_after_questions',
      speaker: 'Лис',
      text:
          'Прости... Сапоги красивые, но денег у меня ещё нет. Вернуть долг '
          'пока не могу.',
      mood: FoxMood.friendly,
      waitUntilNextGameDay: true,
      terminal: true,
      outcomeTone: FoxOutcomeTone.caution,
      groshikFeedback:
          'Лис купил сапоги, но долг не вернул. Желание и необходимость — '
          'не одно и то же. Если покупка не обязательная, а плана возврата '
          'нет, лучше не спешить с займом.',
    ),
    'refused_after_questions': FoxStoryNode(
      id: 'refused_after_questions',
      speaker: 'Лис',
      text: 'Ну ладно, ты прав. Старые сапоги ещё долго прослужат!',
      mood: FoxMood.friendly,
      terminal: true,
      outcomeTone: FoxOutcomeTone.positive,
      groshikFeedback:
          'Отличное решение. Если покупка не обязательная, а плана возврата '
          'нет, лучше не спешить с займом. Мы уберегли наши монетки!',
    ),
  },
);

const _olderHoneyBusiness = FoxScript(
  id: 'fox_older_honey_business',
  title: 'Медовый бизнес',
  ageGroup: FoxAgeGroup.older,
  initialNodeId: 'start',
  nodes: {
    'start': FoxStoryNode(
      id: 'start',
      speaker: 'Лис',
      text: 'Привет, {petName}! Я Лис. Живу неподалёку. Рад познакомиться!',
      continuationTexts: [
        'Иногда я прихожу к друзьям за советом и помощью. Будь другом, помоги пожалуйста.',
        'Сейчас мне очень нужны 20 монет. Через три дня я верну тебе 25.',
      ],
      mood: FoxMood.friendly,
      choices: [
        FoxChoice(
          id: 'give_now',
          label: 'Держи.',
          nextNodeId: 'gave_without_questions',
          coinDelta: -20,
        ),
        FoxChoice(
          id: 'refuse_now',
          label: 'Не дам.',
          nextNodeId: 'refused_without_questions',
        ),
        FoxChoice(
          id: 'ask_purpose',
          label: 'На что нужны деньги?',
          nextNodeId: 'business_plan',
        ),
      ],
    ),
    'gave_without_questions': FoxStoryNode(
      id: 'gave_without_questions',
      speaker: 'Лис',
      text: 'Ого, спасибо! Жди меня завтра!',
      mood: FoxMood.friendly,
      choices: [
        FoxChoice(
          id: 'wait',
          label: 'Ждать до завтра',
          nextNodeId: 'returned_without_profit',
        ),
      ],
    ),
    'returned_without_profit': FoxStoryNode(
      id: 'returned_without_profit',
      speaker: 'Лис',
      text: 'Прости, бизнес пошёл не по плану. Смог вернуть только 20 монет.',
      mood: FoxMood.friendly,
      waitUntilNextGameDay: true,
      coinDeltaOnEnter: 20,
      terminal: true,
      outcomeTone: FoxOutcomeTone.neutral,
      groshikFeedback:
          'Мы вернули свои монетки, но не заработали. Давать деньги вслепую '
          '— риск. Нам повезло, что Лис вернул хотя бы то, что взял.',
    ),
    'refused_without_questions': FoxStoryNode(
      id: 'refused_without_questions',
      speaker: 'Лис',
      text: 'Как знаешь! Бизнес не ждёт, пойду искать, у кого попросить.',
      mood: FoxMood.sly,
      terminal: true,
      outcomeTone: FoxOutcomeTone.neutral,
      groshikFeedback:
          'Наши деньги в безопасности. Но Лис предлагал узнать подробности. '
          'Возможно, мы упустили шанс заработать. В следующий раз стоит '
          'хотя бы выслушать идею.',
    ),
    'business_plan': FoxStoryNode(
      id: 'business_plan',
      speaker: 'Лис',
      text: 'Хочу купить у Медведя мёд и продать его в магазине подороже.',
      mood: FoxMood.sly,
      choices: [
        FoxChoice(
          id: 'ask_risk',
          label: 'А если мёд не купят?',
          nextNodeId: 'risk_explained',
        ),
      ],
    ),
    'risk_explained': FoxStoryNode(
      id: 'risk_explained',
      speaker: 'Лис',
      text:
          'Тогда продам дешевле. Возможно, заработаю меньше, чем рассчитываю, '
          'или вообще выйду в ноль. Как получится.',
      mood: FoxMood.friendly,
      choices: [
        FoxChoice(
          id: 'take_risk',
          label: 'Рискнём. Держи 20 монет.',
          nextNodeId: 'gave_after_questions',
          coinDelta: -20,
        ),
        FoxChoice(
          id: 'decline_risk',
          label: 'Слишком рискованно. Я пас.',
          nextNodeId: 'refused_after_questions',
        ),
      ],
    ),
    'gave_after_questions': FoxStoryNode(
      id: 'gave_after_questions',
      speaker: 'Лис',
      text: 'Спасибо за доверие! Пойду закупать мёд!',
      mood: FoxMood.friendly,
      choices: [
        FoxChoice(
          id: 'wait',
          label: 'Ждать до завтра',
          nextNodeId: 'returned_after_risk',
        ),
      ],
    ),
    'returned_after_risk': FoxStoryNode(
      id: 'returned_after_risk',
      speaker: 'Лис',
      text:
          'Мёд продавался плохо, пришлось делать скидки. Прибыли нет, но '
          'твой долг я возвращаю полностью, как и обещал!',
      mood: FoxMood.friendly,
      waitUntilNextGameDay: true,
      coinDeltaOnEnter: 20,
      terminal: true,
      outcomeTone: FoxOutcomeTone.positive,
      groshikFeedback:
          'План был реальный, но прибыль в бизнесе никогда не гарантирована. '
          'Ты задал правильные вопросы, оценил риски и знал, на что идёшь.',
    ),
    'refused_after_questions': FoxStoryNode(
      id: 'refused_after_questions',
      speaker: 'Лис',
      text: 'Понимаю. В бизнесе всегда есть риск. До встречи!',
      mood: FoxMood.friendly,
      terminal: true,
      outcomeTone: FoxOutcomeTone.positive,
      groshikFeedback:
          'Хороший анализ. Мы выяснили, что прибыль не гарантирована, и '
          'решили не рисковать своими деньгами.',
    ),
  },
);

const _olderUrgentSecret = FoxScript(
  id: 'fox_older_urgent_secret',
  title: 'Срочный секрет',
  ageGroup: FoxAgeGroup.older,
  initialNodeId: 'start',
  nodes: {
    'start': FoxStoryNode(
      id: 'start',
      speaker: 'Лис',
      text:
          'Привет, друг! Выручай! Мне СРОЧНО нужны 30 монет. Прямо сейчас! '
          'Завтра верну 50! Только никому ни слова, это наш большой секрет!',
      mood: FoxMood.sly,
      choices: [
        FoxChoice(
          id: 'give_now',
          label: 'Ничего себе, держи 30 монет!',
          nextNodeId: 'gave_without_questions',
          coinDelta: -30,
        ),
        FoxChoice(
          id: 'refuse_now',
          label: 'Нет, я не даю деньги в такой спешке.',
          nextNodeId: 'refused_without_questions',
        ),
        FoxChoice(
          id: 'ask_reason',
          label: 'Успокойся. Зачем тебе деньги так срочно?',
          nextNodeId: 'real_reason',
        ),
      ],
    ),
    'gave_without_questions': FoxStoryNode(
      id: 'gave_without_questions',
      speaker: 'Лис',
      text: 'Спасибо! Ты меня спас! Завтра вернусь!',
      mood: FoxMood.sly,
      choices: [
        FoxChoice(
          id: 'wait',
          label: 'Ждать до завтра',
          nextNodeId: 'did_not_return',
        ),
      ],
    ),
    'did_not_return': FoxStoryNode(
      id: 'did_not_return',
      speaker: '{petName}',
      text: 'Лис не пришёл и не вернул 30 монет.',
      mood: FoxMood.friendly,
      waitUntilNextGameDay: true,
      terminal: true,
      outcomeTone: FoxOutcomeTone.caution,
      groshikFeedback:
          'Если от тебя требуют деньги срочно и просят хранить это в '
          'секрете, это тревожные признаки. Давление и спешка — плохие '
          'советчики в денежных решениях.',
    ),
    'refused_without_questions': FoxStoryNode(
      id: 'refused_without_questions',
      speaker: 'Лис',
      text: 'Эх, ты не понимаешь! Ладно, побегу к Волку...',
      mood: FoxMood.sly,
      terminal: true,
      outcomeTone: FoxOutcomeTone.positive,
      groshikFeedback:
          'Ситуация выглядит подозрительно. Если тебя торопят и просят '
          'хранить денежное решение в секрете, безопаснее остановиться и всё '
          'проверить.',
    ),
    'real_reason': FoxStoryNode(
      id: 'real_reason',
      speaker: 'Лис',
      text:
          'Ладно, скажу честно. Я занял у Медведя 20 монет на красивую '
          'рубашку, а вернуть не смог. Мне нужно отдать ему 20 монет, а на '
          'оставшиеся 10 я куплю лотерейный билет. Я точно выиграю и верну '
          'тебе 50!',
      mood: FoxMood.sly,
      choices: [
        FoxChoice(
          id: 'ask_debt_risk',
          label:
              'Брать новый долг, чтобы отдать старый? А если билет не '
              'выиграет?',
          nextNodeId: 'lottery_hope',
        ),
      ],
    ),
    'lottery_hope': FoxStoryNode(
      id: 'lottery_hope',
      speaker: 'Лис',
      text: 'Выиграет, я чувствую! Ну так что, поможешь?!',
      mood: FoxMood.sly,
      choices: [
        FoxChoice(
          id: 'give_after_questions',
          label: 'Дать 30 монет',
          nextNodeId: 'gave_after_questions',
          coinDelta: -30,
        ),
        FoxChoice(
          id: 'refuse_after_questions',
          label: 'Не давать',
          nextNodeId: 'refused_after_questions',
        ),
      ],
    ),
    'gave_after_questions': FoxStoryNode(
      id: 'gave_after_questions',
      speaker: 'Лис',
      text: 'Спасибо... Я побежал покупать билет!',
      mood: FoxMood.sly,
      choices: [
        FoxChoice(
          id: 'wait',
          label: 'Ждать до завтра',
          nextNodeId: 'lottery_lost',
        ),
      ],
    ),
    'lottery_lost': FoxStoryNode(
      id: 'lottery_lost',
      speaker: 'Лис',
      text:
          'Прости... Билет ничего не выиграл. Медведю я долг отдал, но '
          'теперь должен тебе 30 монет, а отдавать нечем.',
      mood: FoxMood.friendly,
      waitUntilNextGameDay: true,
      terminal: true,
      outcomeTone: FoxOutcomeTone.caution,
      groshikFeedback:
          'У Лиса не было источника дохода, только надежда на удачу. Брать '
          'новый долг, чтобы погасить старый, опасно.',
    ),
    'refused_after_questions': FoxStoryNode(
      id: 'refused_after_questions',
      speaker: 'Лис',
      text:
          'Наверное, лотерея — глупая идея. Пойду к Медведю, признаюсь, что '
          'денег нет, и предложу отработать долг на огороде.',
      mood: FoxMood.friendly,
      terminal: true,
      outcomeTone: FoxOutcomeTone.positive,
      groshikFeedback:
          'Ты распознал сразу две ловушки: срочность и попытку закрыть '
          'старый долг новым. Деньги остались в безопасности, а Лис нашёл '
          'более разумный выход.',
    ),
  },
);
