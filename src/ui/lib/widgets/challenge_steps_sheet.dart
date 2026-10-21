import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/tr.dart';
import '../models/game.dart';
import '../services/api/api_error.dart';
import '../services/db.dart';
import '../theme.dart';
import 'game_widgets.dart';
import 'hex_badge.dart';
import 'ui.dart';

typedef ChallengeStepSave = Future<void> Function({
  required String exercise,
  required int target,
  required int coins,
  required String muscle,
});

typedef ChallengeStepUpdate = Future<void> Function(
  String id, {
  required String exercise,
  required int target,
  required int coins,
  required String muscle,
});

Future<void> showChallengeStepsManager(BuildContext context) =>
    showSheet<void>(context, const ChallengeStepsManager());

String challengeMuscleName(String key) => switch (key) {
      'arms' => tr("Qo'llar"),
      'chest' => tr("Ko'krak"),
      'legs' => tr('Oyoqlar'),
      _ => key,
    };

class ChallengeStepsManager extends StatefulWidget {
  final Future<List<ChallengeStepAdmin>> Function()? load;
  final Future<List<String>> Function()? exercises;
  final ChallengeStepSave? add;
  final ChallengeStepUpdate? update;
  final Future<void> Function(String id)? remove;

  const ChallengeStepsManager({
    super.key,
    this.load,
    this.exercises,
    this.add,
    this.update,
    this.remove,
  });

  @override
  State<ChallengeStepsManager> createState() => _ChallengeStepsManagerState();
}

