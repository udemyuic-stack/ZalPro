import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/l10n/tr.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/screens/user/profile_screen.dart';
import 'package:kotta_qani_diet/screens/user/today_screen.dart';
import 'package:kotta_qani_diet/theme.dart';
import 'package:kotta_qani_diet/widgets/ui.dart';

Future<void> pump360(WidgetTester tester, Widget child, {bool light = false}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  AppColors.light = light;
  addTearDown(() {
    tester.view.reset();
    AppColors.light = false;
    appLang.value = 'uz';
  });
  await tester.pumpWidget(MaterialApp(theme: AppTheme.current(), home: Scaffold(body: child)));
  await tester.pump();
}

void main() {
  group('salomlashuv va reja sarlavhasi', () {
    testWidgets('ru, 360 px: ism saqlanadi, overflow yo\'q', (tester) async {
      appLang.value = 'ru';
      await pump360(
        tester,
        Row(children: [
          const Expanded(child: TodayGreeting(name: 'Aleksandr Petrov')),
          for (var i = 0; i < 3; i++) const SizedBox(width: kTouchTarget),
          const SizedBox(width: 46),
        ]),
      );
      expect(find.text(trf('Salom, {0}', ['Aleksandr'])), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('juda uzun ism ellipsis bilan qisqartiriladi', (tester) async {
      await pump360(tester, TodayGreeting(name: 'A' * 40));
      expect(find.text(trf('Salom, {0}', ['${'A' * 19}…'])), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uzun reja sarlavhasi to\'liq ko\'rinadi', (tester) async {
      const title = 'Massa nabor uchun haftalik ovqatlanish rejasi, kuchaytirilgan oqsil bilan';
      await pump360(
        tester,
        TodayHeroPanel(plan: Plan(id: 'p', title: title, meals: const []), eaten: 500, weekday: 1),
      );
      final text = tester.widget<Text>(find.text(title));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(tester.takeException(), isNull);
    });
  });

  group('StatTile', () {
    testWidgets('Semantics yorlig\'i va ru "Приёмы пищи" kesilmaydi', (tester) async {
      appLang.value = 'ru';
      await pump360(
        tester,
        Row(children: [
          for (final l in ['Oqsil', 'Maqsad', 'Ovqat'])
            Expanded(
              child: StatTile(
                  icon: Icons.flag_outlined, label: tr(l), value: '3/5', color: Colors.red),
            ),
        ]),
      );
      expect(find.bySemanticsLabel('Приёмы пищи: 3/5'), findsOneWidget);
      expect(find.text('Приёмы пищи'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final tile = tester.getRect(find.byType(StatTile).last);
      expect(tester.getRect(find.text('Приёмы пищи')).width, lessThanOrEqualTo(tile.width));
    });
  });

  group('StepButton', () {
    testWidgets('Semantics yorlig\'i, tap va 48 px', (tester) async {
      var n = 0;
      await pump360(
        tester,
        Row(children: [
          StepButton(icon: Icons.remove, label: tr('Kamaytirish'), onPressed: () => n--),
          StepButton(icon: Icons.add, label: tr('Oshirish'), tonal: true, onPressed: () => n++),
          const StepButton(icon: Icons.add, label: 'off', onPressed: null),
        ]),
      );
      expect(find.bySemanticsLabel('Kamaytirish'), findsOneWidget);
      expect(find.bySemanticsLabel('Oshirish'), findsOneWidget);
      for (final b in tester.widgetList<StepButton>(find.byType(StepButton))) {
        final size = tester.getSize(find.byWidget(b));
        expect(size.width, greaterThanOrEqualTo(kTouchTarget));
        expect(size.height, greaterThanOrEqualTo(kTouchTarget));
      }
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.tap(find.byIcon(Icons.remove));
      expect(n, 0);
    });

    test('yangi kalitlar ru/en da bor', () {
      for (final lang in ['ru', 'en']) {
        appLang.value = lang;
        for (final k in ['Kamaytirish', 'Oshirish']) {
          expect(tr(k), isNot(k));
        }
      }
      appLang.value = 'uz';
    });
  });

  group('BMI', () {
    test('"Normal" tarjimasi', () {
      appLang.value = 'ru';
      expect(tr('Normal'), 'Норма');
      appLang.value = 'en';
      expect(tr('Normal'), 'Normal');
      appLang.value = 'uz';
    });

    testWidgets('chip tilga qarab yangilanadi va Semantics bor', (tester) async {
      appLang.value = 'ru';
      await pump360(tester, const BmiCard(bmi: 22.9), light: true);
      expect(find.text('Норма'), findsOneWidget);
      expect(find.bySemanticsLabel('Индекс массы тела: 22.9, Норма'), findsOneWidget);
      final pill = tester.widget<Text>(find.text('Норма'));
      expect(pill.style?.color, AppColors.successText);
    });

    testWidgets('Pill textColor matn rangini almashtiradi', (tester) async {
      await pump360(tester, const Pill(text: 'x', color: Colors.green, textColor: Colors.black));
      final text = tester.widget<Text>(find.text('x'));
      expect(text.style?.color, Colors.black);
    });
  });
}
