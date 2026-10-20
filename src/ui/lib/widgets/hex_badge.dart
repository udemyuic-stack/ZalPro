import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

class _HexClipper extends CustomClipper<Path> {
  const _HexClipper();

  @override
  Path getClip(Size size) => hexPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

Path hexPath(Size size) {
  final c = Offset(size.width / 2, size.height / 2);
  final r = math.min(size.width, size.height) / 2;
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final a = math.pi / 3 * i - math.pi / 2;
    final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}

class _HexBorder extends CustomPainter {
  final Color color;
  final double width;
  final bool glow;
  const _HexBorder(this.color, this.width, this.glow);

  @override
  void paint(Canvas canvas, Size size) {
    final path = hexPath(size);
    if (glow) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 2.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HexBorder old) =>
      old.color != color || old.width != width || old.glow != glow;
}

String badgeAsset(String exercise) => switch (exercise) {
      'pullup' => 'assets/game/badge_pullup.png',
      'pushup' => 'assets/game/badge_pushup.png',
      'squat' => 'assets/game/badge_squat.png',
      _ => 'assets/game/badge_locked.png',
    };

class HexBadge extends StatelessWidget {
  final String exercise;
  final bool locked;
  final bool done;
  final double size;
  const HexBadge({
    super.key,
    required this.exercise,
    this.locked = false,
    this.done = false,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    final color = locked ? AppColors.textFaint : (done ? AppColors.gold : AppColors.violet);
    final image = Image.asset(
      locked ? badgeAsset('') : badgeAsset(exercise),
      fit: BoxFit.cover,
      width: size,
      height: size,
      errorBuilder: (_, __, ___) => Icon(Icons.fitness_center_outlined, color: color),
    );
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        foregroundPainter: _HexBorder(color, size / 28, !locked),
        child: ClipPath(
          clipper: const _HexClipper(),
          child: Opacity(opacity: locked ? 0.7 : 1, child: image),
        ),
      ),
    );
  }
}
