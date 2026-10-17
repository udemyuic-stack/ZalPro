import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/photo.dart';
import 'package:kotta_qani_diet/widgets/photo_compare_sheet.dart';

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

ProgressPhoto _photo(String id, double weight, {int day = 1}) =>
    ProgressPhoto(id: id, bytes: _png, takenAt: DateTime(2026, 1, day), weight: weight);

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)));

double _factor(WidgetTester tester) =>
    tester.widget<Align>(find.byKey(const Key('compare-before-clip'))).widthFactor!;

void main() {
  testWidgets('slider starts at 50 percent and follows drag within 0..1', (tester) async {
    await tester.pumpWidget(_host(SizedBox(
      width: 300,
      height: 400,
      child: PhotoCompareSlider(before: _photo('a', 80), after: _photo('b', 78, day: 2)),
    )));
    expect(_factor(tester), 0.5);
    await tester.drag(find.byKey(const Key('compare-handle')), const Offset(60, 0));
    await tester.pump();
    expect(_factor(tester), inExclusiveRange(0.55, 0.75));
    await tester.drag(find.byKey(const Key('compare-handle')), const Offset(-1000, 0));
    await tester.pump();
    expect(_factor(tester), 0);
    await tester.tapAt(tester.getTopRight(find.byType(PhotoCompareSlider)) + const Offset(-2, 100));
    await tester.pump();
    expect(_factor(tester), greaterThan(0.95));
  });

  testWidgets('body defaults to oldest and newest, shows weight delta, allows same photo',
      (tester) async {
    final photos = [_photo('a', 80), _photo('b', 79, day: 2), _photo('c', 77.5, day: 3)];
    await tester.pumpWidget(_host(PhotoCompareBody(photos: photos)));
    expect(find.byKey(const Key('compare-delta')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('compare-delta'))).data, contains('−2.5'));
    await tester.tap(find.byKey(const Key('compare-after-0')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('compare-delta'))).data, contains('0'));
    await tester.tap(find.byKey(const Key('compare-before-1')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('compare-delta'))).data, contains('+1'));
  });

  testWidgets('delta hidden when a weight is unknown', (tester) async {
    await tester
        .pumpWidget(_host(PhotoCompareBody(photos: [_photo('a', 0), _photo('b', 70, day: 2)])));
    expect(find.byKey(const Key('compare-delta')), findsNothing);
  });

  testWidgets('no overflow at 360 px', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(_host(PhotoCompareBody(photos: [_photo('a', 80), _photo('b', 70, day: 2)])));
    expect(tester.takeException(), isNull);
  });

  test('weightDelta formats sign', () {
    expect(weightDelta(_photo('a', 80), _photo('b', 78)), contains('−2'));
    expect(weightDelta(_photo('a', 78), _photo('b', 80)), contains('+2'));
    expect(weightDelta(_photo('a', 0), _photo('b', 80)), isNull);
  });
}
