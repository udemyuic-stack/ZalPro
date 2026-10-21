import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/game.dart';
import 'package:kotta_qani_diet/screens/admin/admin_home.dart';
import 'package:kotta_qani_diet/theme.dart';
import 'package:kotta_qani_diet/widgets/challenge_steps_sheet.dart';
import 'package:kotta_qani_diet/widgets/ui.dart';

ChallengeStepAdmin step(int position, {String exercise = 'pushup'}) => ChallengeStepAdmin(
      id: 's$position',
      position: position,
      exercise: exercise,
      target: 10 + position,
      coins: 5,
      muscle: 'chest',
    );

Future<void> pumpManager(
  WidgetTester tester, {
  required List<ChallengeStepAdmin> steps,
  ChallengeStepSave? add,
  ChallengeStepUpdate? update,
  Future<void> Function(String id)? remove,
}) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.current(),
    home: Scaffold(
      body: ChallengeStepsManager(
        load: () async => steps,
        exercises: () async => ['pullup', 'pushup', 'squat'],
        add: add,
        update: update,
        remove: remove,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('ChallengeStepAdmin.fromJson reads all fields', () {
    final s = ChallengeStepAdmin.fromJson(
        {'id': 'a', 'position': 3, 'exercise': 'squat', 'target': 20, 'coins': 7, 'muscle': 'legs'});
    expect(
        [s.id, s.position, s.exercise, s.target, s.coins, s.muscle], ['a', 3, 'squat', 20, 7, 'legs']);
  });

  testWidgets('delete only on last row', (tester) async {
    await pumpManager(tester, steps: [step(0), step(1), step(2)]);
    expect(find.byKey(const Key('challenge-delete-s2')), findsOneWidget);
    expect(find.byKey(const Key('challenge-delete-s0')), findsNothing);
    expect(find.byKey(const Key('challenge-delete-s1')), findsNothing);
  });

  testWidgets('submit disabled until valid, then add sends values', (tester) async {
    final calls = <List<Object>>[];
    await pumpManager(
      tester,
      steps: [step(0)],
      add: ({required exercise, required target, required coins, required muscle}) async =>
          calls.add([exercise, target, coins, muscle]),
    );
    FilledButton submit() => tester.widget(find.byKey(const Key('challenge-submit')));
    expect(submit().onPressed, isNull);
    await tester.enterText(find.byKey(const Key('challenge-target')), '0');
    await tester.enterText(find.byKey(const Key('challenge-coins')), '5');
    await tester.pump();
    expect(submit().onPressed, isNull);
    await tester.enterText(find.byKey(const Key('challenge-target')), '25');
    await tester.tap(find.byKey(const Key('challenge-exercise-squat')));
    await tester.tap(find.byKey(const Key('challenge-muscle-legs')));
    await tester.pump();
    expect(submit().onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('challenge-submit')));
    await tester.pumpAndSettle();
    expect(calls, [
      ['squat', 25, 5, 'legs']
    ]);
  });

  testWidgets('edit fills form, shows hint, calls update', (tester) async {
    final calls = <List<Object>>[];
    await pumpManager(
      tester,
      steps: [step(0)],
      update: (id, {required exercise, required target, required coins, required muscle}) async =>
          calls.add([id, exercise, target, coins, muscle]),
    );
    expect(find.byKey(const Key('challenge-edit-hint')), findsNothing);
    await tester.tap(find.byKey(const Key('challenge-edit-s0')));
    await tester.pump();
    expect(find.byKey(const Key('challenge-edit-hint')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('challenge-target')), '40');
    await tester.pump();
    await tester.tap(find.byKey(const Key('challenge-submit')));
    await tester.pumpAndSettle();
    expect(calls, [
      ['s0', 'pushup', 40, 5, 'chest']
    ]);
    expect(find.byKey(const Key('challenge-edit-hint')), findsNothing);
  });

  testWidgets('delete asks confirm then removes', (tester) async {
    final removed = <String>[];
    await pumpManager(tester, steps: [step(0), step(1)], remove: (id) async => removed.add(id));
    await tester.tap(find.byKey(const Key('challenge-delete-s1')));
    await tester.pumpAndSettle();
    expect(removed, isEmpty);
    await tester.tap(find.text("O'chirish").last);
    await tester.pumpAndSettle();
    expect(removed, ['s1']);
  });

  group('AdminMoreSheet', () {
    Future<void> open(WidgetTester tester, bool isOwner) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.current(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSheet<String>(context, AdminMoreSheet(isOwner: isOwner)),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('entry visible for owner', (tester) async {
      await open(tester, true);
      expect(find.byKey(const Key('more-challenge-steps')), findsOneWidget);
    });

    testWidgets('entry hidden for non-owner', (tester) async {
      await open(tester, false);
      expect(find.byKey(const Key('more-challenge-steps')), findsNothing);
    });
  });
}
