import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/exercises.dart';
import '../../models/gym.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/workout_feedback.dart';
import '../../widgets/ui.dart';
import '../../services/api/api_error.dart';

/// Trener: shogird kartasidagi "Mashqlar" tabi — har mushak uchun shu shogird qiladigan
/// mashqlarni kutubxonadan tanlaydi (kimga ko'p, kimga kam). Trener o'zgartirmaguncha
/// tanlov turadi; shogird faqat tanlanganini ko'radi (`exercisesForStudent`).
class StudentProgramTab extends StatefulWidget {
  final AppUser student;
  const StudentProgramTab({super.key, required this.student});

  @override
  State<StudentProgramTab> createState() => _StudentProgramTabState();
}

class _StudentProgramTabState extends State<StudentProgramTab> {
  late final _custom = Db.customExercises();

  /// Shogirdning mashg'ulot kunlari bo'yicha mushaklar; kunlar tanlanmagan bo'lsa — hammasi
  List<(String, List<String>)> _groups(AppUser u) {
    if (!validGymDays(u.gymDays)) {
      return [
        (tr('Hamma mushaklar'), [for (final m in muscles) m.id])
      ];
    }
    final days = [...u.gymDays]..sort();
    return [
      for (var i = 0; i < days.length; i++)
        ('${tr(weekdayNames[days[i]] ?? '')} · ${tr(workoutGroups[i])}', workoutMuscles[i]),
    ];
  }

  Future<void> _pick(String muscle, List<Exercise> all, List<String> current) async {
    final chosen = await showSheet<List<String>>(
      context,
      _PickSheet(muscle: muscle, all: all, initial: current),
    );
    if (chosen == null || !mounted) return;
    try {
      await Db.setProgram(widget.student.id, muscle, chosen);
      if (mounted) showSnack(context, tr('Mashqlar saqlandi'));
    } catch (e) {
      if (mounted) showSnack(context, trf("Saqlab bo'lmadi: {0}", [apiErrorText(e)]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final u = widget.student;
    return StreamBuilder<List<Exercise>>(
      stream: _custom,
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        final custom = snap.data ?? const <Exercise>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              tr("Har mushak uchun shu shogird qiladigan mashqlarni tanlang. O'zgartirmaguningizcha "
                  'tanlov turadi. Tanlanmagan mushakda — "Boshlovchi" mashqlar.'),
              style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpace.lg),
            WorkoutFeedbackStrip(uid: u.id),
            for (final (title, ids) in _groups(u)) ...[
              const SizedBox(height: AppSpace.lg),
              Text(title, style: t.titleMedium),
              const SizedBox(height: AppSpace.sm),
              for (final id in ids)
                if (muscleById(id) case final m?)
                  _MuscleRow(
                    name: tr(m.name),
                    chosen: u.program[id] ?? const [],
                    shown: exercisesForStudent(id, custom, u.program),
                    onPick: () => _pick(id, exercisesFor(id, custom), u.program[id] ?? const []),
                  ),
            ],
          ],
        );
      },
    );
  }
}

class _MuscleRow extends StatelessWidget {
  final String name;
  final List<String> chosen;

  /// Shogird hozir ko'radigan mashqlar
  final List<Exercise> shown;
  final VoidCallback onPick;
  const _MuscleRow(
      {required this.name, required this.chosen, required this.shown, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: BentoTile(
        onTap: onPick,
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(name, style: t.titleSmall)),
                const SizedBox(width: AppSpace.sm),
                chosen.isEmpty
                    ? Pill(text: tr('Standart'), color: AppColors.textMuted)
                    : Pill(text: trf('{0} ta tanlangan', [chosen.length]), color: AppColors.accent),
              ]),
              const SizedBox(height: 4),
              Text(
                shown.isEmpty ? tr("Mashq yo'q") : shown.map((e) => tr(e.name)).join(' · '),
                style: t.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ]),
          ),
          Icon(Icons.edit_outlined, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}

/// Bitta mushak uchun mashq tanlash varag'i: daraja bo'yicha saralash, video belgisi
class _PickSheet extends StatefulWidget {
  final String muscle;
  final List<Exercise> all;
  final List<String> initial;
  const _PickSheet({required this.muscle, required this.all, required this.initial});

  @override
  State<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends State<_PickSheet> {
  /// Tanlangan mashqlar kaliti (`Exercise.key`), tanlash tartibida
  late final List<String> _keys = [
    for (final k in widget.initial)
      if (widget.all.any((e) => e.key == k)) k,
  ];
  String? _level;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final list = _level == null ? widget.all : widget.all.where((e) => e.level == _level).toList();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr(muscleById(widget.muscle)!.name), style: t.titleLarge),
            const SizedBox(height: AppSpace.sm),
            Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.xs, children: [
              for (final (k, label) in <(String?, String)>[
                (null, tr('Hammasi')),
                for (final l in levels.entries) (l.key, tr(l.value)),
              ])
                ChoiceChip(
                    label: Text(label),
                    selected: _level == k,
                    onSelected: (_) => setState(() => _level = k)),
            ]),
            const SizedBox(height: AppSpace.sm),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Text(tr("Bu darajada mashq yo'q."),
                        style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                  ),
                for (final e in list)
                  CheckboxListTile(
                    value: _keys.contains(e.key),
                    onChanged: (v) =>
                        setState(() => v == true ? _keys.add(e.key) : _keys.remove(e.key)),
                    title: Text(tr(e.name)),
                    subtitle: Text(
                      [
                        if (e.sets.isNotEmpty) tr(e.sets),
                        if (levels[e.level] case final l?) tr(l),
                        if (e.videoProcessing)
                          tr('Tayyorlanmoqda')
                        else if (e.hasVideo)
                          tr('Video'),
                      ].join(' · '),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
              ]),
            ),
            const SizedBox(height: AppSpace.sm),
            FilledButton(
              onPressed: () => Navigator.pop(context, List<String>.of(_keys)),
              child: Text(_keys.isEmpty
                  ? tr('Standartga qaytarish')
                  : trf('Saqlash ({0})', [_keys.length])),
            ),
          ]),
    );
  }
}
