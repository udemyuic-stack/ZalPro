import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../services/notifications.dart';
import '../services/settings.dart';
import '../theme.dart';
import 'lang_picker.dart';
import 'ui.dart';

/// Sozlamalar: ko'rinish (tema) va bildirishnomalar.
/// [student] — shogird uchun ovqat/vazn/reja eslatmalari ham ko'rsatiladi.
Future<void> showSettings(BuildContext context, {required bool student}) =>
    showSheet<void>(context, _SettingsSheet(student: student));

class _SettingsSheet extends StatefulWidget {
  final bool student;
  const _SettingsSheet({required this.student});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  Future<void> _toggle(String key, bool v) async {
    await AppSettings.setNotif(key, v);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget sw(String key, bool value, String title, String sub) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: value,
          onChanged: (v) => _toggle(key, v),
          title: Text(title),
          subtitle: Text(sub, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: ListView(shrinkWrap: true, children: [
        Text(tr('Sozlamalar'), style: t.titleLarge),
        const SizedBox(height: AppSpace.lg),
        Eyebrow(tr("Ko'rinish")),
        const SizedBox(height: AppSpace.sm),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: AppSettings.themeMode,
          builder: (context, mode, _) => SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_outlined),
                  label: Text(tr("Qorong'i"))),
              ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_outlined),
                  label: Text(tr("Yorug'"))),
              ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.phone_android_outlined),
                  label: Text(tr('Telefon'))),
            ],
            selected: {mode},
            onSelectionChanged: (s) {
              // tema almashganda ilova qayta chiziladi — varaqni yopamiz
              Navigator.pop(context);
              AppSettings.setThemeMode(s.first);
            },
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        Eyebrow(tr('Til')),
        const SizedBox(height: AppSpace.sm),
        // til almashganda ilova qayta chiziladi — varaqni yopamiz
        LangPicker(onChanged: () => Navigator.pop(context)),
        const SizedBox(height: AppSpace.xl),
        Eyebrow(tr('Bildirishnomalar')),
        if (!Notifications.supported)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: Text(
              tr("Bildirishnomalar telefondagi (Android) ilovada ishlaydi."),
              style: t.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
        if (widget.student) ...[
          sw('notif_meals', AppSettings.mealReminders, tr('Ovqat vaqti eslatmasi'),
              tr('Rejadagi har mahal vaqtida eslatadi')),
          sw('notif_weight', AppSettings.weighInReminder, tr('Haftalik vazn eslatmasi'),
              tr('Vazn kiritish kuni ertalab 08:00 da')),
          sw('notif_plan', AppSettings.planNotifications, tr('Yangi reja'),
              tr('Trener reja biriktirganda')),
        ],
        sw('notif_chat', AppSettings.chatNotifications, tr('Yangi xabar'),
            widget.student ? tr('Trener yozganda') : tr('Shogird yozganda')),
      ]),
    );
  }
}
