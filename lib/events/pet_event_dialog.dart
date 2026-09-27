import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../theme/app_theme.dart';
import 'pet_event_models.dart';

enum PetEventDialogAction { resolved, openQuests }

class PetEventDialogResult {
  const PetEventDialogResult(this.action, {this.resolution});

  final PetEventDialogAction action;
  final PetEventResolution? resolution;
}

Future<PetEventDialogResult?> showPetEventDialog(
  BuildContext context, {
  required PetEventOccurrence event,
  required String petName,
  required int spendable,
  required Future<PetEventResolution> Function() onResolve,
}) => showDialog<PetEventDialogResult>(
  context: context,
  builder: (_) => PetEventDialog(
    event: event,
    petName: petName,
    spendable: spendable,
    onResolve: onResolve,
  ),
);

class PetEventDialog extends StatefulWidget {
  const PetEventDialog({
    super.key,
    required this.event,
    required this.petName,
    required this.spendable,
    required this.onResolve,
  });

  final PetEventOccurrence event;
  final String petName;
  final int spendable;
  final Future<PetEventResolution> Function() onResolve;

  @override
  State<PetEventDialog> createState() => _PetEventDialogState();
}

class _PetEventDialogState extends State<PetEventDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _celebration = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _resolving = false;
  bool _resolved = false;
  late bool _insufficient = widget.spendable < widget.event.amountDue;
  String? _error;

  @override
  void dispose() {
    _celebration.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    if (_resolving || _resolved) return;
    setState(() {
      _resolving = true;
      _error = null;
    });
    try {
      final resolution = await widget.onResolve();
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _resolved = true;
      });
      _celebration.forward(from: 0);
      await Future<void>.delayed(const Duration(milliseconds: 950));
      if (!mounted) return;
      Navigator.of(context).pop(
        PetEventDialogResult(
          PetEventDialogAction.resolved,
          resolution: resolution,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        if (error.code == 'insufficient_funds') {
          _insufficient = true;
        } else {
          _error = 'Не получилось помочь сейчас. Проверь соединение и попробуй ещё раз.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _error = 'Не получилось помочь сейчас. Проверь соединение и попробуй ещё раз.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final definition = widget.event.definition;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(AppRadii.sheet),
                border: Border.all(color: AppColors.parchmentDark, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Закрыть',
                        onPressed: _resolving || _resolved
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                    _EventPlaceholder(eventId: definition.id),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      definition.dialogTitle(widget.petName),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.eventTitle,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      definition.description,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.story,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      key: const Key('pet-event-price'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.infoBg,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Text(
                        'К оплате: ${widget.event.amountDue} 🪙',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.cardTitle,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_resolved) ...[
                      const Icon(
                        Icons.favorite_rounded,
                        color: AppColors.leafGreen,
                        size: 42,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        definition.feedback,
                        key: const Key('pet-event-feedback'),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.story.copyWith(
                          color: AppColors.leafGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else if (_insufficient) ...[
                      Text(
                        'Монет пока не хватает. Ничего страшного — событие останется здесь, а Финни будет ждать твоей помощи.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.supporting,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Пойдем на тропинку заданий, чтобы заработать на лекарство!',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.cardRowLabel,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton.icon(
                        key: const Key('pet-event-open-quests'),
                        onPressed: () => Navigator.of(context).pop(
                          const PetEventDialogResult(
                            PetEventDialogAction.openQuests,
                          ),
                        ),
                        icon: const Icon(Icons.map_rounded),
                        label: const Text('Пойти на тропинку заданий'),
                      ),
                    ] else ...[
                      if (_error != null) ...[
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.supporting.copyWith(
                            color: AppColors.crimsonDark,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      ElevatedButton.icon(
                        key: const Key('pet-event-resolve'),
                        onPressed: _resolving ? null : _resolve,
                        icon: _resolving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.volunteer_activism_rounded),
                        label: Text(
                          _resolving
                              ? 'Помогаем…'
                              : 'Помочь за ${widget.event.amountDue} 🪙',
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      definition.lesson,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.stepCounter,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_resolved)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _celebration,
                  builder: (_, _) => _Celebration(progress: _celebration.value),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EventPlaceholder extends StatelessWidget {
  const _EventPlaceholder({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    final icon = switch (eventId) {
      'POOR_PAW' => Icons.healing_rounded,
      'SICK' => Icons.sick_rounded,
      'HUNGRY' => Icons.soup_kitchen_rounded,
      'COLD_NIGHT' => Icons.local_fire_department_rounded,
      'ROOF_LEAK' => Icons.roofing_rounded,
      'BEAVER_DAM' => Icons.handyman_rounded,
      _ => Icons.image_outlined,
    };
    return Semantics(
      image: true,
      label: 'Место для иллюстрации события',
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFFE1E1E1),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: const Color(0xFFB4B4B4)),
        ),
        child: Icon(icon, size: 68, color: const Color(0xFF777777)),
      ),
    );
  }
}

class _Celebration extends StatelessWidget {
  const _Celebration({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < 14; i++)
            Positioned(
              left:
                  constraints.maxWidth / 2 +
                  math.cos(i * math.pi / 7) *
                      progress *
                      constraints.maxWidth *
                      0.42 -
                  10,
              top:
                  constraints.maxHeight / 2 +
                  math.sin(i * math.pi / 7) *
                      progress *
                      constraints.maxHeight *
                      0.4 -
                  10,
              child: Opacity(
                opacity: (1 - progress).clamp(0.0, 1.0),
                child: Icon(
                  i.isEven ? Icons.star_rounded : Icons.monetization_on_rounded,
                  size: 20 + (i % 3) * 4,
                  color: i.isEven ? AppColors.coinGold : AppColors.crimson,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
