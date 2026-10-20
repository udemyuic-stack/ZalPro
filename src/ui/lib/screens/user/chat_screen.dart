import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/input_rules.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../services/api/api_error.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../services/chat_audio.dart';
import '../../services/voice_recorder.dart';
import '../../widgets/chat_attach_sheet.dart';
import '../../widgets/chat_media_bubble.dart';
import '../../widgets/ui.dart';
import '../../widgets/voice_record_sheet.dart';

class ChatScreen extends StatefulWidget {
  final String chatUid; // chat egasi (user id)
  final String myId;
  final String title;
  final String? subtitle;

  /// true — faqat o'zim va chat egasi (shogird) xabarlari ko'rinadi.
  /// Trener uchun: bosh admin shogirdga yozgan xabarlar ko'rsatilmaydi.
  final bool onlyMineAndClient;
  const ChatScreen({
    super.key,
    required this.chatUid,
    required this.myId,
    required this.title,
    this.subtitle,
    this.onlyMineAndClient = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _PendingMedia {
  final ChatAttachment attachment;
  double progress = 0;
  bool failed = false;
  bool cancelled = false;
  CancelToken? token;
  _PendingMedia(this.attachment);
}

class _ChatScreenState extends State<ChatScreen> {
  final _c = TextEditingController();
  late final _stream = Db.messages(widget.chatUid);
  final _pending = <_PendingMedia>[];

  @override
  void dispose() {
    for (final p in _pending) {
      p.cancelled = true;
      p.token?.cancel();
      _dropFile(p);
    }
    ChatAudioController.stopActive();
    _c.dispose();
    super.dispose();
  }

  Future<void> _attach() async => _queue(await pickChatAttachment(context));

  Future<void> _voice(VoiceClip clip) async => _queue(chatVoiceAttachment(clip));

  Future<void> _queue(ChatAttachment? picked) async {
    if (picked == null || !mounted) return;
    final item = _PendingMedia(picked);
    setState(() => _pending.add(item));
    await _upload(item);
  }

  Future<void> _upload(_PendingMedia item) async {
    final a = item.attachment;
    final token = CancelToken();
    item.token = token;
    setState(() {
      item.failed = false;
      item.progress = 0;
    });
    try {
      final key = await Db.uploadChatMedia(
        widget.chatUid,
        kind: a.kind,
        contentType: a.contentType,
        size: a.size,
        bytes: a.bytes,
        open: a.bytes == null ? a.file!.openRead : null,
        cancelToken: token,
        onProgress: (sent, total) {
          if (mounted && total > 0 && !item.cancelled) {
            setState(() => item.progress = sent / total);
          }
        },
      );
      if (item.cancelled) return;
      await Db.sendMessage(
        widget.chatUid,
        mediaKey: key,
        mediaKind: a.kind,
        durationMs: a.isAudio ? a.durationMs : null,
      );
      _dropFile(item);
      if (mounted) setState(() => _pending.remove(item));
    } catch (e) {
      if (item.cancelled || !mounted) return;
      setState(() => item.failed = true);
      showSnack(context, trf("Bo'lmadi: {0}", [apiErrorText(e)]));
    }
  }

  void _cancel(_PendingMedia item) {
    item.cancelled = true;
    item.token?.cancel();
    _dropFile(item);
    setState(() => _pending.remove(item));
  }

  void _dropFile(_PendingMedia item) {
    final a = item.attachment;
    final file = a.file;
    if (a.isAudio && file != null) deleteVoiceFile(file.path);
  }

  void _retry(_PendingMedia item) => _upload(item);

  Future<void> _send() async {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    if (InputRules.length(t) > InputLimits.message) {
      showSnack(context, trf("Xabar eng ko'pi {0} belgi bo'lishi mumkin", [InputLimits.message]));
      return;
    }
    _c.clear();
    try {
      await Db.send(widget.chatUid, widget.myId, t);
    } catch (e) {
      if (!mounted) return;
      if (_c.text.isEmpty) _c.text = t;
      showSnack(context, trf("Bo'lmadi: {0}", [apiErrorText(e)]));
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dayLabel(DateTime d) {
    final now = DateTime.now();
    if (_sameDay(d, now)) return tr('Bugun');
    if (_sameDay(d, now.subtract(const Duration(days: 1)))) return tr('Kecha');
    return DateFormat('dd.MM.yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          UserAvatar(name: widget.title, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (widget.subtitle != null)
                Text(widget.subtitle!, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ]),
          ),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) return ErrorState(error: snap.error);
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final msgs = widget.onlyMineAndClient
                  ? snap.data!
                      .where((m) => m.senderId == widget.myId || m.senderId == widget.chatUid)
                      .toList()
                  : snap.data!;
              if (msgs.isEmpty && _pending.isEmpty) {
                return EmptyState(
                  icon: Icons.forum_outlined,
                  title: tr('Suhbatni boshlang'),
                  subtitle: tr("Ovqatlanish, mashq yoki reja bo'yicha savolingizni yozing."),
                  action: Padding(
                    padding: const EdgeInsets.only(top: AppSpace.md),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.sm,
                      children: [
                        for (final q in [
                          tr('Bugun nima yeyman?'),
                          tr('Mashq rejasi haqida savol'),
                          tr('Vazn tushirish bo\'yicha maslahat'),
                        ])
                          ActionChip(
                            label: Text(q),
                            onPressed: () {
                              _c.text = q;
                              _c.selection = TextSelection.collapsed(offset: q.length);
                            },
                          ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                itemCount: _pending.length + msgs.length,
                itemBuilder: (_, n) {
                  if (n < _pending.length) {
                    final p = _pending[_pending.length - 1 - n];
                    return _PendingBubble(
                      item: p,
                      onCancel: () => _cancel(p),
                      onRetry: () => _retry(p),
                    );
                  }
                  final i = n - _pending.length;
                  final m = msgs[i];
                  // ro'yxat teskari: i + 1 — eskiroq xabar
                  final showDay =
                      i == msgs.length - 1 || !_sameDay(m.createdAt, msgs[i + 1].createdAt);
                  final grouped = i > 0 && msgs[i - 1].senderId == m.senderId;
                  return Column(children: [
                    if (showDay) _DayChip(_dayLabel(m.createdAt)),
                    ChatBubble(message: m, mine: m.senderId == widget.myId, tight: grouped),
                  ]);
                },
              );
            },
          ),
        ),
        ChatComposer(controller: _c, onSend: _send, onAttach: _attach, onVoice: _voice),
      ]),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  const _DayChip(this.label);

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: s.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine, tight;
  const ChatBubble({super.key, required this.message, required this.mine, required this.tight});

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) return _SystemNote(message: message);
    final t = Theme.of(context).textTheme;
    final fg = mine ? AppColors.onBubbleOwn : AppColors.text;
    return _BubbleShell(
      mine: mine,
      tight: tight,
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (message.hasMedia) ...[
          ChatMediaBubble(message: message),
          const SizedBox(height: 4),
        ],
        if (message.text.isNotEmpty || !message.hasMedia)
          Text(trChat(message.text), style: t.bodyLarge?.copyWith(color: fg)),
        const SizedBox(height: 2),
        Text(DateFormat('HH:mm').format(message.createdAt),
            style: t.labelSmall?.copyWith(color: mine ? fg : fg.withValues(alpha: 0.7))),
      ]),
    );
  }
}

