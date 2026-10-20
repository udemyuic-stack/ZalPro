import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/kcal_target.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/change_password.dart';
import '../../widgets/game_widgets.dart';
import '../../widgets/lang_picker.dart';
import '../../widgets/settings_sheet.dart';
import '../../widgets/subscription_card.dart';
import '../../widgets/trainer_picker.dart';
import '../../widgets/ui.dart';
import 'profile_setup_screen.dart';

class ProfileScreen extends StatelessWidget {
  final AppUser user;
  const ProfileScreen({super.key, required this.user});

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirm(
      context,
      title: tr('Chiqish'),
      message: tr('Akkauntdan chiqmoqchimisiz?'),
      ok: tr('Chiqish'),
      destructive: true,
    );
    if (ok) await AuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final male = user.gender == 'male';
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Editorial bosh blok: chapda yirik ism, o'ngda squircle avatar
          GradientHeader(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.xl),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Eyebrow(tr('Profil'), color: AppColors.textFaint),
                const SizedBox(height: AppSpace.xl),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        user.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.headlineMedium?.copyWith(color: AppColors.text),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        userContact(user.phone, user.email),
                        style: t.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                          fontFeatures: tabular,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: AppSpace.lg),
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Text(
                      initials(user.name),
                      style: TextStyle(
                        color: AppColors.onAccent,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (user.role == 'user') ...[
                GameLevelCard(user: user),
                const SizedBox(height: 10),
              ],
              Row(children: [
                Expanded(
                  child: StatTile(
                    icon: male ? Icons.male : Icons.female,
                    label: tr('Jins'),
                    value: male ? tr('Erkak') : tr('Ayol'),
                    color: AppColors.protein,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    icon: Icons.cake_outlined,
                    label: tr('Yosh'),
                    value: '${user.age}',
                    color: AppColors.warning,
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.height,
                    label: tr("Bo'y"),
                    value: trf('{0} sm', [user.height.round()]),
                    color: AppColors.water,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    icon: Icons.monitor_weight_outlined,
                    label: tr('Vazn'),
                    value: trf('{0} kg', [fmtNum(user.weight)]),
                    color: s.primary,
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: StatTile(
                    icon: user.isGain ? Icons.trending_up : Icons.trending_down,
                    label: tr('Maqsad'),
                    value: user.goalLabel.isEmpty ? '—' : tr(user.goalLabel),
                    color: user.isGain ? AppColors.protein : AppColors.water,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    icon: user.metabolism == 'fast' ? Icons.bolt_outlined : Icons.hourglass_bottom,
                    label: tr('Metabolizm'),
                    value: switch (user.metabolism) {
                      'fast' => tr('Tez'),
                      'slow' => tr('Sekin'),
                      _ => '—',
                    },
                    color: AppColors.warning,
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              MySubscriptionCard(uid: user.id),
              if (user.trainerId != null) ...[
                const SizedBox(height: 10),
                StreamBuilder<TrainerInfo?>(
                  stream: Db.trainerProfile(user.trainerId!),
                  builder: (context, snap) => StatTile(
                    icon: Icons.badge_outlined,
                    label: tr('Treneringiz'),
                    value: snap.data?.name ?? '—',
                    color: AppColors.accent,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => pickTrainer(context, user),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: Text(tr('Trenerni almashtirish')),
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.md),
              BmiCard(bmi: user.bmi),
              const SizedBox(height: AppSpace.md),
              StreamBuilder<Plan?>(
                stream: user.planId == null ? Stream.value(null) : Db.plan(user.planId!),
                builder: (context, snap) => _TargetCard(
                  user: user,
                  target: kcalTargetOf(user, snap.data, DateTime.now().weekday),
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileSetupScreen(user: user, editing: true)),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: Text(tr("Ma'lumotlarni o'zgartirish")),
              ),
              const SizedBox(height: 8),
              // Til — kirgandan keyin ham shu yerdan almashadi
              Container(
                padding: const EdgeInsets.only(left: AppSpace.lg, right: AppSpace.sm),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(children: [
                  const Icon(Icons.language, size: 20),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: Text(tr('Til'))),
                  const LangPicker(compact: true),
                ]),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => showSettings(context, student: true),
                icon: const Icon(Icons.settings_outlined),
                label: Text(tr("Sozlamalar (ko'rinish, bildirishnomalar)")),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => showChangePassword(context),
                icon: const Icon(Icons.key_outlined),
                label: Text(tr("Parolni o'zgartirish")),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: s.error, minimumSize: const Size(64, kTouchTarget)),
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout),
                label: Text(tr('Chiqish')),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

/// BMI shkalasi: rangli oraliqlar va foydalanuvchi joylashuvi
class BmiCard extends StatelessWidget {
  final double bmi;
  const BmiCard({super.key, required this.bmi});

  static const _lo = 15.0, _hi = 40.0;
  static List<(double, String, Color, Color)> get _segments => [
        (18.5, tr('Vazn kam'), AppColors.water, AppColors.water),
        (25.0, tr('Normal'), AppColors.success, AppColors.successText),
        (30.0, tr('Ortiqcha vazn'), AppColors.warning, AppColors.warning),
        (40.0, tr('Semizlik'), AppColors.danger, AppColors.danger),
      ];

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final segments = _segments;
    final idx = segments.indexWhere((sg) => bmi < sg.$1);
    final seg = segments[idx == -1 ? segments.length - 1 : idx];
    return Semantics(
      label: trf('Tana massasi indeksi: {0}, {1}', [bmi.toStringAsFixed(1), seg.$2]),
      excludeSemantics: true,
      child: BentoTile(
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Eyebrow(tr('Tana massasi indeksi'), color: s.onSurfaceVariant)),
              Pill(text: seg.$2, color: seg.$3, textColor: seg.$4),
            ]),
            const SizedBox(height: AppSpace.sm),
            Text(
              bmi.toStringAsFixed(1),
              style: t.displaySmall?.copyWith(fontFeatures: tabular),
            ),
            const SizedBox(height: AppSpace.lg),
            LayoutBuilder(builder: (context, c) {
              final x = (bmi.clamp(_lo, _hi) - _lo) / (_hi - _lo) * c.maxWidth;
              return SizedBox(
                height: 22,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 7,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: Row(children: [
                        for (var i = 0; i < segments.length; i++)
                          Expanded(
                            flex: ((segments[i].$1 - (i == 0 ? _lo : segments[i - 1].$1)) * 10)
                                .round(),
                            child: Container(height: 8, color: segments[i].$3),
                          ),
                      ]),
                    ),
                  ),
                  Positioned(
                    left: (x - 11).clamp(0.0, c.maxWidth - 22),
                    top: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.text,
                        shape: BoxShape.circle,
                        border: Border.all(color: seg.$3, width: 4),
                        // soyasiz dizayn — belgi ink halqa bilan ajratiladi
                      ),
                    ),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 10),
            Text(tr('Normal oraliq: 18.5 – 24.9'),
                style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  final AppUser user;
  final KcalTarget target;
  const _TargetCard({required this.user, required this.target});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hint = target.fromPlan
        ? (target.recommended == null
            ? tr('Trener rejasi')
            : trf('Tavsiya: {0} kkal', [target.recommended]))
        : trf('Tavsiya etilgan me\'yor: {0}', [user.kcalFormula]);
    return BentoTile(
      feature: true,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Eyebrow(tr(target.fromPlan ? 'Kunlik maqsad' : 'Kunlik norma'),
                color: AppColors.textFaint),
            const SizedBox(height: AppSpace.xs),
            Text(hint, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          ]),
        ),
        const SizedBox(width: AppSpace.md),
        Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${target.target}',
                style: t.headlineMedium?.copyWith(
                  color: AppColors.accent,
                  fontFeatures: tabular,
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Text(tr('kkal'), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ]),
      ]),
    );
  }
}
