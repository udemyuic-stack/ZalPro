import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/gym.dart';
import '../../models/models.dart';
import '../../services/api/api_error.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';
import 'exercises_admin_screen.dart';

/// Trener: Zal bo'limi — shogirdlar kimda qaysi kun, bugun kim keladi, kim uyda.
/// "Uyda mashq" faqat shogird bugun chatda kela olmasligini yozgan bo'lsa belgilanadi.
class GymAdminScreen extends StatefulWidget {
  final AppUser admin;
  const GymAdminScreen({super.key, required this.admin});

  @override
  State<GymAdminScreen> createState() => _GymAdminScreenState();
}

class _GymAdminScreenState extends State<GymAdminScreen> {
  late final _stream = widget.admin.isOwner ? Db.clients() : Db.clientsOf(widget.admin.id);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final today = DateTime.now().weekday;
    final todayKeyStr = todayKey();
    return StreamBuilder<List<AppUser>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final all = [...snap.data!]..sort((a, b) => a.name.compareTo(b.name));
        final home = all.where((u) => u.homeWorkoutDate == todayKeyStr).toList();
        final coming = all
            .where((u) => workoutFor(u.gymDays, today) != null && u.homeWorkoutDate != todayKeyStr)
            .toList();
        final noDays = all.where((u) => !validGymDays(u.gymDays)).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xxl),
          children: [
            // Mashqlar ro'yxati: trener tana chizmasidan mushak tanlab, yangi mashq qo'shadi
            BentoTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ExercisesAdminScreen(admin: widget.admin)),
              ),
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Row(children: [
                Icon(Icons.accessibility_new, color: AppColors.accent),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Mashqlar'), style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      tr("Tana chizmasidan mushak tanlab, yangi mashq qo'shing"),
                      style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                  ]),
                ),
                Icon(Icons.chevron_right, color: AppColors.textMuted),
              ]),
            ),
            const SizedBox(height: AppSpace.xl),
            Text(trf('Bugun · {0}', [tr(weekdayNames[today] ?? '')]), style: t.titleLarge),
            const SizedBox(height: AppSpace.md),
            SectionHeader(tr('Bugun zalga keladi'),
                trailing: Pill(text: '${coming.length}', color: AppColors.accent)),
            if (coming.isEmpty) _empty(context, tr("Bugun hech kimning mashg'uloti yo'q")),
            for (final u in coming)
              _ClientGymTile(client: u, today: today, adminId: widget.admin.id),
            const SizedBox(height: AppSpace.lg),
            SectionHeader(tr('Bugun uyda'),
                trailing: Pill(text: '${home.length}', color: AppColors.water)),
            if (home.isEmpty) _empty(context, tr("Hech kim uyda mashq qilmaydi")),
            for (final u in home) _ClientGymTile(client: u, today: today, adminId: widget.admin.id),
            const SizedBox(height: AppSpace.lg),
            if (all.length > noDays.length) SectionHeader(tr('Hamma shogirdlar jadvali')),
            for (final u in all.where((u) => validGymDays(u.gymDays)))
              _ClientGymTile(client: u, today: today, adminId: widget.admin.id, showWeek: true),
            if (noDays.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm),
                child: Text(
                  trf("{0} ta shogird hali zal kunlarini tanlamagan.", [noDays.length]),
                  style: t.bodySmall?.copyWith(color: AppColors.warning),
                ),
              ),
            const SizedBox(height: AppSpace.xl),
            BentoTile(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Row(children: [
                Icon(Icons.construction_outlined, color: AppColors.warning),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    tr("Mashqlar hozir qo'shilmoqda — har bir mashg'ulotning mashqlari ro'yxati "
                        "ishlab chiqilmoqda."),
                    style: t.bodyMedium,
                  ),
                ),
              ]),
            ),
          ],
        );
      },
    );
  }

  Widget _empty(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm, left: 4),
        child: Text(text, style: TextStyle(color: AppColors.textMuted)),
      );
}

class _ClientGymTile extends StatelessWidget {
  final AppUser client;
  final int today;
  final String adminId;
  final bool showWeek;
  const _ClientGymTile({
    required this.client,
    required this.today,
    required this.adminId,
    this.showWeek = false,
  });

