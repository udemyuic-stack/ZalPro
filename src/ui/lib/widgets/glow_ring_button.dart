import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import 'ui.dart';

class GlowRingButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  const GlowRingButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<GlowRingButton> createState() => _GlowRingButtonState();
}

class _GlowRingButtonState extends State<GlowRingButton> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce || widget.onPressed == null) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void didUpdateWidget(GlowRingButton old) {
    super.didUpdateWidget(old);
    if (widget.onPressed == null) {
      _spin.stop();
    } else if (!_spin.isAnimating && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const radius = AppRadius.md;
    return Pressable(
      enabled: widget.onPressed != null,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _RingPainter(
            turn: _spin,
            from: AppColors.violet,
            to: AppColors.mint,
            radius: radius + 3,
            active: widget.onPressed != null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.onPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, kTouchTarget),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
                ),
                icon: Icon(widget.icon),
                label: Text(widget.label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Animation<double> turn;
  final Color from;
  final Color to;
  final double radius;
  final bool active;
  _RingPainter({
    required this.turn,
    required this.from,
    required this.to,
    required this.radius,
    required this.active,
  }) : super(repaint: turn);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1.5),
      Radius.circular(radius),
    );
    final angle = turn.value * 2 * math.pi;
    final shader = SweepGradient(
      colors: [
        from.withValues(alpha: 0.0),
        from,
        to,
        to.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.25, 0.5, 0.75],
      transform: GradientRotation(angle),
    ).createShader(Offset.zero & size);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..shader = shader;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = shader;
    if (active) canvas.drawRRect(rect, glow);
    canvas.drawRRect(rect, line);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.from != from || old.to != to || old.radius != radius || old.active != active;
}
