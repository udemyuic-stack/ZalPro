import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/extra_food_sheet.dart';
import '../../widgets/ui.dart';
import '../user/chat_screen.dart';
import '../user/progress_screen.dart';
import 'member_analytics_screen.dart';
import 'student_program_tab.dart';
import 'plans_screen.dart' show planTemplates;
import '../../services/api/api_error.dart';

class ClientsScreen extends StatefulWidget {
  final AppUser admin;
  const ClientsScreen({super.key, required this.admin});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  // Bosh admin hamma shogirdni, trener faqat o'ziga biriktirilganlarini ko'radi
  late final _stream = widget.admin.isOwner ? Db.clients() : Db.clientsOf(widget.admin.id);
  late final _plans = Db.plans();
  String _query = '';

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Plan>>(
      stream: _plans,
      builder: (context, ps) {
        if (ps.hasError) return ErrorState(error: ps.error);
        return _list(context, ps.data);
      });

  Widget _list(BuildContext context, List<Plan>? plans) {
    final s = Theme.of(context).colorScheme;
    final plansById = {for (final p in plans ?? <Plan>[]) p.id: p};
    // Reja bor, lekin shogird maqsadiga mos emas — bloklangan, shogirdga ko'rsatilmaydi
    bool mismatched(AppUser u) {
      final p = plansById[u.planId];
      return p != null && !u.fitsPlan(p);
    }

    return StreamBuilder<List<AppUser>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final all = snap.data!;
        if (all.isEmpty) {
          final empty = EmptyState(
            icon: Icons.people_outline,
            title: tr("Hali mijoz yo'q"),
            subtitle: widget.admin.isOwner
                ? tr("Mijozlar ilovada ro'yxatdan o'tgach, shu yerda paydo bo'ladi.")
                : tr("Shogirdlar ro'yxatdan o'tganda sizni katalogdan tanlaydi va shu yerda "
                    "paydo bo'ladi. \"Shogird qabul qilaman\" yoqilgan bo'lsin."),
          );
          if (!widget.admin.isTrainer) return empty;
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xl),
            children: [
              _MyCatalogCard(trainer: widget.admin),
              const SizedBox(height: AppSpace.xxl),
              empty,
            ],
          );
        }
        final waiting = all.where((u) => u.planId == null || mismatched(u)).length;
        final q = _query.trim().toLowerCase();
        final qDigits = q.replaceAll(RegExp(r'\D'), '');
        final list = all
            .where((u) =>
                u.name.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                (qDigits.isNotEmpty && u.phone.contains(qDigits)))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        final withPlan = all.length - waiting;
        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xl),
          children: [
            if (widget.admin.isTrainer) ...[
              _MyCatalogCard(trainer: widget.admin),
              const SizedBox(height: AppSpace.md),
              BentoTile(
                key: const Key('member-analytics-entry'),
                padding: const EdgeInsets.all(AppSpace.md),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MemberAnalyticsScreen(isOwner: false)),
                ),
                child: Row(children: [
                  IconBadge(Icons.groups_outlined, color: AppColors.accent, size: 38),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child:
                        Text(tr("A'zolar tahlili"), style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: AppColors.textFaint),
                ]),
              ),
              const SizedBox(height: AppSpace.md),
            ],
            FadeInUp(
              child: Row(children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.people_outline,
                    label: tr('Jami'),
                    value: '${all.length}',
                    color: s.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: StatTile(
                    icon: Icons.check_circle_outline,
                    label: tr('Reja bor'),
                    value: '$withPlan',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: StatTile(
                    icon: Icons.hourglass_empty,
                    label: tr('Kutmoqda'),
                    value: '$waiting',
                    color: waiting > 0 ? AppColors.warning : s.onSurfaceVariant,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.md),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: tr("Ism yoki telefon raqam bo'yicha qidirish"),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            SectionHeader(
              q.isEmpty ? tr("Ro'yxat") : tr('Qidiruv natijasi'),
              trailing: Text(
                '${list.length}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: s.onSurfaceVariant, fontFeatures: tabular),
              ),
            ),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xxl),
                child: Center(child: Text(tr('Hech narsa topilmadi'))),
              ),
            for (final u in list)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: ClientTile(
                  client: u,
                  planMismatch: mismatched(u),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ClientDetail(client: u, admin: widget.admin)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ClientTile extends StatelessWidget {
  final AppUser client;
  final bool planMismatch;
  final VoidCallback onTap;
  const ClientTile({
    super.key,
    required this.client,
    required this.onTap,
    this.planMismatch = false,
  });

  @override
  Widget build(BuildContext context) {
    final u = client;
    final s = Theme.of(context).colorScheme;
    final Widget status = !u.profileDone
        ? Pill(text: tr("Anketa yo'q"), color: s.outline)
        : u.planId == null
            ? Pill(text: tr('Rejasiz'), color: AppColors.warning)
            : planMismatch
                ? Pill(text: tr('Reja mos emas'), color: AppColors.danger)
                : Pill(text: tr('Reja bor'), color: AppColors.success, icon: Icons.check_rounded);
    final t = Theme.of(context).textTheme;
    return BentoTile(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(children: [
        UserAvatar(name: u.name),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              u.name.isEmpty ? userContact(u.phone, u.email) : u.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.titleMedium,
            ),
            const SizedBox(height: 4),
            Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
              if (u.goal.isNotEmpty)
                GoalPill(user: u)
              else
                Pill(text: tr('Maqsad?'), color: AppColors.warning),
              status,
            ]),
            const SizedBox(height: 2),
            Text(
              u.profileDone
                  ? trf('{0} kg · BMI {1} · {2} kkal',
                      [fmtNum(u.weight), u.bmi.toStringAsFixed(1), u.targetKcal])
                  : userContact(u.phone, u.email),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall?.copyWith(
                color: s.onSurfaceVariant,
                fontFeatures: tabular,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class ClientDetail extends StatelessWidget {
  final AppUser client;
  final AppUser admin;
  const ClientDetail({super.key, required this.client, required this.admin});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: Db.user(client.id),
      builder: (context, snap) {
        final u = snap.data ?? client;
        final s = Theme.of(context).colorScheme;
        final dash = u.profileDone ? null : '—';
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(u.name),
              // Reja va progress alohida tablarda — telefonda ichma-ich o'ralish bo'lmasin
              bottom: TabBar(tabs: [
                Tab(icon: const Icon(Icons.restaurant_menu, size: 20), text: tr('Reja')),
                Tab(icon: const Icon(Icons.show_chart, size: 20), text: tr('Progress')),
                Tab(icon: const Icon(Icons.fitness_center, size: 20), text: tr('Mashqlar')),
              ]),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          chatUid: u.id,
                          myId: admin.id,
                          title: u.name,
                          subtitle: tr('Mijoz'),
                          // trener boshqa xodim (bosh admin) xabarlarini ko'rmaydi
                          onlyMineAndClient: admin.isTrainer,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: Text(tr('Chat')),
                  ),
                ),
              ],
            ),
            body: TabBarView(children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.monitor_weight_outlined,
                        label: tr('Vazn'),
                        value: dash ?? trf('{0} kg', [fmtNum(u.weight)]),
                        color: s.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: StatTile(
                        icon: Icons.speed,
                        label: tr('BMI'),
                        value: dash ?? u.bmi.toStringAsFixed(1),
                        color: AppColors.water,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: StatTile(
                        icon: Icons.local_fire_department_outlined,
                        label: tr('Norma'),
                        value: dash ?? '${u.targetKcal}',
                        color: AppColors.warning,
                      ),
                    ),
                  ]),
                  const SizedBox(height: AppSpace.md),
                  // shogird bugun rejadan tashqari nima yegan (bo'sh bo'lsa chiqmaydi)
                  ExtrasToday(uid: u.id, day: todayKey(), readOnly: true),
                  _PlanPicker(user: u),
                  // Trenerni faqat bosh admin biriktiradi
                  if (admin.isOwner) ...[
                    const SizedBox(height: AppSpace.md),
                    TrainerPicker(user: u),
                  ],
                ]),
              ),
              ProgressScreen(user: u, readOnly: true),
              StudentProgramTab(student: u),
            ]),
          ),
        );
      },
    );
  }
}

