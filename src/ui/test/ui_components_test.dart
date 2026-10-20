import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/theme.dart';
import 'package:kotta_qani_diet/widgets/ui.dart';

Widget _host(Widget child, {double scale = 1.0, bool reduce = false}) => MaterialApp(
      theme: AppTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduce,
        ),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  testWidgets('Heading oddiy harfda va urg\'u qismi bilan', (t) async {
    await t.pumpWidget(_host(const Heading("Zal holati", accent: "bugun")));
    final rt = t.widget<RichText>(find.byType(RichText).last);
    expect(rt.text.toPlainText(), 'Zal holati bugun');
  });

  testWidgets('BentoTile onTap bilan kamida kTouchTarget balandlikda', (t) async {
    await t.pumpWidget(_host(BentoTile(
      onTap: () {},
      padding: EdgeInsets.zero,
      child: const SizedBox(width: 40, height: 10),
    )));
    final h = t.getSize(find.byType(BentoTile)).height;
    expect(h, greaterThanOrEqualTo(kTouchTarget));
  });

  testWidgets('textScale 1.3 da SectionHeader va StatTile overflow bermaydi', (t) async {
    await t.pumpWidget(_host(
      const Column(children: [
        SectionHeader("Bugungi mashq", eyebrow: "Asosiy", trailing: Icon(Icons.add)),
        SizedBox(
          width: 150,
          child: StatTile(
            icon: Icons.scale_outlined,
            label: "Vazn",
            value: "78,4 kg",
            color: Colors.red,
          ),
        ),
      ]),
      scale: 1.3,
    ));
    expect(t.takeException(), isNull);
  });

  testWidgets('reduce motion: CountUp darhol yakuniy qiymatni ko\'rsatadi', (t) async {
    await t.pumpWidget(_host(const CountUp(1840), reduce: true));
    await t.pump();
    expect(find.text('1840'), findsOneWidget);
  });

  testWidgets('ErrorState compact qayta urinishda onRetry chaqiradi', (t) async {
    var n = 0;
    await t.pumpWidget(_host(ErrorState(compact: true, onRetry: () => n++)));
    await t.pumpAndSettle();
    await t.tap(find.byType(BentoTile));
    expect(n, 1);
  });

  testWidgets('Reveal ekran tashqarisidagi blokni skroll qilganda ochadi', (t) async {
    await t.pumpWidget(_host(const Column(children: [
      SizedBox(height: 1000),
      Reveal(child: Text('pastda')),
      SizedBox(height: 400),
    ])));
    await t.pump();
    Opacity op() => t.widget<Opacity>(find.ancestor(of: find.text('pastda'), matching: find.byType(Opacity)).first);
    expect(op().opacity, 0);
    await t.drag(find.byType(SingleChildScrollView), const Offset(0, -700));
    await t.pumpAndSettle();
    expect(op().opacity, 1);
  });

  testWidgets('reduce motion: Reveal darhol ko\'rinadi', (t) async {
    await t.pumpWidget(_host(const Reveal(child: Text('tepada')), reduce: true));
    await t.pump();
    await t.pump();
    final op = t.widget<Opacity>(find.ancestor(of: find.text('tepada'), matching: find.byType(Opacity)).first);
    expect(op.opacity, 1);
  });
}
