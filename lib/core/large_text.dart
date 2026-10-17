import 'package:flutter/widgets.dart';

/// Minimum text scale of the child's «Крупный текст» setting. A larger system
/// font size is kept as is; the cap keeps layouts usable.
const kLargeTextScale = 1.3;
const _maxTextScale = 2.0;

/// App-wide «Крупный текст».
///
/// The child shell owns the setting, but most screens are routes pushed on the
/// root navigator, above the shell: settings, pet care, mini-games, dialogs and
/// sheets. Scaling inside the shell left all of them at normal size, so the
/// scale is applied by [builder] in `MaterialApp`, above the navigator, and
/// the shell only flips [enabled].
abstract final class LargeTextScope {
  static final enabled = ValueNotifier<bool>(false);

  /// Pass as `MaterialApp.builder`.
  static Widget builder(BuildContext context, Widget? child) {
    return ValueListenableBuilder<bool>(
      valueListenable: enabled,
      child: child,
      builder: (context, large, child) {
        if (!large) return child ?? const SizedBox.shrink();
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: kLargeTextScale,
              maxScaleFactor: _maxTextScale,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
