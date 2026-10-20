import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/l10n/tr.dart';
import 'package:kotta_qani_diet/models/game.dart';
import 'package:kotta_qani_diet/models/leaderboard.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/screens/user/leaderboard_screen.dart';
import 'package:kotta_qani_diet/widgets/game_board.dart';

GameLeaderboard board(int rows, {GameRank? me}) => GameLeaderboard(
      period: 'week',
      top: [
        for (var i = 1; i <= rows; i++)
          GameEntry(
            rank: i,
            userId: 'u$i',
            name: 'Juda uzun ismli shogird raqam $i',
            xp: 1000 - i * 10,
            reps: 300 - i * 5,
          ),
      ],
      me: me,
    );

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  double width = 360,
  bool reduce = false,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.3), disableAnimations: reduce),
      child: c!,
    ),
    home: Scaffold(body: child),
  ));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  for (final w in [360.0, 390.0, 412.0]) {
    testWidgets('game board no overflow @ $w x1.3', (tester) async {
      await pump(
        tester,
        GameBoardView(
          userId: 'u5',
          source: (p, e) => Stream.value(board(10, me: const GameRank(rank: 5, xp: 1, reps: 275))),
        ),
        width: w,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('game-board-mine')), findsOneWidget);
    });
  }

  testWidgets('podium works with only two entries and reduce-motion', (tester) async {
    await pump(
      tester,
      GameBoardView(userId: 'x', source: (p, e) => Stream.value(board(2))),
      reduce: true,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty board shows empty state', (tester) async {
    await pump(tester, GameBoardView(userId: 'x', source: (p, e) => Stream.value(board(0))));
    expect(find.text(tr("Hozircha reytingda hech kim yo'q")), findsOneWidget);
  });

  testWidgets('changing period and exercise reopens the source', (tester) async {
    final calls = <String>[];
    await pump(
      tester,
      GameBoardView(
        userId: 'x',
        source: (p, e) {
          calls.add('$p/${e ?? '-'}');
          return Stream.value(board(3));
        },
      ),
    );
    await tester.tap(find.text(tr('Oy')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text(tr('Turnik')),
      200,
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
      ),
    );
    await tester.ensureVisible(find.text(tr('Turnik')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('Turnik')));
    await tester.pump();
    expect(calls, ['week/-', 'month/-', 'month/pullup']);
  });

  testWidgets('leaderboard screen switches to reps tab only with game mode', (tester) async {
    AppUser user({required bool game}) =>
        AppUser(id: 'me', name: 'Men', email: '', gameEnabled: game);
    Future<void> open(AppUser u) async {
      await tester.pumpWidget(MaterialApp(
        home: LeaderboardScreen(
          user: u,
          boardSource: Stream.value(const Leaderboard(periodDays: 30, top: [])),
          userSource: Stream.value(u),
          gameBoardSource: (p, e) => Stream.value(board(3)),
        ),
      ));
      await tester.pump();
    }

    await open(user(game: false));
    expect(find.text(tr('Takror')), findsNothing);
    await open(user(game: true));
    await tester.tap(find.text(tr('Takror')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(GameBoardView), findsOneWidget);
  });
}
