import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/api_error.dart';
import 'package:kotta_qani_diet/services/api/push_api.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, [this.body]);

  final int status;
  final Map<String, dynamic>? body;
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    final payload = body == null ? '' : json.encode(body);
    return ResponseBody.fromString(
      payload,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

PushApi _api(_FakeAdapter adapter) =>
    PushApi(ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter));

void main() {
  test('add posts token and platform and accepts 204', () async {
    final adapter = _FakeAdapter(204);
    await _api(adapter).add('tok123', 'web');
    final req = adapter.seen.single;
    expect(req.method, 'POST');
    expect(req.uri.path, '/v1/users/me/push-tokens');
    expect(req.data, {'token': 'tok123', 'platform': 'web'});
  });

  test('remove encodes token path segment and accepts 204', () async {
    final adapter = _FakeAdapter(204);
    await _api(adapter).remove('a:b/c d');
    final req = adapter.seen.single;
    expect(req.method, 'DELETE');
    expect(req.uri.toString(), 'http://x/v1/users/me/push-tokens/a%3Ab%2Fc%20d');
  });

  test('api error becomes ApiException', () async {
    final adapter = _FakeAdapter(422, {
      'detail': {'code': 'validation_error', 'message': 'bad'},
    });
    await expectLater(
      _api(adapter).add('t', 'android'),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 422)
          .having((e) => e.code, 'code', 'validation_error')),
    );
  });

  test('currentPlatform returns a known value', () {
    expect(['android', 'web', 'ios'], contains(PushApi.currentPlatform()));
  });
}
