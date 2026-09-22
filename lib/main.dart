import 'package:flutter/material.dart';
import 'core/auth_storage.dart';
import 'onboarding/onboarding_flow.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const GroshikApp());
}

class GroshikApp extends StatelessWidget {
  const GroshikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Грошик',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.crimson),
        scaffoldBackgroundColor: AppColors.parchment,
      ),
      home: const _StartupGate(),
    );
  }
}

/// Decides whether to show onboarding or the pet home screen by checking for
/// a locally saved auth token — no pet/account means no token yet.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  final _authStorage = AuthStorage();
  late final Future<String?> _tokenFuture = _authStorage.readToken();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _tokenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.parchment,
            body: Center(child: CircularProgressIndicator(color: AppColors.crimson)),
          );
        }
        if (snapshot.data == null) {
          return OnboardingFlow(
            onFinished: (data) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => OnboardingCompletePlaceholder(data: data)),
              );
            },
          );
        }
        // TODO: replace with the real pet home screen once it exists.
        return const Scaffold(
          backgroundColor: AppColors.parchment,
          body: Center(child: Text('Питомец уже создан — экран дома в разработке')),
        );
      },
    );
  }
}
