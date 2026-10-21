import 'exercises.dart';

const _primaryWeight = 1.0;
const _secondaryWeight = 0.5;
const _strongScore = 3.0;

Map<String, double> muscleScores(Iterable<(Exercise, int)> filled) {
  final scores = <String, double>{};
  for (final (exercise, sets) in filled) {
    if (sets <= 0) continue;
    scores.update(exercise.muscle, (v) => v + sets * _primaryWeight,
        ifAbsent: () => sets * _primaryWeight);
    for (final id in exercise.also) {
      scores.update(id, (v) => v + sets * _secondaryWeight,
          ifAbsent: () => sets * _secondaryWeight);
    }
  }
  return scores;
}

int workedLevel(double score) {
  if (score <= 0) return 0;
  return score >= _strongScore ? 2 : 1;
}

Map<String, int> workedLevels(Map<String, double> scores) => {
      for (final e in scores.entries)
        if (workedLevel(e.value) > 0) e.key: workedLevel(e.value),
    };
