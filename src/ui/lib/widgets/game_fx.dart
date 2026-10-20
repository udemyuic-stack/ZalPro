import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import 'ui.dart';

const _maxParticles = 60;

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final double spin;
  final Color color;
  const _Particle(this.angle, this.speed, this.size, this.spin, this.color);
}

List<_Particle> _makeParticles(int count, List<Color> colors, int seed) {
  final rnd = math.Random(seed);
  final n = count.clamp(0, _maxParticles);
  return List.generate(
    n,
    (i) => _Particle(
      rnd.nextDouble() * math.pi * 2,
      0.45 + rnd.nextDouble() * 0.55,
      3 + rnd.nextDouble() * 4,
      (rnd.nextDouble() - 0.5) * 8,
      colors[i % colors.length],
    ),
  );
}

class Burst extends StatefulWidget {
  final List<Color>? colors;
  final int count;
  final int ms;
  final double radius;
  final int seed;
  final VoidCallback? onDone;
  const Burst({
    super.key,
    this.colors,
    this.count = 36,
    this.ms = 1200,
    this.radius = 140,
    this.seed = 7,
    this.onDone,
  });

  @override
  State<Burst> createState() => _BurstState();
}

class _BurstState extends State<Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  late List<_Particle> _particles;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _particles = const [];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final colors = widget.colors ??
        [AppColors.gold, AppColors.violet, AppColors.sky, AppColors.mint, AppColors.coral];
    final d = motion(context, widget.ms);
    if (d == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone?.call());
      return;
    }
    _particles = _makeParticles(widget.count, colors, widget.seed);
    _c.duration = d;
    _c.forward().whenComplete(() => widget.onDone?.call());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_particles.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _BurstPainter(_particles, _c.value, widget.radius),
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  final double radius;
  _BurstPainter(this.particles, this.t, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final out = Curves.easeOutCubic.transform(t);
    final fade = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
    final paint = Paint();
    for (final p in particles) {
      final dist = radius * p.speed * out;
      final pos = c +
          Offset(math.cos(p.angle) * dist, math.sin(p.angle) * dist + 60 * t * t);
      paint.color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size * 1.6, height: p.size),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

class GlowRing extends StatelessWidget {
  final double progress;
  final double size;
  final double stroke;
  final Color? color;
  final Color? trackColor;
  final Widget? child;
  final int ms;
  const GlowRing({
    super.key,
    required this.progress,
    this.size = 96,
    this.stroke = 8,
    this.color,
    this.trackColor,
    this.child,
    this.ms = 800,
  });

  @override
  Widget build(BuildContext context) {
    final target = progress.clamp(0.0, 1.0);
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: motion(context, ms),
        curve: Curves.easeOutCubic,
        builder: (context, v, c) => CustomPaint(
          size: Size.square(size),
          painter: _RingPainter(
            v,
            stroke,
            color ?? AppColors.violet,
            trackColor ?? AppColors.textFaint.withValues(alpha: 0.2),
          ),
          child: SizedBox(width: size, height: size, child: Center(child: c)),
        ),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final double stroke;
  final Color color;
  final Color track;
  _RingPainter(this.v, this.stroke, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(stroke / 2 + 2);
    canvas.drawArc(
      inset,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (v <= 0) return;
    final sweep = math.pi * 2 * v;
    final shader = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + math.pi * 2,
      colors: [color.withValues(alpha: 0.55), color],
      transform: const GradientRotation(0),
    ).createShader(inset);
    canvas.drawArc(
      inset,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 6
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawArc(
      inset,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
    final a = -math.pi / 2 + sweep;
    final tip = inset.center + Offset(math.cos(a), math.sin(a)) * (inset.width / 2);
    canvas.drawCircle(tip, stroke / 2 + 1, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.v != v || old.color != color || old.track != track || old.stroke != stroke;
}

class FlyingCoin extends StatefulWidget {
  final Offset delta;
  final int ms;
  final double size;
  final VoidCallback? onDone;
  const FlyingCoin({
    super.key,
    required this.delta,
    this.ms = 700,
    this.size = 24,
    this.onDone,
  });

  @override
  State<FlyingCoin> createState() => _FlyingCoinState();
}

class _FlyingCoinState extends State<FlyingCoin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;
  bool _skip = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final d = motion(context, widget.ms);
    if (d == Duration.zero) {
      _skip = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone?.call());
      return;
    }
    _c.duration = d;
    _c.forward().whenComplete(() => widget.onDone?.call());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_skip) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_c.value);
          final arc = math.sin(t * math.pi) * -48;
          final scale = 1.0 - 0.45 * t;
          final opacity = _c.value < 0.85 ? 1.0 : (1 - _c.value) / 0.15;
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(widget.delta.dx * t, widget.delta.dy * t + arc),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.gold, AppColors.gold.withValues(alpha: 0.7)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(Icons.toll_outlined, size: widget.size * 0.62, color: Colors.white),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
