import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../models/models.dart';
import '../services/chat_audio.dart';
import '../theme.dart';
import 'voice_record_sheet.dart';

const double audioBubbleWidth = 240;

class ChatAudioBubble extends StatelessWidget {
  final ChatMessage message;
  final ChatAudioController? controller;
  const ChatAudioBubble({super.key, required this.message, this.controller});

  @override
  Widget build(BuildContext context) {
    final audio = controller ?? ChatAudioController.instance;
    final url = message.mediaUrl;
    final total = Duration(milliseconds: message.mediaDurationMs);
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final playing = audio.isPlaying(url);
        final failed = audio.isFailed(url);
        final position = audio.positionOf(url);
        final progress = total.inMilliseconds == 0
            ? 0.0
            : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
        final t = Theme.of(context).textTheme;
        return SizedBox(
          width: audioBubbleWidth,
          child: Row(children: [
            Semantics(
              button: true,
              label: tr('Ovozli xabar'),
              child: IconButton.filled(
                key: const Key('audio-play'),
                constraints:
                    const BoxConstraints.tightFor(width: kTouchTarget, height: kTouchTarget),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                ),
                onPressed: url.isEmpty ? null : () => audio.toggle(url),
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      color: AppColors.accent,
                      backgroundColor: AppColors.textMuted.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    failed
                        ? tr("Ijro bo'lmadi")
                        : playing || position > Duration.zero
                            ? '${formatVoiceTime(position)} / ${formatVoiceTime(total)}'
                            : formatVoiceTime(total),
                    key: const Key('audio-time'),
                    style: t.labelSmall?.copyWith(
                      color: failed ? AppColors.danger : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}
