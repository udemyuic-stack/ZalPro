import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/tr.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/change_password.dart';
import '../../widgets/join_qr_sheet.dart';
import '../../widgets/lazy_stack.dart';
import '../../widgets/notification_sync.dart';
import '../../widgets/settings_sheet.dart';
import '../../widgets/lang_picker.dart';
import '../../widgets/ui.dart';
import '../notifications_screen.dart';
import 'clients_screen.dart';
import 'gym_admin_screen.dart';
import 'plans_screen.dart';
import 'foods_screen.dart';
import 'shop_admin_screen.dart';
import 'staff_screen.dart';
import 'subscriptions_screen.dart';

class AdminHome extends ConsumerStatefulWidget {
  const AdminHome({super.key});
  @override
  ConsumerState<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends ConsumerState<AdminHome> {
  int _tab = 0;

  // Bosh adminda qo'shimcha "Xodimlar" bo'limi bo'ladi
  static const _trainerTitles = [
    'Mijozlar',
    'Abonement',
    'Zal',
    'Ovqatlanish rejalari',
    'Mahsulotlar bazasi',
    "Do'kon",
    'Eslatmalar',
  ];
  static const _ownerTitles = [..._trainerTitles, 'Xodimlar va shogirdlar'];

  Future<void> _signOut() async {
    final ok = await confirm(
      context,
      title: tr('Chiqish'),
      message: tr('Trener panelidan chiqmoqchimisiz?'),
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
    final titles = me.isOwner ? _ownerTitles : _trainerTitles;
    // Rol o'zgarsa (masalan trenerlikdan olinsa) tanlangan bo'lim chegaradan chiqmasin
    final tab = _tab < titles.length ? _tab : 0;
    final scaffold = Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(titles[tab]).toUpperCase()),
            Text(
              me.isOwner ? tr('Bosh admin • Aura Fit') : tr('Trener paneli • Aura Fit'),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: me.isOwner ? AppColors.accent : s.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr('QR kod'),
            onPressed: () => showJoinQr(context),
            icon: const Icon(Icons.qr_code_2_outlined),
          ),
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
      body: Column(children: [
        Expanded(
          child: LazyIndexedStack(
            index: tab,
            children: [
              ClientsScreen(admin: me),
              SubscriptionsScreen(admin: me),
              GymAdminScreen(admin: me),
              const PlansScreen(),
              const FoodsScreen(),
              ShopAdminScreen(admin: me),
              NotificationsScreen(user: me),
              if (me.isOwner) StaffScreen(owner: me),
            ],
          ),
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        // bo'lim ko'p — yozuv faqat tanlanganida
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        // Faqat ingichka chiziqli ikonkalar (dizayn qoidasi)
        destinations: [
          NavigationDestination(icon: const Icon(Icons.people_outline), label: tr('Mijozlar')),
          NavigationDestination(
              icon: const Icon(Icons.card_membership_outlined), label: tr('Abonement')),
          NavigationDestination(icon: const Icon(Icons.fitness_center_outlined), label: tr('Zal')),
          NavigationDestination(icon: const Icon(Icons.menu_book_outlined), label: tr('Rejalar')),
          NavigationDestination(icon: const Icon(Icons.egg_alt_outlined), label: tr('Ovqat')),
          NavigationDestination(icon: const Icon(Icons.storefront_outlined), label: tr("Do'kon")),
          NavigationDestination(
            icon: FeedBadge(user: me, icon: const Icon(Icons.notifications_none)),
            label: tr('Eslatma'),
          ),
          if (me.isOwner)
            NavigationDestination(icon: const Icon(Icons.badge_outlined), label: tr('Xodimlar')),
        ],
      ),
    );
    // Trener shogirdlaridan kelgan xabarlar haqida bildirishnoma oladi
    return me.isTrainer ? TrainerNotificationSync(trainer: me, child: scaffold) : scaffold;
  }
}
