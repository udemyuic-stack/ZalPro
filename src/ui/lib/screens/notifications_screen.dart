import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../models/feed.dart';
import '../models/models.dart';
import '../models/shop.dart';
import '../services/db.dart';
import '../services/settings.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Bildirishnomalar ro'yxatini yig'ib beradi (shogird va trener uchun turlicha).
///
/// Yangi ma'lumot saqlanmaydi — hammasi bazadagi narsalardan hisoblanadi, shuning uchun
/// telefonda bildirishnoma o'chirilgan bo'lsa ham ro'yxat to'liq bo'ladi.
class FeedBuilder extends StatefulWidget {
  final AppUser user;
  final Widget Function(BuildContext context, List<FeedItem> items) builder;
  const FeedBuilder({super.key, required this.user, required this.builder});

  @override
  State<FeedBuilder> createState() => _FeedBuilderState();
}

class _FeedBuilderState extends State<FeedBuilder> {
  final _subs = <StreamSubscription<dynamic>>[];
  final _chatSubs = <String, StreamSubscription<List<ChatMessage>>>{};

  // shogird
  List<ChatMessage> _messages = const [];
  Plan? _plan;
  List<WeightLog> _weights = const [];
  Set<int> _done = const {};

  // trener
  List<AppUser> _clients = const [];
  final _clientMessages = <String, List<ChatMessage>>{};

  // ikkalasi
  List<ShopOrder> _orders = const [];

  bool get _isStaff => widget.user.isAdmin;
  bool get _isBarmen => widget.user.isBarmen;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _add<T>(Stream<T> stream, void Function(T) onData) {
    _subs.add(stream.listen((v) {
      if (mounted) setState(() => onData(v));
    }));
  }

  void _start() {
    if (_isBarmen) {
      _add(Db.gymOrders(widget.user.gymId), (v) => _orders = v);
      return;
    }
    if (_isStaff) {
      _add(Db.ordersOf(widget.user.id), (v) => _orders = v);
      _add(Db.clientsOf(widget.user.id), (clients) {
        _clients = clients;
        final ids = clients.map((c) => c.id).toSet();
        for (final c in clients) {
          _chatSubs.putIfAbsent(
            c.id,
            () => Db.messages(c.id, live: false).listen((msgs) {
              if (mounted) setState(() => _clientMessages[c.id] = msgs);
            }),
          );
        }
        for (final gone in _chatSubs.keys.where((k) => !ids.contains(k)).toList()) {
          _chatSubs.remove(gone)?.cancel();
          _clientMessages.remove(gone);
        }
      });
      return;
    }

    _add(Db.messages(widget.user.id, live: false), (v) => _messages = v);
    _add(Db.weights(widget.user.id), (v) => _weights = v);
    _add(Db.myOrders(widget.user.id), (v) => _orders = v);
    _add(Db.doneMeals(widget.user.id, todayKey()), (v) => _done = v);
    final planId = widget.user.planId;
    if (planId != null) _add(Db.plan(planId), (v) => _plan = v);
  }

  @override
  void didUpdateWidget(FeedBuilder old) {
    super.didUpdateWidget(old);
    // reja almashsa — yangisiga o'tamiz
    if (!_isStaff && widget.user.planId != old.user.planId) {
      for (final s in _subs) {
        s.cancel();
      }
      _subs.clear();
      _plan = null;
      _start();
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    for (final s in _chatSubs.values) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _isBarmen
        ? barmenFeed(orders: _orders)
        : _isStaff
            ? trainerFeed(
                trainer: widget.user,
                clients: _clients,
                messages: _clientMessages,
                orders: _orders,
              )
            : studentFeed(
                user: widget.user,
                messages: _messages,
                plan: _plan,
                weights: _weights,
                orders: _orders,
                doneMeals: _done,
              );
    return widget.builder(context, items);
  }
}

/// Pastki menyudagi belgi: yangi bildirishnomalar soni
class FeedBadge extends StatelessWidget {
  final AppUser user;
  final Widget icon;
  const FeedBadge({super.key, required this.user, required this.icon});

