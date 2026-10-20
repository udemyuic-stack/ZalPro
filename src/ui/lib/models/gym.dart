import '../services/api/json_helpers.dart';

// Zal: haftasiga 3 mashg'ulot. Shogird o'ziga qulay 3 kunni tanlaydi,
// mashg'ulotlar tanlangan kunlarga tartib bo'yicha tushadi.

/// 3 ta mashg'ulot (tartib bilan)
const workoutGroups = [
  "Ko'krak (grud) + qo'lning oldi (biceps)",
  'Qanot (orqa) + oyoq',
  "Yelka + qo'lning orqasi (triceps)",
];

/// Har mashg'ulotda ishlaydigan mushak guruhlari ([workoutGroups] bilan bir tartibda;
/// id'lar — `exercises.dart` dagi [Muscle.id]). Nomida yo'q mayda guruhlar yaqiniga
/// qo'shilgan: bilak — qo'l kuniga, qorin — oyoq kuniga, trapetsiya — yelka kuniga
/// (taxminiy taqsimot, trener tasdiqlashi kerak).
const workoutMuscles = [
  ['chest', 'biceps', 'forearms'],
  ['back', 'quads', 'hamstrings', 'glutes', 'calves', 'abs'],
  ['shoulders', 'triceps', 'traps'],
];

/// Shu hafta kuni ishlaydigan mushaklar (dam olish kuni yoki kunlar tanlanmagan — bo'sh)
List<String> musclesFor(List<int> days, int weekday) {
  if (!validGymDays(days)) return const [];
  if (isEveryDay(days)) return [for (final g in workoutMuscles) ...g];
  final i = ([...days]..sort()).indexOf(weekday);
  return i < 0 ? const [] : workoutMuscles[i];
}

int? parseFeedback(Object? v) => v is int && v >= 1 && v <= 3 ? v : null;

/// Bugungi mashg'ulot holati (kunlik yozuvda: `users/{uid}/days/{sana}`)
class WorkoutProgress {
  /// Shogird "Mashg'ulotni boshlash" ni bosganmi
  final bool started;

  /// Bajarilgan mashqlar kalitlari (`Exercise.key`)
  final Set<String> done;

  final int? feedback;
  const WorkoutProgress({this.started = false, this.done = const {}, this.feedback});

  factory WorkoutProgress.fromJson(Map<String, dynamic> j) => WorkoutProgress(
        started: jsonBool(j['gym_started']),
        done: jsonStrings(j['gym_done']).toSet(),
        feedback: parseFeedback(j['feedback']),
      );
}

/// Navbatdagi mushak: [plan] tartibida birinchi tugallanmagani ([keysOf] — mushakning
/// mashq kalitlari). Mashqi yo'q mushak o'tkazib yuboriladi. Hammasi tugagan — null.
/// Qoida (zal egasi): bir mushak mashqlari tugamaguncha keyingisi ochilmaydi.
String? activeMuscle(List<String> plan, Set<String> done, List<String> Function(String) keysOf) {
  for (final m in plan) {
    if (keysOf(m).any((k) => !done.contains(k))) return m;
  }
  return null;
}

/// [muscle] haftaning qaysi kunida ishlaydi (rejada yo'q yoki kunlar tanlanmagan — null)
int? weekdayOfMuscle(List<int> days, String muscle) {
  if (!validGymDays(days)) return null;
  final sorted = [...days]..sort();
  if (isEveryDay(days)) return workoutMuscles.any((g) => g.contains(muscle)) ? sorted.first : null;
  for (var i = 0; i < workoutMuscles.length; i++) {
    if (workoutMuscles[i].contains(muscle)) return sorted[i];
  }
  return null;
}

/// Hafta kunlari: DateTime.weekday bo'yicha (1 — dushanba)
const weekdayNames = {
  1: 'Dushanba',
  2: 'Seshanba',
  3: 'Chorshanba',
  4: 'Payshanba',
  5: 'Juma',
  6: 'Shanba',
  7: 'Yakshanba',
};

const weekdayShort = {1: 'Du', 2: 'Se', 3: 'Chor', 4: 'Pay', 5: 'Ju', 6: 'Sha', 7: 'Yak'};

/// Ikki variant (zal qoidasi): Seshanba/Payshanba/Shanba yoki Dushanba/Chorshanba/Juma
const evenDays = [2, 4, 6]; // Se, Pay, Sha
const oddDays = [1, 3, 5]; // Du, Chor, Ju

const everyDays = [1, 2, 3, 4, 5, 6, 7];

const everyDayLabel = "Har kuni — hamma guruh";

bool isEveryDay(List<int> days) => ([...days]..sort()).join(',') == everyDays.join(',');

/// Tanlov to'g'rimi: uch variantdan biri
bool validGymDays(List<int> days) {
  final s = ([...days]..sort()).join(',');
  return s == evenDays.join(',') || s == oddDays.join(',') || s == everyDays.join(',');
}

/// Shu hafta kuni qaysi mashg'ulot (dam olish kuni bo'lsa null)
String? workoutFor(List<int> days, int weekday) {
  if (!validGymDays(days)) return null;
  if (isEveryDay(days)) return everyDayLabel;
  final sorted = [...days]..sort();
  final i = sorted.indexOf(weekday);
  return i < 0 ? null : workoutGroups[i];
}

/// Keyingi mashg'ulot kuni (bugundan keyin) — (hafta kuni, mashg'ulot)
(int, String)? nextWorkout(List<int> days, int todayWeekday) {
  if (!validGymDays(days)) return null;
  for (var k = 1; k <= 7; k++) {
    final wd = (todayWeekday - 1 + k) % 7 + 1;
    final w = workoutFor(days, wd);
    if (w != null) return (wd, w);
  }
  return null;
}

/// Shogird chatda bugun zalga kela olmasligini yozganmi ("bugun kelolmayman", "borolmayman"...)
/// Og'zaki yozuvlar ham: "kelolmayman", "kela olmayman", "boromiman", "borolmiman", "kelmayman"
bool saysCantCome(String text) => RegExp(
      r"(kel|bor)(a\s*)?(ol|o)?\s*m[ai]y?man|uyda\s+qil",
      caseSensitive: false,
    ).hasMatch(text.replaceAll(RegExp("[’'ʻ‘`ʼ]"), ''));
