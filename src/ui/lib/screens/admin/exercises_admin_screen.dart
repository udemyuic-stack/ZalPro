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
/// Har mashq tahrirlanadi — namunaviysi ham (masalan video havolasi qo'shish uchun):
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
              "\"{0}\" namunaviy holiga qaytadi: siz kiritgan o'zgarishlar va video havolasi o'chadi.",
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
      if (mounted) showSnack(context, trf("O'chirib bo'lmadi: {0}", [err]));
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
                      child: Text(tr('OLD')),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _angle = ParticleBody.back),
                      child: Text(tr('ORQA')),
                    ),
                    TextButton.icon(
                      onPressed: () => _rotate(1),
                      icon: const Icon(Icons.threesixty, size: 18),
                      label: Text(tr("O'GIRISH")),
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
                              if (e.video.isNotEmpty)
                                Pill(
                                    text: tr('Video'),
                                    color: AppColors.water,
                                    icon: Icons.play_circle_outline),
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

  late final _video = TextEditingController(text: widget.existing?.video);

  /// Daraja ('' — belgilanmagan)
  late String _lvl = widget.existing?.level ?? '';

  /// Chizma bosilganda nima o'zgaradi: true — yordamchi mushaklar, false — asosiy mushak
  bool _helpers = false;
  bool _busy = false;
  String? _error;
  late bool _hasVideo = widget.existing?.hasVideo ?? false;
  double? _progress;

  bool get _uploading => _progress != null;

  Future<void> _pickVideo(String id) async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    if (await file.length() > Exercise.maxVideoBytes) {
      return setState(() => _error = tr('Video 60 MB dan katta. Avval kichraytiring'));
    }
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      final bytes = await file.readAsBytes();
      await Db.uploadExerciseVideo(id, bytes, onProgress: (sent, total) {
        if (mounted && total > 0) setState(() => _progress = sent / total);
      });
      if (mounted) {
        setState(() {
          _hasVideo = true;
          _progress = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress = null;
          _error = trf('Video yuklanmadi: {0}', [apiErrorText(e)]);
        });
      }
    }
  }

  Future<void> _removeVideo(String id) async {
    try {
      await Db.deleteExerciseVideo(id);
      if (mounted) setState(() => _hasVideo = false);
    } catch (e) {
      if (mounted) setState(() => _error = trf("Video o'chmadi: {0}", [apiErrorText(e)]));
    }
  }

  Widget _videoFile(TextTheme t) {
    final old = widget.existing;
    if (old == null || !old.isCustom) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: Text(
          tr('Video fayl yuklash uchun avval mashqni saqlang'),
          style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          _hasVideo ? tr('Video fayl yuklangan') : tr('Video fayl yo\'q'),
          style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpace.sm),
        if (_uploading)
          LinearProgressIndicator(value: _progress)
        else
          Wrap(spacing: AppSpace.sm, children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pickVideo(old.id),
              icon: const Icon(Icons.video_file_outlined),
              label: Text(_hasVideo ? tr('Videoni almashtirish') : tr('Video yuklash')),
            ),
            if (_hasVideo)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _removeVideo(old.id),
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
    _video.dispose();
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
    final name = _kept(_name.text.trim(), widget.existing?.name), video = _video.text.trim();
    if (name.isEmpty) return setState(() => _error = tr('Mashq nomini yozing'));
    // bir xil mashq ikki marta kiritilmasin (boshqa mushakda bo'lsa ham)
    final same =
        sameExercise(name, widget.custom, exceptId: widget.existing?.id ?? '', exceptBase: _base);
    if (same != null) {
      return setState(() => _error =
          trf('Bunday mashq bor: {0} — {1}', [same.name, tr(muscleById(same.muscle)!.name)]));
    }
    if (video.isNotEmpty && !RegExp(r'^https?://\S+$').hasMatch(video)) {
      return setState(() => _error = tr('Havola http:// yoki https:// bilan boshlanishi kerak'));
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final old = widget.existing;
    try {
      await Db.saveExercise(Exercise(
        name,
        _muscle,
        _kept(_sets.text.trim(), old?.sets),
        _kept(_tip.text.trim(), old?.tip),
        also: _also.toList(),
        id: old?.id ?? '',
        video: video,
        level: _lvl,
        // tahrirda birinchi muallif va vaqt saqlanadi (qoida ham shuni talab qiladi);
        // namunaviy birinchi marta o'zgartirilganda — yangi yozuv
        createdAt: old != null && old.isCustom ? old.createdAt : DateTime.now(),
        createdBy: old != null && old.isCustom ? old.createdBy : widget.adminId,
        base: _base,
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = trf("Saqlab bo'lmadi: {0}", [e]);
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
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(tr('Asosiy mushak'))),
                ButtonSegment(value: true, label: Text(tr('Yordamchi mushaklar'))),
              ],
              selected: {_helpers},
              onSelectionChanged: (s) => setState(() => _helpers = s.first),
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
            TextField(
              controller: _video,
              maxLength: 300,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: tr('Video havolasi (ixtiyoriy)'),
                hintText: 'https://',
              ),
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
