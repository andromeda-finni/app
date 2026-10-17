import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'offline_sync.dart';

/// A calm strip at the top of the child app while it plays without a
/// connection or still has actions to send. It reassures rather than warns:
/// nothing is lost, the game goes on.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.sync});

  final OfflineSync sync;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final pending = sync.pendingCount;
        if (!sync.isOffline && pending == 0) return const SizedBox.shrink();
        final text = sync.isOffline
            ? 'Играем без интернета. Всё сохранится и отправится само, '
                  'когда связь вернётся.'
            : 'Отправляем сделанное без сети…';
        return Semantics(
          liveRegion: true,
          child: Container(
            key: const Key('offline-banner'),
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              0,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: AppColors.goalBorder),
            ),
            child: Row(
              children: [
                Icon(
                  sync.isOffline
                      ? Icons.cloud_off_rounded
                      : Icons.cloud_upload_rounded,
                  color: AppColors.inkMuted,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    pending > 0 && sync.isOffline
                        ? '$text Ждут отправки: $pending.'
                        : text,
                    style: AppTextStyles.swatchLabel.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
