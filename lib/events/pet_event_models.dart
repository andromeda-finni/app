/// Approved random-event content. Keeping the child-facing copy beside the UI
/// makes the client deterministic while the occurrence itself remains server
/// owned and survives app restarts.
class PetEventDefinition {
  const PetEventDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.lesson,
    required this.feedback,
  });

  final String id;
  final String title;
  final String description;
  final int amount;
  final String lesson;
  final String feedback;

  String dialogTitle(String petName) => switch (id) {
    'POOR_PAW' => 'Ой! $petName уколол лапку!',
    'SICK' => 'Ой! $petName простудился!',
    'HUNGRY' => 'Ой! $petName очень проголодался!',
    'COLD_NIGHT' => 'Ой! Печка остыла!',
    'ROOF_LEAK' => 'Ой! Прохудилась крыша!',
    'BEAVER_DAM' => 'Лесной сбор Бобру',
    _ => title,
  };

  String localizedDescription(String petName) =>
      description.replaceAll('Финни', petName);

  String localizedFeedback(String petName) =>
      feedback.replaceAll('Финни', petName);
}

const petEventCatalog = <String, PetEventDefinition>{
  'POOR_PAW': PetEventDefinition(
    id: 'POOR_PAW',
    title: 'Уколол лапку',
    description: 'Финни бегал по лесу за бабочкой и наступил на колючку. Нужен целебный подорожник и бинтик.',
    amount: 10,
    lesson: 'Непредвиденная медицина',
    feedback: 'Хорошо, когда есть монетки на лечение! Лапка снова в порядке!',
  ),
  'SICK': PetEventDefinition(
    id: 'SICK',
    title: 'Питомец простудился',
    description: 'На полянке прошел холодный дождь, Финни чихает и дрожит. Нужен липовый мед и теплый шарфик.',
    amount: 15,
    lesson: 'Сезонные болезни',
    feedback: 'Теплый чай и забота творят чудеса! Здоровье 100%.',
  ),
  'HUNGRY': PetEventDefinition(
    id: 'HUNGRY',
    title: 'Внезапный аппетит',
    description: 'Запасы орехов кончились, а после активных игр в лесу Финни очень проголодался. Нужна горячая похлебка.',
    amount: 10,
    lesson: 'Базовые потребности',
    feedback: 'Финни сыт и полон сил для новых приключений!',
  ),
  'COLD_NIGHT': PetEventDefinition(
    id: 'COLD_NIGHT',
    title: 'Печка остыла',
    description: 'Ночью обещают лесные заморозки. Нужна охапка сухих дров у Дровосека, чтобы в домике было тепло.',
    amount: 8,
    lesson: 'Коммунальные платежи и тепло',
    feedback: 'В домике снова тепло и потрескивает огонь.',
  ),
  'ROOF_LEAK': PetEventDefinition(
    id: 'ROOF_LEAK',
    title: 'Прохудилась крыша',
    description: 'Ночью сильный ветер сдул пару веток с крыши, и теперь капает на пол. Нужна смола и береста для ремонта.',
    amount: 14,
    lesson: 'Непредвиденный ремонт жилья',
    feedback: 'Крыша починена, никакой дождь нам не страшен!',
  ),
  'BEAVER_DAM': PetEventDefinition(
    id: 'BEAVER_DAM',
    title: 'Лесной сбор Бобру',
    description: 'Бобры укрепили плотину и починили мостик к Лесной Ярмарке. Все жители леса сдают монетки на общее дело.',
    amount: 7,
    lesson: 'Налоги и общественная инфраструктура',
    feedback: 'Мы внесли вклад в ремонт мостика, ярмарка открыта!',
  ),
};

class PetEventOccurrence {
  const PetEventOccurrence({
    required this.id,
    required this.definition,
    required this.amountDue,
    this.triggeredAt,
  });

  final String id;
  final PetEventDefinition definition;
  final int amountDue;
  final DateTime? triggeredAt;

  factory PetEventOccurrence.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final definitionId = json['event_definition_id'];
    final amount = json['amount_due'];
    if (id is! String || definitionId is! String || amount is! num) {
      throw const FormatException('invalid pet event occurrence');
    }
    final definition = petEventCatalog[definitionId];
    if (definition == null || amount.toInt() != definition.amount) {
      throw const FormatException('unapproved pet event occurrence');
    }
    final triggered = json['triggered_at'];
    return PetEventOccurrence(
      id: id,
      definition: definition,
      amountDue: amount.toInt(),
      triggeredAt: triggered is String ? DateTime.tryParse(triggered) : null,
    );
  }
}

class PetEventResolution {
  const PetEventResolution({
    required this.spendableBalance,
    required this.healthLevel,
  });

  final int spendableBalance;
  final int healthLevel;

  factory PetEventResolution.fromJson(Map<String, dynamic> json) {
    final balance = json['spendableBalance'];
    final health = json['healthLevel'];
    if (balance is! num || health is! num) {
      throw const FormatException('invalid pet event resolution');
    }
    return PetEventResolution(
      spendableBalance: balance.toInt(),
      healthLevel: health.toInt(),
    );
  }
}
