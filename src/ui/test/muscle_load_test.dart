import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/exercises.dart';
import 'package:kotta_qani_diet/models/muscle_load.dart';

Exercise ex(String muscle, List<String> also) =>
    Exercise('Bench', muscle, '3 × 10', '', also: also);

void main() {
  test('primary counts full and secondary half per filled set', () {
    final scores = muscleScores([
      (ex('chest', ['triceps']), 2)
    ]);
    expect(scores['chest'], 2.0);
    expect(scores['triceps'], 1.0);
  });

  test('zero sets give no score', () {
    expect(
        muscleScores([
          (ex('chest', ['triceps']), 0)
        ]),
        isEmpty);
  });

  test('scores add up across exercises', () {
    final scores = muscleScores([
      (ex('chest', ['triceps']), 1),
      (ex('triceps', []), 2)
    ]);
    expect(scores['triceps'], 2.5);
  });

  test('workedLevel thresholds', () {
    expect(workedLevel(0), 0);
    expect(workedLevel(1.0), 1);
    expect(workedLevel(2.9), 1);
    expect(workedLevel(3.0), 2);
  });

  test('workedLevels drops zero levels', () {
    expect(workedLevels({'chest': 3.0, 'back': 1.0, 'legs': 0.0}),
        {'chest': 2, 'back': 1});
  });
}
