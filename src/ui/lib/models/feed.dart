import '../l10n/tr.dart';
import 'gym.dart';
import 'models.dart';
import 'shop.dart';
import 'subscription.dart';

/// Ilova ichidagi bildirishnomalar ro'yxati ("Eslatma" bo'limi).
///
/// Bu yerda yangi ma'lumot saqlanmaydi — ro'yxat bazadagi narsalardan yig'iladi:
/// chat xabarlari, biriktirilgan reja, vazn muddati, bugungi mahallar, buyurtmalar.
/// Shuning uchun telefonda bildirishnoma o'chirilgan bo'lsa ham hammasi shu yerda ko'rinadi.

enum FeedKind { chat, plan, weighIn, meal, order, attention, gym, subscription }

class FeedItem {
  final FeedKind kind;
  final String title;
  final String body;
  final DateTime at;

  /// true — foydalanuvchidan amal kutilmoqda (vazn kiritish, javob berish)
  final bool action;

  const FeedItem({
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    this.action = false,
  });
}

/// Ro'yxatni vaqt bo'yicha (yangisi yuqorida) saralaydi va [limit] tagacha qisqartiradi
List<FeedItem> sortFeed(List<FeedItem> items, {int limit = 60}) {
  final list = [...items]..sort((a, b) => b.at.compareTo(a.at));
  return list.length > limit ? list.sublist(0, limit) : list;
}

/// Bugungi kun uchun "07:30" kabi vaqtni to'liq sanaga aylantiradi
DateTime? _todayAt(String hhmm, DateTime now) {
  final p = hhmm.split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
  if (h == null || m == null || h > 23 || m > 59) return null;
  return DateTime(now.year, now.month, now.day, h, m);
}

