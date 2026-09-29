import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/child_difficulty.dart';
import '../core/game_audio_service.dart';
import '../economy/savings_screen.dart';
import '../insurance/insurance_screen.dart';
import '../map/quest_map_screen.dart';
import '../settings/child_settings_screen.dart';
import '../shop/shop_screen.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'widgets/app_nav_bar.dart';

/// The app once onboarding is done: four tabs behind one bottom bar.
///
/// The tabs live in an [IndexedStack] rather than being rebuilt on every
/// switch, so each keeps its scroll position and any in-progress input while
/// the child moves between them.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.apiClient,
    this.initialDifficulty = ChildDifficulty.beginner,
    this.onSwitchAudience,
  });

  final ApiClient apiClient;
  final ChildDifficulty initialDifficulty;

  /// Returns to the child/parent role choice; wired from the settings screen.
  final VoidCallback? onSwitchAudience;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _storeReturnIndex = 0;
  int _homeRevision = 0;
  int _storeRevision = 0;
  int _savingsRevision = 0;
  int _mapRevision = 0;
  bool _focusHomePlan = false;
  StoreMode _storeMode = StoreMode.normal;
  bool _planningRequired = false;
  late ChildSettingsSnapshot _settings;

  @override
  void initState() {
    super.initState();
    _settings = ChildSettingsSnapshot(difficulty: widget.initialDifficulty);
    GameAudioService.instance.configure(
      soundEnabled: _settings.sound,
      musicEnabled: _settings.music,
    );
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = ChildSettingsSnapshot.fromJson(
        await widget.apiClient.get('/child/settings'),
      );
      if (!mounted) return;
      GameAudioService.instance.configure(
        soundEnabled: settings.sound,
        musicEnabled: settings.music,
      );
      setState(() => _settings = settings);
    } on ApiException {
      // Keep safe local defaults; the settings screen exposes an explicit
      // retry/error state if the child opens it while the server is offline.
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (screenContext) => ChildSettingsScreen(
          apiClient: widget.apiClient,
          initialSettings: _settings,
          onSettingsChanged: (next) {
            GameAudioService.instance.configure(
              soundEnabled: next.sound,
              musicEnabled: next.music,
            );
            if (_index == 1 && next.music) {
              unawaited(
                GameAudioService.instance.startAmbience(
                  GameAmbience.forestBirds,
                ),
              );
            }
            setState(() {
              if (next.difficulty != _settings.difficulty) _mapRevision++;
              _settings = next;
            });
          },
          onSwitchAudience: () {
            Navigator.of(screenContext).pop();
            widget.onSwitchAudience?.call();
          },
        ),
      ),
    );
  }

  Future<void> _openInsurance() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InsuranceScreen(apiClient: widget.apiClient),
      ),
    );
    if (!mounted) return;
    setState(() {
      _homeRevision++;
      _storeRevision++;
    });
  }

  void _openGoalStore(StoreMode mode) {
    setState(() {
      _storeReturnIndex = _index;
      _storeMode = mode;
      _storeRevision++;
      _index = 2;
    });
  }

  void _goalSelected() {
    setState(() {
      _storeMode = StoreMode.normal;
      _homeRevision++;
      _savingsRevision++;
      _index = 3;
    });
  }

  void _openPlan() {
    unawaited(GameAudioService.instance.stopAmbience());
    setState(() {
      _focusHomePlan = true;
      _homeRevision++;
      _index = 0;
    });
  }

  void _selectTab(int index) {
    if (_planningRequired && (index == 1 || index == 2)) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Сначала составим план'),
          content: const Text(
            'Распредели монеты на сегодня — после этого откроются карта и магазин.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Позже'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openPlan();
              },
              child: const Text('Составить план'),
            ),
          ],
        ),
      );
      return;
    }
    unawaited(GameAudioService.instance.play(GameSound.uiTap));
    if (index == 1) {
      unawaited(
        GameAudioService.instance.startAmbience(GameAmbience.forestBirds),
      );
    } else {
      unawaited(GameAudioService.instance.stopAmbience());
    }
    setState(() {
      // A plan request is one-shot; later visits to the home must not reopen it.
      _focusHomePlan = false;
      if (index == 0) _homeRevision++;
      // Re-read quest progress so a game finished elsewhere opens the next node.
      if (index == 1) _mapRevision++;
      if (index == 2) {
        _storeMode = StoreMode.normal;
        _storeReturnIndex = _index;
        _storeRevision++;
      }
      if (index == 3) _savingsRevision++;
      _index = index;
      if (index != 0) _focusHomePlan = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final content = Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [
            HomeScreen(
              key: ValueKey('home-$_homeRevision'),
              apiClient: widget.apiClient,
              onChooseGoal: () => _openGoalStore(StoreMode.selectGoal),
              onOpenShop: () => _selectTab(2),
              onOpenQuests: () => _selectTab(1),
              onOpenSettings: _openSettings,
              onOpenInsurance: _openInsurance,
              onPlanningRequiredChanged: (required) {
                if (_planningRequired == required || !mounted) return;
                setState(() => _planningRequired = required);
              },
              focusPlan: _focusHomePlan,
            ),
            QuestMapScreen(
              key: ValueKey('map-$_mapRevision'),
              apiClient: widget.apiClient,
              // A tab root has nothing to go back to; the header hides the
              // arrow instead of offering a button that does nothing.
              showBack: false,
              difficulty: _settings.difficulty,
            ),
            ShopScreen(
              key: ValueKey('store-$_storeRevision'),
              apiClient: widget.apiClient,
              mode: _storeMode,
              onBack: () => setState(() => _index = _storeReturnIndex),
              onGoalSelected: _goalSelected,
              onOpenPlan: _openPlan,
              onOpenQuests: () => _selectTab(1),
            ),
            SavingsScreen(
              key: ValueKey('savings-$_savingsRevision'),
              apiClient: widget.apiClient,
              onBack: () => setState(() => _index = 0),
              onChooseGoal: () => _openGoalStore(StoreMode.selectGoal),
              onBrowseGoals: () => _openGoalStore(StoreMode.browseGoals),
              onOpenSettings: _openSettings,
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppNavBar(
        currentIndex: _index,
        onSelected: _selectTab,
      ),
    );
    return MediaQuery(
      data: media.copyWith(
        textScaler: _settings.largeText
            ? media.textScaler.clamp(minScaleFactor: 1.15, maxScaleFactor: 2.0)
            : media.textScaler,
      ),
      child: content,
    );
  }
}
