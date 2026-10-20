import '../l10n/tr.dart';
import '../services/api/json_helpers.dart';

/// Zal do'koni: forma, suv idishlari, anjomlar va dobavkalar (protein, kreatin ...).
/// Tovarlarni trener kiritadi, shogird ko'radi va buyurtma beradi.
/// To'lov ilovada emas — shogird zalga kelganda naqd to'laydi.

/// Dobavkalar ichidagi kichik bo'limlar (sport pitaniya turlari).
const supplementCategories = [
  'Protein',
  'Gainer',
  'Kreatin',
  'L-Karnitin',
  'L-Arginin',
  'Boshqa',
];

/// Do'konning asosiy bo'limlari — shogird avval shulardan tanlaydi.
const shopGroups = ['Forma', 'Suv idishlari', 'Anjomlar', 'Dobavkalar'];

/// Tovar bo'limlari — bazada aynan shu nomlar saqlanadi.
/// Tartibi shogirdga ham shu ko'rinishda chiqadi.
const shopCategories = ['Forma', 'Suv idishlari', 'Anjomlar', ...supplementCategories];

/// Tovar qaysi asosiy bo'limga kiradi: `Protein` -> `Dobavkalar`.
String shopGroupOf(String category) =>
    supplementCategories.contains(category) ? 'Dobavkalar' : category;

/// Valyutalar: so'm (asosiy) va dollar (chetdan keltirilgan tovarlar uchun)
const uzs = 'UZS';
const usd = 'USD';
const currencies = [uzs, usd];

/// Valyuta belgisi: "so'm" / "$"
String currencyLabel(String c) => c == usd ? '\$' : tr("so'm");

/// Pulni to'liq yozish: (450000, UZS) -> "450 000 so'm"; (35, USD) -> "35 \$"
String fmtMoney(int amount, [String currency = uzs]) =>
    '${fmtSum(amount)} ${currencyLabel(currency)}';

