import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../l10n/tr.dart';
import '../../models/exercises.dart';
import '../../models/gym.dart';
import '../../services/api/api_error.dart';
import '../../services/db.dart';
import '../../services/notifications.dart';
import '../../theme.dart';
import '../../widgets/workout_feedback.dart';
import '../../widgets/body_map.dart';
import '../../widgets/particle_body.dart';
import '../../widgets/rest_timer.dart';
import '../../widgets/ui.dart';

class MusclesScreen extends StatefulWidget {
  final List<int> gymDays;

  final bool homeToday;

  final VoidCallback onBack;

  final Stream<List<Exercise>>? custom;

  final Map<String, List<String>> program;

  final Stream<WorkoutProgress>? progress;

  final VoidCallback? onStart;
  final void Function(String key, bool done)? onDone;
  final void Function(int rating)? onFeedback;

  final int? weekday;

  const MusclesScreen({
    super.key,
    required this.gymDays,
    required this.onBack,
    this.homeToday = false,
    this.custom,
    this.program = const {},
    this.progress,
    this.onStart,
    this.onDone,
    this.onFeedback,
    this.weekday,
  });

  @override
  State<MusclesScreen> createState() => _MusclesScreenState();
}

Color get _brand => AppColors.accent;
Color get _brandFill => AppColors.accentFill;
Color get _white => AppColors.text;
Color get _silver => AppColors.textMuted;
Color get _ash => AppColors.textMuted;

TextStyle get _label => TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: AppColors.textMuted,
    );

TextStyle get _lead =>
    TextStyle(fontSize: 17, height: 1.5, fontWeight: FontWeight.w300, color: _silver);

class _MusclesScreenState extends State<MusclesScreen> with WidgetsBindingObserver {
  int _angle = ParticleBody.front;
  String? _muscle;

  String? _open;

  List<Exercise> _custom = const [];

  List<Exercise> _of(String id) => exercisesForStudent(id, _custom, widget.program);

