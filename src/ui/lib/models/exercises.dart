import '../services/api/json_helpers.dart';

// Mushak guruhlari va mashqlar — "Tana xaritasi" ekrani uchun (sinov versiyasi).
// Ikki manba: shu fayldagi namunaviy ro'yxat ([exercises], o'zgarmaydi) va trener
// ilovadan qo'shgan mashqlar (Firestore `exercises` kolleksiyasi, `Db.customExercises`).
// Namunaviy nomlar o'zbekcha (kalit), ekranda `tr()` bilan tarjima qilinadi; trener
// yozgan matn tarjima qilinmaydi — qanday yozilgan bo'lsa, shunday chiqadi.

/// Mushak guruhi: [id] — `BodyMap` dagi shakllar bilan bog'laydi
class Muscle {
  final String id;
  final String name;
  const Muscle(this.id, this.name);
}

const muscles = [
  Muscle('chest', "Ko'krak"),
  Muscle('shoulders', 'Yelka'),
  Muscle('biceps', "Qo'lning oldi (biceps)"),
  Muscle('triceps', "Qo'lning orqasi (triceps)"),
  Muscle('forearms', 'Bilak'),
  Muscle('abs', 'Qorin (press)'),
  Muscle('back', 'Qanot (orqa)'),
  Muscle('traps', 'Trapetsiya'),
  Muscle('glutes', 'Dumba'),
  Muscle('quads', 'Sonning oldi'),
  Muscle('hamstrings', 'Sonning orqasi'),
  Muscle('calves', 'Boldir'),
];

Muscle? muscleById(String id) {
  for (final m in muscles) {
    if (m.id == id) return m;
  }
  return null;
}

/// Mashq darajalari: kalit (bazada) → o'zbekcha nom (ekranda `tr()` bilan)
const levels = {
  'beginner': 'Boshlovchi',
  'middle': "O'rta daraja",
  'pro': 'Professional',
};

class ExerciseVideo {
  final String status;
  final String url;
  const ExerciseVideo(this.status, this.url);
}

class Exercise {
  /// Firestore hujjat id'si; namunaviy (koddagi) mashqda bo'sh
  final String id;
  final String name;

  /// Asosiy ishlaydigan mushak ([Muscle.id])
  final String muscle;

  /// Yordamchi mushaklar
  final List<String> also;

  /// Yondashuv × takror, masalan "4 × 10"
  final String sets;

  /// Qisqa maslahat: qanday bajariladi
  final String tip;

  /// Trener qo'shgan vaqt va kim qo'shgani (namunaviy mashqda yo'q)
  final DateTime? createdAt;
  final String createdBy;

  /// Trener namunaviy mashqni o'zgartirgan bo'lsa (masalan video qo'shgan) — o'sha
  /// namunaviy mashqning nomi. Bunday yozuv ro'yxatda namunaviyning O'RNIGA chiqadi;
  /// o'chirilsa — namunaviy asl holiga qaytadi. Yangi mashqda bo'sh.
  final String base;

  /// Daraja: '' (belgilanmagan), 'beginner', 'middle', 'pro' ([levels]). Faqat trener va bosh
  /// admin ko'radi — shogird ekranida chiqmaydi.
  final String level;

  final bool hasVideo;

  final String videoStatus;

  static const maxVideoBytes = 100 * 1024 * 1024;

  static const videoTypes = {
    'mp4': 'video/mp4',
    'm4v': 'video/mp4',
    'mov': 'video/quicktime',
    'qt': 'video/quicktime',
    'webm': 'video/webm',
  };

  static String? videoContentType(String name, [String? mime]) {
    final m = (mime ?? '').toLowerCase().split(';').first.trim();
    if (videoTypes.containsValue(m)) return m;
    final dot = name.lastIndexOf('.');
    if (dot < 0) return null;
    return videoTypes[name.substring(dot + 1).toLowerCase()];
  }

  const Exercise(
    this.name,
    this.muscle,
    this.sets,
    this.tip, {
    this.also = const [],
    this.id = '',
    this.createdAt,
    this.createdBy = '',
    this.base = '',
    this.level = '',
    this.hasVideo = false,
    this.videoStatus = '',
  });

  bool get videoProcessing => videoStatus == 'processing';
  bool get videoFailed => videoStatus == 'failed';

  /// Trener qo'shganmi (tahrirlash va o'chirish mumkin); namunaviy mashq — yo'q
  bool get isCustom => id.isNotEmpty;

