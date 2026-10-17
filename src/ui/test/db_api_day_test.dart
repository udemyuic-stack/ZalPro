import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/gym.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/day_api.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';

import 'support/fake_api.dart';

Map<String, dynamic> dayJson({
  List<int> done = const [],
  List<Map<String, dynamic>> extras = const [],
  bool started = false,
  List<String> gymDone = const [],
  int water = 0,
  int? feedback,
}) =>
    {
      'day': '2026-05-01',
      'done': done,
      'extras': extras,
      'gym_started': started,
      'gym_done': gymDone,
      'water': water,
      'feedback': feedback,
    };

void main() {
  late FakeAdapter adapter;
  late DayApi api;
  late ChangeBus bus;
  Future<ResponseBody> Function(RequestOptions) respond = (o) async => jsonBody(dayJson(), 200);
  const uid = 'u1';
  const day = '2026-05-01';

  setUp(() {
    respond = (o) async => jsonBody(dayJson(), 200);
    adapter = FakeAdapter((o) => respond(o));
    final client = ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter);
    bus = ChangeBus();
    api = DayApi(client, bus: bus, activity: PollActivity());
  });

  RequestOptions last() => adapter.calls.last;

  test('doneMeals: maps done list to a set', () async {
    respond = (o) async => jsonBody(dayJson(done: [0, 2]), 200);
    expect(await api.doneMeals(uid, day).first, {0, 2});
    expect(last().method, 'GET');
    expect(last().path, '/v1/users/u1/days/2026-05-01');
  });

  test('four day streams share one request', () async {
    respond = (o) async => jsonBody(dayJson(done: [1], water: 3, started: true), 200);
    final results = await Future.wait([
      api.doneMeals(uid, day).first,
      api.water(uid, day).first,
      api.workout(uid, day).first,
      api.extras(uid, day).first,
    ]);
    expect(results[0], {1});
    expect(results[1], 3);
    expect((results[2] as WorkoutProgress).started, isTrue);
    expect(adapter.calls.length, 1);
  });

  test('extras: sorted by at', () async {
    respond = (o) async => jsonBody(
        dayJson(extras: [
          {'name': 'B', 'grams': 10, 'kcal': 5, 'protein': 1, 'at': 20},
          {'name': 'A', 'grams': 10, 'kcal': 5, 'protein': 1, 'at': 10},
        ]),
        200);
    final list = await api.extras(uid, day).first;
    expect(list.map((e) => e.name), ['A', 'B']);
  });

  test('toggleMeal: PUT /meals/{i} with done', () async {
    await api.toggleMeal(uid, day, 3, true);
    expect(last().method, 'PUT');
    expect(last().path, '/v1/users/u1/days/2026-05-01/meals/3');
    expect(last().data, {'done': true});
  });

  test('addExtra: POST /extras with full body', () async {
    const e = ExtraFood(name: 'Olma', grams: 100, kcal: 52, protein: 0.3, at: 1700000000000);
    await api.addExtra(uid, day, e);
    expect(last().method, 'POST');
    expect(last().path, '/v1/users/u1/days/2026-05-01/extras');
    expect(last().data, {
      'name': 'Olma',
      'grams': 100.0,
      'kcal': 52.0,
      'protein': 0.3,
      'at': 1700000000000,
    });
  });

  test('removeExtra: DELETE /extras/{at}', () async {
    const e = ExtraFood(name: 'Olma', grams: 100, kcal: 52, protein: 0.3, at: 1700000000000);
    await api.removeExtra(uid, day, e);
    expect(last().method, 'DELETE');
    expect(last().path, '/v1/users/u1/days/2026-05-01/extras/1700000000000');
  });

  test('startWorkout: PUT /workout/start', () async {
    await api.startWorkout(uid, day);
    expect(last().method, 'PUT');
    expect(last().path, '/v1/users/u1/days/2026-05-01/workout/start');
  });

  test('workout: feedback is read from the day', () async {
    respond = (o) async => jsonBody(dayJson(started: true, feedback: 3), 200);
    expect((await api.workout(uid, day).first).feedback, 3);
    respond = (o) async => jsonBody(dayJson(feedback: 9), 200);
    expect((await api.workout(uid, day).first).feedback, isNull);
  });

  test('setFeedback: PUT /workout/feedback with rating', () async {
    await api.setFeedback(uid, day, 2);
    expect(last().method, 'PUT');
    expect(last().path, '/v1/users/u1/days/2026-05-01/workout/feedback');
    expect(last().data, {'rating': 2});
  });

  test('feedbackWeek: maps day to rating and skips empty days', () async {
    respond = (o) async => jsonBody([
          {...dayJson(feedback: 1), 'day': '2026-05-01'},
          {...dayJson(), 'day': '2026-05-02'},
          {...dayJson(feedback: 3), 'day': '2026-05-03'},
        ], 200);
    final week = await api.feedbackWeek(uid).first;
    expect(week, {'2026-05-01': 1, '2026-05-03': 3});
    expect(last().method, 'GET');
    expect(last().path, '/v1/users/u1/days');
    expect(last().queryParameters.keys, containsAll(['from', 'to']));
  });

  test('toggleExercise: key is percent-encoded', () async {
    await api.toggleExercise(uid, day, 'Shtanga bilan siqish', true);
    expect(last().method, 'PUT');
    expect(last().path, contains('/workout/exercises/Shtanga%20bilan%20siqish'));
    expect(last().data, {'done': true});
    await api.toggleExercise(uid, day, 'c:abc', false);
    expect(last().path, contains('/workout/exercises/c%3Aabc'));
    expect(last().data, {'done': false});
  });

  test('setWater: PUT /water with glasses', () async {
    await api.setWater(uid, day, 5);
    expect(last().method, 'PUT');
    expect(last().path, '/v1/users/u1/days/2026-05-01/water');
    expect(last().data, {'glasses': 5});
  });

  test('write pushes returned DayOut to live listeners', () async {
    var water = 0;
    respond = (o) async {
      if (o.method == 'PUT') water = 7;
      return jsonBody(dayJson(water: water), 200);
    };
    final seen = <int>[];
    final sub = api.water(uid, day).listen(seen.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen, [0]);
    await api.setWater(uid, day, 7);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen.first, 0);
    expect(seen.last, 7);
    expect(seen, contains(7));
    await sub.cancel();
  });

  test('write with no listeners does not throw', () async {
    await api.setWater(uid, day, 2);
    expect(last().method, 'PUT');
  });
}
