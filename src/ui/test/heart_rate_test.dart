import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/heart_rate.dart';

HeartRateEstimator feed(double Function(double t) value, {int seconds = 30, int fps = 30}) {
  final e = HeartRateEstimator();
  for (var i = 0; i < seconds * fps; i++) {
    e.add((i * 1000 / fps).round(), value(i / fps));
  }
  return e;
}

double Function(double) pulse(double bpm, {double noise = 0.2, int seed = 7}) {
  final rnd = math.Random(seed);
  return (t) => 200 + 2 * math.sin(2 * math.pi * bpm / 60 * t) + 2 * noise * (rnd.nextDouble() * 2 - 1) * 2;
}

void main() {
  test('72 bpm with 20% noise is measured within 2', () {
    final r = feed(pulse(72)).estimate();
    expect(r.quality, HrQuality.good);
    expect(r.bpm, closeTo(72, 2));
  });

  test('150 bpm with 20% noise is measured within 3', () {
    final r = feed(pulse(150)).estimate();
    expect(r.quality, HrQuality.good);
    expect(r.bpm, closeTo(150, 3));
  });

  test('result holds across noise seeds', () {
    for (var seed = 1; seed <= 20; seed++) {
      expect(feed(pulse(72, seed: seed)).estimate().bpm, closeTo(72, 2));
    }
  });

  test('flat signal means no finger', () {
    final r = feed((_) => 200).estimate();
    expect(r.quality, HrQuality.noFinger);
    expect(r.bpm, isNull);
  });

  test('dark frame means no finger', () {
    expect(feed((t) => 20 + math.sin(2 * math.pi * 1.2 * t)).estimate().quality, HrQuality.noFinger);
  });

  test('wandering rhythm is unstable', () {
    final r = feed((t) => 200 + 2 * math.sin(2 * math.pi * (1.2 * t + 0.5 * math.sin(2 * math.pi * 0.4 * t)))).estimate();
    expect(r.quality, HrQuality.unstable);
    expect(r.bpm, isNull);
  });

  test('white noise is unstable', () {
    final rnd = math.Random(3);
    final r = feed((_) => 200 + 2 * (rnd.nextDouble() * 2 - 1)).estimate();
    expect(r.quality, HrQuality.unstable);
  });

  test('too little data is not a result', () {
    final r = feed(pulse(72), seconds: 12).estimate();
    expect(r.bpm, isNull);
  });

  test('progress starts after warmup and completes at 30 seconds', () {
    final e = HeartRateEstimator();
    for (var i = 0; i <= 900; i++) {
      e.add((i * 1000 / 30).round(), 200);
      if (i == 150) {
        expect(e.warmingUp, isTrue);
        expect(e.progress, 0);
      }
      if (i == 600) expect(e.progress, closeTo(0.5, 0.01));
    }
    expect(e.complete, isTrue);
    expect(e.progress, 1);
  });

  test('heart rate is supported on android only', () {
    expect(heartRateSupported(isWeb: false, platform: TargetPlatform.android), isTrue);
    expect(heartRateSupported(isWeb: false, platform: TargetPlatform.iOS), isFalse);
    expect(heartRateSupported(isWeb: true, platform: TargetPlatform.android), isFalse);
  });
}
