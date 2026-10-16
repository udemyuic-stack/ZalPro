import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/api_error.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';

import 'support/fake_api.dart';

Map<String, dynamic> pair(String sub, String refresh) =>
    {'access_token': fakeJwt(sub), 'refresh_token': refresh};

DioException networkError(RequestOptions o) =>
    DioException(requestOptions: o, type: DioExceptionType.connectionError, message: 'down');

void main() {
  late MemorySessionStore store;

  setUp(() => store = MemorySessionStore());

  test('login stores refresh token and sets userId from JWT sub', () async {
    final adapter = FakeAdapter((o) async => jsonBody(pair('u1', 'r1'), 200));
    final client = ApiClient(store: store, baseUrl: 'http://x', adapter: adapter);

    await client.login('998901234567', 'secret123');

    expect(await store.readRefreshToken(), 'r1');
    expect(client.userId, 'u1');
    expect(client.accessToken, fakeJwt('u1'));
    expect(adapter.calls.single.path, '/v1/auth/login');
    expect(adapter.calls.single.headers.containsKey('Authorization'), isFalse);
  });

  test('bearer header is sent on authed requests', () async {
    final adapter = FakeAdapter((o) async {
      if (o.path == '/v1/auth/login') return jsonBody(pair('u1', 'r1'), 200);
      return jsonBody({'ok': true}, 200);
    });
    final client = ApiClient(store: store, baseUrl: 'http://x', adapter: adapter);
    await client.login('p', 'q');

    final res = await client.getJson('/v1/users/me');

    expect(res['ok'], true);
    expect(adapter.calls.last.headers['Authorization'], 'Bearer ${fakeJwt('u1')}');
  });

  test('10 parallel 401s trigger exactly one refresh and all succeed', () async {
    var refreshed = false;
    final adapter = FakeAdapter((o) async {
      if (o.path == '/v1/auth/login') return jsonBody(pair('old', 'r1'), 200);
      if (o.path == '/v1/auth/refresh') {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        refreshed = true;
        return jsonBody(pair('new', 'r2'), 200);
      }
      final ok = o.headers['Authorization'] == 'Bearer ${fakeJwt('new')}';
      return ok
          ? jsonBody({'id': 'new'}, 200)
          : jsonBody({
              'detail': {'code': 'expired'}
            }, 401);
    });
    final client = ApiClient(store: store, baseUrl: 'http://x', adapter: adapter);
    await client.login('p', 'q');

    final results = await Future.wait(
      List.generate(10, (_) => client.getJson('/v1/users/me')),
    );

    expect(refreshed, isTrue);
    expect(adapter.count('/v1/auth/refresh'), 1);
    expect(results.every((r) => r['id'] == 'new'), isTrue);
    expect(adapter.count('/v1/users/me'), 20);
    expect(await store.readRefreshToken(), 'r2');
    expect(client.userId, 'new');
  });

  test('refresh 401 clears session and request throws 401', () async {
    final adapter = FakeAdapter((o) async {
      if (o.path == '/v1/auth/login') return jsonBody(pair('u1', 'r1'), 200);
      if (o.path == '/v1/auth/refresh') {
        return jsonBody({
          'detail': {'code': 'invalid_token'}
        }, 401);
      }
      return jsonBody({
        'detail': {'code': 'expired'}
      }, 401);
    });
    final client = ApiClient(store: store, baseUrl: 'http://x', adapter: adapter);
    await client.login('p', 'q');
    final emitted = <String?>[];
    client.userChanges.listen(emitted.add);

    await expectLater(
      client.getJson('/v1/users/me'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
    await Future<void>.delayed(Duration.zero);

    expect(await store.readRefreshToken(), isNull);
    expect(client.userId, isNull);
    expect(client.accessToken, isNull);
    expect(emitted, [null]);
  });

  test('refresh network error keeps session and request throws ApiException', () async {
    final adapter = FakeAdapter((o) async {
      if (o.path == '/v1/auth/login') return jsonBody(pair('u1', 'r1'), 200);
      if (o.path == '/v1/auth/refresh') throw networkError(o);
      return jsonBody({
        'detail': {'code': 'expired'}
      }, 401);
    });
    final client = ApiClient(store: store, baseUrl: 'http://x', adapter: adapter);
    await client.login('p', 'q');

    await expectLater(client.getJson('/v1/users/me'), throwsA(isA<ApiException>()));

    expect(await store.readRefreshToken(), 'r1');
    expect(client.userId, 'u1');
  });

  test('retry that still returns 401 is attempted exactly once', () async {
    final adapter = FakeAdapter((o) async {
      if (o.path == '/v1/auth/login') return jsonBody(pair('u1', 'r1'), 200);
      if (o.path == '/v1/auth/refresh') return jsonBody(pair('u1', 'r2'), 200);
      return jsonBody({
        'detail': {'code': 'forbidden'}
      }, 401);
    });
    final client = ApiClient(store: store, baseUrl: 'http://x', adapter: adapter);
    await client.login('p', 'q');

    await expectLater(
      client.getJson('/v1/users/me'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );

    expect(adapter.count('/v1/users/me'), 2);
    expect(adapter.count('/v1/auth/refresh'), 1);
  });

  test('restore with stored refresh token logs in', () async {
    await store.writeRefreshToken('r0');
    final adapter = FakeAdapter((o) async => jsonBody(pair('u9', 'r9'), 200));
    final client = ApiClient(store: store, baseUrl: 'http://x', adapter: adapter);

    await client.restore();

    expect(client.userId, 'u9');
    expect(await store.readRefreshToken(), 'r9');
    expect(adapter.calls.single.data, {'refresh_token': 'r0'});
  });

  test('restore without stored token does nothing', () async {
    final adapter = FakeAdapter((o) async => jsonBody(pair('u9', 'r9'), 200));
    final client = ApiClient(store: store, baseUrl: 'http://x', adapter: adapter);

    await client.restore();

    expect(adapter.calls, isEmpty);
    expect(client.userId, isNull);
  });

  test('logout clears session even if the logout call fails', () async {
    final adapter = FakeAdapter((o) async {
      if (o.path == '/v1/auth/login') return jsonBody(pair('u1', 'r1'), 200);
      return jsonBody({
        'detail': {'code': 'boom'}
      }, 500);
    });
    final client = ApiClient(store: store, baseUrl: 'http://x', adapter: adapter);
    await client.login('p', 'q');

    await client.logout();

    expect(adapter.count('/v1/auth/logout'), 1);
    expect(await store.readRefreshToken(), isNull);
    expect(client.userId, isNull);
    expect(client.accessToken, isNull);
  });
}
