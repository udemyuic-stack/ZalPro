import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/l10n/tr.dart';
import 'package:kotta_qani_diet/models/game.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/screens/user/game_hub_screen.dart';
import 'package:kotta_qani_diet/widgets/game_widgets.dart';

const me = GameMe(
  coins: 1234,
  xp: 620,
  level: 2,
  levelXp: 500,
  nextLevelXp: 1500,
  streakDays: 5,
  sessionsTotal: 12,
  bestSets: {'pushup': 30, 'squat': 45},
);

AppUser student({bool game = true}) =>
    AppUser(id: 'me', name: 'Men', email: '', gameEnabled: game);

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  double width = 360,
  double scale = 1.3,
  bool reduce = false,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale), disableAnimations: reduce),
      child: c!,
    ),
    home: child,
  ));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  test('AppUser gameEnabled json default and copy', () {
    expect(AppUser.fromJson({'id': 'a', 'name': 'A'}).gameEnabled, isTrue);
    expect(AppUser.fromJson({'id': 'a', 'name': 'A', 'game_enabled': false}).gameEnabled, isFalse);
  });

  test('gameLevelName clamps level', () {
    expect(gameLevelName(0), gameLevelName(1));
    expect(gameLevelName(99), gameLevelName(6));
    expect(clampLevel(-3), 1);
  });

  for (final w in [360.0, 390.0, 412.0]) {
    testWidgets('level card no overflow @ $w x1.3', (tester) async {
      await pump(
        tester,
        Scaffold(body: GameLevelCard(user: student(), meSource: Stream.value(me))),
        width: w,
      );
      expect(tester.takeException(), isNull);
      expect(find.text(gameLevelName(2)), findsOneWidget);
      expect(find.text(trf('{0} coin', [1234])), findsOneWidget);
    });

    testWidgets('hub no overflow @ $w x1.3', (tester) async {
      await pump(
        tester,
        GameHubScreen(user: student(), meSource: Stream.value(me)),
        width: w,
      );
      expect(tester.takeException(), isNull);
      expect(find.text(trf('{0} takror', [30]), skipOffstage: false), findsOneWidget);
    });
  }

  testWidgets('hub works with reduce-motion', (tester) async {
    await pump(tester, GameHubScreen(user: student(), meSource: Stream.value(me)), reduce: true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled card shows enable tile and calls setEnabled', (tester) async {
    bool? called;
    await pump(
      tester,
      Scaffold(
        body: GameLevelCard(
          user: student(game: false),
          meSource: Stream.value(me),
          setEnabled: (v) async => called = v,
        ),
      ),
    );
    await tester.tap(find.byType(GameLevelCard));
    await tester.pump();
    expect(called, isTrue);
  });

  testWidgets('hub switch off calls setEnabled(false)', (tester) async {
    bool? called;
    await pump(
      tester,
      Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => GameHubScreen(
            user: student(),
            meSource: Stream.value(me),
            setEnabled: (v) async => called = v,
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.byType(Switch), 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(called, isFalse);
  });
}
