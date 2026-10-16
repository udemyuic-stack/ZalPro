import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../services/api/api_error.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

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

class _ChatScreenState extends State<ChatScreen> {
  final _c = TextEditingController();
  late final _stream = Db.messages(widget.chatUid);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _c.text.trim();
    if (t.isEmpty) return;
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
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          UserAvatar(name: widget.title, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (widget.subtitle != null)
                Text(widget.subtitle!, style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
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
              if (msgs.isEmpty) {
                return EmptyState(
                  icon: Icons.forum_outlined,
                  title: tr('Suhbatni boshlang'),
                  subtitle: tr("Ovqatlanish, mashq yoki reja bo'yicha savolingizni yozing."),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final m = msgs[i];
                  // ro'yxat teskari: i + 1 — eskiroq xabar
                  final showDay =
                      i == msgs.length - 1 || !_sameDay(m.createdAt, msgs[i + 1].createdAt);
                  final grouped = i > 0 && msgs[i - 1].senderId == m.senderId;
                  return Column(children: [
                    if (showDay) _DayChip(_dayLabel(m.createdAt)),
                    _Bubble(message: m, mine: m.senderId == widget.myId, tight: grouped),
                  ]);
                },
              );
            },
          ),
        ),
        _Composer(controller: _c, onSend: _send),
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

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine, tight;
  const _Bubble({required this.message, required this.mine, required this.tight});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    // O'z xabarim — olmos ko'ki bilan yengil bo'yalgan yuza (urg'u rangi tugmalarga qoladi)
    final bg = mine
        ? Color.alphaBlend(AppColors.accent.withValues(alpha: 0.16), AppColors.card)
        : (Theme.of(context).cardTheme.color ?? s.surface);
    final fg = AppColors.text;
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(trChat(message.text), style: t.bodyLarge?.copyWith(color: fg)),
          const SizedBox(height: 2),
          Text(DateFormat('HH:mm').format(message.createdAt),
              style: t.labelSmall?.copyWith(color: fg.withValues(alpha: 0.7))),
        ]),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    OutlineInputBorder pill([Color? c]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: c == null ? BorderSide.none : BorderSide(color: c, width: 1.5),
        );
    return Material(
      color: Theme.of(context).cardTheme.color,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
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
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, v, child) => IconButton.filled(
                tooltip: tr('Yuborish'),
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  disabledBackgroundColor: s.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: v.text.trim().isEmpty ? null : onSend,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
