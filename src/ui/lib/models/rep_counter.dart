import 'dart:math' as math;
import 'package:flutter/foundation.dart';

const repDownAngle = 100.0;
const repUpAngle = 160.0;
const repMinLikelihood = 0.5;
const repSmoothing = 3;

bool repCounterSupported({required bool isWeb, required TargetPlatform platform}) =>
    !isWeb && platform == TargetPlatform.android;

class Joint {
  final double x;
  final double y;
  final double likelihood;
  const Joint(this.x, this.y, this.likelihood);
}

typedef Leg = (Joint hip, Joint knee, Joint ankle);

double _legLikelihood(Leg leg) =>
    math.min(leg.$1.likelihood, math.min(leg.$2.likelihood, leg.$3.likelihood));

double? kneeAngle(Leg leg) {
  if (_legLikelihood(leg) < repMinLikelihood) return null;
  final ax = leg.$1.x - leg.$2.x;
  final ay = leg.$1.y - leg.$2.y;
  final bx = leg.$3.x - leg.$2.x;
  final by = leg.$3.y - leg.$2.y;
  final la = math.sqrt(ax * ax + ay * ay);
  final lb = math.sqrt(bx * bx + by * by);
  if (la == 0 || lb == 0) return null;
  final cos = ((ax * bx + ay * by) / (la * lb)).clamp(-1.0, 1.0);
  return math.acos(cos) * 180 / math.pi;
}

double? bestKneeAngle(Leg left, Leg right) {
  final better = _legLikelihood(left) >= _legLikelihood(right) ? left : right;
  return kneeAngle(better);
}

class RepCounter {
  final List<double> _window = [];
  int _count = 0;
  bool _down = false;

  int get count => _count;
  bool get isDown => _down;

  void add(double? angle) {
    if (angle == null) return;
    _window.add(angle);
    if (_window.length > repSmoothing) _window.removeAt(0);
    final smooth = _window.reduce((a, b) => a + b) / _window.length;
    if (!_down && smooth <= repDownAngle) {
      _down = true;
    } else if (_down && smooth >= repUpAngle) {
      _down = false;
      _count++;
    }
  }

  void reset() {
    _window.clear();
    _count = 0;
    _down = false;
  }
}