  bool _started = false;
  Set<String> _done = {};
  int? _feedback;
  StreamSubscription<WorkoutProgress>? _sub;
  String? _restKey;
  final RestTimerController _rest = RestTimerController(
    onFinished: restTimerAlert,
    onStarted: Notifications.scheduleRestEnd,
    onStopped: Notifications.cancelRestEnd,
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _rest.refresh();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = widget.progress?.listen((p) {
      if (mounted) {
        setState(() {
          _started = p.started;
          _done = {...p.done};
          _feedback = p.feedback;
        });
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _rest.dispose();
    super.dispose();
  }

  bool get _running => _gymToday && _started;

  String? get _active => activeMuscle(_plan, _done, (m) => [for (final e in _of(m)) e.key]);

  void _start() {
    setState(() {
      _started = true;
      _muscle = null;
      _open = null;
    });
    widget.onStart?.call();
  }

  void _setFeedback(int rating) {
    setState(() => _feedback = rating);
    widget.onFeedback?.call(rating);
  }

  void _toggleDone(Exercise e) {
    final done = !_done.contains(e.key);
    setState(() {
      done ? _done.add(e.key) : _done.remove(e.key);
      _open = null;
    });
    widget.onDone?.call(e.key, done);
    if (widget.onDone == null) return;
    if (done) {
      _startRest(e.key);
    } else {
      _rest.skip();
    }
  }

  Future<void> _startRest(String key) async {
    final seconds = await RestTimerPrefs.load(key);
    if (!mounted || !_done.contains(key)) return;
    _restKey = key;
    _rest.start(Duration(seconds: seconds));
  }

  int get _today => widget.weekday ?? DateTime.now().weekday;
  bool get _hasPlan => validGymDays(widget.gymDays);

  bool get _gymToday => !widget.homeToday && musclesFor(widget.gymDays, _today).isNotEmpty;

  int? get _planDay {
    if (!_hasPlan) return null;
    return _gymToday ? _today : nextWorkout(widget.gymDays, _today)?.$1;
  }

  List<String> get _plan => _planDay == null ? const [] : musclesFor(widget.gymDays, _planDay!);

  void _select(String? id) {
    if (id != null && _hasPlan && !_plan.contains(id)) return;
    if (_running) return;
    setState(() {
      _open = null;
      if (id == null || id == _muscle) {
        _muscle = null;
        return;
      }
      _muscle = id;
      _angle = ParticleBody.angleFor(id, _angle);
    });
  }

  void _rotate(int by) => setState(() => _angle = (_angle + by) % ParticleBody.views);

  void _face(int angle) => setState(() {
        _angle = angle;
        if (_muscle != null && !ParticleBody.has(_muscle!, angle: angle)) {
          _muscle = null;
          _open = null;
        }
      });

  (String, String) get _status {
    final next = nextWorkout(widget.gymDays, _today);
    final after = next == null
        ? ''
        : trf('Keyingi: {0} — {1}', [tr(weekdayNames[next.$1] ?? ''), tr(next.$2)]);
    if (!_hasPlan) {
      return (
        tr('Zal kunlari tanlanmagan'),
        tr("Zal bo'limida kunlarni tanlang — bugungi mashqlar shu yerda chiqadi. Hozircha hamma mushak ochiq."),
      );
    }
    if (widget.homeToday) {
      return (tr('Uyda mashq'), '${tr('Uydagi mashqlar hali tayyor emas.')} $after');
    }
    if (_gymToday) return (tr(workoutFor(widget.gymDays, _today)!), tr('Bugun zalga borish kuni'));
    return (tr('Dam olish kuni'), after);
  }

  Widget _exercises(String id, {bool marking = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final e in _of(id))
          _ExerciseRow(
            exercise: e,
            open: _open == e.name,
            onTap: () => setState(() => _open = _open == e.name ? null : e.name),
            done: marking ? _done.contains(e.key) : null,
            onDone: marking ? () => _toggleDone(e) : null,
          ),
      ]);

  String _names(Iterable<String> ids) => ids.map((id) => tr(muscleById(id)!.name)).join(' → ');

  int _doneIn(String id) => _of(id).where((e) => _done.contains(e.key)).length;

  List<Widget> _workout() {
    final plan = _plan;
    final active = _active;
    final at = active == null ? plan.length : plan.indexOf(active);
    return [
      for (final id in plan.take(at))
        if (_of(id).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '✓ ${trf('{0} — tugadi', [tr(muscleById(id)!.name)])}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: _brand),
            ),
          ),
      if (active == null) ...[
        const SizedBox(height: 14),
        Text(tr("Bugungi mashg'ulot tugadi"), style: _count),
        const SizedBox(height: 12),
        Text(tr('Hamma mashq bajarildi. Barakalla!'), style: _lead),
        if (widget.onFeedback != null) ...[
          const SizedBox(height: 24),
          WorkoutFeedbackPicker(selected: _feedback, onSelect: _setFeedback),
        ],
      ] else ...[
        const SizedBox(height: 14),
        Text('${tr('Hozir')}: ${tr(muscleById(active)!.name)}', style: _label),
        const SizedBox(height: 10),
        Text(trf('{0} / {1} bajarildi', [_doneIn(active), _of(active).length]), style: _count),
        const SizedBox(height: 30),
        _exercises(active, marking: true),
        if (at + 1 < plan.length)
          Text(
            trf('Navbatda: {0}', [_names(plan.skip(at + 1))]),
            style: _lead.copyWith(color: _ash),
          ),
      ],
    ];
  }

  List<Widget> _body() {
    if (_running) return _workout();
    final plan = _plan;
    final m = _muscle;
    if (m != null) {
      final muscle = muscleById(m)!;
      final head = [
        Text(tr(muscle.name), style: _label),
        const SizedBox(height: 10),
      ];
      return [
        ...head,
        Text(trf('{0} ta mashq', [_of(m).length]), style: _count),
        const SizedBox(height: 30),
        _exercises(m),
      ];
    }
    if (plan.isEmpty) {
      return [Text(tr('Hali mushak tanlanmagan.'), style: _lead.copyWith(color: _ash))];
    }
    return [
      Text(
        (_gymToday ? tr('Bugungi mashqlar') : tr("Keyingi mashg'ulot mashqlari")),
        style: _label,
      ),
      const SizedBox(height: 10),
      Text(
        trf('{0} ta mashq', [plan.fold<int>(0, (n, id) => n + _of(id).length)]),
        style: _count,
      ),
      const SizedBox(height: 34),
      for (final id in plan) ...[
        Text(tr(muscleById(id)!.name), style: _label.copyWith(color: _brand)),
        const SizedBox(height: 18),
        _exercises(id),
        const SizedBox(height: 10),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Exercise>>(
        stream: widget.custom,
        builder: (context, snap) {
          if (snap.hasError) return ErrorState(error: snap.error);
          _custom = snap.data ?? const [];
          return _page(context);
        },
      );

  Widget _page(BuildContext context) {
    final wide = MediaQuery.of(context).size.width;
    final active = _running ? _active : null;
    final plan = _running ? {if (active != null) active} : _plan.toSet();
    final (title, note) = _status;
    final fresh = {
      for (final e in _custom)
        if (e.isNew()) e.muscle,
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(children: [
            Expanded(
                child: ListView(
              padding:
                  EdgeInsets.fromLTRB(24, 6, 24, 60 + MediaQuery.viewPaddingOf(context).bottom),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: kTouchTarget, height: kTouchTarget),
                    alignment: Alignment.centerLeft,
                    tooltip: tr('Orqaga'),
                    onPressed: widget.onBack,
                    icon: Icon(Icons.arrow_back, color: _ash),
                  ),
                ),
                const SizedBox(height: 12),
                Text(trf('Bugun · {0}', [tr(weekdayNames[_today] ?? '')]), style: _label),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: wide < 380 ? 30 : 36,
                    height: 1.05,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -1.2,
                    color: _white,
                  ),
                ),
                if (note.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(note.trim(), style: _lead),
                ],
                if (!_hasPlan) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _brandFill,
                      foregroundColor: AppColors.onAccentFill,
                      minimumSize: const Size(double.infinity, kTouchTarget),
                    ),
                    onPressed: widget.onBack,
                    child: Text(tr('Kunlarni tanlash')),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  tr('Hozircha faqat zaldagi mashqlar. Uydagi mashqlar hali tayyor emas.'),
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted),
                ),
                if (_gymToday && _plan.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  if (!_running) ...[
                    Text(trf('Tartib: {0}', [_names(_plan)]), style: _lead),
                    const SizedBox(height: 14),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _brandFill,
                        foregroundColor: AppColors.onAccentFill,
                        minimumSize: const Size(double.infinity, 54),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.4),
                      ),
                      onPressed: _start,
                      child: Text(tr("Mashg'ulotni boshlash")),
                    ),
                  ] else
                    Text(
                      active == null
                          ? tr("Bugungi mashg'ulot tugadi")
                          : '${tr('Hozir')}: ${tr(muscleById(active)!.name)} · '
                              '${trf('{0} / {1} bajarildi', [
                                  _doneIn(active),
                                  _of(active).length
                                ])}',
                      style: TextStyle(
                          fontSize: 18, height: 1.3, fontWeight: FontWeight.w600, color: _white),
                    ),
                ],
                const SizedBox(height: 26),
                Row(children: [
                  _Side(
                    text: tr('Old'),
                    active: _angle == ParticleBody.front,
                    onTap: () => _face(ParticleBody.front),
                  ),
                  const SizedBox(width: 24),
                  _Side(
                    text: tr('Orqa'),
                    active: _angle == ParticleBody.back,
                    onTap: () => _face(ParticleBody.back),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _brandFill,
                      foregroundColor: AppColors.onAccentFill,
                      minimumSize: const Size(0, kTouchTarget),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.4),
                    ),
                    onPressed: () => _rotate(1),
                    child: Text(tr('Aylantirish')),
                  ),
                ]),
                const SizedBox(height: 18),
                FadeInUp(
                  index: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0C12),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                    child: Center(
                      child: ParticleBody(
                        angle: _angle,
                        selected: _running ? null : _muscle,
                        today: plan,
                        onTap: _select,
                        onRotate: _rotate,
                        width: wide < 380 ? 290 : 320,
                        height: wide < 380 ? 520 : 574,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    tr('Surib aylantiring'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: _ash),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _muscle == null || _running ? 0 : 1,
                    child: _Side(
                      text: tr("To'liq ko'rinish"),
                      active: false,
                      onTap: () => _select(null),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                  for (final m in muscles)
                    if (!_hasPlan || _plan.contains(m.id))
                      Semantics(
                        button: true,
                        selected: m.id == (_running ? active : _muscle),
                        child: InkWell(
                          onTap: () => _select(m.id),
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(minWidth: 48, minHeight: kTouchTarget),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: m.id == (_running ? active : _muscle)
                                    ? AppColors.cardHigh
                                    : AppColors.card,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                border: Border.all(
                                  color: m.id == (_running ? active : _muscle)
                                      ? AppColors.accent
                                      : AppColors.hairline,
                                ),
                              ),
                              child: Center(
                                widthFactor: 1,
                                child: Text(
                                  fresh.contains(m.id)
                                      ? '${tr(m.name)} · ${tr('yangi')}'
                                      : tr(m.name),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: m.id == (_running ? active : _muscle)
                                        ? FontWeight.w600
                                        : FontWeight.w300,
                                    color: m.id == (_running ? active : _muscle)
                                        ? _white
                                        : _running
                                            ? (active == null ||
                                                    _plan.indexOf(m.id) < _plan.indexOf(active)
                                                ? _brand
                                                : _ash)
                                            : plan.contains(m.id)
                                                ? _white
                                                : _ash,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                ]),
                const SizedBox(height: 44),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  for (final back in [false, true])
                    Column(children: [
                      BodyMap(
                        back: back,
                        primary: _running ? active : _muscle,
                        secondary: _running ? const {} : plan,
                        onTap: _select,
                        height: wide < 380 ? 270 : 310,
                      ),
                      const SizedBox(height: 6),
                      Text(tr(back ? 'Orqa' : 'Old'), style: _label.copyWith(color: _ash)),
                    ]),
                ]),
                const SizedBox(height: 52),
                ..._body(),
                const SizedBox(height: 18),
                Text(
                  tr("Sinov versiyasi: mashqlar ro'yxati namunaviy — treneringiz bergan dastur ustun turadi."),
                  style: TextStyle(
                      fontSize: 13, height: 1.5, fontWeight: FontWeight.w300, color: _ash),
                ),
              ],
            )),
            ListenableBuilder(
              listenable: _rest,
              builder: (context, _) => _rest.running
                  ? RestTimerBar(controller: _rest, exerciseKey: _restKey)
                  : const SizedBox.shrink(),
            ),
          ]),
        ),
      ),
    );
  }
}

