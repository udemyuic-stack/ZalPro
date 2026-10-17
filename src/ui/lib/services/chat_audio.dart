import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

abstract class AudioEngine {
  Stream<Duration> get position;
  Stream<bool> get playing;
  Stream<void> get completed;
  Future<void> open(String url);
  void play();
  Future<void> pause();
  Future<void> seekToStart();
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioEngine implements AudioEngine {
  final _player = AudioPlayer();

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Stream<bool> get playing => _player.playerStateStream
      .map((s) => s.playing && s.processingState != ProcessingState.completed)
      .distinct();

  @override
  Stream<void> get completed =>
      _player.playerStateStream.where((s) => s.processingState == ProcessingState.completed);

  @override
  Future<void> open(String url) => _player.setUrl(url);

  @override
  void play() => unawaited(_player.play());

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seekToStart() => _player.seek(Duration.zero);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

class ChatAudioController extends ChangeNotifier {
  ChatAudioController(this._engine) {
    _subs.add(_engine.position.listen((p) {
      if (_url == null) return;
      _position = p;
      notifyListeners();
    }));
    _subs.add(_engine.playing.listen((v) {
      _playing = v;
      notifyListeners();
    }));
    _subs.add(_engine.completed.listen((_) {
      _playing = false;
      _position = Duration.zero;
      notifyListeners();
    }));
  }

  static ChatAudioController? _instance;
  static ChatAudioController get instance => _instance ??= ChatAudioController(JustAudioEngine());

  @visibleForTesting
  static set instance(ChatAudioController? value) => _instance = value;

  static void stopActive() => _instance?.stop();

  final AudioEngine _engine;
  final _subs = <StreamSubscription<Object?>>[];
  String? _url;
  String? _failedUrl;
  bool _playing = false;
  Duration _position = Duration.zero;

  String? get url => _url;
  bool isFailed(String url) => _failedUrl == url;
  bool isPlaying(String url) => _url == url && _playing;
  Duration positionOf(String url) => _url == url ? _position : Duration.zero;

  Future<void> toggle(String url) async {
    if (_url == url) {
      if (_playing) {
        await _engine.pause();
      } else {
        _engine.play();
      }
      return;
    }
    _failedUrl = null;
    _url = url;
    _position = Duration.zero;
    _playing = false;
    notifyListeners();
    try {
      await _engine.open(url);
      if (_url != url) return;
      _engine.play();
    } catch (_) {
      _failedUrl = url;
      _url = null;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (_url == null) return;
    _url = null;
    _playing = false;
    _position = Duration.zero;
    notifyListeners();
    await _engine.stop();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _engine.dispose();
    super.dispose();
  }
}
