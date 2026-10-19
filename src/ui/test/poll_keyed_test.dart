import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/billing_api.dart';
import 'package:kotta_qani_diet/services/api/chat_api.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';
import 'package:kotta_qani_diet/services/api/shop_api.dart';
import 'package:kotta_qani_diet/services/api/users_api.dart';

import 'support/fake_api.dart';

const _settle = Duration(milliseconds: 120);

Map<String, dynamic> order(String id, String client, String trainer) => {
      'id': id,
      'client_id': client,
      'trainer_id': trainer,
      'product_id': 'p1',
      'qty': 1,
      'status': 'pending',
      'created_at': '2026-10-01T10:00:00Z',
    };

void main() {
  late FakeAdapter adapter;
  late ApiClient client;
  late ChangeBus bus;
  late PollActivity activity;
  late Map<String, Object> bodies;

  Future<void> settle([Duration d = _settle]) => Future<void>.delayed(d);

  setUp(() {
    bodies = {
      '/v1/orders': [order('o1', 'u1', 't1'), order('o2', 'u2', 't2')],
      '/v1/reminders': [],
      '/v1/users/me': {'id': 'u1', 'name': 'A', 'role': 'user'},
      '/v1/chats/c1/messages': [],
    };
    adapter = FakeAdapter((o) async {
      if (o.path == '/v1/auth/login') {
        return jsonBody({'access_token': fakeJwt('u1'), 'refresh_token': 'r1'}, 200);
      }
      return jsonBody(bodies[o.path] ?? [], 200);
    });
    client = ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter);
    bus = ChangeBus();
    activity = PollActivity();
  });

  test('orders of different callers share one GET and filter per listener', () async {
    final api = ShopApi(client, bus: bus, activity: activity);
    final mine = <int>[];
    final trainers = <int>[];
    final subA = api.myOrders('u1').listen((v) => mine.add(v.length));
    final subB = api.ordersOf('t2').listen((v) => trainers.add(v.length));
    final subC = api.gymOrders('').listen((_) {});
    await settle();
    expect(adapter.count('/v1/orders'), 1);
    expect(mine, [1]);
    expect(trainers, [1]);
    await subA.cancel();
    await subB.cancel();
    await subC.cancel();
  });

  test('all orders and windowed orders use separate requests', () async {
    final api = ShopApi(client, bus: bus, activity: activity);
    final a = api.allOrders().listen((_) {});
    final b = api.myOrders('u1').listen((_) {});
    await settle();
    expect(adapter.count('/v1/orders'), 2);
    await a.cancel();
    await b.cancel();
  });

  test('reminders of different trainers share one GET', () async {
    final api = BillingApi(client, bus: bus, activity: activity);
    final a = api.remindersOf('t1').listen((_) {});
    final b = api.remindersOf('t2').listen((_) {});
    await settle();
    expect(adapter.count('/v1/reminders'), 1);
    await a.cancel();
    await b.cancel();
  });

  test('me stream is shared and refreshes on the user tag', () async {
    await client.login('998900000001', 'secret123');
    final api = UsersApi(client, bus: bus, activity: activity);
    final seen = <String?>[];
    final a = api.me('u1').listen((u) => seen.add(u?.name));
    final b = api.me('u1').listen((_) {});
    await settle();
    expect(adapter.count('/v1/users/me'), 1);
    bodies['/v1/users/me'] = {'id': 'u1', 'name': 'B', 'role': 'user'};
    bus.touch('user:u1');
    await settle();
    expect(seen, ['A', 'B']);
    await a.cancel();
    await b.cancel();
  });

  test('updating the user profile refreshes the shared me stream', () async {
    await client.login('998900000001', 'secret123');
    final api = UsersApi(client, bus: bus, activity: activity);
    final seen = <String?>[];
    final sub = api.me('u1').listen((u) => seen.add(u?.trainerId));
    await settle();
    bodies['/v1/users/me'] = {'id': 'u1', 'name': 'A', 'role': 'user', 'trainer_id': 't1'};
    await api.updateUser(AppUser(id: 'u1', name: 'A', email: ''));
    await settle();
    expect(seen.last, 't1');
    await sub.cancel();
  });

  test('chat watcher resubscribed within grace reuses the request', () async {
    final api = ChatApi(client, bus: bus, activity: activity);
    final first = api.messageEvents('c1').listen((_) {});
    await settle();
    await first.cancel();
    final second = api.messageEvents('c1').listen((_) {});
    await settle();
    expect(adapter.count('/v1/chats/c1/messages'), 1);
    await second.cancel();
    await settle(const Duration(milliseconds: 400));
  });

  test('chat watcher shares a poll with the live message stream', () async {
    final api = ChatApi(client, bus: bus, activity: activity);
    final a = api.messageEvents('c1').listen((_) {});
    final b = api.messageEvents('c1').listen((_) {});
    await settle();
    expect(adapter.count('/v1/chats/c1/messages'), 1);
    await a.cancel();
    await b.cancel();
    await settle(const Duration(milliseconds: 400));
  });
}
