import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/tr.dart';
import '../../services/db.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/lazy_stack.dart';
import '../../widgets/notification_sync.dart';
import 'today_screen.dart';
import 'progress_screen.dart';
import 'trainer_tab.dart';
import 'gym_screen.dart';
import 'profile_screen.dart';

class UserHome extends ConsumerWidget {
  const UserHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    if (me == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return StudentNotificationSync(
      user: me,
      child: StudentShell(
        pages: (signals) => [
          TodayScreen(
            user: me,
            onStartWorkout: () async {
              signals.goTo(StudentShell.gymTab);
              try {
                await Db.startWorkout(me.id, todayKey());
              } catch (_) {}
              signals.openGym.value++;
            },
          ),
          ProgressScreen(user: me),
          GymScreen(user: me, openSignal: signals.openGym, resetSignal: signals.resetGym),
          TrainerTab(user: me),
          ProfileScreen(user: me),
        ],
      ),
    );
  }
}

class StudentTabSignals {
  final ValueNotifier<int> openGym;
  final ValueNotifier<int> resetGym;
  final void Function(int tab) goTo;
  const StudentTabSignals(this.openGym, this.resetGym, this.goTo);
}

class StudentShell extends StatefulWidget {
  static const gymTab = 2;
  final List<Widget> Function(StudentTabSignals signals) pages;
  const StudentShell({super.key, required this.pages});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _tab = 0;
  final _openGym = ValueNotifier<int>(0);
  final _resetGym = ValueNotifier<int>(0);

  @override
  void dispose() {
    _openGym.dispose();
    _resetGym.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _tab) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      if (i == StudentShell.gymTab) _resetGym.value++;
      return;
    }
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LazyIndexedStack(
        index: _tab,
        children: widget.pages(StudentTabSignals(_openGym, _resetGym, _select)),
      ),
      bottomNavigationBar: AppNavBar(
        selected: _tab,
        onSelected: _select,
        items: [
          AppNavItem(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today),
            label: tr('Bugun'),
          ),
          AppNavItem(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: tr('Progress'),
          ),
          AppNavItem(
            icon: const Icon(Icons.fitness_center_outlined),
            selectedIcon: const Icon(Icons.fitness_center),
            label: tr('Zal'),
          ),
          AppNavItem(
            icon: const Icon(Icons.support_agent_outlined),
            selectedIcon: const Icon(Icons.support_agent),
            label: tr('Trener'),
          ),
          AppNavItem(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: tr('Profil'),
          ),
        ],
      ),
    );
  }
}
