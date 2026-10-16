import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/tr.dart';
import '../services/api/upgrade_gate.dart';
import '../widgets/ui.dart';

class UpgradeGate extends StatelessWidget {
  const UpgradeGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UpgradeInfo?>(
      valueListenable: upgradeRequired,
      builder: (context, info, _) =>
          info == null ? child : UpgradeScreen(downloadUrl: info.downloadUrl),
    );
  }
}

class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key, required this.downloadUrl});

  final String downloadUrl;

  Future<void> _open(BuildContext context) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && context.mounted) {
      showSnack(context, tr("Havolani ochib bo'lmadi — nusxalab brauzerda oching"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.system_update_outlined,
          title: tr('Ilova eskirgan'),
          subtitle: tr('Yangi versiyani yuklab oling'),
          action: downloadUrl.isEmpty
              ? null
              : FilledButton(
                  onPressed: () => _open(context),
                  child: Text(tr('Yuklab olish')),
                ),
        ),
      ),
    );
  }
}
