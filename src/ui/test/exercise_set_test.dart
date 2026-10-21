import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/exercise_set.dart';

void main() {
  test('previousLabel formats kg and reps', () {
    expect(previousLabel(const ExerciseSet(setNo: 1, weightKg: 60, reps: 10)), '60 × 10');
    expect(previousLabel(const ExerciseSet(setNo: 1, weightKg: 62.5, reps: 8)), '62.5 × 8');
  });

  test('previousLabel is a dash without data', () {
    expect(previousLabel(null), '—');
    expect(previousLabel(const ExerciseSet(setNo: 1)), '—');
    expect(previousLabel(const ExerciseSet(setNo: 1, reps: 12)), '— × 12');
  });

  test('fromJson and toJson round trip', () {
    final s = ExerciseSet.fromJson({'set_no': 2, 'weight_kg': 45.5, 'reps': null});
    expect(s.setNo, 2);
    expect(s.weightKg, 45.5);
    expect(s.reps, isNull);
    expect(s.toJson(), {'set_no': 2, 'weight_kg': 45.5, 'reps': null});
  });
}
