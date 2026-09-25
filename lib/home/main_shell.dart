import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../economy/savings_screen.dart';
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
  const MainShell({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _storeReturnIndex = 0;
  int _homeRevision = 0;
  int _storeRevision = 0;
  int _savingsRevision = 0;
  StoreMode _storeMode = StoreMode.normal;

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
            ),
            _TabPlaceholder(destination: kNavDestinations[1]),
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

/// Stand-in body for a tab whose real screen has not been built yet. Each tab
/// names itself so switching is visibly doing something.
class _TabPlaceholder extends StatelessWidget {
  const _TabPlaceholder({required this.destination});

  final NavDestination destination;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              destination.activeIcon,
              size: 64,
              color: AppColors.crimsonFaded,
            ),
            const SizedBox(height: 16),
            Text(destination.label, style: AppTextStyles.cardTitle),
            const SizedBox(height: 8),
            Text(
              'Этот экран ещё в разработке.',
              textAlign: TextAlign.center,
              style: AppTextStyles.swatchLabel,
            ),
          ],
        ),
      ),
    );
  }
}
