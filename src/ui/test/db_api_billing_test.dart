import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/models/subscription.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/billing_api.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';

import 'support/fake_api.dart';

Map<String, dynamic> subJson(String id, String uid, String start, {int months = 1, int days = 0}) =>
    {
      'id': id,
      'user_id': uid,
      'start_date': start,
      'months': months,
      'days': days,
      'price': 500000,
      'currency': 'UZS',
      'paid_date': start,
      'created_at': start,
      'paid_at': start,
      'expires_at': start,
    };

Map<String, dynamic> reminderJson(String id, String trainer) => {
      'id': id,
      'client_id': 'u1',
      'client_name': 'Ali',
      'trainer_id': trainer,
      'sent_by': trainer,
      'sent_at': '2026-05-09T09:00:00Z',
      'days_left': 2,
    };

AppUser person(String id, {String role = 'user', String? gymId}) => AppUser(
      id: id,
      name: 'Ali',
      email: '',
      gender: 'male',
      metabolism: 'normal',
      role: role,
      gymId: gymId,
    );

void main() {
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
    api = BillingApi(client,
        bus: bus, activity: PollActivity(), now: () => DateTime(2026, 5, 10, 15));
  });

  RequestOptions last() => adapter.calls.last;

  test('subscriptions: sorted by startDate descending', () async {
    respond = (o) async => jsonBody([
          subJson('a', 'u1', '2026-01-01T00:00:00Z'),
          subJson('b', 'u1', '2026-04-01T00:00:00Z'),
          subJson('c', 'u1', '2026-02-01T00:00:00Z'),
        ], 200);
    final list = await api.subscriptions('u1').first;
    expect(last().path, '/v1/users/u1/subscriptions');
    expect(list.map((s) => s.id), ['b', 'c', 'a']);
  });

  test('allSubscriptions: pairs rows with user_id and sends no window', () async {
    respond = (o) async => jsonBody([
          subJson('a', 'u1', '2026-01-01T00:00:00Z'),
          subJson('b', 'u2', '2026-04-01T00:00:00Z', months: 0, days: 3),
        ], 200);
    final list = await api.allSubscriptions().first;
    expect(last().path, '/v1/subscriptions');
    expect(last().queryParameters, isEmpty);
    expect(list.map((e) => e.$1), ['u1', 'u2']);
    expect(list[1].$2.isDaily, true);
  });

  test('addSubscription: POST with the six fields in UTC and touches mirrors', () async {
    final s = Subscription(
      startDate: DateTime.utc(2026, 5, 10, 8),
      months: 3,
      price: 1500000,
      paidDate: DateTime.utc(2026, 5, 10, 8),
    );
    await api.addSubscription(person('u1'), s);
    expect(last().method, 'POST');
    expect(last().path, '/v1/users/u1/subscriptions');
    expect(last().data, {
      'start_date': '2026-05-10T08:00:00.000Z',
      'months': 3,
      'days': 0,
      'price': 1500000,
      'currency': 'UZS',
      'paid_date': '2026-05-10T08:00:00.000Z',
    });
    await Future<void>.delayed(Duration.zero);
    expect(touched, containsAll(['subscriptions', 'memberships', 'user:u1', 'users']));
    expect(adapter.calls.length, 1);
  });

  test('addSubscription: failure touches nothing', () async {
    respond = (o) async => jsonBody({
          'detail': {'code': 'validation_error', 'message': 'x'}
        }, 422);
    final s = Subscription(startDate: DateTime.utc(2026, 5, 10), months: 1);
    await expectLater(api.addSubscription(person('u1'), s), throwsA(anything));
    await Future<void>.delayed(Duration.zero);
    expect(touched, isEmpty);
  });

  test('memberships: owner fetches, staff without gym makes no request', () async {
    respond = (o) async => jsonBody([
          {
            'user_id': 'u1',
            'name': 'Ali',
            'gym_id': 'g1',
            'months': 1,
            'days': 0,
            'price': 500000,
            'currency': 'UZS',
            'paid_date': '2026-05-01T00:00:00Z',
            'expires_at': '2026-06-01T00:00:00Z',
            'updated_at': '2026-05-01T00:00:00Z',
          },
        ], 200);
    final owner = await api.memberships(person('o', role: 'owner')).first;
    expect(last().path, '/v1/memberships');
    expect(owner.single.uid, 'u1');
    final before = adapter.calls.length;
    final none = await api.memberships(person('t', role: 'admin')).first;
    expect(none, isEmpty);
    expect(adapter.calls.length, before);
    final gym = await api.memberships(person('t', role: 'admin', gymId: 'g1')).first;
    expect(gym.length, 1);
    expect(adapter.calls.length, before + 1);
  });

  test('attendance: shared poll per user and day, mark pushes and PUTs', () async {
    var present = false;
    respond = (o) async => jsonBody({'day': '2026-05-10', 'present': present}, 200);
    final values = <bool>[];
    final sub = api.attendance('u1', '2026-05-10').listen(values.add);
    final sub2 = api.attendance('u1', '2026-05-10').listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(adapter.count('/v1/users/u1/attendance/2026-05-10'), 1);
    expect(values, [false]);
    present = true;
    await api.markAttendance('u1', '2026-05-10', true);
    final put = adapter.calls.firstWhere((c) => c.method == 'PUT');
    expect(put.path, '/v1/users/u1/attendance/2026-05-10');
    expect(put.data, {'present': true});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(values.last, true);
    await sub.cancel();
    await sub2.cancel();
  });

  test('allReminders: no window; remindersOf: 400-day window and trainer filter', () async {
    respond = (o) async => jsonBody([reminderJson('r1', 't1'), reminderJson('r2', 't2')], 200);
    final all = await api.allReminders().first;
    expect(last().path, '/v1/reminders');
    expect(last().queryParameters, isEmpty);
    expect(all.length, 2);
    final mine = await api.remindersOf('t1').first;
    expect(last().queryParameters, {'from': '2025-04-07', 'to': '2026-05-11'});
    expect(mine.single.id, 'r1');
  });

  test('sendSubscriptionReminder: POST client_id and clamped days_left, no chat call', () async {
    await api.sendSubscriptionReminder(person('u1'), -9999);
    expect(last().method, 'POST');
    expect(last().path, '/v1/reminders');
    expect(last().data, {'client_id': 'u1', 'days_left': -3650});
    await api.sendSubscriptionReminder(person('u1'), 90);
    expect(last().data, {'client_id': 'u1', 'days_left': 31});
    expect(adapter.calls.every((c) => c.path == '/v1/reminders'), true);
    await Future<void>.delayed(Duration.zero);
    expect(touched, contains('reminders'));
  });
}
