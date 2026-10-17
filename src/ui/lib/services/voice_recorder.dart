import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

const minVoiceMs = 1000;

bool voiceRecordSupported({required bool isWeb, required TargetPlatform platform}) =>
    !isWeb && platform == TargetPlatform.android;

class VoiceClip {
  final String path;
  final int durationMs;
  final int size;
  const VoiceClip({required this.path, required this.durationMs, required this.size});
}

abstract class VoiceRecorder {
  Future<bool> start();
  Duration get elapsed;
  Future<VoiceClip?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class RecordVoiceRecorder implements VoiceRecorder {
  final _recorder = AudioRecorder();
  final _watch = Stopwatch();
  String? _path;

  @override
  Duration get elapsed => _watch.elapsed;

  @override
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
    _path = path;
    _watch
      ..reset()
      ..start();
    return true;
  }

  @override
  Future<VoiceClip?> stop() async {
    _watch.stop();
    final path = await _recorder.stop() ?? _path;
    _path = null;
    if (path == null) return null;
    return VoiceClip(
      path: path,
      durationMs: _watch.elapsedMilliseconds,
      size: await XFile(path).length(),
    );
  }

  @override
  Future<void> cancel() async {
    _watch.stop();
    final path = _path;
    _path = null;
    await _recorder.cancel();
    if (path != null) await deleteVoiceFile(path);
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

Future<void> deleteVoiceFile(String path) async {
  if (kIsWeb) return;
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {}
}
