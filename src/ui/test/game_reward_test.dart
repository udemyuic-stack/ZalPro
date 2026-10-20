import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/l10n/tr.dart';
import 'package:kotta_qani_diet/models/game.dart';
import 'package:kotta_qani_diet/screens/user/game_reward_screen.dart';

GameSessionResult result({
  String status = 'valid',
  bool levelUp = false,
  int bonus = 0,
  int level = 2,
  int totalXp = 620,
  ChallengeResult? challenge,
}) =>
    GameSessionResult(
      id: 'a',
      status: status,
      coins: 30,
      xp: 120,
      streakBonus: bonus,
      streakDays: 3,
      totalCoins: 400,
      totalXp: totalXp,
      level: level,
      levelUp: levelUp,
      challenge: challenge,
    );

Future<void> pump(
  WidgetTester tester,
  GameRewardScreen screen, {
  double width = 360,
  bool reduce = false,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.3), disableAnimations: reduce),
      child: c!,
    ),
    home: screen,
  ));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  test('rewardProgress', () {
    expect(rewardProgress(0, 1), 0);
    expect(rewardProgress(1000, 2), 0.5);
    expect(rewardProgress(99999, 6), 1);
    expect(rewardProgress(10, 0), closeTo(10 / 500, 1e-9));
    expect(rewardProgress(400, 2), 0);
  });

  for (final w in [360.0, 390.0, 412.0]) {
    testWidgets('full reward no overflow @ $w x1.3', (tester) async {
      await pump(
        tester,
        GameRewardScreen(
          result: result(levelUp: true, bonus: 10),
          exercise: 'pushup',
          reps: 40,
          newRecord: true,
        ),
        width: w,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('reward-streak')), findsOneWidget);
      expect(find.byKey(const Key('reward-levelup')), findsOneWidget);
      expect(find.byKey(const Key('reward-record')), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
    });
  }

  testWidgets('flagged session shows no coins and explains', (tester) async {
    await pump(
      tester,
      GameRewardScreen(result: result(status: 'flagged'), exercise: 'squat', reps: 80),
    );
    expect(find.text(tr('Sessiya hisoblanmadi')), findsOneWidget);
    expect(find.text(tr('Coin')), findsNothing);
    expect(find.byKey(const Key('reward-record')), findsNothing);
  });

  testWidgets('reduce-motion renders without exceptions', (tester) async {
    await pump(
      tester,
      GameRewardScreen(result: result(levelUp: true), exercise: 'auto', reps: 10),
      reduce: true,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('continue button pops the route', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => GameRewardScreen(result: result(), exercise: 'pushup', reps: 5),
          )),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('Davom etish')));
    await tester.pumpAndSettle();
    expect(find.byType(GameRewardScreen), findsNothing);
  });

  ChallengeResult chal({bool completed = false, int progress = 12}) => ChallengeResult(
        step: 9,
        exercise: 'squat',
        target: 100,
        progress: progress,
        completed: completed,
        coins: 50,
        muscle: 'legs',
        finished: false,
      );

  testWidgets('challenge progress card', (tester) async {
    await pump(
      tester,
      GameRewardScreen(result: result(challenge: chal()), exercise: 'squat', reps: 12),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('reward-challenge')), findsOneWidget);
    expect(find.text('12 / 100'), findsOneWidget);
  });

  testWidgets('challenge completed shows coins and muscle', (tester) async {
    await pump(
      tester,
      GameRewardScreen(
          result: result(challenge: chal(completed: true, progress: 100)),
          exercise: 'squat',
          reps: 88),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('+50 coin'), findsOneWidget);
  });

  testWidgets('flagged hides challenge card', (tester) async {
    await pump(
      tester,
      GameRewardScreen(
          result: result(status: 'flagged', challenge: chal()), exercise: 'squat', reps: 5),
    );
    expect(find.byKey(const Key('reward-challenge')), findsNothing);
  });
}
