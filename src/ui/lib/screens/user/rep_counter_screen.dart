import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/tr.dart';
import '../../models/heart_rate.dart';
import '../../models/rep_counter.dart';
import '../../services/rep_camera.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';
import 'heart_rate_screen.dart';

enum _CamState { starting, ready, denied, unavailable }

class RepCounterScreen extends StatefulWidget {
  final RepCameraSource Function()? sourceBuilder;
  const RepCounterScreen({super.key, this.sourceBuilder});

  @override
  State<RepCounterScreen> createState() => _RepCounterScreenState();
}

class _RepCounterScreenState extends State<RepCounterScreen> {
  late final RepCameraSource _source = (widget.sourceBuilder ?? MlKitRepCamera.new)();
  final RepCounter _counter = RepCounter();
  _CamState _state = _CamState.starting;
  bool _counting = false;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _open();
  }

  Future<void> _open() async {
    try {
      await _source.start(_onAngle);
      if (mounted) setState(() => _state = _CamState.ready);
    } on RepCameraDenied {
      if (mounted) setState(() => _state = _CamState.denied);
    } catch (_) {
      if (mounted) setState(() => _state = _CamState.unavailable);
    }
  }

  void _onAngle(double? angle) {
    if (!mounted) return;
    final visible = angle != null;
    if (_counting) _counter.add(angle);
    setState(() => _visible = visible);
  }

  bool get _heartRateOk => heartRateSupported(isWeb: kIsWeb, platform: defaultTargetPlatform);

  Future<void> _openHeartRate() async {
    await _source.stop();
    if (!mounted) return;
    await Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: (_) => const HeartRateScreen()));
  }

  Future<void> _suggestHeartRate() async {
    final t = Theme.of(context).textTheme;
    final go = await showSheet<bool>(
      context,
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr("Mashqdan keyin yurak urishini o'lchang"), style: t.titleLarge),
        const SizedBox(height: AppSpace.sm),
        Text(
          tr("Barmog'ingizni orqa kameraga qo'yib, 30 soniyada o'lchang"),
          style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpace.xl),
        FilledButton(
          key: const ValueKey('hr-suggest-go'),
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
          child: Text(tr("O'lchash")),
        ),
        const SizedBox(height: AppSpace.sm),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(tr('Keyinroq')),
        ),
      ]),
    );
    if (go == true) await _openHeartRate();
  }

  void _toggle() {
    final stopping = _counting;
    setState(() => _counting = !_counting);
    if (stopping && _counter.count > 0 && _heartRateOk) _suggestHeartRate();
  }

  void _reset() => setState(_counter.reset);

  @override
  void dispose() {
    _source.stop();
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(tr('Takror sanagich')),
          actions: [
            if (_heartRateOk)
              IconButton(
                key: const ValueKey('rep-heart-rate'),
                tooltip: tr('Yurak urishi'),
                icon: const Icon(Icons.favorite_outline),
                onPressed: _openHeartRate,
              ),
          ],
        ),
        body: switch (_state) {
          _CamState.starting => const Center(child: CircularProgressIndicator()),
          _CamState.denied => EmptyState(
              icon: Icons.videocam_off_outlined,
              title: tr('Kameraga ruxsat berilmagan'),
              subtitle: tr('Telefon sozlamalarida Aura Fit uchun kamerani yoqing'),
            ),
          _CamState.unavailable => EmptyState(
              icon: Icons.videocam_off_outlined,
              title: tr('Kamera ochilmadi'),
              subtitle: tr("Boshqa ilova kamerani ishlatayotgan bo'lishi mumkin"),
            ),
          _CamState.ready => _ready(context),
        },
      );

  Widget _ready(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Stack(fit: StackFit.expand, children: [
            Center(child: _source.preview()),
            if (_counting && !_visible)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Text(
                    tr("Butun tanangiz ko'rinsin"),
                    key: const ValueKey('rep-hint'),
                    style: t.titleMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${_counter.count}',
            key: const ValueKey('rep-count'),
            style: t.displayLarge,
          ),
          const SizedBox(height: AppSpace.md),
          Row(children: [
            Expanded(
              child: FilledButton(
                key: const ValueKey('rep-toggle'),
                onPressed: _toggle,
                style: FilledButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
                child: Text(_counting ? tr("To'xtatish") : tr('Boshlash')),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('rep-reset'),
                onPressed: _reset,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
                child: Text(tr('Nolga qaytarish')),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }
}
