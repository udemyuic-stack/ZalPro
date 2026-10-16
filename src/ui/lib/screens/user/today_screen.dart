import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/gym.dart' show weekdayNames;
import '../../models/models.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/extra_food_sheet.dart';
import '../../widgets/food_image.dart';
import '../../widgets/plan_photo.dart';
import '../../widgets/ui.dart';
import '../../widgets/watermark.dart';

/// "Bugun" — bento setka: yirik ink bloki + kichik ko'rsatkich kataklari,
/// so'ng ovqatlar ro'yxati. Har blok ochilishda pastdan suzib chiqadi.
class TodayScreen extends StatelessWidget {
  final AppUser user;
  const TodayScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final day = todayKey();
    Widget page(List<Widget> children) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xxl),
          children: [_Header(user: user), ...children],
        );

    return Scaffold(
      // Suv belgisi: ekran o'rtasida xira rasm
      body: Watermark(
        child: SafeArea(
          child: user.planId == null
              ? page(const [SizedBox(height: AppSpace.xxl), _NoPlan()])
              : StreamBuilder<Plan?>(
                  stream: Db.plan(user.planId!),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return page([
                        const SizedBox(height: AppSpace.xxl),
                        ErrorState(error: snap.error),
                      ]);
                    }
                    if (snap.connectionState == ConnectionState.waiting) {
                      return page(const [
                        SizedBox(height: 120),
                        Center(child: CircularProgressIndicator()),
                      ]);
                    }
                    final plan = snap.data;
                    if (plan == null) {
                      return page(const [SizedBox(height: AppSpace.xxl), _NoPlan()]);
                    }
                    // Maqsadga mos kelmaydigan reja bloklangan — shogirdga ko'rsatilmaydi
                    if (!user.fitsPlan(plan)) {
                      return page(const [SizedBox(height: AppSpace.xxl), _PlanMismatch()]);
                    }
                    return StreamBuilder<Set<int>>(
                      stream: Db.doneMeals(user.id, day),
                      builder: (context, doneSnap) {
                        if (doneSnap.hasError) {
                          return page([
                            const SizedBox(height: AppSpace.xxl),
                            ErrorState(error: doneSnap.error),
                          ]);
                        }
                        final done = doneSnap.data ?? <int>{};
                        // Haftalik rejada — bugungi kun menyusi
                        final weekday = DateTime.now().weekday;
                        final meals = plan.mealsFor(weekday);
                        final indexes = List.generate(meals.length, (i) => i);
                        final doneCount = indexes.where(done.contains).length;
                        final planEaten = indexes
                            .where(done.contains)
                            .fold<double>(0, (s, i) => s + meals[i].kcal);
                        final next = indexes.firstWhere((i) => !done.contains(i), orElse: () => -1);

                        // Rejadan tashqari yeyilganlar ham kunlik hisobga qo'shiladi
                        return StreamBuilder<List<ExtraFood>>(
                          stream: Db.extras(user.id, day),
                          builder: (context, extraSnap) {
                            if (extraSnap.hasError) {
                              return page([
                                const SizedBox(height: AppSpace.xxl),
                                ErrorState(error: extraSnap.error),
                              ]);
                            }
                            final eaten = planEaten +
                                ExtraFood.totalKcal(extraSnap.data ?? const <ExtraFood>[]);
                            return page([
                              FadeInUp(
                                  child: _HeroPanel(plan: plan, eaten: eaten, weekday: weekday)),
                              const SizedBox(height: AppSpace.md),
                              FadeInUp(
                                index: 1,
                                child: _MetricsGrid(
                                  user: user,
                                  plan: plan,
                                  eaten: eaten,
                                  weekday: weekday,
                                  doneCount: doneCount,
                                  mealCount: meals.length,
                                ),
                              ),
                              const SizedBox(height: AppSpace.md),
                              FadeInUp(index: 2, child: _WaterCard(uid: user.id, day: day)),
                              const SizedBox(height: AppSpace.xl),
                              SectionHeader(
                                tr('Bugungi ovqatlar'),
                                eyebrow: plan.isWeekly
                                    ? trf('Reja · {0}', [tr(weekdayNames[weekday] ?? '')])
                                    : tr('Reja'),
                                trailing: Pill(
                                  text: '$doneCount / ${meals.length}',
                                  color: doneCount == meals.length && meals.isNotEmpty
                                      ? AppColors.success
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  icon: Icons.check_rounded,
                                ),
                              ),
                              // Trener bergan ratsion rasmi — shu kunniki
                              if (plan.photoFor(weekday) case final photo?
                                  when photo.isNotEmpty) ...[
                                FadeInUp(
                                  index: 3,
                                  child: PlanPhoto(
                                    path: photo,
                                    caption: trf(
                                        'Trener bergan ratsion · {0}'
                                        ' — kattalashtirish uchun bosing',
                                        [tr(weekdayNames[weekday] ?? '')]),
                                  ),
                                ),
                                const SizedBox(height: AppSpace.md),
                              ],
                              if (meals.isNotEmpty && next == -1) ...[
                                const _AllDoneBanner(),
                                const SizedBox(height: AppSpace.md),
                              ],
                              for (final i in indexes)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                                  child: FadeInUp(
                                    index: 3 + i,
                                    child: _MealCard(
                                      meal: meals[i],
                                      done: done.contains(i),
                                      isNext: i == next,
                                      onToggle: (v) => Db.toggleMeal(user.id, day, i, v),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: AppSpace.md),
                              ExtrasToday(uid: user.id, day: day),
                              if (plan.forbidden.isNotEmpty) ...[
                                const SizedBox(height: AppSpace.md),
                                _ForbiddenCard(items: plan.forbidden),
                              ],
                              if (plan.note.isNotEmpty) ...[
                                const SizedBox(height: AppSpace.md),
                                _NoteCard(note: plan.note),
                              ],
                            ]);
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppUser user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final first = user.name.trim().split(' ').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, AppSpace.md, 2, AppSpace.xl),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Eyebrow(uzDate(DateTime.now())),
            const SizedBox(height: AppSpace.sm),
            Text(
              first.isEmpty ? tr('Salom') : trf('Salom, {0}', [first]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.headlineLarge,
            ),
          ]),
        ),
        const SizedBox(width: AppSpace.md),
        UserAvatar(name: user.name, size: 46),
      ]),
    );
  }
}

