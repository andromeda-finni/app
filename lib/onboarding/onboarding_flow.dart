import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/auth_storage.dart';
import '../theme/app_theme.dart';
import 'onboarding_data.dart';
import 'onboarding_step1_screen.dart';
import 'onboarding_step2_screen.dart';
import 'onboarding_step3_screen.dart';
import 'onboarding_step4_screen.dart';
import 'widgets/story_button.dart';

/// Hosts the 4-step onboarding and keeps the current step explicit so it can
/// be restored after the app is closed.
///
/// Two real backend calls happen along the way:
/// - Before step 1 is shown: `POST /auth/child/register` (standalone, no
///   parent/invite required — that's an optional later step from
///   settings), token saved locally.
/// - Right after step 1 (name + fur color collected): `PUT /pet`. Repeating
///   this after navigating back updates the same pet instead of attempting to
///   create a second one.
/// - After steps 2-4: `PUT /onboarding/progress`. The server advances only
///   one step at a time, so a restart resumes at the first unfinished step.
///
/// [onFinished] fires once the child taps "Начать игру" on step 4 — by then
/// the account and pet already exist server-side.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.onFinished,
    this.apiClient,
    this.authStorage,
    this.initialStep = 1,
    this.initialData,
  });

  final VoidCallback onFinished;
  final ApiClient? apiClient;
  final int initialStep;
  final OnboardingData? initialData;

  /// Test-only injection point — `AuthStorage`'s default backend is a real
  /// platform-channel secure-storage plugin, which hangs forever in a plain
  /// `flutter_test` widget test (no platform on the other end to reply).
  final AuthStorage? authStorage;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum _RegistrationState { loading, ready, error }

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  late final AuthStorage _authStorage = widget.authStorage ?? AuthStorage();

  late OnboardingData _data;
  late int _currentStep;
  _RegistrationState _registrationState = _RegistrationState.loading;
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData ?? OnboardingData();
    _currentStep = widget.initialStep;
    _register();
  }

  Future<void> _register() async {
    setState(() => _registrationState = _RegistrationState.loading);
    try {
      // Reuse an existing token if one is already saved (e.g. the app was
      // killed after account creation but before the pet was created) —
      // otherwise every retry here would orphan a fresh, pet-less account.
      final existingToken = await _authStorage.readToken();
      if (existingToken == null) {
        final result = await _api.post('/auth/child/register', auth: false);
        await _authStorage.saveToken(result['token'] as String);
      }
      if (!mounted) return;
      setState(() => _registrationState = _RegistrationState.ready);
    } catch (_) {
      if (!mounted) return;
      setState(() => _registrationState = _RegistrationState.error);
    }
  }

  /// Awaited by step 1's own submit handler — throwing here keeps the child
  /// on step 1 with an inline error instead of silently losing the tap.
  Future<void> _savePet(OnboardingData data) async {
    await _api.put(
      '/pet',
      body: {'petName': data.petName.trim(), 'furOptionId': data.furColorId},
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_registrationState) {
      case _RegistrationState.loading:
        return const Scaffold(
          backgroundColor: AppColors.parchment,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.crimson),
          ),
        );
      case _RegistrationState.error:
        return Scaffold(
          backgroundColor: AppColors.parchment,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Не получилось начать игру — проверьте подключение к интернету.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.story,
                  ),
                  const SizedBox(height: 20),
                  StoryButton(
                    label: 'Повторить',
                    expand: false,
                    onPressed: _register,
                  ),
                ],
              ),
            ),
          ),
        );
      case _RegistrationState.ready:
        return _buildCurrentStep();
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return OnboardingStep1Screen(
          initialData: _data,
          onNext: _goToStep2AfterCreatingPet,
        );
      case 2:
        return OnboardingStep2Screen(
          data: _data,
          onBack: () => setState(() => _currentStep = 1),
          onNext: _advancing ? null : _completeStep2,
          isSubmitting: _advancing,
        );
      case 3:
        return OnboardingStep3Screen(
          initialData: _data,
          onBack: (data) => setState(() {
            _data = data;
            _currentStep = 2;
          }),
          onNext: _advancing ? null : _completeStep3,
          isSubmitting: _advancing,
        );
      case 4:
        return OnboardingStep4Screen(
          data: _data,
          onBack: () => setState(() => _currentStep = 3),
          onFinish: _advancing ? null : _finishOnboarding,
          isSubmitting: _advancing,
        );
      default:
        throw StateError('Unsupported onboarding step: $_currentStep');
    }
  }

  Future<void> _goToStep2AfterCreatingPet(OnboardingData data) async {
    await _savePet(data);
    if (!mounted) return;
    setState(() {
      _data = data;
      _currentStep = 2;
    });
  }

  Future<bool> _persistCompletedStep(int completedStep) async {
    if (_advancing) return false;
    setState(() => _advancing = true);
    try {
      await _api.put(
        '/onboarding/progress',
        body: {'completedStep': completedStep},
      );
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не получилось сохранить прогресс. Попробуй ещё раз.',
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _advancing = false);
    }
  }

  Future<void> _completeStep2() async {
    if (!await _persistCompletedStep(2) || !mounted) return;
    setState(() => _currentStep = 3);
  }

  Future<void> _completeStep3(OnboardingData data) async {
    if (!await _persistCompletedStep(3) || !mounted) return;
    setState(() {
      _data = data;
      _currentStep = 4;
    });
  }

  Future<void> _finishOnboarding() async {
    if (!await _persistCompletedStep(4) || !mounted) return;
    widget.onFinished();
  }
}
