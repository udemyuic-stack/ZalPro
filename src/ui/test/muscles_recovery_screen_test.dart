import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/exercises.dart';
import 'package:kotta_qani_diet/screens/user/muscles_screen.dart';
import 'package:kotta_qani_diet/theme.dart';

String _day(int ago) {
  final d = DateTime.now().subtract(Duration(days: ago));
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

void main() {
  for (final (w, scale) in [(320.0, 1.5), (360.0, 1.0), (412.0, 1.3)]) {
    testWidgets('recovery marks and counts @ $w x $scale', (t) async {
      t.view.physicalSize = Size(w, 740);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final chest = exercisesFor('chest', const []).first.key;
      final legs = exercisesFor('quads', const []).first.key;
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: MusclesScreen(
          gymDays: const [DateTime.monday, DateTime.thursday],
          onBack: () {},
          history: Stream.value({
            _day(0): {chest},
            _day(4): {legs},
          }),
        ),
      ));
      await t.pump(const Duration(seconds: 3));
      await t.scrollUntilVisible(find.byIcon(Icons.hourglass_bottom_outlined), 300);
      expect(find.byIcon(Icons.hourglass_bottom_outlined), findsWidgets);
      await t.scrollUntilVisible(find.byIcon(Icons.check_circle_outline), 300);
      expect(find.byIcon(Icons.check_circle_outline), findsWidgets);
      expect(t.takeException(), isNull);
    });
  }
}
