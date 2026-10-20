from typing import Any

# Ovqatlar: nomi, kkal, oqsil, yog', uglevod — 100 g uchun (USDA FoodData Central o'rtachasi).
FOODS: tuple[tuple[str, float, float, float, float], ...] = (
    ("Suli yormasi (quruq)", 389, 16.9, 6.9, 66.3),
    ("Grechka (quruq)", 343, 13.3, 3.4, 71.5),
    ("Guruch (quruq)", 365, 7.1, 0.7, 80.0),
    ("Makaron (quruq)", 371, 13.0, 1.5, 74.7),
    ("Non (bug'doy)", 265, 9.0, 3.2, 49.0),
    ("Kartoshka (qaynatilgan)", 87, 1.9, 0.1, 20.1),
    ("Tovuq ko'kragi (pishirilgan)", 165, 31.0, 3.6, 0.0),
    ("Tovuq soni (pishirilgan)", 209, 26.0, 10.9, 0.0),
    ("Mol go'shti (pishirilgan)", 250, 26.0, 15.0, 0.0),
    ("Qo'y go'shti (pishirilgan)", 294, 25.6, 20.9, 0.0),
    ("Indeyka ko'kragi (pishirilgan)", 135, 30.0, 0.7, 0.0),
    ("Losos baliq (pishirilgan)", 206, 22.1, 12.4, 0.0),
    ("Orqa suzgichli tuna (konserva)", 116, 25.5, 0.8, 0.0),
    ("Tuxum (qaynatilgan)", 155, 12.6, 10.6, 1.1),
    ("Tuxum oqi", 52, 10.9, 0.2, 0.7),
    ("Tvorog (past yog'li)", 98, 11.1, 4.3, 3.4),
    ("Sut (2.5%)", 52, 3.4, 2.5, 4.8),
    ("Qatiq (past yog'li)", 56, 5.7, 1.5, 4.7),
    ("Grek yogurti (0%)", 59, 10.2, 0.4, 3.6),
    ("Pishloq (Gollandiya)", 356, 25.0, 27.0, 2.2),
    ("Loviya (qaynatilgan)", 127, 8.7, 0.5, 22.8),
    ("Noxat (qaynatilgan)", 164, 8.9, 2.6, 27.4),
    ("Yasmiq (qaynatilgan)", 116, 9.0, 0.4, 20.1),
    ("Yong'oq (grek)", 654, 15.2, 65.2, 13.7),
    ("Bodom", 579, 21.2, 49.9, 21.6),
    ("Yer yong'oq", 567, 25.8, 49.2, 16.1),
    ("Mayiz", 299, 3.1, 0.5, 79.2),
    ("Xurmo", 282, 2.5, 0.4, 75.0),
    ("Banan", 89, 1.1, 0.3, 22.8),
    ("Olma", 52, 0.3, 0.2, 13.8),
    ("Apelsin", 47, 0.9, 0.1, 11.8),
    ("Qulupnay", 32, 0.7, 0.3, 7.7),
    ("Uzum", 69, 0.7, 0.2, 18.1),
    ("Pomidor", 18, 0.9, 0.2, 3.9),
    ("Bodring", 15, 0.7, 0.1, 3.6),
    ("Brokkoli", 34, 2.8, 0.4, 6.6),
    ("Sabzi", 41, 0.9, 0.2, 9.6),
    ("Ko'kat (ukrop, petrushka)", 43, 3.3, 0.8, 7.0),
    ("Zaytun yog'i", 884, 0.0, 100.0, 0.0),
    ("Asal", 304, 0.3, 0.0, 82.4),
    ("Whey protein kukuni", 400, 80.0, 6.0, 8.0),
)

