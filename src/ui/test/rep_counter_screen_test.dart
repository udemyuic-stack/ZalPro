import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/screens/user/rep_counter_screen.dart';
import 'package:kotta_qani_diet/services/rep_camera.dart';

class _FakeCamera implements RepCameraSource {
  _FakeCamera({this.error});
  final Object? error;
  void Function(double?)? onAngle;
  bool stopped = false;

  @override
  Future<void> start(void Function(double? kneeAngle) onAngle) async {
    if (error != null) throw error!;
    this.onAngle = onAngle;
  }

  @override
  Widget preview() => const SizedBox(key: ValueKey('fake-preview'));

  @override
  Future<void> stop() async => stopped = true;
}

Widget _app(_FakeCamera cam) => MaterialApp(home: RepCounterScreen(sourceBuilder: () => cam));

void main() {
  testWidgets('denied permission shows guidance without crashing', (tester) async {
    await tester.pumpWidget(_app(_FakeCamera(error: const RepCameraDenied())));
    await tester.pump();
    expect(find.text('Kameraga ruxsat berilmagan'), findsOneWidget);
    expect(find.byKey(const ValueKey('rep-toggle')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('other camera failure shows the unavailable state', (tester) async {
    await tester.pumpWidget(_app(_FakeCamera(error: const RepCameraUnavailable())));
    await tester.pump();
    expect(find.text('Kamera ochilmadi'), findsOneWidget);
  });

  testWidgets('counts reps only after start, reset zeroes, stops camera on dispose',
      (tester) async {
    final cam = _FakeCamera();
    await tester.pumpWidget(_app(cam));
    await tester.pump();
    expect(find.byKey(const ValueKey('fake-preview')), findsOneWidget);

    void squat() {
      for (final a in <double>[170, 170, 170, 90, 90, 90, 170, 170, 170]) {
        cam.onAngle!(a);
      }
    }

    squat();
    await tester.pump();
    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rep-toggle')));
    await tester.pump();
    squat();
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rep-reset')));
    await tester.pump();
    expect(find.text('0'), findsOneWidget);

    cam.onAngle!(null);
    await tester.pump();
    expect(find.byKey(const ValueKey('rep-hint')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    expect(cam.stopped, isTrue);
  });

  testWidgets('fits 360 px', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_FakeCamera()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
