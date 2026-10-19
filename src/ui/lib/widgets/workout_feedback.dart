import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../services/api/day_api.dart';
import '../services/db.dart';
import '../theme.dart';
import 'ui.dart';

const feedbackValues = [1, 2, 3];

String feedbackLabel(int value) => switch (value) {
      1 => tr('Oson'),
      2 => tr("To'g'ri"),
      _ => tr('Qiyin'),
    };

Color feedbackColor(int value) => switch (value) {
      1 => AppColors.success,
      2 => AppColors.water,
      _ => AppColors.warning,
    };

IconData feedbackIcon(int value) => switch (value) {
      1 => Icons.sentiment_very_satisfied_outlined,
      2 => Icons.sentiment_satisfied_outlined,
      _ => Icons.local_fire_department_outlined,
    };

class WorkoutFeedbackPicker extends StatelessWidget {
  final int? selected;
  final ValueChanged<int> onSelect;
  const WorkoutFeedbackPicker({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        tr("Mashg'ulot qanday bo'ldi?"),
        style: const TextStyle(fontSize: 17, color: Color(0xFFBDBDBD), fontWeight: FontWeight.w300),
      ),
      const SizedBox(height: AppSpace.md),
      Row(children: [
        for (final v in feedbackValues) ...[
          if (v != feedbackValues.first) const SizedBox(width: AppSpace.sm),
          Expanded(child: _Choice(value: v, selected: selected == v, onTap: () => onSelect(v))),
        ],
      ]),
    ]);
  }
}

class _Choice extends StatelessWidget {
  final int value;
  final bool selected;
  final VoidCallback onTap;
  const _Choice({required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = feedbackColor(value);
    return Semantics(
      button: true,
      selected: selected,
      label: feedbackLabel(value),
      child: GestureDetector(
        key: Key('feedback-$value'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: kTouchTarget + 20),
          padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
            border: Border.all(color: selected ? color : const Color(0x33FFFFFF), width: 1.5),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(feedbackIcon(value), color: selected ? color : const Color(0xFFBDBDBD)),
            const SizedBox(height: 4),
            Text(
              feedbackLabel(value),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? color : const Color(0xFFBDBDBD),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

List<DateTime> feedbackWindow(DateTime today) => [
      for (var i = DayApi.feedbackDays - 1; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];

String feedbackKey(DateTime d) => todayKey(d);

class WorkoutFeedbackStrip extends StatelessWidget {
  final String uid;
  final Stream<Map<String, int>>? source;
  final DateTime? today;
  const WorkoutFeedbackStrip({super.key, required this.uid, this.source, this.today});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final days = feedbackWindow(today ?? DateTime.now());
    return StreamBuilder<Map<String, int>>(
      stream: source ?? Db.workoutFeedbackWeek(uid),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error, compact: true);
        final byDay = snap.data ?? const <String, int>{};
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr("Mashg'ulot fikri · oxirgi 7 kun"), style: t.titleMedium),
          const SizedBox(height: AppSpace.sm),
          Row(children: [
            for (final d in days) Expanded(child: _Cell(day: d, value: byDay[feedbackKey(d)], isToday: d == days.last)),
          ]),
          const SizedBox(height: AppSpace.sm),
          Wrap(spacing: AppSpace.md, children: [
            for (final v in feedbackValues)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 10, color: feedbackColor(v)),
                const SizedBox(width: 4),
                Text(
                  feedbackLabel(v),
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ]),
          ]),
        ]);
      },
    );
  }
}

class _Cell extends StatelessWidget {
  final DateTime day;
  final int? value;
  final bool isToday;
  const _Cell({required this.day, required this.value, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color =
        value == null ? AppColors.textMuted.withValues(alpha: 0.25) : feedbackColor(value!);
    return Semantics(
      label: '${day.day}: ${value == null ? '—' : feedbackLabel(value!)}',
      child: ConstrainedBox(
        key: Key('feedback-hit-${feedbackKey(day)}'),
        constraints: const BoxConstraints(minHeight: kTouchTarget),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${day.day}', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Container(
            key: Key('feedback-cell-${feedbackKey(day)}'),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isToday ? Border.all(color: AppColors.text, width: 2) : null,
            ),
            child: value == null
                ? null
                : Icon(feedbackIcon(value!), size: 18, color: AppColors.onAccent),
          ),
        ]),
      ),
    );
  }
}
