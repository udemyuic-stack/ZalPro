import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/tr.dart';
import '../../models/exercises.dart';
import '../../models/models.dart';
import '../../services/api/api_error.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/body_map.dart';
import '../../widgets/particle_body.dart';
import '../../widgets/ui.dart';

/// Trener / bosh admin: mashqlar ro'yxati ("Tana xaritasi" uchun).
/// Tana chizmasida mushak bosiladi — shu mushak mashqlari chiqadi va yangisi qo'shiladi.
/// Har mashq tahrirlanadi — namunaviysi ham (masalan video qo'shish uchun):
/// namunaviy o'zgartirilsa, bazaga uning nusxasi yoziladi va ro'yxatda aslining o'rniga
/// chiqadi; nusxa o'chirilsa — asl holiga qaytadi. Trener qo'shgan mashq butunlay o'chadi.
/// Shogird o'zgarishni darhol ko'radi (bazadan o'qiladi).
class ExercisesAdminScreen extends StatefulWidget {
  final AppUser admin;
  const ExercisesAdminScreen({super.key, required this.admin});

  @override
  State<ExercisesAdminScreen> createState() => _ExercisesAdminScreenState();
}

class _ExercisesAdminScreenState extends State<ExercisesAdminScreen> {
  late final _stream = Db.customExercises();
  String? _muscle;

  /// Ro'yxat filtri: null — hammasi, '' — belgisiz, aks holda daraja kaliti ([levels])
  String? _level;

  /// Nuqtali tana ko'rinishi: 0 — old, 4 — orqa (har qadam 45 gradus)
  int _angle = ParticleBody.front;

  void _select(String id) => setState(() {
        _muscle = id == _muscle ? null : id;
        // nuqtali tana tanlangan mushak ko'rinadigan tomonga o'giriladi
        if (_muscle != null) _angle = ParticleBody.angleFor(id, _angle);
      });

  void _rotate(int by) => setState(() => _angle = (_angle + by) % ParticleBody.views);

  /// Oxirgi kelgan ro'yxat — qo'shish varag'i takror nomni shundan tekshiradi
  List<Exercise> _custom = const [];

  Future<void> _edit(String muscle, [Exercise? e]) async {
    final saved = await showSheet<bool>(
      context,
      ExerciseForm(adminId: widget.admin.id, muscle: muscle, existing: e, custom: _custom),
    );
    if (saved == true && mounted) {
      showSnack(context, e == null ? tr("Mashq qo'shildi") : tr('Mashq saqlandi'));
    }
  }

