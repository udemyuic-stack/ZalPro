enum Recovery { unknown, recovering, ready }

const recoveryDays = 2;
const recoveryWindowDays = 7;

DateTime? _parseDay(String key) => DateTime.tryParse(key);

int _daysAgo(DateTime today, DateTime day) {
  final a = DateTime(today.year, today.month, today.day);
  final b = DateTime(day.year, day.month, day.day);
  return a.difference(b).inDays;
}

Map<String, Recovery> muscleRecovery(
  Map<String, Set<String>> doneByDay,
  Map<String, String> muscleOfKey,
  DateTime today,
) {
  final last = <String, int>{};
  doneByDay.forEach((dayKey, keys) {
    final day = _parseDay(dayKey);
    if (day == null) return;
    final ago = _daysAgo(today, day);
    if (ago < 0 || ago >= recoveryWindowDays) return;
    for (final k in keys) {
      final m = muscleOfKey[k];
      if (m == null) continue;
      final prev = last[m];
      if (prev == null || ago < prev) last[m] = ago;
    }
  });
  return {
    for (final e in last.entries)
      e.key: e.value < recoveryDays ? Recovery.recovering : Recovery.ready
  };
}

Map<String, int> weeklySets(
  Map<String, Set<String>> doneByDay,
  Map<String, String> muscleOfKey,
  DateTime today,
) {
  final out = <String, int>{};
  doneByDay.forEach((dayKey, keys) {
    final day = _parseDay(dayKey);
    if (day == null) return;
    final ago = _daysAgo(today, day);
    if (ago < 0 || ago >= recoveryWindowDays) return;
    for (final k in keys) {
      final m = muscleOfKey[k];
      if (m != null) out[m] = (out[m] ?? 0) + 1;
    }
  });
  return out;
}