/// Biriktirilgan reja shogird maqsadiga mos emas — bloklangan
class _PlanMismatch extends StatelessWidget {
  const _PlanMismatch();

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.sync_problem_outlined,
        title: tr('Reja yangilanmoqda'),
        subtitle: tr("Biriktirilgan reja maqsadingizga mos emas. Trener sizga mos rejani "
            "biriktiradi. Savollaringizni 'Trener' bo'limida yozing."),
      );
}

class _NoPlan extends StatelessWidget {
  const _NoPlan();

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.restaurant_menu,
        title: tr('Reja hali biriktirilmagan'),
        subtitle: tr("Trener tez orada sizga shaxsiy ovqatlanish rejasini tuzadi. "
            "Savollaringizni 'Trener' bo'limida yozing."),
      );
}

/// Bosh blok: to'q ink yuza, laym halqa — kunning asosiy ko'rsatkichi
class _HeroPanel extends StatelessWidget {
  final Plan plan;
  final double eaten;
  final int weekday;
  const _HeroPanel({required this.plan, required this.eaten, required this.weekday});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final total = plan.kcalFor(weekday);
    final left = (total - eaten).clamp(0.0, total);
    // rejadan tashqari ovqat bilan me'yordan oshgan bo'lsa — qancha ortiqcha
    final over = eaten > total && total > 0 ? eaten - total : 0.0;
    final pct = total > 0 ? (eaten / total * 100).round() : 0;

    return BentoTile(
      feature: true,
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        KcalRing(
          value: eaten,
          total: total,
          size: 112,
          color: AppColors.accent,
          trackColor: AppColors.cardHigh,
          textColor: AppColors.text,
        ),
        const SizedBox(width: AppSpace.xl),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Eyebrow(tr('Bugungi reja'), color: AppColors.textFaint),
            const SizedBox(height: AppSpace.xs),
            Text(
              tr(plan.title),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.titleMedium?.copyWith(color: AppColors.text),
            ),
            const SizedBox(height: AppSpace.lg),
            Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  CountUp(
                    over > 0 ? over : left,
                    style: t.displaySmall
                        ?.copyWith(color: over > 0 ? AppColors.danger : AppColors.accent),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(over > 0 ? tr('kkal ortiqcha') : tr('kkal qoldi'),
                        style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                  ),
                ]),
            const SizedBox(height: AppSpace.md),
            _ProgressBar(value: total > 0 ? (eaten / total).clamp(0.0, 1.0) : 0),
            const SizedBox(height: AppSpace.sm),
            Text(trf('{0}% bajarildi', [pct]),
                style: t.labelSmall?.copyWith(
                  color: AppColors.textFaint,
                  letterSpacing: 0.4,
                )),
          ]),
        ),
      ]),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: 6,
            color: AppColors.accent,
            backgroundColor: AppColors.cardHigh,
          ),
        ),
      );
}