TextStyle get _count => TextStyle(
      fontSize: 30,
      height: 1.05,
      fontWeight: FontWeight.w400,
      letterSpacing: -1,
      color: _white,
    );

class _Side extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;
  const _Side({required this.text, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: kTouchTarget),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: active ? _white : _ash,
              ),
            ),
          ),
        ),
      );
}

class _ExerciseRow extends StatelessWidget {
  final Exercise exercise;
  final bool open;
  final VoidCallback onTap;

  final bool? done;
  final VoidCallback? onDone;
  const _ExerciseRow({
    required this.exercise,
    required this.open,
    required this.onTap,
    this.done,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    final back = BodyMap.backIsBetter(e.muscle);
    final also = [for (final id in e.also) muscleById(id)].whereType<Muscle>().toList();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 36),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (e.isNew()) ...[
                  Text(tr('Yangi'), style: _label),
                  const SizedBox(height: 6),
                ],
                Text(
                  tr(e.name),
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.15,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.4,
                    color: _white,
                  ),
                ),
                const SizedBox(height: 8),
                if (e.sets.isNotEmpty)
                  Text(
                    tr(e.sets),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _brand),
                  ),
                if (done != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: done! ? _brand : _white,
                      side: BorderSide(color: done! ? _brand : _ash),
                      minimumSize: const Size(0, kTouchTarget),
                    ),
                    onPressed: onDone,
                    icon: Icon(done! ? Icons.check_circle : Icons.radio_button_unchecked, size: 18),
                    label: Text(done! ? tr('Bajarildi') : tr('Bajardim')),
                  ),
                ],
                if (also.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    trf('Yordamchi: {0}', [also.map((m) => tr(m.name)).join(', ')]),
                    style: TextStyle(
                        fontSize: 13, height: 1.4, fontWeight: FontWeight.w300, color: _ash),
                  ),
                ],
              ]),
            ),
            const SizedBox(width: 18),
            BodyMap(back: back, primary: e.muscle, secondary: e.also.toSet(), height: 150),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topLeft,
            child: open
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (e.hasVideo || e.videoProcessing) ...[
                        _StoredVideo(id: e.id, processing: e.videoProcessing),
                        const SizedBox(height: 14),
                      ],
                      Text(
                        tr(e.tip),
                        style: TextStyle(
                            fontSize: 16, height: 1.5, fontWeight: FontWeight.w300, color: _silver),
                      ),
                    ]),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    );
  }
}

