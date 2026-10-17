import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/tr.dart';
import '../theme.dart';

const restTimerChoices = [60, 90, 120];
const restTimerDefault = 90;
const restTimerKey = 'rest_timer_seconds';

Stream<void> _secondTicker() => Stream<void>.periodic(const Duration(seconds: 1));

class RestTimerController extends ChangeNotifier {
  RestTimerController({
    this.onFinished,
    this.onStarted,
    this.onStopped,
    Stream<void> Function()? ticker,
    DateTime Function()? clock,
  })  : _ticker = ticker ?? _secondTicker,
        _clock = clock ?? DateTime.now;

  final Stream<void> Function() _ticker;
  final DateTime Function() _clock;
  final VoidCallback? onFinished;
  final void Function(DateTime endsAt)? onStarted;
  final VoidCallback? onStopped;

  StreamSubscription<void>? _sub;
  Duration _total = Duration.zero;
  Duration _remaining = Duration.zero;
  DateTime _endsAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _running = false;

  Duration get total => _total;
  Duration get remaining => _remaining;
  bool get running => _running;

  double get progress =>
      _total.inMilliseconds == 0 ? 0 : _remaining.inMilliseconds / _total.inMilliseconds;

  void start(Duration duration) {
    _sub?.cancel();
    _sub = null;
    final wasRunning = _running;
    _total = duration;
    _remaining = duration;
    _running = duration > Duration.zero;
    if (_running) {
      _endsAt = _clock().add(duration);
      _sub = _ticker().listen((_) => refresh());
      onStarted?.call(_endsAt);
    } else if (wasRunning) {
      onStopped?.call();
    }
    notifyListeners();
  }

  void refresh() {
    if (!_running) return;
    final left = _endsAt.difference(_clock());
    if (left > Duration.zero) {
      _remaining = left;
      notifyListeners();
      return;
    }
    _remaining = Duration.zero;
    _running = false;
    _sub?.cancel();
    _sub = null;
    notifyListeners();
    onStopped?.call();
    onFinished?.call();
  }

  void skip() {
    if (!_running) return;
    _sub?.cancel();
    _sub = null;
    _running = false;
    _remaining = Duration.zero;
    onStopped?.call();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    if (_running) {
      _running = false;
      onStopped?.call();
    }
    super.dispose();
  }
}

class RestTimerPrefs {
  static String _key(String? exerciseKey) =>
      exerciseKey == null ? restTimerKey : '${restTimerKey}_$exerciseKey';

  static Future<int> load([String? exerciseKey]) async {
    try {
      final p = await SharedPreferences.getInstance();
      final own = exerciseKey == null ? null : p.getInt(_key(exerciseKey));
      if (restTimerChoices.contains(own)) return own!;
      final v = p.getInt(restTimerKey);
      return restTimerChoices.contains(v) ? v! : restTimerDefault;
    } catch (_) {
      return restTimerDefault;
    }
  }

  static Future<void> save(int seconds, [String? exerciseKey]) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(restTimerKey, seconds);
      if (exerciseKey != null) await p.setInt(_key(exerciseKey), seconds);
    } catch (_) {
      return;
    }
  }
}

void restTimerAlert() {
  HapticFeedback.heavyImpact();
  SystemSound.play(SystemSoundType.alert);
}

String formatRest(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final m = (s ~/ 60).toString().padLeft(2, '0');
  final r = (s % 60).toString().padLeft(2, '0');
  return '$m:$r';
}

class RestTimerBar extends StatelessWidget {
  final RestTimerController controller;
  final String? exerciseKey;
  const RestTimerBar({super.key, required this.controller, this.exerciseKey});

  Future<void> _pick(int seconds) async {
    controller.start(Duration(seconds: seconds));
    await RestTimerPrefs.save(seconds, exerciseKey);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Container(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border(top: BorderSide(color: AppColors.hairlineStrong)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    tr('Dam olish'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    formatRest(controller.remaining),
                    key: const ValueKey('rest-remaining'),
                    style: TextStyle(
                      fontSize: 34,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      fontFeatures: tabular,
                      color: AppColors.text,
                    ),
                  ),
                ]),
              ),
              TextButton(
                onPressed: controller.skip,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentText,
                  minimumSize: const Size(0, kTouchTarget),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                child: Text(tr("O'tkazib yuborish")),
              ),
            ]),
            const SizedBox(height: AppSpace.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: controller.progress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: AppColors.hairline,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Row(children: [
              for (final s in restTimerChoices) ...[
                if (s != restTimerChoices.first) const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: _Chip(
                    seconds: s,
                    selected: controller.total.inSeconds == s,
                    onTap: () => _pick(s),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      );
}

class _Chip extends StatelessWidget {
  final int seconds;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.seconds, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.accentFill : AppColors.cardHigh,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kTouchTarget),
              child: Center(
                child: Text(
                  trf('{0} s', [seconds]),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.onAccentFill : AppColors.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
