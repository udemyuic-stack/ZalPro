import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/l10n/tr.dart';
import 'package:kotta_qani_diet/models/gym.dart';
import 'package:kotta_qani_diet/models/kcal_target.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/screens/user/muscles_screen.dart';
import 'package:kotta_qani_diet/screens/user/user_home.dart';
import 'package:kotta_qani_diet/screens/user/trainer_tab.dart';
import 'package:kotta_qani_diet/services/db.dart';
import 'package:kotta_qani_diet/theme.dart';
import 'package:kotta_qani_diet/widgets/today_workout_card.dart';

AppUser student({String? trainerId, List<int> gymDays = const [], String? homeDate}) => AppUser(
      id: 'u1',
      name: 'Ali',
      email: 'a@b.c',
      age: 30,
      height: 175,
      weight: 85,
      metabolism: 'slow',
      trainerId: trainerId,
      gymDays: gymDays,
      homeWorkoutDate: homeDate,
    );

Future<void> pumpApp(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.current(), home: child));
  await tester.pump();
}

void main() {
  group('bitta kaloriya maqsadi', () {
    final plan = Plan(
      id: 'p',
      title: 'Reja',
      meals: [
        Meal(
            time: '08:00',
            title: 'Nonushta',
            items: [MealItem(name: 'Guruch', grams: 100, kcal: 2537)]),
      ],
    );

    test('reja bor — reja maqsad, formula tavsiya', () {
      final u = student();
      final t = kcalTargetOf(u, plan, 1);
      expect(t.fromPlan, isTrue);
      expect(t.target, 2537);
      expect(t.recommended, u.targetKcal);
    });

    test("reja yo'q — formula maqsad, tavsiya yo'q", () {
      final u = student();
      final t = kcalTargetOf(u, null, 1);
      expect(t.fromPlan, isFalse);
      expect(t.target, u.targetKcal);
      expect(t.recommended, isNull);
    });
  });

  group('trener tabi', () {
    testWidgets('trenersiz: Trener tanlang holati, chat yozuvi yo\'q', (tester) async {
      var picked = 0;
      await pumpApp(tester, TrainerTab(user: student(), onPick: (_, __) async => picked++));
      expect(find.text(tr('Trener tanlang')), findsWidgets);
      expect(find.text(tr('Savollaringizga javob beradi')), findsNothing);
      await tester.tap(find.byKey(const Key('choose-trainer')));
      expect(picked, 1);
    });
  });

  group('Bugungi mashq kartasi', () {
    test('mashq kuni nom qaytaradi, dam olish kuni va uyda mashqda null', () {
      final u = student(gymDays: evenDays);
      final workoutDay = DateTime(2026, 10, 20);
      final restDay = DateTime(2026, 10, 19);
      expect(evenDays.contains(workoutDay.weekday), isTrue);
      expect(todayWorkoutName(u, workoutDay), isNotNull);
      expect(todayWorkoutName(u, restDay), isNull);
      expect(todayWorkoutName(student(), workoutDay), isNull);
    });

    test('uyda mashq kuni karta yo\'q', () {
      final u = student(gymDays: evenDays, homeDate: todayKey());
      expect(todayWorkoutName(u, DateTime.now()), isNull);
    });

    testWidgets('Boshlash bitta bosishda ishlaydi, tugma 52 px', (tester) async {
      var started = 0;
      await pumpApp(
          tester, Scaffold(body: TodayWorkoutCard(name: 'Ko\'krak', onStart: () => started++)));
      final btn = find.widgetWithText(FilledButton, tr('Boshlash'));
      expect(tester.getSize(btn).height, greaterThanOrEqualTo(kTouchTarget));
      await tester.tap(btn);
      expect(started, 1);
    });
  });

  group('pastki panel', () {
    Widget shell(ValueNotifier<int> resets) {
      var wired = false;
      return StudentShell(
        pages: (signals) {
          if (!wired) {
            wired = true;
            signals.resetGym.addListener(() => resets.value++);
          }
          return [
            for (final n in ['p0', 'p1', 'p2', 'p3', 'p4']) Text(n)
          ];
        },
      );
    }

    testWidgets('shogirdda aynan 5 ta tab, Ko\'proq yo\'q', (tester) async {
      await pumpApp(tester, shell(ValueNotifier(0)));
      for (final l in ['Bugun', 'Progress', 'Zal', 'Trener', 'Profil']) {
        expect(find.text(tr(l)), findsOneWidget, reason: l);
      }
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(find.text(tr("Ko'proq")), findsNothing);
    });

    testWidgets('faol Zal tabini qayta bosish ildizga qaytaradi', (tester) async {
      final resets = ValueNotifier<int>(0);
      await pumpApp(tester, shell(resets));
      await tester.tap(find.text(tr('Zal')));
      await tester.pump();
      expect(resets.value, 0);
      await tester.tap(find.text(tr('Zal')));
      await tester.pump();
      expect(resets.value, 1);
      await tester.tap(find.text(tr('Bugun')));
      await tester.pump();
      await tester.tap(find.text(tr('Bugun')));
      await tester.pump();
      expect(resets.value, 1);
    });

    testWidgets('Tana xaritasi orqaga tugmasi 52 px', (tester) async {
      await pumpApp(tester, MusclesScreen(gymDays: evenDays, onBack: () {}));
      await tester.pump(const Duration(seconds: 3));
      final back = find.byTooltip(tr('Orqaga'));
      expect(tester.getSize(back).width, greaterThanOrEqualTo(kTouchTarget));
      expect(tester.getSize(back).height, greaterThanOrEqualTo(kTouchTarget));
    });
  });
}