class _ChallengeStepsManagerState extends State<ChallengeStepsManager> {
  final _target = TextEditingController();
  final _coins = TextEditingController();
  List<ChallengeStepAdmin>? _steps;
  List<String> _exercises = const [];
  Object? _loadError;
  ChallengeStepAdmin? _editing;
  String? _exercise;
  String _muscle = challengeMuscles.first;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadExercises();
  }

  @override
  void dispose() {
    _target.dispose();
    _coins.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final rows = await (widget.load ?? Db.challengeSteps)();
      if (!mounted) return;
      setState(() {
        _steps = rows;
        _loadError = null;
      });
    } catch (err) {
      if (mounted) setState(() => _loadError = err);
    }
  }

  Future<void> _loadExercises() async {
    try {
      final keys = await (widget.exercises ?? _catalogKeys)();
      if (!mounted) return;
      setState(() {
        _exercises = keys;
        _exercise ??= keys.isEmpty ? null : keys.first;
      });
    } catch (err) {
      if (mounted) showSnack(context, trf('Amalga oshmadi: {0}', [apiErrorText(err)]));
    }
  }

  Future<List<String>> _catalogKeys() async =>
      [for (final rule in (await Db.gameCatalog()).exercises) rule.key];

  int? get _targetValue => int.tryParse(_target.text.trim());
  int? get _coinsValue => int.tryParse(_coins.text.trim());

  bool get _valid {
    final target = _targetValue;
    final coins = _coinsValue;
    return _exercise != null &&
        target != null &&
        target > 0 &&
        target <= challengeTargetMax &&
        coins != null &&
        coins >= 0 &&
        coins <= challengeCoinsMax;
  }

  void _startEdit(ChallengeStepAdmin step) {
    setState(() {
      _editing = step;
      _exercise = step.exercise;
      _muscle = step.muscle;
      _target.text = '${step.target}';
      _coins.text = '${step.coins}';
    });
  }

  void _resetForm() {
    _editing = null;
    _target.clear();
    _coins.clear();
    _muscle = challengeMuscles.first;
    _exercise = _exercises.isEmpty ? null : _exercises.first;
  }

  Future<void> _submit() async {
    final editing = _editing;
    final exercise = _exercise;
    final target = _targetValue;
    final coins = _coinsValue;
    if (exercise == null || target == null || coins == null) return;
    setState(() => _busy = true);
    try {
      if (editing == null) {
        await (widget.add ?? Db.addChallengeStep)(
          exercise: exercise,
          target: target,
          coins: coins,
          muscle: _muscle,
        );
      } else {
        await (widget.update ?? Db.updateChallengeStep)(
          editing.id,
          exercise: exercise,
          target: target,
          coins: coins,
          muscle: _muscle,
        );
      }
      if (!mounted) return;
      setState(_resetForm);
      await _reload();
    } catch (err) {
      if (mounted) showSnack(context, trf('Amalga oshmadi: {0}', [apiErrorText(err)]));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(ChallengeStepAdmin step) async {
    final ok = await confirm(
      context,
      title: tr("Qadamni o'chiramizmi?"),
      message: tr("Bu qadam o'chiriladi."),
      ok: tr("O'chirish"),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await (widget.remove ?? Db.removeChallengeStep)(step.id);
      if (!mounted) return;
      if (_editing?.id == step.id) setState(_resetForm);
      await _reload();
    } catch (err) {
      if (!mounted) return;
      final blocked = err is ApiException && err.status == 409;
      showSnack(
        context,
        blocked
            ? tr('Foydalanuvchilar bu qadamga yetgan')
            : trf('Amalga oshmadi: {0}', [apiErrorText(err)]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final steps = _steps;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: ListView(shrinkWrap: true, children: [
        Text(tr("Vazifalar yo'li"), style: t.titleLarge),
        const SizedBox(height: AppSpace.md),
        if (_loadError != null && steps == null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: Text(
              apiErrorText(_loadError!),
              style: t.bodyMedium?.copyWith(color: AppColors.danger),
            ),
          )
        else if (steps == null)
          const Padding(
            padding: EdgeInsets.all(AppSpace.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (steps.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: Text(
              tr("Qadam yo'q"),
              style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ),
        for (final step in steps ?? const <ChallengeStepAdmin>[])
          _StepRow(
            step: step,
            last: step.id == steps!.last.id,
            selected: _editing?.id == step.id,
            onEdit: () => _startEdit(step),
            onDelete: () => _remove(step),
          ),
        const SizedBox(height: AppSpace.sm),
        Text(_editing == null ? tr('Yangi qadam') : tr('Qadamni tahrirlash'), style: t.titleMedium),
        const SizedBox(height: AppSpace.sm),
        Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
          for (final key in _exercises)
            ChoiceChip(
              key: Key('challenge-exercise-$key'),
              selected: _exercise == key,
              onSelected: (_) => setState(() => _exercise = key),
              label: Text(gameExerciseName(key)),
            ),
        ]),
        if (_editing != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: Text(
              tr("Mashq turini o'zgartirish hozirgi foydalanuvchilar progressiga ta'sir qiladi"),
              key: const Key('challenge-edit-hint'),
              style: t.bodySmall?.copyWith(color: AppColors.warning),
            ),
          ),
        const SizedBox(height: AppSpace.sm),
        Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
          for (final muscle in challengeMuscles)
            ChoiceChip(
              key: Key('challenge-muscle-$muscle'),
              selected: _muscle == muscle,
              onSelected: (_) => setState(() => _muscle = muscle),
              label: Text(challengeMuscleName(muscle)),
            ),
        ]),
        const SizedBox(height: AppSpace.sm),
        TextField(
          key: const Key('challenge-target'),
          controller: _target,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: '$challengeTargetMax'.length,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: tr('Nishon (marta)')),
        ),
        TextField(
          key: const Key('challenge-coins'),
          controller: _coins,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: '$challengeCoinsMax'.length,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: tr('Mukofot (tanga)')),
        ),
        const SizedBox(height: AppSpace.lg),
        FilledButton(
          key: const Key('challenge-submit'),
          onPressed: (_busy || !_valid) ? null : _submit,
          child: Text(_editing == null ? tr("Qo'shish") : tr('Saqlash')),
        ),
        if (_editing != null)
          TextButton(
            key: const Key('challenge-cancel'),
            onPressed: _busy ? null : () => setState(_resetForm),
            child: Text(tr('Bekor qilish')),
          ),
      ]),
    );
  }
}

class _StepRow extends StatelessWidget {
  final ChallengeStepAdmin step;
  final bool last;
  final bool selected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StepRow({
    required this.step,
    required this.last,
    required this.selected,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: BentoTile(
        child: Row(children: [
          HexBadge(exercise: step.exercise, size: 40),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                trf('{0}: {1} marta', [gameExerciseName(step.exercise), step.target]),
                style: t.titleSmall?.copyWith(
                  color: selected ? AppColors.accent : null,
                ),
              ),
              Text(
                '${challengeMuscleName(step.muscle)} · ${step.coins}',
                style: t.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ]),
          ),
          IconButton(
            key: Key('challenge-edit-${step.id}'),
            tooltip: tr('Tahrirlash'),
            constraints: const BoxConstraints(minWidth: kTouchTarget, minHeight: kTouchTarget),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          if (last)
            IconButton(
              key: Key('challenge-delete-${step.id}'),
              tooltip: tr("O'chirish"),
              constraints: const BoxConstraints(minWidth: kTouchTarget, minHeight: kTouchTarget),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ]),
      ),
    );
  }
}
