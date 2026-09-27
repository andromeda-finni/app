import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../ivan_game_content.dart';
import '../ivan_game_models.dart';

class IvanResultView extends StatelessWidget {
  const IvanResultView({
    super.key,
    required this.level,
    required this.result,
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

  final IvanLevelConfig level;
  final IvanSelectionResult result;
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
    return '${parts.join(' ')} Вернись к прилавку и измени выбор.';
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
          IvanAssets.shopBackground,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.canvasWarm.withValues(alpha: 0.12),
                AppColors.canvasWarm.withValues(alpha: 0.64),
              ],
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 650;
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Material(
                      key: const ValueKey('ivan-result-card'),
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
                              success
                                  ? 'Можно отправляться!'
                                  : 'Проверим ещё раз',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.screenTitle.copyWith(
                                color: success
                                    ? AppColors.leafGreen
                                    : AppColors.crimsonDark,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              success ? level.successText : _failureText,
                              textAlign: TextAlign.center,
                              style: compact
                                  ? AppTextStyles.supporting.copyWith(
                                      color: AppColors.ink,
                                    )
                                  : AppTextStyles.story,
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
                                      ivanLearningText,
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.supporting.copyWith(
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Semantics(
                                label: rewardText,
                                child: ExcludeSemantics(
                                  child: Row(
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
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            if (!success)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  key: const ValueKey('ivan-revise-selection'),
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
                                    key: const ValueKey('ivan-retry-sync'),
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
                                      key: const ValueKey('ivan-replay'),
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
                                              ? 'ivan-next-level'
                                              : 'ivan-exit',
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
