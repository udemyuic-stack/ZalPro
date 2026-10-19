import '../../models/leaderboard.dart';
import 'api_service.dart';

class LeaderboardApi extends ApiService {
  LeaderboardApi(super.client, {super.bus, super.activity});

  static const _every = Duration(seconds: 60);
  static const _tag = 'leaderboard';

  Stream<Leaderboard> leaderboard() => poll(() async {
        final json = await client.getJson('/v1/leaderboard');
        return Leaderboard.fromJson(json);
      }, _every, {_tag}, key: 'leaderboard');
}
