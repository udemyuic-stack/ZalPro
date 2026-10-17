import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/shop_analytics.dart';
import 'package:kotta_qani_diet/screens/admin/shop_analytics_screen.dart';
import 'package:kotta_qani_diet/services/api/analytics_api.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';
import 'package:kotta_qani_diet/widgets/ui.dart';

import 'support/fake_api.dart';

ShopAnalytics sample({
  int noCost = 0,
  bool withUsd = false,
  bool empty = false,
}) {
  if (empty) {
    return const ShopAnalytics(from: '', to: '', totals: {}, topProducts: [], byWeekday: []);
  }
  return ShopAnalytics(
    from: '2026-09-18',
    to: '2026-10-17',
    totals: {
      'UZS':
          ShopTotals(orders: 12, units: 30, revenue: 1500000, profit: 400000, noCostOrders: noCost),
      if (withUsd) 'USD': const ShopTotals(orders: 2, units: 3, revenue: 90, profit: 30),
    },
    topProducts: [
      for (var i = 1; i <= 10; i++)
        TopProduct(
          productId: 'p$i',
          name: 'Juda uzun nomli sport ovqat mahsuloti raqami $i',
          category: 'food',
          currency: 'UZS',
          units: 20 - i,
          revenue: 100000 * (11 - i),
          profit: 20000 * (11 - i),
        ),
      if (withUsd)
        const TopProduct(
          productId: 'u1',
          name: 'Import protein',
          category: 'food',
          currency: 'USD',
          units: 3,
          revenue: 90,
          profit: 30,
        ),
    ],
    byWeekday: [
      for (var d = 0; d < 7; d++)
        WeekdaySales(weekday: d, currency: 'UZS', orders: d, revenue: d * 100000),
      if (withUsd)
        for (var d = 0; d < 7; d++)
          WeekdaySales(
              weekday: d, currency: 'USD', orders: d == 2 ? 2 : 0, revenue: d == 2 ? 90 : 0),
    ],
  );
}

Future<void> pump(
  WidgetTester tester,
  ShopAnalyticsLoader loader, {
  double width = 360,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: ShopAnalyticsScreen(loader: loader)));
  await tester.pump();
  await tester.pump();
}

void main() {
  test('ShopAnalytics.fromJson maps totals, products and weekdays', () {
    final a = ShopAnalytics.fromJson({
      'from': '2026-09-18',
      'to': '2026-10-17',
      'totals': {
        'UZS': {'orders': 2, 'units': 5, 'revenue': 100, 'profit': 40, 'no_cost_orders': 1},
      },
      'top_products': [
        {
          'product_id': 'p',
          'name': 'Protein',
          'category': 'food',
          'currency': 'UZS',
          'units': 5,
          'revenue': 100,
          'profit': 40,
        },
      ],
      'by_weekday': [
        {'weekday': 0, 'currency': 'UZS', 'orders': 2, 'revenue': 100},
      ],
    });
    expect(a.totals['UZS']!.noCostOrders, 1);
    expect(a.topProducts.single.name, 'Protein');
    expect(a.weekdaysFor('UZS'), hasLength(7));
    expect(a.weekdaysFor('UZS').first.revenue, 100);
    expect(a.isEmpty, isFalse);
    expect(ShopAnalytics.fromJson({}).isEmpty, isTrue);
  });

  test('AnalyticsApi GETs /v1/analytics/shop with from and to', () async {
    final adapter = FakeAdapter((o) async => jsonBody({
          'from': '2026-10-01',
          'to': '2026-10-17',
          'totals': {},
          'top_products': [],
          'by_weekday': [],
        }, 200));
    final client = ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter);
    final api = AnalyticsApi(client, bus: ChangeBus(), activity: PollActivity());
    final data = await api.shop(DateTime(2026, 10, 1), DateTime(2026, 10, 17));
    final call = adapter.calls.last;
    expect(call.path, '/v1/analytics/shop');
    expect(call.queryParameters, {'from': '2026-10-01', 'to': '2026-10-17'});
    expect(data.isEmpty, isTrue);
  });

  testWidgets('shows totals, top list and weekday bars', (tester) async {
    await pump(tester, (f, t) async => sample());
    expect(find.text('Juda uzun nomli sport ovqat mahsuloti raqami 1'), findsOneWidget);
    expect(find.text('Du'), findsOneWidget);
    expect(find.text('Ya'), findsOneWidget);
    expect(find.byKey(const Key('bar-UZS-6')), findsOneWidget);
    final top = tester.getSize(find.byKey(const Key('bar-UZS-6'))).width;
    final mid = tester.getSize(find.byKey(const Key('bar-UZS-3'))).width;
    expect(top, greaterThan(mid));
    expect(find.byKey(const Key('no-cost-UZS')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('period switch reloads with a different window', (tester) async {
    final spans = <int>[];
    await pump(tester, (f, t) async {
      spans.add(t.difference(f).inDays + 1);
      return sample();
    });
    expect(spans, [30]);
    await tester.tap(find.byKey(const Key('period-7')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('period-90')));
    await tester.pump();
    await tester.pump();
    expect(spans, [30, 7, 90]);
  });

  testWidgets('empty state when there are no sales', (tester) async {
    await pump(tester, (f, t) async => sample(empty: true));
    expect(find.text("Bu davrda sotuv yo'q"), findsOneWidget);
    expect(find.byKey(const Key('bar-UZS-0')), findsNothing);
  });

  testWidgets('no-cost warning appears only when no_cost_orders > 0', (tester) async {
    await pump(tester, (f, t) async => sample(noCost: 4));
    expect(find.byKey(const Key('no-cost-UZS')), findsOneWidget);
    expect(find.text("Tannarxi yo'q: 4 ta buyurtma"), findsOneWidget);
  });

  testWidgets('two currencies get separate sections', (tester) async {
    await pump(tester, (f, t) async => sample(withUsd: true));
    expect(find.byKey(const Key('section-UZS')), findsOneWidget);
    expect(find.byKey(const Key('section-USD')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Import protein'), 300,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Import protein'), findsOneWidget);
  });

  testWidgets('error state is shown when loading fails', (tester) async {
    await pump(tester, (f, t) async => throw Exception('boom'));
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('period-30')), findsOneWidget);
  });

  testWidgets('no overflow at 360 px with long names and two currencies', (tester) async {
    await pump(tester, (f, t) async => sample(noCost: 3, withUsd: true));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -2000));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
