import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../l10n/tr.dart';
import '../models/models.dart';
import 'reminders.dart';
import 'settings.dart';

/// Telefon bildirishnomalari (faqat Android; web/boshqa platformalarda hech narsa qilmaydi).
///  * ovqat vaqti eslatmasi — har kuni rejadagi vaqtlarda (server kerak emas)
///  * haftalik vazn eslatmasi (server kerak emas)
///  * yangi chat xabari / yangi reja — faqat ilova xotirada bo'lsa (lokal)
class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const channelId = 'diamond_general';

  /// Kanal tavsifi — telefonning bildirishnoma sozlamalarida ko'rinadi (ilova tilida)
  static String get _channelDesc => tr('Ovqat vaqti, vazn, chat va reja eslatmalari');

  static NotificationDetails get _details => NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Aura Fit',
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      );

  // Bildirishnoma id oralig'lari
  static const _mealBase = 1000; // 1000..1099 — ovqat mahallari
  static const _weighInId = 1100;
  static const _restEndId = 1101;
  static const _maxMeals = 20;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    if (!supported || _ready) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Tashkent'));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _android?.createNotificationChannel(AndroidNotificationChannel(
        channelId,
        'Aura Fit',
        description: _channelDesc,
        importance: Importance.high,
      ));
      _ready = true;
    } catch (e) {
      debugPrint('Bildirishnomalar ishga tushmadi: $e');
    }
  }

  /// Android 13+ da ruxsat so'raydi (bir marta tizim oynasi chiqadi)
  static Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await _android?.requestNotificationsPermission();
    } catch (_) {}
  }

  static tz.TZDateTime _tz(DateTime d) => tz.TZDateTime.from(d, tz.local);

  /// Ovqat eslatmalarini rejaga qarab qayta rejalashtiradi (reja yo'q yoki o'chirilgan — bekor)
  static Future<void> scheduleMeals(Plan? plan) async {
    if (!_ready) return;
    for (var i = 0; i < _maxMeals; i++) {
      await _plugin.cancel(id: _mealBase + i);
    }
    if (plan == null || !AppSettings.mealReminders) return;
    final now = DateTime.now();
    // Haftalik rejada bugungi kun menyusi olinadi (ilova ochilganda qayta rejalashtiriladi)
    final meals = plan.mealsFor(now.weekday);
    for (var i = 0; i < meals.length && i < _maxMeals; i++) {
      final meal = meals[i];
      final t = parseMealTime(meal.time);
      if (t == null) continue;
      final (title, body) = mealReminderText(meal);
      await _plugin.zonedSchedule(
        id: _mealBase + i,
        scheduledDate: _tz(nextDailyAt(now, t.$1, t.$2)),
        notificationDetails: _details,
        // aniq vaqt ruxsati talab qilinmasin — bir necha daqiqa farq qilishi mumkin
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        title: title,
        body: body,
      );
    }
  }

  /// Haftalik vazn eslatmasi (bitta, keyingi o'lchov kuni ertalab)
  static Future<void> scheduleWeighIn(DateTime? lastWeighIn) async {
    if (!_ready) return;
    await _plugin.cancel(id: _weighInId);
    if (!AppSettings.weighInReminder) return;
    await _plugin.zonedSchedule(
      id: _weighInId,
      scheduledDate: _tz(weighInReminderAt(lastWeighIn, DateTime.now())),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: tr('Vazn kiritish kuni'),
      body: tr("Ertalab nahorga tortilib, Progress bo'limida vazningizni kiriting"),
    );
  }

  static Future<void> scheduleRestEnd(DateTime endsAt) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _restEndId);
      if (!endsAt.isAfter(DateTime.now())) return;
      await _plugin.zonedSchedule(
        id: _restEndId,
        scheduledDate: _tz(endsAt),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: tr('Dam olish tugadi'),
        body: tr('Keyingi setga tayyor'),
      );
    } catch (e) {
      debugPrint('Dam olish bildirishnomasi rejalanmadi: $e');
    }
  }

  static Future<void> cancelRestEnd() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _restEndId);
    } catch (_) {}
  }

  /// Darhol ko'rsatish. [tag] bir xil bo'lsa (masalan xabar id) push bilan takrorlanmaydi.
  static Future<void> showNow(String tag, String title, String body) async {
    if (!_ready) return;
    await _plugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Aura Fit',
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          tag: tag,
        ),
      ),
    );
  }

  /// Chiqishda: rejalashtirilgan eslatmalarni bekor qilish
  static Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }
}
