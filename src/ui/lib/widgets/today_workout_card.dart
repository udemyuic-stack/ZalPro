import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../models/gym.dart';
import '../models/models.dart';
import '../services/db.dart';
import '../theme.dart';
import 'ui.dart';

String? todayWorkoutName(AppUser user, DateTime now) {
  if (user.homeWorkoutDate == todayKey()) return null;
  return workoutFor(user.gymDays, now.weekday);
}

class TodayWorkoutCard extends StatelessWidget {
  final String name;
  final VoidCallback onStart;
  const TodayWorkoutCard({super.key, required this.name, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return BentoTile(
      feature: true,
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Eyebrow(tr('Bugungi mashq'), color: AppColors.textFaint),
            const SizedBox(height: AppSpace.xs),
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleLarge),
          ]),
        ),
        const SizedBox(width: AppSpace.md),
        FilledButton(
          onPressed: onStart,
          style: FilledButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
          child: Text(tr('Boshlash')),
        ),
      ]),
    );
  }
}
