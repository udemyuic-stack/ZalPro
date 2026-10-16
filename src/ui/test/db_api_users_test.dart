import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/api_error.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';
import 'package:kotta_qani_diet/services/api/users_api.dart';

import 'support/fake_api.dart';

Map<String, dynamic> userJson(String id, {String role = 'user', Object? trainerId}) => {
      'id': id,
      'name': 'Ali',
      'phone': '998901234567',
      'role': role,
      'trainer_id': trainerId,
      'gym_days': [1, 3, 5],
    };

void main() {
  late FakeAdapter adapter;
  late UsersApi api;
  late ChangeBus bus;
  late PollActivity activity;
  late List<String> touched;
  Future<ResponseBody> Function(RequestOptions) respond = (o) async => jsonBody({}, 200);

  setUp(() {
    respond = (o) async => jsonBody({}, 200);
    adapter = FakeAdapter((o) => respond(o));
    final client = ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter);
    bus = ChangeBus();
    activity = PollActivity();
    touched = [];
    bus.changes.listen(touched.add);
    api = UsersApi(client, bus: bus, activity: activity, now: () => DateTime.utc(2026, 5, 1, 9));
  });

  RequestOptions last() => adapter.calls.last;

  test('user: 200 maps to AppUser, uses GET /v1/users/{id}', () async {
    respond = (o) async => jsonBody(userJson('u1'), 200);
    final u = await api.user('u1').first;
    expect(last().method, 'GET');
    expect(last().path, '/v1/users/u1');
    expect(u!.id, 'u1');
    expect(u.gymDays, [1, 3, 5]);
    expect(u.email, '');
  });

  test('user: 404 yields null', () async {
    respond = (o) async => jsonBody({
          'detail': {'code': 'not_found', 'message': 'yo\'q'},
        }, 404);
    expect(await api.user('u1').first, isNull);
  });

  test('clients: role=user query and paging', () async {
    final page = List.generate(500, (i) => userJson('u$i'));
    respond = (o) async {
      final offset = o.queryParameters['offset'] as int;
      return jsonBody(offset == 0 ? page : [userJson('last')], 200);
    };
    final list = await api.clients().first;
    expect(list.length, 501);
    expect(adapter.calls.length, 2);
    expect(adapter.calls.first.path, '/v1/users');
    expect(adapter.calls.first.queryParameters['role'], 'user');
    expect(adapter.calls.first.queryParameters['limit'], 500);
    expect(adapter.calls.last.queryParameters['offset'], 500);
  });

  test('clientsOf sends trainer_id', () async {
    respond = (o) async => jsonBody([userJson('u1', trainerId: 't1')], 200);
    final list = await api.clientsOf('t1').first;
    expect(list.single.trainerId, 't1');
    expect(last().queryParameters['trainer_id'], 't1');
    expect(last().queryParameters['role'], 'user');
  });

  test('staff sends three roles, trainers one', () async {
    respond = (o) async => jsonBody([], 200);
    await api.staff().first;
    expect(last().queryParameters['role'], ['admin', 'owner', 'barmen']);
    await api.trainers().first;
    expect(last().queryParameters['role'], 'admin');
  });

  test('gyms sorted by name', () async {
    respond = (o) async => jsonBody([
          {'id': 'g2', 'name': 'Zebra'},
          {'id': 'g1', 'name': 'Alfa'},
        ], 200);
    final list = await api.gyms().first;
    expect(list.map((g) => g.id), ['g1', 'g2']);
  });

  test('saveGym: empty id POSTs and returns new id, else PUTs', () async {
    respond = (o) async => jsonBody({'id': 'g9', 'name': 'N'}, 201);
    final id = await api.saveGym(const Gym(name: 'N', region: 'R'));
    expect(id, 'g9');
    expect(last().method, 'POST');
    expect(last().path, '/v1/gyms');
    expect(last().data, {'name': 'N', 'country': '', 'region': 'R', 'district': '', 'address': ''});
    expect(touched, contains('gyms'));
    respond = (o) async => jsonBody({'id': 'g1', 'name': 'N'}, 200);
    expect(await api.saveGym(const Gym(id: 'g1', name: 'N')), 'g1');
    expect(last().method, 'PUT');
    expect(last().path, '/v1/gyms/g1');
  });

  test('deleteGym and setUserGym', () async {
    respond = (o) async => jsonBody({}, 204);
    await api.deleteGym('g1');
    expect(last().method, 'DELETE');
    expect(last().path, '/v1/gyms/g1');
    await api.setUserGym('u1', null);
    expect(last().method, 'PUT');
    expect(last().path, '/v1/users/u1/gym');
    expect(last().data, {'gym_id': null});
  });

  test('createStaff posts normalized body and returns id', () async {
    respond = (o) async => jsonBody(userJson('n1', role: 'admin'), 201);
    final id = await api.createStaff(
      name: ' Vali ',
      phone: '998901112233',
      password: 'pass1234',
      role: 'admin',
      gymId: 'g1',
    );
    expect(id, 'n1');
    expect(last().method, 'POST');
    expect(last().path, '/v1/users');
    expect(last().data, {
      'name': 'Vali',
      'phone': '998901112233',
      'password': 'pass1234',
      'role': 'admin',
      'gym_id': 'g1',
    });
  });

  AppUser form({double weight = 70, String? trainerId}) => AppUser(
        id: 'u1',
        name: 'Ali',
        email: '',
        phone: '1',
        gender: 'male',
        age: 25,
        height: 180,
        weight: weight,
        activity: 1.55,
        metabolism: 'normal',
        goal: 'lose',
        trainerId: trainerId,
      );

  test('updateUser: PATCH without weight when already set', () async {
    await api.updateUser(form(), before: form());
    expect(adapter.calls.length, 1);
    expect(last().method, 'PATCH');
    expect(last().path, '/v1/users/u1');
    expect(last().data, {
      'name': 'Ali',
      'gender': 'male',
      'age': 25,
      'height': 180.0,
      'activity': 1.55,
      'metabolism': 'normal',
      'goal': 'lose',
    });
  });

  test('updateUser: weight sent only on first setup, trainer via PUT', () async {
    await api.updateUser(form(trainerId: 't1'), before: form(weight: 0));
    expect(adapter.calls.length, 2);
    expect(adapter.calls.first.data['weight'], 70.0);
    expect(last().method, 'PUT');
    expect(last().path, '/v1/users/u1/trainer');
    expect(last().data, {'trainer_id': 't1'});
    expect(touched, containsAll(['users', 'user:u1']));
  });

  test('updateUser: unchanged trainer is not re-sent', () async {
    await api.updateUser(form(trainerId: 't1'), before: form(trainerId: 't1'));
    expect(adapter.calls.length, 1);
  });

  test('assignPlan sends UTC timestamp, null clears it', () async {
    await api.assignPlan('u1', 'p1');
    expect(last().method, 'PATCH');
    expect(last().data, {'plan_id': 'p1', 'plan_assigned_at': '2026-05-01T09:00:00.000Z'});
    await api.assignPlan('u1', null);
    expect(last().data, {'plan_id': null, 'plan_assigned_at': null});
  });

  test('setGoal, setGymDays (sorted), setHomeWorkout', () async {
    await api.setGoal('u1', 'gain');
    expect(last().data, {'goal': 'gain'});
    await api.setGymDays('u1', [5, 1, 3]);
    expect(last().data, {
      'gym_days': [1, 3, 5]
    });
    await api.setHomeWorkout('u1', '2026-05-02');
    expect(last().data, {'home_workout_date': '2026-05-02'});
    await api.setHomeWorkout('u1', null);
    expect(last().data, {'home_workout_date': null});
    expect(last().path, '/v1/users/u1');
  });

  test('assignTrainer PUTs trainer', () async {
    await api.assignTrainer('u1', null);
    expect(last().method, 'PUT');
    expect(last().path, '/v1/users/u1/trainer');
    expect(last().data, {'trainer_id': null});
  });

  test('failed write does not touch the bus', () async {
    respond = (o) async => jsonBody({
          'detail': {'code': 'forbidden', 'message': 'x'},
        }, 403);
    await expectLater(api.setGoal('u1', 'gain'), throwsA(isA<ApiException>()));
    expect(touched, isEmpty);
  });

  test('trainerDirectory filters accepting and sorts; profile picks one', () async {
    respond = (o) async => jsonBody([
          {'id': 't2', 'name': 'Zafar', 'bio': '', 'accepting': true, 'gym_id': 'g1'},
          {'id': 't3', 'name': 'Hidden', 'bio': '', 'accepting': false, 'gym_id': null},
          {'id': 't1', 'name': 'Anvar', 'bio': 'b', 'accepting': true, 'gym_id': null},
        ], 200);
    final dir = await api.trainerDirectory().first;
    expect(dir.map((t) => t.id), ['t1', 't2']);
    expect(last().path, '/v1/trainers');
    expect((await api.trainerProfile('t3').first)!.accepting, isFalse);
    expect(await api.trainerProfile('nope').first, isNull);
  });

  test('saveTrainerProfile PUTs, falls back to POST on 404', () async {
    var puts = 0;
    respond = (o) async {
      if (o.method == 'PUT') {
        puts++;
        return jsonBody({
          'detail': {'code': 'not_found', 'message': 'x'},
        }, 404);
      }
      return jsonBody({'id': 't1', 'name': 'A', 'bio': '', 'accepting': true}, 201);
    };
    await api.saveTrainerProfile(const TrainerInfo('t1', 'Anvar', bio: 'salom', accepting: false));
    expect(puts, 1);
    expect(adapter.calls.first.path, '/v1/trainers/t1');
    expect(last().method, 'POST');
    expect(last().path, '/v1/trainers/t1');
    expect(last().data, {'name': 'Anvar', 'bio': 'salom', 'accepting': false});
  });

  test('saveTrainerProfile omits empty name; non-404 error rethrown', () async {
    await api.saveTrainerProfile(const TrainerInfo('t1', '  '));
    expect(last().data.containsKey('name'), isFalse);
    respond = (o) async => jsonBody({
          'detail': {'code': 'forbidden', 'message': 'x'},
        }, 403);
    await expectLater(
      api.saveTrainerProfile(const TrainerInfo('t1', 'A')),
      throwsA(isA<ApiException>()),
    );
    expect(adapter.calls.where((c) => c.method == 'POST'), isEmpty);
  });

  test('ratings keyed by trainer_id; saveRating PUTs', () async {
    respond = (o) async => jsonBody([
          {
            'trainer_id': 't1',
            'stars': 4,
            'comment': 'yaxshi',
            'updated_at': '2026-05-01T09:00:00Z',
          },
        ], 200);
    final map = await api.ratings().first;
    expect(map['t1']!.stars, 4);
    expect(last().path, '/v1/ratings');
    await api.saveRating('t1', 5, 'zo\'r');
    expect(last().method, 'PUT');
    expect(last().path, '/v1/ratings/t1');
    expect(last().data, {'stars': 5, 'comment': 'zo\'r'});
  });

  test('setRole and deleteUser', () async {
    await api.setRole('u1', 'admin');
    expect(last().method, 'PUT');
    expect(last().path, '/v1/users/u1/role');
    expect(last().data, {'role': 'admin'});
    await api.deleteUser('u1');
    expect(last().method, 'DELETE');
    expect(last().path, '/v1/users/u1');
    expect(touched, containsAll(['users', 'trainers', 'user:u1']));
  });
}
