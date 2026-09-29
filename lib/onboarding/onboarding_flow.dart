import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/auth_storage.dart';
import '../core/child_difficulty.dart';
import '../theme/app_theme.dart';
import 'difficulty_choice_screen.dart';
import 'onboarding_collar_screen.dart';
import 'onboarding_data.dart';
import 'onboarding_step1_screen.dart';
import 'onboarding_step2_screen.dart';
import 'onboarding_step3_screen.dart';
import 'onboarding_step4_screen.dart';
import 'widgets/story_button.dart';

/// Hosts onboarding and keeps each persisted tutorial step explicit so it can
/// be restored after the app is closed.
///
/// Two real backend calls happen along the way:
/// - Before step 1 is shown: `POST /auth/child/register` (standalone, no
///   parent/invite required — that's an optional later step from
///   settings), token saved locally.
/// - Right after step 1 (name + fur color collected): `PUT /pet`. The extra
///   collar screen updates that same singleton pet before tutorial step 2.
///   Repeating
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
    this.initialDifficulty,
    this.onDifficultySaved,
  });

  final ValueChanged<OnboardingData> onFinished;
  final ApiClient? apiClient;
  final int initialStep;
  final OnboardingData? initialData;
  final ChildDifficulty? initialDifficulty;
  final ValueChanged<ChildDifficulty>? onDifficultySaved;

  /// Test-only injection point — `AuthStorage`'s default backend is a real
  /// platform-channel secure-storage plugin, which hangs forever in a plain
  /// `flutter_test` widget test (no platform on the other end to reply).
  final AuthStorage? authStorage;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum _RegistrationState { choosing, loading, ready, error }

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  late final AuthStorage _authStorage = widget.authStorage ?? AuthStorage();

  late OnboardingData _data;
  late int _currentStep;
  late bool _showCollarChoice;
  _RegistrationState _registrationState = _RegistrationState.loading;
  bool _advancing = false;
  ChildDifficulty? _difficulty;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData ?? OnboardingData();
    _currentStep = widget.initialStep;
    _showCollarChoice = _currentStep == 2 && _data.collarColorId == null;
    _difficulty = widget.initialDifficulty;
    _register();
  }

  Future<void> _register([ChildDifficulty? selected]) async {
    if (selected != null) _difficulty = selected;
    try {
      // Reuse an existing token if one is already saved (e.g. the app was
      // killed after account creation but before the pet was created) —
      // otherwise every retry here would orphan a fresh, pet-less account.
      final existingToken = await _authStorage.readToken();
      if (existingToken == null) {
        if (_difficulty == null) {
          if (mounted) {
            setState(() => _registrationState = _RegistrationState.choosing);
          }
          return;
        }
        setState(() => _registrationState = _RegistrationState.loading);
        final result = await _api.post(
          '/auth/child/register',
          auth: false,
          body: {'difficulty': _difficulty!.apiValue},
        );
        await _authStorage.saveToken(result['token'] as String);
        widget.onDifficultySaved?.call(_difficulty!);
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
      body: {
        'petName': data.petName.trim(),
        'furOptionId': data.furColorId,
        'accessoryOptionId': data.collarColorId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_registrationState) {
      case _RegistrationState.choosing:
        return DifficultyChoiceScreen(
          selected: _difficulty,
          onSelected: (value) => setState(() => _difficulty = value),
          onContinue: _difficulty == null ? null : () => _register(_difficulty),
        );
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
                    onPressed: () => _register(_difficulty),
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
    if (_showCollarChoice) {
      return OnboardingCollarScreen(
        initialData: _data,
        onBack: (data) => setState(() {
          _data = data;
          _showCollarChoice = false;
          _currentStep = 1;
        }),
        onNext: _saveCollarAndOpenStep2,
      );
    }
    switch (_currentStep) {
      case 1:
        return OnboardingStep1Screen(
          initialData: _data,
          onNext: _goToCollarAfterCreatingPet,
        );
      case 2:
        return OnboardingStep2Screen(
          data: _data,
          onBack: () => setState(() => _showCollarChoice = true),
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

  Future<void> _goToCollarAfterCreatingPet(OnboardingData data) async {
    await _savePet(data);
    if (!mounted) return;
    setState(() {
      _data = data;
      _currentStep = 2;
      _showCollarChoice = true;
    });
  }

  Future<void> _saveCollarAndOpenStep2(OnboardingData data) async {
    await _savePet(data);
    if (!mounted) return;
    setState(() {
      _data = data;
      _currentStep = 2;
      _showCollarChoice = false;
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
    widget.onFinished(_data);
  }
}