  /// Namunaviy mashqning trener o'zgartirgan nusxasimi
  bool get isOverride => base.isNotEmpty;

  /// "Bajardim" belgisi uchun barqaror kalit (kunlik yozuvda saqlanadi): trener qo'shgan
  /// mashqda hujjat id'si, namunaviyda (o'zgartirilgan bo'lsa ham) — asl o'zbekcha nomi
  String get key => isOverride ? base : (isCustom ? 'c:$id' : name);

  /// Yaqinda qo'shilganmi — shogirdga "YANGI" belgisi bilan ko'rsatiladi
  bool isNew([DateTime? now]) =>
      !isOverride && createdAt != null && (now ?? DateTime.now()).difference(createdAt!) < newFor;

  static const newFor = Duration(days: 7);

  /// Bazadagi yozuvdan; noto'g'ri mushak yoki bo'sh nom — null (ro'yxatga tushmaydi)
  static Exercise? fromMap(String id, Map<String, dynamic> m) {
    final name = (m['name'] ?? '').toString().trim();
    final muscle = (m['muscle'] ?? '').toString();
    if (name.isEmpty || muscleById(muscle) == null) return null;
    final at = m['createdAt'];
    return Exercise(
      name,
      muscle,
      (m['sets'] ?? '').toString(),
      (m['tip'] ?? '').toString(),
      also: [
        for (final a in (m['also'] as List? ?? const []))
          if (a != muscle && muscleById(a.toString()) != null) a.toString(),
      ],
      id: id,
      createdAt: at is int ? DateTime.fromMillisecondsSinceEpoch(at) : null,
      createdBy: (m['createdBy'] ?? '').toString(),
      base: (m['base'] ?? '').toString(),
      level: levels.containsKey(m['level']) ? m['level'] as String : '',
    );
  }

