import 'package:flutter/material.dart';

import 'dictionary_progress.dart';

/// The shell owns progress. Routes receive the same profile's instance;
/// dialogs and bottom sheets capture it with the other inherited themes.
class DictionaryScope extends InheritedTheme {
  const DictionaryScope({
    super.key,
    required this.progress,
    this.media,
    required super.child,
  });

  final DictionaryProgress? progress;
  final MediaQueryData? media;

  static DictionaryScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DictionaryScope>();

  @override
  Widget wrap(BuildContext context, Widget child) =>
      DictionaryScope(progress: progress, media: media, child: child);

  @override
  bool updateShouldNotify(DictionaryScope oldWidget) =>
      progress != oldWidget.progress || media != oldWidget.media;
}
