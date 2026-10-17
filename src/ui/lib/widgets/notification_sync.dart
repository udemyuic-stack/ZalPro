import 'dart:async';
import 'package:flutter/widgets.dart';
import '../l10n/tr.dart';
import '../models/models.dart';
import '../services/db.dart';
import '../services/notifications.dart';
import '../services/settings.dart';

/// Ilova orqa fonda (yig'ilgan) bo'lsa true — shunda lokal bildirishnoma ko'rsatiladi.
/// Ilova ekranda ochiq bo'lsa foydalanuvchi o'zi ko'rib turibdi, bezovta qilinmaydi.
bool _inBackground() =>
    WidgetsBinding.instance.lifecycleState != null &&
    WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;

/// Shogird: ovqat va vazn eslatmalarini rejalashtiradi, yangi reja va trener xabarini bildiradi
class StudentNotificationSync extends StatefulWidget {
  final AppUser user;
  final Widget child;
  const StudentNotificationSync({super.key, required this.user, required this.child});

  @override
  State<StudentNotificationSync> createState() => _StudentNotificationSyncState();
}

class _StudentNotificationSyncState extends State<StudentNotificationSync> {
  StreamSubscription<Plan?>? _planSub;
  StreamSubscription<List<WeightLog>>? _weightSub;
  StreamSubscription<List<(String, ChatMessage)>>? _chatSub;
  Plan? _plan;
  DateTime? _lastWeighIn;
  Set<String>? _seenMessages; // birinchi yuklanishdagi eski xabarlar bildirilmaydi

  @override
  void initState() {
    super.initState();
    _start();
    AppSettings.notifChanged.addListener(_reschedule);
  }

  Future<void> _start() async {
    await Notifications.init();
    await Notifications.requestPermission();
    _listenPlan(widget.user.planId);
    _weightSub = Db.weights(widget.user.id).listen((logs) {
      _lastWeighIn = logs.isEmpty ? null : logs.last.date;
      Notifications.scheduleWeighIn(_lastWeighIn);
    });
    _chatSub = Db.messageEvents(widget.user.id).listen(_onMessages);
  }

  void _listenPlan(String? planId) {
    _planSub?.cancel();
    _plan = null;
    if (planId == null) {
      Notifications.scheduleMeals(null);
      return;
    }
    _planSub = Db.plan(planId).listen((p) {
      _plan = p;
      // bloklangan (maqsadga mos kelmaydigan) reja uchun eslatma yo'q
      Notifications.scheduleMeals(p != null && widget.user.fitsPlan(p) ? p : null);
    });
  }

  void _reschedule() {
    final p = _plan;
    Notifications.scheduleMeals(p != null && widget.user.fitsPlan(p) ? p : null);
    Notifications.scheduleWeighIn(_lastWeighIn);
  }

  void _onMessages(List<(String, ChatMessage)> msgs) {
    final seen = _seenMessages;
    if (seen == null) {
      _seenMessages = msgs.map((m) => m.$1).toSet();
      return;
    }
    for (final (id, m) in msgs) {
      if (!seen.add(id)) continue;
      if (m.senderId == widget.user.id) continue;
      if (AppSettings.chatNotifications && _inBackground()) {
        Notifications.showNow('msg-$id', tr('Treneringizdan xabar'), m.preview);
      }
    }
  }

  @override
  void didUpdateWidget(StudentNotificationSync old) {
    super.didUpdateWidget(old);
    final newPlan = widget.user.planId;
    if (old.user.planId != newPlan) {
      _listenPlan(newPlan);
      if (newPlan != null && AppSettings.planNotifications && _inBackground()) {
        Notifications.showNow('plan-$newPlan', tr('Yangi reja biriktirildi'),
            tr("Trener sizga ovqatlanish rejasini berdi — 'Bugun' bo'limida ko'ring"));
      }
    } else if (old.user.goal != widget.user.goal) {
      _reschedule();
    }
  }

  @override
  void dispose() {
    AppSettings.notifChanged.removeListener(_reschedule);
    _planSub?.cancel();
    _weightSub?.cancel();
    _chatSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Trener: o'z shogirdlaridan kelgan yangi xabarlarni bildiradi
class TrainerNotificationSync extends StatefulWidget {
  final AppUser trainer;
  final Widget child;
  const TrainerNotificationSync({super.key, required this.trainer, required this.child});

  @override
  State<TrainerNotificationSync> createState() => _TrainerNotificationSyncState();
}

class _TrainerNotificationSyncState extends State<TrainerNotificationSync> {
  StreamSubscription<List<AppUser>>? _clientsSub;
  final _chatSubs = <String, StreamSubscription<List<(String, ChatMessage)>>>{};
  final _seen = <String, Set<String>>{};
  final _names = <String, String>{};

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Notifications.init();
    await Notifications.requestPermission();
    _clientsSub = Db.clientsOf(widget.trainer.id).listen((clients) {
      final ids = clients.map((c) => c.id).toSet();
      for (final c in clients) {
        _names[c.id] = c.name.isEmpty ? tr('Shogird') : c.name;
        _chatSubs.putIfAbsent(
          c.id,
          () => Db.messageEvents(c.id).listen((msgs) => _onMessages(c.id, msgs)),
        );
      }
      for (final gone in _chatSubs.keys.where((k) => !ids.contains(k)).toList()) {
        _chatSubs.remove(gone)?.cancel();
        _seen.remove(gone);
      }
    });
  }

  void _onMessages(String clientId, List<(String, ChatMessage)> msgs) {
    final seen = _seen[clientId];
    if (seen == null) {
      _seen[clientId] = msgs.map((m) => m.$1).toSet();
      return;
    }
    for (final (id, m) in msgs) {
      if (!seen.add(id)) continue;
      // faqat shogird yozgan xabar (trenerning o'zi va boshqa xodimlarniki emas)
      if (m.senderId != clientId) continue;
      if (AppSettings.chatNotifications && _inBackground()) {
        Notifications.showNow('msg-$id', _names[clientId] ?? tr('Shogird'), m.preview);
      }
    }
  }

  @override
  void dispose() {
    _clientsSub?.cancel();
    for (final s in _chatSubs.values) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
