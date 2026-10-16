import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/exercises.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/catalog_api.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';

import 'support/fake_api.dart';

void main() {
  late FakeAdapter adapter;
  late CatalogApi api;
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
    api = CatalogApi(client, bus: bus, activity: PollActivity());
  });

  RequestOptions last() => adapter.calls.last;

  Food food({String id = ''}) =>
      Food(id: id, name: 'Guruch', kcal: 130, protein: 2.7, fat: 0.3, carbs: 28);

  test('foods: GET /v1/foods maps rows', () async {
    respond = (o) async => jsonBody([
          {'id': 'f1', 'name': 'Tuxum', 'kcal': 155, 'protein': 13, 'fat': 11, 'carbs': 1.1},
        ], 200);
    final list = await api.foods().first;
    expect(last().path, '/v1/foods');
    expect(list.single.name, 'Tuxum');
    expect(list.single.kcal, 155);
  });

  test('saveFood: empty id POSTs, id PUTs, both touch foods', () async {
    await api.saveFood(food());
    expect(last().method, 'POST');
    expect(last().path, '/v1/foods');
    expect(last().data['name'], 'Guruch');
    await api.saveFood(food(id: 'f9'));
    expect(last().method, 'PUT');
    expect(last().path, '/v1/foods/f9');
    expect(touched, ['foods', 'foods']);
  });

  test('deleteFood: DELETE with no body', () async {
    respond = (o) async => ResponseBody.fromString('', 204);
    await api.deleteFood('f1');
    expect(last().method, 'DELETE');
    expect(last().path, '/v1/foods/f1');
    expect(touched, ['foods']);
  });

  test('customExercises: drops rows with unknown muscle', () async {
    respond = (o) async => jsonBody([
          {'id': 'e1', 'name': 'Tortish', 'muscle': 'back', 'sets': '3 × 10', 'tip': 't'},
          {'id': 'e2', 'name': 'Noma\'lum', 'muscle': 'zzz', 'sets': '', 'tip': ''},
        ], 200);
    final list = await api.customExercises().first;
    expect(last().path, '/v1/exercises');
    expect(list.map((e) => e.id), ['e1']);
  });

  test('saveExercise: POST carries base, PUT does not', () async {
    const created = Exercise('Yangi', 'chest', '3 × 10', 'tip', base: 'Asl', level: 'pro');
    await api.saveExercise(created);
    expect(last().method, 'POST');
    expect(last().path, '/v1/exercises');
    expect(last().data['base'], 'Asl');
    expect(last().data['level'], 'pro');
    expect(last().data.containsKey('createdAt'), isFalse);
    const edited = Exercise('Yangi', 'chest', '3 × 10', 'tip', id: 'e7', base: 'Asl');
    await api.saveExercise(edited);
    expect(last().method, 'PUT');
    expect(last().path, '/v1/exercises/e7');
    expect(last().data.containsKey('base'), isFalse);
    expect(touched, ['exercises', 'exercises']);
  });

  test('deleteExercise: DELETE', () async {
    respond = (o) async => ResponseBody.fromString('', 204);
    await api.deleteExercise('e1');
    expect(last().method, 'DELETE');
    expect(last().path, '/v1/exercises/e1');
  });

  test('setProgram: reads user, replaces one muscle, PATCHes whole map', () async {
    respond = (o) async {
      if (o.method == 'GET') {
        return jsonBody({
          'id': 'u1',
          'program': {
            'chest': ['a'],
            'back': ['b'],
          },
        }, 200);
      }
      return jsonBody({}, 200);
    };
    await api.setProgram('u1', 'chest', ['x', 'y']);
    expect(adapter.calls.first.method, 'GET');
    expect(adapter.calls.first.path, '/v1/users/u1');
    expect(last().method, 'PATCH');
    expect(last().data, {
      'program': {
        'chest': ['x', 'y'],
        'back': ['b'],
      },
    });
    expect(touched, ['users', 'user:u1']);
  });

  test('setProgram: empty keys removes the muscle', () async {
    respond = (o) async {
      if (o.method == 'GET') {
        return jsonBody({
          'id': 'u1',
          'program': {
            'chest': ['a'],
            'back': ['b'],
          },
        }, 200);
      }
      return jsonBody({}, 200);
    };
    await api.setProgram('u1', 'chest', []);
    expect(last().data, {
      'program': {
        'back': ['b'],
      },
    });
  });

  test('setProgram: user without program gets a fresh map', () async {
    respond = (o) async => jsonBody({'id': 'u1'}, 200);
    await api.setProgram('u1', 'legs', ['k']);
    expect(last().data, {
      'program': {
        'legs': ['k'],
      },
    });
  });

  test('plans: GET /v1/plans', () async {
    respond = (o) async => jsonBody([
          {
            'id': 'p1',
            'title': 'Massa',
            'note': '',
            'meals': [],
            'forbidden': ['shakar']
          },
        ], 200);
    final list = await api.plans().first;
    expect(last().path, '/v1/plans');
    expect(list.single.title, 'Massa');
    expect(list.single.forbidden, ['shakar']);
  });

  test('plan: 404 yields null', () async {
    respond = (o) async => jsonBody({
          'detail': {'code': 'not_found', 'message': 'yo\'q'},
        }, 404);
    expect(await api.plan('p1').first, isNull);
    expect(last().path, '/v1/plans/p1');
  });

  test('plan: 200 maps to Plan', () async {
    respond = (o) async => jsonBody({'id': 'p1', 'title': 'Massa', 'meals': []}, 200);
    final p = await api.plan('p1').first;
    expect(p!.id, 'p1');
  });

  test('savePlan: POST returns server id and touches plans', () async {
    respond = (o) async => jsonBody({'id': 'p5'}, 201);
    final id = await api.savePlan(Plan(title: 'Yangi', meals: []));
    expect(id, 'p5');
    expect(last().method, 'POST');
    expect(last().path, '/v1/plans');
    expect(touched, ['plans']);
  });

  test('savePlan: PUT returns same id and touches plan tag', () async {
    final id = await api.savePlan(Plan(id: 'p2', title: 'Eski', meals: []));
    expect(id, 'p2');
    expect(last().method, 'PUT');
    expect(last().path, '/v1/plans/p2');
    expect(touched, ['plans', 'plan:p2']);
  });

  test('deletePlan: DELETE touches both tags', () async {
    respond = (o) async => ResponseBody.fromString('', 204);
    await api.deletePlan('p3');
    expect(last().method, 'DELETE');
    expect(last().path, '/v1/plans/p3');
    expect(touched, ['plans', 'plan:p3']);
  });
}