/// Maqsadga mos variant: bazada saqlangan reja (id bor) yoki hali saqlanmagan shablon
class _Variant {
  final Plan plan;
  final bool saved;
  const _Variant(this.plan, {required this.saved});
}

/// Shogird maqsadiga mos variantlar: har shablon (bazada shu nomli reja bo'lsa — o'sha reja)
/// va trener shu kategoriyada qo'lda tuzgan rejalar
List<_Variant> _variantsFor(String category, List<Plan> saved) {
  final inCategory = saved.where((p) => p.category == category).toList();
  final templates = planTemplates().where((p) => p.category == category).toList();
  return [
    for (final tpl in templates)
      inCategory
              .where((p) => p.title == tpl.title)
              .map((p) => _Variant(p, saved: true))
              .firstOrNull ??
          _Variant(tpl, saved: false),
    for (final p in inCategory)
      if (!templates.any((tpl) => tpl.title == p.title)) _Variant(p, saved: true),
  ];
}

class _PlanPicker extends StatefulWidget {
  final AppUser user;
  const _PlanPicker({required this.user});

  @override
  State<_PlanPicker> createState() => _PlanPickerState();
}

class _PlanPickerState extends State<_PlanPicker> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() job, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
      if (mounted) showSnack(context, done);
    } catch (e) {
      if (mounted) showSnack(context, trf("Saqlab bo'lmadi: {0}", [apiErrorText(e)]));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Variantni biriktirish: shablon hali saqlanmagan bo'lsa — avval bazaga reja qilib saqlanadi
  Future<void> _pick(_Variant v) => _run(() async {
        final id = v.saved ? v.plan.id : await Db.savePlan(v.plan);
        await Db.assignPlan(widget.user.id, id);
      }, tr('Reja biriktirildi'));

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: StreamBuilder<List<Plan>>(
          stream: Db.plans(),
          builder: (context, ps) {
            if (ps.hasError) return ErrorState(error: ps.error, compact: true);
            final plans = [...(ps.data ?? <Plan>[])]..sort((a, b) => a.title.compareTo(b.title));
            final variants = u.goalLabel.isEmpty ? <_Variant>[] : _variantsFor(u.goalLabel, plans);
            final current = plans.where((p) => p.id == u.planId).firstOrNull;
            bool warn(Plan p) => u.targetKcal > 0 && (p.kcal - u.targetKcal).abs() > 300;
            // Mos kelmaydigan reja bloklangan: nomi ko'rsatilmaydi, shogirdga ham chiqmaydi
            final blocked = current != null && !u.fitsPlan(current);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (u.profileDone)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Text(
                    trf('{0} • {1} yosh • {2} sm',
                        [u.gender == 'male' ? tr('Erkak') : tr('Ayol'), u.age, u.height.round()]),
                    style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant),
                  ),
                ),
              // Maqsad: shogird anketada tanlaydi; tanlamagan bo'lsa trener belgilaydi
              Eyebrow(tr('Maqsad')),
              const SizedBox(height: AppSpace.sm),
              // Maqsad belgilangan bo'lsa — aniq ko'rsatiladi, o'zgartirilmaydi (shogird tanlagan).
              // Bo'sh bo'lsa — trener ikkitadan birini belgilaydi.
              if (u.goal.isNotEmpty)
                Row(children: [
                  GoalPill(user: u),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      tr('Faqat shu maqsad rejalari beriladi'),
                      style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                ])
              else ...[
                Row(children: [
                  for (final (goal, label, icon) in [
                    // vazn kam (BMI < 18,5) bo'lsa ozish umuman ko'rsatilmaydi
                    if (u.canLose) ('lose', tr('Ozish'), Icons.trending_down),
                    ('gain', tr('Massa nabor'), Icons.trending_up),
                  ]) ...[
                    if (goal == 'gain' && u.canLose) const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(() => Db.setGoal(u.id, goal), trf('Maqsad: {0}', [label])),
                        icon: Icon(icon, size: 18),
                        label: Text(label),
                      ),
                    ),
                  ],
                ]),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm, left: 4),
                  child: Text(
                    tr("Shogird maqsadini hali tanlamagan — yangi versiyada kirganda so'raladi "
                        "yoki shu yerda o'zingiz belgilang. Maqsadsiz reja berib bo'lmaydi."),
                    style: t.bodySmall?.copyWith(color: AppColors.warning),
                  ),
                ),
              ],
              if (!u.canLose && u.goal.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm, left: 4),
                  child: Text(
                    trf('BMI {0} — vazn kam, faqat massa nabor mumkin.',
                        [u.bmi.toStringAsFixed(1)]),
                    style: t.bodySmall?.copyWith(color: AppColors.danger),
                  ),
                ),
              if (variants.isNotEmpty) ...[
                const SizedBox(height: AppSpace.lg),
                Eyebrow(trf('{0} — {1} ta variant', [tr(u.goalLabel), variants.length])),
                const SizedBox(height: AppSpace.sm),
                for (final v in variants)
                  _VariantTile(
                    variant: v,
                    selected: v.saved && v.plan.id == u.planId,
                    enabled: !_busy,
                    onTap: () => _pick(v),
                  ),
              ],
              // Boshqa kategoriyadagi rejani berib bo'lmaydi — faqat maqsadga mos variantlar.
              // Hozirgi reja variantlar orasida bo'lmasa (eski yoki boshqa kategoriya) — ko'rsatiladi.
              if (blocked)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.md),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.block, color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        u.goal.isEmpty
                            ? tr(
                                'Eski reja biriktirilgan — maqsad belgilangach mos variantni tanlang.')
                            : tr("Biriktirilgan reja maqsadga mos emas — bloklangan, shogirdga "
                                "ko'rsatilmaydi. Yuqoridagi variantlardan birini tanlang."),
                        style: t.bodySmall?.copyWith(color: AppColors.danger),
                      ),
                    ),
                  ]),
                )
              else if (current != null && !variants.any((v) => v.saved && v.plan.id == current.id))
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.md, left: 4),
                  child: Text(
                    trf('Hozir biriktirilgan: {0}', [tr(current.title)]),
                    style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant),
                  ),
                ),
              if (current != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() => Db.assignPlan(u.id, null), tr('Reja olib tashlandi')),
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(tr('Rejani olib tashlash')),
                  ),
                ),
              if (current != null && !blocked && warn(current)) ...[
                const SizedBox(height: AppSpace.md),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trf(
                          'Reja ({0} kkal) mijoz normasidan '
                          "({1} kkal) 300 kkal dan ko'proq farq qiladi.",
                          [current.kcal.round(), u.targetKcal]),
                      style: t.bodySmall,
                    ),
                  ),
                ]),
              ],
            ]);
          },
        ),
      ),
    );
  }
}

