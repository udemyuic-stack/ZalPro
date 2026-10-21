import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/tr.dart';
import '../../models/gym.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../theme.dart';
import 'leaderboard_screen.dart';
import 'muscles_screen.dart';
import 'rep_counter_screen.dart';
import '../../models/rep_counter.dart';
import '../../widgets/ui.dart';
import '../../widgets/workout_feedback.dart';
import '../../services/api/api_error.dart';

/// Shogird: Zal bo'limi — 3 ta mashg'ulot kunini tanlaydi, bugungi mashg'ulotni ko'radi.
/// Mashqlarni belgilash yo'q (mashqlar ro'yxati hali ishlab chiqilmoqda).
class GymScreen extends StatefulWidget {
  final AppUser user;
  final ValueListenable<int>? openSignal;
  final ValueListenable<int>? resetSignal;
  const GymScreen({super.key, required this.user, this.openSignal, this.resetSignal});

  @override
  State<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> {
  AppUser get user => widget.user;

  /// "Tana xaritasi" ochiqmi. Alohida sahifa qilib ochilmaydi — shu tab ichida ko'rsatiladi,
  /// shunda pastki menyu yo'qolib qolmaydi.
  bool _muscles = false;

  /// Trener qo'shgan mashqlar — bir marta ochiladi (har qurilishda qayta ulanmasin)
  late final _custom = Db.customExercises();

  /// Bugungi mashg'ulot holati (boshlangan, bajarilgan mashqlar)
  late final _progress = Db.workout(user.id, todayKey());

  late final _history = Db.workoutDoneWeek(user.id);

  late final _gyms = Db.gyms();

  @override
  void initState() {
    super.initState();
    widget.openSignal?.addListener(_open);
    widget.resetSignal?.addListener(_reset);
  }

  @override
  void dispose() {
    widget.openSignal?.removeListener(_open);
    widget.resetSignal?.removeListener(_reset);
    super.dispose();
  }

  void _open() => setState(() => _muscles = true);

  void _reset() {
    if (_muscles) setState(() => _muscles = false);
  }

  Future<void> _chooseDays(BuildContext context) async {
    final days = await showSheet<List<int>>(context, _DaysPicker(initial: user.gymDays));
    if (days == null) return;
    try {
      await Db.setGymDays(user.id, days);
      if (context.mounted) showSnack(context, tr('Zal kunlari saqlandi'));
    } catch (e) {
      if (context.mounted) showSnack(context, trf("Saqlab bo'lmadi: {0}", [apiErrorText(e)]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final today = DateTime.now().weekday;
    final days = user.gymDays;
    final hasDays = validGymDays(days);
    final isHome = user.homeWorkoutDate == todayKey();
    final todayWorkout = workoutFor(days, today);
    final next = nextWorkout(days, today);

    if (_muscles) {
      return MusclesScreen(
        gymDays: days,
        homeToday: isHome,
        custom: _custom,
        program: user.program,
        progress: _progress,
        history: _history,
        setsUserId: user.id,
        onStart: () => Db.startWorkout(user.id, todayKey()),
        onDone: (key, done) => Db.toggleExercise(user.id, todayKey(), key, done),
        onFeedback: (rating) => Db.setWorkoutFeedback(user.id, todayKey(), rating),
        onBack: () => setState(() => _muscles = false),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(tr('Zal'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xxl),
        children: [
          _GymLocationTile(stream: _gyms, gymId: user.gymId),
          if (!hasDays)
            BentoTile(
              feature: true,
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(tr('Haftasiga 3 kun mashg\'ulot'), style: t.titleLarge),
                const SizedBox(height: AppSpace.sm),
                Text(
                  tr("O'zingizga qulay variantni tanlang: Seshanba, Payshanba, Shanba yoki "
                      "Dushanba, Chorshanba, Juma."),
                  style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpace.lg),
                FilledButton.icon(
                  onPressed: () => _chooseDays(context),
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text(tr('Kunlarni tanlash')),
                ),
              ]),
            )
          else ...[
            // Bugun
            BentoTile(
              feature: true,
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Eyebrow(trf('Bugun · {0}', [tr(weekdayNames[today] ?? '')])),
                const SizedBox(height: AppSpace.sm),
                if (isHome) ...[
                  Row(children: [
                    Icon(Icons.home_outlined, color: AppColors.accent),
                    const SizedBox(width: AppSpace.sm),
                    Text(tr('Uyda mashq'), style: t.headlineSmall),
                  ]),
                  const SizedBox(height: AppSpace.xs),
                  Text(tr("Trener bugun uyda mashq qilishingizni belgiladi."),
                      style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                ] else if (todayWorkout != null) ...[
                  Text(todayWorkout, style: t.headlineSmall),
                  const SizedBox(height: AppSpace.xs),
                  Text(tr('Bugun zalga borish kuni'),
                      style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                ] else ...[
                  Text(tr('Dam olish kuni'), style: t.headlineSmall),
                  if (next != null) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(trf('Keyingi: {0} — {1}', [tr(weekdayNames[next.$1] ?? ''), tr(next.$2)]),
                        style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                  ],
                ],
              ]),
            ),
            const SizedBox(height: AppSpace.xl),
            SectionHeader(
              tr('Mening jadvalim'),
              eyebrow: tr('Haftasiga 3 kun'),
              trailing: TextButton.icon(
                onPressed: () => _chooseDays(context),
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: Text(tr("O'zgartirish")),
              ),
            ),
            if (isEveryDay(days))
              BentoTile(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Row(children: [
                  Expanded(child: Text(tr(everyDayLabel), style: t.titleMedium)),
                ]),
              )
            else
              for (final d in ([...days]..sort()))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: BentoTile(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Row(children: [
                      SizedBox(
                        width: 96,
                        child: Text(tr(weekdayNames[d]!),
                            style: t.titleMedium
                                ?.copyWith(color: d == today ? AppColors.accent : null)),
                      ),
                      Expanded(child: Text(workoutFor(days, d)!, style: t.bodyMedium)),
                    ]),
                  ),
                ),
          ],
          const SizedBox(height: AppSpace.xl),
          WorkoutFeedbackStrip(uid: user.id),
          const SizedBox(height: AppSpace.xl),
          SectionHeader(tr('Mashqlar')),
          BentoTile(
            onTap: () => setState(() => _muscles = true),
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Row(children: [
              Icon(Icons.accessibility_new, color: AppColors.accent),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('Tana xaritasi'), style: t.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    tr("Bugungi mashqlar — haftalik reja bo'yicha"),
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ]),
              ),
              Icon(Icons.chevron_right, color: AppColors.textMuted),
            ]),
          ),
          const SizedBox(height: AppSpace.md),
          BentoTile(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => LeaderboardScreen(user: user))),
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Row(children: [
              Icon(Icons.emoji_events_outlined, color: AppColors.accent),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('Zal reytingi'), style: t.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    trf('Oxirgi {0} kun', [30]),
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ]),
              ),
              Icon(Icons.chevron_right, color: AppColors.textMuted),
            ]),
          ),
          if (repCounterSupported(isWeb: kIsWeb, platform: defaultTargetPlatform)) ...[
            const SizedBox(height: AppSpace.md),
            BentoTile(
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => const RepCounterScreen())),
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Row(children: [
                Icon(Icons.videocam_outlined, color: AppColors.accent),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Takror sanagich (sinov)'), style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      tr('Squat takrorlarini kamera sanaydi'),
                      style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                  ]),
                ),
                Icon(Icons.chevron_right, color: AppColors.textMuted),
              ]),
            ),
          ],
          if (user.trainerId != null) ...[
            const SizedBox(height: AppSpace.md),
            Text(
              tr("Bugun zalga kela olmasangiz — 'Trener' bo'limida \"bugun kelolmayman\" deb yozing, "
                  "trener uyda mashq belgilaydi."),
              style: t.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// 3 kun tanlash: toq kunlar / juft kunlar / o'zim tanlayman
class _DaysPicker extends StatefulWidget {
  final List<int> initial;
  const _DaysPicker({required this.initial});

  @override
  State<_DaysPicker> createState() => _DaysPickerState();
}

class _DaysPickerState extends State<_DaysPicker> {
  late final Set<int> _sel = {...widget.initial};

  bool _same(List<int> preset) => _sel.length == preset.length && preset.every(_sel.contains);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget preset(String title, List<int> days) => Card(
          child: ListTile(
            leading: Icon(
              _same(days) ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: _same(days) ? AppColors.accent : AppColors.textMuted,
            ),
            title: Text(title),
            subtitle: Text(days.map((d) => tr(weekdayNames[d] ?? '')).join(', ')),
            onTap: () => setState(() => _sel
              ..clear()
              ..addAll(days)),
          ),
        );

    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Zal kunlari'), style: t.titleLarge),
          const SizedBox(height: AppSpace.xs),
          Text(
              trf(
                  "Haftasiga 3 kun yoki har kun. 3 kunda mashg'ulotlar tartibida: 1) {0}, "
                  "2) {1}, 3) {2}. Har kunlik variantda har kuni hamma guruh ishlaydi.",
                  [tr(workoutGroups[0]), tr(workoutGroups[1]), tr(workoutGroups[2])]),
              style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpace.md),
          preset('1-variant', evenDays),
          preset('2-variant', oddDays),
          preset(tr('Har kunlik'), everyDays),
          const SizedBox(height: AppSpace.lg),
          FilledButton(
            onPressed: _same(evenDays) || _same(oddDays) || _same(everyDays)
                ? () => Navigator.pop(context, _sel.toList())
                : null,
            child: Text(tr('Saqlash')),
          ),
          const SizedBox(height: AppSpace.sm),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Bekor')),
          ),
        ]);
  }
}

class _GymLocationTile extends StatelessWidget {
  final Stream<List<Gym>> stream;
  final String? gymId;
  const _GymLocationTile({required this.stream, required this.gymId});

  Future<void> _open(BuildContext context, String url) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && context.mounted) showSnack(context, tr("Havolani ochib bo'lmadi"));
  }

  @override
  Widget build(BuildContext context) {
    if (gymId == null || gymId!.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<List<Gym>>(
      stream: stream,
      builder: (context, snap) {
        final matches = (snap.data ?? const <Gym>[]).where((g) => g.id == gymId);
        if (matches.isEmpty) return const SizedBox.shrink();
        final gym = matches.first;
        final t = Theme.of(context).textTheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          child: BentoTile(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Row(children: [
              Icon(Icons.location_on_outlined, color: AppColors.textMuted),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(gym.name,
                      style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (gym.fullAddress.isNotEmpty)
                    Text(
                      gym.fullAddress,
                      style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ]),
              ),
              if (gym.mapUrl.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _open(context, gym.mapUrl),
                  icon: const Icon(Icons.directions_outlined, size: 18),
                  label: Text(tr("Yo'nalish")),
                ),
            ]),
          ),
        );
      },
    );
  }
}
