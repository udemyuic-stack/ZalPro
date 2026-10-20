import 'package:flutter/material.dart';
import '../models/pose_frame.dart';
import '../models/position_check.dart';
import '../theme.dart';

class PoseOverlay extends StatelessWidget {
  final PoseFrame? frame;
  final PositionCheck check;
  final bool mirror;
  const PoseOverlay({
    super.key,
    required this.frame,
    required this.check,
    this.mirror = true,
  });

  @override
  Widget build(BuildContext context) {
    final f = frame;
    if (f == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _PosePainter(
          frame: f,
          bad: check.bad,
          good: AppColors.mint,
          warn: AppColors.coral,
          mirror: mirror,
        ),
      ),
    );
  }
}

class _PosePainter extends CustomPainter {
  final PoseFrame frame;
  final Set<PoseKey> bad;
  final Color good;
  final Color warn;
  final bool mirror;
  _PosePainter({
    required this.frame,
    required this.bad,
    required this.good,
    required this.warn,
    required this.mirror,
  });

  Offset? _map(PoseKey key, Size size) {
    if (!frame.sees(key) || frame.width <= 0 || frame.height <= 0) return null;
    final j = frame.at(key)!;
    final nx = (j.x / frame.width).clamp(0.0, 1.0);
    final ny = (j.y / frame.height).clamp(0.0, 1.0);
    return Offset((mirror ? 1 - nx : nx) * size.width, ny * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in poseBones) {
      final pa = _map(a, size);
      final pb = _map(b, size);
      if (pa == null || pb == null) continue;
      line.color = (bad.contains(a) || bad.contains(b) ? warn : good).withValues(alpha: 0.85);
      canvas.drawLine(pa, pb, line);
    }
    final dot = Paint();
    for (final key in PoseKey.values) {
      final p = _map(key, size);
      if (p == null) continue;
      dot.color = bad.contains(key) ? warn : good;
      canvas.drawCircle(p, 5, dot);
    }
  }

  @override
  bool shouldRepaint(_PosePainter old) =>
      old.frame != frame || old.bad != bad || old.mirror != mirror;
}
