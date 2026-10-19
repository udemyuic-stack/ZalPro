import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/screens/admin/subscriptions_screen.dart';
import 'package:kotta_qani_diet/theme.dart';

const _serverMax = 2147483647;

Future<void> _open(WidgetTester t) async {
  t.view.physicalSize = const Size(400, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = AppUser(id: 'c1', name: 'Ali', email: 'a@b.c');
  await t.pumpWidget(MaterialApp(
    theme: AppTheme.dark(),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => addSubscriptionSheet(context, client),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

Future<String> _price(WidgetTester t, String text) async {
  await t.enterText(find.byType(TextFormField), text);
  await t.pump();
  return t.widget<TextField>(find.byType(TextField)).controller!.text;
}

void main() {
  testWidgets('price at server max is accepted', (t) async {
    await _open(t);
    expect(await _price(t, '$_serverMax'), '$_serverMax');
    expect(find.textContaining('gacha'), findsNothing);
  });

  testWidgets('price above server max is rejected', (t) async {
    await _open(t);
    expect(await _price(t, '${_serverMax + 1}'), '${_serverMax + 1}');
    expect(find.textContaining('gacha'), findsOneWidget);
  });

  testWidgets('10 digit price is rejected and 11th digit is not typed', (t) async {
    await _open(t);
    expect(await _price(t, '9999999999'), '9999999999');
    expect(find.textContaining('gacha'), findsOneWidget);
    expect(await _price(t, '99999999999'), '9999999999');
  });
}
