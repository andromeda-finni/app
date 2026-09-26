import 'turnip_game_models.dart';

const turnipDefaultPetName = 'Грошик';

List<TurnipStoryLine> turnipIntroLinesFor(String petName) {
  final displayName = petName.trim().isEmpty
      ? turnipDefaultPetName
      : petName.trim();
  return [
    TurnipStoryLine(
      speaker: 'Дедушка',
      text:
          'Ох-ох! Привет, $displayName! Посмотри, какая у меня репка выросла! Я её и тяну, и тяну, а она ни с места!',
    ),
    TurnipStoryLine(speaker: displayName, text: 'Может, тебе нужна помощь?'),
    const TurnipStoryLine(
      speaker: 'Дедушка',
      text: 'Точно! Одному мне не справиться. Позовём остальных!',
    ),
  ];
}

const turnipTaskText = 'Перетащи помощников к Дедушке';
const turnipHintText = 'Попробуй поставить героев по росту!';
const turnipWrongOrderText = 'Ой, кажется, я стою не на своём месте!';
const turnipSuccessText =
    'Вместе герои вытащили репку. Часть урожая Дедушка отвезёт на ярмарку, чтобы получить монеты на необходимые покупки.';
