import 'pose_frame.dart';
import 'rep_counter.dart';

const positionHold = Duration(seconds: 2);
const positionGrace = Duration(milliseconds: 300);
const positionStraightAngle = 160.0;
const positionEdgeMargin = 0.03;

enum PositionItemKind { visible, inFrame, order, armsStraight, legsStraight, plank }

enum PositionState { searching, adjusting, ready }

class PositionItem {
  final PositionItemKind kind;
  final bool ok;
  final double? value;
  const PositionItem(this.kind, this.ok, [this.value]);
}

class PositionCheck {
  final List<PositionItem> items;
  final PositionState state;
  final Set<PoseKey> bad;
  const PositionCheck(this.items, this.state, this.bad);

  static const empty = PositionCheck([], PositionState.searching, {});

  PositionItem? item(PositionItemKind kind) {
    for (final i in items) {
      if (i.kind == kind) return i;
    }
    return null;
  }
}

const _armKeys = [
  PoseKey.leftShoulder,
  PoseKey.rightShoulder,
  PoseKey.leftElbow,
  PoseKey.rightElbow,
  PoseKey.leftWrist,
  PoseKey.rightWrist,
];

const _legKeys = [
  PoseKey.leftHip,
  PoseKey.rightHip,
  PoseKey.leftKnee,
  PoseKey.rightKnee,
  PoseKey.leftAnkle,
  PoseKey.rightAnkle,
];

double? _angle(PoseFrame f, PoseKey a, PoseKey b, PoseKey c) {
  final ja = f.at(a);
  final jb = f.at(b);
  final jc = f.at(c);
  if (ja == null || jb == null || jc == null) return null;
  return kneeAngle((ja, jb, jc));
}

double? _mean(List<double?> values) {
  final present = values.whereType<double>().toList();
  if (present.length != values.length || present.isEmpty) return null;
  return present.reduce((a, b) => a + b) / present.length;
}

bool _inside(PoseFrame f, PoseKey key) {
  final j = f.at(key);
  if (j == null || f.width <= 0 || f.height <= 0) return false;
  final mx = f.width * positionEdgeMargin;
  final my = f.height * positionEdgeMargin;
  return j.x >= mx && j.x <= f.width - mx && j.y >= my && j.y <= f.height - my;
}

PositionCheck evaluatePosition(String exercise, PoseFrame? frame) {
  if (frame == null) return PositionCheck.empty;
  final keys = exercise == 'squat' ? _legKeys : _armKeys;
  final missing = keys.where((k) => !frame.sees(k)).toSet();
  if (missing.isNotEmpty) {
    return PositionCheck(
      [const PositionItem(PositionItemKind.visible, false)],
      PositionState.searching,
      missing,
    );
  }
  final items = <PositionItem>[const PositionItem(PositionItemKind.visible, true)];
  final bad = <PoseKey>{};

  final outside = keys.where((k) => !_inside(frame, k)).toSet();
  bad.addAll(outside);
  items.add(PositionItem(PositionItemKind.inFrame, outside.isEmpty));

  if (exercise == 'squat') {
    final knee = _mean([
      _angle(frame, PoseKey.leftHip, PoseKey.leftKnee, PoseKey.leftAnkle),
      _angle(frame, PoseKey.rightHip, PoseKey.rightKnee, PoseKey.rightAnkle),
    ]);
    final ok = knee != null && knee >= positionStraightAngle;
    if (!ok) bad.addAll([PoseKey.leftKnee, PoseKey.rightKnee]);
    items.add(PositionItem(PositionItemKind.legsStraight, ok, knee));
  } else {
    final arm = _mean([
      _angle(frame, PoseKey.leftShoulder, PoseKey.leftElbow, PoseKey.leftWrist),
      _angle(frame, PoseKey.rightShoulder, PoseKey.rightElbow, PoseKey.rightWrist),
    ]);
    final armOk = arm != null && arm >= positionStraightAngle;
    if (!armOk) bad.addAll([PoseKey.leftElbow, PoseKey.rightElbow]);
    items.add(PositionItem(PositionItemKind.armsStraight, armOk, arm));

    if (exercise == 'pushup') {
      final orderOk = _handsBelow(frame);
      if (!orderOk) bad.addAll([PoseKey.leftWrist, PoseKey.rightWrist]);
      items.add(PositionItem(PositionItemKind.order, orderOk));
      final plank = _plank(frame);
      if (plank != null) {
        final ok = plank >= positionStraightAngle;
        if (!ok) bad.addAll([PoseKey.leftHip, PoseKey.rightHip]);
        items.add(PositionItem(PositionItemKind.plank, ok, plank));
      }
    }
  }

  final allOk = items.every((i) => i.ok);
  return PositionCheck(
    items,
    allOk ? PositionState.ready : PositionState.adjusting,
    bad,
  );
}

bool _handsBelow(PoseFrame f) {
  double y(PoseKey a, PoseKey b) => (f.at(a)!.y + f.at(b)!.y) / 2;
  final wrist = y(PoseKey.leftWrist, PoseKey.rightWrist);
  final elbow = y(PoseKey.leftElbow, PoseKey.rightElbow);
  final shoulder = y(PoseKey.leftShoulder, PoseKey.rightShoulder);
  return wrist > elbow && elbow > shoulder;
}

double? _plank(PoseFrame f) {
  for (final k in [
    PoseKey.leftHip,
    PoseKey.rightHip,
    PoseKey.leftAnkle,
    PoseKey.rightAnkle,
  ]) {
    if (!f.sees(k)) return null;
  }
  return _mean([
    _angle(f, PoseKey.leftShoulder, PoseKey.leftHip, PoseKey.leftAnkle),
    _angle(f, PoseKey.rightShoulder, PoseKey.rightHip, PoseKey.rightAnkle),
  ]);
}

class PositionHold {
  Duration? _since;
  Duration? _lastReady;
  bool _locked = false;

  bool get locked => _locked;

  double progress(Duration now) {
    final since = _since;
    if (_locked) return 1;
    if (since == null) return 0;
    return ((now - since).inMilliseconds / positionHold.inMilliseconds).clamp(0.0, 1.0);
  }

  bool update(bool ready, Duration now) {
    if (_locked) return true;
    if (ready) {
      _since ??= now;
      _lastReady = now;
      if (now - _since! >= positionHold) _locked = true;
    } else {
      final last = _lastReady;
      if (last == null || now - last > positionGrace) {
        _since = null;
        _lastReady = null;
      }
    }
    return _locked;
  }

  void reset() {
    _since = null;
    _lastReady = null;
    _locked = false;
  }
}
