import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/gym.dart';
import 'package:kotta_qani_diet/widgets/workout_feedback.dart';

Widget host(Widget child, {double width = 360}) => MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
    );

void main() {
  test('parseFeedback keeps only 1..3', () {
    expect([0, 1, 2, 3, 4, null, '2'].map(parseFeedback), [null, 1, 2, 3, null, null, null]);
  });

  test('WorkoutProgress.fromJson reads feedback', () {
    final p = WorkoutProgress.fromJson({
      'gym_started': true,
      'gym_done': ['a'],
      'feedback': 2,
    });
    expect(p.feedback, 2);
    expect(WorkoutProgress.fromJson({'gym_started': true, 'gym_done': []}).feedback, isNull);
  });

  test('feedback window crosses month and year boundaries', () {
    final days = feedbackWindow(DateTime(2026, 1, 3));
    expect(days.first, DateTime(2025, 12, 28));
    expect(days.last, DateTime(2026, 1, 3));
    expect(days.map(feedbackKey).toSet().length, 7);
  });

  testWidgets('picker marks selection and reports taps', (tester) async {
    int? picked;
    int? selected;
    await tester.pumpWidget(host(StatefulBuilder(
      builder: (context, set) => WorkoutFeedbackPicker(
        selected: selected,
        onSelect: (v) => set(() {
          picked = v;
          selected = v;
        }),
      ),
    )));
    expect(find.byKey(const Key('feedback-1')), findsOneWidget);
    expect(find.byKey(const Key('feedback-2')), findsOneWidget);
    expect(find.byKey(const Key('feedback-3')), findsOneWidget);
    await tester.tap(find.byKey(const Key('feedback-3')));
    await tester.pump();
    expect(picked, 3);
    await tester.tap(find.byKey(const Key('feedback-1')));
    await tester.pump();
    expect(picked, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker buttons are at least 52 px tall', (tester) async {
    await tester.pumpWidget(host(WorkoutFeedbackPicker(selected: null, onSelect: (_) {})));
    for (final v in feedbackValues) {
      expect(tester.getSize(find.byKey(Key('feedback-$v'))).height, greaterThanOrEqualTo(52));
    }
  });

  testWidgets('strip shows 7 cells, grey for empty days', (tester) async {
    final today = DateTime(2026, 5, 7);
    await tester.pumpWidget(host(WorkoutFeedbackStrip(
      uid: 'u1',
      today: today,
      source: Stream.value({'2026-05-07': 3, '2026-05-05': 1, '2026-04-30': 2}),
    )));
    await tester.pump();
    final days = feedbackWindow(today);
    expect(days.length, 7);
    expect(days.first, DateTime(2026, 5, 1));
    for (final d in days) {
      expect(find.byKey(Key('feedback-cell-${feedbackKey(d)}')), findsOneWidget);
    }
    Color colorOf(String key) {
      final box = tester.widget<Container>(find.byKey(Key('feedback-cell-$key')));
      return (box.decoration! as BoxDecoration).color!;
    }

    expect(colorOf('2026-05-07'), feedbackColor(3));
    expect(colorOf('2026-05-05'), feedbackColor(1));
    expect(colorOf('2026-05-06'), isNot(feedbackColor(1)));
    expect(colorOf('2026-05-06'), isNot(feedbackColor(2)));
    expect(colorOf('2026-05-06'), isNot(feedbackColor(3)));
    expect(find.byKey(const Key('feedback-cell-2026-04-30')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