class _SystemNote extends StatelessWidget {
  final ChatMessage message;
  const _SystemNote({required this.message});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: LayoutBuilder(
        builder: (context, box) => Center(
          child: Container(
            key: const Key('system-note'),
            constraints: BoxConstraints(maxWidth: box.maxWidth * 0.9),
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.notifications_none_outlined, size: 22, color: AppColors.textMuted),
              const SizedBox(width: AppSpace.sm),
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    tr('Tizim xabari'),
                    style: t.labelMedium?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(trChat(message.text), style: t.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('HH:mm').format(message.createdAt),
                    style: t.labelSmall?.copyWith(color: AppColors.textMuted),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PendingBubble extends StatelessWidget {
  final _PendingMedia item;
  final VoidCallback onCancel, onRetry;
  const _PendingBubble({required this.item, required this.onCancel, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _BubbleShell(
      mine: true,
      tight: false,
      child: PendingMediaBubble(
        attachment: item.attachment,
        progress: item.progress,
        failed: item.failed,
        onCancel: onCancel,
        onRetry: onRetry,
      ),
    );
  }
}

class _BubbleShell extends StatelessWidget {
  final bool mine, tight;
  final Widget child;
  const _BubbleShell({required this.mine, required this.tight, required this.child});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final bg = mine ? AppColors.bubbleOwn : (Theme.of(context).cardTheme.color ?? s.surface);
    const r = Radius.circular(18);
    const tail = Radius.circular(6);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: tight ? 3 : 10, left: mine ? 48 : 0, right: mine ? 0 : 48),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: mine ? r : tail,
            bottomRight: mine ? tail : r,
          ),
          border: mine ? null : Border.all(color: s.outlineVariant),
        ),
        child: child,
      ),
    );
  }
}

