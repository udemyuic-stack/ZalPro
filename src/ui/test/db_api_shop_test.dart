import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/shop.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/api_error.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';
import 'package:kotta_qani_diet/services/api/shop_api.dart';

import 'support/fake_api.dart';

Map<String, dynamic> orderJson(String id, {String client = 'u1', String gym = 'g1'}) => {
      'id': id,
      'client_id': client,
      'client_name': 'Ali',
      'client_phone': '998901234567',
      'trainer_id': 't1',
      'gym_id': gym,
      'product_id': 'p1',
      'product_name': 'Protein',
      'category': 'Protein',
      'size': '',
      'color': '',
      'price': 100000,
      'currency': 'UZS',
      'qty': 2,
      'status': 'new',
      'created_at': '2026-05-01T09:00:00Z',
      'updated_at': null,
      'given_by': '',
      'given_at': null,
      'total': 200000,
    };

void main() {
  late FakeAdapter adapter;
  late ShopApi api;
  late ChangeBus bus;
  late List<String> touched;
  Future<ResponseBody> Function(RequestOptions) respond = (o) async => jsonBody({}, 200);

  setUp(() {
    respond = (o) async => jsonBody({}, 200);
    adapter = FakeAdapter((o) => respond(o));
    final client = ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter);
    bus = ChangeBus();
    touched = [];
    bus.changes.listen(touched.add);
    api = ShopApi(client, bus: bus, activity: PollActivity(), now: () => DateTime(2026, 5, 10, 15));
  });

  RequestOptions last() => adapter.calls.last;

  test('products: null cost_price becomes 0 and size_stock maps', () async {
    respond = (o) async => jsonBody([
          {
            'id': 'p1',
            'category': 'Forma',
            'name': 'Futbolka',
            'price': 90000,
            'currency': 'UZS',
            'stock': 5,
            'sizes': ['M', 'L'],
            'size_stock': {'M': 2, 'L': 3},
            'cost_price': null,
            'active': true,
          },
        ], 200);
    final list = await api.products().first;
    expect(last().path, '/v1/products');
    expect(list.single.costPrice, 0);
    expect(list.single.sizeStock, {'M': 2, 'L': 3});
    expect(list.single.totalStock, 5);
  });

  test('saveProduct: sized product sends size_stock and no stock', () async {
    const p = Product(
      category: 'Forma',
      name: 'Futbolka',
      price: 90000,
      sizes: ['M', 'L'],
      sizeStock: {'M': 2, 'L': 3, 'XL': 9},
      stock: 99,
    );
    await api.saveProduct(p);
    expect(last().method, 'POST');
    expect(last().path, '/v1/products');
    final body = last().data as Map<String, dynamic>;
    expect(body.containsKey('stock'), isFalse);
    expect(body['size_stock'], {'M': 2, 'L': 3});
    expect(body['cost_price'], 0);
    expect(body['name_ru'], '');
    expect(touched, ['products']);
  });

  test('saveProduct: plain product sends stock and empty size_stock', () async {
    const p = Product(category: 'Protein', name: 'Whey', price: 1000, stock: 7);
    await api.saveProduct(p);
    final body = last().data as Map<String, dynamic>;
    expect(body['stock'], 7);
    expect(body['size_stock'], <String, dynamic>{});
  });

  test('saveProduct: existing id PATCHes', () async {
    const p = Product(id: 'p9', category: 'Protein', name: 'Whey', price: 1000, stock: 7);
    await api.saveProduct(p);
    expect(last().method, 'PATCH');
    expect(last().path, '/v1/products/p9');
  });

  test('deleteProduct: DELETE', () async {
    respond = (o) async => ResponseBody.fromString('', 204);
    await api.deleteProduct('p9');
    expect(last().method, 'DELETE');
    expect(last().path, '/v1/products/p9');
    expect(touched, ['products']);
  });

  test('myOrders: sends a 400-day window and keeps only own orders', () async {
    respond = (o) async => jsonBody([orderJson('o1'), orderJson('o2', client: 'other')], 200);
    final list = await api.myOrders('u1').first;
    expect(last().path, '/v1/orders');
    expect(last().queryParameters['to'], '2026-05-11');
    expect(last().queryParameters['from'], '2025-04-07');
    final from = DateTime.parse(last().queryParameters['from'] as String);
    final to = DateTime.parse(last().queryParameters['to'] as String);
    expect(to.difference(from).inDays + 1, 400);
    expect(list.map((o) => o.id), ['o1']);
  });

  test('allOrders: owner sends no window', () async {
    respond = (o) async => jsonBody([orderJson('o1')], 200);
    final list = await api.allOrders().first;
    expect(last().queryParameters.containsKey('from'), isFalse);
    expect(last().queryParameters.containsKey('to'), isFalse);
    expect(list.length, 1);
  });

  test('ordersOf and gymOrders filter by trainer and gym', () async {
    respond = (o) async => jsonBody([orderJson('o1'), orderJson('o2', gym: 'g2')], 200);
    expect((await api.ordersOf('t1').first).length, 2);
    expect((await api.ordersOf('zz').first), isEmpty);
    expect((await api.gymOrders('g2').first).map((o) => o.id), ['o2']);
  });

  test('gymOrders: empty gym makes no request', () async {
    expect(await api.gymOrders('').first, isEmpty);
    expect(await api.gymOrders(null).first, isEmpty);
    expect(adapter.calls, isEmpty);
  });

  test('createOrder: POST with exactly four fields and no chat call', () async {
    respond = (o) async => jsonBody(orderJson('o1'), 201);
    await api.createOrder('p1', 2, size: 'M', color: 'sariq');
    expect(adapter.calls.length, 1);
    expect(last().method, 'POST');
    expect(last().path, '/v1/orders');
    expect(last().data, {'product_id': 'p1', 'qty': 2, 'size': 'M', 'color': 'sariq'});
    expect(touched, ['orders']);
  });

  test('setOrderStatus: PATCH status only, touches orders and products', () async {
    respond = (o) async => jsonBody(orderJson('o1'), 200);
    await api.setOrderStatus('o1', orderGiven);
    expect(adapter.calls.length, 1);
    expect(last().method, 'PATCH');
    expect(last().path, '/v1/orders/o1/status');
    expect(last().data, {'status': 'given'});
    expect(touched, ['orders', 'products']);
  });

  test('setOrderStatus: 409 insufficient_stock surfaces, no touch, Uzbek text', () async {
    respond = (o) async => jsonBody({
          'detail': {'code': 'insufficient_stock', 'message': 'Omborda tovar yetarli emas'},
        }, 409);
    Object? error;
    try {
      await api.setOrderStatus('o1', orderGiven);
    } catch (e) {
      error = e;
    }
    expect(error, isA<ApiException>());
    expect((error as ApiException).code, 'insufficient_stock');
    expect(touched, isEmpty);
    expect(apiErrorText(error), 'Omborda tovar yetarli emas');
  });

  test('apiErrorText: status transition and missing product', () {
    const a = ApiException(code: 'invalid_status_transition', message: 'x', status: 409);
    const b = ApiException(code: 'product_missing', message: 'x', status: 409);
    expect(apiErrorText(a), "Buyurtma holatini o'zgartirib bo'lmaydi");
    expect(apiErrorText(b), "Tovar topilmadi, buyurtmani topshirib bo'lmaydi");
  });
}
