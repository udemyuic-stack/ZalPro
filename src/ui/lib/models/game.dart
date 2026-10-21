import '../services/api/json_helpers.dart';

class GameExerciseRule {
  final String key;
  final int xpPerRep;
  final int maxRepsPerMinute;

  const GameExerciseRule({
    required this.key,
    required this.xpPerRep,
    required this.maxRepsPerMinute,
  });

  factory GameExerciseRule.fromJson(Map<String, dynamic> j) => GameExerciseRule(
        key: jsonString(j['key']),
        xpPerRep: jsonInt(j['xp_per_rep']),
        maxRepsPerMinute: jsonInt(j['max_reps_per_minute']),
      );
}

class GameStreakBonus {
  final int days;
  final int coins;

  const GameStreakBonus({required this.days, required this.coins});

  factory GameStreakBonus.fromJson(Map<String, dynamic> j) =>
      GameStreakBonus(days: jsonInt(j['days']), coins: jsonInt(j['coins']));
}

class GameCatalog {
  final List<GameExerciseRule> exercises;
  final List<int> levels;
  final int dailyXpCap;
  final List<GameStreakBonus> streakBonuses;

  const GameCatalog({
    required this.exercises,
    required this.levels,
    required this.dailyXpCap,
    required this.streakBonuses,
  });

  factory GameCatalog.fromJson(Map<String, dynamic> j) => GameCatalog(
        exercises: [for (final r in jsonMaps(j['exercises'])) GameExerciseRule.fromJson(r)],
        levels: jsonInts(j['levels']),
        dailyXpCap: jsonInt(j['daily_xp_cap']),
        streakBonuses: [for (final r in jsonMaps(j['streak_bonuses'])) GameStreakBonus.fromJson(r)],
      );

  GameExerciseRule? rule(String key) {
    for (final r in exercises) {
      if (r.key == key) return r;
    }
    return null;
  }
}

class ChallengeResult {
  final int step;
  final String exercise;
  final int target;
  final int progress;
  final bool completed;
  final int coins;
  final String muscle;
  final bool finished;

  const ChallengeResult({
    required this.step,
    required this.exercise,
    required this.target,
    required this.progress,
    required this.completed,
    required this.coins,
    required this.muscle,
    required this.finished,
  });

  factory ChallengeResult.fromJson(Map<String, dynamic> j) => ChallengeResult(
        step: jsonInt(j['step']),
        exercise: jsonString(j['exercise']),
        target: jsonInt(j['target']),
        progress: jsonInt(j['progress']),
        completed: jsonBool(j['completed']),
        coins: jsonInt(j['coins']),
        muscle: jsonString(j['muscle']),
        finished: jsonBool(j['finished']),
      );
}

class ChallengeStep {
  final int index;
  final String exercise;
  final int target;
  final int coins;
  final String muscle;
  final String state;

  const ChallengeStep({
    required this.index,
    required this.exercise,
    required this.target,
    required this.coins,
    required this.muscle,
    required this.state,
  });

  bool get done => state == 'done';
  bool get current => state == 'current';
  bool get locked => state == 'locked';

  factory ChallengeStep.fromJson(Map<String, dynamic> j) => ChallengeStep(
        index: jsonInt(j['index']),
        exercise: jsonString(j['exercise']),
        target: jsonInt(j['target']),
        coins: jsonInt(j['coins']),
        muscle: jsonString(j['muscle']),
        state: jsonString(j['state'], 'locked'),
      );
}

class ChallengeStepAdmin {
  final String id;
  final int position;
  final String exercise;
  final int target;
  final int coins;
  final String muscle;

  const ChallengeStepAdmin({
    required this.id,
    required this.position,
    required this.exercise,
    required this.target,
    required this.coins,
    required this.muscle,
  });

  factory ChallengeStepAdmin.fromJson(Map<String, dynamic> j) => ChallengeStepAdmin(
        id: jsonString(j['id']),
        position: jsonInt(j['position']),
        exercise: jsonString(j['exercise']),
        target: jsonInt(j['target']),
        coins: jsonInt(j['coins']),
        muscle: jsonString(j['muscle']),
      );
}

const challengeMuscles = ['arms', 'chest', 'legs'];
const challengeTargetMax = 10000;
const challengeCoinsMax = 100000;

class MuscleLevels {
  final int arms;
  final int chest;
  final int legs;

  const MuscleLevels({this.arms = 0, this.chest = 0, this.legs = 0});

  factory MuscleLevels.fromJson(Map<String, dynamic> j) =>
      MuscleLevels(arms: jsonInt(j['arms']), chest: jsonInt(j['chest']), legs: jsonInt(j['legs']));
}

class GameChallenges {
  final int step;
  final int progress;
  final bool finished;
  final MuscleLevels muscles;
  final List<ChallengeStep> steps;

  const GameChallenges({
    required this.step,
    required this.progress,
    required this.finished,
    required this.muscles,
    required this.steps,
  });

  ChallengeStep? get current {
    for (final s in steps) {
      if (s.current) return s;
    }
    return null;
  }

