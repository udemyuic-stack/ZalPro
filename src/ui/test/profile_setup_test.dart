import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/screens/user/profile_setup_screen.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/theme.dart';

final _user = AppUser(id: 'u1', name: 'Ali', email: 'a@b.c');

Future<int> _pump(WidgetTester t) async {
  var opened = 0;
  t.view.physicalSize = const Size(400, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: AppTheme.dark(),
    home: ProfileSetupScreen(
      user: _user,
      trainerSource: () {
        opened++;
        return pollStream<List<TrainerInfo>>(
          () async => const [TrainerInfo('t1', 'Bobur')],
          every: const Duration(hours: 1),
          bus: ChangeBus(),
          activity: PollActivity(),
        );
      },
    ),
  ));
  await t.pump();
  await t.pump();
  return opened;
}

Future<void> _type(WidgetTester t, int index, String text) async {
  await t.enterText(find.byType(TextFormField).at(index), text);
  await t.pump();
}

Future<void> _end(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump();
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  await t.pump();
}

void main() {
  testWidgets('trainer list survives BMI warning shifting the list children', (t) async {
    await _pump(t);
    expect(find.text('Bobur'), findsOneWidget);
    await _type(t, 0, '30');
    await _type(t, 1, '180');
    await _type(t, 2, '40');
    expect(find.textContaining('BMI'), findsWidgets);
    expect(t.takeException(), isNull);
    expect(find.text('Bobur'), findsOneWidget);
    await _type(t, 2, '80');
    expect(t.takeException(), isNull);
    expect(find.text('Bobur'), findsOneWidget);
    await _end(t);
  });

  testWidgets('trainer list survives scrolling out of view and back', (t) async {
    await _pump(t);
    t.view.physicalSize = const Size(400, 500);
    await t.pump();
    await t.drag(find.byType(ListView), const Offset(0, -3000));
    await t.pump();
    await t.drag(find.byType(ListView), const Offset(0, 3000));
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('Bobur'), findsOneWidget);
    await _end(t);
  });

  testWidgets('stray characters are rejected in age, height and weight', (t) async {
    await _pump(t);
    await _type(t, 0, '-3a5');
    await _type(t, 1, '1..8.0x');
    await _type(t, 2, '7-0.55');
    final fields = t.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].controller!.text, '35');
    expect(fields[1].controller!.text, '1.8');
    expect(fields[2].controller!.text, '70.5');
    expect(t.takeException(), isNull);
    await _end(t);
  });

  testWidgets('BMI preview is hidden and safe on empty or invalid input', (t) async {
    await _pump(t);
    for (final v in ['', '.', '0', '999']) {
      await _type(t, 0, v);
      await _type(t, 1, v);
      await _type(t, 2, v);
      expect(find.textContaining('kkal'), findsNothing);
      expect(t.takeException(), isNull);
    }
    await _type(t, 0, '30');
    await _type(t, 1, '180');
    await _type(t, 2, '80');
    expect(find.textContaining('kkal'), findsOneWidget);
    await _end(t);
  });

  testWidgets('at 360 px fields stack, errors are not clipped and units do not overlap', (t) async {
    await _pump(t);
    t.view.physicalSize = const Size(360, 1800);
    await t.pump();
    await _type(t, 0, '5');
    await _type(t, 1, '500');
    final age = t.getRect(find.byType(TextFormField).at(0));
    final height = t.getRect(find.byType(TextFormField).at(1));
    expect(age.width, greaterThan(250));
    expect(height.top, greaterThan(age.bottom));
    expect(find.textContaining('gacha'), findsWidgets);
    for (final e in find.textContaining('gacha').evaluate()) {
      expect(t.getSize(find.byWidget(e.widget)).width, greaterThan(150));
    }
    expect(t.takeException(), isNull);
    await _end(t);
  });

  testWidgets('missing trainer shows an inline error that clears on choice', (t) async {
    await _pump(t);
    await t.tap(find.text('Ozish'));
    await t.tap(find.text('Erkak'));
    await t.tap(find.text('Sekin'));
    await _type(t, 0, '30');
    await _type(t, 1, '180');
    await _type(t, 2, '80');
    t.view.physicalSize = const Size(400, 2600);
    await t.pump();
    await t.tap(find.text('Saqlash'));
    await t.pump();
    expect(find.byKey(const ValueKey('trainer-error')), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await t.tap(find.text('Bobur'));
    await t.pump();
    expect(find.byKey(const ValueKey('trainer-error')), findsNothing);
    await _end(t);
  });
}