  Future<void> _delete(Exercise e) async {
    final ok = await confirm(
      context,
      title: e.isOverride ? tr('Asl holiga qaytarish') : tr("Mashqni o'chirish"),
      message: e.isOverride
          ? trf(
              "\"{0}\" namunaviy holiga qaytadi: siz kiritgan o'zgarishlar va yuklangan video o'chadi.",
              [tr(e.name)])
          : trf("\"{0}\" o'chiriladi. Shogirdlar uni boshqa ko'rmaydi.", [e.name]),
      ok: e.isOverride ? tr('Qaytarish') : tr("O'chirish"),
      destructive: true,
    );
    if (!ok) return;
    try {
      await Db.deleteExercise(e.id);
      if (mounted) {
        showSnack(context, e.isOverride ? tr('Asl holiga qaytdi') : tr("Mashq o'chirildi"));
      }
    } catch (err) {
      if (mounted) showSnack(context, trf("O'chirib bo'lmadi: {0}", [apiErrorText(err)]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Mashqlar'))),
      body: StreamBuilder<List<Exercise>>(
        stream: _stream,
        builder: (context, snap) {
          if (!snap.hasData && !snap.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          // baza javob bermasa ham ekran bo'sh qolmaydi: namunaviy ro'yxat va sxema ko'rinadi
          final custom = _custom = snap.data ?? const [];
          // yaqinda mashq qo'shilgan mushaklar chizmada och rangda ko'rinadi
          final fresh = {
            for (final e in custom)
              if (e.isNew()) e.muscle,
          };
          final m = _muscle;
          final all = m == null ? const <Exercise>[] : exercisesFor(m, custom);
          final list = _level == null ? all : all.where((e) => e.level == _level).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xxl),
            children: [
              if (snap.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: BentoTile(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Text(
                      tr("Trener qo'shgan mashqlar yuklanmadi — hozircha faqat namunaviy ro'yxat. "
                          "Yangi mashq saqlanmasligi mumkin."),
                      style: t.bodyMedium?.copyWith(color: AppColors.danger),
                    ),
                  ),
                ),
              Text(
                tr("Tanadan mushakni bosing — shu joy mashqlarini ko'rasiz va yangisini qo'shasiz."),
                style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpace.md),
              // Nuqtali tana — shogird ko'radigan ko'rinishning o'zi (360° aylanadi, bosiladi).
              // Qora fonda: nuqtalar shu fonga mo'ljallangan.
              Container(
                decoration:
                    BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                child: Column(children: [
                  ParticleBody(
                    angle: _angle,
                    selected: m,
                    today: fresh,
                    onTap: (id) => id == null ? setState(() => _muscle = null) : _select(id),
                    onRotate: _rotate,
                    width: 280,
                    height: 500,
                  ),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TextButton(
                      onPressed: () => setState(() => _angle = ParticleBody.front),
                      child: Text(tr('Old')),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _angle = ParticleBody.back),
                      child: Text(tr('Orqa')),
                    ),
                    TextButton.icon(
                      onPressed: () => _rotate(1),
                      icon: const Icon(Icons.threesixty, size: 18),
                      label: Text(tr("O'g'irish")),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: AppSpace.lg),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                for (final back in [false, true])
                  BodyMap(
                    back: back,
                    primary: m,
                    secondary: fresh,
                    onTap: _select,
                    height: 280,
                    accent: AppColors.accent,
                  ),
              ]),
              if (fresh.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm),
                  child: Text(
                    tr("Och rang — oxirgi 7 kunda yangi mashq qo'shilgan mushaklar."),
                    textAlign: TextAlign.center,
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              const SizedBox(height: AppSpace.md),
              Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                for (final g in muscles)
                  ChoiceChip(
                    label: Text('${tr(g.name)} · ${exercisesFor(g.id, custom).length}'),
                    selected: g.id == m,
                    onSelected: (_) => _select(g.id),
                  ),
              ]),
              const SizedBox(height: AppSpace.xl),
              if (m == null)
                Text(tr('Hali mushak tanlanmagan.'),
                    style: t.bodyMedium?.copyWith(color: AppColors.textMuted))
              else ...[
                SectionHeader(
                  tr(muscleById(m)!.name),
                  eyebrow: trf('{0} ta mashq', [all.length]),
                  trailing: FilledButton.icon(
                    onPressed: () => _edit(m),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(tr("Mashq qo'shish")),
                  ),
                ),
                // daraja bo'yicha saralash (faqat trener ko'radi)
                Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.xs, children: [
                  for (final (k, label) in <(String?, String)>[
                    (null, tr('Hammasi')),
                    for (final l in levels.entries) (l.key, tr(l.value)),
                    ('', tr('Belgisiz')),
                  ])
                    ChoiceChip(
                      label: Text(
                          k == null ? label : '$label · ${all.where((e) => e.level == k).length}'),
                      selected: _level == k,
                      onSelected: (_) => setState(() => _level = k),
                    ),
                ]),
                const SizedBox(height: AppSpace.md),
                if (list.isEmpty)
                  Text(tr("Bu darajada mashq yo'q."),
                      style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                for (final e in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.sm),
                    child: BentoTile(
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // trener yozgan matnning tarjimasi yo'q — tr() uni o'zgartirmay qaytaradi
                            Text(tr(e.name), style: t.titleMedium),
                            if (e.sets.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(tr(e.sets),
                                  style: t.bodyMedium?.copyWith(color: AppColors.accent)),
                            ],
                            const SizedBox(height: AppSpace.sm),
                            Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.xs, children: [
                              if (!e.isCustom)
                                Pill(text: tr('Namunaviy'), color: AppColors.textMuted)
                              else if (e.isOverride)
                                Pill(text: tr("Namunaviy · o'zgartirilgan"), color: AppColors.water)
                              else if (e.isNew())
                                Pill(text: tr('Yangi'), color: AppColors.accent)
                              else
                                Pill(text: tr("Trener qo'shgan"), color: AppColors.water),
                              if (e.videoProcessing)
                                Pill(
                                    text: tr('Tayyorlanmoqda'),
                                    color: AppColors.warning,
                                    icon: Icons.hourglass_empty_outlined)
                              else if (e.hasVideo)
                                Pill(
                                    text: tr('Video bor'),
                                    color: AppColors.water,
                                    icon: Icons.play_circle_outline)
                              else if (e.videoFailed)
                                Pill(
                                    text: tr('Video tayyorlanmadi'),
                                    color: AppColors.danger,
                                    icon: Icons.error_outline),
                              if (levels[e.level] case final l?)
                                Pill(
                                    text: tr(l),
                                    color: AppColors.warning,
                                    icon: Icons.signal_cellular_alt),
                            ]),
                          ]),
                        ),
                        // namunaviy mashq ham tahrirlanadi (video qo'shish uchun)
                        IconButton(
                          tooltip: tr('Tahrirlash'),
                          onPressed: () => _edit(m, e),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        if (e.isCustom)
                          IconButton(
                            tooltip: e.isOverride ? tr('Asl holiga qaytarish') : tr("O'chirish"),
                            onPressed: () => _delete(e),
                            icon: Icon(e.isOverride ? Icons.restore : Icons.delete_outline),
                          ),
                      ]),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Mashq qo'shish / tahrirlash varag'i. Tepada tana chizmasi turadi: asosiy mushak to'q,
/// yordamchilar och — trener qayerga mashq qo'shayotganini ko'rib turadi; chizmani bosib
/// o'zgartiradi.
class ExerciseForm extends StatefulWidget {
  final String adminId;

  /// Boshlang'ich asosiy mushak (ro'yxatda tanlangan)
  final String muscle;
  final Exercise? existing;

  /// Trener qo'shgan hamma mashqlar — takror nomni tekshirish va tanlangan mushakdagi
  /// mavjud mashqlarni ko'rsatish uchun
  final List<Exercise> custom;
  const ExerciseForm({
    super.key,
    required this.adminId,
    required this.muscle,
    this.existing,
    this.custom = const [],
  });

  @override
  State<ExerciseForm> createState() => _ExerciseFormState();
}

enum _VideoPhase { none, uploading, processing, failed, ready }

class _ExerciseFormState extends State<ExerciseForm> {
  late String _muscle = widget.existing?.muscle ?? widget.muscle;
  late final Set<String> _also = {...?widget.existing?.also};
  // namunaviy mashq matni ilova tilida ko'rsatiladi (trener o'qiy olsin); tegilmasa —
  // saqlashda asl o'zbekcha kalit yoziladi, tarjimasi yo'qolmaydi
  late final _name = TextEditingController(text: _shown(widget.existing?.name));
  late final _sets = TextEditingController(text: _shown(widget.existing?.sets));
  late final _tip = TextEditingController(text: _shown(widget.existing?.tip));

  String _shown(String? text) => text == null || text.isEmpty ? '' : tr(text);

  /// Maydon tegilmagan bo'lsa — asl matn (kalit), aks holda trener yozgani
  String _kept(String typed, String? original) =>
      original != null && original.isNotEmpty && typed == tr(original) ? original : typed;

  /// Tahrirlanayotgan namunaviy mashqning nomi (yangi mashqda bo'sh)
  String get _base {
    final old = widget.existing;
    if (old == null) return '';
    return old.isOverride ? old.base : (old.isCustom ? '' : old.name);
  }

  /// Daraja ('' — belgilanmagan)
  late String _lvl = widget.existing?.level ?? '';

  /// Chizma bosilganda nima o'zgaradi: true — yordamchi mushaklar, false — asosiy mushak
  bool _helpers = false;
  bool _busy = false;
  String? _error;
  late bool _hasVideo = widget.existing?.hasVideo ?? false;
  late _VideoPhase _phase = _initialPhase();
  double _progress = 0;
  XFile? _picked;
  String? _savedId;

  String get _id {
    final old = widget.existing;
    return _savedId ?? (old != null && old.isCustom ? old.id : '');
  }

  _VideoPhase _initialPhase() {
    final old = widget.existing;
    if (old == null || !old.isCustom) return _VideoPhase.none;
    if (old.videoProcessing) return _VideoPhase.processing;
    if (old.videoFailed) return _VideoPhase.failed;
    return old.hasVideo ? _VideoPhase.ready : _VideoPhase.none;
  }

  @override
  void initState() {
    super.initState();
    if (_phase == _VideoPhase.processing) _watch(_id);
  }

  bool get _uploading => _phase == _VideoPhase.uploading;

  Future<void> _watch(String id) async {
    try {
      final result = await Db.waitVideoReady(id, cancelled: () => !mounted);
      if (!mounted || result == 'processing') return;
      setState(() {
        _phase = result == 'ready' ? _VideoPhase.ready : _VideoPhase.failed;
        if (result == 'ready') _hasVideo = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _VideoPhase.failed;
        _error = trf('Video yuklanmadi: {0}', [apiErrorText(e)]);
      });
    }
  }

  Future<bool> _send(String id, XFile file) async {
    final previous = _hasVideo ? _VideoPhase.ready : _VideoPhase.none;
    setState(() {
      _phase = _VideoPhase.uploading;
      _progress = 0;
      _error = null;
    });
    try {
      final type = Exercise.videoContentType(file.name, file.mimeType) ??
          Exercise.videoContentType(file.path);
      if (type == null) {
        throw const ApiException(code: 'video_type_unsupported', message: '');
      }
      final size = await file.length();
      await Db.uploadExerciseVideo(
        id,
        size: size,
        contentType: type,
        bytes: kIsWeb ? await file.readAsBytes() : null,
        open: kIsWeb ? null : file.openRead,
        onProgress: (sent, total) {
          if (mounted && total > 0) setState(() => _progress = sent / total);
        },
      );
      if (!mounted) return true;
      setState(() => _phase = _VideoPhase.processing);
      _watch(id);
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = previous;
          _error = trf('Video yuklanmadi: {0}', [apiErrorText(e)]);
        });
      }
      return false;
    }
  }

  Future<void> _pickVideo() async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    if (await file.length() > Exercise.maxVideoBytes) {
      return setState(() => _error = tr('Video 100 MB dan katta. Avval kichraytiring'));
    }
    if (Exercise.videoContentType(file.name, file.mimeType) == null &&
        Exercise.videoContentType(file.path) == null) {
      return setState(() => _error = tr("Video turi qo'llanmaydi (mp4, mov, webm)"));
    }
    if (_id.isEmpty) {
      return setState(() {
        _picked = file;
        _error = null;
      });
    }
    await _send(_id, file);
  }

