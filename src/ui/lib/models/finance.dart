import 'shop.dart';
import 'subscription.dart';

/// Bosh admin uchun oylik moliyaviy hisobot: abonement tushumi, do'kon tushumi va foydasi.
/// Sof hisob — Firestore'ga bog'liq emas, shuning uchun to'liq test qilinadi.
class MonthlyReport {
  /// Shu oyda to'langan abonementlar soni va valyuta bo'yicha summasi
  final int subsCount;
  final Map<String, int> subsSums;

  /// Shu oyda berilgan buyurtmalar soni (dona emas — buyurtma) va summasi
  final int ordersCount;
  final Map<String, int> shopSums;

  /// Do'kon foydasi: Σ (sotilgan narx − hozirgi tan narx) × dona, valyuta bo'yicha
  final Map<String, int> profit;

  /// Tan narxi kiritilmagan tovarlar bo'yicha buyurtmalar — foydaga qo'shilmagan
  final int noCostOrders;

  const MonthlyReport({
    this.subsCount = 0,
    this.subsSums = const {},
    this.ordersCount = 0,
    this.shopSums = const {},
    this.profit = const {},
    this.noCostOrders = 0,
  });

  /// Jami tushum (abonement + do'kon), valyuta bo'yicha
  Map<String, int> get income {
    final r = <String, int>{...subsSums};
    shopSums.forEach((k, v) => r[k] = (r[k] ?? 0) + v);
    return r;
  }

  /// Sana shu oyga tushadimi (oyning 1-kuni 00:00 dan keyingi oyning 1-kuni 00:00 gacha)
  static bool inMonth(DateTime? d, DateTime month) {
    if (d == null) return false;
    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1);
    return !d.isBefore(from) && d.isBefore(to);
  }

  /// Abonement qaysi oyga yoziladi: to'langan sana, bo'lmasa qo'shilgan, bo'lmasa boshlanish
  static DateTime paidAt(Subscription s) => s.paidDate ?? s.createdAt ?? s.startDate;

  static void _add(Map<String, int> m, String k, int v) => m[k] = (m[k] ?? 0) + v;

  /// [products] — id bo'yicha (tan narx shu yerdan olinadi)
  static MonthlyReport build(
    DateTime month, {
    List<Subscription> subs = const [],
    List<ShopOrder> orders = const [],
    Map<String, Product> products = const {},
  }) {
    final subsSums = <String, int>{};
    var subsCount = 0;
    for (final s in subs) {
      if (!inMonth(paidAt(s), month)) continue;
      subsCount++;
      _add(subsSums, s.currency, s.price);
    }

    final shopSums = <String, int>{};
    final profit = <String, int>{};
    var ordersCount = 0, noCost = 0;
    for (final o in orders) {
      if (!o.isGiven || !inMonth(SalesReport.soldAt(o), month)) continue;
      ordersCount++;
      _add(shopSums, o.currency, o.total);
      final cost = products[o.productId]?.costPrice ?? 0;
      if (cost > 0) {
        _add(profit, o.currency, (o.price - cost) * o.qty);
      } else {
        noCost++;
      }
    }

    return MonthlyReport(
      subsCount: subsCount,
      subsSums: subsSums,
      ordersCount: ordersCount,
      shopSums: shopSums,
      profit: profit,
      noCostOrders: noCost,
    );
  }

  /// Trenerlar kesimida: har trenerning shogirdlari soni va shu oyda ular to'lagan abonement.
  /// [subs] — (shogird uid, abonement); [clientTrainer] — shogird uid -> trener uid.
  /// Treneri yo'q shogirdlar '' kaliti ostida yig'iladi.
  static Map<String, TrainerShare> byTrainer(
    DateTime month, {
    List<(String, Subscription)> subs = const [],
    Map<String, String> clientTrainer = const {},
  }) {
    final clients = <String, int>{};
    for (final t in clientTrainer.values) {
      clients[t] = (clients[t] ?? 0) + 1;
    }
    final count = <String, int>{};
    final sums = <String, Map<String, int>>{};
    for (final (uid, s) in subs) {
      if (!inMonth(paidAt(s), month)) continue;
      final t = clientTrainer[uid] ?? '';
      count[t] = (count[t] ?? 0) + 1;
      _add(sums.putIfAbsent(t, () => {}), s.currency, s.price);
    }
    return {
      for (final t in {...clients.keys, ...count.keys})
        t: TrainerShare(
          clients: clients[t] ?? 0,
          subsCount: count[t] ?? 0,
          sums: sums[t] ?? const {},
        ),
    };
  }

  /// Ko'rsatish uchun: "450 000 so'm · 70 $" (bo'sh bo'lsa "0 so'm")
  static String money(Map<String, int> sums) =>
      sums.isEmpty ? fmtMoney(0) : sums.entries.map((e) => fmtMoney(e.value, e.key)).join(' · ');
}

/// Bitta trenerning oylik ko'rsatkichi: shogirdlari, sotilgan abonementlar va ulardan ulushi
class TrainerShare {
  final int clients, subsCount;

  /// Shogirdlari shu oyda to'lagan abonement summasi, valyuta bo'yicha
  final Map<String, int> sums;
  const TrainerShare({this.clients = 0, this.subsCount = 0, this.sums = const {}});

  /// Trener ulushi: tushumning [percent] foizi (butun songa yaxlitlanadi)
  Map<String, int> share(int percent) =>
      sums.map((k, v) => MapEntry(k, (v * percent / 100).round()));
}
