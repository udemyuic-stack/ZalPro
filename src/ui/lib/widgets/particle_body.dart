import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import 'body_photo_points.dart';

/// Tana mayda nuqta zarrachalardan yig'iladi: ekran ochilganda zarrachalar har tomondan
/// uchib kelib qomatni hosil qiladi ("Dala" saytidagi zarrachali shakl uslubida).
/// Qomat 8 tomondan bor (0, 45 ... 315 gradus) — [angle] o'zgarsa zarrachalar bir
/// ko'rinish so'nib, qo'shnisi paydo bo'ladi (aylanayotgandek ko'rinadi); barmoq bilan surib
/// ham aylantiriladi. Mushak tanlansa — ko'rinish o'sha joyga yaqinlashadi va shu joy yonadi.
///
/// Zarrachalar `body_photo_points.dart` dan (400×900; `tools/tana/zarrachalar.py` zal egasi
/// bergan "360 gradus" rasmidan yaratadi). Mushak joylari hamma ko'rinishda qo'lda
/// belgilangan: old va orqada aniqroq, qiya va yon ko'rinishlarda taxminiy to'rtburchaklar.
class ParticleBody extends StatefulWidget {
  /// Ko'rinish: 0 — old, 2 — o'ng yon, 4 — orqa, 6 — chap yon (har qadam 45 gradus)
  final int angle;

  /// Tanlangan mushak (null yoki shu ko'rinishda yo'q mushak — butun tana ko'rinadi)
  final String? selected;

  /// Hech narsa tanlanmaganda yonib turadigan mushaklar (bugungi mashg'ulot) —
  /// yaqinlashmaydi, faqat ajralib turadi
  final Set<String> today;

  /// Mushak bosildi; bo'sh joy bosilsa null (tanlov bekor bo'ladi)
  final ValueChanged<String?> onTap;

  /// Barmoq bilan surildi: +1 yoki -1 qadam
  final ValueChanged<int>? onRotate;
  final double width, height;

  const ParticleBody({
    super.key,
    this.angle = front,
    required this.selected,
    this.today = const {},
    required this.onTap,
    this.onRotate,
    this.width = 300,
    this.height = 540,
  });

  static const front = 0, back = 4, views = 8;

  /// Shu mushak shu ko'rinishda bormi (bosib tanlasa va yaqinlashsa bo'ladimi)
  static bool has(String muscle, {required int angle}) =>
      _regions[angle]?.containsKey(muscle) ?? false;

  /// [muscle] ko'rinadigan ko'rinish: hozirgisida bo'lsa — o'zi, bo'lmasa old yoki orqa
  static int angleFor(String muscle, int current) {
    if (has(muscle, angle: current)) return current;
    if (has(muscle, angle: front)) return front;
    if (has(muscle, angle: back)) return back;
    return current;
  }

  /// Nuqta ([x], [y] — 400×900 o'lchamda) qaysi mushakka tushadi
  static String? hit(double x, double y, {int angle = front}) {
    final regions = _regions[angle];
    if (regions == null) return null;
    for (final e in regions.entries) {
      for (final path in e.value) {
        if (path.contains(Offset(x, y))) return e.key;
      }
    }
    return null;
  }

  @override
  State<ParticleBody> createState() => _ParticleBodyState();
}

Path _poly(List<double> p) {
  final path = Path()..moveTo(p[0], p[1]);
  for (var i = 2; i + 1 < p.length; i += 2) {
    path.lineTo(p[i], p[i + 1]);
  }
  return path..close();
}

/// Juft mushak: [p] — rasmning chap tomonidagi shakl, ikkinchisi — o'rta chiziqqa
/// ([cx]) nisbatan ko'zgusi
List<Path> _pair(double cx, List<double> p) => [
      _poly(p),
      _poly([
        for (var i = 0; i < p.length; i++) i.isEven ? 2 * cx - p[i] : p[i],
      ]),
    ];

