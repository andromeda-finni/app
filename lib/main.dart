import 'package:flutter/material.dart';

import 'audience/role_choice_screen.dart';
import 'core/api_client.dart';
import 'core/auth_storage.dart';
import 'home/main_shell.dart';
import 'onboarding/onboarding_data.dart';
import 'onboarding/onboarding_flow.dart';
import 'parent/parent_connect_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const GroshikApp());
}

class GroshikApp extends StatelessWidget {
  const GroshikApp({
    super.key,
    @visibleForTesting this.authStorage,
    @visibleForTesting this.apiClient,
    @visibleForTesting this.initialAudience,
  });

  final AuthStorage? authStorage;
  final ApiClient? apiClient;
  final AppAudience? initialAudience;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Грошик',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _AudienceGate(
        authStorage: authStorage,
        apiClient: apiClient,
        initialAudience: initialAudience,
      ),
    );
  }
}

enum AppAudience { child, parent }

class _AudienceGate extends StatefulWidget {
  const _AudienceGate({this.authStorage, this.apiClient, this.initialAudience});

  final AuthStorage? authStorage;
  final ApiClient? apiClient;
  final AppAudience? initialAudience;

  @override
  State<_AudienceGate> createState() => _AudienceGateState();
}

class _AudienceGateState extends State<_AudienceGate> {
  late AppAudience? _audience = widget.initialAudience;

  @override
  Widget build(BuildContext context) {
    switch (_audience) {
      case AppAudience.child:
        return _StartupGate(
          authStorage: widget.authStorage,
          apiClient: widget.apiClient,
          onSwitchAudience: () => setState(() => _audience = null),
        );
      case AppAudience.parent:
        return ParentConnectScreen(
          onBack: () => setState(() => _audience = null),
        );
      case null:
        return RoleChoiceScreen(
          onChildSelected: () => setState(() => _audience = AppAudience.child),
          onParentSelected: () =>
              setState(() => _audience = AppAudience.parent),
        );
    }
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
    required this.onSwitchAudience,
  });

  final AuthStorage? authStorage;
  final ApiClient? apiClient;
  final VoidCallback onSwitchAudience;

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
          onFinished: () => setState(() => _state = _StartupState.hasPet),
          apiClient: _api,
          authStorage: _authStorage,
          initialStep: _onboarding.currentStep,
          initialData: _onboarding.data,
        );
      case _StartupState.hasPet:
        return MainShell(
          apiClient: _api,
          onSwitchAudience: widget.onSwitchAudience,
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
