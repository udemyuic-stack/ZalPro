import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/api_error.dart';
import 'package:kotta_qani_diet/services/api/api_service.dart';
import 'package:kotta_qani_diet/services/api/catalog_api.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';
import 'package:kotta_qani_diet/services/api/shop_api.dart';

import 'support/fake_api.dart';

void main() {
  late FakeAdapter adapter;
  late CatalogApi catalog;
  late ShopApi shop;
  late List<String> touched;
  Future<ResponseBody> Function(RequestOptions) respond = (o) async => jsonBody({}, 200);

  setUp(() {
    respond = (o) async => jsonBody({}, 200);
    adapter = FakeAdapter((o) => respond(o));
    final client = ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter);
    client.setAppVersion('1.0.0+7');
    final bus = ChangeBus();
    touched = [];
    bus.changes.listen(touched.add);
    catalog = CatalogApi(client, bus: bus, activity: PollActivity());
    shop = ShopApi(client, bus: bus, activity: PollActivity());
  });

  test('uploadFoodImage: slot, direct PUT with declared type, confirm, returns Food', () async {
    respond = (o) async {
      if (o.path == '/v1/foods/f1/image/upload-url') {
        return jsonBody(
            {'key': 'images/foods/f1/a.png', 'upload_url': 'https://r2.test/p?s=1'}, 201);
      }
      if (o.uri.host == 'r2.test') return ResponseBody.fromString('', 200);
      return jsonBody({'id': 'f1', 'name': 'Olma', 'image_url': 'https://cdn/a.png'}, 200);
    };
    final food = await catalog.uploadFoodImage('f1', Uint8List(500), contentType: 'image/png');
    final calls = adapter.calls;
    expect(calls.map((c) => '${c.method} ${c.uri.host}${c.uri.path}'), [
      'POST x/v1/foods/f1/image/upload-url',
      'PUT r2.test/p',
      'PUT x/v1/foods/f1/image',
    ]);
    expect(calls[0].data, {'size': 500, 'content_type': 'image/png'});
    expect(calls[1].contentType, 'image/png');
    expect(calls[1].headers.containsKey('Authorization'), isFalse);
    expect(calls[2].data, {'key': 'images/foods/f1/a.png'});
    expect(food.imageUrl, 'https://cdn/a.png');
    expect(touched, ['foods']);
  });

  test('deleteFoodImage sends DELETE and touches foods', () async {
    await catalog.deleteFoodImage('f1');
    expect(adapter.calls.single.method, 'DELETE');
    expect(adapter.calls.single.uri.path, '/v1/foods/f1/image');
    expect(touched, ['foods']);
  });

  test('uploadProductImage returns key; setProductImages replaces list', () async {
    respond = (o) async {
      if (o.path == '/v1/products/p1/images/upload-url') {
        return jsonBody(
            {'key': 'images/products/p1/a.jpg', 'upload_url': 'https://r2.test/p'}, 201);
      }
      if (o.uri.host == 'r2.test') return ResponseBody.fromString('', 200);
      return jsonBody({
        'id': 'p1',
        'category': 'Forma',
        'name': 'X',
        'image_urls': ['https://cdn/a.jpg'],
        'image_keys': ['images/products/p1/a.jpg'],
      }, 200);
    };
    final key = await shop.uploadProductImage('p1', Uint8List(10));
    expect(key, 'images/products/p1/a.jpg');
    expect(adapter.calls[0].data, {'size': 10, 'content_type': 'image/jpeg'});
    final saved = await shop.setProductImages('p1', [key]);
    expect(adapter.calls.last.method, 'PUT');
    expect(adapter.calls.last.uri.path, '/v1/products/p1/images');
    expect(adapter.calls.last.data, {
      'keys': [key]
    });
    expect(saved.imageUrls, ['https://cdn/a.jpg']);
    expect(saved.imageKeys, [key]);
    expect(touched, ['products']);
  });

  test('image over 5 MB rejected before any request', () async {
    await expectLater(
      catalog.uploadFoodImage('f1', Uint8List(ApiService.maxImageBytes + 1)),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'image_too_large')),
    );
    expect(adapter.calls, isEmpty);
  });

  test('missing slot fails and never confirms', () async {
    await expectLater(
      shop.uploadProductImage('p1', Uint8List(10)),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'upload_slot_missing')),
    );
    expect(adapter.calls, hasLength(1));
    expect(touched, isEmpty);
  });
}
