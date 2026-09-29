import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../goldfish_game_content.dart';
import '../goldfish_game_models.dart';

class GoldfishResultView extends StatelessWidget {
  const GoldfishResultView({
    super.key,
    required this.level,
    required this.result,
    required this.selectedOffers,
    required this.rewardAmount,
    required this.statusNote,
    required this.isSyncing,
    required this.rewardWasAlreadyGranted,
    required this.onRevise,
    required this.onReplay,
    this.onRetrySync,
    this.onNextLevel,
    this.onExit,
  });

  final GoldfishLevelConfig level;
  final GoldfishSelectionResult result;
  final List<GoldfishOffer> selectedOffers;
  final int? rewardAmount;
  final String? statusNote;
  final bool isSyncing;
  final bool rewardWasAlreadyGranted;
  final VoidCallback onRevise;
  final VoidCallback onReplay;
  final VoidCallback? onRetrySync;
  final VoidCallback? onNextLevel;
  final VoidCallback? onExit;

  String get _failureText {
    final parts = <String>[];
    if (result.missingRequirements.isNotEmpty) {
      parts.add('Не хватает: ${result.missingRequirements.join(', ')}.');
    }
    if (result.isOverBudget) {
      parts.add(
        'Покупки дороже бюджета на ${result.spent - level.budget} монет.',
      );
    }
    if (result.isReserveTooSmall) {
      parts.add(
        'В запасе нужно оставить не меньше ${level.minimumReserve} монет.',
      );
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final success = result.isSuccessful;
    final rewardText = rewardAmount != null
        ? rewardWasAlreadyGranted
              ? 'Награда $rewardAmount монет уже была получена.'
              : '+$rewardAmount монет начислено в кошелёк!'
        : statusNote ??
              (isSyncing
                  ? 'Сохраняем результат…'
                  : 'Награда за уровень: ${level.reward} монет');

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          success
              ? GoldfishAssets.homeAfterPortrait
              : GoldfishAssets.homeBeforePortrait,
          key: ValueKey(
            success
                ? 'goldfish-result-home-renovated'
                : 'goldfish-result-home-needs-repair',
          ),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.canvasWarm.withValues(alpha: 0.08),
                AppColors.canvasWarm.withValues(alpha: 0.72),
              ],
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 680;
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Material(
                      key: const ValueKey('goldfish-result-card'),
                      color: AppColors.cardBg.withValues(alpha: 0.97),
                      elevation: 10,
                      borderRadius: BorderRadius.circular(AppRadii.sheet),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          compact ? AppSpacing.md : AppSpacing.xl,
                          AppSpacing.lg,
                          compact ? AppSpacing.md : AppSpacing.xl,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              success ? 'Домик готов!' : 'Проверим покупки',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.screenTitle.copyWith(
                                color: success
                                    ? AppColors.leafGreen
                                    : AppColors.crimsonDark,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              success
                                  ? 'Потрачено ${result.spent} монет, осталось ${result.remaining}.'
                                  : _failureText,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.story,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: [
                                for (final offer in selectedOffers)
                                  Semantics(
                                    label: offer.name,
                                    child: Container(
                                      width: 62,
                                      height: 62,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.parchment,
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.sm,
                                        ),
                                        border: Border.all(
                                          color: AppColors.fieldBorder,
                                        ),
                                      ),
                                      child: Image.asset(
                                        offer.assetPath,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (success) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.infoBg,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.md,
                                  ),
                                  border: Border.all(
                                    color: AppColors.parchmentDark,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Что важно запомнить',
                                      style: AppTextStyles.sectionTitle
                                          .copyWith(
                                            color: AppColors.crimsonDark,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.xxs),
                                    Text(
                                      level.learningText,
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.supporting.copyWith(
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/icons/coin.webp',
                                    width: 26,
                                    height: 26,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Flexible(
                                    child: Text(
                                      rewardText,
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.cardRowLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            if (!success)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  key: const ValueKey(
                                    'goldfish-revise-selection',
                                  ),
                                  onPressed: onRevise,
                                  style: _primaryStyle,
                                  child: Text(
                                    'Исправить выбор',
                                    style: AppTextStyles.button,
                                  ),
                                ),
                              )
                            else ...[
                              if (onRetrySync != null && !isSyncing) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    key: const ValueKey('goldfish-retry-sync'),
                                    onPressed: onRetrySync,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Повторить сохранение'),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      key: const ValueKey('goldfish-replay'),
                                      onPressed: isSyncing ? null : onReplay,
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 52),
                                        foregroundColor: AppColors.crimsonDark,
                                        side: const BorderSide(
                                          color: AppColors.crimson,
                                        ),
                                        shape: const StadiumBorder(),
                                      ),
                                      child: const Text('Ещё раз'),
                                    ),
                                  ),
                                  if (onNextLevel != null ||
                                      onExit != null) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: ElevatedButton(
                                        key: ValueKey(
                                          onNextLevel != null
                                              ? 'goldfish-next-level'
                                              : 'goldfish-exit',
                                        ),
                                        onPressed: isSyncing
                                            ? null
                                            : onNextLevel ?? onExit,
                                        style: _primaryStyle,
                                        child: Text(
                                          onNextLevel != null
                                              ? 'Следующий уровень'
                                              : 'На карту',
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.button,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

final ButtonStyle _primaryStyle = ElevatedButton.styleFrom(
  minimumSize: const Size(0, 52),
  backgroundColor: AppColors.crimson,
  foregroundColor: Colors.white,
  disabledBackgroundColor: AppColors.crimsonFaded,
  shape: const StadiumBorder(),
);
