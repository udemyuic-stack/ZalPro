import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/models/stats.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';
import 'package:kotta_qani_diet/services/api/stats_api.dart';

import 'support/fake_api.dart';

AppUser trainer(String id) => AppUser(id: id, name: 'T $id', email: '', role: 'admin');

void main() {
  late FakeAdapter adapter;
  late StatsApi api;
  Future<ResponseBody> Function(RequestOptions) respond = (o) async => jsonBody([], 200);

  setUp(() {
    respond = (o) async => jsonBody([], 200);
    adapter = FakeAdapter((o) => respond(o));
    final client = ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter);
    api = StatsApi(client, bus: ChangeBus(), activity: PollActivity());
  });

  test('trainerStats: one request, server numbers map onto TrainerStat', () async {
    respond = (o) async => jsonBody([
          {
            'trainer_id': 't1',
            'name': 'T t1',
            'client_count': 4,
            'tracked_days': 7,
            'meals_done': 10,
            'meals_expected': 20,
            'adherence': 0.5,
            'plan_coverage': 0.75,
            'reply_rate': 1,
            'progress_rate': null,
            'messages_sent': 9,
            'score': 71,
            'stars': 4,
            'average_rating': null,
            'rating_count': 0,
          },
        ], 200);
    final stats = await api.trainerStats([trainer('t1'), trainer('t2')]);
    expect(adapter.calls.length, 1);
    expect(adapter.calls.single.path, '/v1/stats/trainers');
    expect(adapter.calls.single.queryParameters, {'days': statsDays});
    final a = stats.first;
    expect(a.clientCount, 4);
    expect(a.planCoverage, 0.75);
    expect(a.replyRate, 1.0);
    expect(a.adherence, 0.5);
    expect(a.progressRate, isNull);
    expect(a.messagesSent, 9);
    expect(a.score, 71);
    expect(a.stars, 4);
    expect(a.hasClientDetail, false);
    final b = stats.last;
    expect(b.clientCount, 0);
    expect(b.score, isNull);
    expect(b.stars, isNull);
  });
}
