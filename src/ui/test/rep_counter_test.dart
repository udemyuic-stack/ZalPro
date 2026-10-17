import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/rep_counter.dart';

void feed(RepCounter c, List<double> angles, {int each = 4}) {
  for (final a in angles) {
    for (var i = 0; i < each; i++) {
      c.add(a);
    }
  }
}

void main() {
  test('full squat 170 -> 90 -> 170 counts one rep', () {
    final c = RepCounter();
    feed(c, [170, 90, 170]);
    expect(c.count, 1);
  });

  test('shallow squat 170 -> 120 -> 170 does not count', () {
    final c = RepCounter();
    feed(c, [170, 120, 170]);
    expect(c.count, 0);
    expect(c.isDown, isFalse);
  });

  test('single noisy frame does not add a rep', () {
    final c = RepCounter();
    for (final a in <double>[170, 170, 170, 60, 170, 170, 170]) {
      c.add(a);
    }
    expect(c.count, 0);
  });

  test('null angles are skipped', () {
    final c = RepCounter();
    feed(c, [170, 90]);
    for (var i = 0; i < 10; i++) {
      c.add(null);
    }
    expect(c.isDown, isTrue);
    feed(c, [170]);
    expect(c.count, 1);
  });

  test('ten reps count ten and reset clears', () {
    final c = RepCounter();
    for (var i = 0; i < 10; i++) {
      feed(c, [170, 90]);
    }
    feed(c, [170]);
    expect(c.count, 10);
    c.reset();
    expect(c.count, 0);
    expect(c.isDown, isFalse);
  });

  group('kneeAngle', () {
    Leg leg(Joint hip, Joint knee, Joint ankle) => (hip, knee, ankle);

    test('straight leg is about 180 and right angle is 90', () {
      expect(kneeAngle(leg(const Joint(0, 0, 1), const Joint(0, 1, 1), const Joint(0, 2, 1))),
          closeTo(180, 0.01));
      expect(kneeAngle(leg(const Joint(0, 0, 1), const Joint(0, 1, 1), const Joint(1, 1, 1))),
          closeTo(90, 0.01));
    });

    test('low likelihood or zero length gives null', () {
      expect(kneeAngle(leg(const Joint(0, 0, 1), const Joint(0, 1, 0.2), const Joint(0, 2, 1))),
          isNull);
      expect(
          kneeAngle(leg(const Joint(0, 1, 1), const Joint(0, 1, 1), const Joint(0, 2, 1))), isNull);
    });

    test('best leg picks the more confident side', () {
      final bent = leg(const Joint(0, 0, 0.9), const Joint(0, 1, 0.9), const Joint(1, 1, 0.9));
      final hidden = leg(const Joint(0, 0, 0.3), const Joint(0, 1, 0.3), const Joint(0, 2, 0.3));
      expect(bestKneeAngle(hidden, bent), closeTo(90, 0.01));
      expect(bestKneeAngle(bent, hidden), closeTo(90, 0.01));
      expect(bestKneeAngle(hidden, hidden), isNull);
    });
  });

  test('only Android native shows the entry', () {
    expect(repCounterSupported(isWeb: false, platform: TargetPlatform.android), isTrue);
    expect(repCounterSupported(isWeb: true, platform: TargetPlatform.android), isFalse);
    expect(repCounterSupported(isWeb: false, platform: TargetPlatform.iOS), isFalse);
  });
}
