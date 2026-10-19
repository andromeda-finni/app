import 'package:flutter/material.dart';

import 'map/daily_quests.dart';
import 'map/quest_map_screen.dart';
import 'theme/app_theme.dart';

/// Visual review only. Actual daily selection lives in the authenticated API.
void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const QuestMapScreen(
      initialUnlockedIndex: 2,
      dailyPreview: DailyQuestDay(
        periodId: 'preview',
        sequenceNo: 1,
        planConfirmed: true,
        offers: [
          DailyQuestOffer(
            trackId: 'ivan',
            questId: 'Q_IVAN_ROAD_EASY_1',
            status: DailyQuestStatus.inProgress,
            rewardAmount: 10,
          ),
          DailyQuestOffer(
            trackId: 'squirrel',
            questId: 'Q_SQUIRREL_QUALITY_SIMPLE',
            status: DailyQuestStatus.available,
            rewardAmount: 10,
          ),
          DailyQuestOffer(
            trackId: 'goldfish',
            questId: 'Q_GOLDFISH_HOME_SIMPLE_1',
            status: DailyQuestStatus.available,
            rewardAmount: 10,
          ),
        ],
      ),
    ),
  ),
);
