import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/leaderboard.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/screens/user/leaderboard_screen.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/leaderboard_api.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';

import 'support/fake_api.dart';

AppUser student({bool visible = true, String? trainerId}) => AppUser(
      id: 'me',
      name: 'Men',
      email: '',
      trainerId: trainerId,
      showInLeaderboard: visible,
    );

Leaderboard board({int rows = 3, LeaderboardMe? me}) => Leaderboard(
      periodDays: 30,
      top: [
        for (var i = 1; i <= rows; i++)
          LeaderboardEntry(
            rank: i,
            userId: i == 2 ? 'me' : 'u$i',
            name: 'Juda uzun ism familiya $i',
            points: 100 - i,
            activeDays: 10 - i,
          ),
      ],
      me: me,
    );

Future<void> pump(
  WidgetTester tester,
  Leaderboard data,
  AppUser user, {
  double width = 360,
  Future<void> Function(bool)? setVisible,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: LeaderboardScreen(
      user: user,
      boardSource: Stream.value(data),
      userSource: Stream.value(user),
      setVisible: setVisible,
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  test('Leaderboard.fromJson maps top and me', () {
    final b = Leaderboard.fromJson({
      'period_days': 30,
      'top': [
        {'rank': 1, 'user_id': 'a', 'name': 'Ali', 'points': 25, 'active_days': 2},
      ],
      'me': {'rank': 11, 'points': 10, 'active_days': 1},
    });
    expect(b.top.single.name, 'Ali');
    expect(b.me!.rank, 11);
    expect(Leaderboard.fromJson({'period_days': 30, 'top': [], 'me': null}).me, isNull);
  });

  test('AppUser.showInLeaderboard defaults to true', () {
    expect(AppUser.fromJson({'id': 'x'}).showInLeaderboard, isTrue);
    expect(AppUser.fromJson({'id': 'x', 'show_in_leaderboard': false}).showInLeaderboard, isFalse);
  });

  test('LeaderboardApi GETs /v1/leaderboard', () async {
    final adapter =
        FakeAdapter((o) async => jsonBody({'period_days': 30, 'top': [], 'me': null}, 200));
    final client = ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter);
    final api = LeaderboardApi(client, bus: ChangeBus(), activity: PollActivity());
    final data = await api.leaderboard().first;
    expect(adapter.calls.last.path, '/v1/leaderboard');
    expect(data.top, isEmpty);
  });

  testWidgets('shows ranked rows and own rank outside top', (tester) async {
    await pump(
        tester, board(me: const LeaderboardMe(rank: 11, points: 10, activeDays: 1)), student());
    expect(find.textContaining('Juda uzun ism familiya 1'), findsOneWidget);
    expect(find.textContaining('11'), findsWidgets);
    expect(find.byKey(const Key('leaderboard-mine')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trainer and trainerless students see the same screen', (tester) async {
    const me = LeaderboardMe(rank: 2, points: 98, activeDays: 8);
    await pump(tester, board(me: me), student());
    final without = find.textContaining('Juda uzun').evaluate().length;
    await pump(tester, board(me: me), student(trainerId: 't1'));
    expect(find.textContaining('Juda uzun').evaluate().length, without);
    expect(find.byKey(const Key('leaderboard-visible')), findsOneWidget);
  });

  testWidgets('opted-out student sees hidden notice', (tester) async {
    await pump(tester, board(), student(visible: false));
    expect(find.text("Reytingda ko'rinmaysiz"), findsOneWidget);
    final tile = tester.widget<SwitchListTile>(find.byKey(const Key('leaderboard-visible')));
    expect(tile.value, isFalse);
  });

  testWidgets('empty state when nobody has points', (tester) async {
    await pump(tester, board(rows: 0), student());
    expect(find.text("Hozircha reytingda hech kim yo'q"), findsOneWidget);
    expect(find.text("Hali ballingiz yo'q"), findsOneWidget);
  });

  testWidgets('toggle calls setVisible with new value', (tester) async {
    bool? sent;
    await pump(tester, board(), student(), setVisible: (v) async => sent = v);
    await tester.tap(find.byKey(const Key('leaderboard-visible')));
    await tester.pump();
    expect(sent, isFalse);
  });

  testWidgets('staff sees list without own-rank or switch', (tester) async {
    final staff = AppUser(id: 'o', name: 'Owner', email: '', role: 'owner');
    await pump(tester, board(), staff);
    expect(find.byKey(const Key('leaderboard-visible')), findsNothing);
    expect(find.byKey(const Key('leaderboard-mine')), findsNothing);
  });

  testWidgets('no overflow at 360 px with 10 long names', (tester) async {
    await pump(tester, board(rows: 10, me: const LeaderboardMe(rank: 11, points: 5, activeDays: 1)),
        student());
    expect(tester.takeException(), isNull);
  });
}
