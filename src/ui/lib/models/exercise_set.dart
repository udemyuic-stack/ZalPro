import '../services/api/json_helpers.dart';

class ExerciseSet {
  final int setNo;
  final double? weightKg;
  final int? reps;

  const ExerciseSet({required this.setNo, this.weightKg, this.reps});

  factory ExerciseSet.fromJson(Map<String, dynamic> json) => ExerciseSet(
        setNo: jsonInt(json['set_no']),
        weightKg: json['weight_kg'] is num ? (json['weight_kg'] as num).toDouble() : null,
        reps: json['reps'] is num ? (json['reps'] as num).toInt() : null,
      );

  Map<String, dynamic> toJson() => {'set_no': setNo, 'weight_kg': weightKg, 'reps': reps};

  bool get isEmpty => weightKg == null && reps == null;
}

String formatKg(double kg) => kg == kg.roundToDouble() ? kg.toInt().toString() : kg.toString();

String previousLabel(ExerciseSet? set) {
  if (set == null || set.isEmpty) return '—';
  final kg = set.weightKg == null ? '—' : formatKg(set.weightKg!);
  final reps = set.reps == null ? '—' : '${set.reps}';
  return '$kg × $reps';
}