/// Bento setka: uchta kichik ko'rsatkich katagi
class _MetricsGrid extends StatelessWidget {
  final AppUser user;
  final Plan plan;
  final double eaten;
  final int weekday;
  final int doneCount, mealCount;
  const _MetricsGrid({
    required this.user,
    required this.plan,
    required this.eaten,
    required this.weekday,
    required this.doneCount,
    required this.mealCount,
  });

  @override
  Widget build(BuildContext context) {
    final diff = plan.kcalFor(weekday) - user.targetKcal;
    final onTarget = user.targetKcal == 0 || diff.abs() <= 300;
    return Row(children: [
      Expanded(
        child: StatTile(
          icon: Icons.egg_alt_outlined,
          label: tr('Oqsil'),
          value: trf('{0} g', [plan.proteinFor(weekday).round()]),
          color: AppColors.protein,
        ),
      ),
      const SizedBox(width: AppSpace.md),
      Expanded(
        child: StatTile(
          icon: onTarget ? Icons.flag_outlined : Icons.warning_amber_rounded,
          label: tr('Norma'),
          value: user.targetKcal == 0 ? '—' : '${user.targetKcal}',
          color: onTarget ? AppColors.success : AppColors.warning,
        ),
      ),
      const SizedBox(width: AppSpace.md),
      Expanded(
        child: StatTile(
          icon: Icons.restaurant_outlined,
          label: tr('Ovqat'),
          value: '$doneCount/$mealCount',
          color: AppColors.accent,
        ),
      ),
    ]);
  }
}