/// Mushak joylari (qo'lda belgilangan, 400×900; har shakl — x, y, x, y ... ro'yxati).
/// Tartib muhim: ustma-ust tushgan joyda birinchi topilgani olinadi (yelka va qo'l
/// ko'krakdan oldin).
final Map<int, Map<String, List<Path>>> _regions = {
  ParticleBody.front: {
    'shoulders': _pair(197, [62, 208, 74, 168, 100, 156, 114, 180, 102, 214, 70, 222]),
    'biceps': _pair(197, [56, 224, 102, 216, 102, 290, 50, 300]),
    'forearms': _pair(197, [48, 302, 100, 292, 82, 402, 26, 402]),
    'traps': _pair(197, [152, 118, 197, 128, 197, 164, 112, 160]),
    'chest': _pair(197, [110, 162, 197, 166, 197, 226, 150, 234, 110, 216]),
    'abs': [
      _poly([128, 236, 266, 236, 260, 404, 134, 404])
    ],
    'quads': _pair(197, [78, 440, 192, 440, 166, 612, 78, 612]),
    'calves': _pair(197, [60, 626, 152, 626, 142, 772, 58, 772]),
  },
  ParticleBody.back: {
    'shoulders': _pair(205, [58, 202, 70, 160, 108, 150, 114, 196, 98, 214]),
    'triceps': _pair(205, [50, 214, 102, 206, 102, 292, 46, 300]),
    'forearms': _pair(205, [38, 302, 100, 294, 82, 402, 28, 402]),
    'traps': [
      _poly([205, 100, 300, 150, 205, 232, 110, 150])
    ],
    'back': _pair(205, [112, 200, 205, 216, 205, 344, 150, 344, 118, 282]),
    'glutes': _pair(205, [100, 400, 205, 400, 205, 482, 96, 482]),
    'hamstrings': _pair(205, [82, 484, 202, 484, 166, 612, 80, 612]),
    'calves': _pair(205, [72, 622, 156, 622, 150, 762, 70, 762]),
  },
  // 45° — old-o'ng qiya
  1: {
    'shoulders': [
      _poly([250, 158, 300, 152, 330, 180, 325, 215, 255, 205]),
      _poly([105, 170, 150, 155, 150, 200, 108, 205]),
    ],
    'biceps': [
      _poly([262, 215, 345, 220, 340, 285, 265, 285]),
      _poly([95, 205, 135, 205, 120, 265, 85, 265]),
    ],
    'forearms': [
      _poly([250, 287, 345, 287, 330, 400, 255, 400]),
      _poly([70, 268, 122, 268, 100, 440, 45, 440]),
    ],
    'traps': [
      _poly([165, 110, 255, 125, 250, 158, 160, 158])
    ],
    'chest': [
      _poly([150, 160, 250, 160, 262, 235, 150, 240])
    ],
    'abs': [
      _poly([135, 245, 252, 245, 250, 400, 125, 400])
    ],
    'quads': [
      _poly([110, 445, 320, 445, 310, 615, 115, 615])
    ],
    'calves': [
      _poly([115, 625, 320, 625, 325, 750, 120, 750])
    ],
  },
  // 90° — o'ng yon
  2: {
    'shoulders': [
      _poly([150, 150, 250, 148, 258, 200, 150, 200])
    ],
    'biceps': [
      _poly([150, 202, 205, 202, 195, 290, 140, 290])
    ],
    'triceps': [
      _poly([205, 202, 262, 202, 250, 290, 195, 290])
    ],
    'forearms': [
      _poly([130, 292, 252, 292, 250, 410, 105, 450])
    ],
    'traps': [
      _poly([195, 105, 265, 115, 262, 150, 200, 148])
    ],
    'chest': [
      _poly([118, 170, 150, 170, 150, 235, 122, 240])
    ],
    'back': [
      _poly([258, 160, 285, 170, 280, 330, 255, 330])
    ],
    'abs': [
      _poly([118, 245, 140, 245, 135, 400, 112, 400])
    ],
    'glutes': [
      _poly([190, 385, 262, 385, 258, 455, 190, 455])
    ],
    'quads': [
      _poly([125, 440, 190, 440, 185, 615, 130, 615])
    ],
    'hamstrings': [
      _poly([190, 455, 255, 455, 250, 615, 185, 615])
    ],
    'calves': [
      _poly([150, 625, 255, 625, 250, 750, 150, 750])
    ],
  },
  // 135° — orqa qiya
  3: {
    'shoulders': [
      _poly([200, 150, 275, 150, 285, 200, 205, 205]),
      _poly([80, 170, 115, 160, 115, 205, 78, 205]),
    ],
    'triceps': [
      _poly([208, 205, 285, 205, 290, 275, 215, 275]),
      _poly([70, 205, 112, 205, 110, 268, 62, 268]),
    ],
    'forearms': [
      _poly([235, 277, 300, 277, 330, 440, 262, 440]),
      _poly([60, 270, 112, 270, 118, 385, 70, 385]),
    ],
    'traps': [
      _poly([130, 105, 215, 95, 205, 160, 118, 160])
    ],
    'back': [
      _poly([115, 165, 200, 160, 210, 345, 125, 345])
    ],
    'glutes': [
      _poly([115, 395, 300, 395, 300, 475, 112, 475])
    ],
    'hamstrings': [
      _poly([105, 477, 305, 477, 295, 615, 110, 615])
    ],
    'calves': [
      _poly([105, 625, 300, 625, 300, 750, 100, 750])
    ],
  },
  // 225° — orqa qiya
  5: {
    'shoulders': [
      _poly([200, 150, 278, 150, 280, 200, 205, 205]),
      _poly([85, 165, 120, 155, 120, 205, 82, 205]),
    ],
    'triceps': [
      _poly([205, 205, 282, 205, 288, 275, 210, 275]),
      _poly([72, 205, 115, 205, 112, 268, 68, 268]),
    ],
    'forearms': [
      _poly([232, 277, 300, 277, 335, 445, 262, 445]),
      _poly([70, 270, 112, 270, 125, 390, 78, 390]),
    ],
    'traps': [
      _poly([125, 110, 225, 100, 205, 160, 122, 160])
    ],
    'back': [
      _poly([120, 165, 200, 160, 208, 345, 125, 345])
    ],
    'glutes': [
      _poly([112, 395, 292, 395, 292, 475, 110, 475])
    ],
    'hamstrings': [
      _poly([100, 477, 292, 477, 288, 615, 105, 615])
    ],
    'calves': [
      _poly([95, 625, 290, 625, 290, 750, 92, 750])
    ],
  },
  // 270° — chap yon
  6: {
    'shoulders': [
      _poly([130, 150, 230, 148, 232, 200, 135, 200])
    ],
    'biceps': [
      _poly([195, 202, 240, 202, 250, 290, 205, 290])
    ],
    'triceps': [
      _poly([140, 202, 195, 202, 205, 290, 150, 290])
    ],
    'forearms': [
      _poly([160, 292, 255, 292, 285, 450, 200, 450])
    ],
    'traps': [
      _poly([140, 105, 205, 105, 200, 148, 135, 150])
    ],
    'chest': [
      _poly([232, 165, 268, 180, 265, 230, 240, 235])
    ],
    'back': [
      _poly([110, 165, 135, 165, 142, 330, 115, 330])
    ],
    'glutes': [
      _poly([135, 385, 205, 385, 205, 455, 135, 455])
    ],
    'quads': [
      _poly([205, 440, 275, 440, 270, 615, 205, 615])
    ],
    'hamstrings': [
      _poly([140, 455, 205, 455, 205, 615, 140, 615])
    ],
    'calves': [
      _poly([140, 625, 262, 625, 262, 750, 145, 750])
    ],
  },
  // 315° — old qiya
  7: {
    'shoulders': [
      _poly([265, 160, 320, 160, 342, 205, 270, 212]),
      _poly([88, 205, 100, 165, 150, 152, 150, 200]),
    ],
    'biceps': [
      _poly([275, 215, 350, 220, 352, 290, 282, 290]),
      _poly([68, 208, 112, 208, 105, 265, 58, 265]),
    ],
    'forearms': [
      _poly([285, 292, 355, 292, 350, 430, 300, 430]),
      _poly([52, 267, 105, 267, 95, 440, 38, 440]),
    ],
    'traps': [
      _poly([160, 115, 260, 125, 262, 156, 150, 156])
    ],
    'chest': [
      _poly([150, 158, 265, 158, 268, 232, 150, 236])
    ],
    'abs': [
      _poly([150, 245, 262, 245, 262, 400, 145, 400])
    ],
    'quads': [
      _poly([90, 445, 330, 445, 325, 615, 95, 615])
    ],
    'calves': [
      _poly([95, 625, 340, 625, 345, 750, 100, 750])
    ],
  },
};

