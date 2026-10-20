import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/payment.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/api_error.dart';
import 'package:kotta_qani_diet/services/api/billing_api.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';
import 'package:kotta_qani_diet/theme.dart';
import 'package:kotta_qani_diet/widgets/buy_subscription_sheet.dart';
import 'package:kotta_qani_diet/widgets/ui.dart';

import 'support/fake_api.dart';

Map<String, dynamic> orderJson(String status, {String? url, String? expires}) => {
      'id': 'o1',
      'provider': 'payme',
      'months': 3,
      'amount': 1500000,
      'currency': 'UZS',
      'status': status,
      'created_at': '2026-10-20T10:00:00Z',
      'paid_at': status == 'paid' ? '2026-10-20T10:01:00Z' : null,
      'expires_at': expires,
      'pay_url': url,
    };

const optionsJson = {
  'providers': ['payme', 'click'],
  'plans': [
    {'months': 1, 'price': 500000, 'currency': 'UZS'},
    {'months': 3, 'price': 1500000, 'currency': 'UZS'},
  ],
};

void main() {
  group('models', () {
    test('PaymentOptions.fromJson', () {
      final o = PaymentOptions.fromJson(optionsJson);
      expect(o.providers, ['payme', 'click']);
      expect(o.plans.map((p) => p.months), [1, 3]);
      expect(o.plans.last.price, 1500000);
      expect(o.available, true);
      expect(const PaymentOptions().available, false);
      expect(const PaymentOptions(providers: ['payme']).available, false);
    });

    test('PaymentOrder status flags', () {
      final pending = PaymentOrder.fromJson(orderJson('pending', url: 'https://pay'));
      expect(pending.isFinal, false);
      expect(pending.payUrl, 'https://pay');
      final created = PaymentOrder.fromJson(orderJson('created'));
      expect(created.isFinal, false);
      final paid = PaymentOrder.fromJson(orderJson('paid', expires: '2027-01-20T00:00:00Z'));
      expect(paid.isPaid, true);
      expect(paid.isFinal, true);
      expect(paid.paidAt, isNotNull);
      expect(paid.expiresAt, isNotNull);
      expect(PaymentOrder.fromJson(orderJson('canceled')).isFinal, true);
      expect(PaymentOrder.fromJson(const {}).status, 'pending');
    });
  });

  group('BillingApi payments', () {
    late FakeAdapter adapter;
    late BillingApi api;
    late List<String> touched;
    Future<ResponseBody> Function(RequestOptions) respond = (o) async => jsonBody({}, 200);

    setUp(() {
      respond = (o) async => jsonBody({}, 200);
      adapter = FakeAdapter((o) => respond(o));
      final client = ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter);
      final bus = ChangeBus();
      touched = [];
      bus.changes.listen(touched.add);
      api = BillingApi(client, bus: bus, activity: PollActivity());
    });

    test('paymentOptions: GET /v1/payments/options', () async {
      respond = (o) async => jsonBody(optionsJson, 200);
      final options = await api.paymentOptions();
      expect(adapter.calls.last.path, '/v1/payments/options');
      expect(options.providers, ['payme', 'click']);
    });

    test('createPaymentOrder: sends only months and provider, never a price', () async {
      respond = (o) async => jsonBody(orderJson('pending', url: 'https://pay'), 201);
      final order = await api.createPaymentOrder(3, 'payme');
      final call = adapter.calls.last;
      expect(call.method, 'POST');
      expect(call.path, '/v1/payments/orders');
      expect(call.data, {'months': 3, 'provider': 'payme'});
      expect(order.payUrl, 'https://pay');
    });

    test('createPaymentOrder: provider_unavailable surfaces as ApiException', () async {
      respond = (o) async => jsonBody({
            'detail': {'code': 'provider_unavailable', 'message': 'x'}
          }, 503);
      await expectLater(
        api.createPaymentOrder(1, 'click'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'provider_unavailable')),
      );
    });

    test('watchPaymentOrder: polls until paid, then refreshes subscription streams', () async {
      final statuses = ['pending', 'created', 'paid'];
      respond = (o) async => jsonBody(orderJson(statuses.removeAt(0)), 200);
      final seen = await api
          .watchPaymentOrder('u1', 'o1', every: const Duration(milliseconds: 1))
          .map((o) => o.status)
          .toList();
      expect(seen, ['pending', 'created', 'paid']);
      expect(adapter.calls.every((c) => c.path == '/v1/payments/orders/o1'), true);
      expect(touched,
          containsAll(['subscriptions', 'subscriptions:u1', 'memberships', 'users', 'user:u1']));
    });

    test('watchPaymentOrder: canceled ends the stream without refreshing', () async {
      respond = (o) async => jsonBody(orderJson('canceled'), 200);
      final seen = await api
          .watchPaymentOrder('u1', 'o1', every: const Duration(milliseconds: 1))
          .map((o) => o.status)
          .toList();
      expect(seen, ['canceled']);
      expect(touched, isEmpty);
    });

    test('watchPaymentOrder: network errors are skipped, other errors are raised', () async {
      var n = 0;
      respond = (o) async {
        n++;
        if (n == 1) {
          throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
        }
        return jsonBody(orderJson('paid'), 200);
      };
      final seen = await api
          .watchPaymentOrder('u1', 'o1', every: const Duration(milliseconds: 1))
          .map((o) => o.status)
          .toList();
      expect(seen, ['paid']);

      respond = (o) async => jsonBody({
            'detail': {'code': 'not_found', 'message': 'x'}
          }, 404);
      await expectLater(
        api.watchPaymentOrder('u1', 'zz', every: const Duration(milliseconds: 1)).toList(),
        throwsA(isA<ApiException>()),
      );
    });

    test('watchPaymentOrder: gives up after the timeout', () async {
      respond = (o) async => jsonBody(orderJson('created'), 200);
      final seen = await api
          .watchPaymentOrder('u1', 'o1',
              every: const Duration(milliseconds: 5), timeout: const Duration(milliseconds: 40))
          .toList();
      expect(seen, isNotEmpty);
      expect(seen.every((o) => !o.isFinal), true);
      expect(touched, isEmpty);
    });
  });

  group('BuySubscriptionBody', () {
    late StreamController<PaymentOrder> watch;
    late List<(int, String)> created;
    late List<String> opened;
    bool openOk = true;

    setUp(() {
      watch = StreamController<PaymentOrder>();
      created = [];
      opened = [];
      openOk = true;
    });

    tearDown(() {
      if (!watch.isClosed) unawaited(watch.close());
    });

    Widget body({
      Future<PaymentOptions> Function()? options,
      Future<PaymentOrder> Function(String id)? fetchOrder,
    }) {
      return BuySubscriptionBody(
        uid: 'u1',
        loadOptions: options ?? () async => PaymentOptions.fromJson(optionsJson),
        createOrder: (months, provider) async {
          created.add((months, provider));
          return PaymentOrder.fromJson(
              orderJson('pending', url: 'https://pay.test/$provider/$months'));
        },
        watchOrder: (uid, id) => watch.stream,
        fetchOrder: fetchOrder,
        openUrl: (url) async {
          opened.add(url);
          return openOk;
        },
      );
    }

    Widget host({
      Future<PaymentOptions> Function()? options,
      Future<PaymentOrder> Function(String id)? fetchOrder,
    }) =>
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: body(options: options, fetchOrder: fetchOrder)),
        );

    testWidgets('lists plans and providers, pays with the chosen plan and provider', (t) async {
      await t.pumpWidget(host());
      await t.pump();
      expect(find.byKey(const ValueKey('plan:1')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan:3')), findsOneWidget);
      expect(find.byKey(const ValueKey('pay:payme')), findsOneWidget);
      expect(find.byKey(const ValueKey('pay:click')), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('plan:3')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('pay:click')));
      await t.pump();
      await t.pump();

      expect(created, [(3, 'click')]);
      expect(opened, ['https://pay.test/click/3']);
      expect(find.byKey(const ValueKey('reopen')), findsOneWidget);
    });

    testWidgets('defaults to the first plan', (t) async {
      await t.pumpWidget(host());
      await t.pump();
      await t.tap(find.byKey(const ValueKey('pay:payme')));
      await t.pump();
      await t.pump();
      expect(created, [(1, 'payme')]);
    });

    testWidgets('paid status shows success and closes with true', (t) async {
      bool? result;
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showSheet<bool>(context, body()),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('pay:payme')));
      await t.pump();
      await t.pump();
      watch.add(PaymentOrder.fromJson(orderJson('paid', expires: '2027-01-20T00:00:00Z')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const ValueKey('done')), findsOneWidget);
      expect(find.textContaining('20.01.2027'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('done')));
      await t.pumpAndSettle();
      expect(result, true);
    });

    testWidgets('canceled status offers a retry that returns to the plans', (t) async {
      await t.pumpWidget(host());
      await t.pump();
      await t.tap(find.byKey(const ValueKey('pay:payme')));
      await t.pump();
      await t.pump();
      watch.add(PaymentOrder.fromJson(orderJson('canceled')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const ValueKey('retry')), findsOneWidget);
      expect(find.byKey(const ValueKey('pay:payme')), findsNothing);
      await t.tap(find.byKey(const ValueKey('retry')));
      await t.pump();
      expect(find.byKey(const ValueKey('pay:payme')), findsOneWidget);
    });

    testWidgets('manual status check picks up a payment the stream missed', (t) async {
      var fetched = 0;
      await t.pumpWidget(host(fetchOrder: (id) async {
        fetched++;
        return PaymentOrder.fromJson(orderJson('paid', expires: '2027-01-20T00:00:00Z'));
      }));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('pay:payme')));
      await t.pump();
      await t.pump();
      await t.tap(find.byKey(const ValueKey('check')));
      await t.pump();
      await t.pump();
      expect(fetched, 1);
      expect(find.byKey(const ValueKey('done')), findsOneWidget);
    });

    testWidgets('a stream that ends without result shows the stale state', (t) async {
      await t.pumpWidget(host());
      await t.pump();
      await t.tap(find.byKey(const ValueKey('pay:payme')));
      await t.pump();
      await t.pump();
      unawaited(watch.close());
      await t.pump();
      await t.pump();
      expect(find.byKey(const ValueKey('check')), findsOneWidget);
      expect(find.byKey(const ValueKey('reopen')), findsNothing);
    });

    testWidgets('resuming the app re-checks the order', (t) async {
      var fetched = 0;
      await t.pumpWidget(host(fetchOrder: (id) async {
        fetched++;
        return PaymentOrder.fromJson(orderJson('created'));
      }));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('pay:payme')));
      await t.pump();
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(fetched, 1);
    });

    testWidgets('failing to open the payment page keeps waiting and tells the user', (t) async {
      openOk = false;
      await t.pumpWidget(host());
      await t.pump();
      await t.tap(find.byKey(const ValueKey('pay:payme')));
      await t.pump();
      await t.pump();
      expect(find.text("To'lov sahifasini ochib bo'lmadi"), findsOneWidget);
      expect(find.byKey(const ValueKey('reopen')), findsOneWidget);
    });

    testWidgets('no providers: explains and offers no pay buttons', (t) async {
      await t.pumpWidget(host(options: () async => const PaymentOptions()));
      await t.pump();
      expect(find.textContaining('hozircha ulanmagan'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('options error shows retry', (t) async {
      var calls = 0;
      await t.pumpWidget(host(options: () async {
        calls++;
        if (calls == 1) throw const ApiException(code: ApiException.networkCode, message: '');
        return PaymentOptions.fromJson(optionsJson);
      }));
      await t.pump();
      await t.pump();
      expect(find.text('Internet aloqasini tekshiring'), findsOneWidget);
      await t.tap(find.text('Qayta urinish'));
      await t.pump();
      await t.pump();
      expect(find.byKey(const ValueKey('pay:payme')), findsOneWidget);
    });
  });
}