/// Bitta variant qatori: tanlangani belgili, saqlanmagan shablon "Shablon" deb yoziladi
class _VariantTile extends StatelessWidget {
  final _Variant variant;
  final bool selected, enabled;
  final VoidCallback onTap;
  const _VariantTile({
    required this.variant,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = variant.plan;
    final name =
        p.title.startsWith('${p.category} • ') ? p.title.substring(p.category.length + 3) : p.title;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Material(
        color: selected ? AppColors.accent.withValues(alpha: 0.12) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: selected ? AppColors.accent : AppColors.text.withValues(alpha: 0.12),
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled && !selected ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.md),
            child: Row(children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? AppColors.accent : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: t.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    p.meals.isEmpty && !p.isWeekly
                        ? tr("Faqat maslahatlar — mahallarni Rejalar bo'limida qo'shing")
                        : trf(
                            '{0}{1} mahal · '
                            '{2} kkal · {3} g oqsil',
                            [
                                p.isWeekly ? tr("Haftalik · ") : "",
                                p.mealsPerDay,
                                p.kcal.round(),
                                p.protein.round()
                              ]),
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted, fontFeatures: tabular),
                  ),
                ]),
              ),
              if (selected)
                Pill(text: tr('Biriktirilgan'), color: AppColors.accent)
              else if (!variant.saved)
                Pill(text: tr('Shablon'), color: AppColors.textMuted),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Shogird maqsadi: ozish (pastga) yoki massa nabor (yuqoriga)
