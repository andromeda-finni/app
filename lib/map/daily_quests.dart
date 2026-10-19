import 'package:flutter/foundation.dart';

enum DailyQuestStatus { available, inProgress, completed }

@immutable
class DailyQuestOffer {
  const DailyQuestOffer({
    required this.trackId,
    required this.questId,
    required this.status,
    required this.rewardAmount,
  });

  factory DailyQuestOffer.fromJson(Map<String, dynamic> json) =>
      DailyQuestOffer(
        trackId: json['trackId'] as String,
        questId: json['questId'] as String,
        status: switch (json['status']) {
          'AVAILABLE' => DailyQuestStatus.available,
          'IN_PROGRESS' => DailyQuestStatus.inProgress,
          'COMPLETED' => DailyQuestStatus.completed,
          _ => throw const FormatException('Invalid daily quest status'),
        },
        rewardAmount: (json['rewardAmount'] as num).toInt(),
      );

  final String trackId;
  final String questId;
  final DailyQuestStatus status;
  final int rewardAmount;
  bool get canEarn => status != DailyQuestStatus.completed;
}

@immutable
class DailyQuestDay {
  const DailyQuestDay({
    required this.periodId,
    required this.sequenceNo,
    required this.planConfirmed,
    required this.offers,
    this.replays = const [],
  });

  factory DailyQuestDay.fromJson(Map<String, dynamic> json) {
    if (json['offers'] is! List) {
      throw const FormatException('Daily quest offers are missing');
    }
    return DailyQuestDay(
      periodId: json['periodId'] as String?,
      sequenceNo: (json['sequenceNo'] as num?)?.toInt(),
      planConfirmed: json['planConfirmed'] == true,
      offers: List.unmodifiable(
        (json['offers'] as List).map(
          (row) =>
              DailyQuestOffer.fromJson(Map<String, dynamic>.from(row as Map)),
        ),
      ),
      replays: List.unmodifiable(
        (json['replays'] as List? ?? []).map(
          (row) =>
              DailyQuestOffer.fromJson(Map<String, dynamic>.from(row as Map)),
        ),
      ),
    );
  }

  final String? periodId;
  final int? sequenceNo;
  final bool planConfirmed;
  final List<DailyQuestOffer> offers;
  final List<DailyQuestOffer> replays;

  DailyQuestOffer? offerFor(String trackId) =>
      offers.where((offer) => offer.trackId == trackId).firstOrNull;
  DailyQuestOffer? replayFor(String trackId) =>
      replays.where((offer) => offer.trackId == trackId).firstOrNull;
}

const noDailyQuestMessage = 'Сегодня помощь не нужна, приходи в другой день';