  factory GameChallenges.fromJson(Map<String, dynamic> j) => GameChallenges(
        step: jsonInt(j['step']),
        progress: jsonInt(j['progress']),
        finished: jsonBool(j['finished']),
        muscles: MuscleLevels.fromJson(j['muscles'] is Map<String, dynamic>
            ? j['muscles'] as Map<String, dynamic>
            : const {}),
        steps: [for (final r in jsonMaps(j['steps'])) ChallengeStep.fromJson(r)],
      );
}

class GameSessionDraft {
  final String id;
  final String exercise;
  final int reps;
  final int durationS;
  final int visibilityPct;
  final DateTime startedAt;

  const GameSessionDraft({
    required this.id,
    required this.exercise,
    required this.reps,
    required this.durationS,
    required this.visibilityPct,
    required this.startedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'exercise': exercise,
        'reps': reps,
        'duration_s': durationS,
        'visibility_pct': visibilityPct,
        'started_at': startedAt.toUtc().toIso8601String(),
      };
}

class GameSessionResult {
  final String id;
  final String status;
  final int coins;
  final int xp;
  final int streakBonus;
  final int streakDays;
  final int totalCoins;
  final int totalXp;
  final int level;
  final bool levelUp;
  final ChallengeResult? challenge;

  const GameSessionResult({
    required this.id,
    required this.status,
    required this.coins,
    required this.xp,
    required this.streakBonus,
    required this.streakDays,
    required this.totalCoins,
    required this.totalXp,
    required this.level,
    required this.levelUp,
    this.challenge,
  });

  bool get flagged => status == 'flagged';

  factory GameSessionResult.fromJson(Map<String, dynamic> j) => GameSessionResult(
        id: jsonString(j['id']),
        status: jsonString(j['status'], 'valid'),
        coins: jsonInt(j['coins']),
        xp: jsonInt(j['xp']),
        streakBonus: jsonInt(j['streak_bonus']),
        streakDays: jsonInt(j['streak_days']),
        totalCoins: jsonInt(j['total_coins']),
        totalXp: jsonInt(j['total_xp']),
        level: jsonInt(j['level']),
        levelUp: jsonBool(j['level_up']),
        challenge: j['challenge'] is Map<String, dynamic>
            ? ChallengeResult.fromJson(j['challenge'] as Map<String, dynamic>)
            : null,
      );
}

class GameMe {
  final int coins;
  final int xp;
  final int level;
  final int levelXp;
  final int? nextLevelXp;
  final int streakDays;
  final int sessionsTotal;
  final Map<String, int> bestSets;

  const GameMe({
    this.coins = 0,
    this.xp = 0,
    this.level = 0,
    this.levelXp = 0,
    this.nextLevelXp,
    this.streakDays = 0,
    this.sessionsTotal = 0,
    this.bestSets = const {},
  });

  double get levelProgress {
    final next = nextLevelXp;
    if (next == null) return 1;
    final span = next - levelXp;
    if (span <= 0) return 1;
    return ((xp - levelXp) / span).clamp(0.0, 1.0);
  }

  int get xpToNext {
    final next = nextLevelXp;
    return next == null ? 0 : (next - xp).clamp(0, next);
  }

  factory GameMe.fromJson(Map<String, dynamic> j) {
    final best = j['best_sets'];
    return GameMe(
      coins: jsonInt(j['coins']),
      xp: jsonInt(j['xp']),
      level: jsonInt(j['level']),
      levelXp: jsonInt(j['level_xp']),
      nextLevelXp: j['next_level_xp'] is num ? jsonInt(j['next_level_xp']) : null,
      streakDays: jsonInt(j['streak_days']),
      sessionsTotal: jsonInt(j['sessions_total']),
      bestSets: best is Map
          ? {
              for (final e in best.entries)
                if (e.value is num) e.key.toString(): (e.value as num).toInt(),
            }
          : const {},
    );
  }
}

class GameEntry {
  final int rank;
  final String userId;
  final String name;
  final int xp;
  final int reps;

  const GameEntry({
    required this.rank,
    required this.userId,
    required this.name,
    required this.xp,
    required this.reps,
  });

  factory GameEntry.fromJson(Map<String, dynamic> j) => GameEntry(
        rank: jsonInt(j['rank']),
        userId: jsonString(j['user_id']),
        name: jsonString(j['name']),
        xp: jsonInt(j['xp']),
        reps: jsonInt(j['reps']),
      );
}

class GameRank {
  final int rank;
  final int xp;
  final int reps;

  const GameRank({required this.rank, required this.xp, required this.reps});

  factory GameRank.fromJson(Map<String, dynamic> j) =>
      GameRank(rank: jsonInt(j['rank']), xp: jsonInt(j['xp']), reps: jsonInt(j['reps']));
}

class GameLeaderboard {
  final String period;
  final String? exercise;
  final List<GameEntry> top;
  final GameRank? me;

  const GameLeaderboard({required this.period, this.exercise, required this.top, this.me});

  factory GameLeaderboard.fromJson(Map<String, dynamic> j) {
    final me = j['me'];
    return GameLeaderboard(
      period: jsonString(j['period'], 'week'),
      exercise: jsonStringOrNull(j['exercise']),
      top: [for (final r in jsonMaps(j['top'])) GameEntry.fromJson(r)],
      me: me is Map<String, dynamic> ? GameRank.fromJson(me) : null,
    );
  }
}
