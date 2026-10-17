import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/screens/user/today_screen.dart';
import 'package:kotta_qani_diet/theme.dart';

Future<List<int>> pump(WidgetTester tester, int g, {double width = 360}) async {
  final calls = <int>[];
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.current(),
    home: Scaffold(
      body: WaterCard(
        uid: 'u',
        day: '2026-10-17',
        source: Stream.value(g),
        setGlasses: (v) async => calls.add(v),
      ),
    ),
  ));
  await tester.pump();
  return calls;
}

void main() {
  testWidgets('plus and minus change by one glass', (tester) async {
    final calls = await pump(tester, 5);
    await tester.tap(find.byKey(const Key('water-plus')));
    await tester.tap(find.byKey(const Key('water-minus')));
    expect(calls, [6, 4]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('minus disabled at 0', (tester) async {
    final calls = await pump(tester, 0);
    await tester.tap(find.byKey(const Key('water-minus')));
    expect(calls, isEmpty);
  });

  testWidgets('plus disabled at 30', (tester) async {
    final calls = await pump(tester, 30);
    await tester.tap(find.byKey(const Key('water-plus')));
    expect(calls, isEmpty);
  });

  testWidgets('more than 8 glasses shows true count and ml', (tester) async {
    await pump(tester, 10);
    expect(find.text('10'), findsOneWidget);
    expect(find.textContaining('2500'), findsOneWidget);
  });

  testWidgets('tile tap keeps old behaviour', (tester) async {
    final calls = await pump(tester, 3);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^5 ')).first);
    expect(calls, [5]);
  });
}
