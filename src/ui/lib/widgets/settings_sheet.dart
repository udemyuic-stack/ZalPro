import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../services/notifications.dart';
import '../services/settings.dart';
import '../theme.dart';
import 'change_password.dart';
import 'lang_picker.dart';
import 'ui.dart';

Future<void> showSettings(
  BuildContext context, {
  required bool student,
  VoidCallback? onSignOut,
}) =>
    showSheet<void>(context, _SettingsSheet(student: student, host: context, onSignOut: onSignOut));

class _SettingsSheet extends StatefulWidget {
  final bool student;
  final BuildContext host;
  final VoidCallback? onSignOut;
  const _SettingsSheet({required this.student, required this.host, this.onSignOut});

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
          builder: (context, mode, _) => AppSegmented<ThemeMode>(
            segments: [
              AppSegment(
                  value: ThemeMode.dark, icon: Icons.dark_mode_outlined, label: tr("Qorong'i")),
              AppSegment(
                  value: ThemeMode.light, icon: Icons.light_mode_outlined, label: tr("Yorug'")),
              AppSegment(
                  value: ThemeMode.system,
                  icon: Icons.phone_android_outlined,
                  label: tr('Telefon')),
            ],
            selected: mode,
            onChanged: AppSettings.setThemeMode,
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        Eyebrow(tr('Til')),
        const SizedBox(height: AppSpace.sm),
        const LangPicker(),
        if (!widget.student) ...[
          const SizedBox(height: AppSpace.md),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              if (widget.host.mounted) showChangePassword(widget.host);
            },
            icon: const Icon(Icons.key_outlined),
            label: Text(tr("Parolni o'zgartirish")),
          ),
        ],
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
        if (widget.onSignOut != null) ...[
          const SizedBox(height: AppSpace.xl),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(context);
              if (widget.host.mounted) widget.onSignOut!();
            },
            icon: const Icon(Icons.logout),
            label: Text(tr('Chiqish')),
          ),
        ],
      ]),
    );
  }
}
