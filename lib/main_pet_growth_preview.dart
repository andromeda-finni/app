import 'dart:async';

import 'package:flutter/material.dart';

import 'core/game_audio_service.dart';
import 'core/pet_assets.dart';
import 'home/models/pet.dart';
import 'home/widgets/pet_scene.dart';
import 'home/widgets/pet_name_header.dart';
import 'home/widgets/stage_transition_screen.dart';
import 'onboarding/onboarding_data.dart';
import 'onboarding/onboarding_step1_screen.dart';
import 'theme/app_theme.dart';

/// Local visual review entry point; never used by the production application.
void main() => runApp(
  MaterialApp(
    title: 'Грошик · котёнок и взросление',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const _PetPreview(),
  ),
);

class _PetPreview extends StatefulWidget {
  const _PetPreview();

  @override
  State<_PetPreview> createState() => _PetPreviewState();
}

class _PetPreviewState extends State<_PetPreview> {
  bool _onboarding = Uri.base.queryParameters['mode'] != 'ages';
  int _stage = (int.tryParse(Uri.base.queryParameters['stage'] ?? '') ?? 1)
      .clamp(1, 3);
  OnboardingData _data = OnboardingData();

  Widget _art(int stage) => Align(
    alignment: Alignment.bottomCenter,
    child: FractionallySizedBox(
      heightFactor: catStageScale(stage) / catStageScale(3),
      child: Image.asset(
        catAsset(
          furOptionId: _data.furColorId,
          accessoryOptionId: _data.collarColorId,
          evolutionStage: stage,
          mood: PetMood.happy,
        ),
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
      ),
    ),
  );

  Future<void> _grow() async {
    final before = _stage;
    final after = (before + 1).clamp(1, 3);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => StageTransitionScreen(
          beforeArtwork: _art(before),
          afterArtwork: _art(after),
          title:
              '${_data.petName.isEmpty ? 'Мурзик' : _data.petName} повзрослел!',
          message:
              'Вы столько всего узнали вместе! Впереди ещё много открытий.',
          onFanfare: () =>
              unawaited(GameAudioService.instance.play(GameSound.magicEvent)),
          onCompleted: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
    if (mounted) setState(() => _stage = after);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Локальный просмотр'),
      actions: [
        TextButton(
          onPressed: () => setState(() => _onboarding = !_onboarding),
          child: Text(_onboarding ? 'Возрасты' : 'Онбординг'),
        ),
      ],
    ),
    body: _onboarding
        ? OnboardingStep1Screen(
            initialData: _data,
            onNext: (data) async => setState(() {
              _data = data;
              _onboarding = false;
            }),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PetNameHeader(
                pet: Pet(
                  name: _data.petName.isEmpty ? 'Мурзик' : _data.petName,
                  furOptionId: _data.furColorId,
                  accessoryOptionId: _data.collarColorId,
                  satiety: 60,
                  joy: 50,
                  health: 100,
                  evolutionStage: _stage,
                ),
                onRename: (name) async =>
                    setState(() => _data = _data.copyWith(petName: name)),
                onUpdateIdentity: (name, collarId) async => setState(
                  () => _data = _data.copyWith(
                    petName: name,
                    collarColorId: collarId,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              PetScene(
                pet: Pet(
                  name: _data.petName,
                  furOptionId: _data.furColorId,
                  accessoryOptionId: _data.collarColorId,
                  satiety: 60,
                  joy: 50,
                  health: 100,
                  evolutionStage: _stage,
                ),
                backgroundAsset: 'assets/backgrounds/home_room.webp',
                height: 340,
                petHeightFactor: 0.68,
              ),
              const SizedBox(height: 16),
              const Text(
                'Переключатели ниже есть только в этом предпросмотре.',
                textAlign: TextAlign.center,
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  for (final stage in [1, 2, 3])
                    ChoiceChip(
                      label: Text(
                        ['Котёнок', 'Средний', 'Взрослый'][stage - 1],
                      ),
                      selected: _stage == stage,
                      onSelected: (_) => setState(() => _stage = stage),
                    ),
                ],
              ),
              FilledButton(
                onPressed: _stage < 3 ? _grow : null,
                child: const Text('Посмотреть превращение'),
              ),
            ],
          ),
  );
}