/// Narxni o'qishli qilish: 450000 -> "450 000"
String fmtSum(int v) {
  final s = v.abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// `shop/{id}` — sotuvdagi tovar
class Product {
  final String id;

  /// [shopCategories] dan biri
  final String category;
  final String name;

  /// Qisqa izoh: ta'mi, hajmi, o'lchami
  final String note;

  /// Nom va izohning ruscha / inglizcha tarjimasi (ixtiyoriy; bo'sh bo'lsa o'zbekchasi chiqadi).
  /// [name] va [note] — asosiy (o'zbekcha): buyurtma va hisobotlarga shular yoziladi.
  final String nameRu, nameEn, noteRu, noteEn;

  /// Serverdagi rasmlarning vaqtinchalik havolalari. Birinchisi — muqova.
  final List<String> imageUrls;

  /// [imageUrls] bilan bir xil tartibdagi saqlash kalitlari (rasmlar ro'yxatini almashtirish uchun)
  final List<String> imageKeys;

  /// Mavjud o'lchamlar: XL, XXL, 3XL … Bo'sh bo'lsa o'lcham so'ralmaydi.
  final List<String> sizes;

  /// Mavjud ranglar: sariq, kulrang … Bo'sh bo'lsa rang so'ralmaydi.
  /// Qoldiq rang bo'yicha yuritilmaydi — faqat o'lcham bo'yicha.
  final List<String> colors;

  /// Narx — butun son, [currency] valyutasida
  final int price;

  /// Narx valyutasi: `UZS` (so'm) yoki `USD` (dollar)
  final String currency;

  /// Zaldagi qoldiq (jamlangan — [sizes] bo'lsa [sizeStock] yig'indisi). 0 bo'lsa buyurtma
  /// tugmasi ochilmaydi. [sizes] bo'sh tovarlarda bu qiymat to'g'ridan-to'g'ri tahrirlanadi.
  final int stock;

  /// O'lcham bo'yicha qoldiq ([sizes] dagi nomlar bilan kalitlangan). [sizes] bo'sh bo'lgan
  /// tovarlarda ishlatilmaydi — ular [stock] dan to'g'ridan-to'g'ri foydalanadi.
  final Map<String, int> sizeStock;

  /// Tan narx (yetkazib beruvchidan) — ustama hisoblash uchun, ixtiyoriy (0 — kiritilmagan).
  final int costPrice;

  /// false — vaqtincha sotuvda yo'q, shogirdga ko'rinmaydi
  final bool active;

  const Product({
    this.id = '',
    required this.category,
    required this.name,
    this.note = '',
    this.nameRu = '',
    this.nameEn = '',
    this.noteRu = '',
    this.noteEn = '',
    this.imageUrls = const [],
    this.imageKeys = const [],
    this.sizes = const [],
    this.colors = const [],
    this.price = 0,
    this.currency = uzs,
    this.stock = 0,
    this.sizeStock = const {},
    this.costPrice = 0,
    this.active = true,
  });

  /// Ko'rsatiladigan hamma rasm (muqova birinchi, takrorlanmaydi)
  List<String> get gallery {
    final all = <String>[];
    for (final u in imageUrls) {
      final t = u.trim();
      if (t.isNotEmpty && !all.contains(t)) all.add(t);
    }
    return all;
  }

  /// Muqova rasm havolasi (rasm bo'lmasa bo'sh)
  String get image => gallery.isEmpty ? '' : gallery.first;

  /// Jami qoldiq — [sizes] bo'lsa [sizeStock] yig'indisi, bo'lmasa [stock].
  int get totalStock => sizes.isEmpty ? stock : sizeStock.values.fold(0, (a, b) => a + b);

  /// Berilgan o'lchamdagi qoldiq ([sizes] bo'sh bo'lsa — [stock], o'lcham ko'rsatilmasa — 0).
  int stockFor(String? size) => sizes.isEmpty ? stock : (size == null ? 0 : (sizeStock[size] ?? 0));

  /// Shogirdga ko'rinadimi va buyurtma berish mumkinmi
  bool get onSale => active && totalStock > 0 && price > 0;

  /// Narx yozuvi: "450 000 so'm" yoki "35 \$"
  String get priceText => fmtMoney(price, currency);

  /// Ilova tilidagi nom (tarjimasi bo'lmasa — o'zbekcha)
  String get displayName => switch (appLang.value) {
        'ru' => nameRu.isEmpty ? name : nameRu,
        'en' => nameEn.isEmpty ? name : nameEn,
        _ => name,
      };

  /// Ilova tilidagi izoh (tarjimasi bo'lmasa — o'zbekcha)
  String get displayNote => switch (appLang.value) {
        'ru' => noteRu.isEmpty ? note : noteRu,
        'en' => noteEn.isEmpty ? note : noteEn,
        _ => note,
      };

  /// Foyda ([costPrice] kiritilmagan bo'lsa 0 — hali hisoblanmagan)
  int get margin => costPrice > 0 ? price - costPrice : 0;

  factory Product.fromJson(Map<String, dynamic> j) {
    final stockMap = j['size_stock'];
    return Product(
      id: jsonString(j['id']),
      category: jsonString(j['category']),
      name: jsonString(j['name']),
      note: jsonString(j['note']),
      nameRu: jsonString(j['name_ru']),
      nameEn: jsonString(j['name_en']),
      noteRu: jsonString(j['note_ru']),
      noteEn: jsonString(j['note_en']),
      imageUrls: jsonStrings(j['image_urls']),
      imageKeys: jsonStrings(j['image_keys']),
      sizes: jsonStrings(j['sizes']),
      colors: jsonStrings(j['colors']),
      price: jsonInt(j['price']),
      currency: jsonString(j['currency'], uzs),
      stock: jsonInt(j['stock']),
      sizeStock: stockMap is Map
          ? {
              for (final e in stockMap.entries)
                if (e.value is num) e.key.toString(): (e.value as num).toInt(),
            }
          : const {},
      costPrice: jsonInt(j['cost_price']),
      active: jsonBool(j['active'], true),
    );
  }

  Map<String, dynamic> toMap() => {
        'category': category,
        'name': name,
        'note': note,
        if (nameRu.isNotEmpty) 'nameRu': nameRu,
        if (nameEn.isNotEmpty) 'nameEn': nameEn,
        if (noteRu.isNotEmpty) 'noteRu': noteRu,
        if (noteEn.isNotEmpty) 'noteEn': noteEn,
        'sizes': sizes,
        'colors': colors,
        'price': price,
        'currency': currency,
        'stock': totalStock,
        'sizeStock': sizeStock,
        'costPrice': costPrice,
        'active': active,
      };

  Map<String, dynamic> toJson() => {
        'category': category,
        'name': name,
        'note': note,
        'name_ru': nameRu,
        'name_en': nameEn,
        'note_ru': noteRu,
        'note_en': noteEn,
        'sizes': sizes,
        'colors': colors,
        'price': price,
        'currency': currency,
        'cost_price': costPrice,
        'active': active,
        'size_stock': {
          for (final e in sizeStock.entries)
            if (sizes.contains(e.key)) e.key: e.value,
        },
        if (sizes.isEmpty) 'stock': stock,
      };

  Product copyWith({int? stock, Map<String, int>? sizeStock}) => Product(
        id: id,
        category: category,
        name: name,
        note: note,
        nameRu: nameRu,
        nameEn: nameEn,
        noteRu: noteRu,
        noteEn: noteEn,
        imageUrls: imageUrls,
        imageKeys: imageKeys,
        sizes: sizes,
        colors: colors,
        price: price,
        currency: currency,
        stock: stock ?? this.stock,
        sizeStock: sizeStock ?? this.sizeStock,
        costPrice: costPrice,
        active: active,
      );
}

/// Buyurtma holatlari
const orderNew = 'new'; // shogird so'radi, trener hali bermagan
const orderGiven = 'given'; // zalda berildi va to'lov olindi
const orderCanceled = 'canceled'; // bekor qilindi

/// `orders/{id}` — shogirdning bitta tovarga buyurtmasi
class ShopOrder {
  final String id;
  final String clientId, clientName, clientPhone;

  /// Shogirdning treneri (bo'sh — trener tanlanmagan, buyurtmani bosh admin ko'radi)
  final String trainerId;

  /// Trener zali (buyurtma paytida) — barmen faqat o'z zalining buyurtmalarini ko'radi.
  /// Bo'sh — shogirdda trener yo'q, buyurtmani faqat bosh admin ko'radi.
  final String gymId;
  final String productId, productName, category;

  /// Tanlangan o'lcham (bo'sh — tovarda o'lcham yo'q)
  final String size;

  /// Tanlangan rang (bo'sh — tovarda rang yo'q)
  final String color;
  final int price, qty;

  /// Narx valyutasi (buyurtma berilgan paytdagi)
  final String currency;
  final String status;
  final DateTime? createdAt;

  /// Kim berdi (trener yoki barmen uid) va qachon — sotuv hisoboti shunga tayanadi
  final String givenBy;
  final DateTime? givenAt;

  const ShopOrder({
    this.id = '',
    required this.clientId,
    this.clientName = '',
    this.clientPhone = '',
    this.trainerId = '',
    this.gymId = '',
    required this.productId,
    required this.productName,
    this.category = '',
    this.size = '',
    this.color = '',
    required this.price,
    this.currency = uzs,
    this.qty = 1,
    this.status = orderNew,
    this.createdAt,
    this.givenBy = '',
    this.givenAt,
  });

  int get total => price * qty;

  /// Jami summa yozuvi: "900 000 so'm" yoki "70 \$"
  String get totalText => fmtMoney(total, currency);

  bool get isNew => status == orderNew;
  bool get isGiven => status == orderGiven;

  String get statusLabel => switch (status) {
        orderGiven => tr('Topshirildi'),
        orderCanceled => tr('Bekor qilindi'),
        _ => tr('Kutilmoqda'),
      };

  /// Nomi o'lchami va rangi bilan: "Venum komplekt (XL, sariq)"
  String get title {
    final extra = [size, color].where((e) => e.isNotEmpty).join(', ');
    return extra.isEmpty ? productName : '$productName ($extra)';
  }

  /// Chatga yoziladigan matn — trener xabarnoma sifatida ko'radi
  String get chatText => '🛒 Buyurtma: $title × $qty — $totalText';

  factory ShopOrder.fromJson(Map<String, dynamic> j) {
    return ShopOrder(
      id: jsonString(j['id']),
      clientId: jsonString(j['client_id']),
      clientName: jsonString(j['client_name']),
      clientPhone: jsonString(j['client_phone']),
      trainerId: jsonString(j['trainer_id']),
      gymId: jsonString(j['gym_id']),
      productId: jsonString(j['product_id']),
      productName: jsonString(j['product_name']),
      category: jsonString(j['category']),
      size: jsonString(j['size']),
      color: jsonString(j['color']),
      price: jsonInt(j['price']),
      currency: jsonString(j['currency'], uzs),
      qty: jsonInt(j['qty'], 1),
      status: jsonString(j['status'], orderNew),
      createdAt: jsonDate(j['created_at']),
      givenBy: jsonString(j['given_by']),
      givenAt: jsonDate(j['given_at']),
    );
  }
}

/// Sotuv hisoboti: berilgan buyurtmalar bo'yicha summa va soni
class SalesReport {
  /// Jami summa — valyutalar aralash bo'lsa ma'nosiz bo'ladi, shuning uchun
  /// ko'rsatishda [money] ishlatiladi ([sums] valyuta bo'yicha ajratilgan).
  final int sum, count;

  /// Valyuta -> summa
  final Map<String, int> sums;

  const SalesReport(this.sum, this.count, [this.sums = const {}]);

  /// Ko'rsatish uchun: "450 000 so'm · 70 \$"
  String get money =>
      sums.isEmpty ? fmtMoney(sum) : sums.entries.map((e) => fmtMoney(e.value, e.key)).join(' · ');

  static Map<String, int> _sums(List<ShopOrder> list) {
    final r = <String, int>{};
    for (final o in list) {
      r[o.currency] = (r[o.currency] ?? 0) + o.total;
    }
    return r;
  }

  /// Hisobga olinadigan sana: berilgan vaqt, bo'lmasa buyurtma vaqti
  static DateTime? soldAt(ShopOrder o) => o.givenAt ?? o.createdAt;

  /// Shu davrga kiradigan, berilgan buyurtmalar (0 — hamma vaqt)
  static List<ShopOrder> sold(List<ShopOrder> orders, {int days = 0, DateTime? now}) {
    final n = now ?? DateTime.now();
    return orders.where((o) {
      if (!o.isGiven) return false;
      if (days <= 0) return true;
      final at = soldAt(o);
      return at != null && n.difference(at).inDays < days;
    }).toList();
  }

  /// [days] kun ichida berilgan buyurtmalar (0 — hammasi)
  factory SalesReport.of(List<ShopOrder> orders, {int days = 0, DateTime? now}) {
    final list = sold(orders, days: days, now: now);
    return SalesReport(list.fold(0, (s, o) => s + o.total), list.length, _sums(list));
  }

  /// Sotuvchi (barmen/trener) bo'yicha: uid -> (summa, soni)
  static Map<String, SalesReport> bySeller(
    List<ShopOrder> orders, {
    int days = 0,
    DateTime? now,
  }) {
    final groups = <String, List<ShopOrder>>{};
    for (final o in sold(orders, days: days, now: now)) {
      groups.putIfAbsent(o.givenBy, () => []).add(o);
    }
    return {
      for (final e in groups.entries)
        e.key: SalesReport(
          e.value.fold(0, (s, o) => s + o.total),
          e.value.length,
          _sums(e.value),
        ),
    };
  }

  /// Tovar bo'yicha: nomi -> (summa, soni)
  static Map<String, SalesReport> byProduct(
    List<ShopOrder> orders, {
    int days = 0,
    DateTime? now,
  }) {
    final groups = <String, List<ShopOrder>>{};
    for (final o in sold(orders, days: days, now: now)) {
      groups.putIfAbsent(o.productName, () => []).add(o);
    }
    return {
      for (final e in groups.entries)
        e.key: SalesReport(
          e.value.fold(0, (s, o) => s + o.total),
          e.value.fold(0, (s, o) => s + o.qty),
          _sums(e.value),
        ),
    };
  }
}
