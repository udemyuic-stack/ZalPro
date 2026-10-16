import 'package:flutter/material.dart';

/// Suv belgisi — [child] ustida, ekran o'rtasida juda xira rasm (`assets/brand/suv_belgisi.png`).
/// Shaffof PNG matn rangiga bo'yaladi — qorong'i va yorug' rejimda ham ko'rinadi.
/// Bosish va aylantirishga xalaqit bermaydi.
///
/// 7-okt 2026 gacha ustida shogird ismi va telefoni ham takrorlanib turardi — zal egasi
/// olib tashlatdi (skrinshot endi `ScreenGuard` bilan bloklanadi).
class Watermark extends StatelessWidget {
  final Widget child;
  const Watermark({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Stack(children: [
      child,
      Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.86,
              child: Image.asset(
                'assets/brand/suv_belgisi.png',
                fit: BoxFit.contain,
                color: onSurface.withValues(alpha: 0.10),
                colorBlendMode: BlendMode.srcIn,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
