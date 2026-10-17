import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/tr.dart';
import '../models/announcement.dart';
import '../services/db.dart';
import '../theme.dart';
import 'announcement_sheet.dart';
import 'ui.dart';

class AnnouncementBanner extends StatefulWidget {
  final String userId;
  final Stream<List<Announcement>>? source;
  final DateTime Function()? clock;
  const AnnouncementBanner({super.key, required this.userId, this.source, this.clock});

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  late final Stream<List<Announcement>> _stream = widget.source ?? Db.announcements();
  Set<String> _dismissed = {};
  bool _loaded = false;

  String get _key => 'announcement_dismissed_${widget.userId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dismissed = (prefs.getStringList(_key) ?? const <String>[]).toSet();
      _loaded = true;
    });
  }

  Future<void> _dismiss(String id) async {
    setState(() => _dismissed = {..._dismissed, id});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _dismissed.toList());
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return StreamBuilder<List<Announcement>>(
      stream: _stream,
      builder: (context, snap) {
        final now = (widget.clock ?? DateTime.now)();
        final active = activeAnnouncements(snap.data ?? const [], now);
        final shown = active.where((a) => !_dismissed.contains(a.id));
        if (shown.isEmpty) return const SizedBox.shrink();
        final a = shown.first;
        final t = Theme.of(context).textTheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.lg),
          child: BentoTile(
            key: const Key('announcement-banner'),
            feature: true,
            padding:
                const EdgeInsets.fromLTRB(AppSpace.md + 2, AppSpace.sm, AppSpace.xs, AppSpace.sm),
            onTap: () => showAnnouncements(context, active),
            child: Row(children: [
              Icon(Icons.campaign_outlined, color: AppColors.accent),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    a.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ]),
              ),
              IconButton(
                key: const Key('announcement-dismiss'),
                tooltip: tr('Yopish'),
                constraints: const BoxConstraints(minWidth: kTouchTarget, minHeight: kTouchTarget),
                onPressed: () => _dismiss(a.id),
                icon: const Icon(Icons.close),
              ),
            ]),
          ),
        );
      },
    );
  }
}
