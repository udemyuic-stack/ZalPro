import 'dart:math' as math;
import 'package:flutter/foundation.dart';

const hrWarmupMs = 10000;
const hrWindowMs = 20000;
const hrTotalMs = hrWarmupMs + hrWindowMs;
const hrMinBpm = 42;
const hrMaxBpm = 210;
const hrSampleRate = 30;
const hrMinFingerRed = 100.0;
const hrMinAmplitude = 0.05;
const hrMinPeakGapSec = 0.3;
const hrMaxIntervalVariation = 0.2;
const hrMinPeaks = 5;
const hrMinSpanMs = 8000;

bool heartRateSupported({required bool isWeb, required TargetPlatform platform}) =>
    !isWeb && platform == TargetPlatform.android;

enum HrQuality { noFinger, unstable, good }

class HeartRateResult {
  final int? bpm;
  final HrQuality quality;
  const HeartRateResult(this.bpm, this.quality);
}

class HeartRateEstimator {
  final List<int> _times = [];
  final List<double> _values = [];

  int get count => _times.length;

  int get elapsedMs => _times.isEmpty ? 0 : _times.last - _times.first;

  bool get warmingUp => elapsedMs < hrWarmupMs;

  bool get complete => elapsedMs >= hrTotalMs;

  double get progress => ((elapsedMs - hrWarmupMs) / hrWindowMs).clamp(0.0, 1.0);

  void add(int timeMs, double red) {
    if (_times.isNotEmpty && timeMs <= _times.last) return;
    _times.add(timeMs);
    _values.add(red);
  }

  void reset() {
    _times.clear();
    _values.clear();
  }

  HeartRateResult estimate() {
    if (_times.isEmpty) return const HeartRateResult(null, HrQuality.noFinger);
    final start = _times.first + hrWarmupMs;
    final end = math.min(_times.last, start + hrWindowMs);
    final ts = <int>[];
    final vs = <double>[];
    for (var i = 0; i < _times.length; i++) {
      if (_times[i] >= start && _times[i] <= end) {
        ts.add(_times[i]);
        vs.add(_values[i]);
      }
    }
    if (ts.length < 2 || ts.last - ts.first < hrMinSpanMs) {
      return const HeartRateResult(null, HrQuality.unstable);
    }
    final x = _resample(ts, vs);
    if (_mean(x) < hrMinFingerRed) return const HeartRateResult(null, HrQuality.noFinger);
    final trimmed = _lowPass(_detrend(x)).sublist(hrSampleRate, x.length - hrSampleRate);
    final sd = _std(trimmed);
    if (sd < hrMinAmplitude) return const HeartRateResult(null, HrQuality.noFinger);

    final peaks = _peaks(trimmed, sd);
    if (peaks.length < hrMinPeaks) return const HeartRateResult(null, HrQuality.unstable);
    final intervals = [
      for (var i = 1; i < peaks.length; i++) (peaks[i] - peaks[i - 1]) / hrSampleRate,
    ];
    final sorted = [...intervals]..sort();
    final median = sorted.length.isOdd
        ? sorted[sorted.length ~/ 2]
        : (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2;
    final bpm = 60 / median;
    final variation = _std(intervals) / _mean(intervals);
    if (variation > hrMaxIntervalVariation || bpm < hrMinBpm || bpm > hrMaxBpm) {
      return const HeartRateResult(null, HrQuality.unstable);
    }
    return HeartRateResult(bpm.round(), HrQuality.good);
  }

  static double _mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;

  static double _std(List<double> v) {
    final m = _mean(v);
    var s = 0.0;
    for (final e in v) {
      s += (e - m) * (e - m);
    }
    return math.sqrt(s / v.length);
  }

  static List<double> _resample(List<int> ts, List<double> vs) {
    final out = <double>[];
    const step = 1000 / hrSampleRate;
    var j = 0;
    for (var t = ts.first.toDouble(); t <= ts.last; t += step) {
      while (j < ts.length - 2 && ts[j + 1] < t) {
        j++;
      }
      final span = ts[j + 1] - ts[j];
      final f = span > 0 ? (t - ts[j]) / span : 0.0;
      out.add(vs[j] + (vs[j + 1] - vs[j]) * f);
    }
    return out;
  }

  static List<double> _detrend(List<double> x) {
    const half = 22;
    final prefix = List<double>.filled(x.length + 1, 0);
    for (var i = 0; i < x.length; i++) {
      prefix[i + 1] = prefix[i] + x[i];
    }
    return [
      for (var i = 0; i < x.length; i++)
        x[i] -
            (prefix[math.min(x.length, i + half + 1)] - prefix[math.max(0, i - half)]) /
                (math.min(x.length, i + half + 1) - math.max(0, i - half)),
    ];
  }

  static List<double> _lowPass(List<double> x) {
    const cutoffHz = 3.5;
    final k = math.tan(math.pi * cutoffHz / hrSampleRate);
    const root2 = math.sqrt2;
    final norm = 1 / (1 + root2 * k + k * k);
    final b0 = k * k * norm;
    final b1 = 2 * b0;
    final a1 = 2 * (k * k - 1) * norm;
    final a2 = (1 - root2 * k + k * k) * norm;

    List<double> run(List<double> input) {
      final out = <double>[];
      var x1 = input.first, x2 = input.first, y1 = input.first, y2 = input.first;
      for (final v in input) {
        final y = b0 * v + b1 * x1 + b0 * x2 - a1 * y1 - a2 * y2;
        x2 = x1;
        x1 = v;
        y2 = y1;
        y1 = y;
        out.add(y);
      }
      return out;
    }

    return run(run(x).reversed.toList()).reversed.toList();
  }

  static List<double> _peaks(List<double> f, double sd) {
    final idx = <int>[];
    final pos = <double>[];
    for (var i = 1; i < f.length - 1; i++) {
      if (f[i] > f[i - 1] && f[i] >= f[i + 1] && f[i] > 0.3 * sd) {
        if (idx.isNotEmpty && i - idx.last < hrMinPeakGapSec * hrSampleRate) {
          if (f[i] <= f[idx.last]) continue;
          idx.removeLast();
          pos.removeLast();
        }
        final d = f[i - 1] - 2 * f[i] + f[i + 1];
        idx.add(i);
        pos.add(i + (d == 0 ? 0 : 0.5 * (f[i - 1] - f[i + 1]) / d));
      }
    }
    return pos;
  }
}