class GoalPill extends StatelessWidget {
  final AppUser user;
  const GoalPill({super.key, required this.user});

  @override
  Widget build(BuildContext context) => user.goalLabel.isEmpty
      ? const SizedBox.shrink()
      : Pill(
          text: tr(user.goalLabel),
          color: user.isGain ? AppColors.protein : AppColors.water,
          icon: user.isGain ? Icons.trending_up : Icons.trending_down,
        );
}

/// Shogirdni trenerga biriktirish — faqat bosh admin ko'radi
class TrainerPicker extends StatelessWidget {
  final AppUser user;
  final Stream<List<AppUser>> Function()? trainersSource;
  final Future<void> Function(String uid, String? trainerId)? assign;
  const TrainerPicker({super.key, required this.user, this.trainersSource, this.assign});

  String _label(AppUser t) => t.name.isEmpty ? fmtPhone(t.phone) : t.name;

  Future<void> _open(BuildContext context, List<AppUser> staff, String? currentId) async {
    final picked = await showSheet<_TrainerChoice>(
      context,
      ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: ListView(shrinkWrap: true, children: [
          Text(tr('Biriktirilgan trener'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.md),
          _TrainerOption(
            label: tr("— Trener yo'q —"),
            selected: currentId == null,
            onTap: () => Navigator.pop(context, const _TrainerChoice(null)),
          ),
          for (final t in staff)
            _TrainerOption(
              label: _label(t),
              selected: t.id == currentId,
              onTap: () => Navigator.pop(context, _TrainerChoice(t.id)),
            ),
        ]),
      ),
    );
    if (picked == null || picked.id == currentId) return;
    await (assign ?? Db.assignTrainer)(user.id, picked.id);
    if (context.mounted) {
      showSnack(
          context, picked.id == null ? tr('Trener olib tashlandi') : tr('Trener biriktirildi'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BentoTile(
      padding: const EdgeInsets.all(AppSpace.md),
      child: StreamBuilder<List<AppUser>>(
        // faqat trenerlar — bosh admin trener sifatida ko'rsatilmaydi
        stream: (trainersSource ?? Db.trainers)(),
        builder: (context, snap) {
          if (snap.hasError) return ErrorState(error: snap.error, compact: true);
          final staff = [...(snap.data ?? <AppUser>[])]..sort((a, b) => a.name.compareTo(b.name));
          // biriktirilgan trener ro'yxatdan chiqib ketgan bo'lsa, dropdown buzilmasin
          final currentId = staff.any((t) => t.id == user.trainerId) ? user.trainerId : null;
          final current = staff.where((t) => t.id == currentId).firstOrNull;
          return InkWell(
            key: const Key('trainer-picker'),
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => _open(context, staff, currentId),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kTouchTarget),
              child: Row(children: [
                Icon(Icons.badge_outlined, color: AppColors.textMuted),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tr('Biriktirilgan trener'),
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      Text(
                        current == null ? tr("— Trener yo'q —") : _label(current),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.expand_more, color: AppColors.textMuted),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _TrainerChoice {
  final String? id;
  const _TrainerChoice(this.id);
}

class _TrainerOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TrainerOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        minTileHeight: kTouchTarget,
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: selected ? Icon(Icons.check, color: AppColors.accent) : null,
        selected: selected,
        onTap: onTap,
      );
}

/// Trenerning katalogdagi o'z yozuvi — shogirdlar anketada shuni ko'rib trener tanlaydi.
/// Trener o'zi boshqaradi: ism, qisqa ma'lumot, yangi shogird qabul qilish.
class _MyCatalogCard extends StatelessWidget {
  final AppUser trainer;
  const _MyCatalogCard({required this.trainer});

  String get _defaultName => trainer.name.isEmpty ? fmtPhone(trainer.phone) : trainer.name;

  Future<void> _edit(BuildContext context, TrainerInfo current) async {
    final name = TextEditingController(text: current.name);
    final bio = TextEditingController(text: current.bio);
    final ok = await showSheet<bool>(
      context,
      Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Katalogdagi profilim'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpace.xs),
            Text(
              tr("Shogirdlar ro'yxatdan o'tayotganda shu ma'lumotni ko'rib trener tanlaydi."),
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: name,
              maxLength: 60,
              decoration: InputDecoration(labelText: tr("Ism (shogirdlarga ko'rinadi)")),
            ),
            const SizedBox(height: AppSpace.sm),
            TextField(
              controller: bio,
              maxLength: 300,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: tr("Qisqa ma'lumot"),
                hintText: tr("Masalan: 5 yil tajriba, ozish va massa nabor"),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Saqlash'))),
          ]),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    await Db.saveTrainerProfile(TrainerInfo(
      trainer.id,
      name.text.trim(),
      bio: bio.text.trim(),
      accepting: current.accepting,
    ));
    if (context.mounted) showSnack(context, tr('Profil saqlandi'));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamBuilder<TrainerInfo?>(
      stream: Db.trainerProfile(trainer.id),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error, compact: true);
        if (snap.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        final p = snap.data;
        return BentoTile(
          feature: true,
          padding: const EdgeInsets.all(AppSpace.md),
          child: p == null
              ? Row(children: [
                  Expanded(
                    child: Text(
                      tr("Siz katalogda yo'qsiz — shogirdlar sizni tanlay olmaydi."),
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
                    onPressed: () => Db.saveTrainerProfile(TrainerInfo(trainer.id, _defaultName)),
                    child: Text(tr("Qo'shilish")),
                  ),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Eyebrow(tr('Katalogdagi profilim')),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _edit(context, p),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(tr('Tahrirlash')),
                    ),
                  ]),
                  Text(p.name, style: t.titleMedium),
                  if (p.bio.isNotEmpty)
                    Text(p.bio, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: AppSpace.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: p.accepting,
                    title: Text(tr('Yangi shogird qabul qilaman')),
                    subtitle: Text(
                      p.accepting
                          ? tr("Ro'yxatdan o'tayotgan shogirdlar sizni tanlay oladi")
                          : tr("Katalogda ko'rinmaysiz — yangi shogird tanlay olmaydi"),
                      style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                    onChanged: (v) => Db.saveTrainerProfile(
                      TrainerInfo(p.id, p.name, bio: p.bio, accepting: v),
                    ),
                  ),
                ]),
        );
      },
    );
  }
}