/// Kulrang darajalari (yorqinlik 0..5) va rangli urg'ular (binafsha, sariq, yashil-moviy)
const _tones = [
  Color(0xFF3C3C3C),
  Color(0xFF5C5C5C),
  Color(0xFF808080),
  Color(0xFFABABAB),
  Color(0xFFD0D0D0),
  Color(0xFFFFFFFF),
  Color(0xFFD0D0D0),
  Color(0xFFABABAB),
  Color(0xFFD0D0D0),
];

/// Tanlangan mushak ranglari: soyada to'q sariq, yorug'da och sariq (yorqinlik darajasi 0..5)
const _lit = [
  Color(0xFF8A5A08),
  Color(0xFFA86C06),
  Color(0xFFCC8A0A),
  Color(0xFFFFB829),
  Color(0xFFFFD270),
  Color(0xFFFFF0C2),
];

/// Chizishga tayyor nuqtalar: har rang uchun bitta ro'yxat (x, y, x, y ...). Bir marta
/// hisoblanadi va saqlanadi — kadr sayin faqat ekranga chiqariladi, shuning uchun tana
/// tinch turganda, yaqinlashganda va aylanganda ham yengil ishlaydi.
class _Layer {
  /// Rang bo'yicha: 0..8 — [_tones], 9..14 — [_lit] (tanlangan mushak)
  final List<Float32List> pts;

