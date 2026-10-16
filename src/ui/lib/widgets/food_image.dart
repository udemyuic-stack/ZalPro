import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../l10n/tr.dart';
import 'ui.dart';

/// Mahsulot nomidagi kalit so'z -> assets/foods/<kalit>.jpg
/// Kalit so'z so'z boshidan qidiriladi (regex bo'lagi). Nomda bir nechta mahsulot bo'lsa
/// ("Yong'oq (yoki 1 porsiya protein)") — **birinchi tilga olingani** tanlanadi.
const _rules = <(List<String>, String)>[
  (['suli', 'ovsyanka', 'gerkules', 'oat'], 'oats'),
  (['grechka', 'grechixa', 'buckwheat'], 'buckwheat'),
  (['guruch', 'gruch', r'osh\b', 'plov', 'rice'], 'rice'),
  (['makaron', 'spagetti', 'pasta'], 'pasta'),
  (['kartoshka', 'kartofel', 'potato'], 'potato'),
  (['tuxum oqi'], 'egg_white'),
  (['tuxum', 'omlet', 'egg'], 'egg'),
  (['tvorog', 'suzma'], 'cottage_cheese'),
  (['pishloq', r'sir\b', 'cheese'], 'cheese'),
  (['protein', 'izolyat', 'kokteyl', 'gainer'], 'protein'),
  (['baliq', 'fish'], 'fish'),
  (['tovuq', 'chicken'], 'chicken'),
  (['gosht', 'kotlet', 'bifshteks', r'mol\b', 'beef'], 'beef'),
  (['loviya', 'fosol'], 'beans'),
  (['noxat'], 'chickpeas'),
  (['yongoq'], 'walnut'),
  (['bodom', 'almond'], 'almond'),
  (['mayiz'], 'raisins'),
  (['banan'], 'banana'),
  (['olma', 'apple'], 'apple'),
  (['kivi', 'kiwi'], 'kiwi'),
  (['qulupnay'], 'strawberry'),
  (['limon', 'lemon'], 'lemon'),
  (['meva', 'frukt', 'fruit'], 'fruits'),
  (['pomidor'], 'tomato'),
  (['bodring'], 'cucumber'),
  (['bolgar', 'qalampir'], 'pepper'),
  (['piyoz', 'onion'], 'onion'),
  (['brokkoli', 'gulkaram', 'broccoli'], 'broccoli'),
  (['kokat', 'ukrop', 'petrushka', 'shivit', 'salat'], 'greens'),
  ([r'sut\b', 'suti', 'milk'], 'milk'),
  (['kefir', 'qatiq', 'yogurt'], 'kefir'),
  (['shokolad', 'chocolate'], 'chocolate'),
  (['yogi', 'oil'], 'oil'),
];

// .jpg dan boshqa formatdagi rasmlar
const _ext = <String, String>{};

final _patterns = [
  for (final (keys, key) in _rules) (RegExp('(?:^|[^a-z])(${keys.join('|')})'), key),
];

/// Nomga mos ichki rasm yo'li yoki null
String? foodAsset(String name) {
  // o'zbekcha apostroflarning barcha turlarini olib tashlaymiz: yong'oq / yong‘oq -> yongoq
  final n = name.toLowerCase().replaceAll(RegExp("[’'ʻ‘`ʼ]"), '');
  String? best;
  int bestAt = 1 << 30, bestLen = 0;
  for (final (re, key) in _patterns) {
    final m = re.firstMatch(n);
    if (m == null) continue;
    final len = m.group(1)!.length, at = m.end - len;
    // eng oldin kelgani; bir joyda bo'lsa — uzunrog'i ("tuxum oqi" > "tuxum")
    if (at < bestAt || (at == bestAt && len > bestLen)) {
      best = key;
      bestAt = at;
      bestLen = len;
    }
  }
  return best == null ? null : 'assets/foods/$best${_ext[best] ?? '.jpg'}';
}

/// Tarmoq rasmi. Telefonda diskda keshlanadi — ilova qayta ochilganda internetdan qayta
/// yuklanmaydi. Web'da brauzerning o'z keshi ishlaydi (va CORS'siz saytlar uchun <img> zaxirasi).
/// [cacheWidth] — xotirada shu enga kichraytirib saqlanadi (null — to'liq o'lcham).
Widget netImage(
  String url, {
  int? cacheWidth,
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
}) =>
    kIsWeb
        ? Image.network(
            url,
            fit: fit,
            width: width,
            height: height,
            cacheWidth: cacheWidth,
            // CORS sarlavhasiz saytlardagi rasmlar ham web'da ko'rinsin
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            errorBuilder: errorBuilder,
          )
        : CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            width: width,
            height: height,
            memCacheWidth: cacheWidth,
            fadeInDuration: const Duration(milliseconds: 120),
            errorWidget: (c, _, e) => errorBuilder(c, e, null),
          );

/// Mahsulot rasmi: URL -> nom bo'yicha ichki rasm -> rangli ikonka
class FoodImage extends StatelessWidget {
  final String name;
  final String url;
  final double size;
  const FoodImage({super.key, required this.name, this.url = '', this.size = 48});

  @override
  Widget build(BuildContext context) {
    final asset = foodAsset(name);
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    Widget placeholder(BuildContext c, Object e, StackTrace? s) =>
        _Placeholder(name: name, size: size);
    Widget assetOr(BuildContext c, Object e, StackTrace? s) => asset == null
        ? placeholder(c, e, s)
        : Image.asset(asset, fit: BoxFit.cover, cacheWidth: px, errorBuilder: placeholder);

    final link = url.trim();
    final Widget img = link.isNotEmpty
        ? netImage(link, cacheWidth: px, errorBuilder: assetOr)
        : asset != null
            ? Image.asset(asset, fit: BoxFit.cover, cacheWidth: px, errorBuilder: placeholder)
            : _Placeholder(name: name, size: size);

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: SizedBox.square(dimension: size, child: img),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String name;
  final double size;
  const _Placeholder({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final c = avatarColor(name);
    return Container(
      color: c.withValues(alpha: 0.14),
      alignment: Alignment.center,
      child: Icon(Icons.restaurant, size: size * 0.45, color: c),
    );
  }
}

/// Rasm mualliflari va litsenziyalari (CC BY-SA talabi)
Future<void> showImageCredits(BuildContext context) async {
  final text = await rootBundle.loadString('assets/credits.txt').catchError((_) => '');
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('Rasm manbalari')),
      content: SingleChildScrollView(
        child: SelectableText(
          text.isEmpty ? tr("Ma'lumot yo'q") : text,
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Yopish')))],
    ),
  );
}
