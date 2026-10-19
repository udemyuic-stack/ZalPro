import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../services/settings.dart';
import '../theme.dart';
import 'ui.dart';

enum ThemeChoice { graphite, quartz, emerald, amber }

extension ThemeChoiceInfo on ThemeChoice {
  bool get isLight => this == ThemeChoice.quartz;

  AppPalette get palette => switch (this) {
        ThemeChoice.emerald => AppPalette.emerald,
        ThemeChoice.amber => AppPalette.amber,
        _ => AppPalette.graphite,
      };

  String get title => switch (this) {
        ThemeChoice.graphite => tr('Grafit Tungi'),
        ThemeChoice.quartz => tr('Kvars Kunduzgi'),
        ThemeChoice.emerald => tr('Kiber Zumrad'),
        ThemeChoice.amber => tr('Tungi Oltin'),
      };

  String get badge => switch (this) {
        ThemeChoice.graphite => tr('Standart'),
        ThemeChoice.quartz => tr('Kunduzgi'),
        ThemeChoice.emerald => tr('Energiya'),
        ThemeChoice.amber => tr('VIP klub'),
      };

  String get tag => switch (this) {
        ThemeChoice.graphite => 'Graphite Dark · Crimson',
        ThemeChoice.quartz => 'Quartz Light · Clean',
        ThemeChoice.emerald => 'Cyber Emerald · Mint',
        ThemeChoice.amber => 'Midnight Gold · Amber',
      };

  String get description => switch (this) {
        ThemeChoice.graphite => tr("Qorong'i grafit fon, yorqin qizil urg'u"),
        ThemeChoice.quartz => tr("Yorug' va toza kvars fon, qirollik qizil urg'u"),
        ThemeChoice.emerald => tr("To'q slanets fon, baquvvat neon zumrad urg'u"),
        ThemeChoice.amber => tr("Obsidian fon, VIP qirollik oltin urg'u"),
      };
}

ThemeChoice currentThemeChoice() {
  if (AppColors.light) return ThemeChoice.quartz;
  return switch (AppSettings.palette.value) {
    AppPalette.emerald => ThemeChoice.emerald,
    AppPalette.amber => ThemeChoice.amber,
    AppPalette.graphite => ThemeChoice.graphite,
  };
}

Future<void> applyThemeChoice(ThemeChoice c) async {
  await AppSettings.setPalette(c.palette);
  await AppSettings.setThemeMode(c.isLight ? ThemeMode.light : ThemeMode.dark);
}

Future<void> showThemePicker(BuildContext context) =>
    showSheet<void>(context, const _ThemePickerSheet());

class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: ListenableBuilder(
        listenable: Listenable.merge([AppSettings.themeMode, AppSettings.palette]),
        builder: (context, _) {
          final selected = currentThemeChoice();
          final system = AppSettings.themeMode.value == ThemeMode.system;
          return ListView(shrinkWrap: true, children: [
            Text(tr('Dizayn mavzulari'), style: t.titleLarge),
            const SizedBox(height: AppSpace.xs),
            Text(tr('Aura Fit uchun 4 ta rang palitrasi'),
                style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpace.md),
            Text(tr("Tugmalar, kartalar, chiziqlar va fon ranglari tanlangan mavzuga darhol o'zgaradi."),
                style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpace.md),
            for (final c in ThemeChoice.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: _ThemeCard(
                    choice: c, selected: c == selected, onTap: () => applyThemeChoice(c)),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: system,
              onChanged: (v) => AppSettings.setThemeMode(
                  v ? ThemeMode.system : (AppColors.light ? ThemeMode.light : ThemeMode.dark)),
              title: Text(tr('Telefon sozlamasiga ergashish')),
              subtitle: Text(tr("Telefon qorong'i bo'lsa tanlangan rang, yorug' bo'lsa Kvars"),
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
  const _ThemeCard({required this.choice, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sw = AppColors.swatch(choice.palette, isLight: choice.isLight);
    return Semantics(
      button: true,
      selected: selected,
      label: choice.title,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: kTouchTarget),
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentContainer : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.hairline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            _Miniature(bg: sw.bg, card: sw.card, accent: sw.accent),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(choice.title, style: t.titleSmall),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.hairlineSoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(choice.badge.toUpperCase(),
                        style: t.labelSmall?.copyWith(color: AppColors.textMuted)),
                  ),
                ]),
                const SizedBox(height: AppSpace.xs),
                Text(choice.tag, style: t.labelSmall?.copyWith(color: AppColors.textFaint)),
                const SizedBox(height: AppSpace.xs),
                Text(choice.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              ]),
            ),
            const SizedBox(width: AppSpace.sm),
            Icon(selected ? Icons.check_circle_outlined : Icons.circle_outlined,
                color: selected ? AppColors.accent : AppColors.textFaint),
          ]),
        ),
      ),
    );
  }
}

class _Miniature extends StatelessWidget {
  final Color bg;
  final Color card;
  final Color accent;
  const _Miniature({required this.bg, required this.card, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.hairlineStrong),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Expanded(child: Container(height: 4, color: card)),
        ]),
        const Spacer(),
        Container(
          height: 8,
          decoration:
              BoxDecoration(color: accent, borderRadius: BorderRadius.circular(AppRadius.sm)),
        ),
      ]),
    );
  }
}
