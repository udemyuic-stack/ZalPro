// Logotipdan ilova ikonkasi uchun kvadrat rasmlar tayyorlaydi.
//
//   dart run tools/make_icon.dart
//
// Chiqadigan fayllar:
//   assets/icon/icon.png            — 1024x1024, SHAFFOF fon (eski Android va web uchun)
//   assets/icon/icon_foreground.png — 1024x1024, shaffof (adaptiv ikonka; fon ham shaffof —
//                                     pubspec: adaptive_icon_background #00000000, inset 0)
import 'dart:io';
import 'package:image/image.dart' as img;

const _size = 1024;

/// Adaptiv ikonka: tizim niqobi (doira/squircle) ~66–72% ni ko'rsatadi — logotip shunga
/// sig'adi va chetlari qirqilmaydi. Avval 60% + 16% inset edi (juda kichik ko'rinardi).
const _foregroundScale = 0.68;

/// Oddiy ikonka: deyarli butun maydon
const _legacyScale = 0.96;

void main() {
  final srcFile = File('assets/icon/logo_src.jpg');
  if (!srcFile.existsSync()) {
    stderr.writeln('Topilmadi: ${srcFile.path}');
    exit(1);
  }
  final src = img.decodeImage(srcFile.readAsBytesSync());
  if (src == null) {
    stderr.writeln('Rasmni o’qib bo’lmadi');
    exit(1);
  }
  print('Manba: ${src.width}x${src.height}');

  // Oq fonni shaffofga aylantiramiz — logotip qora, fon deyarli oq
  final cut = _whiteToAlpha(src);
  final trimmed = img.trim(cut, mode: img.TrimMode.transparent);
  print('Qirqilgan: ${trimmed.width}x${trimmed.height}');

  _write('assets/icon/icon.png', _compose(trimmed, _legacyScale, null));
  _write('assets/icon/icon_foreground.png', _compose(trimmed, _foregroundScale, null));
  print('Tayyor.');
}

/// Faqat TASHQI oq fonni shaffof qiladi: rasm chetlaridan boshlab oqqa yaqin piksellar
/// bo'ylab to'ldiriladi. Logotip ichidagi oq detallar (qo'l, yuz yorug'i) oq bo'lib qoladi —
/// ikonka foni shaffof bo'lganda ular orqali ekran foni ko'rinmasin.
img.Image _whiteToAlpha(img.Image src) {
  final w = src.width, h = src.height;
  bool isWhite(int x, int y) {
    final p = src.getPixel(x, y);
    final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
    final maxc = [r, g, b].reduce((a, c) => a > c ? a : c);
    final minc = [r, g, b].reduce((a, c) => a < c ? a : c);
    return maxc > 232 && (maxc - minc) < 24;
  }

  final background = List<bool>.filled(w * h, false);
  final stack = <int>[];
  void push(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final i = y * w + x;
    if (background[i] || !isWhite(x, y)) return;
    background[i] = true;
    stack.add(i);
  }

  for (var x = 0; x < w; x++) {
    push(x, 0);
    push(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    push(0, y);
    push(w - 1, y);
  }
  while (stack.isNotEmpty) {
    final i = stack.removeLast();
    final x = i % w, y = i ~/ w;
    push(x + 1, y);
    push(x - 1, y);
    push(x, y + 1);
    push(x, y - 1);
  }

  final out = img.Image(width: w, height: h, numChannels: 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = src.getPixel(x, y);
      out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), background[y * w + x] ? 0 : 255);
    }
  }
  return out;
}

/// Logotipni kvadrat maydonga markazlab joylaydi
img.Image _compose(img.Image logo, double scale, img.Color? background) {
  final canvas = img.Image(width: _size, height: _size, numChannels: 4);
  if (background != null) {
    img.fill(canvas, color: background);
  }
  final box = (_size * scale).round();
  final k = box / (logo.width > logo.height ? logo.width : logo.height);
  final w = (logo.width * k).round();
  final h = (logo.height * k).round();
  final resized = img.copyResize(
    logo,
    width: w,
    height: h,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    canvas,
    resized,
    dstX: ((_size - w) / 2).round(),
    dstY: ((_size - h) / 2).round(),
  );
  return canvas;
}

void _write(String path, img.Image im) {
  File(path).writeAsBytesSync(img.encodePng(im));
  print('  -> $path (${im.width}x${im.height})');
}
