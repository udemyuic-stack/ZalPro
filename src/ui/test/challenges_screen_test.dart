import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/l10n/tr.dart';
import 'package:kotta_qani_diet/models/game.dart';
import 'package:kotta_qani_diet/screens/user/challenges_screen.dart';

GameChallenges sample({int step = 1, int progress = 4}) => GameChallenges(
      step: step,
      progress: progress,
      finished: false,
      muscles: const MuscleLevels(arms: 1),
      steps: [
        const ChallengeStep(
            index: 0, exercise: 'pullup', target: 20, coins: 20, muscle: 'arms', state: 'done'),
        const ChallengeStep(
            index: 1, exercise: 'pushup', target: 10, coins: 15, muscle: 'chest', state: 'current'),
        const ChallengeStep(
            index: 2, exercise: 'squat', target: 20, coins: 15, muscle: 'legs', state: 'locked'),
      ],
    );

Future<void> pump(WidgetTester tester, Stream<GameChallenges> source,
    {double width = 360, double scale = 1.3, VoidCallback? onStart}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: c!,
    ),
    home: ChallengesScreen(source: source, onStart: onStart),
  ));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  for (final w in [360.0, 390.0, 412.0]) {
    for (final s in [1.0, 1.3]) {
      testWidgets('challenges $w x$s: overflow yo\'q, joriy challenj ko\'rinadi', (tester) async {
        await pump(tester, Stream.value(sample()), width: w, scale: s);
        expect(tester.takeException(), isNull);
        expect(find.text(trf('{0} / {1}', [4, 10])), findsOneWidget);
        expect(find.text(tr('Boshlash')), findsOneWidget);
      });
    }
  }

  testWidgets('Boshlash onStart ni chaqiradi', (tester) async {
    var started = 0;
    await pump(tester, Stream.value(sample()), onStart: () => started++);
    await tester.ensureVisible(find.text(tr('Boshlash')));
    await tester.tap(find.text(tr('Boshlash')));
    expect(started, 1);
  });

  testWidgets('tugagan zanjirda tabrik ko\'rinadi', (tester) async {
    const done = GameChallenges(
      step: 12,
      progress: 0,
      finished: true,
      muscles: MuscleLevels(arms: 4, chest: 4, legs: 4),
      steps: [],
    );
    await pump(tester, Stream.value(done));
    expect(find.text(tr('Barcha vazifalar bajarildi!')), findsOneWidget);
    expect(find.text(tr('Boshlash')), findsNothing);
  });
}
