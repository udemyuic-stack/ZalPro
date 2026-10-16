import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/theme.dart';

double _lin(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _lum(Color c) => 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

double contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  final hi = math.max(x, y), lo = math.min(x, y);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    group('kontrast $mode', () {
      setUp(() => AppColors.light = light);
      tearDown(() => AppColors.light = false);

      test('matn / fon >= 4.5', () {
        expect(contrast(AppColors.text, AppColors.bg), greaterThanOrEqualTo(4.5));
        expect(contrast(AppColors.text, AppColors.card), greaterThanOrEqualTo(4.5));
      });

      test('textMuted / fon va karta >= 4.5', () {
        expect(contrast(AppColors.textMuted, AppColors.bg), greaterThanOrEqualTo(4.5));
        expect(contrast(AppColors.textMuted, AppColors.card), greaterThanOrEqualTo(4.5));
        expect(contrast(AppColors.textMuted, AppColors.cardHigh), greaterThanOrEqualTo(4.5));
      });

      test('textFaint / fon va karta >= 4.5', () {
        expect(contrast(AppColors.textFaint, AppColors.bg), greaterThanOrEqualTo(4.5));
        expect(contrast(AppColors.textFaint, AppColors.card), greaterThanOrEqualTo(4.5));
      });

      test('accent va accentText / fon va karta >= 4.5', () {
        expect(contrast(AppColors.accent, AppColors.bg), greaterThanOrEqualTo(4.5));
        expect(contrast(AppColors.accentText, AppColors.card), greaterThanOrEqualTo(4.5));
      });

      test('onAccentFill / accentFill >= 4.5', () {
        expect(
          contrast(AppColors.onAccentFill, AppColors.accentFill),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('onAccent / accent >= 4.5', () {
        expect(contrast(AppColors.onAccent, AppColors.accent), greaterThanOrEqualTo(4.5));
      });

      test('holat ranglari / fon >= 4.5', () {
        for (final c in [AppColors.success, AppColors.warning, AppColors.danger]) {
          expect(contrast(c, AppColors.bg), greaterThanOrEqualTo(4.5));
        }
      });
    });
  }
}