class ChatComposer extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final Future<void> Function(VoiceClip clip)? onVoice;
  final VoiceRecorder Function()? recorderBuilder;
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    this.onVoice,
    this.recorderBuilder,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

enum _VoicePhase { idle, recording, locked }

class _ChatComposerState extends State<ChatComposer> {
  static const _cancelDx = 100.0;
  static const _lockDy = 80.0;

  _VoicePhase _phase = _VoicePhase.idle;
  VoiceRecorder? _recorder;
  Timer? _ticker;
  bool _holding = false;
  bool _starting = false;

  bool get _active => _phase != _VoicePhase.idle;

  Future<void> _begin() async {
    if (_starting || _active || widget.onVoice == null) return;
    _starting = true;
    _holding = true;
    final recorder = (widget.recorderBuilder ?? RecordVoiceRecorder.new)();
    bool ok;
    try {
      ok = await recorder.start();
    } catch (_) {
      ok = false;
    }
    _starting = false;
    if (!mounted) {
      await recorder.cancel();
      await recorder.dispose();
      return;
    }
    if (!ok) {
      _holding = false;
      await recorder.dispose();
      if (mounted) {
        showSnack(context, tr('Mikrofon ruxsati berilmagan. Sozlamalardan ruxsat bering'));
      }
      return;
    }
    _recorder = recorder;
    HapticFeedback.mediumImpact();
    setState(() => _phase = _VoicePhase.recording);
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    if (!_holding) await _finish(send: true);
  }

  Future<void> _tick() async {
    final r = _recorder;
    if (!mounted || r == null || !_active) return;
    if (r.elapsed.inMilliseconds >= ChatMessage.maxAudioMs) {
      await _finish(send: true);
      return;
    }
    setState(() {});
  }

  void _move(LongPressMoveUpdateDetails d) {
    if (_phase != _VoicePhase.recording) return;
    final o = d.offsetFromOrigin;
    if (o.dx <= -_cancelDx) {
      HapticFeedback.lightImpact();
      _finish(send: false);
    } else if (-o.dy >= _lockDy) {
      HapticFeedback.lightImpact();
      setState(() => _phase = _VoicePhase.locked);
    }
  }

  void _release() {
    _holding = false;
    if (_phase == _VoicePhase.recording) _finish(send: true);
  }

