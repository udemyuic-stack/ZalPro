import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/tr.dart';
import '../models/exercise_set.dart';
import '../services/api/api_error.dart';
import '../services/db.dart';
import '../theme.dart';

const _saveDelay = Duration(milliseconds: 500);
const _maxSets = 20;

class ExerciseSetsEditor extends StatefulWidget {
  final String userId;
  final String exerciseKey;
  final ValueChanged<int>? onFilledChanged;

  const ExerciseSetsEditor({
    super.key,
    required this.userId,
    required this.exerciseKey,
    this.onFilledChanged,
  });

  @override
  State<ExerciseSetsEditor> createState() => _ExerciseSetsEditorState();
}

class _SetRow {
  final TextEditingController kg;
  final TextEditingController reps;

  _SetRow({String kg = '', String reps = ''})
      : kg = TextEditingController(text: kg),
        reps = TextEditingController(text: reps);

  ExerciseSet toSet(int no) => ExerciseSet(
        setNo: no,
        weightKg: double.tryParse(kg.text.trim().replaceAll(',', '.')),
        reps: int.tryParse(reps.text.trim()),
      );

  void dispose() {
    kg.dispose();
    reps.dispose();
  }
}

class _ExerciseSetsEditorState extends State<ExerciseSetsEditor> {
  final _rows = <_SetRow>[];
  List<ExerciseSet> _previous = const [];
  Timer? _timer;
  bool _loading = true;
  bool _dirty = false;
  String? _error;
  late final String _day = todayKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        Db.exerciseSets(widget.userId, _day, widget.exerciseKey),
        Db.previousExerciseSets(widget.userId, widget.exerciseKey, _day),
      ]);
      if (!mounted) return;
      final today = results[0];
      setState(() {
        _previous = results[1];
        final count = today.length > _previous.length ? today.length : _previous.length;
        for (var i = 0; i < (count == 0 ? 1 : count); i++) {
          final saved = i < today.length ? today[i] : null;
          _rows.add(_SetRow(
            kg: saved?.weightKg == null ? '' : formatKg(saved!.weightKg!),
            reps: saved?.reps == null ? '' : '${saved!.reps}',
          ));
        }
        _loading = false;
      });
      widget.onFilledChanged?.call(_collect().length);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorText(e);
        _loading = false;
      });
    }
  }

  List<ExerciseSet> _collect() {
    final out = <ExerciseSet>[];
    for (var i = 0; i < _rows.length; i++) {
      final s = _rows[i].toSet(i + 1);
      if (!s.isEmpty) out.add(s);
    }
    return out;
  }

  void _changed() {
    widget.onFilledChanged?.call(_collect().length);
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(_saveDelay, _save);
  }

  Future<void> _save() async {
    _timer?.cancel();
    if (!_dirty) return;
    _dirty = false;
    try {
      await Db.saveExerciseSets(widget.userId, _day, widget.exerciseKey, _collect());
      if (mounted && _error != null) setState(() => _error = null);
    } catch (e) {
      _dirty = true;
      if (mounted) setState(() => _error = apiErrorText(e));
    }
  }

  void _addRow() {
    if (_rows.length >= _maxSets) return;
    setState(() => _rows.add(_SetRow()));
  }

  @override
  void dispose() {
    if (_dirty) unawaited(_save());
    _timer?.cancel();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Widget _header(TextStyle? style) => Row(children: [
        SizedBox(width: 36, child: Text(tr('SET'), style: style)),
        Expanded(flex: 3, child: Text(tr('OLDINGI'), style: style)),
        Expanded(flex: 2, child: Text(tr('KG'), style: style)),
        const SizedBox(width: AppSpace.sm),
        Expanded(flex: 2, child: Text(tr('TAKROR'), style: style)),
      ]);

  Widget _field(TextEditingController c, {required bool decimal, required Key key}) => TextField(
        key: key,
        controller: c,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]')),
        ],
        maxLength: decimal ? 7 : 4,
        textAlign: TextAlign.center,
        onChanged: (_) => _changed(),
        decoration: const InputDecoration(counterText: '', isDense: true),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);
    if (_loading) return const SizedBox(height: kTouchTarget);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header(muted),
      const SizedBox(height: AppSpace.xs),
      for (var i = 0; i < _rows.length; i++)
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kTouchTarget),
          child: Row(children: [
            SizedBox(width: 36, child: Text('${i + 1}', style: t.bodyMedium)),
            Expanded(
              flex: 3,
              child: Text(
                previousLabel(i < _previous.length ? _previous[i] : null),
                key: Key('set-previous-$i'),
                style: muted,
              ),
            ),
            Expanded(flex: 2, child: _field(_rows[i].kg, decimal: true, key: Key('set-kg-$i'))),
            const SizedBox(width: AppSpace.sm),
            Expanded(
                flex: 2, child: _field(_rows[i].reps, decimal: false, key: Key('set-reps-$i'))),
          ]),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.xs),
          child: Text(_error!, style: t.bodySmall?.copyWith(color: AppColors.danger)),
        ),
      if (_rows.length < _maxSets)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('set-add'),
            style: TextButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
            onPressed: _addRow,
            icon: const Icon(Icons.add, size: 18),
            label: Text(tr("Set qo'shish")),
          ),
        ),
    ]);
  }
}
