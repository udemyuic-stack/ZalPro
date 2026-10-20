import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/tr.dart';
import '../../models/heart_rate.dart';
import '../../services/hr_camera.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

enum _HrState { starting, measuring, done, denied, unavailable }

class HeartRateScreen extends StatefulWidget {
  final HrCameraSource Function()? sourceBuilder;
  const HeartRateScreen({super.key, this.sourceBuilder});

  @override
  State<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends State<HeartRateScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _idleLimit = Duration(seconds: 30);
  static const _measureLimit = Duration(milliseconds: hrTotalMs + 2000);

  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
    lowerBound: 0.9,
    upperBound: 1.1,
  );
  final HeartRateEstimator _estimator = HeartRateEstimator();
  HrCameraSource? _source;
  Timer? _deadline;
  Timer? _ui;
  _HrState _state = _HrState.starting;
  HeartRateResult? _result;
  bool _finger = false;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _beat.repeat(reverse: true);
    _begin();
  }

  Future<void> _begin() async {
    final run = ++_run;
    _estimator.reset();
    _finger = false;
    _result = null;
    setState(() => _state = _HrState.starting);
    _beat.duration = const Duration(milliseconds: 800);
    if (_beat.isAnimating) _beat.repeat(reverse: true);
    final source = (widget.sourceBuilder ?? TorchHrCamera.new)();
    _source = source;
    try {
      await source.start((t, red) => _onSample(run, t, red));
      if (!mounted || run != _run) {
        await source.stop();
        return;
      }
      setState(() => _state = _HrState.measuring);
      _armDeadline(_idleLimit);
      _ui = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() {});
      });
    } on HrCameraDenied {
      await _fail(run, _HrState.denied);
    } catch (_) {
      await _fail(run, _HrState.unavailable);
    }
  }

  Future<void> _fail(int run, _HrState state) async {
    await _release();
    if (mounted && run == _run) setState(() => _state = state);
  }

  void _armDeadline(Duration d) {
    _deadline?.cancel();
    _deadline = Timer(d, _finish);
  }

  void _onSample(int run, int timeMs, double red) {
    if (!mounted || run != _run || _state != _HrState.measuring) return;
    if (red < hrMinFingerRed) {
      if (_finger) {
        _finger = false;
        _estimator.reset();
        _armDeadline(_idleLimit);
      }
      return;
    }
    if (!_finger) {
      _finger = true;
      _armDeadline(_measureLimit);
    }
    _estimator.add(timeMs, red);
    if (_estimator.complete) _finish();
  }

  Future<void> _finish() async {
    if (_state != _HrState.measuring) return;
    final result = _finger
        ? _estimator.estimate()
        : const HeartRateResult(null, HrQuality.noFinger);
    _state = _HrState.done;
    await _release();
    if (!mounted) return;
    final bpm = result.bpm;
    if (bpm != null) {
      _beat.duration = Duration(milliseconds: (60000 / bpm).round());
      _beat.repeat(reverse: true);
    }
    setState(() => _result = result);
  }

  Future<void> _release() async {
    _deadline?.cancel();
    _ui?.cancel();
    final s = _source;
    _source = null;
    await s?.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _state == _HrState.measuring) {
      _run++;
      _release();
      setState(() => _state = _HrState.done);
      _result = const HeartRateResult(null, HrQuality.noFinger);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _run++;
    _release();
    _beat.dispose();
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr('Yurak urishi'))),
        body: SafeArea(
          child: switch (_state) {
            _HrState.starting => const Center(child: CircularProgressIndicator()),
            _HrState.denied => EmptyState(
                icon: Icons.videocam_off_outlined,
                title: tr('Kameraga ruxsat berilmagan'),
                subtitle: tr('Telefon sozlamalarida Aura Fit uchun kamerani yoqing'),
              ),
            _HrState.unavailable => EmptyState(
                icon: Icons.videocam_off_outlined,
                title: tr('Kamera ochilmadi'),
                subtitle: tr("Boshqa ilova kamerani ishlatayotgan bo'lishi mumkin"),
                action: _retryButton(),
              ),
            _ => _body(context),
          },
        ),
      );

  Widget _retryButton() => OutlinedButton(
        key: const ValueKey('hr-retry'),
        onPressed: _begin,
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
        child: Text(tr("Qayta o'lchash")),
      );

  Widget _body(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final result = _result;
    final done = _state == _HrState.done && result != null;
    final good = done && result.quality == HrQuality.good;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(children: [
        const Spacer(),
        ScaleTransition(
          scale: _beat,
          child: Icon(
            Icons.favorite,
            key: const ValueKey('hr-heart'),
            size: 120,
            color: done && !good ? AppColors.textFaint : AppColors.accent,
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        if (good) ...[
          Text('${result.bpm}', key: const ValueKey('hr-bpm'), style: t.displayLarge),
          Text(tr('zarba/daq'), style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
        ] else if (done) ...[
          Text(
            result.quality == HrQuality.noFinger
                ? tr('Barmoq topilmadi')
                : tr("O'lchash barqaror chiqmadi"),
            key: const ValueKey('hr-fail'),
            textAlign: TextAlign.center,
            style: t.titleLarge,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            tr("Barmog'ingizni orqa kamera va chiroqqa yengil bosing, qimirlatmang"),
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
        ] else ...[
          Text(
            _finger
                ? (_estimator.warmingUp ? tr('Sozlanmoqda...') : tr("O'lchanmoqda..."))
                : tr("Barmog'ingizni orqa kamera va chiroq ustiga qo'ying"),
            key: const ValueKey('hr-hint'),
            textAlign: TextAlign.center,
            style: t.titleMedium,
          ),
          const SizedBox(height: AppSpace.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              key: const ValueKey('hr-progress'),
              value: _finger ? _estimator.progress : 0,
              minHeight: 8,
              color: AppColors.accent,
              backgroundColor: AppColors.cardHigh,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            trf('{0} soniya qoldi', [
              _finger ? ((hrTotalMs - _estimator.elapsedMs) / 1000).ceil().clamp(0, 30) : 30,
            ]),
            style: t.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
        const Spacer(),
        if (done) ...[
          SizedBox(width: double.infinity, child: _retryButton()),
          const SizedBox(height: AppSpace.md),
        ],
        Text(
          tr('Tibbiy maqsadda emas'),
          key: const ValueKey('hr-disclaimer'),
          textAlign: TextAlign.center,
          style: t.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
      ]),
    );
  }
}
