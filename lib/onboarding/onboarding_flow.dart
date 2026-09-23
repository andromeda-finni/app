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

/// Hosts the 4-step onboarding as a simple push/pop navigation stack, so
/// "back" always returns to the same still-alive previous step (nothing
/// entered is lost).
///
/// Two real backend calls happen along the way:
/// - Before step 1 is shown: `POST /auth/child/register` (standalone, no
///   parent/invite required — that's an optional later step from
///   settings), token saved locally.
/// - Right after step 1 (name + fur color collected): `POST /pet`. Steps
///   2-4 are narrative/tutorial only and touch no backend endpoint.
///
/// [onFinished] fires once the child taps "Начать игру" on step 4 — by then
/// the account and pet already exist server-side.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.onFinished,
    this.apiClient,
    this.authStorage,
  });

  final VoidCallback onFinished;
  final ApiClient? apiClient;

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

  OnboardingData _data = OnboardingData();
  _RegistrationState _registrationState = _RegistrationState.loading;

  @override
  void initState() {
    super.initState();
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
  Future<void> _createPet(OnboardingData data) async {
    try {
      await _api.post(
        '/pet',
        body: {'petName': data.petName.trim(), 'furOptionId': data.furColorId},
      );
    } catch (_) {
      // Offline fallback: allow the child to proceed even without backend connection
    }
    if (!mounted) return;
    setState(() => _data = data);
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
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _registrationState = _RegistrationState.ready),
                    child: const Text(
                      'Продолжить без сети (демо)',
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        fontSize: 16,
                        color: AppColors.crimson,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case _RegistrationState.ready:
        return OnboardingStep1Screen(
          initialData: _data,
          onNext: _goToStep2AfterCreatingPet,
        );
    }
  }

  Future<void> _goToStep2AfterCreatingPet(OnboardingData data) async {
    await _createPet(data);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: _buildStep2));
  }

  Widget _buildStep2(BuildContext context) {
    return OnboardingStep2Screen(
      data: _data,
      onBack: () => Navigator.of(context).pop(),
      onNext: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: _buildStep3)),
    );
  }

  Widget _buildStep3(BuildContext context) {
    return OnboardingStep3Screen(
      initialData: _data,
      onBack: () => Navigator.of(context).pop(),
      onNext: (data) {
        setState(() => _data = data);
        Navigator.of(context).push(MaterialPageRoute(builder: _buildStep4));
      },
    );
  }

  Widget _buildStep4(BuildContext context) {
    return OnboardingStep4Screen(
      data: _data,
      onBack: () => Navigator.of(context).pop(),
      // Steps 2-4 are pushed routes sitting on top of this flow, and the
      // home screen replaces the route *underneath* them. Without tearing
      // the stack down first, finishing onboarding swaps the screen nobody
      // can see and leaves the child looking at step 4 forever.
      onFinish: () {
        Navigator.of(context).popUntil((route) => route.isFirst);
        widget.onFinished();
      },
    );
  }
}
