class ParkProjectState {
  const ParkProjectState({
    required this.stage,
    required this.scene,
    required this.targetAmount,
    required this.collectedAmount,
    required this.spendableBalance,
    required this.availableToContribute,
    required this.canContribute,
    required this.childContribution,
    required this.completed,
    this.offerAmount,
    this.daysToNextStage,
  });

  factory ParkProjectState.fromJson(Map<String, dynamic> json) =>
      ParkProjectState(
        stage: json['stage'] as String,
        scene: json['scene'] as String,
        targetAmount: (json['targetAmount'] as num).toInt(),
        collectedAmount: (json['collectedAmount'] as num).toInt(),
        offerAmount: (json['offerAmount'] as num?)?.toInt(),
        spendableBalance: (json['spendableBalance'] as num).toInt(),
        availableToContribute: (json['availableToContribute'] as num).toInt(),
        canContribute: json['canContribute'] == true,
        childContribution: (json['childContribution'] as num).toInt(),
        completed: json['completed'] == true,
        daysToNextStage: (json['daysToNextStage'] as num?)?.toInt(),
      );

  final String stage;
  final String scene;
  final int targetAmount;
  final int collectedAmount;
  final int? offerAmount;
  final int spendableBalance;
  final int availableToContribute;
  final bool canContribute;
  final int childContribution;
  final bool completed;
  final int? daysToNextStage;

  bool get hasOffer => stage == 'FIRST_OFFER' || stage == 'SECOND_OFFER';
  String get offerCode => stage == 'SECOND_OFFER' ? 'SECOND' : 'FIRST';
}

abstract final class ParkAssets {
  static const root = 'assets/minigames/park';
  static const background = '$root/fair_background.webp';
  static const badger = '$root/badger.webp';
  static const donationBox = '$root/donation_box.webp';
  static const parkBuilding = '$root/park_building.webp';
  static const parkAlmostReady = '$root/park_almost_ready.webp';
  static const parkOpen = '$root/park_open.webp';

  static String backgroundFor(String scene) => switch (scene) {
    'BUILDING' => parkBuilding,
    'ALMOST_READY' => parkAlmostReady,
    'OPEN' => parkOpen,
    _ => background,
  };

  static String backgroundLabelFor(String scene) => switch (scene) {
    'BUILDING' => 'Сказочный парк строится',
    'ALMOST_READY' => 'Сказочный парк почти готов к открытию',
    'OPEN' => 'Открытый сказочный парк с аттракционами',
    _ => 'Сказочная ярмарка',
  };
}
