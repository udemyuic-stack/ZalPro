import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/tr.dart';
import '../../services/api/api_error.dart';
import '../../services/db.dart';
import '../../services/screen_guard.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';
import '../admin/admin_home.dart';
import '../barmen/barmen_home.dart';
import '../user/profile_setup_screen.dart';
import '../user/user_home.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return auth.when(
      loading: () => const _Splash(),
      error: (e, _) => _ErrorView(message: apiErrorText(e)),
      data: (user) {
        if (user == null) {
          ScreenGuard.set(false);
          return const LoginScreen();
        }
        final me = ref.watch(meProvider);
        return me.when(
          loading: () => const _Splash(),
          error: (e, _) => _ErrorView(message: apiErrorText(e)),
          data: (u) {
            if (u == null) return const _Splash();
            ScreenGuard.set(!u.isAdmin && !u.isBarmen);
            if (u.isAdmin) return const AdminHome();
            if (u.isBarmen) return const BarmenHome();
            final trainers = ref.watch(trainerDirectoryProvider).value ?? const [];
            final needTrainer = u.trainerId == null && trainers.isNotEmpty;
            if (!u.profileDone || u.goal.isEmpty || u.metabolism.isEmpty || needTrainer) {
              return ProfileSetupScreen(user: u);
            }
            return const UserHome();
          },
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(gradient: AppColors.headerGradient),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AuraLogo(size: 44, stacked: true),
              const SizedBox(height: AppSpace.xxl),
              SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: EmptyState(
          icon: Icons.error_outline,
          title: tr('Xatolik yuz berdi'),
          subtitle: message,
          action: OutlinedButton(onPressed: AuthService.signOut, child: Text(tr('Qayta kirish'))),
        ),
      );
}
