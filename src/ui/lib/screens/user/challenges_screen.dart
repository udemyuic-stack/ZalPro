import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/game.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/game_widgets.dart';
import '../../widgets/glow_ring_button.dart';
import '../../widgets/hero_body.dart';
import '../../widgets/hex_badge.dart';
import '../../widgets/shimmer_bar.dart';
import '../../widgets/ui.dart';
import 'rep_counter_screen.dart';

class ChallengesScreen extends StatefulWidget {
  final Stream<GameChallenges>? source;
  final VoidCallback? onStart;
  const ChallengesScreen({super.key, this.source, this.onStart});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  late final Stream<GameChallenges> _stream = widget.source ?? Db.gameChallenges();

  void _start() {
    final custom = widget.onStart;
    if (custom != null) {
      custom();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RepCounterScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr('Challenjlar'))),
        body: StreamBuilder<GameChallenges>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError && !snap.hasData) return ErrorState(error: snap.error);
            final data = snap.data;
            if (data == null) return const Center(child: CircularProgressIndicator());
            return _Body(data: data, onStart: _start);
          },
        ),
      );
}

class _Body extends StatelessWidget {
  final GameChallenges data;
  final VoidCallback onStart;
  const _Body({required this.data, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final current = data.current;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        BentoTile(
          feature: true,
          child: Center(child: HeroBody(muscles: data.muscles, height: 380)),
        ),
        const SizedBox(height: AppSpace.md),
        Row(children: [
          Expanded(
            child: StatTile(
              icon: Icons.fitness_center_outlined,
              label: tr("Qo'llar"),
              value: '${data.muscles.arms}',
              color: AppColors.sky,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: StatTile(
              icon: Icons.favorite_border,
              label: tr("Ko'krak"),
              value: '${data.muscles.chest}',
              color: AppColors.coral,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: StatTile(
              icon: Icons.directions_run_outlined,
              label: tr('Oyoqlar'),
              value: '${data.muscles.legs}',
              color: AppColors.mint,
            ),
          ),
        ]),
        const SizedBox(height: AppSpace.lg),
        if (current != null)
          _CurrentCard(step: current, progress: data.progress, onStart: onStart)
        else
          BentoTile(
            child: Row(children: [
              Icon(Icons.emoji_events_outlined, color: AppColors.gold),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(tr('Hamma challenjlar tugadi!'), style: t.titleMedium),
              ),
            ]),
          ),
        const SizedBox(height: AppSpace.lg),
        SectionHeader(tr('Challenj yo\'li')),
        for (var i = 0; i < data.steps.length; i++)
          FadeInUp(
            index: i < 6 ? i : 6,
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _Rail(
                  step: data.steps[i],
                  first: i == 0,
                  last: i == data.steps.length - 1,
                  previousDone: i > 0 && data.steps[i - 1].done,
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.sm),
                    child: _StepRow(step: data.steps[i]),
                  ),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

class _CurrentCard extends StatelessWidget {
  final ChallengeStep step;
  final int progress;
  final VoidCallback onStart;
  const _CurrentCard({required this.step, required this.progress, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fraction = step.target == 0 ? 0.0 : (progress / step.target).clamp(0.0, 1.0);
    return BentoTile(
      feature: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Breathe(child: HexBadge(exercise: step.exercise, size: 64)),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trf('{0} challenj', [step.index + 1]),
                  style: t.labelMedium?.copyWith(color: AppColors.textMuted)),
              _FocusReveal(
                child: Text(
                  trf('{0}: {1} marta', [gameExerciseName(step.exercise), step.target]),
                  style: t.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: AppSpace.md),
        ShimmerBar(value: fraction, color: AppColors.violet),
        const SizedBox(height: AppSpace.sm),
        Row(children: [
          Expanded(
            child: Text(
              trf('{0} / {1}', [progress, step.target]),
              style: t.bodyMedium?.copyWith(fontFeatures: tabular),
            ),
          ),
          Icon(Icons.toll_outlined, size: 18, color: AppColors.gold),
          const SizedBox(width: AppSpace.xs),
          Text(
            trf('+{0} coin', [step.coins]),
            style: t.bodyMedium?.copyWith(color: AppColors.gold, fontFeatures: tabular),
          ),
        ]),
        const SizedBox(height: AppSpace.md),
        GlowRingButton(
          onPressed: onStart,
          icon: Icons.play_arrow_outlined,
          label: tr('Boshlash'),
        ),
      ]),
    );
  }
}

class _StepRow extends StatelessWidget {
  final ChallengeStep step;
  const _StepRow({required this.step});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = step.locked ? AppColors.textFaint : null;
    return BentoTile(
      child: Row(children: [
        HexBadge(exercise: step.exercise, locked: step.locked, done: step.done, size: 48),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Text(
            step.locked
                ? trf('{0} challenj', [step.index + 1])
                : trf('{0}: {1} marta', [gameExerciseName(step.exercise), step.target]),
            style: t.titleMedium?.copyWith(color: muted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        if (step.done)
          Icon(Icons.check_circle_outline, color: AppColors.mint)
        else
          Text(
            trf('+{0} coin', [step.coins]),
            style: t.bodyMedium?.copyWith(color: AppColors.gold, fontFeatures: tabular),
          ),
      ]),
    );
  }
}

class _FocusReveal extends StatelessWidget {
  final Widget child;
  const _FocusReveal({required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: motion(context, 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, c) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: ImageFiltered(
            enabled: v < 1,
            imageFilter: ImageFilter.blur(sigmaX: (1 - v) * 6, sigmaY: (1 - v) * 6),
            child: c,
          ),
        ),
        child: child,
      );
}

class _Rail extends StatelessWidget {
  final ChallengeStep step;
  final bool first;
  final bool last;
  final bool previousDone;
  const _Rail({
    required this.step,
    required this.first,
    required this.last,
    required this.previousDone,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 16,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: motion(context, 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => CustomPaint(
            painter: _RailPainter(
              grow: v,
              first: first,
              last: last,
              above: previousDone,
              below: step.done,
              current: step.state == 'current',
              done: step.done,
              fill: AppColors.mint,
              track: AppColors.cardHigh,
              accent: AppColors.violet,
            ),
          ),
        ),
      );
}

class _RailPainter extends CustomPainter {
  final double grow;
  final bool first;
  final bool last;
  final bool above;
  final bool below;
  final bool current;
  final bool done;
  final Color fill;
  final Color track;
  final Color accent;
  _RailPainter({
    required this.grow,
    required this.first,
    required this.last,
    required this.above,
    required this.below,
    required this.current,
    required this.done,
    required this.fill,
    required this.track,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final mid = size.height / 2;
    final line = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    if (!first) {
      line.color = above ? fill : track;
      canvas.drawLine(Offset(x, 0), Offset(x, mid * (above ? grow : 1)), line);
    }
    if (!last) {
      line.color = below ? fill : track;
      canvas.drawLine(Offset(x, mid), Offset(x, mid + (size.height - mid) * (below ? grow : 1)), line);
    }
    final color = done ? fill : (current ? accent : track);
    canvas.drawCircle(Offset(x, mid), current ? 7 : 5, Paint()..color = color);
    if (current) {
      canvas.drawCircle(
        Offset(x, mid),
        11,
        Paint()
          ..color = accent.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.grow != grow ||
      old.above != above ||
      old.below != below ||
      old.current != current ||
      old.done != done;
}
