import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../services/settings.dart';

/// Til tanlash: O'zbek / Русский / English. Tanlanganda butun ilova shu tilga o'tadi.
/// [compact] — kirish ekrani va Profil uchun kichik tugma (ochiladigan ro'yxat);
/// [iconOnly] — tepa panel uchun faqat globus belgisi; aks holda Sozlamalar uchun
/// uch bo'lakli tugma.
class LangPicker extends StatelessWidget {
  final bool compact;
  final bool iconOnly;

  /// Til almashgandan keyin (masalan, varaqni yopish uchun)
  final VoidCallback? onChanged;
  const LangPicker({super.key, this.compact = false, this.iconOnly = false, this.onChanged});

  void _set(String code) {
    onChanged?.call();
    AppSettings.setLang(code);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) {
        if (iconOnly) {
          return PopupMenuButton<String>(
            tooltip: tr('Til'),
            initialValue: lang,
            onSelected: _set,
            icon: const Icon(Icons.language),
            itemBuilder: (_) => [
              for (final e in appLangs.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
            ],
          );
        }
        if (compact) {
          return PopupMenuButton<String>(
            initialValue: lang,
            onSelected: _set,
            itemBuilder: (_) => [
              for (final e in appLangs.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.language, size: 18),
                const SizedBox(width: 6),
                Text(appLangs[lang] ?? lang),
                const Icon(Icons.arrow_drop_down, size: 18),
              ]),
            ),
          );
        }
        return SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final e in appLangs.entries) ButtonSegment(value: e.key, label: Text(e.value)),
            ],
            selected: {lang},
            onSelectionChanged: (s) => _set(s.first),
          ),
        );
      },
    );
  }
}
