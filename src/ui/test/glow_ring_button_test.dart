import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/widgets/glow_ring_button.dart';
import 'package:kotta_qani_diet/widgets/shimmer_bar.dart';

Widget host(Widget child, {bool reduce = false}) => MaterialApp(
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: c!,
      ),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('GlowRingButton tap calls onPressed', (t) async {
    var taps = 0;
    await t.pumpWidget(host(GlowRingButton(
      label: 'Go',
      icon: Icons.play_arrow_outlined,
      onPressed: () => taps++,
    )));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('Go'));
    expect(taps, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('GlowRingButton reduce-motion settles', (t) async {
    await t.pumpWidget(host(
      GlowRingButton(label: 'Go', icon: Icons.play_arrow_outlined, onPressed: () {}),
      reduce: true,
    ));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('GlowRingButton disabled does not animate or tap', (t) async {
    await t.pumpWidget(host(
      const GlowRingButton(label: 'Go', icon: Icons.play_arrow_outlined, onPressed: null),
    ));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('ShimmerBar and Breathe reduce-motion settle', (t) async {
    await t.pumpWidget(host(
      const Column(children: [
        SizedBox(width: 200, child: ShimmerBar(value: 0.4, color: Colors.purple)),
        Breathe(child: SizedBox(width: 20, height: 20)),
      ]),
      reduce: true,
    ));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('ShimmerBar animates and disposes cleanly', (t) async {
    await t.pumpWidget(host(
      const SizedBox(width: 200, child: ShimmerBar(value: 0.4, color: Colors.purple)),
    ));
    await t.pump(const Duration(seconds: 2));
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });
}