  static Exercise? fromJson(Map<String, dynamic> j) {
    final name = jsonString(j['name']).trim();
    final muscle = jsonString(j['muscle']);
    if (name.isEmpty || muscleById(muscle) == null) return null;
    final level = jsonString(j['level']);
    return Exercise(
      name,
      muscle,
      jsonString(j['sets']),
      jsonString(j['tip']),
      also: [
        for (final a in jsonStrings(j['also']))
          if (a != muscle && muscleById(a) != null) a,
      ],
      id: jsonString(j['id']),
      createdAt: jsonDate(j['created_at']),
      createdBy: jsonString(j['created_by']),
      base: jsonString(j['base']),
      level: levels.containsKey(level) ? level : '',
      hasVideo: j['has_video'] == true,
      videoStatus: jsonString(j['video_status']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'muscle': muscle,
        'sets': sets,
        'tip': tip,
        'also': also,
        'createdAt': (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
        'createdBy': createdBy,
        'base': base,
        'level': level,
      };
}

const exercises = [
  // ko'krak
  Exercise('Shtanga bilan yotib siqish', 'chest', '4 × 8–10',
      "Kuraklarni siqib yoting, shtangani ko'krak o'rtasiga tushiring.",
      also: ['triceps', 'shoulders']),
  Exercise('Gantel bilan qiya skameykada siqish', 'chest', '3 × 10–12',
      "Skameyka 30° qiya. Ko'krakning tepa qismi ishlaydi.",
      also: ['shoulders', 'triceps']),
  Exercise('Otjimaniya', 'chest', '3 × 15',
      "Tana tekis, tirsaklar 45° burchakda. Ko'krak polga yaqin tushsin.",
      also: ['triceps', 'shoulders', 'abs']),
  // yelka
  Exercise("Gantelni tepaga ko'tarish (o'tirib)", 'shoulders', '4 × 10',
      "Bel tik, gantellarni quloq balandligidan tepaga siqing.",
      also: ['triceps', 'traps']),
  Exercise("Gantelni yonga ko'tarish", 'shoulders', '3 × 12–15',
      "Tirsak biroz bukilgan, yelka balandligigacha. Silkitmang.",
      also: ['traps']),
  Exercise("Egilib gantelni yonga ochish", 'shoulders', '3 × 12–15',
      'Bel tekis, oldinga egiling. Yelkaning orqa qismi ishlaydi.',
      also: ['back', 'traps']),
  // biceps
  Exercise("Shtangani tik turib bukish", 'biceps', '4 × 10',
      "Tirsaklar tanaga yopishgan, tanani tebratmang.",
      also: ['forearms']),
  Exercise('Gantel bilan navbatma-navbat bukish', 'biceps', '3 × 12',
      "Ko'tarayotganda kaftni tashqariga burang.",
      also: ['forearms']),
  Exercise('"Bolg\'a" usulida bukish', 'biceps', '3 × 12',
      "Kaftlar bir-biriga qaragan holda. Bilak ham kuchli ishlaydi.",
      also: ['forearms']),
  // triceps
  Exercise('Brusda siqilish', 'triceps', '3 × 8–12',
      "Tana tik, tirsaklar orqaga qaraydi. Chuqur tushmang.",
      also: ['chest', 'shoulders']),
  Exercise('Blokda pastga siqish', 'triceps', '4 × 12',
      "Tirsaklar tanaga yopishgan, faqat bilak harakatlanadi."),
  Exercise("Gantelni bosh orqasidan ko'tarish", 'triceps', '3 × 12',
      "Tirsaklar tepaga qaraydi va ochilib ketmaydi.",
      also: ['shoulders']),
  // bilak
  Exercise('Shtanga bilan kaftni bukish', 'forearms', '3 × 15',
      "Bilak sonda yotadi, faqat kaft harakatlanadi."),
  Exercise('Turnikda osilib turish', 'forearms', '3 × 30–40 soniya',
      "To'liq osiling, yelkalarni bo'shashtirmang.",
      also: ['back']),
  Exercise("\"Fermer yurishi\"", 'forearms', '3 × 30 metr',
      "Og'ir gantellarni ushlab, tik qomat bilan yuring.",
      also: ['traps', 'abs']),
  // qorin
  Exercise(
      'Yotib tanani bukish', 'abs', '3 × 20', "Belni poldan uzmang, iyakni ko'krakka tortmang."),
  Exercise(
      "Osilib oyoqni ko'tarish", 'abs', '3 × 12', "Tebranmasdan, tizzalarni ko'krakka torting.",
      also: ['forearms']),
  Exercise('Planka', 'abs', '3 × 40–60 soniya', "Tana bir chiziqda, bel pastga cho'kmasin.",
      also: ['shoulders', 'glutes']),
  // qanot
  Exercise(
      'Turnikda tortilish', 'back', '4 × 8–10', "Ko'krakni turnikka torting, kuraklarni siqing.",
      also: ['biceps', 'forearms']),
  Exercise("Egilib shtangani tortish", 'back', '4 × 10', "Bel tekis, shtangani qoringa torting.",
      also: ['biceps', 'traps']),
  Exercise(
      'Giperekstenziya', 'back', '3 × 15', "Belning pastki qismi ishlaydi. Keskin harakat qilmang.",
      also: ['glutes', 'hamstrings']),
  // trapetsiya
  Exercise('Gantel bilan yelka qisish', 'traps', '4 × 12–15',
      "Yelkalarni quloqqa torting, tepada 1 soniya ushlang.",
      also: ['forearms']),
  Exercise("Shtangani iyakka tortish", 'traps', '3 × 12', "Tirsaklar kaftdan baland ko'tariladi.",
      also: ['shoulders']),
  Exercise(
      "Blokni yuzga tortish", 'traps', '3 × 15', "Arqonni peshonaga torting, tirsaklarni yoying.",
      also: ['shoulders', 'back']),
  // dumba
  Exercise("Shtanga bilan tosni ko'tarish", 'glutes', '4 × 10–12',
      "Kuraklar skameykada, tepada dumbani siqing.",
      also: ['hamstrings']),
  Exercise("Oldinga qadam tashlab o'tirish", 'glutes', '3 × 12',
      "Qadam keng, oldingi tizza oyoq uchidan o'tmasin.",
      also: ['quads', 'hamstrings']),
  Exercise("Oyoqni orqaga ko'tarish (blokda)", 'glutes', '3 × 15',
      "Belni bukmasdan, oyoqni dumba kuchi bilan ko'taring.",
      also: ['hamstrings']),
  // sonning oldi
  Exercise("Shtanga bilan o'tirib-turish", 'quads', '4 × 8–10',
      "Bel tekis, tizzalar oyoq uchi yo'nalishida. Son polga parallel bo'lguncha.",
      also: ['glutes', 'hamstrings', 'abs']),
  Exercise('Oyoq bilan platformani siqish', 'quads', '4 × 12',
      "Tizzani oxirigacha to'g'rilamang, bel suyanchiqdan uzilmasin.",
      also: ['glutes']),
  Exercise("O'tirib oyoqni yozish", 'quads', '3 × 15', "Tepada 1 soniya ushlab, sekin tushiring."),
  // sonning orqasi
  Exercise("To'g'ri oyoqda egilish (rumin tortishi)", 'hamstrings', '4 × 10',
      "Bel tekis, tosni orqaga suring. Shtanga oyoq bo'ylab sirpanadi.",
      also: ['glutes', 'back']),
  Exercise('Yotib oyoqni bukish', 'hamstrings', '3 × 12', "Tosni skameykadan ko'tarmang."),
  Exercise("\"Xayrli tong\" egilishi", 'hamstrings', '3 × 12',
      "Shtanga yelkada, bel tekis holda oldinga egiling.",
      also: ['back', 'glutes']),
  // boldir
  Exercise("Tik turib oyoq uchiga ko'tarilish", 'calves', '4 × 15–20',
      "Tepada 1 soniya ushlang, pastda to'liq cho'zing."),
  Exercise(
      "O'tirib oyoq uchiga ko'tarilish", 'calves', '3 × 20', "Sekin va to'liq amplituda bilan."),
  Exercise('Arqonda sakrash', 'calves', '3 × 1 daqiqa', "Oyoq uchida, past sakrang.",
      also: ['shoulders', 'forearms']),
];

/// Nomni solishtirish uchun: kichik harf, tutuq belgisi va ortiqcha bo'shliqsiz
/// ("Gantel  bilan" va "gantel bilan", "qo'l" va "qo‘l" — bir xil)
String exerciseKey(String name) => name
    .toLowerCase()
    .replaceAll(RegExp("[’'ʻ‘`ʼ\"«»]"), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Hamma mashq: trener qo'shgan yangilar va namunaviylar (trener o'zgartirgani — o'z
/// nusxasi bilan almashtirilgan)
List<Exercise> allExercises([List<Exercise> custom = const []]) {
  final over = {
    for (final e in custom)
      if (e.isOverride) e.base: e,
  };
  return [
    ...custom.where((e) => !e.isOverride).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0))),
    for (final e in exercises) over[e.name] ?? e,
  ];
}

/// [name] nomli mashq allaqachon bormi ([custom] bilan birga hamma mashq ichida).
/// Tahrirlanayotgan mashqning o'zi hisobga olinmaydi: [exceptId] — bazadagi id'si,
/// [exceptBase] — namunaviy nomi. Bor bo'lsa — o'sha mashq.
Exercise? sameExercise(String name, List<Exercise> custom,
    {String exceptId = '', String exceptBase = ''}) {
  final key = exerciseKey(name);
  if (key.isEmpty) return null;
  for (final e in allExercises(custom)) {
    if (e.isCustom && e.id == exceptId) continue;
    if (exceptBase.isNotEmpty && (e.base == exceptBase || (!e.isCustom && e.name == exceptBase))) {
      continue;
    }
    if (exerciseKey(e.name) == key) return e;
  }
  return null;
}

/// Shogird ko'radigan [muscleId] mashqlari:
/// 1) trener shu shogirdga tanlagan bo'lsa ([program]) — faqat shular, trener tanlagan
///    tartibda (o'chirilgan mashq kaliti tashlab ketiladi);
/// 2) tanlamagan bo'lsa (yoki tanlanganlarning hammasi o'chirilgan) — "Boshlovchi" mashqlar;
/// 3) ular ham bo'lmasa — mushakning hamma mashqi.
List<Exercise> exercisesForStudent(
  String muscleId,
  List<Exercise> custom,
  Map<String, List<String>> program,
) {
  final all = exercisesFor(muscleId, custom);
  final chosen = program[muscleId] ?? const [];
  if (chosen.isNotEmpty) {
    final byKey = {for (final e in all) e.key: e};
    final out = [
      for (final k in chosen)
        if (byKey[k] case final e?) e,
    ];
    if (out.isNotEmpty) return out;
  }
  final easy = all.where((e) => e.level == 'beginner').toList();
  return easy.isNotEmpty ? easy : all;
}

/// [muscleId] mashqlari: avval trener qo'shgan yangilar (eng yangisi tepada), keyin
/// namunaviylar (trener o'zgartirgani — o'z nusxasi bilan, o'sha joyida)
List<Exercise> exercisesFor(String muscleId, [List<Exercise> custom = const []]) =>
    allExercises(custom).where((e) => e.muscle == muscleId).toList();
