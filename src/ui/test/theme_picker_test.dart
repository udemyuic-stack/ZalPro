import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotta_qani_diet/services/settings.dart';
import 'package:kotta_qani_diet/theme.dart';
import 'package:kotta_qani_diet/widgets/theme_picker.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.init();
    AppColors.light = false;
  });

  test('har tanlov to\'g\'ri rejim va palitrani o\'rnatadi', () async {
    await applyThemeChoice(ThemeChoice.emerald);
    expect(AppSettings.themeMode.value, ThemeMode.dark);
    expect(AppSettings.palette.value, AppPalette.emerald);

    await applyThemeChoice(ThemeChoice.amber);
    expect(AppSettings.palette.value, AppPalette.amber);

    await applyThemeChoice(ThemeChoice.quartz);
    expect(AppSettings.themeMode.value, ThemeMode.light);

    await applyThemeChoice(ThemeChoice.graphite);
    expect(AppSettings.themeMode.value, ThemeMode.dark);
    expect(AppSettings.palette.value, AppPalette.graphite);
  });

  test('swatch global holatni buzmaydi va palitraga mos', () {
    AppColors.light = false;
    AppColors.palette = AppPalette.graphite;
    final e = AppColors.swatch(AppPalette.emerald, isLight: false);
    final q = AppColors.swatch(AppPalette.graphite, isLight: true);
    expect(AppColors.light, isFalse);
    expect(AppColors.palette, AppPalette.graphite);
    expect(e.accent, isNot(q.accent));
    expect(q.bg, isNot(e.bg));
  });
}
