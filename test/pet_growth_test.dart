import 'dart:io';

import 'package:andromeda_app/core/pet_assets.dart';
import 'package:andromeda_app/day_summary/day_summary.dart';
import 'package:andromeda_app/home/models/pet.dart';
import 'package:andromeda_app/home/widgets/pet_scene.dart';
import 'package:andromeda_app/onboarding/onboarding_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'well-fed pets look content while illness and low joy remain visible',
    () {
      for (final stage in [1, 2, 3]) {
        final json = {
          'pet_name': 'Финни',
          'fur_option_id': 'FUR_WHITE',
          'accessory_option_id': 'ACC_COLLAR_BLUE',
          'energy_level': 100,
          'joy_level': 65,
          'health_level': 100,
          'evolution_stage': stage,
        };
        final fed = Pet.fromJson(json);
        expect(fed.mood, PetMood.fully);
        expect(
          fed.assetPath,
          catAsset(
            furOptionId: 'FUR_WHITE',
            accessoryOptionId: 'ACC_COLLAR_BLUE',
            evolutionStage: stage,
            mood: PetMood.happy,
          ),
        );
        expect(
          Pet.fromJson({...json, 'health_level': 55}).assetPath,
          endsWith('/sad_white.webp'),
        );
        expect(
          Pet.fromJson({...json, 'joy_level': 10}).assetPath,
          endsWith('/sad_white.webp'),
        );
        expect(fed.satiety, 100);
        expect(fed.joy, 65);
        expect(fed.health, 100);
      }
    },
  );

  test('all 135 appearance combinations resolve to nonempty bundled art', () {
    final paths = <String>{};
    for (final stage in [1, 2, 3]) {
      for (final fur in ['FUR_GRAY', 'FUR_ORANGE', 'FUR_WHITE']) {
        for (final collar in [
          'ACC_COLLAR_RED',
          'ACC_COLLAR_GREEN',
          'ACC_COLLAR_BLUE',
        ]) {
          for (final mood in PetMood.values) {
            final path = catAsset(
              furOptionId: fur,
              accessoryOptionId: collar,
              evolutionStage: stage,
              mood: mood,
            );
            paths.add(path);
            expect(File(path).lengthSync(), greaterThan(0), reason: path);
          }
        }
      }
    }
    expect(paths.length, 135);
  });

  test('old profiles keep red collar and their persisted growth stage', () {
    expect(
      catAsset(furOptionId: 'FUR_WHITE', evolutionStage: 2),
      endsWith('/middle/red/base_white.webp'),
    );
    final restored = OnboardingResumeState.fromJson({
      'currentStep': 2,
      'completed': false,
      'pet': {
        'petName': 'Мурзик',
        'furOptionId': 'FUR_WHITE',
        'accessoryOptionId': 'ACC_COLLAR_GREEN',
      },
    });
    expect(restored.data.collarColorId, 'ACC_COLLAR_GREEN');
  });

  test('day summary detects only an actual server-side stage increase', () {
    final json = {
      'periodId': 'day-1',
      'plan': <String, Object>{},
      'actual': <String, Object>{},
      'feedback': 'Спасибо!',
      'petStageBefore': 1,
      'petStageAfter': 2,
    };
    expect(DaySummary.fromJson(json).petGrew, isTrue);
    expect(DaySummary.fromJson({...json, 'petStageAfter': 1}).petGrew, isFalse);
    expect(
      DaySummary.fromJson({...json, 'petStageBefore': 3, 'petStageAfter': 3})
          .petGrew,
      isFalse,
    );
  });

  testWidgets('three ages have increasing visible size on the same floor', (
    tester,
  ) async {
    final bottoms = <double>[];
    final heights = <double>[];
    for (final stage in [1, 2, 3]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: PetScene(
                pet: Pet(
                  name: 'Мурзик',
                  furOptionId: 'FUR_GRAY',
                  accessoryOptionId: 'ACC_COLLAR_BLUE',
                  satiety: 60,
                  joy: 50,
                  health: 100,
                  evolutionStage: stage,
                ),
                backgroundAsset: 'assets/backgrounds/home_room.webp',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = find.byKey(
        ValueKey(
          catAsset(
            furOptionId: 'FUR_GRAY',
            accessoryOptionId: 'ACC_COLLAR_BLUE',
            evolutionStage: stage,
          ),
        ),
      );
      heights.add(tester.getSize(image).height);
      bottoms.add(tester.getBottomLeft(image).dy);
      expect(tester.takeException(), isNull);
    }
    expect(heights[0], lessThan(heights[1]));
    expect(heights[1], lessThan(heights[2]));
    expect(bottoms[0], closeTo(bottoms[1], 0.1));
    expect(bottoms[1], closeTo(bottoms[2], 0.1));
  });
}
