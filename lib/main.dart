import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/auth_storage.dart';
import 'games/turnip/turnip_game_models.dart';
import 'games/turnip/turnip_game_demo_screen.dart';
import 'home/main_shell.dart';
import 'home/pet_home_screen.dart';
import 'onboarding/onboarding_data.dart';
import 'onboarding/onboarding_flow.dart';
import 'theme/app_theme.dart';

const _foxEventDemo = bool.fromEnvironment('FOX_EVENT_DEMO');
const _turnipGameDemo = bool.fromEnvironment('TURNIP_GAME_DEMO');

void main() {
  runApp(const GroshikApp());
}

class GroshikApp extends StatelessWidget {
  const GroshikApp({
    super.key,
    @visibleForTesting this.authStorage,
    @visibleForTesting this.apiClient,
    this.turnipDifficulty = TurnipDifficulty.normal,
  });

  final AuthStorage? authStorage;
  final ApiClient? apiClient;
  final TurnipDifficulty turnipDifficulty;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Грошик',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _turnipGameDemo
          ? const TurnipGameDemoScreen()
          : _foxEventDemo
          ? const PetHomeScreen()
          : _StartupGate(
              authStorage: authStorage,
              apiClient: apiClient,
              turnipDifficulty: turnipDifficulty,
            ),
    );
  }
}

enum _StartupState { checking, needsOnboarding, hasPet, error }

/// Decides whether to show onboarding or the pet home screen. A saved bearer
/// token or an already-created pet does not prove that all four onboarding
/// steps were completed, so the server returns the first unfinished step via
/// `GET /onboarding/status`.
class _StartupGate extends StatefulWidget {
  const _StartupGate({
    this.authStorage,
    this.apiClient,
    required this.turnipDifficulty,
  });

  final AuthStorage? authStorage;
  final ApiClient? apiClient;
  final TurnipDifficulty turnipDifficulty;

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late final AuthStorage _authStorage = widget.authStorage ?? AuthStorage();
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  _StartupState _state = _StartupState.checking;
  OnboardingResumeState _onboarding = OnboardingResumeState.fresh();

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _state = _StartupState.checking);

    final token = await _authStorage.readToken();
    if (token == null) {
      if (!mounted) return;
      setState(() {
        _onboarding = OnboardingResumeState.fresh();
        _state = _StartupState.needsOnboarding;
      });
      return;
    }

    try {
      final response = await _api.get('/onboarding/status');
      final onboarding = OnboardingResumeState.fromJson(response);
      if (!mounted) return;
      setState(() {
        _onboarding = onboarding;
        _state = onboarding.completed
            ? _StartupState.hasPet
            : _StartupState.needsOnboarding;
      });
    } on ApiException catch (e) {
      // 401 means the saved token is dead server-side (revoked or expired).
      // It has to be *deleted*, not merely ignored: onboarding reuses any
      // token it finds rather than registering again, so leaving it behind
      // sends the revoked token straight back out on PUT /pet and traps the
      // child in a loop no retry can escape.
      if (e.statusCode == 401) {
        await _authStorage.clearToken();
      }
      if (!mounted) return;
      if (e.statusCode == 401) {
        setState(() {
          _onboarding = OnboardingResumeState.fresh();
          _state = _StartupState.needsOnboarding;
        });
      } else {
        setState(() => _state = _StartupState.error);
      }
    } on FormatException {
      if (!mounted) return;
      setState(() => _state = _StartupState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _StartupState.checking:
        return const Scaffold(
          backgroundColor: AppColors.parchment,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.crimson),
          ),
        );
      case _StartupState.needsOnboarding:
        return OnboardingFlow(
          onFinished: (data) => setState(() {
            _onboarding = OnboardingResumeState(
              currentStep: 4,
              completed: true,
              data: data,
            );
            _state = _StartupState.hasPet;
          }),
          apiClient: _api,
          authStorage: _authStorage,
          initialStep: _onboarding.currentStep,
          initialData: _onboarding.data,
        );
      case _StartupState.hasPet:
        return MainShell(
          apiClient: _api,
          petName: _onboarding.data.petName,
          turnipDifficulty: widget.turnipDifficulty,
        );
      case _StartupState.error:
        return Scaffold(
          backgroundColor: AppColors.parchment,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Не получилось загрузить прогресс — проверьте подключение к интернету.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.story,
                  ),
                  const SizedBox(height: 16),
                  TextButton(onPressed: _check, child: const Text('Повторить')),
                ],
              ),
            ),
          ),
        );
    }
  }
}
