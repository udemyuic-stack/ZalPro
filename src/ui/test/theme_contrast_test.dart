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
  tearDown(() {
    AppColors.light = false;
    AppColors.palette = AppPalette.graphite;
  });
  paletteTests();
  contrastReportTests();

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

    test('$name: yashil BMI chipi matni >= 4.5', () {
      AppColors.light = light;
      for (final base in [AppColors.card, AppColors.bg]) {
        final chip = Color.alphaBlend(AppColors.success.withValues(alpha: 0.12), base);
        expect(_ratio(AppColors.successText, chip), greaterThanOrEqualTo(4.5));
      }
    });

    test('$name: karta fondan ajraladi', () {
      AppColors.light = light;
      expect(_ratio(AppColors.card, AppColors.bg), greaterThan(1.05));
    });
  }
}

void paletteTests() {
  for (final pal in [AppPalette.emerald, AppPalette.amber]) {
    test('${pal.name}: kontrast >= 4.5 va karta fondan ajraladi', () {
      AppColors.light = false;
      AppColors.palette = pal;
      for (final bg in [AppColors.bg, AppColors.card, AppColors.cardHigh]) {
        expect(_ratio(AppColors.text, bg), greaterThanOrEqualTo(4.5));
        expect(_ratio(AppColors.textMuted, bg), greaterThanOrEqualTo(4.5));
        expect(_ratio(AppColors.accentText, bg), greaterThanOrEqualTo(4.5));
      }
      expect(_ratio(AppColors.onAccentFill, AppColors.accentFill), greaterThanOrEqualTo(4.5));
      expect(_ratio(AppColors.card, AppColors.bg), greaterThan(1.05));
      AppColors.palette = AppPalette.graphite;
    });
  }

  test('yorug' 'da palitra e\'tiborga olinmaydi', () {
    AppColors.light = true;
    AppColors.palette = AppPalette.emerald;
    expect(AppColors.bg, const Color(0xFFEFF1FA));
    AppColors.palette = AppPalette.graphite;
    AppColors.light = false;
  });
}

// Hisobot: 4 mavzu x juftliklar. Hozirgi pastlar "known" ro'yxatda; yangi past chiqsa test yiqiladi.
const _knownBelowAA = {
  'graphite: violet/card',
  'emerald: violet/card',
  'amber: violet/card',
  'light: success/bg',
  'light: warning/bg',
  'light: mint/card',
  'light: gold/card',
  'light: sky/card',
  'light: violet/card',
  'light: coral/card',
};
const _knownBelowLarge = {
  'light: mint/card',
  'light: gold/card',
  'light: sky/card',
  'light: coral/card',
};

void contrastReportTests() {
  final themes = <String, (bool, AppPalette)>{
    'graphite': (false, AppPalette.graphite),
    'emerald': (false, AppPalette.emerald),
    'amber': (false, AppPalette.amber),
    'light': (true, AppPalette.graphite),
  };

  test('kontrast hisoboti: AA dan pastlar faqat known ro\'yxatda', () {
    final belowAA = <String>[];
    final belowLarge = <String>[];
    final buf = StringBuffer();
    themes.forEach((name, cfg) {
      AppColors.light = cfg.$1;
      AppColors.palette = cfg.$2;
      final pairs = <String, double>{
        'text/bg': _ratio(AppColors.text, AppColors.bg),
        'textMuted/card': _ratio(AppColors.textMuted, AppColors.card),
        'textFaint/card': _ratio(AppColors.textFaint, AppColors.card),
        'accentText/bg': _ratio(AppColors.accentText, AppColors.bg),
        'onAccentFill/accentFill': _ratio(AppColors.onAccentFill, AppColors.accentFill),
        'success/bg': _ratio(AppColors.success, AppColors.bg),
        'danger/bg': _ratio(AppColors.danger, AppColors.bg),
        'warning/bg': _ratio(AppColors.warning, AppColors.bg),
        'mint/card': _ratio(AppColors.mint, AppColors.card),
        'gold/card': _ratio(AppColors.gold, AppColors.card),
        'sky/card': _ratio(AppColors.sky, AppColors.card),
        'violet/card': _ratio(AppColors.violet, AppColors.card),
        'coral/card': _ratio(AppColors.coral, AppColors.card),
      };
      buf.writeln('== $name ==');
      pairs.forEach((pair, r) {
        final key = '$name: $pair';
        buf.writeln('  ${pair.padRight(24)} ${r.toStringAsFixed(2)}');
        if (r < 4.5) belowAA.add('$key (${r.toStringAsFixed(2)})');
        if (r < 3.0) belowLarge.add('$key (${r.toStringAsFixed(2)})');
      });
    });
    // ignore: avoid_print
    print(buf);
    // ignore: avoid_print
    print('AA (<4.5) dan past:\n  ${belowAA.join('\n  ')}');
    // ignore: avoid_print
    print('Katta matn/ikonka (<3.0) dan past:\n  ${belowLarge.join('\n  ')}');

    String keyOf(String e) => e.substring(0, e.indexOf(' ('));
    expect(belowAA.map(keyOf).where((k) => !_knownBelowAA.contains(k)), isEmpty,
        reason: 'yangi <4.5 juftlik');
    expect(belowLarge.map(keyOf).where((k) => !_knownBelowLarge.contains(k)), isEmpty,
        reason: 'yangi <3.0 juftlik');
  });
}
