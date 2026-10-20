import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/pose_frame.dart';
import 'package:kotta_qani_diet/models/position_check.dart';
import 'package:kotta_qani_diet/models/rep_counter.dart';
import 'package:kotta_qani_diet/widgets/pose_overlay.dart';

Joint j(double x, double y, [double l = 0.9]) => Joint(x, y, l);

PoseFrame pushupFrame({double elbowX = 100, double wristY = 300}) => PoseFrame({
      PoseKey.leftShoulder: j(100, 100),
      PoseKey.rightShoulder: j(300, 100),
      PoseKey.leftElbow: j(elbowX, 200),
      PoseKey.rightElbow: j(300, 200),
      PoseKey.leftWrist: j(100, wristY),
      PoseKey.rightWrist: j(300, wristY),
    }, width: 400, height: 400);

PoseFrame squatFrame({double kneeX = 200}) => PoseFrame({
      PoseKey.leftHip: j(100, 100),
      PoseKey.rightHip: j(300, 100),
      PoseKey.leftKnee: j(kneeX == 200 ? 100 : kneeX, 200),
      PoseKey.rightKnee: j(300, 200),
      PoseKey.leftAnkle: j(100, 300),
      PoseKey.rightAnkle: j(300, 300),
    }, width: 400, height: 400);

void main() {
  test('null frame searches', () {
    expect(evaluatePosition('pushup', null).state, PositionState.searching);
  });

  test('pushup straight arms ready', () {
    final c = evaluatePosition('pushup', pushupFrame());
    expect(c.state, PositionState.ready);
    expect(c.item(PositionItemKind.armsStraight)!.ok, isTrue);
    expect(c.item(PositionItemKind.plank), isNull);
  });

  test('pushup bent elbow adjusts', () {
    final c = evaluatePosition('pushup', pushupFrame(elbowX: 170));
    expect(c.state, PositionState.adjusting);
    expect(c.bad, contains(PoseKey.leftElbow));
  });

  test('pushup wrists above elbows fails order', () {
    final c = evaluatePosition('pushup', pushupFrame(wristY: 150));
    expect(c.item(PositionItemKind.order)!.ok, isFalse);
  });

  test('missing joint searches', () {
    final f = PoseFrame({
      ...pushupFrame().joints,
      PoseKey.leftWrist: j(100, 300, 0.1),
    }, width: 400, height: 400);
    expect(evaluatePosition('pushup', f).state, PositionState.searching);
  });

  test('joint on edge fails inFrame', () {
    final f = PoseFrame({
      ...pushupFrame().joints,
      PoseKey.leftWrist: j(2, 300),
    }, width: 400, height: 400);
    expect(evaluatePosition('pushup', f).item(PositionItemKind.inFrame)!.ok, isFalse);
  });

  test('squat standing ready, bent knee adjusts', () {
    expect(evaluatePosition('squat', squatFrame()).state, PositionState.ready);
    expect(evaluatePosition('squat', squatFrame(kneeX: 160)).state, PositionState.adjusting);
  });

  test('pullup uses arm rules', () {
    expect(evaluatePosition('pullup', pushupFrame()).item(PositionItemKind.order), isNull);
  });

  group('PositionHold', () {
    test('locks after 2 s of continuous ready', () {
      final h = PositionHold();
      for (var ms = 0; ms < 2000; ms += 100) {
        expect(h.update(true, Duration(milliseconds: ms)), isFalse);
      }
      expect(h.update(true, const Duration(seconds: 2)), isTrue);
      expect(h.progress(const Duration(seconds: 3)), 1);
    });

    test('short dropout within grace keeps hold', () {
      final h = PositionHold();
      h.update(true, Duration.zero);
      h.update(true, const Duration(milliseconds: 1000));
      h.update(false, const Duration(milliseconds: 1200));
      expect(h.update(true, const Duration(milliseconds: 2000)), isTrue);
    });

    test('long dropout restarts hold', () {
      final h = PositionHold();
      h.update(true, Duration.zero);
      h.update(true, const Duration(milliseconds: 1000));
      h.update(false, const Duration(milliseconds: 1100));
      h.update(false, const Duration(milliseconds: 1500));
      expect(h.update(true, const Duration(milliseconds: 2100)), isFalse);
      expect(h.progress(const Duration(milliseconds: 2100)), 0);
    });
  });

  for (final w in [360.0, 412.0]) {
    testWidgets('PoseOverlay paints @ $w', (t) async {
      t.view.physicalSize = Size(w, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final f = pushupFrame(elbowX: 170);
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: PoseOverlay(frame: f, check: evaluatePosition('pushup', f)),
          ),
        ),
      ));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: PoseOverlay(frame: null, check: PositionCheck.empty)),
      ));
      expect(t.takeException(), isNull);
    });
  }
}
