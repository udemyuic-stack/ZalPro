import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/theme.dart';
import 'package:kotta_qani_diet/widgets/game_fx.dart';

Widget _host(Widget child, {bool reduce = false, double scale = 1.0, Size? size}) =>
    MaterialApp(
      theme: AppTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size ?? const Size(390, 844),
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduce,
        ),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  testWidgets('Burst tugagach onDone chaqiriladi va cheksiz loop yo\'q', (t) async {
    var done = 0;
    await t.pumpWidget(_host(SizedBox(
      width: 300,
      height: 300,
      child: Burst(ms: 600, onDone: () => done++),
    )));
    await t.pump(const Duration(milliseconds: 300));
    expect(done, 0);
    await t.pumpAndSettle();
    expect(done, 1);
  });

  testWidgets('Burst reduce-motion da zarra chizmaydi, onDone darhol', (t) async {
    var done = 0;
    await t.pumpWidget(_host(
      SizedBox(width: 300, height: 300, child: Burst(onDone: () => done++)),
      reduce: true,
    ));
    await t.pump();
    expect(done, 1);
    expect(find.byType(CustomPaint).evaluate().where((e) => e.widget is CustomPaint && (e.widget as CustomPaint).painter != null), isEmpty);
  });

  testWidgets('GlowRing qiymatni 0..1 ga qisadi va bolani markazga qo\'yadi', (t) async {
    await t.pumpWidget(_host(const GlowRing(progress: 1.7, child: Text('42'))));
    await t.pumpAndSettle();
    expect(find.text('42'), findsOneWidget);
    expect(t.getSize(find.byType(GlowRing)), const Size.square(96));
  });

  testWidgets('GlowRing qiymat o\'zgarsa oldingi qiymatdan davom etadi', (t) async {
    await t.pumpWidget(_host(const GlowRing(progress: 0.2)));
    await t.pumpAndSettle();
    await t.pumpWidget(_host(const GlowRing(progress: 0.8)));
    await t.pump(const Duration(milliseconds: 100));
    expect(t.takeException(), isNull);
    await t.pumpAndSettle();
  });

  testWidgets('FlyingCoin oxirida onDone, reduce-motion da darhol', (t) async {
    var done = 0;
    await t.pumpWidget(_host(FlyingCoin(delta: const Offset(80, -200), onDone: () => done++)));
    await t.pumpAndSettle();
    expect(done, 1);
    await t.pumpWidget(const SizedBox());
    var done2 = 0;
    await t.pumpWidget(_host(
      FlyingCoin(delta: const Offset(80, -200), onDone: () => done2++),
      reduce: true,
    ));
    await t.pump();
    expect(done2, 1);
  });

  for (final s in [const Size(360, 740), const Size(412, 915)]) {
    testWidgets('GlowRing overflow yo\'q ${s.width.toInt()} / x1.3', (t) async {
      await t.pumpWidget(_host(
        const GlowRing(progress: 0.5, size: 120, child: Text('Sportchi')),
        scale: 1.3,
        size: s,
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
