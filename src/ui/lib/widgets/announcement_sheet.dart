import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../models/announcement.dart';
import '../models/models.dart';
import '../services/api/api_error.dart';
import '../services/db.dart';
import '../theme.dart';
import 'ui.dart';

Future<void> showAnnouncements(BuildContext context, List<Announcement> items) =>
    showSheet<void>(context, AnnouncementList(items: items));

Future<void> showAnnouncementManager(BuildContext context, AppUser me) =>
    showSheet<void>(context, AnnouncementManager(me: me));

String announcementDate(DateTime? d) =>
    d == null ? '' : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

class AnnouncementList extends StatelessWidget {
  final List<Announcement> items;
  const AnnouncementList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: ListView(shrinkWrap: true, children: [
        Text(tr("E'lonlar"), style: t.titleLarge),
        const SizedBox(height: AppSpace.md),
        for (final a in items) AnnouncementCard(item: a),
      ]),
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  final Announcement item;
  final Widget? trailing;
  const AnnouncementCard({super.key, required this.item, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final meta = [item.authorName, announcementDate(item.createdAt)].where((e) => e.isNotEmpty);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: BentoTile(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: t.titleMedium),
              const SizedBox(height: AppSpace.xs),
              Text(item.body, style: t.bodyMedium),
              const SizedBox(height: AppSpace.sm),
              Text(
                meta.join(' · '),
                style: t.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      ),
    );
  }
}

class AnnouncementManager extends StatefulWidget {
  final AppUser me;
  final Stream<List<Announcement>>? source;
  const AnnouncementManager({super.key, required this.me, this.source});

  @override
  State<AnnouncementManager> createState() => _AnnouncementManagerState();
}

class _AnnouncementManagerState extends State<AnnouncementManager> {
  late final Stream<List<Announcement>> _stream = widget.source ?? Db.announcements();
  final _title = TextEditingController();
  final _body = TextEditingController();
  int? _days = 7;
  AnnouncementAudience _audience = AnnouncementAudience.students;
  bool _busy = false;
  bool _serverFull = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _owner => widget.me.isOwner;

  String _expiryLabel(int? days) => switch (days) {
        1 => tr('1 kun'),
        7 => tr('7 kun'),
        30 => tr('30 kun'),
        _ => tr('Muddatsiz'),
      };

  bool get _valid => _title.text.trim().isNotEmpty && _body.text.trim().isNotEmpty;

  Future<void> _add() async {
    setState(() => _busy = true);
    try {
      await Db.addAnnouncement(
        title: _title.text.trim(),
        body: _body.text.trim(),
        audience: _owner ? _audience : AnnouncementAudience.students,
        expiresInDays: _days,
      );
      if (!mounted) return;
      _title.clear();
      _body.clear();
      setState(() => _busy = false);
    } catch (err) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (err is ApiException && err.status == 409) {
        setState(() => _serverFull = true);
      } else if (err is ApiException && err.status == 403) {
        return;
      } else {
        showSnack(context, trf('Amalga oshmadi: {0}', [apiErrorText(err)]));
      }
    }
  }

  Future<void> _remove(Announcement a) async {
    try {
      await Db.removeAnnouncement(a.id);
      if (mounted) setState(() => _serverFull = false);
    } catch (err) {
      if (mounted) showSnack(context, trf('Amalga oshmadi: {0}', [apiErrorText(err)]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: StreamBuilder<List<Announcement>>(
        stream: _stream,
        builder: (context, snap) {
          final now = DateTime.now();
          final active = activeAnnouncements(snap.data ?? const [], now);
          final mine = [
            for (final a in active)
              if (_owner || a.authorId == widget.me.id) a,
          ];
          final full = _serverFull || announcementFull(active, widget.me.id, now);
          return ListView(shrinkWrap: true, children: [
            Text(tr("E'lonlar"), style: t.titleLarge),
            const SizedBox(height: AppSpace.md),
            if (mine.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: Text(
                  tr("Faol e'lon yo'q"),
                  style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              ),
            for (final a in mine)
              AnnouncementCard(
                item: a,
                trailing: IconButton(
                  key: Key('announcement-delete-${a.id}'),
                  tooltip: tr("O'chirish"),
                  constraints:
                      const BoxConstraints(minWidth: kTouchTarget, minHeight: kTouchTarget),
                  onPressed: () => _remove(a),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            const SizedBox(height: AppSpace.sm),
            Text(tr("Yangi e'lon"), style: t.titleMedium),
            const SizedBox(height: AppSpace.sm),
            TextField(
              key: const Key('announcement-title'),
              controller: _title,
              maxLength: announcementTitleMax,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: tr('Sarlavha')),
            ),
            TextField(
              key: const Key('announcement-body'),
              controller: _body,
              maxLength: announcementBodyMax,
              minLines: 2,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: tr('Matn')),
            ),
            const SizedBox(height: AppSpace.sm),
            Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
              for (final d in announcementExpiryChoices)
                ChoiceChip(
                  key: Key('announcement-expiry-${d ?? 'none'}'),
                  selected: _days == d,
                  onSelected: (_) => setState(() => _days = d),
                  label: Text(_expiryLabel(d)),
                ),
            ]),
            if (_owner) ...[
              const SizedBox(height: AppSpace.md),
              Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                ChoiceChip(
                  key: const Key('announcement-audience-students'),
                  selected: _audience == AnnouncementAudience.students,
                  onSelected: (_) => setState(() => _audience = AnnouncementAudience.students),
                  label: Text(tr('Mening shogirdlarim')),
                ),
                ChoiceChip(
                  key: const Key('announcement-audience-all'),
                  selected: _audience == AnnouncementAudience.all,
                  onSelected: (_) => setState(() => _audience = AnnouncementAudience.all),
                  label: Text(tr('Butun zal')),
                ),
              ]),
            ],
            const SizedBox(height: AppSpace.lg),
            if (full)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: Text(
                  tr("Eski e'lonni o'chiring"),
                  key: const Key('announcement-full-hint'),
                  style: t.bodySmall?.copyWith(color: AppColors.warning),
                ),
              ),
            FilledButton(
              key: const Key('announcement-add'),
              onPressed: (_busy || full || !_valid) ? null : _add,
              child: Text(tr("Qo'shish")),
            ),
          ]);
        },
      ),
    );
  }
}
