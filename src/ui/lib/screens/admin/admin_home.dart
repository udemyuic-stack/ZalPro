import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/tr.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/announcement_sheet.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/join_qr_sheet.dart';
import '../../widgets/lazy_stack.dart';
import '../../widgets/notification_sync.dart';
import '../../widgets/scan_sheet.dart';
import '../../widgets/settings_sheet.dart';
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

  static const _trainerTitles = [
    'Mijozlar',
    'Obuna',
    'Zal',
    'Ovqatlanish rejalari',
    'Eslatmalar',
    'Mahsulotlar bazasi',
    "Do'kon",
  ];
  static const _ownerTitles = [..._trainerTitles, 'Xodimlar'];

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
    final tab = _tab < titles.length ? _tab : 0;
    final scaffold = Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(titles[tab])),
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
            tooltip: tr("E'lonlar"),
            constraints: const BoxConstraints(minWidth: kTouchTarget, minHeight: kTouchTarget),
            onPressed: () => showAnnouncementManager(context, me),
            icon: const Icon(Icons.campaign_outlined),
          ),
          IconButton(
            tooltip: tr('Skaner'),
            constraints: const BoxConstraints(minWidth: kTouchTarget, minHeight: kTouchTarget),
            onPressed: () => showCheckinScanner(context),
            icon: const Icon(Icons.qr_code_scanner_outlined),
          ),
          IconButton(
            tooltip: tr("Ro'yxatdan o'tish QR kodi"),
            onPressed: () => showJoinQr(context),
            icon: const Icon(Icons.person_add_alt_outlined),
          ),
          IconButton(
            tooltip: tr('Sozlamalar'),
            onPressed: () => showSettings(context, student: false, onSignOut: _signOut),
            icon: const Icon(Icons.settings_outlined),
          ),
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
              NotificationsScreen(user: me),
              const FoodsScreen(),
              ShopAdminScreen(admin: me),
              if (me.isOwner) StaffScreen(owner: me),
            ],
          ),
        ),
      ]),
      bottomNavigationBar: AppNavBar(
        selected: tab,
        onSelected: (i) => setState(() => _tab = i),
        primary: 5,
        moreIcon: const Icon(Icons.more_horiz),
        items: [
          AppNavItem(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: tr('Mijozlar'),
          ),
          AppNavItem(
            icon: const Icon(Icons.event_repeat_outlined),
            selectedIcon: const Icon(Icons.event_repeat),
            label: tr('Obuna'),
          ),
          AppNavItem(
            icon: const Icon(Icons.fitness_center_outlined),
            selectedIcon: const Icon(Icons.fitness_center),
            label: tr('Zal'),
          ),
          AppNavItem(
            icon: const Icon(Icons.assignment_outlined),
            selectedIcon: const Icon(Icons.assignment),
            label: tr('Rejalar'),
          ),
          AppNavItem(
            icon: FeedBadge(user: me, icon: const Icon(Icons.notifications_none)),
            selectedIcon: FeedBadge(user: me, icon: const Icon(Icons.notifications)),
            label: tr('Eslatma'),
          ),
          AppNavItem(
            icon: const Icon(Icons.restaurant_outlined),
            selectedIcon: const Icon(Icons.restaurant),
            label: tr('Ovqat'),
          ),
          AppNavItem(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront),
            label: tr("Do'kon"),
          ),
          if (me.isOwner)
            AppNavItem(
              icon: const Icon(Icons.badge_outlined),
              selectedIcon: const Icon(Icons.badge),
              label: tr('Xodimlar'),
            ),
        ],
      ),
    );
    return me.isTrainer ? TrainerNotificationSync(trainer: me, child: scaffold) : scaffold;
  }
}
