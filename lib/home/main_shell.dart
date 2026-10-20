import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/child_difficulty.dart';
import '../core/game_audio_service.dart';
import '../core/large_text.dart';
import '../core/offline/offline_banner.dart';
import '../dictionary/dictionary_progress.dart';
import '../dictionary/dictionary_scope.dart';
import '../dictionary/dictionary_storage.dart';
import '../dictionary/scroll_sheet.dart';
import '../dictionary/word_token.dart';
import '../economy/savings_screen.dart';
import '../insurance/insurance_screen.dart';
import '../map/quest_map_screen.dart';
import '../settings/child_settings_screen.dart';
import '../shop/shop_screen.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'home_tour.dart';
import 'main_tabs_tour.dart';
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
    this.showHomeTour = false,
    this.showMainTabsTour = false,
    this.onSwitchAudience,
    this.dictionaryProgress,
  });

  final ApiClient apiClient;
  final ChildDifficulty initialDifficulty;
  final bool showHomeTour;
  final bool showMainTabsTour;

  /// Returns to the child/parent role choice; wired from the settings screen.
  final VoidCallback? onSwitchAudience;
  final DictionaryProgress? dictionaryProgress;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _tourOverlayKey = GlobalKey(debugLabel: 'home-tour-overlay');
  final _tourTargets = HomeTourTargets();
  final _mainTabsTourTargets = MainTabsTourTargets();
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
  late final DictionaryProgress _dictionary =
      widget.dictionaryProgress ??
      DictionaryProgress(
        storage: DeviceDictionaryStorage(apiClient: widget.apiClient),
      );
  bool _homeReady = false;
  bool _tourCompleted = false;
  bool _tourBusy = false;
  int _tourStep = 0;
  String? _tourError;
  List<Rect> _spotlights = const [];
  bool _mainTabsTourStarted = false;
  bool _mainTabsTourCompleted = false;
  bool _mainTabsTourBusy = false;
  int _mainTabsTourStep = 0;
  String? _mainTabsTourError;
  List<Rect> _mainTabsSpotlights = const [];
  final Set<int> _mainTabsReady = {};

  @override
  void initState() {
    super.initState();
    _settings = ChildSettingsSnapshot(difficulty: widget.initialDifficulty);
    LargeTextScope.enabled.value = _settings.largeText;
    widget.apiClient.offline?.addListener(_offlineChanged);
    GameAudioService.instance.configure(
      soundEnabled: _settings.sound,
      musicEnabled: _settings.music,
    );
    _loadSettings();
  }

  @override
  void dispose() {
    // The parent side and onboarding do not use the child's setting.
    LargeTextScope.enabled.value = false;
    widget.apiClient.offline?.removeListener(_offlineChanged);
    _tourTargets.dispose();
    _mainTabsTourTargets.dispose();
    if (widget.dictionaryProgress == null) _dictionary.dispose();
    super.dispose();
  }

  int _seenSyncRevision = 0;
  int _homeSyncSignal = 0;

  /// After actions done offline reach the server, the screens reload the
  /// server's state, and anything it refused is explained to the child.
  void _offlineChanged() {
    final sync = widget.apiClient.offline;
    if (sync == null || !mounted) return;
    if (sync.syncRevision != _seenSyncRevision) {
      _seenSyncRevision = sync.syncRevision;
      // The home reloads in place; other tabs are rebuilt only when hidden,
      // so a child in the middle of a shop shelf is not thrown back.
      setState(() {
        _homeSyncSignal++;
        if (_index != 2) _storeRevision++;
        if (_index != 3) _savingsRevision++;
      });
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    for (final notice in sync.takeNotices()) {
      messenger?.showSnackBar(SnackBar(content: Text(notice)));
    }
  }

  bool get _tourActive => widget.showHomeTour && _homeReady && !_tourCompleted;

  bool get _mainTabsTourActive =>
      widget.showMainTabsTour &&
      _mainTabsTourStarted &&
      !_mainTabsTourCompleted &&
      _mainTabsReady.contains(
        _mainTabsTourTargets.tabForStep(_mainTabsTourStep),
      );

  void _homeDidBecomeReady() {
    if (_homeReady) return;
    setState(() => _homeReady = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tourActive) {
        _prepareTourStep(0);
      } else {
        _startMainTabsTour();
      }
    });
  }

  Duration _tourMotionDuration() =>
      MediaQuery.maybeOf(context)?.disableAnimations == true
      ? Duration.zero
      : const Duration(milliseconds: 260);

  Future<void> _moveScroll(ScrollController controller, double offset) async {
    final duration = _tourMotionDuration();
    if (duration == Duration.zero) {
      controller.jumpTo(offset);
      return;
    }
    await controller.animateTo(
      offset,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _prepareTourStep(int step) async {
    if (!mounted || !_tourActive || _tourBusy) return;
    setState(() {
      _tourStep = step;
      _tourError = null;
      _spotlights = const [];
    });

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_tourTargets.scrollController.hasClients) return;

    final controller = _tourTargets.scrollController;
    if (step < 2) {
      await _moveScroll(controller, 0);
    } else {
      final planContext = _tourTargets.plan.currentContext;
      if (planContext == null) {
        await _moveScroll(
          controller,
          controller.position.maxScrollExtent.clamp(0, 520),
        );
        await WidgetsBinding.instance.endOfFrame;
      }
      final visiblePlanContext = _tourTargets.plan.currentContext;
      if (visiblePlanContext != null && visiblePlanContext.mounted) {
        await Scrollable.ensureVisible(
          visiblePlanContext,
          alignment: 0.08,
          duration: _tourMotionDuration(),
          curve: Curves.easeOutCubic,
        );
      }
    }
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) _refreshSpotlights();
  }

  void _refreshSpotlights() {
    final overlayBox = _tourOverlayKey.currentContext?.findRenderObject();
    if (overlayBox is! RenderBox || !overlayBox.hasSize) return;
    final viewport = Offset.zero & overlayBox.size;
    final rects = <Rect>[];
    for (final key in _tourTargets.keysForStep(_tourStep)) {
      final targetBox = key.currentContext?.findRenderObject();
      if (targetBox is! RenderBox || !targetBox.hasSize) continue;
      final origin = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
      final rect = origin & targetBox.size;
      if (rect.overlaps(viewport)) rects.add(rect.intersect(viewport));
    }
    if (mounted) setState(() => _spotlights = rects);
  }

  Future<void> _nextTourStep() async {
    if (_tourStep < 2) {
      await _prepareTourStep(_tourStep + 1);
      return;
    }
    await _finishTour();
  }

  Future<void> _finishTour() async {
    if (_tourBusy) return;
    setState(() {
      _tourBusy = true;
      _tourError = null;
    });
    try {
      final response = await widget.apiClient.put('/onboarding/home-tour');
      if (response['homeTourCompleted'] != true) {
        throw const FormatException('Invalid home tour response');
      }
      if (_tourTargets.scrollController.hasClients) {
        await _moveScroll(_tourTargets.scrollController, 0);
      }
      if (!mounted) return;
      setState(() {
        _tourBusy = false;
        _tourCompleted = true;
        _spotlights = const [];
      });
      _startMainTabsTour();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tourBusy = false;
        _tourError = 'Не получилось сохранить. Попробовать ещё раз.';
      });
    }
  }

  void _startMainTabsTour() {
    if (!mounted ||
        !widget.showMainTabsTour ||
        _mainTabsTourStarted ||
        _mainTabsTourCompleted ||
        _tourActive) {
      return;
    }
    setState(() {
      _mainTabsTourStarted = true;
      _index = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _prepareMainTabsTourStep(0),
    );
  }

  void _mainTabDidBecomeReady(int tab) {
    _mainTabsReady.add(tab);
    if (!_mainTabsTourActive ||
        _mainTabsTourTargets.tabForStep(_mainTabsTourStep) != tab) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _prepareMainTabsTourStep(_mainTabsTourStep),
    );
  }

  Future<void> _prepareMainTabsTourStep(int step) async {
    if (!mounted || !_mainTabsTourActive || _mainTabsTourBusy) return;
    final targetTab = _mainTabsTourTargets.tabForStep(step);
    final changingTab = _index != targetTab;
    setState(() {
      _mainTabsTourStep = step;
      _mainTabsTourError = null;
      _mainTabsSpotlights = const [];
      if (changingTab && targetTab == 2) {
        _storeMode = StoreMode.normal;
        _storeRevision++;
        _mainTabsReady.remove(2);
      }
      if (changingTab && targetTab == 3) {
        _savingsRevision++;
        _mainTabsReady.remove(3);
      }
      _index = targetTab;
    });

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_mainTabsReady.contains(targetTab)) return;

    final target = _mainTabsTourTargets.scrollTargetForStep(step);
    final controller = _mainTabsTourTargets.scrollControllerForStep(step);
    if (controller?.hasClients == true && (step == 2 || step == 4)) {
      await _moveScroll(controller!, 0);
    }
    final targetContext = target?.currentContext;
    if (targetContext != null && targetContext.mounted) {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: step == 6 ? 0.08 : 0.2,
        duration: _tourMotionDuration(),
        curve: Curves.easeOutCubic,
      );
    }
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) _refreshMainTabsSpotlights();
  }

  void _refreshMainTabsSpotlights() {
    final overlayBox = _tourOverlayKey.currentContext?.findRenderObject();
    if (overlayBox is! RenderBox || !overlayBox.hasSize) return;
    final viewport = Offset.zero & overlayBox.size;
    final rects = <Rect>[];
    for (final key in _mainTabsTourTargets.keysForStep(_mainTabsTourStep)) {
      final targetBox = key.currentContext?.findRenderObject();
      if (targetBox is! RenderBox || !targetBox.hasSize) continue;
      final origin = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
      final rect = origin & targetBox.size;
      if (rect.overlaps(viewport)) rects.add(rect.intersect(viewport));
    }
    if (mounted) setState(() => _mainTabsSpotlights = rects);
  }

  Future<void> _nextMainTabsTourStep() async {
    if (_mainTabsTourStep < MainTabsTourOverlay.stepCount - 1) {
      await _prepareMainTabsTourStep(_mainTabsTourStep + 1);
      return;
    }
    await _finishMainTabsTour();
  }

  Future<void> _finishMainTabsTour() async {
    if (_mainTabsTourBusy) return;
    setState(() {
      _mainTabsTourBusy = true;
      _mainTabsTourError = null;
    });
    try {
      final response = await widget.apiClient.put('/onboarding/main-tabs-tour');
      if (response['mainTabsTourCompleted'] != true) {
        throw const FormatException('Invalid main tabs tour response');
      }
      final savingsScroll = _mainTabsTourTargets.savingsScrollController;
      if (savingsScroll.hasClients) {
        await _moveScroll(savingsScroll, 0);
      }
      if (!mounted) return;
      setState(() {
        _mainTabsTourBusy = false;
        _mainTabsTourCompleted = true;
        _mainTabsSpotlights = const [];
        _index = 0;
        _homeRevision++;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mainTabsTourBusy = false;
        _mainTabsTourError = 'Не получилось сохранить. Попробовать ещё раз.';
      });
    }
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
      LargeTextScope.enabled.value = settings.largeText;
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
            LargeTextScope.enabled.value = next.largeText;
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

  Future<void> _openMenu(BuildContext gameContext) async {
    final selection = await showModalBottomSheet<String>(
      context: gameContext,
      backgroundColor: AppColors.cardBg,
      builder: (menuContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const WaxSeal(size: 40),
                title: const Text('Словарик'),
                onTap: () => Navigator.pop(menuContext, 'dictionary'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.settings_rounded,
                  color: AppColors.crimson,
                ),
                title: const Text('Настройки'),
                onTap: () => Navigator.pop(menuContext, 'settings'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || !gameContext.mounted) return;
    if (selection == 'settings') _openSettings();
    if (selection == 'dictionary') {
      await showDictionaryScroll(gameContext, progress: _dictionary);
    }
  }

  Future<void> _openInsurance() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DictionaryScope(
          progress: _dictionary,
          media: MediaQuery.of(context),
          child: InsuranceScreen(apiClient: widget.apiClient),
        ),
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
    final homeTourPending = widget.showHomeTour && !_tourCompleted;
    final mainTabsTourPending =
        widget.showMainTabsTour && !_mainTabsTourCompleted;
    final anyTourPending = homeTourPending || mainTabsTourPending;
    final content = Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (widget.apiClient.offline != null)
              OfflineBanner(sync: widget.apiClient.offline!),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  HomeScreen(
                    key: ValueKey('home-$_homeRevision'),
                    apiClient: widget.apiClient,
                    refreshSignal: _homeSyncSignal,
                    onChooseGoal: () => _openGoalStore(StoreMode.selectGoal),
                    onOpenShop: () => _selectTab(2),
                    onOpenQuests: () => _selectTab(1),
                    onOpenSettings: _openSettings,
                    onOpenMenu: _openMenu,
                    onOpenInsurance: _openInsurance,
                    onPlanningRequiredChanged: (required) {
                      if (_planningRequired == required || !mounted) return;
                      setState(() => _planningRequired = required);
                    },
                    isActive: _index == 0 && !anyTourPending,
                    focusPlan: _focusHomePlan,
                    tourTargets: widget.showHomeTour ? _tourTargets : null,
                    onTourReady: _homeDidBecomeReady,
                  ),
                  if (homeTourPending) ...[
                    const SizedBox.shrink(),
                    const SizedBox.shrink(),
                    const SizedBox.shrink(),
                  ] else ...[
                    // IndexedStack keeps hidden tabs alive; the map's looping scene
                    // animations must not keep ticking (and draining the battery)
                    // while another tab is on screen.
                    TickerMode(
                      enabled: _index == 1,
                      child: QuestMapScreen(
                        key: ValueKey('map-$_mapRevision'),
                        apiClient: widget.apiClient,
                        dictionaryProgress: _dictionary,
                        // A tab root has nothing to go back to; the header hides the
                        // arrow instead of offering a button that does nothing.
                        showBack: false,
                        difficulty: _settings.difficulty,
                        tourTargets: mainTabsTourPending
                            ? _mainTabsTourTargets
                            : null,
                        onTourReady: mainTabsTourPending
                            ? () => _mainTabDidBecomeReady(1)
                            : null,
                      ),
                    ),
                    ShopScreen(
                      key: ValueKey('store-$_storeRevision'),
                      apiClient: widget.apiClient,
                      mode: _storeMode,
                      onBack: () => setState(() => _index = _storeReturnIndex),
                      onGoalSelected: _goalSelected,
                      onOpenPlan: _openPlan,
                      onOpenQuests: () => _selectTab(1),
                      tourTargets: mainTabsTourPending
                          ? _mainTabsTourTargets
                          : null,
                      onTourReady: mainTabsTourPending
                          ? () => _mainTabDidBecomeReady(2)
                          : null,
                    ),
                    TickerMode(
                      enabled: _index == 3,
                      child: SavingsScreen(
                        key: ValueKey('savings-$_savingsRevision'),
                        apiClient: widget.apiClient,
                        onBack: () => setState(() => _index = 0),
                        onChooseGoal: () =>
                            _openGoalStore(StoreMode.selectGoal),
                        onBrowseGoals: () =>
                            _openGoalStore(StoreMode.browseGoals),
                        onOpenSettings: _openSettings,
                        tourTargets: mainTabsTourPending
                            ? _mainTabsTourTargets
                            : null,
                        onTourReady: mainTabsTourPending
                            ? () => _mainTabDidBecomeReady(3)
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: KeyedSubtree(
        key: _tourTargets.navigation,
        child: AppNavBar(currentIndex: _index, onSelected: _selectTab),
      ),
    );
    return Stack(
      key: _tourOverlayKey,
      children: [
        Positioned.fill(
          child: DictionaryScope(
            progress: _dictionary,
            media: MediaQuery.of(context),
            child: ExcludeSemantics(
              excluding: _tourActive || _mainTabsTourActive,
              child: content,
            ),
          ),
        ),
        if (_tourActive)
          Positioned.fill(
            child: HomeTourOverlay(
              step: _tourStep,
              spotlights: _spotlights,
              busy: _tourBusy,
              error: _tourError,
              onNext: _nextTourStep,
              onBack: () => _prepareTourStep(_tourStep - 1),
            ),
          ),
        if (_mainTabsTourActive && !_tourActive)
          Positioned.fill(
            child: MainTabsTourOverlay(
              step: _mainTabsTourStep,
              spotlights: _mainTabsSpotlights,
              busy: _mainTabsTourBusy,
              error: _mainTabsTourError,
              onNext: _nextMainTabsTourStep,
              onBack: () => _prepareMainTabsTourStep(_mainTabsTourStep - 1),
            ),
          ),
      ],
    );
  }
}
