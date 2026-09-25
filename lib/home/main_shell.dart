import 'package:flutter/material.dart';

import '../core/api_client.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [
            HomeScreen(apiClient: widget.apiClient),
            for (final destination in kNavDestinations.skip(1))
              _TabPlaceholder(destination: destination),
          ],
        ),
      ),
      bottomNavigationBar: AppNavBar(
        currentIndex: _index,
        onSelected: (index) => setState(() => _index = index),
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