# Do'kon: toifa, nomi, izoh, narx (so'm), tannarx (so'm), qoldiq.
# DIQQAT: narxlar bozor bo'yicha taxminiy — ishga tushirishdan oldin o'z narxingizga almashtiring.
PRODUCTS: tuple[tuple[str, str, str, int, int, int], ...] = (
    (
        "Protein",
        "Whey protein 2 kg",
        "Zardobdan olingan oqsil, 1 porsiyada ~24 g oqsil",
        520000,
        430000,
        15,
    ),
    ("Protein", "Whey protein 900 g", "Zardobdan olingan oqsil, sinov hajmi", 260000, 210000, 20),
    (
        "Gainer",
        "Gainer 3 kg",
        "Massa yig'ish uchun oqsil va uglevod aralashmasi",
        430000,
        350000,
        10,
    ),
    (
        "Kreatin",
        "Kreatin monogidrat 300 g",
        "Kuch va chidamlilik uchun, kuniga 5 g",
        240000,
        190000,
        25,
    ),
    ("L-Karnitin", "L-Karnitin suyuq 500 ml", "Mashqdan oldin qabul qilinadi", 180000, 140000, 12),
    (
        "L-Arginin",
        "L-Arginin kapsula 120 dona",
        "Aminokislota, kuniga 2–3 kapsula",
        150000,
        115000,
        12,
    ),
    (
        "Suv idishlari",
        "Shaker 700 ml",
        "Protein aralashtirish uchun, sharcha bilan",
        45000,
        28000,
        40,
    ),
    ("Suv idishlari", "Sport butilka 1 litr", "BPA-siz plastik", 60000, 38000, 30),
    ("Anjomlar", "Qo'lqop (zal uchun)", "Shtanga va gantel uchun, ter shimadi", 70000, 45000, 25),
    ("Anjomlar", "Sport kamar", "Og'ir mashqlar uchun bel tayanchi", 180000, 120000, 10),
    ("Anjomlar", "Arqon (sakrash)", "Ko'p qirrali, uzunligi sozlanadi", 40000, 22000, 30),
    (
        "Anjomlar",
        "Qo'l bog'ichi (lyamka)",
        "Tortish mashqlarida bilakni yengillashtiradi",
        35000,
        20000,
        30,
    ),
    ("Forma", "Diamond futbolka", "Paxtali, zalning logotipi bilan", 120000, 75000, 30),
    ("Forma", "Diamond sport shimi", "Elastik mato, tez quriydi", 160000, 100000, 20),
)

_BREAKFAST_OATS = {
    "time": "08:00",
    "title": "Nonushta",
    "items": [
        {"name": "Suli yormasi (quruq)", "grams": 80, "kcal": 311, "protein": 14},
        {"name": "Tuxum (qaynatilgan)", "grams": 110, "kcal": 171, "protein": 14},
        {"name": "Banan", "grams": 100, "kcal": 89, "protein": 1},
    ],
}
_LUNCH_CHICKEN_RICE = {
    "time": "13:00",
    "title": "Tushlik",
    "items": [
        {"name": "Tovuq ko'kragi (pishirilgan)", "grams": 200, "kcal": 330, "protein": 62},
        {"name": "Guruch (quruq)", "grams": 90, "kcal": 329, "protein": 6},
        {"name": "Pomidor", "grams": 150, "kcal": 27, "protein": 1},
    ],
}
_SNACK_COTTAGE = {
    "time": "16:30",
    "title": "Tushlikdan keyin",
    "items": [
        {"name": "Tvorog (past yog'li)", "grams": 200, "kcal": 196, "protein": 22},
        {"name": "Yong'oq (grek)", "grams": 25, "kcal": 164, "protein": 4},
    ],
}
_DINNER_FISH = {
    "time": "19:30",
    "title": "Kechki ovqat",
    "items": [
        {"name": "Losos baliq (pishirilgan)", "grams": 180, "kcal": 371, "protein": 40},
        {"name": "Brokkoli", "grams": 200, "kcal": 68, "protein": 6},
        {"name": "Kartoshka (qaynatilgan)", "grams": 200, "kcal": 174, "protein": 4},
    ],
}
_NIGHT_YOGURT = {
    "time": "22:00",
    "title": "Uyqudan oldin",
    "items": [{"name": "Grek yogurti (0%)", "grams": 250, "kcal": 148, "protein": 26}],
}
_LUNCH_BEEF_BUCKWHEAT = {
    "time": "13:00",
    "title": "Tushlik",
    "items": [
        {"name": "Mol go'shti (pishirilgan)", "grams": 150, "kcal": 375, "protein": 39},
        {"name": "Grechka (quruq)", "grams": 80, "kcal": 274, "protein": 11},
        {"name": "Bodring", "grams": 150, "kcal": 23, "protein": 1},
    ],
}
_BREAKFAST_LIGHT = {
    "time": "08:00",
    "title": "Nonushta",
    "items": [
        {"name": "Tuxum oqi", "grams": 200, "kcal": 104, "protein": 22},
        {"name": "Suli yormasi (quruq)", "grams": 50, "kcal": 195, "protein": 8},
        {"name": "Olma", "grams": 150, "kcal": 78, "protein": 0},
    ],
}
_DINNER_TURKEY = {
    "time": "19:00",
    "title": "Kechki ovqat",
    "items": [
        {"name": "Indeyka ko'kragi (pishirilgan)", "grams": 180, "kcal": 243, "protein": 54},
        {"name": "Brokkoli", "grams": 250, "kcal": 85, "protein": 7},
    ],
}

