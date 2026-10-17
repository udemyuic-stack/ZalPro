import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/tr.dart';
import '../../services/db.dart';
import '../../widgets/app_nav_bar.dart';
import '../../theme.dart';
import '../../widgets/lazy_stack.dart';
import '../../widgets/scan_sheet.dart';
import '../../widgets/settings_sheet.dart';
import '../../widgets/ui.dart';
import '../admin/sales_report_screen.dart';
import '../admin/shop_admin_screen.dart';
import '../notifications_screen.dart';
import '../payments_screen.dart';

class BarmenHome extends ConsumerStatefulWidget {
  const BarmenHome({super.key});

  @override
  ConsumerState<BarmenHome> createState() => _BarmenHomeState();
}

class _BarmenHomeState extends ConsumerState<BarmenHome> {
  int _tab = 0;

  static const _titles = ["Do'kon", 'Sotuv hisobim', "To'lovlar", 'Eslatmalar'];

  Future<void> _signOut() async {
    final ok = await confirm(
      context,
      title: tr('Chiqish'),
      message: tr('Barmen panelidan chiqmoqchimisiz?'),
      ok: tr('Chiqish'),
      destructive: true,
    );
    if (ok) await AuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).value;
    if (me == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final s = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(_titles[_tab])),
            Text(
              tr('Barmen • Aura Fit'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: s.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr('Skaner'),
            constraints: const BoxConstraints(minWidth: kTouchTarget, minHeight: kTouchTarget),
            onPressed: () => showCheckinScanner(context),
            icon: const Icon(Icons.qr_code_scanner_outlined),
          ),
          IconButton(
            tooltip: tr('Sozlamalar'),
            onPressed: () => showSettings(context, student: false),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(tooltip: tr('Chiqish'), onPressed: _signOut, icon: const Icon(Icons.logout)),
          const SizedBox(width: 4),
        ],
      ),
      body: LazyIndexedStack(
        index: _tab,
        children: [
          ShopAdminScreen(admin: me),
          SalesReportScreen(me: me, ownerView: false),
          PaymentsScreen(me: me),
          NotificationsScreen(user: me),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        selected: _tab,
        onSelected: (i) => setState(() => _tab = i),
        items: [
          AppNavItem(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront),
            label: tr("Do'kon"),
          ),
          AppNavItem(
            icon: const Icon(Icons.payments_outlined),
            selectedIcon: const Icon(Icons.payments),
            label: tr('Hisobim'),
          ),
          AppNavItem(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: tr("To'lovlar"),
          ),
          AppNavItem(
            icon: FeedBadge(user: me, icon: const Icon(Icons.notifications_none)),
            selectedIcon: FeedBadge(user: me, icon: const Icon(Icons.notifications)),
            label: tr('Eslatma'),
          ),
        ],
      ),
    );
  }
}
