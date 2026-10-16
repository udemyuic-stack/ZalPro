import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/tr.dart';
import '../../services/db.dart';
import '../../widgets/change_password.dart';
import '../../widgets/lazy_stack.dart';
import '../../widgets/settings_sheet.dart';
import '../../widgets/lang_picker.dart';
import '../../widgets/ui.dart';
import '../admin/sales_report_screen.dart';
import '../admin/shop_admin_screen.dart';
import '../notifications_screen.dart';
import '../payments_screen.dart';

/// Barmen paneli — zal bari/sotuvchisi uchun.
/// Faqat do'kon: tovar, buyurtma, qoldiq va o'z sotuv hisoboti.
/// Shogirdlar, rejalar va chatni ko'rmaydi; zal mijozlarining abonement to'lovini ko'radi.
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
            Text(tr(_titles[_tab]).toUpperCase()),
            Text(
              tr('Barmen • Aura Fit'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: s.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          // til — ichkarida ham bir bosishda almashadi
          const LangPicker(iconOnly: true),
          IconButton(
            tooltip: tr('Sozlamalar'),
            onPressed: () => showSettings(context, student: false),
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: tr("Parolni o'zgartirish"),
            onPressed: () => showChangePassword(context),
            icon: const Icon(Icons.key_outlined),
          ),
          IconButton(tooltip: tr('Chiqish'), onPressed: _signOut, icon: const Icon(Icons.logout)),
          const SizedBox(width: 4),
        ],
      ),
      body: LazyIndexedStack(
        index: _tab,
        children: [
          ShopAdminScreen(admin: me),
          // o'z sotuvi: nechta va qancha — zal egasiga shu bo'yicha hisob beradi
          SalesReportScreen(me: me, ownerView: false),
          // zal mijozlarining abonement to'lovlari — faqat ko'rish
          PaymentsScreen(me: me),
          NotificationsScreen(user: me),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.storefront_outlined), label: tr("Do'kon")),
          NavigationDestination(icon: const Icon(Icons.payments_outlined), label: tr('Hisobim')),
          NavigationDestination(
              icon: const Icon(Icons.card_membership_outlined), label: tr("To'lovlar")),
          NavigationDestination(
            icon: FeedBadge(user: me, icon: const Icon(Icons.notifications_none)),
            label: tr('Eslatma'),
          ),
        ],
      ),
    );
  }
}
