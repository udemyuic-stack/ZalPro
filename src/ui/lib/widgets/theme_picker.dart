import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../services/settings.dart';
import '../theme.dart';
import 'ui.dart';

class ThemeChoice {
  final String title;
  final String name;
  final String subtitle;
  final ThemeMode mode;
  final AppPalette palette;
  const ThemeChoice(
      this.title, this.name, this.subtitle, this.mode, this.palette);

  bool get isLight => mode == ThemeMode.light;
}

const themeChoices = <ThemeChoice>[
  ThemeChoice(
      'Grafit',
      'Grafit Tungi',
      "Qorong'i grafit fon, yorqin qizil urg'u",
      ThemeMode.dark,
      AppPalette.graphite),
  ThemeChoice(
      'Kunduzgi',
      'Kvars Kunduzgi',
      "Yorug' va toza kvars fon, qirollik qizil urg'u",
      ThemeMode.light,
      AppPalette.graphite),
  ThemeChoice(
      'Zumrad',
      'Kiber Zumrad',
      "To'q slanets fon, baquvvat neon zumrad urg'u",
      ThemeMode.dark,
      AppPalette.emerald),
  ThemeChoice('Oltin', 'Tungi Oltin', "Obsidian fon, VIP qirollik oltin urg'u",
      ThemeMode.dark, AppPalette.amber),
];

bool _matches(ThemeChoice c, ThemeMode mode, AppPalette palette) =>
    c.mode == mode && (c.isLight || c.palette == palette);

ThemeChoice? selectedThemeChoice() {
  for (final c in themeChoices) {
    if (_matches(c, AppSettings.themeMode.value, AppSettings.palette.value)) {
      return c;
    }
  }
  return null;
}

String currentThemeTitle() {
  final c = selectedThemeChoice();
  if (AppSettings.themeMode.value == ThemeMode.system || c == null) {
    return tr('Telefon');
  }
  return tr(c.title);
}

({String title}) currentThemeChoice() => (title: currentThemeTitle());

Future<void> showThemePicker(BuildContext context) =>
    showSheet<void>(context, const ThemePicker());

class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});

  void _pick(ThemeChoice c) {
    AppSettings.setPalette(c.palette);
    AppSettings.setThemeMode(c.mode);
  }

  void _follow(bool on) {
    AppSettings.setThemeMode(on ? ThemeMode.system : ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: ListenableBuilder(
        listenable:
            Listenable.merge([AppSettings.themeMode, AppSettings.palette]),
        builder: (context, _) {
          final mode = AppSettings.themeMode.value;
          final palette = AppSettings.palette.value;
          return ListView(shrinkWrap: true, children: [
            Text(tr('Dizayn mavzulari'), style: t.titleLarge),
            const SizedBox(height: AppSpace.xs),
            Text(
                tr("Tugmalar, kartalar, chiziqlar va fon ranglari tanlangan mavzuga darhol o'zgaradi."),
                style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpace.lg),
            for (var i = 0; i < themeChoices.length; i += 2) ...[
              if (i > 0) const SizedBox(height: AppSpace.md),
              IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var j = i; j < i + 2; j++) ...[
                        if (j > i) const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: _ThemeCard(
                            key: ValueKey('theme-card-$j'),
                            choice: themeChoices[j],
                            selected: _matches(themeChoices[j], mode, palette),
                            onTap: () => _pick(themeChoices[j]),
                          ),
                        ),
                      ],
                    ]),
              ),
            ],
            const SizedBox(height: AppSpace.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: mode == ThemeMode.system,
              onChanged: _follow,
              title: Text(tr('Telefon sozlamasiga ergashish')),
              subtitle: Text(
                  tr("Telefon qorong'i bo'lsa tanlangan rang, yorug' bo'lsa Kvars"),
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ),
          ]);
        },
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final ThemeChoice choice;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeCard(
      {super.key,
      required this.choice,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sw = AppColors.swatch(choice.palette, isLight: choice.isLight);
    final radius = BorderRadius.circular(AppRadius.lg);
    return Semantics(
      button: true,
      selected: selected,
      label: tr(choice.name),
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
              color: selected ? AppColors.accent : AppColors.hairline,
              width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: sw.bg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.hairline),
                ),
                padding: const EdgeInsets.all(AppSpace.sm),
                child: Row(children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: sw.card,
                          borderRadius: BorderRadius.circular(AppRadius.sm)),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Container(
                    width: 20,
                    height: 20,
                    decoration:
                        BoxDecoration(color: sw.accent, shape: BoxShape.circle),
                  ),
                ]),
              ),
              const SizedBox(height: AppSpace.sm),
              Row(children: [
                Expanded(
                  child: Text(tr(choice.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleSmall),
                ),
                if (selected)
                  Icon(Icons.check_circle, size: 18, color: AppColors.accent),
              ]),
              const SizedBox(height: AppSpace.xs),
              Text(tr(choice.subtitle),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ]),
          ),
        ),
      ),
    );
  }
}
