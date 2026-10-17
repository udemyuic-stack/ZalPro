import '../services/api/json_helpers.dart';

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String name;
  final int points;
  final int activeDays;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.name,
    required this.points,
    required this.activeDays,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        rank: jsonInt(j['rank']),
        userId: jsonString(j['user_id']),
        name: jsonString(j['name']),
        points: jsonInt(j['points']),
        activeDays: jsonInt(j['active_days']),
      );
}

class LeaderboardMe {
  final int rank;
  final int points;
  final int activeDays;

  const LeaderboardMe({required this.rank, required this.points, required this.activeDays});

  factory LeaderboardMe.fromJson(Map<String, dynamic> j) => LeaderboardMe(
        rank: jsonInt(j['rank']),
        points: jsonInt(j['points']),
        activeDays: jsonInt(j['active_days']),
      );
}

class Leaderboard {
  final int periodDays;
  final List<LeaderboardEntry> top;
  final LeaderboardMe? me;

  const Leaderboard({required this.periodDays, required this.top, this.me});

  factory Leaderboard.fromJson(Map<String, dynamic> j) {
    final me = j['me'];
    return Leaderboard(
      periodDays: jsonInt(j['period_days'], 30),
      top: [for (final row in jsonMaps(j['top'])) LeaderboardEntry.fromJson(row)],
      me: me is Map<String, dynamic> ? LeaderboardMe.fromJson(me) : null,
    );
  }
}
