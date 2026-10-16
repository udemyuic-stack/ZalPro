import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/tr.dart';
import '../../services/db.dart';
import '../../widgets/lazy_stack.dart';
import '../../widgets/notification_sync.dart';
import '../notifications_screen.dart';
import 'today_screen.dart';
import 'progress_screen.dart';
import 'chat_screen.dart';
import 'gym_screen.dart';
import 'shop_screen.dart';
import 'profile_screen.dart';

class UserHome extends ConsumerStatefulWidget {
  const UserHome({super.key});
  @override
  ConsumerState<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends ConsumerState<UserHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).value;
    if (me == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // IndexedStack — bo'limlar almashganda scroll holati saqlanadi
    return StudentNotificationSync(
      user: me,
      child: Scaffold(
        body: LazyIndexedStack(
          index: _tab,
          children: [
            TodayScreen(user: me),
            ProgressScreen(user: me),
            GymScreen(user: me),
            ShopScreen(user: me),
            NotificationsScreen(user: me),
            ChatScreen(
              chatUid: me.id,
              myId: me.id,
              title: tr('Trener'),
              subtitle: tr('Savollaringizga javob beradi'),
            ),
            ProfileScreen(user: me),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          // 7 ta bo'lim — yozuv faqat tanlanganida ko'rinadi, aks holda tiqilib ketadi
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          // Faqat ingichka chiziqli ikonkalar — tanlangani rang bilan ajraladi
          destinations: [
            NavigationDestination(icon: const Icon(Icons.today_outlined), label: tr('Bugun')),
            NavigationDestination(icon: const Icon(Icons.insights_outlined), label: tr('Progress')),
            NavigationDestination(
                icon: const Icon(Icons.fitness_center_outlined), label: tr('Zal')),
            NavigationDestination(icon: const Icon(Icons.storefront_outlined), label: tr("Do'kon")),
            NavigationDestination(
              icon: FeedBadge(user: me, icon: const Icon(Icons.notifications_none)),
              label: tr('Eslatma'),
            ),
            NavigationDestination(icon: const Icon(Icons.chat_bubble_outline), label: tr('Trener')),
            NavigationDestination(icon: const Icon(Icons.person_outline), label: tr('Profil')),
          ],
        ),
      ),
    );
  }
}
