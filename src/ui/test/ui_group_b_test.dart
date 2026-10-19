import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/feed.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/screens/admin/admin_home.dart';
import 'package:kotta_qani_diet/screens/admin/clients_screen.dart';
import 'package:kotta_qani_diet/screens/user/trainer_tab.dart';
import 'package:kotta_qani_diet/theme.dart';
import 'package:kotta_qani_diet/widgets/app_nav_bar.dart';
import 'package:kotta_qani_diet/widgets/ui.dart';

Future<void> pump360(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.current(), home: Scaffold(body: child)));
  await tester.pump();
  await tester.pump();
}

AppUser student({String? trainerId}) =>
    AppUser(id: 'u1', name: 'Ali', email: 'a@b.c', trainerId: trainerId);

void main() {
  group('10: biriktirilgan trener sheet orqali', () {
    final trainers = [
      AppUser(id: 't1', name: 'Bobur', email: '', role: 'admin'),
      AppUser(id: 't2', name: 'Sardor', email: '', role: 'admin'),
    ];

    testWidgets('popup yo\'q, sheet ochiladi, tanlov saqlanadi', (tester) async {
      final calls = <String?>[];
      await pump360(
        tester,
        TrainerPicker(
          user: student(trainerId: 't1'),
          trainersSource: () => Stream.value(trainers),
          assign: (uid, id) async => calls.add(id),
        ),
      );
      expect(find.byType(DropdownButtonFormField<String?>), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.text('Bobur'), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('trainer-picker'))).height,
          greaterThanOrEqualTo(kTouchTarget));

      await tester.tap(find.byKey(const Key('trainer-picker')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(3));
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile))) {
        expect(tile.minTileHeight, greaterThanOrEqualTo(kTouchTarget));
      }

      await tester.tap(find.text('Sardor'));
      await tester.pumpAndSettle();
      expect(calls, ['t2']);
    });

    testWidgets('trenersiz: "Trener yo\'q" ko\'rinadi, olib tashlash null yuboradi',
        (tester) async {
      final calls = <String?>[];
      await pump360(
        tester,
        TrainerPicker(
          user: student(trainerId: 't1'),
          trainersSource: () => Stream.value(trainers),
          assign: (uid, id) async => calls.add(id),
        ),
      );
      await tester.tap(find.byKey(const Key('trainer-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text("— Trener yo'q —"));
      await tester.pumpAndSettle();
      expect(calls, [null]);
    });
  });

  group('13: chat sarlavhasi', () {
    testWidgets('trener ismi ko\'rsatiladi', (tester) async {
      String? shown;
      await pump360(
        tester,
        TrainerTab(
          user: student(trainerId: 't1'),
          trainerSource: (_) => Stream.value(const TrainerInfo('t1', 'Bobur')),
          chatBuilder: (title) {
            shown = title;
            return Text('chat:$title');
          },
        ),
      );
      expect(shown, 'Bobur');
      expect(find.text('chat:Bobur'), findsOneWidget);
    });

    testWidgets('trenersiz: Trener tanlanmagan', (tester) async {
      await pump360(tester, TrainerTab(user: student(), onPick: (_, __) async {}));
      expect(find.text('Trener tanlanmagan'), findsOneWidget);
    });
  });

  group('15: eslatmalar guruhlanadi', () {
    final now = DateTime(2026, 10, 19, 12);
    final trainer = AppUser(id: 't', name: 'T', email: '', role: 'admin');
    AppUser c(String id, {String? plan}) =>
        AppUser(id: id, name: id, email: '', planId: plan, gymDays: const [1, 3, 5]);

    test('ko\'p rejasiz shogird bitta qatorga yig\'iladi', () {
      final items = trainerFeed(
        trainer: trainer,
        clients: [for (var i = 0; i < 60; i++) c('c$i'), c('ok', plan: 'p')],
        now: now,
      );
      final rows = items.where((i) => i.title == 'Reja berilmagan').toList();
      expect(rows, hasLength(1));
      expect(rows.first.body, contains('60'));
    });

    test('bitta rejasiz shogird ismi bilan qoladi', () {
      final items = trainerFeed(trainer: trainer, clients: [c('Aziz')], now: now);
      final rows = items.where((i) => i.title == 'Reja berilmagan').toList();
      expect(rows, hasLength(1));
      expect(rows.first.body, contains('Aziz'));
    });
  });

  group('17: trener menyusi', () {
    testWidgets('Chiqish ko\'rinadi, 52 px, "out" qaytaradi', (tester) async {
      String? result;
      await pump360(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showSheet<String>(context, const AdminMoreSheet()),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Chiqish'), findsOneWidget);
      expect(find.text('Sozlamalar'), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('more-sign-out'))).height,
          greaterThanOrEqualTo(kTouchTarget));
      await tester.tap(find.text('Chiqish'));
      await tester.pumpAndSettle();
      expect(result, 'out');
    });
  });

  group('14: pastki navigatsiya tooltipi', () {
    testWidgets('tooltip osilmaydi', (tester) async {
      await pump360(
        tester,
        const SizedBox.shrink(),
      );
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.current(),
        home: Scaffold(
          bottomNavigationBar: AppNavBar(
            selected: 0,
            onSelected: (_) {},
            items: const [
              AppNavItem(icon: Icon(Icons.people), label: 'Mijozlar'),
              AppNavItem(icon: Icon(Icons.event), label: 'Obuna'),
            ],
          ),
        ),
      ));
      expect(find.byTooltip('Obuna'), findsNothing);
    });
  });
}
