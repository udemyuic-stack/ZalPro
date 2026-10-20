import 'package:flutter/material.dart';
import '../models/game.dart';
import '../theme.dart';

const heroBodyAsset = 'assets/game/hero_body.png';
const heroAspect = 592 / 1499;
const _growthPerLevel = 0.05;

class _Region {
  final Rect rect;
  final Color Function() color;
  final int Function(MuscleLevels) level;
  const _Region(this.rect, this.color, this.level);
}

final _regions = <_Region>[
  _Region(const Rect.fromLTRB(0.25, 0.16, 0.75, 0.30), () => AppColors.coral, (m) => m.chest),
  _Region(const Rect.fromLTRB(0.0, 0.16, 0.29, 0.56), () => AppColors.sky, (m) => m.arms),
  _Region(const Rect.fromLTRB(0.71, 0.16, 1.0, 0.56), () => AppColors.sky, (m) => m.arms),
  _Region(const Rect.fromLTRB(0.05, 0.56, 0.95, 1.0), () => AppColors.mint, (m) => m.legs),
];

class _RectClipper extends CustomClipper<Rect> {
  final Rect fraction;
  const _RectClipper(this.fraction);

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
        fraction.left * size.width,
        fraction.top * size.height,
        fraction.right * size.width,
        fraction.bottom * size.height,
      );

  @override
  bool shouldReclip(covariant _RectClipper old) => old.fraction != fraction;
}

Rect _grown(Rect r, double scale) {
  final c = r.center;
  final w = r.width * scale;
  final h = r.height * scale;
  return Rect.fromCenter(center: c, width: w, height: h);
}

class HeroBody extends StatelessWidget {
  final MuscleLevels muscles;
  final double height;
  final int ms;
  const HeroBody({super.key, required this.muscles, this.height = 360, this.ms = 600});

  @override
  Widget build(BuildContext context) {
    final width = height * heroAspect;
    final image = Image.asset(
      heroBodyAsset,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => SizedBox(
        width: width,
        height: height,
        child: Icon(Icons.accessibility_new_outlined, size: height / 2, color: AppColors.textFaint),
      ),
    );
    final duration = MediaQuery.maybeDisableAnimationsOf(context) == true
        ? Duration.zero
        : Duration(milliseconds: ms);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(children: [
        image,
        for (final region in _regions)
          TweenAnimationBuilder<double>(
            tween: Tween(end: region.level(muscles).toDouble()),
            duration: duration,
            curve: Curves.easeOutBack,
            builder: (context, level, _) {
              if (level <= 0.01) return const SizedBox.shrink();
              final scale = 1 + _growthPerLevel * level;
              final grown = _grown(region.rect, scale);
              final glow = region.color();
              return Positioned.fill(
                child: ClipRect(
                  clipper: _RectClipper(grown),
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment(
                      region.rect.center.dx * 2 - 1,
                      region.rect.center.dy * 2 - 1,
                    ),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        glow.withValues(alpha: (0.035 * level).clamp(0.0, 0.14)),
                        BlendMode.srcATop,
                      ),
                      child: image,
                    ),
                  ),
                ),
              );
            },
          ),
      ]),
    );
  }
}