@visibleForTesting
Widget Function(String url)? debugVideoPlayer;

@visibleForTesting
Future<String> Function(String id)? debugVideoUrl;

class _StoredVideo extends StatefulWidget {
  final String id;
  final bool processing;
  const _StoredVideo({required this.id, this.processing = false});

  @override
  State<_StoredVideo> createState() => _StoredVideoState();
}

class _StoredVideoState extends State<_StoredVideo> {
  VideoPlayerController? _controller;
  String? _url;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_StoredVideo old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      _release();
      _load();
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  void _release() {
    _controller?.dispose();
    _controller = null;
    _url = null;
  }

  Future<void> _load() async {
    final id = widget.id;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await (debugVideoUrl ?? Db.exerciseVideoUrl)(id);
      if (!mounted || id != widget.id) return;
      if (url.isEmpty) {
        setState(() {
          _url = null;
          _loading = false;
        });
        return;
      }
      if (debugVideoPlayer != null) {
        setState(() {
          _url = url;
          _loading = false;
        });
        return;
      }
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted || id != widget.id) {
        await controller.dispose();
        return;
      }
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() {
        _controller = controller;
        _url = url;
        _loading = false;
      });
    } catch (e) {
      if (mounted && id == widget.id) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  void _toggle() {
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? c.pause() : c.play();
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    final url = _url;
    final controller = _controller;
    if (!_loading && _error == null && (url == null || url.isEmpty) && !widget.processing) {
      return const SizedBox.shrink();
    }
    if (_loading) {
      body = Center(child: CircularProgressIndicator(color: _brand));
    } else if (_error == null && (url == null || url.isEmpty)) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            tr('Video tayyorlanmoqda'),
            textAlign: TextAlign.center,
            style: TextStyle(color: _silver),
          ),
        ),
      );
    } else if (_error != null || url == null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            _error == null ? tr('Video yuklanmadi') : apiErrorText(_error!),
            textAlign: TextAlign.center,
            style: TextStyle(color: _silver),
          ),
          TextButton(
            onPressed: _load,
            child: Text(tr('Qayta urinish'), style: TextStyle(color: _brand)),
          ),
        ]),
      );
    } else if (debugVideoPlayer != null) {
      body = debugVideoPlayer!(url);
    } else {
      final playing = controller!.value.isPlaying;
      body = Stack(fit: StackFit.expand, children: [
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
        Semantics(
          button: true,
          label: playing ? tr('Pauza') : tr("Videoni ko'rish"),
          child: InkWell(
            onTap: _toggle,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: playing ? 0 : 1,
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: _brand, shape: BoxShape.circle),
                  child: Icon(Icons.play_arrow, color: _white, size: 38),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: VideoProgressColors(playedColor: _brand),
          ),
        ),
      ]);
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: Colors.black, child: body),
          ),
        ),
      ),
    );
  }
}
