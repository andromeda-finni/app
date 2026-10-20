import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Anchors owned by the real home screen. The tour measures these widgets
/// after layout so its spotlight always follows the rendered UI.
class HomeTourTargets {
  final settings = GlobalKey(debugLabel: 'home-tour-settings');
  final wallet = GlobalKey(debugLabel: 'home-tour-wallet');
  final identity = GlobalKey(debugLabel: 'home-tour-identity');
  final pet = GlobalKey(debugLabel: 'home-tour-pet');
  final event = GlobalKey(debugLabel: 'home-tour-event');
  final stats = GlobalKey(debugLabel: 'home-tour-stats');
  final plan = GlobalKey(debugLabel: 'home-tour-plan');
  final navigation = GlobalKey(debugLabel: 'home-tour-navigation');
  final scrollController = ScrollController();

  Iterable<GlobalKey> keysForStep(int step) => switch (step) {
    0 => [wallet, navigation],
    1 => [settings, identity, pet, event, stats],
    _ => [plan],
  };

  void dispose() => scrollController.dispose();
}

class HomeTourOverlay extends StatelessWidget {
  const HomeTourOverlay({
    super.key,
    required this.step,
    required this.spotlights,
    required this.busy,
    required this.onNext,
    required this.onBack,
    this.error,
  });

  final int step;
  final List<Rect> spotlights;
  final bool busy;
  final String? error;
  final VoidCallback onNext;
  final VoidCallback onBack;

  static const _titles = ['Деньги и разделы', 'Твой питомец', 'План на период'];

  static const _messages = [
    'Сверху показаны твои монеты: сколько можно потратить и сколько лежит '
        'в копилке. Снизу можно перейти домой, на карту, в магазин или в копилку.',
    'Здесь живёт твой питомец. Зелёная кнопка с лапкой слева показывает его '
        'сытость, радость и здоровье. Под домиком появляются события, в которых '
        'ему нужна помощь. Меню со словариком и настройками находится слева сверху.',
    'Красная кнопка начинает новый период и открывает план. В нём ты '
        'распределяешь монеты между нужным, желаниями и копилкой.',
  ];

  @override
  Widget build(BuildContext context) => GuidedTourOverlay(
    stepLabel: 'ЗНАКОМСТВО С ЭКРАНОМ · ${step + 1} / 3',
    semanticLabel: 'Знакомство с экраном, шаг ${step + 1} из 3',
    title: _titles[step],
    message: _messages[step],
    spotlights: spotlights,
    busy: busy,
    error: error,
    onNext: onNext,
    onBack: step > 0 ? onBack : null,
    nextLabel: 'Далее',
    blockerKey: const Key('home-tour-blocker'),
    backKey: const Key('home-tour-back'),
    nextKey: const Key('home-tour-next'),
    errorKey: const Key('home-tour-error'),
    alignment: step == 0 ? Alignment.center : Alignment.bottomCenter,
    bottomInset: step == 0 ? 102 : AppSpacing.md,
  );
}

/// Shared presentation module for tours over real application screens.
///
/// Screen modules only expose measurable anchors. This widget owns input
/// blocking, semantics, responsive card layout and the multi-hole mask.
class GuidedTourOverlay extends StatelessWidget {
  const GuidedTourOverlay({
    super.key,
    required this.stepLabel,
    required this.semanticLabel,
    required this.title,
    required this.message,
    required this.spotlights,
    required this.busy,
    required this.onNext,
    required this.nextLabel,
    required this.blockerKey,
    required this.nextKey,
    this.onBack,
    this.error,
    this.backKey,
    this.errorKey,
    this.alignment = Alignment.bottomCenter,
    this.bottomInset = AppSpacing.md,
  });

  final String stepLabel;
  final String semanticLabel;
  final String title;
  final String message;
  final List<Rect> spotlights;
  final bool busy;
  final String? error;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final String nextLabel;
  final Key blockerKey;
  final Key nextKey;
  final Key? backKey;
  final Key? errorKey;
  final Alignment alignment;
  final double bottomInset;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: DefaultTextStyle(
      style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
          .copyWith(decoration: TextDecoration.none),
      child: BlockSemantics(
        blocking: true,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: semanticLabel,
          explicitChildNodes: true,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: blockerKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: CustomPaint(painter: _SpotlightPainter(spotlights)),
                ),
              ),
              Positioned.fill(
                child: SafeArea(
                  minimum: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    bottomInset,
                  ),
                  child: Align(
                    alignment: alignment,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: SingleChildScrollView(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            border: Border.all(color: AppColors.parchmentDark),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x55000000),
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  stepLabel,
                                  style: AppTextStyles.stepCounter,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(title, style: AppTextStyles.screenTitle),
                                const SizedBox(height: AppSpacing.sm),
                                Text(message, style: AppTextStyles.story),
                                if (error != null) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    error!,
                                    key: errorKey,
                                    style: AppTextStyles.supporting.copyWith(
                                      color: AppColors.crimson,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    if (onBack != null) ...[
                                      Expanded(
                                        child: OutlinedButton(
                                          key: backKey,
                                          onPressed: busy ? null : onBack,
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size(48, 52),
                                            foregroundColor: AppColors.ink,
                                            side: const BorderSide(
                                              color: AppColors.fieldBorder,
                                            ),
                                            shape: const StadiumBorder(),
                                          ),
                                          child: const Text('Назад'),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                    ],
                                    Expanded(
                                      flex: onBack != null ? 2 : 1,
                                      child: ElevatedButton(
                                        key: nextKey,
                                        onPressed: busy ? null : onNext,
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(48, 52),
                                          backgroundColor: AppColors.crimson,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor:
                                              AppColors.crimsonFaded,
                                          shape: const StadiumBorder(),
                                        ),
                                        child: busy
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : Text(
                                                nextLabel,
                                                textAlign: TextAlign.center,
                                                style: AppTextStyles.button,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter(this.spotlights);

  final List<Rect> spotlights;

  @override
  void paint(Canvas canvas, Size size) {
    var mask = Path()..addRect(Offset.zero & size);
    for (final rect in spotlights) {
      final hole = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            rect.inflate(AppSpacing.xs),
            const Radius.circular(AppRadii.lg),
          ),
        );
      mask = Path.combine(PathOperation.difference, mask, hole);
    }
    canvas.drawPath(mask, Paint()..color = const Color(0xB8000000));

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.coinGold;
    for (final rect in spotlights) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.inflate(AppSpacing.xs),
          const Radius.circular(AppRadii.lg),
        ),
        border,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.spotlights != spotlights;
}
