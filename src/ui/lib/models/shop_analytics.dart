import '../services/api/json_helpers.dart';

class ShopTotals {
  final int orders;
  final int units;
  final int revenue;
  final int profit;
  final int noCostOrders;

  const ShopTotals({
    this.orders = 0,
    this.units = 0,
    this.revenue = 0,
    this.profit = 0,
    this.noCostOrders = 0,
  });

  factory ShopTotals.fromJson(Map<String, dynamic> j) => ShopTotals(
        orders: jsonInt(j['orders']),
        units: jsonInt(j['units']),
        revenue: jsonInt(j['revenue']),
        profit: jsonInt(j['profit']),
        noCostOrders: jsonInt(j['no_cost_orders']),
      );
}

class TopProduct {
  final String productId;
  final String name;
  final String category;
  final String currency;
  final int units;
  final int revenue;
  final int profit;

  const TopProduct({
    required this.productId,
    required this.name,
    required this.category,
    required this.currency,
    required this.units,
    required this.revenue,
    required this.profit,
  });

  factory TopProduct.fromJson(Map<String, dynamic> j) => TopProduct(
        productId: jsonString(j['product_id']),
        name: jsonString(j['name']),
        category: jsonString(j['category']),
        currency: jsonString(j['currency']),
        units: jsonInt(j['units']),
        revenue: jsonInt(j['revenue']),
        profit: jsonInt(j['profit']),
      );
}

class WeekdaySales {
  final int weekday;
  final String currency;
  final int orders;
  final int revenue;

  const WeekdaySales({
    required this.weekday,
    required this.currency,
    required this.orders,
    required this.revenue,
  });

  factory WeekdaySales.fromJson(Map<String, dynamic> j) => WeekdaySales(
        weekday: jsonInt(j['weekday']),
        currency: jsonString(j['currency']),
        orders: jsonInt(j['orders']),
        revenue: jsonInt(j['revenue']),
      );
}

class ShopAnalytics {
  final String from;
  final String to;
  final Map<String, ShopTotals> totals;
  final List<TopProduct> topProducts;
  final List<WeekdaySales> byWeekday;

  const ShopAnalytics({
    required this.from,
    required this.to,
    required this.totals,
    required this.topProducts,
    required this.byWeekday,
  });

  factory ShopAnalytics.fromJson(Map<String, dynamic> j) {
    final raw = j['totals'];
    return ShopAnalytics(
      from: jsonString(j['from']),
      to: jsonString(j['to']),
      totals: {
        if (raw is Map)
          for (final e in raw.entries)
            if (e.value is Map)
              e.key.toString(): ShopTotals.fromJson(Map<String, dynamic>.from(e.value as Map)),
      },
      topProducts: [for (final r in jsonMaps(j['top_products'])) TopProduct.fromJson(r)],
      byWeekday: [for (final r in jsonMaps(j['by_weekday'])) WeekdaySales.fromJson(r)],
    );
  }

  List<String> get currencies {
    final keys = <String>{...totals.keys};
    final list = keys.toList()..sort();
    return list;
  }

  bool get isEmpty => totals.values.every((t) => t.orders == 0);

  List<TopProduct> topFor(String currency) => [
        for (final p in topProducts)
          if (p.currency == currency) p
      ];

  List<WeekdaySales> weekdaysFor(String currency) {
    final byDay = {
      for (final w in byWeekday)
        if (w.currency == currency) w.weekday: w
    };
    return [
      for (var d = 0; d < 7; d++)
        byDay[d] ?? WeekdaySales(weekday: d, currency: currency, orders: 0, revenue: 0),
    ];
  }
}
