import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/game.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/game_api.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';

import 'support/fake_api.dart';

void main() {
  late FakeAdapter adapter;
  late GameApi api;
  Future<ResponseBody> Function(RequestOptions) respond = (o) async => jsonBody({}, 200);

  setUp(() {
    respond = (o) async => jsonBody({}, 200);
    adapter = FakeAdapter((o) => respond(o));
    final client = ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter);
    api = GameApi(client, bus: ChangeBus(), activity: PollActivity());
  });

  RequestOptions last() => adapter.calls.last;

  test('GameMe.fromJson va progress', () {
    final me = GameMe.fromJson({
      'coins': 120,
      'xp': 700,
      'level': 1,
      'level_xp': 500,
      'next_level_xp': 1500,
      'streak_days': 3,
      'sessions_total': 9,
      'best_sets': {'pushup': 30},
    });
    expect(me.levelProgress, closeTo(0.2, 1e-9));
    expect(me.xpToNext, 800);
    expect(me.bestSets['pushup'], 30);
  });

  test('GameMe oxirgi darajada progress 1 va keyingi yo\'q', () {
    final me = GameMe.fromJson({'xp': 13000, 'level': 5, 'level_xp': 12000, 'next_level_xp': null});
    expect(me.levelProgress, 1);
    expect(me.xpToNext, 0);
  });

  test('GameMe bo\'sh javobda xatosiz', () {
    final me = GameMe.fromJson({});
    expect(me.levelProgress, 1);
    expect(me.bestSets, isEmpty);
  });

  test('draft UTC ISO va maydon nomlari', () {
    final d = GameSessionDraft(
      id: 'abc',
      exercise: 'squat',
      reps: 20,
      durationS: 40,
      visibilityPct: 95,
      startedAt: DateTime.utc(2026, 10, 20, 8),
    );
    expect(d.toJson(), {
      'id': 'abc',
      'exercise': 'squat',
      'reps': 20,
      'duration_s': 40,
      'visibility_pct': 95,
      'started_at': '2026-10-20T08:00:00.000Z',
    });
  });

  test('submit: POST /v1/game/sessions va natija', () async {
    respond = (o) async => jsonBody({
          'id': 'abc',
          'status': 'flagged',
          'coins': 0,
          'xp': 0,
          'streak_bonus': 0,
          'streak_days': 1,
          'total_coins': 10,
          'total_xp': 40,
          'level': 0,
          'level_up': false,
        }, 201);
    final r = await api.submit(GameSessionDraft(
      id: 'abc',
      exercise: 'squat',
      reps: 20,
      durationS: 40,
      visibilityPct: 95,
      startedAt: DateTime.utc(2026, 10, 20),
    ));
    expect(last().method, 'POST');
    expect(last().path, '/v1/game/sessions');
    expect(r.flagged, isTrue);
    expect(r.totalXp, 40);
  });

  test('leaderboard: period va exercise so\'rovga o\'tadi', () async {
    respond = (o) async => jsonBody({
          'period': 'month',
          'exercise': 'pushup',
          'top': [
            {'rank': 1, 'user_id': 'u', 'name': 'Ali', 'xp': 10, 'reps': 25},
          ],
          'me': {'rank': 1, 'xp': 10, 'reps': 25},
        }, 200);
    final lb = await api.leaderboard(period: 'month', exercise: 'pushup').first;
    expect(last().path, '/v1/game/leaderboard');
    expect(last().queryParameters, {'period': 'month', 'exercise': 'pushup'});
    expect(lb.top.single.reps, 25);
    expect(lb.me?.rank, 1);
  });

  test('challenges: zanjir va mushaklar', () async {
    respond = (o) async => jsonBody({
          'step': 1,
          'progress': 4,
          'finished': false,
          'muscles': {'arms': 1, 'chest': 0, 'legs': 0},
          'steps': [
            {'index': 0, 'exercise': 'pullup', 'target': 20, 'coins': 20, 'muscle': 'arms', 'state': 'done'},
            {'index': 1, 'exercise': 'pushup', 'target': 10, 'coins': 15, 'muscle': 'chest', 'state': 'current'},
            {'index': 2, 'exercise': 'squat', 'target': 20, 'coins': 15, 'muscle': 'legs', 'state': 'locked'},
          ],
        }, 200);
    final c = await api.challenges().first;
    expect(last().path, '/v1/game/challenges');
    expect(c.muscles.arms, 1);
    expect(c.current?.exercise, 'pushup');
    expect(c.steps.map((s) => s.locked), [false, false, true]);
  });

  test('GameSessionResult.challenge', () {
    final r = GameSessionResult.fromJson({
      'id': 'a',
      'challenge': {
        'step': 0,
        'exercise': 'pullup',
        'target': 20,
        'progress': 20,
        'completed': true,
        'coins': 20,
        'muscle': 'arms',
        'finished': false,
      },
    });
    expect(r.challenge?.completed, isTrue);
    expect(r.challenge?.coins, 20);
    expect(GameSessionResult.fromJson({'id': 'b'}).challenge, isNull);
  });

  test('catalog: rule qidirish', () async {
    respond = (o) async => jsonBody({
          'exercises': [
            {'key': 'pushup', 'xp_per_rep': 8, 'max_reps_per_minute': 60},
          ],
          'levels': [0, 500],
          'daily_xp_cap': 600,
          'streak_bonuses': [
            {'days': 3, 'coins': 10},
          ],
        }, 200);
    final c = await api.catalog();
    expect(c.rule('pushup')?.maxRepsPerMinute, 60);
    expect(c.rule('pushup')?.xpPerRep, 8);
    expect(c.dailyXpCap, 600);
    expect(c.rule('nope'), isNull);
    expect(c.streakBonuses.single.coins, 10);
  });
}
