import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../l10n/tr.dart';
import '../models/models.dart';
import '../theme.dart';
import 'chat_attach_sheet.dart';
import 'chat_audio_bubble.dart';
import 'food_image.dart';
import 'image_viewer.dart';

const double _tileWidth = 240;
const double _imageHeight = 240;
const double _videoHeight = 160;
const double _audioHeight = 96;

class ChatMediaBubble extends StatelessWidget {
  final ChatMessage message;
  const ChatMediaBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isAudio) return ChatAudioBubble(message: message);
    if (message.isImage) return _image(context);
    return _video(context);
  }

  Widget _image(BuildContext context) {
    final url = message.mediaUrl;
    if (url.isEmpty) {
      return const _Tile(
        height: _imageHeight,
        child: Icon(Icons.image_outlined, color: Colors.white54, size: 40),
      );
    }
    return Semantics(
      button: true,
      label: tr('Rasm'),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => showImageViewer(context, [url]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: SizedBox(
            width: _tileWidth,
            height: _imageHeight,
            child: netImage(
              url,
              cacheWidth: 720,
              errorBuilder: (_, __, ___) => const _Tile(
                height: _imageHeight,
                child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 40),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _video(BuildContext context) {
    switch (message.mediaStatus) {
      case ChatMessage.statusReady:
        final url = message.mediaUrl;
        return Semantics(
          button: true,
          label: tr("Videoni ko'rish"),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: url.isEmpty ? null : () => showChatVideoPlayer(context, url),
            child: const _Tile(height: _videoHeight, child: _PlayBadge()),
          ),
        );
      case ChatMessage.statusFailed:
        return _Tile(
          height: _videoHeight,
          child: _Caption(icon: Icons.error_outline, text: tr('Video yuborilmadi')),
        );
      default:
        return _Tile(
          height: _videoHeight,
          child: _Caption(spinner: true, text: tr('Video tayyorlanmoqda…')),
        );
    }
  }
}

class PendingMediaBubble extends StatelessWidget {
  final ChatAttachment attachment;
  final double progress;
  final bool failed;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  const PendingMediaBubble({
    super.key,
    required this.attachment,
    required this.progress,
    required this.failed,
    required this.onCancel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final bytes = attachment.bytes;
    final height = attachment.isAudio
        ? _audioHeight
        : attachment.isVideo
            ? _videoHeight
            : _imageHeight;
    final Widget preview = !attachment.isVideo && !attachment.isAudio && bytes != null
        ? Image.memory(bytes, fit: BoxFit.cover, width: _tileWidth, height: height)
        : _Tile(
            height: height,
            child: Icon(
              attachment.isAudio ? Icons.mic_none : Icons.videocam_outlined,
              color: Colors.white54,
              size: 40,
            ),
          );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: SizedBox(
          width: _tileWidth,
          height: height,
          child: Stack(fit: StackFit.expand, children: [
            preview,
            ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
            Center(
              child: failed
                  ? const Icon(Icons.error_outline, color: Colors.white, size: 36)
                  : SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: progress > 0 && progress < 1 ? progress : null,
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: AppSpace.xs),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Expanded(
          child: Text(
            failed ? tr('Yuborilmadi') : trf('Yuborilmoqda: {0}%', [(progress * 100).round()]),
            style: t.labelSmall?.copyWith(color: AppColors.onBubbleOwn),
          ),
        ),
        if (failed)
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 40),
              foregroundColor: AppColors.onBubbleOwn,
            ),
            onPressed: onRetry,
            child: Text(tr('Qayta urinish')),
          ),
        IconButton(
          tooltip: tr('Bekor'),
          style: IconButton.styleFrom(
            minimumSize: const Size(40, 40),
            foregroundColor: AppColors.onBubbleOwn,
          ),
          onPressed: onCancel,
          icon: const Icon(Icons.close, size: 20),
        ),
      ]),
    ]);
  }
}

class _Tile extends StatelessWidget {
  final double height;
  final Widget child;
  const _Tile({required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        width: _tileWidth,
        height: height,
        child: ColoredBox(color: Colors.black, child: Center(child: child)),
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
      child: Icon(Icons.play_arrow, color: AppColors.onAccent, size: 34),
    );
  }
}

class _Caption extends StatelessWidget {
  final IconData? icon;
  final bool spinner;
  final String text;
  const _Caption({this.icon, this.spinner = false, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (spinner)
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white70),
        )
      else
        Icon(icon, color: Colors.white70, size: 32),
      const SizedBox(height: AppSpace.sm),
      Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    ]);
  }
}

@visibleForTesting
Widget Function(String url)? debugChatVideoPlayer;

Future<void> showChatVideoPlayer(BuildContext context, String url) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (_) => Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Stack(children: [
          Positioned.fill(child: _ChatVideoPlayer(url: url)),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: tr('Yopish'),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ]),
      ),
    ),
  );
}

class _ChatVideoPlayer extends StatefulWidget {
  final String url;
  const _ChatVideoPlayer({required this.url});

  @override
  State<_ChatVideoPlayer> createState() => _ChatVideoPlayerState();
}

class _ChatVideoPlayerState extends State<_ChatVideoPlayer> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (debugChatVideoPlayer == null) _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    controller.addListener(() {
      if (mounted) setState(() {});
    });
    setState(() => _controller = controller);
    await controller.play();
  }

  void _toggle() {
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? c.pause() : c.play();
  }

  @override
  Widget build(BuildContext context) {
    final debug = debugChatVideoPlayer;
    if (debug != null) return debug(widget.url);
    final c = _controller;
    if (_failed) {
      return Center(
        child: Text(tr('Video yuklanmadi'), style: const TextStyle(color: Colors.white70)),
      );
    }
    if (c == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white70));
    }
    final playing = c.value.isPlaying;
    return Stack(fit: StackFit.expand, children: [
      Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
      Semantics(
        button: true,
        label: playing ? tr('Pauza') : tr("Videoni ko'rish"),
        child: InkWell(
          onTap: _toggle,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: playing ? 0 : 1,
            child: const Center(child: _PlayBadge()),
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: VideoProgressIndicator(
          c,
          allowScrubbing: true,
          colors: VideoProgressColors(playedColor: AppColors.accent),
        ),
      ),
    ]);
  }
}
