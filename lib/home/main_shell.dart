import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../economy/savings_screen.dart';
import '../profile/child_access_code.dart';
import '../quest_map/quest_map_screen.dart';
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
  const MainShell({super.key, required this.apiClient, this.onSwitchAudience});

  final ApiClient apiClient;

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
  StoreMode _storeMode = StoreMode.normal;
  ChildSettingsSnapshot _settings = const ChildSettingsSnapshot();

  Future<void> _openSettings(String? petId) async {
    // Only the home tab already holds the pet; from elsewhere ask the server,
    // so the access code shown is always the child's real one.
    var id = petId;
    if (id == null) {
      try {
        id = (await widget.apiClient.get('/pet'))['id'] as String?;
      } on ApiException {
        id = null;
      }
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (screenContext) => ChildSettingsScreen(
          childCode: childAccessCodeFrom(id),
          initialSettings: _settings,
          onSettingsChanged: (next) => setState(() => _settings = next),
          onSwitchAudience: () {
            Navigator.of(screenContext).pop();
            widget.onSwitchAudience?.call();
          },
        ),
      ),
    );
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

  void _selectTab(int index) {
    setState(() {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              onOpenSettings: _openSettings,
            ),
            QuestMapScreen(
              key: ValueKey('map-$_mapRevision'),
              apiClient: widget.apiClient,
              // A tab root has nothing to go back to; the header hides the
              // arrow instead of offering a button that does nothing.
              showBack: false,
            ),
            ShopScreen(
              key: ValueKey('store-$_storeRevision'),
              apiClient: widget.apiClient,
              mode: _storeMode,
              onBack: () => setState(() => _index = _storeReturnIndex),
              onGoalSelected: _goalSelected,
            ),
            SavingsScreen(
              key: ValueKey('savings-$_savingsRevision'),
              apiClient: widget.apiClient,
              onBack: () => setState(() => _index = 0),
              onChooseGoal: () => _openGoalStore(StoreMode.selectGoal),
              onBrowseGoals: () => _openGoalStore(StoreMode.browseGoals),
              onOpenSettings: () => _openSettings(null),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppNavBar(
        currentIndex: _index,
        onSelected: _selectTab,
      ),
    );
  }
}
