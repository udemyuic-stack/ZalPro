import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/l10n/tr.dart';
import 'package:kotta_qani_diet/services/settings.dart';
import 'package:kotta_qani_diet/theme.dart';
import 'package:kotta_qani_diet/widgets/theme_picker.dart';

Future<void> openPicker(WidgetTester tester, {double width = 360}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.current(),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showThemePicker(context),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    appLang.value = 'uz';
    AppSettings.themeMode.value = ThemeMode.dark;
    AppSettings.palette.value = AppPalette.graphite;
  });

  testWidgets('sheet shows four theme cards', (tester) async {
    await openPicker(tester);
    expect(find.byKey(const ValueKey('theme-card-0')), findsOneWidget);
    expect(
        find.byWidgetPredicate((w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('theme-card-')),
        findsNWidgets(4));
    for (final name in [
      'Grafit Tungi',
      'Kvars Kunduzgi',
      'Kiber Zumrad',
      'Tungi Oltin'
    ]) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('tapping a card sets themeMode and palette', (tester) async {
    await openPicker(tester);

    await tester.tap(find.text('Kiber Zumrad'));
    await tester.pumpAndSettle();
    expect(AppSettings.themeMode.value, ThemeMode.dark);
    expect(AppSettings.palette.value, AppPalette.emerald);

    await tester.tap(find.text('Tungi Oltin'));
    await tester.pumpAndSettle();
    expect(AppSettings.themeMode.value, ThemeMode.dark);
    expect(AppSettings.palette.value, AppPalette.amber);

    await tester.tap(find.text('Kvars Kunduzgi'));
    await tester.pumpAndSettle();
    expect(AppSettings.themeMode.value, ThemeMode.light);
    expect(AppSettings.palette.value, AppPalette.graphite);

    await tester.tap(find.text('Grafit Tungi'));
    await tester.pumpAndSettle();
    expect(AppSettings.themeMode.value, ThemeMode.dark);
    expect(AppSettings.palette.value, AppPalette.graphite);
  });

  testWidgets('selected card shows a check mark', (tester) async {
    AppSettings.palette.value = AppPalette.emerald;
    await openPicker(tester);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tester.tap(find.text('Tungi Oltin'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(selectedThemeChoice()?.palette, AppPalette.amber);
  });

  testWidgets('follow-phone switch sets ThemeMode.system', (tester) async {
    await openPicker(tester);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(AppSettings.themeMode.value, ThemeMode.system);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(currentThemeChoice().title, 'Tizim');

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(AppSettings.themeMode.value, ThemeMode.dark);
  });

  for (final lang in ['uz', 'ru', 'en']) {
    testWidgets('no overflow at 360 px ($lang)', (tester) async {
      appLang.value = lang;
      await openPicker(tester);
      expect(tester.takeException(), isNull);
      for (final c in themeChoices) {
        final box = tester.getRect(find.text(tr(c.name)));
        expect(box.right, lessThanOrEqualTo(360));
        expect(box.left, greaterThanOrEqualTo(0));
      }
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