  @override
  Widget build(BuildContext context) => FeedBuilder(
        user: user,
        builder: (context, items) => ValueListenableBuilder<DateTime?>(
          valueListenable: AppSettings.feedSeen,
          builder: (context, seen, _) {
            final n = unreadCount(items, seen);
            if (n == 0) return icon;
            return Badge(
              label: Text('$n'),
              backgroundColor: AppColors.danger,
              textColor: AppColors.onAccent,
              child: icon,
            );
          },
        ),
      );
}

/// "Eslatma" bo'limi — hamma bildirishnomalar bitta ro'yxatda
class NotificationsScreen extends StatefulWidget {
  final AppUser user;
  const NotificationsScreen({super.key, required this.user});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// Ekran ochilgandagi holat — shu vaqtdan keyingilari "yangi" deb belgilanadi
  DateTime? _seenAt;

  @override
  void initState() {
    super.initState();
    _seenAt = AppSettings.feedSeen.value;
    WidgetsBinding.instance.addPostFrameCallback((_) => AppSettings.markFeedSeen());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FeedBuilder(
      user: widget.user,
      builder: (context, items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.notifications_none,
            title: tr('Bildirishnoma yo‘q'),
            subtitle: tr('Yangi xabar, reja yoki buyurtma bo‘lsa shu yerda chiqadi — '
                'telefonda bildirishnoma o‘chirilgan bo‘lsa ham.'),
          );
        }
        final action = items.where((i) => i.action).toList();
        final rest = items.where((i) => !i.action).toList();

        // AppBar yo'q - ro'yxat telefon status bari ostiga kirib ketmasin
        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xxl),
            children: [
              Text(tr('Eslatmalar'), style: t.headlineSmall),
              const SizedBox(height: 2),
              Text(
                tr('Ilovadagi hamma bildirishnoma shu yerda saqlanadi'),
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
              const SizedBox(height: AppSpace.lg),
              if (action.isNotEmpty) ...[
                SectionHeader(
                  tr('Amal kutilmoqda'),
                  trailing: Pill(text: '${action.length}', color: AppColors.warning),
                ),
                for (final i in action)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.sm),
                    child: _FeedTile(item: i, isNew: _isNew(i)),
                  ),
                const SizedBox(height: AppSpace.lg),
              ],
              if (rest.isNotEmpty) SectionHeader(tr('Tarix')),
              for (final i in rest)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: _FeedTile(item: i, isNew: _isNew(i)),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _isNew(FeedItem i) => _seenAt == null || i.at.isAfter(_seenAt!);
}

class _FeedTile extends StatelessWidget {
  final FeedItem item;
  final bool isNew;
  const _FeedTile({required this.item, required this.isNew});

  static (IconData, Color) _look(FeedKind kind) => switch (kind) {
        FeedKind.chat => (Icons.chat_bubble_outline, AppColors.accent),
        FeedKind.plan => (Icons.restaurant_menu, AppColors.success),
        FeedKind.weighIn => (Icons.monitor_weight_outlined, AppColors.water),
        FeedKind.meal => (Icons.schedule, AppColors.warning),
        FeedKind.order => (Icons.storefront_outlined, AppColors.protein),
        FeedKind.attention => (Icons.error_outline, AppColors.danger),
        FeedKind.gym => (Icons.fitness_center_outlined, AppColors.warning),
        FeedKind.subscription => (Icons.card_membership_outlined, AppColors.danger),
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (icon, color) = _look(item.kind);
    return BentoTile(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(icon, color: color, size: 38),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(item.title,
                    style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (isNew) ...[
                const SizedBox(width: AppSpace.sm),
                Pill(text: tr('Yangi'), color: AppColors.danger),
              ],
            ]),
            const SizedBox(height: 2),
            Text(
              item.body,
              style: t.bodySmall?.copyWith(color: AppColors.textMuted),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(feedTime(item.at), style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}

/// "5 daqiqa oldin", "Bugun 14:20", "Chorshanba, 17-sentabr"
String feedTime(DateTime at, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final diff = n.difference(at);
  if (diff.inMinutes.abs() < 1) return tr('Hozir');
  if (diff.inMinutes < 60 && !diff.isNegative) return trf('{0} daqiqa oldin', [diff.inMinutes]);
  final hhmm = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  final sameDay = at.year == n.year && at.month == n.month && at.day == n.day;
  if (sameDay) return trf('Bugun {0}', [hhmm]);
  final yesterday = n.subtract(const Duration(days: 1));
  final isYesterday =
      at.year == yesterday.year && at.month == yesterday.month && at.day == yesterday.day;
  if (isYesterday) return trf('Kecha {0}', [hhmm]);
  return '${uzDate(at)}, $hhmm';
}
