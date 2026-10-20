import 'package:flutter/material.dart';
import '../theme.dart';

enum WeightTrend { good, bad, flat }

WeightTrend weightTrendOf(double diff, {required bool gainGoal}) {
  if (diff.abs() < 0.05) return WeightTrend.flat;
  final good = gainGoal ? diff > 0 : diff < 0;
  return good ? WeightTrend.good : WeightTrend.bad;
}

Color weightTrendColor(WeightTrend trend) => switch (trend) {
      WeightTrend.good => AppColors.success,
      WeightTrend.bad => AppColors.danger,
      WeightTrend.flat => AppColors.textMuted,
    };