  Future<void> _finish({required bool send}) async {
    final recorder = _recorder;
    if (recorder == null) return;
    _recorder = null;
    _ticker?.cancel();
    setState(() => _phase = _VoicePhase.idle);
    if (!send) {
      await recorder.cancel();
      await recorder.dispose();
      return;
    }
    VoiceClip? clip;
    try {
      clip = await recorder.stop();
    } catch (_) {
      clip = null;
    }
    await recorder.dispose();
    if (!mounted) {
      if (clip != null) await deleteVoiceFile(clip.path);
      return;
    }
    if (clip == null || clip.durationMs < minVoiceMs) {
      if (clip != null) await deleteVoiceFile(clip.path);
      if (mounted) showSnack(context, tr('Yozuv juda qisqa'));
      return;
    }
    await widget.onVoice?.call(clip);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    final r = _recorder;
    if (r != null) {
      unawaited(r.cancel().whenComplete(r.dispose));
    }
    super.dispose();
  }

  Widget _micButton(ColorScheme s) {
    return GestureDetector(
      key: const Key('composer-mic'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showSnack(context, tr('Yozish uchun mikrofonni bosib turing')),
      onLongPressStart: (_) => _begin(),
      onLongPressMoveUpdate: _move,
      onLongPressEnd: (_) => _release(),
      onLongPressCancel: _release,
      child: _actionIcon(s, _active ? Icons.mic : Icons.mic_none, scale: _active ? 1.25 : 1),
    );
  }

  Widget _actionIcon(ColorScheme s, IconData icon, {double scale = 1}) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, color: AppColors.onAccent),
      ),
    );
  }

  Widget _recordingBar(ColorScheme s) {
    final t = Theme.of(context).textTheme;
    final locked = _phase == _VoicePhase.locked;
    final elapsed = _recorder?.elapsed ?? Duration.zero;
    return Row(children: [
      if (locked)
        IconButton(
          key: const Key('voice-discard'),
          tooltip: tr("O'chirish"),
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => _finish(send: false),
          icon: Icon(Icons.delete_outline, color: AppColors.danger),
        )
      else
        const SizedBox(width: AppSpace.sm),
      Icon(Icons.fiber_manual_record, color: AppColors.danger, size: 14),
      const SizedBox(width: AppSpace.sm),
      Text(formatVoiceTime(elapsed), key: const Key('voice-timer'), style: t.titleMedium),
      const SizedBox(width: AppSpace.md),
      Expanded(
        child: Text(
          locked ? tr('Yozilmoqda') : tr('Chapga — bekor, tepaga — qulf'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final canRecord = widget.onVoice != null &&
        voiceRecordSupported(isWeb: kIsWeb, platform: defaultTargetPlatform);
    OutlineInputBorder pill([Color? c]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: c == null ? BorderSide.none : BorderSide(color: c, width: 1.5),
        );
    final field = Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      IconButton(
        tooltip: tr('Rasm yoki video'),
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: widget.onAttach,
        icon: const Icon(Icons.attach_file_outlined),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: TextField(
          controller: widget.controller,
          minLines: 1,
          maxLines: 4,
          maxLength: InputLimits.message,
          buildCounter: InputRules.counterAtEighty,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => widget.onSend(),
          decoration: InputDecoration(
            hintText: tr('Xabar yozing...'),
            fillColor: s.surfaceContainerHighest.withValues(alpha: 0.6),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            border: pill(),
            enabledBorder: pill(),
            focusedBorder: pill(s.primary),
          ),
        ),
      ),
    ]);
    return Material(
      color: Theme.of(context).cardTheme.color,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: _active ? SizedBox(height: 48, child: _recordingBar(s)) : field,
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, v, child) {
                final empty = v.text.trim().isEmpty;
                if (_phase == _VoicePhase.locked) {
                  return IconButton.filled(
                    key: const Key('voice-send'),
                    tooltip: tr('Yuborish'),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: () => _finish(send: true),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  );
                }
                if ((empty && canRecord) || _active) return _micButton(s);
                return IconButton.filled(
                  tooltip: tr('Yuborish'),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    disabledBackgroundColor: AppColors.cardHigh,
                    disabledForegroundColor: AppColors.textMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  onPressed: empty ? null : widget.onSend,
                  icon: const Icon(Icons.arrow_upward_rounded),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}
