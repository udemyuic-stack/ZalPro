import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/api_error.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';
import 'package:kotta_qani_diet/services/api/users_api.dart';

import 'support/fake_api.dart';

const _settle = Duration(milliseconds: 120);

void main() {
  late FakeAdapter adapter;
  late UsersApi api;
  late ChangeBus bus;
  late PollActivity activity;
  var gyms = <Map<String, dynamic>>[];
  Future<ResponseBody> Function(RequestOptions) respond = (o) async => jsonBody([], 200);

  Future<void> settle([Duration d = _settle]) => Future<void>.delayed(d);

  setUp(() {
    gyms = [
      {'id': 'g1', 'name': 'B'},
      {'id': 'g2', 'name': 'A'},
    ];
    respond = (o) async => jsonBody(gyms, 200);
    adapter = FakeAdapter((o) => respond(o));
    final client = ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter);
    bus = ChangeBus();
    activity = PollActivity();
    api = UsersApi(client, bus: bus, activity: activity);
  });

  int gets() => adapter.count('/v1/gyms');

  test('two concurrent listeners share one GET and both get the value', () async {
    final a = <int>[];
    final b = <int>[];
    final subA = api.gyms().listen((v) => a.add(v.length));
    final subB = api.gyms().listen((v) => b.add(v.length));
    await settle();
    expect(gets(), 1);
    expect(a, [2]);
    expect(b, [2]);
    await subA.cancel();
    await subB.cancel();
  });

  test('late listener gets the last value without another GET', () async {
    final subA = api.gyms().listen((_) {});
    await settle();
    final late = <int>[];
    final subB = api.gyms().listen((v) => late.add(v.length));
    await settle(const Duration(milliseconds: 20));
    expect(late, [2]);
    expect(gets(), 1);
    await subA.cancel();
    await subB.cancel();
  });

  test('tag touch burst makes one fresh GET with the new data', () async {
    final seen = <int>[];
    final subA = api.gyms().listen((v) => seen.add(v.length));
    final subB = api.gyms().listen((_) {});
    await settle();
    gyms = [
      {'id': 'g1', 'name': 'B'},
    ];
    bus.touchAll(['gyms', 'gyms', 'gyms']);
    await settle();
    expect(gets(), 2);
    expect(seen, [2, 1]);
    await subA.cancel();
    await subB.cancel();
  });

  test('touch while a fetch is in flight still refetches after it', () async {
    final gate = Completer<void>();
    var served = 0;
    respond = (o) async {
      served++;
      if (served == 1) await gate.future;
      return jsonBody(gyms, 200);
    };
    final seen = <int>[];
    final sub = api.gyms().listen((v) => seen.add(v.length));
    await settle(const Duration(milliseconds: 20));
    gyms = [
      {'id': 'g1', 'name': 'B'},
    ];
    bus.touch('gyms');
    await settle(const Duration(milliseconds: 20));
    gate.complete();
    await settle();
    expect(seen.last, 1);
    expect(gets(), 2);
    await sub.cancel();
  });

  test('cancelling every listener stops the loop', () async {
    final a = api.gyms().listen((_) {});
    final b = api.gyms().listen((_) {});
    await settle();
    await a.cancel();
    await settle(const Duration(milliseconds: 20));
    bus.touch('gyms');
    await settle();
    expect(gets(), 2);
    await b.cancel();
    await settle(const Duration(milliseconds: 400));
    final stopped = gets();
    bus.touch('gyms');
    activity.value = false;
    activity.value = true;
    await settle(const Duration(milliseconds: 400));
    expect(gets(), stopped);
  });

  test('listening again after everything cancelled starts a new loop', () async {
    final first = await api.gyms().first;
    expect(first.length, 2);
    await settle(const Duration(milliseconds: 400));
    final before = gets();
    final second = await api.gyms().first;
    expect(second.length, 2);
    expect(gets(), before + 1);
  });

  test('resubscribing in the same frame reuses the running loop', () async {
    final first = api.gyms().listen((_) {});
    await settle();
    await first.cancel();
    final second = api.gyms().listen((_) {});
    await settle();
    expect(gets(), 1);
    await second.cancel();
  });

  test('error reaches every listener, also a late one', () async {
    respond = (o) async => jsonBody({'detail': 'x'}, 500);
    final errA = <Object>[];
    final errB = <Object>[];
    final subA = api.gyms().listen((_) {}, onError: errA.add);
    final subB = api.gyms().listen((_) {}, onError: errB.add);
    await settle();
    final errC = <Object>[];
    final subC = api.gyms().listen((_) {}, onError: errC.add);
    await settle(const Duration(milliseconds: 20));
    expect(errA.single, isA<ApiException>());
    expect(errB.single, isA<ApiException>());
    expect(errC.single, isA<ApiException>());
    await subA.cancel();
    await subB.cancel();
    await subC.cancel();
  });

  test('scripted scenario of 4 listeners, 3 touch bursts and 5 resubscribes stays at a few GETs',
      () async {
    final subs = <StreamSubscription<Object?>>[];
    for (var i = 0; i < 4; i++) {
      subs.add(api.gyms().listen((_) {}));
    }
    await settle();
    for (var i = 0; i < 3; i++) {
      bus.touchAll(['gyms', 'gyms']);
      await settle(const Duration(milliseconds: 20));
    }
    for (var i = 0; i < 5; i++) {
      await subs.removeAt(0).cancel();
      subs.add(api.gyms().listen((_) {}));
      await settle(const Duration(milliseconds: 10));
    }
    await settle(const Duration(milliseconds: 400));
    expect(gets(), lessThanOrEqualTo(4));
    for (final s in subs) {
      await s.cancel();
    }
  });
}
