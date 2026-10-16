# Diamond (Flutter + ZalPro API)

> 📌 **Loyihaning to’liq holati bitta faylda: [DAVOM.md](DAVOM.md)** — ishni davom
> ettirish uchun avval o’shani o’qing. Bu fayl tafsilotlar uchun qoldirilgan.

Zal mijozlari uchun ovqatlanish rejasi ilovasi. Uch rol: **user** (shogird), **admin** (trener)
va **owner** (bosh admin).

> **📘 To'liq foydalanuvchi qo'llanmasi (o'rnatish, ishlatish, havolalar) — [QOLLANMA.md](QOLLANMA.md).**
> **Istalgan kompyuterda davom ettirish:** `powershell -ExecutionPolicy Bypass -File .\start.ps1`
> Ishlab chiqish holati va ochiq masalalar — [HOLAT.md](HOLAT.md).
>
> 📱 Ilovani yuklab olish: **https://kotta-qani-09111753.web.app**

## Imkoniyatlar

**User:** ro'yxatdan o'tish, anketa (jins, yosh, bo'y, vazn, faollik), kunlik norma va BMI hisobi,
bugungi ovqat rejasi (vaqtlar, gramm, kaloriya), "yedim" belgisi, suv hisobi,
vazn kiritish va grafik, trener bilan chat.

**Admin:** mijozlar ro'yxati va progressi, mahsulotlar bazasi (100 g uchun KBJU),
reja yaratish/nusxalash/tahrirlash, rejani mijozga biriktirish (normadan farq qilsa ⚠),
mijoz bilan chat. "Diamond shablonidan boshlash" tugmasi tayyor rejani yaratadi.

## Tez ishga tushirish

Ilova Firebase'siz, faqat ZalPro FastAPI serveri bilan ishlaydi. Manzil build vaqtida beriladi:
`flutter run -d chrome --dart-define=API_URL=http://localhost:8000`
(`flutter build apk --release --dart-define=API_URL=http://<IP>:8000`).

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

Skript `flutter pub get` qilib, ilovani Chrome'da ochadi: **http://localhost:5173**.
Kompyuter va telefon **bitta bazani** ko'radi.

Kerak: **Flutter 3.47+** (Dart 3.13+) va Chrome.
Chrome yo'q bo'lsa: `flutter run -d edge --web-port 5173`.

### Lokal emulyator (ixtiyoriy, akkauntsiz sinov)

Haqiqiy bazaga tegmasdan sinash uchun: `lib/main.dart` da `useEmulator = true` qiling va
Java 21 + `firebase-tools` o'rnatilgan bo'lsin (`npm install -g firebase-tools`).

```powershell
# 1-terminal: Auth + Firestore emulyatorlari (UI: http://localhost:4000)
powershell -ExecutionPolicy Bypass -File .\emulators.ps1

# 2-terminal: ilova
flutter run -d chrome --web-port 5173
```

Ma'lumotlar `.emulator-data` ga emulyator to'xtaganda (Ctrl+C) saqlanadi.
Sinovdan keyin `useEmulator = false` ga qaytaring.

## Admin qilish

Trener akkaunti allaqachon bor (yuqoridagi raqam/parol). Yangi admin kerak bo'lsa:

1. Ilovada oddiy ro'yxatdan o'ting.
2. [Firebase Console](https://console.firebase.google.com/project/kotta-qani-09111753/firestore) →
   Firestore → `users` → o'z hujjatingiz → `role` maydonini `admin` qiling.
3. Ilovaga qayta kiring — admin panel ochiladi.

## Birinchi sozlash (admin)

1. **Mahsulotlar** → "Standart mahsulotlarni qo'shish".
2. **Rejalar** → "Diamond shablonidan boshlash" → saqlash.
3. Erkaklar uchun nusxa olib, porsiyalarni kattalashtiring.
4. **Mijozlar** → mijozni tanlang → rejani biriktiring.

## Rollar

| Rol | Kim | Nima ko'radi |
|---|---|---|
| `user` | shogird | o'z rejasi, progressi, trener bilan chat |
| `admin` | trener | Mijozlar, Rejalar, Mahsulotlar |
| `owner` | **bosh admin** (zal egasi) | yuqoridagilar **+ Xodimlar** bo'limi |

Bosh admin: trener tayinlaydi/oladi, har trenerning shogirdlarini ko'radi,
shogirdni trenerga biriktiradi, akkaunt o'chiradi. Rolni **faqat** bosh admin
o'zgartira oladi — [firestore.rules](firestore.rules) bilan himoyalangan.

Birinchi kirishda trener panelida "Bosh admin tayinlanmagan" banneri chiqadi —
"Men" tugmasi hozirgi akkauntni bosh admin qiladi (bir marta).

## Ilova ikonkasi

Logotip: `assets/icon/logo_src.jpg`. O'zgartirilsa:

```powershell
dart run tools/make_icon.dart      # kvadrat + shaffof variantlarni yasaydi
dart run flutter_launcher_icons    # barcha o'lchamlarni chiqaradi
```

## Tekshiruv va yig'ish

```powershell
flutter analyze
flutter test

# Xavfsizlik qoidalari (lokal emulyatorda, 33 ta holat)
firebase emulators:start --only firestore --project demo-rules-test
cd tools\rules_test; npm install; node test.mjs

# APK (har bir protsessor uchun alohida, ~20 MB)
flutter build apk --release --split-per-abi

# Yuklab olish sahifasini yangilash (havola o'zgarmaydi)
copy build\app\outputs\flutter-apk\app-arm64-v8a-release.apk public\app\kq.bin
copy build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk public\app\kq-eski.bin
firebase deploy --only hosting
```

## Joylash (deploy)

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy.ps1
```

Kirishni tekshiradi (kerak bo'lsa brauzer ochiladi), so'ng `firestore:rules` va
`hosting` ni joylaydi.

> **Tartib muhim:** avval ilovaga trener bo'lib kiring va "Bosh admin tayinlanmagan"
> bannerida **"Men"** tugmasini bosing — keyingina qoidalarni joylang. Yangi qoidalarda
> rolni faqat bosh admin o'zgartira oladi.

## Tuzilma

```
lib/
  main.dart                   Firebase ulanishi, tema, keng ekran ramkasi
  theme.dart                  Ranglar va Material 3 tema (light/dark)
  firebase_options.dart       Firebase sozlamalari (flutterfire configure)
  models/models.dart          AppUser, Food, MealItem, Meal, Plan, WeightLog, ChatMessage
  services/db.dart            Firebase Auth + Firestore, Riverpod providerlar
  widgets/ui.dart             Umumiy UI komponentlar
  widgets/food_image.dart     Mahsulot rasmi (nom -> rasm), rasm manbalari oynasi
  screens/auth/               AuthGate (rolga qarab yo'naltirish), Login
  screens/user/               Bugun, Progress, Chat, Profil, Anketa
  screens/admin/              Mijozlar, Rejalar (editor + shablon), Mahsulotlar, Xodimlar
assets/foods/                 19 ta mahsulot rasmi; assets/credits.txt — mualliflar
test/widget_test.dart         Unit testlar (16 ta)
firestore.rules               Xavfsizlik qoidalari
firebase.json, .firebaserc    Firebase (hosting + firestore + emulyator)
public/                       Yuklab olish sahifasi va APK fayllari
start.ps1                     Ilovani ishga tushirish (haqiqiy Firebase)
emulators.ps1                 Faqat lokal emulyator
usb.ps1, internet.ps1         Telefonni lokal emulyatorga ulash (endi shart emas)
```

## Keyingi qadamlar

- Push-eslatmalar (firebase_messaging + flutter_local_notifications) yoki kunlik SMS ratsion
- Mashg'ulotlar bo'limi
- Payme / Click obuna
- Rus tili
