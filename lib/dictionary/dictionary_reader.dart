import 'package:flutter/material.dart';

import 'dictionary_audio.dart';
import 'dictionary_catalog.dart';
import 'dictionary_progress.dart';
import 'scroll_sheet.dart';
import 'word_explanation.dart';

Future<void> explainDictionaryWord(
  BuildContext context, {
  required DictionaryProgress progress,
  required DictionaryWord word,
  DictionaryAudio audio = const GameDictionaryAudio(),
  MediaQueryData? media,
}) async {
  final openScroll = await showWordExplanation(
    context,
    notebook: progress,
    word: word,
    media: media,
  );
  if (openScroll == true && context.mounted) {
    await showDictionaryScroll(
      context,
      progress: progress,
      audio: audio,
      media: media,
    );
  }
}
