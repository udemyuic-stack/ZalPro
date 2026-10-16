import 'package:flutter/foundation.dart';
import 'en.dart';
import 'ru.dart';

/// Ilova tili: `uz` (asosiy), `ru`, `en`. `AppSettings` qurilmadan o'qiydi va saqlaydi;
/// o'zgarsa `MaterialApp` qayta quriladi (tema kabi).
final appLang = ValueNotifier<String>('uz');

/// Til tanlash ro'yxati: kod -> o'z tilidagi nomi
const appLangs = {'uz': "O'zbek", 'ru': 'Русский', 'en': 'English'};

/// Matnni tanlangan tilga o'giradi. Kalit — o'zbekcha matnning o'zi; lug'atda bo'lmasa
/// o'zbekchasi qaytadi (tarjima yo'qolsa ham ekranda ma'noli matn turadi).
/// Lug'atlar `tools/l10n/tarjima.json` dan generatsiya qilinadi.
String tr(String uz) => switch (appLang.value) {
      'ru' => ru[uz] ?? uz,
      'en' => en[uz] ?? uz,
      _ => uz,
    };

/// O'zgaruvchili matn: `trf('{0} kun qoldi', [5])` -> "5 kun qoldi" / "Осталось 5 дн.".
/// So'z tartibi tilga qarab o'zgarishi mumkin — shuning uchun qo'shib yozilmaydi.
String trf(String uz, List<Object?> args) {
  var s = tr(uz);
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}

/// Chatga ilovaning o'zi yozgan xabarlar (buyurtma, abonement eslatmasi) bazada o'zbekcha
/// turadi — ko'rsatishda tanlangan tilga o'giriladi. Odam yozgan xabar o'zgarmaydi.
String trChat(String text) {
  if (appLang.value == 'uz') return text;
  String money(String v) =>
      v.endsWith(" so'm") ? '${v.substring(0, v.length - 5)} ${tr("so'm")}' : v;
  var m = RegExp(r'^🛒 Buyurtma: (.+) × (\d+) — (.+)$').firstMatch(text);
  if (m != null) return trf('🛒 Buyurtma: {0} × {1} — {2}', [m[1], m[2], money(m[3]!)]);
  m = RegExp(r'^✅ Buyurtma berildi: (.+) × (\d+) — (.+)$').firstMatch(text);
  if (m != null) return trf('✅ Buyurtma berildi: {0} × {1} — {2}', [m[1], m[2], money(m[3]!)]);
  m = RegExp(r'^❌ Buyurtma bekor qilindi: (.+)$').firstMatch(text);
  if (m != null) return trf('❌ Buyurtma bekor qilindi: {0}', [m[1]]);
  m = RegExp(r'^⏰ Abonementingiz (\d+) kundan keyin tugaydi$').firstMatch(text);
  if (m != null) return trf('⏰ Abonementingiz {0} kundan keyin tugaydi', [m[1]]);
  if (text == '⏰ Abonementingiz tugadi — yangilang') return tr(text);
  return text;
}
