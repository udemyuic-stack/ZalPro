import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/screens/admin/admin_home.dart';
import 'package:kotta_qani_diet/screens/user/today_screen.dart';
import 'package:kotta_qani_diet/theme.dart';
import 'package:kotta_qani_diet/widgets/ui.dart';

void setSize(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> pumpWater(
  WidgetTester tester, {
  required int g,
  required Future<void> Function(int) set,
  double width = 360,
}) async {
  setSize(tester, width);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.current(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: WaterCard(uid: 'u', day: '2026-10-17', source: Stream.value(g), setGlasses: set),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('water shows the new value before the call completes', (tester) async {
    final gate = Completer<void>();
    await pumpWater(tester, g: 5, set: (_) => gate.future);
    await tester.tap(find.byKey(const Key('water-plus')));
    await tester.pump();
    expect(find.text('6'), findsOneWidget);
    expect(find.text('5'), findsNothing);
    gate.complete();
    await tester.pump();
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('water rolls back and shows a snack when the call fails', (tester) async {
    await pumpWater(tester, g: 5, set: (_) async => throw Exception('boom'));
    await tester.tap(find.byKey(const Key('water-plus')));
    await tester.pump();
    await tester.pump();
    expect(find.text('5'), findsOneWidget);
    expect(find.text('6'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('water glass tiles are at least 48x48 at 360 px', (tester) async {
    await pumpWater(tester, g: 3, set: (_) async {});
    for (var i = 1; i <= 8; i++) {
      final size = tester.getSize(find.bySemanticsLabel(RegExp('^$i ')).first);
      expect(size.width, greaterThanOrEqualTo(48), reason: 'tile $i');
      expect(size.height, greaterThanOrEqualTo(48), reason: 'tile $i');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppSegmented is at least 52 high and reports taps', (tester) async {
    setSize(tester, 360);
    var value = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.current(),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, set) => AppSegmented<int>(
            key: const Key('seg'),
            segments: const [
              AppSegment(value: 0, label: 'A'),
              AppSegment(value: 1, label: 'B'),
              AppSegment(value: 2, label: 'C'),
            ],
            selected: value,
            onChanged: (v) => set(() => value = v),
          ),
        ),
      ),
    ));
    expect(tester.getSize(find.byKey(const Key('seg'))).height, greaterThanOrEqualTo(52));
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(value, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin header keeps the title on one line at 360 px', (tester) async {
    setSize(tester, 360);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.current(),
      home: Scaffold(
        appBar: AdminAppBar(title: 'Ovqatlanish rejalari', isOwner: true, onMore: () {}),
      ),
    ));
    await tester.pump();
    final title = tester.getSize(find.text('Ovqatlanish rejalari'));
    expect(title.height, lessThan(30));
    for (final tip in ['Skaner', "Ro'yxatdan o'tish QR kodi", "Ko'proq"]) {
      final size = tester.getSize(find.byTooltip(tip));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });
}