  Future<void> _toggleHome(BuildContext context, bool isHome) async {
    try {
      await Db.setHomeWorkout(client.id, isHome ? null : todayKey());
      if (context.mounted) {
        showSnack(
            context, isHome ? tr('Uyda mashq bekor qilindi') : tr('Bugun uyda mashq belgilandi'));
      }
    } catch (e) {
      if (context.mounted) showSnack(context, trf('Amalga oshmadi: {0}', [apiErrorText(e)]));
    }
  }

  Future<void> _toggleAttendance(BuildContext context, bool present) async {
    try {
      await Db.markAttendance(client.id, todayKey(), !present, adminId);
      if (context.mounted) {
        showSnack(
            context, present ? tr('Davomat bekor qilindi') : tr('Bugun keldi deb belgilandi'));
      }
    } catch (e) {
      if (context.mounted) showSnack(context, trf('Amalga oshmadi: {0}', [apiErrorText(e)]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final u = client;
    final name = u.name.isEmpty ? fmtPhone(u.phone) : u.name;
    final days = [...u.gymDays]..sort();
    final isHome = u.homeWorkoutDate == todayKey();
    final todayWorkout = workoutFor(u.gymDays, today);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: BentoTile(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            UserAvatar(name: name, size: 38),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  !validGymDays(days)
                      ? tr('Kunlar tanlanmagan')
                      : isHome
                          ? tr('Bugun uyda mashq')
                          : (todayWorkout == null ? tr('Bugun dam olish') : tr(todayWorkout)),
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ]),
            ),
          ]),
          if (showWeek && validGymDays(days)) ...[
            const SizedBox(height: AppSpace.sm),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (isEveryDay(days))
                Pill(text: tr('Har kunlik'), color: AppColors.accent)
              else
              for (final d in days)
                Pill(
                  text:
                      '${tr(weekdayShort[d] ?? '')} · ${tr(workoutGroups[days.indexOf(d)]).split(' ').first}',
                  color: d == today ? AppColors.accent : AppColors.textMuted,
                ),
            ]),
          ],
          // Uyda mashq — faqat bugun mashg'ulot kuni bo'lsa va shogird chatda
          // bugun kela olmasligini yozgan bo'lsa (yoki allaqachon belgilangan bo'lsa bekor qilish)
          if (!showWeek && (todayWorkout != null || isHome))
            StreamBuilder<List<(String, ChatMessage)>>(
              stream: Db.messageEvents(u.id),
              builder: (context, snap) {
                if (snap.hasError) return ErrorState(error: snap.error, compact: true);
                final now = DateTime.now();
                final wrote = (snap.data ?? []).any((e) {
                  final m = e.$2;
                  return m.senderId == u.id &&
                      m.createdAt.year == now.year &&
                      m.createdAt.month == now.month &&
                      m.createdAt.day == now.day &&
                      saysCantCome(m.text);
                });
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        isHome
                            ? tr('Uyda mashq belgilangan')
                            : wrote
                                ? tr('Chatda bugun kela olmasligini yozdi')
                                : tr(
                                    'Chatda "bugun kelolmayman" deb yozsa, uyda mashq belgilash mumkin'),
                        style: t.bodySmall?.copyWith(
                            color: wrote || isHome ? AppColors.warning : AppColors.textFaint),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: isHome || wrote ? () => _toggleHome(context, isHome) : null,
                      icon: Icon(isHome ? Icons.close : Icons.home_outlined, size: 18),
                      label: Text(isHome ? tr('Bekor') : tr('Uyda mashq')),
                    ),
                  ]),
                );
              },
            ),
          // Davomat — faqat bugun mashg'ulot kuni bo'lsa va uyda mashq qilmayotgan bo'lsa
          if (!showWeek && todayWorkout != null && !isHome)
            StreamBuilder<bool>(
              stream: Db.attendance(u.id, todayKey()),
              builder: (context, attSnap) {
                if (attSnap.hasError) return ErrorState(error: attSnap.error, compact: true);
                final present = attSnap.data ?? false;
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        present
                            ? tr('Bugun keldi deb belgilangan')
                            : tr('Hali kelgani belgilanmagan'),
                        style: t.bodySmall
                            ?.copyWith(color: present ? AppColors.success : AppColors.textFaint),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: () => _toggleAttendance(context, present),
                      icon: Icon(present ? Icons.close : Icons.check, size: 18),
                      label: Text(present ? tr('Bekor') : tr('Keldi')),
                    ),
                  ]),
                );
              },
            ),
        ]),
      ),
    );
  }
}