  /// [pts] dagi har nuqtaning zarracha tartib raqami (yig'ilish animatsiyasi uchun)
  final List<Int32List> idx;
  const _Layer(this.pts, this.idx);
}

final _layers = <String, _Layer>{};

/// [angle] ko'rinishi; [selected] mushaklar (vergul bilan, bitta yoki bir nechta) nuqtalari
/// alohida (sariq) ro'yxatlarga tushadi
_Layer _layer(int angle, String? selected) => _layers.putIfAbsent('$angle|$selected', () {
      final lit = selected?.split(',').toSet() ?? const <String>{};
      final src = bodyViews[angle];
      final n = src.length ~/ 3;
      final accent = _accents();
      final bucket = Int32List(n);
      final count = List.filled(_tones.length + _lit.length, 0);
      for (var i = 0; i < n; i++) {
        final x = src[i * 3].toDouble(), y = src[i * 3 + 1].toDouble(), level = src[i * 3 + 2];
        final on = lit.isNotEmpty && lit.contains(ParticleBody.hit(x, y, angle: angle));
        final b = on ? _tones.length + level : (accent[i] < 0 ? level : accent[i]);
        bucket[i] = b;
        count[b]++;
      }
      final pts = [for (final c in count) Float32List(c * 2)];
      final idx = [for (final c in count) Int32List(c)];
      final at = List.filled(count.length, 0);
      for (var i = 0; i < n; i++) {
        final b = bucket[i], k = at[b]++;
        pts[b][k * 2] = src[i * 3].toDouble();
        pts[b][k * 2 + 1] = src[i * 3 + 1].toDouble();
        idx[b][k] = i;
      }
      return _Layer(pts, idx);
    });

/// Eng ko'p nuqtali ko'rinishdagi nuqtalar soni (ko'rinishlarda son har xil bo'lishi mumkin)
final _maxPoints = bodyViews.map((v) => v.length ~/ 3).reduce(math.max);

Int8List? _accentCache;

/// Rangli zarrachalar: 6, 7, 8 — [_tones] dagi urg'u rangi; -1 — rangi yorqinlikdan.
/// Har 18-zarrachadan biri rangli — qomat bir xil kulrang bo'lib qolmasin.
Int8List _accents() => _accentCache ??= () {
      final rnd = math.Random(5);
      final out = Int8List(_maxPoints);
      for (var i = 0; i < out.length; i++) {
        out[i] = rnd.nextInt(18) == 0 ? 6 + rnd.nextInt(3) : -1;
      }
      return out;
    }();

Float32List? _scatterCache;

/// Yig'ilish animatsiyasi uchun: har zarrachaning sochilgan paytdagi siljishi (dx, dy)
/// va kechikishi (0..0.4) — uchtadan
Float32List _scatter() => _scatterCache ??= () {
      final rnd = math.Random(7);
      final out = Float32List(_maxPoints * 3);
      for (var i = 0; i + 2 < out.length; i += 3) {
        final a = rnd.nextDouble() * math.pi * 2, d = 320 + rnd.nextDouble() * 700;
        out[i] = math.cos(a) * d;
        out[i + 1] = math.sin(a) * d;
        out[i + 2] = rnd.nextDouble() * 0.4;
      }
      return out;
    }();

