import '../../models/game.dart';
import 'api_error.dart';
import 'api_service.dart';
import 'json_helpers.dart';

class GameApi extends ApiService {
  GameApi(super.client, {super.bus, super.activity});

  static const _every = Duration(seconds: 60);
  static const _tag = 'game';

  Future<GameCatalog> catalog() async =>
      GameCatalog.fromJson(await client.getJson('/v1/game/catalog'));

  Stream<GameChallenges> challenges() => poll(() async {
        return GameChallenges.fromJson(await client.getJson('/v1/game/challenges'));
      }, _every, {_tag}, key: 'game-challenges');

  Stream<GameMe> me() => poll(() async {
        return GameMe.fromJson(await client.getJson('/v1/game/me'));
      }, _every, {_tag}, key: 'game-me');

  Stream<GameLeaderboard> leaderboard({String period = 'week', String? exercise}) => poll(
        () async {
          final json = await client.getJson('/v1/game/leaderboard', query: {
            'period': period,
            if (exercise != null) 'exercise': exercise,
          });
          return GameLeaderboard.fromJson(json);
        },
        _every,
        {_tag, 'leaderboard'},
        key: 'game-lb-$period-${exercise ?? ''}',
      );

  Future<GameSessionResult> submit(GameSessionDraft draft) async {
    final json = await bus.after(
      client.request<Map<String, dynamic>>('POST', '/v1/game/sessions', data: draft.toJson()),
      const [_tag, 'leaderboard'],
    );
    if (json == null || json.isEmpty) {
      throw const ApiException(code: 'empty_response', message: '');
    }
    return GameSessionResult.fromJson(json);
  }

  Future<List<ChallengeStepAdmin>> challengeSteps() async {
    final rows = await client.getList('/v1/game/challenge-steps');
    return [for (final row in jsonMaps(rows)) ChallengeStepAdmin.fromJson(row)];
  }

  Future<void> addChallengeStep({
    required String exercise,
    required int target,
    required int coins,
    required String muscle,
  }) =>
      write(
        'POST',
        '/v1/game/challenge-steps',
        {'exercise': exercise, 'target': target, 'coins': coins, 'muscle': muscle},
        const [_tag],
      );

  Future<void> updateChallengeStep(
    String id, {
    required String exercise,
    required int target,
    required int coins,
    required String muscle,
  }) =>
      write(
        'PATCH',
        '/v1/game/challenge-steps/${Uri.encodeComponent(id)}',
        {'exercise': exercise, 'target': target, 'coins': coins, 'muscle': muscle},
        const [_tag],
      );

  Future<void> removeChallengeStep(String id) =>
      write('DELETE', '/v1/game/challenge-steps/${Uri.encodeComponent(id)}', null, const [_tag]);
}