_MASS_DAY = [_BREAKFAST_OATS, _LUNCH_CHICKEN_RICE, _SNACK_COTTAGE, _DINNER_FISH, _NIGHT_YOGURT]
_CUT_DAY = [_BREAKFAST_LIGHT, _LUNCH_BEEF_BUCKWHEAT, _DINNER_TURKEY]

# Ratsionlar: nomi, izoh, taqiqlangan ovqatlar, kunlik ovqatlanish (hafta kunlari 1–7 bir xil).
PLANS: tuple[dict[str, Any], ...] = (
    {
        "title": "Massa nabor (~2800 kkal)",
        "note": "Kuniga 2.5–3 litr suv iching. Mashqdan keyin 1 porsiya protein qo'shing.",
        "forbidden": ["shakar", "gazli ichimlik", "fastfud", "chips"],
        "meals": _MASS_DAY,
    },
    {
        "title": "Ozish (~1700 kkal)",
        "note": "Kuniga 2.5 litr suv. Qadamlar soni kamida 8000. Ovqatlanish oralig'i 4–5 soat.",
        "forbidden": ["shakar", "gazli ichimlik", "qovurilgan ovqat", "shirinlik", "non (oq)"],
        "meals": _CUT_DAY,
    },
)

# Mashqlar ilovadagi namunaviy ro'yxat bilan bir xil (src/ui/lib/models/exercises.dart).
EXERCISES: tuple[tuple[str, str, str, str, tuple[str, ...]], ...] = (
    (
        "Shtanga bilan yotib siqish",
        "chest",
        "4 × 8–10",
        "Kuraklarni siqib yoting, shtangani ko'krak o'rtasiga tushiring.",
        ("triceps", "shoulders"),
    ),
    (
        "Gantel bilan qiya skameykada siqish",
        "chest",
        "3 × 10–12",
        "Skameyka 30° qiya. Ko'krakning tepa qismi ishlaydi.",
        ("shoulders", "triceps"),
    ),
    (
        "Otjimaniya",
        "chest",
        "3 × 15",
        "Tana tekis, tirsaklar 45° burchakda. Ko'krak polga yaqin tushsin.",
        ("triceps", "shoulders", "abs"),
    ),
    (
        "Gantelni tepaga ko'tarish (o'tirib)",
        "shoulders",
        "4 × 10",
        "Bel tik, gantellarni quloq balandligidan tepaga siqing.",
        ("triceps", "traps"),
    ),
    (
        "Gantelni yonga ko'tarish",
        "shoulders",
        "3 × 12–15",
        "Tirsak biroz bukilgan, yelka balandligigacha. Silkitmang.",
        ("traps",),
    ),
    (
        "Egilib gantelni yonga ochish",
        "shoulders",
        "3 × 12–15",
        "Bel tekis, oldinga egiling. Yelkaning orqa qismi ishlaydi.",
        ("back", "traps"),
    ),
    (
        "Shtangani tik turib bukish",
        "biceps",
        "4 × 10",
        "Tirsaklar tanaga yopishgan, tanani tebratmang.",
        ("forearms",),
    ),
    (
        "Gantel bilan navbatma-navbat bukish",
        "biceps",
        "3 × 12",
        "Ko'tarayotganda kaftni tashqariga burang.",
        ("forearms",),
    ),
    (
        '"Bolg\'a" usulida bukish',
        "biceps",
        "3 × 12",
        "Kaftlar bir-biriga qaragan holda. Bilak ham kuchli ishlaydi.",
        ("forearms",),
    ),
    (
        "Brusda siqilish",
        "triceps",
        "3 × 8–12",
        "Tana tik, tirsaklar orqaga qaraydi. Chuqur tushmang.",
        ("chest", "shoulders"),
    ),
    (
        "Blokda pastga siqish",
        "triceps",
        "4 × 12",
        "Tirsaklar tanaga yopishgan, faqat bilak harakatlanadi.",
        (),
    ),
    (
        "Gantelni bosh orqasidan ko'tarish",
        "triceps",
        "3 × 12",
        "Tirsaklar tepaga qaraydi va ochilib ketmaydi.",
        ("shoulders",),
    ),
    (
        "Shtanga bilan kaftni bukish",
        "forearms",
        "3 × 15",
        "Bilak sonda yotadi, faqat kaft harakatlanadi.",
        (),
    ),
    (
        "Turnikda osilib turish",
        "forearms",
        "3 × 30–40 soniya",
        "To'liq osiling, yelkalarni bo'shashtirmang.",
        ("back",),
    ),
    (
        '"Fermer yurishi"',
        "forearms",
        "3 × 30 metr",
        "Og'ir gantellarni ushlab, tik qomat bilan yuring.",
        ("traps", "abs"),
    ),
    ("Yotib tanani bukish", "abs", "3 × 20", "Belni poldan uzmang, iyakni ko'krakka tortmang.", ()),
    (
        "Osilib oyoqni ko'tarish",
        "abs",
        "3 × 12",
        "Tebranmasdan, tizzalarni ko'krakka torting.",
        ("forearms",),
    ),
    (
        "Planka",
        "abs",
        "3 × 40–60 soniya",
        "Tana bir chiziqda, bel pastga cho'kmasin.",
        ("shoulders", "glutes"),
    ),
    (
        "Turnikda tortilish",
        "back",
        "4 × 8–10",
        "Ko'krakni turnikka torting, kuraklarni siqing.",
        ("biceps", "forearms"),
    ),
    (
        "Egilib shtangani tortish",
        "back",
        "4 × 10",
        "Bel tekis, shtangani qoringa torting.",
        ("biceps", "traps"),
    ),
    (
        "Giperekstenziya",
        "back",
        "3 × 15",
        "Belning pastki qismi ishlaydi. Keskin harakat qilmang.",
        ("glutes", "hamstrings"),
    ),
    (
        "Gantel bilan yelka qisish",
        "traps",
        "4 × 12–15",
        "Yelkalarni quloqqa torting, tepada 1 soniya ushlang.",
        ("forearms",),
    ),
    (
        "Shtangani iyakka tortish",
        "traps",
        "3 × 12",
        "Tirsaklar kaftdan baland ko'tariladi.",
        ("shoulders",),
    ),
    (
        "Blokni yuzga tortish",
        "traps",
        "3 × 15",
        "Arqonni peshonaga torting, tirsaklarni yoying.",
        ("shoulders", "back"),
    ),
    (
        "Shtanga bilan tosni ko'tarish",
        "glutes",
        "4 × 10–12",
        "Kuraklar skameykada, tepada dumbani siqing.",
        ("hamstrings",),
    ),
    (
        "Oldinga qadam tashlab o'tirish",
        "glutes",
        "3 × 12",
        "Qadam keng, oldingi tizza oyoq uchidan o'tmasin.",
        ("quads", "hamstrings"),
    ),
    (
        "Oyoqni orqaga ko'tarish (blokda)",
        "glutes",
        "3 × 15",
        "Belni bukmasdan, oyoqni dumba kuchi bilan ko'taring.",
        ("hamstrings",),
    ),
    (
        "Shtanga bilan o'tirib-turish",
        "quads",
        "4 × 8–10",
        "Bel tekis, tizzalar oyoq uchi yo'nalishida. Son polga parallel bo'lguncha.",
        ("glutes", "hamstrings", "abs"),
    ),
    (
        "Oyoq bilan platformani siqish",
        "quads",
        "4 × 12",
        "Tizzani oxirigacha to'g'rilamang, bel suyanchiqdan uzilmasin.",
        ("glutes",),
    ),
    ("O'tirib oyoqni yozish", "quads", "3 × 15", "Tepada 1 soniya ushlab, sekin tushiring.", ()),
    (
        "To'g'ri oyoqda egilish (rumin tortishi)",
        "hamstrings",
        "4 × 10",
        "Bel tekis, tosni orqaga suring. Shtanga oyoq bo'ylab sirpanadi.",
        ("glutes", "back"),
    ),
    ("Yotib oyoqni bukish", "hamstrings", "3 × 12", "Tosni skameykadan ko'tarmang.", ()),
    (
        '"Xayrli tong" egilishi',
        "hamstrings",
        "3 × 12",
        "Shtanga yelkada, bel tekis holda oldinga egiling.",
        ("back", "glutes"),
    ),
    (
        "Tik turib oyoq uchiga ko'tarilish",
        "calves",
        "4 × 15–20",
        "Tepada 1 soniya ushlang, pastda to'liq cho'zing.",
        (),
    ),
    ("O'tirib oyoq uchiga ko'tarilish", "calves", "3 × 20", "Sekin va to'liq amplituda bilan.", ()),
    (
        "Arqonda sakrash",
        "calves",
        "3 × 1 daqiqa",
        "Oyoq uchida, past sakrang.",
        ("shoulders", "forearms"),
    ),
)