class _WaterCard extends StatelessWidget {
  final String uid, day;
  const _WaterCard({required this.uid, required this.day});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return StreamBuilder<int>(
      stream: Db.water(uid, day),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error, compact: true);
        final g = snap.data ?? 0;
        return BentoTile(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.sm),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.water_drop_outlined, size: 17, color: AppColors.water),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Eyebrow(tr('Suv · 1 stakan = 250 ml'), color: s.onSurfaceVariant),
              ),
              if (g >= 8)
                Pill(text: tr('Bajarildi'), color: AppColors.success, icon: Icons.check_rounded),
            ]),
            const SizedBox(height: AppSpace.sm),
            // Birlik aniq ko'rinsin: nechta stakan va necha ml
            Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$g',
                    style: t.headlineSmall?.copyWith(
                      color: g > 0 ? AppColors.water : s.onSurfaceVariant,
                      fontFeatures: tabular,
                    ),
                  ),
                  const SizedBox(width: AppSpace.xs),
                  Text(
                    tr('stakan / 8'),
                    style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Text(
                    trf('{0} ml / 2000 ml', [g * 250]),
                    style: t.bodySmall?.copyWith(
                      color: s.onSurfaceVariant,
                      fontFeatures: tabular,
                    ),
                  ),
                ]),
            const SizedBox(height: AppSpace.xs),
            Row(
              children: List.generate(8, (i) {
                final full = i < g;
                return Expanded(
                  child: Semantics(
                    button: true,
                    label: trf('{0} stakan', [i + 1]),
                    child: InkResponse(
                      radius: 26,
                      // oxirgi to'la stakanni bossangiz — bittaga kamayadi
                      onTap: () => Db.setWater(uid, day, i + 1 == g ? i : i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                          child: Icon(
                            full ? Icons.water_drop : Icons.water_drop_outlined,
                            key: ValueKey(full),
                            size: 28,
                            color: full ? AppColors.water : s.outlineVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ]),
        );
      },
    );
  }
}

class _MealCard extends StatelessWidget {
  final Meal meal;
  final bool done;
  final bool isNext;
  final ValueChanged<bool> onToggle;
  const _MealCard({
    required this.meal,
    required this.done,
    required this.isNext,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final cardColor = Theme.of(context).cardTheme.color ?? s.surface;
    return Card(
      color: isNext ? Color.alphaBlend(s.primary.withValues(alpha: 0.04), cardColor) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isNext ? s.primary : s.outlineVariant,
          width: isNext ? 1.5 : 1,
        ),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.lg, AppSpace.sm),
        childrenPadding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.lg),
        leading: _CheckCircle(done: done, onTap: () => onToggle(!done)),
        // Vaqt — editorial urg'u: yirik, zich, tabular
        title: Row(children: [
          Text(
            meal.time,
            style: t.titleMedium?.copyWith(
              color: done ? s.onSurfaceVariant : s.onSurface,
              fontFeatures: tabular,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Flexible(
            child: Text(
              tr(meal.title),
              overflow: TextOverflow.ellipsis,
              style: t.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
                decoration: done ? TextDecoration.lineThrough : null,
                color: s.onSurfaceVariant,
              ),
            ),
          ),
          if (isNext) ...[
            const SizedBox(width: AppSpace.sm),
            Pill(text: tr('Navbatdagi'), color: s.primary),
          ],
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.xs),
            child: Text(
              trf('{0} kkal  ·  {1} g oqsil', [meal.kcal.round(), meal.protein.round()]),
              style: t.bodySmall?.copyWith(
                color: s.onSurfaceVariant,
                fontFeatures: tabular,
              ),
            ),
          ),
          if (meal.items.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            // yopiq kartochkada ham nima yeyilishi rasmlardan ko'rinib tursin
            Row(children: [
              for (final i in meal.items.take(5))
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Opacity(
                    opacity: done ? 0.45 : 1,
                    child: FoodImage(name: i.name, url: i.image, size: 32),
                  ),
                ),
            ]),
          ],
        ]),
        children: [
          for (final i in meal.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                FoodImage(name: i.name, url: i.image, size: 44),
                const SizedBox(width: AppSpace.md),
                Expanded(child: Text(tr(i.name), style: t.bodyMedium)),
                const SizedBox(width: AppSpace.sm),
                Text(
                  trf('{0} g', [i.grams.round()]),
                  style: t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: tabular,
                  ),
                ),
                SizedBox(
                  width: 66,
                  child: Text(
                    trf('{0} kkal', [i.kcal.round()]),
                    textAlign: TextAlign.right,
                    style: t.bodySmall?.copyWith(
                      color: s.onSurfaceVariant,
                      fontFeatures: tabular,
                    ),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

class _CheckCircle extends StatelessWidget {
  final bool done;
  final VoidCallback onTap;
  const _CheckCircle({required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Tooltip(
      message: done ? tr('Belgini olib tashlash') : tr('Yedim'),
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(done ? 14 : 9),
                color: done ? AppColors.success : Colors.transparent,
                border: Border.all(color: done ? AppColors.success : s.outline, width: 2),
              ),
              child: done ? Icon(Icons.check_rounded, size: 18, color: AppColors.onAccent) : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _AllDoneBanner extends StatelessWidget {
  const _AllDoneBanner();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return BentoTile(
      feature: true,
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(Icons.check_rounded, color: AppColors.onAccent, size: 24),
        ),
        const SizedBox(width: AppSpace.lg),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Barakalla!'), style: t.titleMedium?.copyWith(color: AppColors.text)),
            const SizedBox(height: 2),
            Text(
              tr("Bugungi rejani to'liq bajardingiz."),
              style: t.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ForbiddenCard extends StatelessWidget {
  final List<String> items;
  const _ForbiddenCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return BentoTile(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.block, color: s.error, size: 17),
          const SizedBox(width: AppSpace.sm),
          Eyebrow(tr('Vaqtincha mumkin emas'), color: s.error),
        ]),
        const SizedBox(height: AppSpace.md),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final f in items)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 7),
                decoration: BoxDecoration(
                  color: s.error.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  tr(f),
                  style: t.bodySmall?.copyWith(color: s.error, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ]),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return BentoTile(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.tips_and_updates_outlined, size: 17, color: AppColors.warning),
          const SizedBox(width: AppSpace.sm),
          Eyebrow(tr('Trener maslahati'), color: s.onSurfaceVariant),
        ]),
        const SizedBox(height: AppSpace.md),
        // tayyor shablon matni bo'lsa tarjima qilinadi; trener o'zi yozgan bo'lsa — o'zicha
        Text(tr(note), style: t.bodyMedium?.copyWith(height: 1.5)),
      ]),
    );
  }
}
