import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/tr.dart';

/// Telefon/brauzerda saqlanadigan shaxsiy sozlamalar: ko'rinish (tema) va bildirishnomalar.
/// Hisobga bog'lanmagan — har qurilmada o'z tanlovi.
class AppSettings {
  static SharedPreferences? _p;

  /// Ko'rinish: qorong'i (asosiy), yorug' yoki telefon sozlamasiga qarab
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);

  /// Bildirishnoma sozlamalari o'zgarganda oshadi (eslatmalarni qayta rejalashtirish uchun)
  static final notifChanged = ValueNotifier<int>(0);

  static Future<void> init() async {
    try {
      _p = await SharedPreferences.getInstance();
    } catch (_) {
      _p = null; // saqlab bo'lmasa ham ilova standart sozlamalar bilan ishlayveradi
    }
    themeMode.value = switch (_p?.getString('theme')) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    final lang = _p?.getString('lang');
    appLang.value = appLangs.containsKey(lang) ? lang! : 'uz';
    _loadFeedSeen();
  }

  /// Ilova tili (`uz` / `ru` / `en`) — [appLang] ni o'zgartiradi, ilova qayta chiziladi
  static Future<void> setLang(String code) async {
    if (!appLangs.containsKey(code)) return;
    appLang.value = code;
    await _p?.setString('lang', code);
  }

  static Future<void> setThemeMode(ThemeMode m) async {
    themeMode.value = m;
    await _p?.setString('theme', m.name);
  }

  // ---------- bildirishnomalar (hammasi standart holatda yoqilgan) ----------
  static bool get mealReminders => _p?.getBool('notif_meals') ?? true;
  static bool get weighInReminder => _p?.getBool('notif_weight') ?? true;
  static bool get chatNotifications => _p?.getBool('notif_chat') ?? true;
  static bool get planNotifications => _p?.getBool('notif_plan') ?? true;

  static Future<void> setNotif(String key, bool v) async {
    await _p?.setBool(key, v);
    notifChanged.value++;
  }

  // ---------- oylik hisobot ----------
  /// Trener ulushi (abonement tushumidan foiz) — bosh admin hisobot ekranida tanlaydi.
  /// Qurilmada saqlanadi: bu hisob-kitob uchun yordamchi son, bazadagi qoida emas.
  static int get trainerSharePct => _p?.getInt('trainer_share_pct') ?? 40;
  static Future<void> setTrainerSharePct(int v) async =>
      _p?.setInt('trainer_share_pct', v.clamp(0, 100));

  // ---------- "Eslatma" bo'limi ----------
  /// Bildirishnomalar oxirgi marta qachon ko'rilgan (yangi belgisini hisoblash uchun).
  /// Hisobga emas, qurilmaga bog'langan.
  static final feedSeen = ValueNotifier<DateTime?>(null);

  static void _loadFeedSeen() {
    final ms = _p?.getInt('feed_seen');
    feedSeen.value = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Bo'lim ochilganda chaqiriladi — shundan keyin eskilari "yangi" bo'lmaydi
  static Future<void> markFeedSeen([DateTime? at]) async {
    final t = at ?? DateTime.now();
    feedSeen.value = t;
    await _p?.setInt('feed_seen', t.millisecondsSinceEpoch);
  }
}
