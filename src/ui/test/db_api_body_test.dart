import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/api_error.dart';
import 'package:kotta_qani_diet/services/api/body_api.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';

import 'support/fake_api.dart';

void main() {
  late FakeAdapter adapter;
  late BodyApi api;
  late List<String> touched;
  Future<ResponseBody> Function(RequestOptions) respond = (o) async => jsonBody([], 200);

  setUp(() {
    respond = (o) async => jsonBody([], 200);
    adapter = FakeAdapter((o) => respond(o));
    final client = ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter);
    final bus = ChangeBus();
    touched = [];
    bus.changes.listen(touched.add);
    api = BodyApi(client, bus: bus, activity: PollActivity());
  });

  RequestOptions last() => adapter.calls.last;

  test('weights: ascending by date', () async {
    respond = (o) async => jsonBody([
          {'id': 'b', 'date': '2026-05-10T10:00:00Z', 'weight': 81.5},
          {'id': 'a', 'date': '2026-05-01T10:00:00Z', 'weight': 82.0},
        ], 200);
    final logs = await api.weights('u1').first;
    expect(last().path, '/v1/users/u1/weights');
    expect(logs.map((l) => l.weight), [82.0, 81.5]);
  });

  test('addWeight: POST weight, touches weights and user tags', () async {
    respond = (o) async => jsonBody({'id': 'x', 'date': '2026-05-10T10:00:00Z', 'weight': 80}, 201);
    await api.addWeight('u1', 80);
    expect(last().method, 'POST');
    expect(last().data, {'weight': 80.0});
    await Future<void>.delayed(Duration.zero);
    expect(touched, containsAll(['weights:u1', 'user:u1', 'users']));
  });

  test('addWeight: 409 weigh_in_too_soon surfaces as localized text', () async {
    respond = (o) async => jsonBody({
          'detail': {'code': 'weigh_in_too_soon', 'message': 'x'}
        }, 409);
    await expectLater(
      api.addWeight('u1', 80),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'weigh_in_too_soon')),
    );
    await Future<void>.delayed(Duration.zero);
    expect(touched, isEmpty);
  });

  test('photos: oldest first, keeps download url', () async {
    respond = (o) async => jsonBody([
          {
            'id': 'new',
            'taken_at': '2026-05-10T10:00:00Z',
            'weight': 80.0,
            'size': 10,
            'download_url': 'http://r2/new'
          },
          {
            'id': 'old',
            'taken_at': '2026-04-10T10:00:00Z',
            'weight': 85.0,
            'size': 10,
            'download_url': 'http://r2/old'
          },
        ], 200);
    final photos = await api.photos('u1').first;
    expect(last().path, '/v1/users/u1/photos');
    expect(photos.map((p) => p.id), ['old', 'new']);
    expect(photos.first.url, 'http://r2/old');
    expect(photos.first.bytes, isEmpty);
    expect(photos.first.urlExpiresAt, isNotNull);
  });

  test('addPhoto: asks upload url, PUTs bytes to it, touches photos tag', () async {
    respond = (o) async {
      if (o.path.endsWith('/upload-url')) {
        return jsonBody(
            {'photo_id': 'p1', 'upload_url': 'http://r2/put?sig=1', 'expires_in': 600}, 201);
      }
      return jsonBody({}, 200);
    };
    await api.addPhoto('u1', Uint8List.fromList([1, 2, 3]), 80.5);
    expect(adapter.calls.first.path, '/v1/users/u1/photos/upload-url');
    expect(adapter.calls.first.data, {'weight': 80.5, 'size': 3});
    final put = last();
    expect(put.method, 'PUT');
    expect(put.uri.toString(), 'http://r2/put?sig=1');
    expect(put.headers['Authorization'], isNull);
    await Future<void>.delayed(Duration.zero);
    expect(touched, contains('photos:u1'));
  });

  test('addPhoto: failed upload removes the reserved photo and rethrows', () async {
    respond = (o) async {
      if (o.path.endsWith('/upload-url')) {
        return jsonBody({'photo_id': 'p1', 'upload_url': 'http://r2/put', 'expires_in': 600}, 201);
      }
      if (o.method == 'PUT') return jsonBody({}, 403);
      return jsonBody({}, 204);
    };
    await expectLater(api.addPhoto('u1', Uint8List.fromList([1]), 80), throwsA(anything));
    expect(last().method, 'DELETE');
    expect(last().path, '/v1/users/u1/photos/p1');
    await Future<void>.delayed(Duration.zero);
    expect(touched, isEmpty);
  });

  test('deletePhoto: DELETE and touches photos tag', () async {
    respond = (o) async => jsonBody({}, 204);
    await api.deletePhoto('u1', 'p1');
    expect(last().method, 'DELETE');
    expect(last().path, '/v1/users/u1/photos/p1');
    await Future<void>.delayed(Duration.zero);
    expect(touched, contains('photos:u1'));
  });
}