class _ParticleBodyState extends State<ParticleBody> with TickerProviderStateMixin {
  /// Yig'ilish animatsiyasi
  late final _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

  /// Yaqinlashish animatsiyasi
  late final _zoom = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));

  /// Aylanish animatsiyasi
  late final _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

  late Rect _from = _viewFor(widget.selected), _to = _from;

  /// Aylanish holati ko'rinish birligida (kasr — ikki ko'rinish orasi); 8 ga karrali emas,
  /// to'xtovsiz o'sib yoki kamayib boradi
  late double _posFrom = widget.angle.toDouble(), _posTo = _posFrom;

  /// Barmoq bilan surishda yig'ilgan masofa
  double _drag = 0;

  double get _ratio => widget.width / widget.height;

  /// Butun tana: quti nisbatiga mos
  Rect get _full {
    const top = 6.0, bottom = 884.0;
    final h = bottom - top, w = h * _ratio;
    return Rect.fromLTWH((bodyW - w) / 2, top, w, h);
  }

  /// Tanlangan mushakka yaqinlashgan ko'rinish (quti nisbati saqlanadi)
  Rect _viewFor(String? muscle) {
    final paths = muscle == null ? null : _regions[widget.angle]?[muscle];
    if (paths == null) return _full;
    var r = paths.first.getBounds();
    var all = r;
    for (final q in paths.skip(1)) {
      all = all.expandToInclude(q.getBounds());
    }
    // juft mushak bir-biriga yaqin bo'lsa (ko'krak, qanot, son) ikkalasi sig'adi; uzoq bo'lsa
    // (ikki qo'l, ikki yelka) — bittasiga yaqinlashadi, aks holda yaqinlashish sezilmaydi
    if (all.width <= 250) r = all;
    r = r.inflate(46);
    r = r.width / r.height > _ratio
        ? Rect.fromCenter(center: r.center, width: r.width, height: r.width / _ratio)
        : Rect.fromCenter(center: r.center, width: r.height * _ratio, height: r.height);
    // juda yaqinlashib ketmasin
    if (r.height < 380) r = Rect.fromCenter(center: r.center, width: 380 * _ratio, height: 380);
    return r;
  }

  Rect get _view => Rect.lerp(_from, _to, Curves.easeInOutCubic.transform(_zoom.value))!;

  double get _pos => _posFrom + (_posTo - _posFrom) * Curves.easeInOut.transform(_turn.value);

  @override
  void initState() {
    super.initState();
    _zoom.value = 1;
    _turn.value = 1;
    _intro.forward();
  }

  @override
  void didUpdateWidget(ParticleBody old) {
    super.didUpdateWidget(old);
    if (old.angle != widget.angle) {
      // eng qisqa yo'l bilan aylanadi (masalan 7 dan 0 ga — bir qadam oldinga)
      var d = (widget.angle - old.angle) % ParticleBody.views;
      if (d > ParticleBody.views ~/ 2) d -= ParticleBody.views;
      _posFrom = _pos;
      _posTo = _posTo + d;
      _turn
        ..duration = Duration(milliseconds: 220 + 130 * (_posTo - _posFrom).abs().round())
        ..forward(from: 0);
    }
    if (old.angle != widget.angle || old.selected != widget.selected) {
      _from = _view;
      _to = _viewFor(widget.selected);
      _zoom.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _zoom.dispose();
    _turn.dispose();
    super.dispose();
  }

  void _tap(TapUpDetails d) {
    final v = _to;
    final k = v.width / widget.width;
    final p = Offset(v.left + d.localPosition.dx * k, v.top + d.localPosition.dy * k);
    widget.onTap(ParticleBody.hit(p.dx, p.dy, angle: widget.angle));
  }

  void _dragBy(DragUpdateDetails d) {
    if (widget.onRotate == null) return;
    _drag += d.delta.dx;
    const step = 34.0;
    while (_drag.abs() >= step) {
      widget.onRotate!(_drag > 0 ? 1 : -1);
      _drag -= _drag > 0 ? step : -step;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    // yonadigan mushaklar: tanlangani; tanlanmagan bo'lsa — bugungi mashg'ulotdagilar
    String? lit;
    if (sel != null && ParticleBody.has(sel, angle: widget.angle)) {
      lit = sel;
    } else if (sel == null) {
      final t = widget.today.where((m) => ParticleBody.has(m, angle: widget.angle)).toList()
        ..sort();
      if (t.isNotEmpty) lit = t.join(',');
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _tap,
      onHorizontalDragStart: (_) => _drag = 0,
      onHorizontalDragUpdate: _dragBy,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: Listenable.merge([_intro, _zoom, _turn]),
          builder: (_, __) => CustomPaint(
            size: Size(widget.width, widget.height),
            painter: _ParticlePainter(
              pos: _pos,
              t: _intro.value,
              view: _view,
              angle: widget.angle,
              selected: lit,
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  /// Aylanish holati (kasr — ikki ko'rinish orasi), yig'ilish holati 0..1
  final double pos, t;
  final Rect view;

  /// Hozirgi (maqsad) ko'rinish va undagi yonadigan mushaklar (vergul bilan)
  final int angle;
  final String? selected;
  _ParticlePainter({
    required this.pos,
    required this.t,
    required this.view,
    required this.angle,
    required this.selected,
  });

  static double _ease(double x) => 1 - math.pow(1 - x, 3).toDouble();

  /// Nuqta mayda (rasm kabi tiniq chiqsin); yorug' joyda sal yirikroq — mushak bo'rtadi.
  /// O'lcham tana birligida: yaqinlashganda nuqta ham kattalashadi.
  void _draw(Canvas canvas, _Layer layer, double alpha, double grow,
      {Float32List? Function(int)? moved}) {
    final others = selected == null ? 1.0 : 0.38;
    for (var b = 0; b < layer.pts.length; b++) {
      final pts = moved?.call(b) ?? layer.pts[b];
      if (pts.isEmpty) continue;
      final lit = b >= _tones.length;
      final level = lit ? b - _tones.length : (b < _lit.length ? b : 3);
      final color = lit ? _lit[level] : _tones[b];
      canvas.drawRawPoints(
        PointMode.points,
        pts,
        Paint()
          ..color = color.withValues(alpha: alpha * (lit ? 1 : others))
          ..strokeCap = StrokeCap.round
          ..strokeWidth = ((lit ? 1.7 : 1.5) + level * 0.23) * grow,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / view.width;
    canvas.save();
    canvas.scale(k);
    canvas.translate(-view.left, -view.top);

    if (t < 1) {
      // Yig'ilish: har nuqta sochilgan joyidan o'z joyiga keladi (faqat ekran ochilganda)
      final layer = _layer(angle, selected), sc = _scatter();
      _draw(canvas, layer, _ease(t), 1 + (1 - t) * 0.8, moved: (b) {
        final src = layer.pts[b], idx = layer.idx[b];
        final out = Float32List(src.length);
        for (var j = 0; j < idx.length; j++) {
          final i = idx[j] * 3, delay = sc[i + 2];
          final e = 1 - _ease(((t - delay) / (1 - delay)).clamp(0.0, 1.0));
          out[j * 2] = src[j * 2] + sc[i] * e;
          out[j * 2 + 1] = src[j * 2 + 1] + sc[i + 1] * e;
        }
        return out;
      });
    } else {
      // Aylanish: nuqtalar ko'chmaydi (oyoq-qo'l sochilib ketmasin) — bir ko'rinish so'nib,
      // qo'shnisi paydo bo'ladi; ikkalasi o'rta chiziq atrofida sal torayib-kengayadi
      final base = pos.floor();
      final f = pos - base;
      final a = base % ParticleBody.views, b = (base + 1) % ParticleBody.views;
      void side(int v, double w) {
        if (w < 0.01) return;
        canvas.save();
        canvas.translate(bodyW / 2, 0);
        canvas.scale(0.72 + 0.28 * w, 1);
        canvas.translate(-bodyW / 2, 0);
        _draw(canvas, _layer(v, v == angle ? selected : null), w, 1);
        canvas.restore();
      }

      side(a, 1 - f);
      side(b, f);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.pos != pos ||
      old.t != t ||
      old.view != view ||
      old.angle != angle ||
      old.selected != selected;
}
