import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/screens/user/chat_screen.dart';
import 'package:kotta_qani_diet/screens/user/progress_screen.dart';
import 'package:kotta_qani_diet/theme.dart';

Future<void> _size(WidgetTester t) async {
  t.view.physicalSize = const Size(400, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _openWeight(WidgetTester t) async {
  await _size(t);
  final user = AppUser(id: 'u1', name: 'Ali', email: 'a@b.c');
  await t.pumpWidget(MaterialApp(
    theme: AppTheme.dark(),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => addWeightSheet(context, user, null),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

Future<void> _weight(WidgetTester t, String text) async {
  await t.enterText(find.byType(TextFormField), text);
  await t.pump();
}

Future<TextEditingController> _composer(WidgetTester t) async {
  await _size(t);
  final c = TextEditingController();
  addTearDown(c.dispose);
  await t.pumpWidget(MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      bottomNavigationBar: ChatComposer(
        controller: c,
        onSend: () {},
        onAttach: () {},
      ),
    ),
  ));
  return c;
}

void main() {
  testWidgets('weight 30 and 300 accepted', (t) async {
    await _openWeight(t);
    await _weight(t, '30');
    expect(find.textContaining('gacha'), findsNothing);
    await _weight(t, '300');
    expect(find.textContaining('gacha'), findsNothing);
  });

  testWidgets('weight 29.9 and 300.1 rejected', (t) async {
    await _openWeight(t);
    await _weight(t, '29.9');
    expect(find.textContaining('gacha'), findsOneWidget);
    await _weight(t, '300.1');
    expect(find.textContaining('gacha'), findsOneWidget);
  });

  testWidgets('weight field drops stray characters', (t) async {
    await _openWeight(t);
    await _weight(t, '-7a0..5.5');
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '70.5');
  });

  testWidgets('chat composer hides counter below 80 percent', (t) async {
    final c = await _composer(t);
    await t.enterText(find.byType(TextField), 'a' * 1599);
    await t.pump();
    expect(find.text('1599/2000'), findsNothing);
    expect(c.text.length, 1599);
  });

  testWidgets('chat composer shows counter at 80 percent', (t) async {
    await _composer(t);
    await t.enterText(find.byType(TextField), 'a' * 1600);
    await t.pump();
    expect(find.text('1600/2000'), findsOneWidget);
  });

  testWidgets('chat composer cuts input at 2000', (t) async {
    final c = await _composer(t);
    await t.enterText(find.byType(TextField), 'a' * 2001);
    await t.pump();
    expect(c.text.length, 2000);
    expect(find.text('2000/2000'), findsOneWidget);
  });
}
