import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/streak.dart';

Set<String> days(List<String> keys) => keys.toSet();

void main() {
  const mwf = [1, 3, 5];

  test('empty history: nothing done, streak 0', () {
    final p = weekProgress(<String>{}, '2026-05-13', mwf);
    expect(p.goal, 3);
    expect(p.done, 0);
    expect(p.days, List.filled(7, false));
    expect(p.todayIndex, 2);
    expect(streakWeeks(<String>{}, '2026-05-13', mwf), 0);
  });

  test('week flags map Monday to Sunday and todayIndex follows weekday', () {
    final present = days(['2026-05-11', '2026-05-13', '2026-05-17']);
    final p = weekProgress(present, '2026-05-17', mwf);
    expect(p.days, [true, false, true, false, false, false, true]);
    expect(p.done, 3);
    expect(p.todayIndex, 6);
    expect(p.reached, isTrue);
  });

  test('full previous weeks count, current week below goal does not break', () {
    final present = days([
      '2026-04-27',
      '2026-04-29',
      '2026-05-01',
      '2026-05-04',
      '2026-05-06',
      '2026-05-08',
      '2026-05-11',
    ]);
    expect(streakWeeks(present, '2026-05-13', mwf), 2);
  });

  test('current week reaching the goal adds one', () {
    final present = days([
      '2026-05-04',
      '2026-05-06',
      '2026-05-08',
      '2026-05-11',
      '2026-05-13',
      '2026-05-15',
    ]);
    expect(streakWeeks(present, '2026-05-15', mwf), 2);
  });

  test('broken week stops the streak', () {
    final present = days([
      '2026-04-20',
      '2026-04-22',
      '2026-04-24',
      '2026-04-27',
      '2026-04-29',
      '2026-05-04',
      '2026-05-06',
      '2026-05-08',
    ]);
    expect(streakWeeks(present, '2026-05-13', mwf), 1);
  });

  test('current week exactly at goal minus one is not counted', () {
    final present = days(['2026-05-11', '2026-05-12']);
    expect(streakWeeks(present, '2026-05-14', mwf), 0);
    expect(weekProgress(present, '2026-05-14', mwf).done, 2);
  });

  test('empty gym_days falls back to goal 3', () {
    final present = days(['2026-05-11', '2026-05-12', '2026-05-13']);
    expect(weeklyGoal(const []), 3);
    expect(weekProgress(present, '2026-05-13', const []).goal, 3);
    expect(streakWeeks(present, '2026-05-13', const []), 1);
  });

  test('goal follows gym_days length and is clamped to 1..7', () {
    expect(weeklyGoal(const [2, 4]), 2);
    expect(weeklyGoal(const [1, 2, 3, 4, 5, 6, 7, 1]), 7);
  });

  test('Sunday belongs to the week that started on Monday', () {
    final present = days(['2026-05-11', '2026-05-13', '2026-05-17']);
    expect(streakWeeks(present, '2026-05-17', mwf), 1);
    final monday = weekProgress(present, '2026-05-18', mwf);
    expect(monday.done, 0);
    expect(monday.todayIndex, 0);
    expect(streakWeeks(present, '2026-05-18', mwf), 1);
  });

  test('year boundary: week spanning Dec 29 - Jan 4', () {
    final present = days(['2025-12-29', '2025-12-31', '2026-01-02']);
    final p = weekProgress(present, '2026-01-01', mwf);
    expect(p.days, [true, false, true, false, true, false, false]);
    expect(p.done, 3);
    expect(p.todayIndex, 3);
    expect(streakWeeks(present, '2026-01-05', mwf), 1);
  });

  test('streak across year boundary with consecutive weeks', () {
    final present = days([
      '2025-12-22',
      '2025-12-24',
      '2025-12-26',
      '2025-12-29',
      '2025-12-31',
      '2026-01-02',
      '2026-01-05',
      '2026-01-07',
      '2026-01-09',
    ]);
    expect(streakWeeks(present, '2026-01-12', mwf), 3);
  });

  test('historyFromKey is the Monday 11 weeks before the current week start', () {
    expect(historyFromKey('2026-05-13'), '2026-02-23');
    expect(historyFromKey('2026-05-11'), '2026-02-23');
    expect(historyFromKey('2026-05-17'), '2026-02-23');
    expect(historyFromKey('2026-01-05'), '2025-10-20');
  });

  test('malformed today key degrades to an empty week', () {
    final p = weekProgress(<String>{}, 'bad', mwf);
    expect(p.done, 0);
    expect(streakWeeks(<String>{}, 'bad', mwf), 0);
  });
}
