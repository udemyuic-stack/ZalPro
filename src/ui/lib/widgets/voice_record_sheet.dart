import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../services/voice_recorder.dart';
import '../models/models.dart';
import '../theme.dart';
import 'ui.dart';

enum _Phase { starting, recording, limit, denied }

String formatVoiceTime(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class VoiceRecordSheet extends StatefulWidget {
  final VoiceRecorder Function()? recorderBuilder;
  const VoiceRecordSheet({super.key, this.recorderBuilder});

  @override
  State<VoiceRecordSheet> createState() => _VoiceRecordSheetState();
}

class _VoiceRecordSheetState extends State<VoiceRecordSheet> {
  late final VoiceRecorder _recorder = (widget.recorderBuilder ?? RecordVoiceRecorder.new)();
  _Phase _phase = _Phase.starting;
  Timer? _ticker;
  VoiceClip? _clip;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _begin() async {
    bool ok;
    try {
      ok = await _recorder.start();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (!ok) {
      setState(() => _phase = _Phase.denied);
      return;
    }
    setState(() => _phase = _Phase.recording);
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  Future<void> _tick() async {
    if (!mounted || _phase != _Phase.recording) return;
    if (_recorder.elapsed.inMilliseconds >= ChatMessage.maxAudioMs) {
      _ticker?.cancel();
      final clip = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _clip = clip;
        _phase = _Phase.limit;
      });
      return;
    }
    setState(() {});
  }

  Future<void> _send() async {
    _ticker?.cancel();
    final clip = _clip ?? await _recorder.stop();
    if (!mounted) return;
    if (clip == null || clip.durationMs < minVoiceMs) {
      showSnack(context, tr('Yozuv juda qisqa'));
      await _discard(clip);
      return;
    }
    _finished = true;
    Navigator.pop(context, clip);
  }

  Future<void> _discard([VoiceClip? clip]) async {
    _ticker?.cancel();
    _finished = true;
    final navigator = Navigator.of(context);
    final cleanup = clip != null ? deleteVoiceFile(clip.path) : _recorder.cancel();
    navigator.pop();
    await cleanup;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    final clip = _clip;
    if (!_finished) {
      if (clip != null) {
        unawaited(deleteVoiceFile(clip.path));
      } else {
        unawaited(_recorder.cancel());
      }
    }
    unawaited(_recorder.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final denied = _phase == _Phase.denied;
    final elapsed = _clip != null ? Duration(milliseconds: _clip!.durationMs) : _recorder.elapsed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('Ovozli xabar'), style: t.titleLarge),
        const SizedBox(height: AppSpace.md),
        if (denied)
          Text(
            tr("Mikrofon ruxsati berilmagan. Sozlamalardan ruxsat bering"),
            key: const Key('voice-denied'),
            style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
          )
        else
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.fiber_manual_record, color: AppColors.danger, size: 14),
            const SizedBox(width: AppSpace.sm),
            Text(
              formatVoiceTime(elapsed),
              key: const Key('voice-timer'),
              style: t.headlineSmall,
            ),
          ]),
        if (_phase == _Phase.limit) ...[
          const SizedBox(height: AppSpace.sm),
          Text(
            tr('Yozuv 5 daqiqaga yetdi'),
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: AppSpace.lg),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('voice-cancel'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
              onPressed: () => _discard(_clip),
              child: Text(denied ? tr('Yopish') : tr('Bekor')),
            ),
          ),
          if (!denied) ...[
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: FilledButton(
                key: const Key('voice-send'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
                onPressed: _phase == _Phase.starting ? null : _send,
                child: Text(tr('Yuborish')),
              ),
            ),
          ],
        ]),
      ],
    );
  }
}

Future<VoiceClip?> showVoiceRecordSheet(
  BuildContext context, {
  VoiceRecorder Function()? recorderBuilder,
}) =>
    showSheet<VoiceClip>(context, VoiceRecordSheet(recorderBuilder: recorderBuilder));
