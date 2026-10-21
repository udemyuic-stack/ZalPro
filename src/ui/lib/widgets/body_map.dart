import 'package:flutter/material.dart';
import '../theme.dart';
import 'body_parts_data.dart';

/// Qismli tana chizmasi (old yoki orqa tomon): har mushak — alohida ko'pburchak, bosilsa
/// [onTap] ga guruh id'si beriladi (`lib/models/exercises.dart` dagi [Muscle.id]).
/// Rasm fayli yo'q — vektor: 200×440 shartli o'lchamda chiziladi va kerakli balandlikka
/// kattalashtiriladi, shuning uchun har o'lchamda tiniq.
/// Shakllar `body_parts_data.dart` da (react-body-highlighter chizmasidan, MIT).
class BodyMap extends StatelessWidget {
  final bool back;

  /// Asosiy ajratilgan mushak (to'q rang)
  final String? primary;

  /// Yordamchi mushaklar (xiraroq rang)
  final Set<String> secondary;

  /// Ishlagan mushaklar darajasi: 1 — xira, 2 — to'q
  final Map<String, int> worked;
  final ValueChanged<String>? onTap;
  final double height;
  final Color? accent;

  const BodyMap({
    super.key,
    this.back = false,
    this.primary,
    this.secondary = const {},
    this.worked = const {},
    this.onTap,
    this.height = 360,
    this.accent,
  });

  static const _w = 200.0, _h = 440.0;

  /// Shu tomonda bosiladigan mushak guruhlari
  static Set<String> musclesOn({required bool back}) => {
        for (final s in _shapes(back))
          if (s.muscle != null) s.muscle!,
      };

  /// [muscle] qaysi tomonda yaxshiroq ko'rinadi: true — orqa (u yerda maydoni sezilarli
  /// kattaroq). Masalan qo'l orqasi (triceps) old tomonda ham bor, lekin ingichka bo'lak;
  /// yelka ikkala tomonda deyarli teng — old tomon tanlanadi.
  static bool backIsBetter(String muscle) => _area(muscle, true) > _area(muscle, false) * 1.3;

  static double _area(String muscle, bool back) {
    var sum = 0.0;
    for (final s in _shapes(back)) {
      if (s.muscle != muscle) continue;
      final b = s.path.getBounds();
      sum += b.width * b.height;
    }
    return sum;
  }

  /// Nuqta ([x], [y] — 200×440 o'lchamda) qaysi mushakka tushadi
  static String? hit({required bool back, required double x, required double y}) {
    for (final s in _shapes(back)) {
      if (s.muscle != null && s.path.contains(Offset(x, y))) return s.muscle;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final width = height * _w / _h;
    final paint = CustomPaint(
      size: Size(width, height),
      painter: _BodyPainter(
        back: back,
        primary: primary,
        secondary: secondary,
        worked: worked,
        accent: accent ?? AppColors.accent,
      ),
    );
    if (onTap == null) return paint;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        final k = _h / height;
        final m = hit(back: back, x: d.localPosition.dx * k, y: d.localPosition.dy * k);
        if (m != null) onTap!(m);
      },
      child: paint,
    );
  }
}

class _Shape {
  /// null — mushak emas (bosh, bo'yin, tizza)
  final String? muscle;
  final Path path;
  const _Shape(this.muscle, this.path);
}

final _cache = <bool, List<_Shape>>{};

/// Old tomon chizmasi orqadagidan kaltaroq chizilgan (oyoq panjasi yo'q) — pastga
/// suriladi, ikkala shakl yonma-yon turganda bir tekisda ko'rinsin
const _frontShift = 24.0;

List<_Shape> _shapes(bool back) => _cache.putIfAbsent(back, () {
      final dy = back ? 0.0 : _frontShift;
      return [
        for (final (muscle, p) in back ? bodyPartsBack : bodyPartsFront)
          _Shape(
            muscle.isEmpty ? null : muscle,
            Path()
              ..addPolygon([
                for (var i = 0; i + 1 < p.length; i += 2) Offset(p[i], p[i + 1] + dy),
              ], true),
          ),
      ];
    });

class _BodyPainter extends CustomPainter {
  final bool back;
  final String? primary;
  final Set<String> secondary;
  final Map<String, int> worked;
  final Color accent;
  _BodyPainter({
    required this.back,
    required this.primary,
    required this.secondary,
    required this.worked,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / BodyMap._w, size.height / BodyMap._h);
    const base = Color(0xFF1E1E1E), muscle = Color(0xFF343434);
    for (final s in _shapes(back)) {
      final Color fill;
      if (s.muscle == null) {
        fill = base;
      } else if (s.muscle == primary || worked[s.muscle] == 2) {
        fill = accent;
      } else if (secondary.contains(s.muscle) || worked[s.muscle] == 1) {
        fill = Color.lerp(muscle, accent, 0.45)!;
      } else {
        fill = muscle;
      }
      canvas.drawPath(s.path, Paint()..color = fill);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.back != back ||
      old.primary != primary ||
      old.accent != accent ||
      old.secondary.length != secondary.length ||
      !old.secondary.containsAll(secondary) ||
      !_sameLevels(old.worked, worked);

  static bool _sameLevels(Map<String, int> a, Map<String, int> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}
