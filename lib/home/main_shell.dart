import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/child_difficulty.dart';
import '../core/game_audio_service.dart';
import '../core/large_text.dart';
import '../core/offline/offline_banner.dart';
import '../dictionary/dictionary_progress.dart';
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
    this.onSwitchAudience,
    this.dictionaryProgress,
  });

  final ApiClient apiClient;
  final ChildDifficulty initialDifficulty;
  final bool showHomeTour;

  /// Returns to the child/parent role choice; wired from the settings screen.
  final VoidCallback? onSwitchAudience;
  final DictionaryProgress? dictionaryProgress;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _tourOverlayKey = GlobalKey(debugLabel: 'home-tour-overlay');
  final _tourTargets = HomeTourTargets();
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

  void _homeDidBecomeReady() {
    if (!widget.showHomeTour || _homeReady) return;
    setState(() => _homeReady = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareTourStep(0));
  }

  Duration _tourMotionDuration() =>
      MediaQuery.maybeOf(context)?.disableAnimations == true
      ? Duration.zero
      : const Duration(milliseconds: 260);

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
      await controller.animateTo(
        0,
        duration: _tourMotionDuration(),
        curve: Curves.easeOutCubic,
      );
    } else {
      final planContext = _tourTargets.plan.currentContext;
      if (planContext == null) {
        await controller.animateTo(
          controller.position.maxScrollExtent.clamp(0, 520),
          duration: _tourMotionDuration(),
          curve: Curves.easeOutCubic,
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
        await _tourTargets.scrollController.animateTo(
          0,
          duration: _tourMotionDuration(),
          curve: Curves.easeOutCubic,
        );
      }
      if (!mounted) return;
      setState(() {
        _tourBusy = false;
        _tourCompleted = true;
        _spotlights = const [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tourBusy = false;
        _tourError = 'Не получилось сохранить. Попробовать ещё раз.';
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
    final tourPending = widget.showHomeTour && !_tourCompleted;
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
                    isActive: _index == 0 && !tourPending,
                    focusPlan: _focusHomePlan,
                    tourTargets: widget.showHomeTour ? _tourTargets : null,
                    onTourReady: _homeDidBecomeReady,
                  ),
                  if (tourPending) ...[
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
                    ),
                    SavingsScreen(
                      key: ValueKey('savings-$_savingsRevision'),
                      apiClient: widget.apiClient,
                      onBack: () => setState(() => _index = 0),
                      onChooseGoal: () => _openGoalStore(StoreMode.selectGoal),
                      onBrowseGoals: () =>
                          _openGoalStore(StoreMode.browseGoals),
                      onOpenSettings: _openSettings,
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
          child: ExcludeSemantics(excluding: _tourActive, child: content),
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
      ],
    );
  }
}