/// Shogird uchun bildirishnomalar
List<FeedItem> studentFeed({
  required AppUser user,
  required List<ChatMessage> messages,
  Plan? plan,
  List<WeightLog> weights = const [],
  List<ShopOrder> orders = const [],
  Set<int> doneMeals = const {},
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final items = <FeedItem>[];

  // 1. Trenerdan kelgan xabarlar
  for (final m in messages) {
    if (m.senderId == user.id) continue;
    items.add(FeedItem(
      kind: FeedKind.chat,
      title: tr('Trener xabar yozdi'),
      body: m.preview,
      at: m.createdAt,
    ));
  }

  // 2. Biriktirilgan reja
  if (plan != null && user.planAssignedAt != null) {
    items.add(FeedItem(
      kind: FeedKind.plan,
      title: tr('Yangi reja berildi'),
      body: plan.title,
      at: user.planAssignedAt!,
    ));
  }

  // 3. Haftalik vazn — muddat kelgan bo'lsa
  final last = weights.isEmpty ? null : weights.last;
  if (user.profileDone && WeightLog.canAdd(last, n)) {
    items.add(FeedItem(
      kind: FeedKind.weighIn,
      title: tr('Vazn kiritish vaqti keldi'),
      body: last == null
          ? tr("Birinchi o'lchov — ertalab, nahorga tortiling")
          : trf("Oxirgi o'lchovdan {0} kun o'tdi", [WeightLog.daysSince(last.date, n)]),
      at: last == null ? n : last.date.add(const Duration(days: weighInIntervalDays)),
      action: true,
    ));
  }

  // 3b. Abonement tugashi yaqinlashgan
  if (Subscription.isExpiringSoon(user.subscriptionExpiresAt, n)) {
    final left = Subscription.daysLeft(user.subscriptionExpiresAt, n);
    items.add(FeedItem(
      kind: FeedKind.subscription,
      title: left <= 0 ? tr('Abonement tugadi') : tr('Abonement tugashi yaqinlashdi'),
      body: left <= 0
          ? tr('Yangilash uchun trenerga murojaat qiling')
          : trf('{0} kundan keyin tugaydi', [left]),
      at: n,
      action: true,
    ));
  }

  // 4. Bugungi mahallar — vaqti o'tgan, lekin belgilanmagani
  if (plan != null && user.fitsPlan(plan)) {
    final meals = plan.mealsFor(n.weekday);
    for (var i = 0; i < meals.length; i++) {
      if (doneMeals.contains(i)) continue;
      final at = _todayAt(meals[i].time, n);
      if (at == null || at.isAfter(n)) continue;
      final names = meals[i].items.map((e) => e.name.split('(').first.trim()).take(3);
      items.add(FeedItem(
        kind: FeedKind.meal,
        title: trf("{0} vaqti o'tdi", [meals[i].title.isEmpty ? tr('Ovqat') : tr(meals[i].title)]),
        body: names.isEmpty ? tr('Belgilashni unutmang') : names.join(', '),
        at: at,
        action: true,
      ));
    }
  }

  // 5. Buyurtmalar
  for (final o in orders) {
    final at = o.createdAt;
    if (at == null) continue;
    items.add(FeedItem(
      kind: FeedKind.order,
      title: switch (o.status) {
        orderGiven => tr('Buyurtma berildi'),
        orderCanceled => tr('Buyurtma bekor qilindi'),
        _ => tr('Buyurtma kutilmoqda'),
      },
      body: '${o.title} × ${o.qty} — ${o.totalText}',
      at: at,
    ));
  }

  return sortFeed(items);
}

/// Trener uchun bildirishnomalar
List<FeedItem> trainerFeed({
  required AppUser trainer,
  required List<AppUser> clients,
  Map<String, List<ChatMessage>> messages = const {},
  List<ShopOrder> orders = const [],
  List<Gym> gyms = const [],
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final items = <FeedItem>[];
  final nameOf = {
    for (final c in clients) c.id: c.name.isEmpty ? tr('Shogird') : c.name,
  };

  // 1. Shogirdlardan kelgan xabarlar
  for (final e in messages.entries) {
    for (final m in e.value) {
      if (m.senderId != e.key) continue;
      items.add(FeedItem(
        kind: FeedKind.chat,
        title: nameOf[e.key] ?? tr('Shogird'),
        body: m.preview,
        at: m.createdAt,
      ));
    }
  }

  // 2. Buyurtmalar — yangisi amal talab qiladi
  for (final o in orders) {
    final at = o.createdAt;
    if (at == null) continue;
    items.add(FeedItem(
      kind: FeedKind.order,
      title: o.isNew ? tr('Yangi buyurtma') : trf('Buyurtma: {0}', [o.statusLabel.toLowerCase()]),
      body: '${o.clientName.isEmpty ? 'Shogird' : o.clientName} · '
          '${o.title} × ${o.qty}',
      at: at,
      action: o.isNew,
    ));
  }

  // 3. E'tibor: rejasiz shogirdlar
  final noPlan = clients.where((c) => c.planId == null).toList();
  if (noPlan.length == 1) {
    items.add(FeedItem(
      kind: FeedKind.attention,
      title: tr('Reja berilmagan'),
      body: trf("{0} — hali ovqatlanish rejasi yo'q", [nameOf[noPlan.first.id]]),
      at: n,
      action: true,
    ));
  } else if (noPlan.length > 1) {
    items.add(FeedItem(
      kind: FeedKind.attention,
      title: tr('Reja berilmagan'),
      body: trf("{0} ta shogirdda hali ovqatlanish rejasi yo'q", [noPlan.length]),
      at: n,
      action: true,
    ));
  }

  // 4. E'tibor: zal kunlarini tanlamagan shogirdlar
  for (final c in clients) {
    if (validGymDays(c.gymDays)) continue;
    items.add(FeedItem(
      kind: FeedKind.gym,
      title: tr('Zal kunlari tanlanmagan'),
      body: trf("{0} — mashg'ulot kunlarini tanlamagan", [nameOf[c.id]]),
      at: n.subtract(const Duration(seconds: 1)),
      action: true,
    ));
  }

  // 5. E'tibor: abonementi tugayotgan shogirdlar
  for (final c in clients) {
    if (!Subscription.isExpiringSoon(c.subscriptionExpiresAt, n)) continue;
    final left = Subscription.daysLeft(c.subscriptionExpiresAt, n);
    items.add(FeedItem(
      kind: FeedKind.subscription,
      title: tr('Abonement tugashi yaqinlashdi'),
      body:
          '${nameOf[c.id]} — ${left <= 0 ? tr('tugadi') : trf('{0} kundan keyin tugaydi', [left])}',
      at: n.subtract(const Duration(seconds: 2)),
      action: true,
    ));
  }

  return sortFeed(items);
}

/// Barmen uchun — faqat do'kon buyurtmalari
List<FeedItem> barmenFeed({List<ShopOrder> orders = const []}) {
  final items = <FeedItem>[];
  for (final o in orders) {
    final at = o.createdAt;
    if (at == null) continue;
    items.add(FeedItem(
      kind: FeedKind.order,
      title: o.isNew ? tr('Yangi buyurtma') : trf('Buyurtma: {0}', [o.statusLabel.toLowerCase()]),
      body: '${o.clientName.isEmpty ? 'Shogird' : o.clientName} · '
          '${o.title} × ${o.qty} — ${o.totalText}',
      at: at,
      action: o.isNew,
    ));
  }
  return sortFeed(items);
}

/// Yangi (ko'rilmagan) bildirishnomalar soni
int unreadCount(List<FeedItem> items, DateTime? lastSeen) {
  if (lastSeen == null) return items.length;
  return items.where((i) => i.at.isAfter(lastSeen)).length;
}
