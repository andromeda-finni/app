import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Short, reusable audio cues shared by the map, economy and mini-games.
enum GameSound {
  uiTap('audio/sfx/item_place.wav', volume: 0.22),
  itemPlaced('audio/sfx/item_place.wav', volume: 0.45),
  purchase('audio/sfx/purchase.wav', volume: 0.48),
  coinSingle('audio/sfx/coin_single.ogg', volume: 0.55),
  coinsMultiple('audio/sfx/coins_multiple.ogg', volume: 0.58),
  successReward('audio/sfx/success_reward.ogg', volume: 0.58),
  tryAgain('audio/sfx/try_again.ogg', volume: 0.34),
  magicEvent('audio/sfx/magic_event.ogg', volume: 0.55),
  catMeow('audio/sfx/cat_meow.ogg', volume: 0.58),
  catPurr('audio/sfx/cat_mewpurr.wav', volume: 0.52);

  const GameSound(this.assetPath, {required this.volume});

  final String assetPath;
  final double volume;
}

enum GameAmbience {
  forestBirds('audio/ambience/forest_birds.ogg', volume: 0.16);

  const GameAmbience(this.assetPath, {required this.volume});

  final String assetPath;
  final double volume;
}

enum GameMusic {
  mainTheme('audio/music/music.mp3', volume: 0.5);

  const GameMusic(this.assetPath, {required this.volume});

  final String assetPath;
  final double volume;
}

/// A small audio boundary for the whole application.
///
/// UI code names an event instead of knowing a file path. That keeps sound
/// replacement and volume tuning in one place and makes the existing sound
/// and music settings effective for every game.
class GameAudioService {
  GameAudioService._({
    List<AudioPlayer>? effectPlayers,
    AudioPlayer? ambience,
    AudioPlayer? music,
  })
    : _effectPlayers = effectPlayers ?? List.generate(3, (_) => AudioPlayer()),
      _ambiencePlayer = ambience ?? AudioPlayer(),
      _musicPlayer = music ?? AudioPlayer();

  static final GameAudioService instance = GameAudioService._();

  final List<AudioPlayer> _effectPlayers;
  final AudioPlayer _ambiencePlayer;
  final AudioPlayer _musicPlayer;
  int _nextEffectPlayer = 0;
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  GameAmbience? _activeAmbience;
  GameMusic? _activeMusic;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  void configure({required bool soundEnabled, required bool musicEnabled}) {
    final shouldRestartMusic = !_musicEnabled && musicEnabled;
    _soundEnabled = soundEnabled;
    _musicEnabled = musicEnabled;
    if (!soundEnabled) unawaited(stopEffects());
    if (!musicEnabled) {
      unawaited(stopAmbience());
      unawaited(stopMusic());
    } else if (shouldRestartMusic) {
      unawaited(startMusic(GameMusic.mainTheme));
    }
  }

  Future<void> play(GameSound sound) async {
    if (!_soundEnabled) return;
    final player = _effectPlayers[_nextEffectPlayer];
    _nextEffectPlayer = (_nextEffectPlayer + 1) % _effectPlayers.length;
    try {
      await player.stop();
      await player.play(
        AssetSource(sound.assetPath),
        volume: sound.volume,
        mode: PlayerMode.lowLatency,
      );
    } catch (error, stackTrace) {
      // Audio feedback must never block the child from completing a quest.
      debugPrint('Could not play ${sound.name}: $error\n$stackTrace');
    }
  }

  Future<void> startAmbience(GameAmbience ambience) async {
    if (!_musicEnabled || _activeAmbience == ambience) return;
    try {
      await _ambiencePlayer.stop();
      await _ambiencePlayer.setReleaseMode(ReleaseMode.loop);
      await _ambiencePlayer.play(
        AssetSource(ambience.assetPath),
        volume: ambience.volume,
      );
      _activeAmbience = ambience;
    } catch (error, stackTrace) {
      debugPrint('Could not play ${ambience.name}: $error\n$stackTrace');
    }
  }

  Future<void> stopEffects() async {
    try {
      await Future.wait(_effectPlayers.map((player) => player.stop()));
    } catch (error, stackTrace) {
      debugPrint('Could not stop sound effects: $error\n$stackTrace');
    }
  }

  Future<void> stopAmbience() async {
    _activeAmbience = null;
    try {
      await _ambiencePlayer.stop();
    } catch (error, stackTrace) {
      debugPrint('Could not stop ambience: $error\n$stackTrace');
    }
  }

  Future<void> startMusic(GameMusic music) async {
    if (!_musicEnabled || _activeMusic == music) return;
    try {
      await _musicPlayer.stop();
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.play(
        AssetSource(music.assetPath),
        volume: music.volume,
      );
      _activeMusic = music;
    } catch (error, stackTrace) {
      debugPrint('Could not play ${music.name}: $error\n$stackTrace');
    }
  }

  Future<void> pauseMusic() async {
    if (_activeMusic == null) return;
    try {
      await _musicPlayer.pause();
    } catch (error, stackTrace) {
      debugPrint('Could not pause music: $error\n$stackTrace');
    }
  }

  Future<void> resumeMusic() async {
    if (!_musicEnabled || _activeMusic == null) return;
    try {
      await _musicPlayer.resume();
    } catch (error, stackTrace) {
      debugPrint('Could not resume music: $error\n$stackTrace');
    }
  }

  Future<void> stopMusic() async {
    _activeMusic = null;
    try {
      await _musicPlayer.stop();
    } catch (error, stackTrace) {
      debugPrint('Could not stop music: $error\n$stackTrace');
    }
  }

  @visibleForTesting
  void resetForTest() {
    _soundEnabled = true;
    _musicEnabled = true;
    _activeAmbience = null;
    _activeMusic = null;
    _nextEffectPlayer = 0;
  }
}
