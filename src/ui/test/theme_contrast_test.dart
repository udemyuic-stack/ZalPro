import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/theme.dart';

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _ratio(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  tearDown(() => AppColors.light = false);

  for (final light in [false, true]) {
    final name = light ? 'yorug' : 'qorong\'i';
    test('$name: matn kontrasti >= 4.5', () {
      AppColors.light = light;
      for (final bg in [AppColors.bg, AppColors.card, AppColors.cardHigh]) {
        expect(_ratio(AppColors.text, bg), greaterThanOrEqualTo(4.5));
        expect(_ratio(AppColors.textMuted, bg), greaterThanOrEqualTo(4.5));
        expect(_ratio(AppColors.accentText, bg), greaterThanOrEqualTo(light ? 4.5 : 3.0));
      }
    });

    test('$name: karta fondan ajraladi', () {
      AppColors.light = light;
      expect(_ratio(AppColors.card, AppColors.bg), greaterThan(1.05));
    });
  }
}
