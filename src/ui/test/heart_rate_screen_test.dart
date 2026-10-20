import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/screens/user/heart_rate_screen.dart';
import 'package:kotta_qani_diet/services/hr_camera.dart';

class FakeHr implements HrCameraSource {
  int stops = 0;
  void Function(int, double)? sink;

  @override
  Future<void> start(void Function(int timeMs, double red) onSample) async => sink = onSample;

  @override
  Future<void> stop() async => stops++;
}

void main() {
  testWidgets('shows disclaimer, finishes at 30s and releases the camera', (tester) async {
    final fake = FakeHr();
    await tester.pumpWidget(MaterialApp(home: HeartRateScreen(sourceBuilder: () => fake)));
    await tester.pump();
    expect(find.byKey(const ValueKey('hr-disclaimer')), findsOneWidget);
    for (var i = 0; i <= 900; i++) {
      fake.sink!((i * 1000 / 30).round(), 200);
    }
    await tester.pump();
    await tester.pump();
    expect(fake.stops, 1);
    expect(find.byKey(const ValueKey('hr-retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('hr-disclaimer')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('leaving the screen releases the camera', (tester) async {
    final fake = FakeHr();
    await tester.pumpWidget(MaterialApp(home: HeartRateScreen(sourceBuilder: () => fake)));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(fake.stops, 1);
  });

  testWidgets('idle without a finger stops after 30s', (tester) async {
    final fake = FakeHr();
    await tester.pumpWidget(MaterialApp(home: HeartRateScreen(sourceBuilder: () => fake)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 31));
    expect(fake.stops, 1);
    expect(find.byKey(const ValueKey('hr-fail')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
