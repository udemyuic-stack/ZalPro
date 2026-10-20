import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/subscription.dart';
import 'package:kotta_qani_diet/models/weight_trend.dart';
import 'package:kotta_qani_diet/theme.dart';

double _lin(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _lum(Color c) => 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

double contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  final hi = math.max(x, y), lo = math.min(x, y);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  tearDown(() => AppColors.light = false);

  test('weight trend by goal', () {
    expect(weightTrendOf(-4.2, gainGoal: false), WeightTrend.good);
    expect(weightTrendOf(1.5, gainGoal: false), WeightTrend.bad);
    expect(weightTrendOf(2, gainGoal: true), WeightTrend.good);
    expect(weightTrendOf(-2, gainGoal: true), WeightTrend.bad);
    expect(weightTrendOf(0, gainGoal: true), WeightTrend.flat);
    AppColors.light = false;
    expect(weightTrendColor(WeightTrend.good), AppColors.success);
    expect(weightTrendColor(WeightTrend.bad), AppColors.danger);
  });

  for (final light in [false, true]) {
    test('textFaint contrast >= 4.5 (light=$light)', () {
      AppColors.light = light;
      for (final bg in [AppColors.bg, AppColors.bgDeep, AppColors.card, AppColors.cardHigh]) {
        expect(contrast(AppColors.textFaint, bg), greaterThanOrEqualTo(4.5));
      }
    });
    test('own chat bubble contrast >= 4.5 (light=$light)', () {
      AppColors.light = light;
      expect(contrast(AppColors.onBubbleOwn, AppColors.bubbleOwn), greaterThanOrEqualTo(4.5));
    });
  }

  test('subscription urgency and sort', () {
    final now = DateTime(2026, 10, 17);
    DateTime? d(int n) => DateTime(2026, 10, 17 + n);
    expect(Subscription.urgencyOf(null, now), SubscriptionUrgency.none);
    expect(Subscription.urgencyOf(d(-1), now), SubscriptionUrgency.expired);
    expect(Subscription.urgencyOf(d(0), now), SubscriptionUrgency.soon);
    expect(Subscription.urgencyOf(d(7), now), SubscriptionUrgency.soon);
    expect(Subscription.urgencyOf(d(8), now), SubscriptionUrgency.ok);
    final sorted = Subscription.sortByExpiry<DateTime?>([d(20), null, d(3), d(-5)], (e) => e, now);
    expect(sorted, [d(-5), d(3), d(20), null]);
  });

  testWidgets('chip and segment tap targets >= kTouchTarget', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Column(children: [
            const ChoiceChip(key: Key('chip'), label: Text('A'), selected: false),
            SegmentedButton<int>(
              key: const Key('seg'),
              segments: const [ButtonSegment(value: 0, label: Text('A'))],
              selected: const {0},
            ),
          ]),
        ),
      ),
    );
    expect(
        tester.getSize(find.byKey(const Key('chip'))).height, greaterThanOrEqualTo(kTouchTarget));
    expect(
        tester
            .getSize(find.descendant(
                of: find.byKey(const Key('seg')), matching: find.byType(TextButton)))
            .height,
        greaterThanOrEqualTo(48));
  });
}
