import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/muscle_recovery.dart';

void main() {
  final today = DateTime(2026, 10, 20, 15);
  const keyOf = {'a': 'chest', 'b': 'chest', 'c': 'legs'};

  test('no data gives empty maps', () {
    expect(muscleRecovery({}, keyOf, today), isEmpty);
    expect(weeklySets({}, keyOf, today), isEmpty);
  });

  test('today and yesterday recovering, two days ago ready', () {
    final r = muscleRecovery({
      '2026-10-20': {'a'},
      '2026-10-19': {'c'},
      '2026-10-18': {'c'},
    }, keyOf, today);
    expect(r['chest'], Recovery.recovering);
    expect(r['legs'], Recovery.recovering);
    final r2 = muscleRecovery({
      '2026-10-18': {'c'}
    }, keyOf, today);
    expect(r2['legs'], Recovery.ready);
  });

  test('latest day wins and window is 7 days', () {
    final r = muscleRecovery({
      '2026-10-20': {'a'},
      '2026-10-10': {'a'},
      '2026-10-13': {'c'},
      '2026-10-14': {'c'},
    }, keyOf, today);
    expect(r['chest'], Recovery.recovering);
    expect(r['legs'], Recovery.ready);
    expect(
        muscleRecovery({
          '2026-10-13': {'c'}
        }, keyOf, today),
        isEmpty);
  });

  test('unknown keys, bad days and future days are ignored', () {
    final r = muscleRecovery({
      'bad': {'a'},
      '2026-10-25': {'a'},
      '2026-10-20': {'zzz'},
    }, keyOf, today);
    expect(r, isEmpty);
  });

  test('weekly sets count per muscle', () {
    final w = weeklySets({
      '2026-10-20': {'a', 'b', 'c'},
      '2026-10-19': {'a'},
      '2026-10-01': {'a'},
    }, keyOf, today);
    expect(w, {'chest': 3, 'legs': 1});
  });
}
