import 'package:flutter/material.dart';
import '../theme.dart';
import 'ui.dart';

class ShimmerBar extends StatefulWidget {
  final double value;
  final Color color;
  final double height;
  const ShimmerBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 10,
  });

  @override
  State<ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<ShimmerBar> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _sweep.forward();
      });
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        height: widget.height,
        child: Stack(fit: StackFit.expand, children: [
          ColoredBox(color: AppColors.cardHigh),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: target),
            duration: motion(context, 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: v,
                child: Stack(fit: StackFit.expand, children: [
                  ColoredBox(color: widget.color),
                  AnimatedBuilder(
                    animation: _sweep,
                    builder: (context, _) => FractionallySizedBox(
                      alignment: Alignment(-1 + 3 * _sweep.value, 0),
                      widthFactor: 0.4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.35),
                            Colors.white.withValues(alpha: 0),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class Breathe extends StatefulWidget {
  final Widget child;
  const Breathe({super.key, required this.child});

  @override
  State<Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<Breathe> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: Tween(begin: 1.0, end: 1.05).animate(
          CurvedAnimation(parent: _c, curve: Curves.easeInOut),
        ),
        child: widget.child,
      );
}
