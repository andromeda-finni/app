import '../core/game_audio_service.dart';

abstract interface class DictionaryAudio {
  Future<void> openScroll();
}

class GameDictionaryAudio implements DictionaryAudio {
  const GameDictionaryAudio();

  @override
  Future<void> openScroll() =>
      GameAudioService.instance.play(GameSound.parchment);
}
