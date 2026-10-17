const defaultWeeklyGoal = 3;
const historyWeeks = 12;
const _maxStreakWeeks = 520;

class WeekProgress {
  final int goal;
  final int done;
  final List<bool> days;
  final int todayIndex;
  const WeekProgress({
    required this.goal,
    required this.done,
    required this.days,
    required this.todayIndex,
  });

  bool get reached => done >= goal;
}

int weeklyGoal(List<int> gymDays) {
  if (gymDays.isEmpty) return defaultWeeklyGoal;
  return gymDays.length.clamp(1, 7);
}

String dayKeyOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime? _parseKey(String key) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (m == null) return null;
  return DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

DateTime _weekStart(DateTime day) => day.subtract(Duration(days: day.weekday - 1));

String historyFromKey(String today, {int weeks = historyWeeks}) {
  final d = _parseKey(today);
  if (d == null) return today;
  return dayKeyOf(_weekStart(d).subtract(Duration(days: 7 * (weeks - 1))));
}

WeekProgress _week(Set<String> present, DateTime start, int goal, int todayIndex) {
  final days = [
    for (var i = 0; i < 7; i++) present.contains(dayKeyOf(start.add(Duration(days: i)))),
  ];
  return WeekProgress(
    goal: goal,
    done: days.where((p) => p).length,
    days: days,
    todayIndex: todayIndex,
  );
}

WeekProgress weekProgress(Set<String> present, String today, List<int> gymDays) {
  final goal = weeklyGoal(gymDays);
  final d = _parseKey(today);
  if (d == null) {
    return WeekProgress(goal: goal, done: 0, days: List.filled(7, false), todayIndex: 0);
  }
  return _week(present, _weekStart(d), goal, d.weekday - 1);
}

int streakWeeks(Set<String> present, String today, List<int> gymDays) {
  final goal = weeklyGoal(gymDays);
  final d = _parseKey(today);
  if (d == null) return 0;
  final current = _weekStart(d);
  var streak = _week(present, current, goal, 0).reached ? 1 : 0;
  for (var i = 1; i <= _maxStreakWeeks; i++) {
    final start = current.subtract(Duration(days: 7 * i));
    if (!_week(present, start, goal, 0).reached) break;
    streak++;
  }
  return streak;
}
