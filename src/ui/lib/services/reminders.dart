import '../l10n/tr.dart';
import '../models/models.dart';

/// Eslatmalar vaqtini hisoblash — plaginga bog'liq emas (testlanadi).

/// Rejadagi "07:30" kabi vaqtni (soat, daqiqa) ga aylantiradi; noto'g'ri bo'lsa null
(int, int)? parseMealTime(String hhmm) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return (h, min);
}

/// Bugun shu vaqt hali kelmagan bo'lsa — bugun, o'tib ketgan bo'lsa — ertaga
DateTime nextDailyAt(DateTime now, int hour, int minute) {
  final today = DateTime(now.year, now.month, now.day, hour, minute);
  return today.isAfter(now) ? today : today.add(const Duration(days: 1));
}

/// Haftalik vazn eslatmasi: oxirgi o'lchovdan 7 kun keyin ertalab 08:00.
/// Muddat allaqachon kelgan bo'lsa — eng yaqin 08:00 (bugun yoki ertaga).
/// Hali o'lchov yo'q bo'lsa — eng yaqin 08:00.
DateTime weighInReminderAt(DateTime? lastWeighIn, DateTime now) {
  if (lastWeighIn != null) {
    final due = DateTime(lastWeighIn.year, lastWeighIn.month, lastWeighIn.day)
        .add(const Duration(days: weighInIntervalDays))
        .add(const Duration(hours: 8));
    if (due.isAfter(now)) return due;
  }
  return nextDailyAt(now, 8, 0);
}

/// Ovqat eslatmasi matni: "Nonushta vaqti · 07:30" / "Suli bo'tqasi, Tvorog, Tuxum oqi"
(String, String) mealReminderText(Meal meal) {
  final title =
      trf('{0} vaqti · {1}', [meal.title.isEmpty ? tr('Ovqat') : tr(meal.title), meal.time]);
  final names = meal.items.map((i) => i.name.split('(').first.trim()).where((n) => n.isNotEmpty);
  final body =
      names.isEmpty ? tr('Rejangizdagi mahalni belgilashni unutmang') : names.take(3).join(', ');
  return (title, body);
}