  Future<void> _removeVideo() async {
    final id = _id;
    if (id.isEmpty) return setState(() => _picked = null);
    try {
      await Db.deleteExerciseVideo(id);
      if (mounted) {
        setState(() {
          _hasVideo = false;
          _phase = _VideoPhase.none;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = trf("Video o'chmadi: {0}", [apiErrorText(e)]));
    }
  }

  Widget _videoFile(TextTheme t) {
    final muted = t.bodyMedium?.copyWith(color: AppColors.textMuted);
    final pending = _picked != null;
    final String label;
    switch (_phase) {
      case _VideoPhase.uploading:
        label = trf('Video yuklanmoqda: {0}%', [(_progress * 100).round()]);
      case _VideoPhase.processing:
        label = tr('Video tayyorlanmoqda (bir necha daqiqa)');
      case _VideoPhase.failed:
        label = tr('Video tayyorlanmadi');
      case _VideoPhase.ready:
        label = tr('Video fayl yuklangan');
      case _VideoPhase.none:
        label = pending ? _picked!.name : tr("Video fayl yo'q");
    }
    final busyPhase = _uploading || _phase == _VideoPhase.processing;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          label,
          style: _phase == _VideoPhase.failed ? muted?.copyWith(color: AppColors.danger) : muted,
        ),
        if (pending && _phase == _VideoPhase.none)
          Text(tr('Video mashq saqlanganda yuklanadi'),
              style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: AppSpace.sm),
        if (busyPhase)
          LinearProgressIndicator(value: _uploading ? _progress : null)
        else
          Wrap(spacing: AppSpace.sm, children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickVideo,
              icon: const Icon(Icons.video_file_outlined),
              label: Text(_phase == _VideoPhase.failed
                  ? tr('Qayta yuklash')
                  : (_hasVideo || pending)
                      ? tr('Videoni almashtirish')
                      : tr('Video yuklash')),
            ),
            if (_hasVideo || pending)
              OutlinedButton.icon(
                onPressed: _busy ? null : _removeVideo,
                icon: const Icon(Icons.delete_outline),
                label: Text(tr("Videoni o'chirish")),
              ),
          ]),
      ]),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _sets.dispose();
    _tip.dispose();
    super.dispose();
  }

  void _tap(String id) => setState(() {
        if (!_helpers) {
          _muscle = id;
          _also.remove(id);
        } else if (id != _muscle && !_also.remove(id)) {
          _also.add(id);
        }
      });

  Future<void> _save() async {
    final name = _kept(_name.text.trim(), widget.existing?.name);
    if (name.isEmpty) return setState(() => _error = tr('Mashq nomini yozing'));
    // bir xil mashq ikki marta kiritilmasin (boshqa mushakda bo'lsa ham)
    final same = sameExercise(name, widget.custom, exceptId: _id, exceptBase: _base);
    if (same != null) {
      return setState(() => _error =
          trf('Bunday mashq bor: {0} — {1}', [same.name, tr(muscleById(same.muscle)!.name)]));
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final old = widget.existing;
    try {
      final id = await Db.saveExercise(Exercise(
        name,
        _muscle,
        _kept(_sets.text.trim(), old?.sets),
        _kept(_tip.text.trim(), old?.tip),
        also: _also.toList(),
        id: _id,
        level: _lvl,
        // tahrirda birinchi muallif va vaqt saqlanadi (qoida ham shuni talab qiladi);
        // namunaviy birinchi marta o'zgartirilganda — yangi yozuv
        createdAt: old != null && old.isCustom ? old.createdAt : DateTime.now(),
        createdBy: old != null && old.isCustom ? old.createdBy : widget.adminId,
        base: _base,
      ));
      final file = _picked;
      if (file != null && id.isNotEmpty) {
        _savedId = id;
        _picked = null;
        if (!await _send(id, file)) {
          if (mounted) {
            setState(() {
              _busy = false;
              _error = trf('Mashq saqlandi, lekin video yuklanmadi: {0}', [_error ?? '']);
            });
          }
          return;
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = trf("Saqlab bo'lmadi: {0}", [apiErrorText(e)]);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final also = [for (final id in _also) muscleById(id)].whereType<Muscle>().toList();
    return SingleChildScrollView(
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? tr("Mashq qo'shish") : tr('Mashqni tahrirlash'),
                style: t.titleLarge),
            const SizedBox(height: AppSpace.md),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final back in [false, true])
                BodyMap(
                  back: back,
                  primary: _muscle,
                  secondary: _also,
                  onTap: _tap,
                  height: 210,
                  accent: AppColors.accent,
                ),
            ]),
            const SizedBox(height: AppSpace.sm),
            Text(trf('Asosiy mushak: {0}', [tr(muscleById(_muscle)!.name)]), style: t.titleSmall),
            Text(
              also.isEmpty
                  ? tr("Yordamchi mushaklar: yo'q")
                  : trf('Yordamchi: {0}', [also.map((m) => tr(m.name)).join(', ')]),
              style: t.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpace.sm),
            AppSegmented<bool>(
              segments: [
                AppSegment(value: false, label: tr('Asosiy mushak')),
                AppSegment(value: true, label: tr('Yordamchi mushaklar')),
              ],
              selected: _helpers,
              onChanged: (v) => setState(() => _helpers = v),
            ),
            const SizedBox(height: 4),
            Text(
              tr('Chizmani bosing — tanlangan tur belgilanadi.'),
              style: t.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpace.md),
            // shu mushakda bor mashqlar — trener takrorlamasligi uchun ko'z oldida turadi
            Text(
              trf('Bu mushakda bor mashqlar: {0}', [exercisesFor(_muscle, widget.custom).length]),
              style: t.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final e in exercisesFor(_muscle, widget.custom))
              if (e.key != widget.existing?.key)
                Text(
                  '· ${tr(e.name)}',
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
            const SizedBox(height: AppSpace.md),
            // daraja — shogird ko'rmaydi; trener mashq tanlayotganda saralash uchun
            Text(tr('Daraja (shogird ko\'rmaydi)'), style: t.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.xs, children: [
              for (final (k, label) in <(String, String)>[
                for (final l in levels.entries) (l.key, tr(l.value)),
                ('', tr('Belgisiz')),
              ])
                ChoiceChip(
                    label: Text(label),
                    selected: _lvl == k,
                    onSelected: (_) => setState(() => _lvl = k)),
            ]),
            const SizedBox(height: AppSpace.md),
            TextField(
              controller: _name,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tr('Mashq nomi')),
            ),
            TextField(
              controller: _sets,
              maxLength: 40,
              decoration: InputDecoration(labelText: tr('Yondashuv × takror'), hintText: '4 × 10'),
            ),
            TextField(
              controller: _tip,
              maxLength: 500,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tr('Maslahat: qanday bajariladi')),
            ),
            _videoFile(t),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: Text(_error!, style: t.bodyMedium?.copyWith(color: AppColors.danger)),
              ),
            FilledButton(
              onPressed: _busy || _uploading ? null : _save,
              child: Text(_busy ? tr('Saqlanmoqda…') : tr('Saqlash')),
            ),
          ]),
    );
  }
}
