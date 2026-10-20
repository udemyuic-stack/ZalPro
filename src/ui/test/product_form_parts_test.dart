import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/widgets/product_form_parts.dart';

void main() {
  test('marginPercent', () {
    expect(marginPercent(100, 60), 40);
    expect(marginPercent(0, 10), isNull);
    expect(marginPercent(100, 120), -20);
  });

  testWidgets('stepper bounds', (t) async {
    final c = TextEditingController(text: '0');
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: QtyStepper(controller: c, onChanged: () {}))));
    await t.tap(find.byKey(const Key('stock-minus')));
    expect(c.text, '0');
    await t.tap(find.byKey(const Key('stock-plus')));
    expect(c.text, '1');
  });

  testWidgets('chip toggles and keeps non-preset values', (t) async {
    final c = TextEditingController(text: '4XL');
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ChipPicker(
      controller: c,
      presets: sizePresets,
      addLabel: 'x',
      onChanged: () {},
    )))));
    await t.tap(find.byKey(const Key('chip-M')));
    await t.pump();
    expect(c.text, '4XL, M');
    await t.tap(find.byKey(const Key('chip-4XL')));
    await t.pump();
    expect(c.text, 'M');
  });
}
