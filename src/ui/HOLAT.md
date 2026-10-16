# Diamond (Kotta Qani Diet) — loyiha holati va davom ettirish

> 📌 **Loyihaning to’liq holati bitta faylda: [DAVOM.md](DAVOM.md)** — ishni davom
> ettirish uchun avval o’shani o’qing. Bu fayl tafsilotlar uchun qoldirilgan.

> Oxirgi yangilanish: **2026-09-12**. Bu fayl qilingan ishlar, hozirgi holat va loyihani
> istalgan kompyuterda davom ettirish yo'riqnomasi.

## 0. HOZIRGI HOLAT — haqiqiy Firebase'ga ulangan (2026-09-11)

- **Firebase loyiha:** `kotta-qani-09111753` (CLI akkaunti lokal `PAROLLAR.md` da).
  Auth = Email/Password (telefon+parol) yoqilgan, Firestore (eur3) yaratilgan,
  qoidalar joylangan. `lib/main.dart`: `useEmulator = false`, `firebase_options.dart` ulangan.
- **Ilovani telefonga yuklab olish (istalgan joyda ishlaydi):**
  **https://kotta-qani-09111753.web.app** — sahifadagi tugma APK beradi.
- **Trener:** telefon `+998 90 000 00 00` (maydonga `900000000`); parol lokal `PAROLLAR.md` da
  (repo ochiq, shuning uchun hujjatda parol yozilmaydi).
- **Kompyuterda:** `powershell -ExecutionPolicy Bypass -File .\start.ps1` — Chrome'da ochiladi,
  o'sha haqiqiy bazaga ulanadi (kompyuter va telefon bir xil ma'lumotni ko'radi).
- APK'ni qayta yig'ish: `flutter build apk --release --split-per-abi`. Yangi APK'ni
  `public/app/kq.bin` (arm64) va `kq-eski.bin` (armeabi) ga nusxalab,
  `firebase deploy --only hosting` bilan yangilang (Spark rejada `.apk` bloklanadi, shuning
  uchun `.bin` nomi + Content-Disposition header orqali `.apk` bo'lib yuklanadi).
- **Emulyator endi shart emas** (lokal sinov uchun `useEmulator = true` qilib qaytarsa bo'ladi).
- Owner API token: firebase-tools refresh token'idan (`~/.config/configstore/firebase-tools.json`)
  ochiq OAuth mijozi bilan access token olinadi — admin hujjatni qoidalarni chetlab yozish uchun.

## 1. Tez start (istalgan Windows kompyuter)

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

Skript `flutter pub get` qiladi va ilovani Chrome'da ochadi: **http://localhost:5173**.
Ilova to'g'ridan-to'g'ri haqiqiy Firebase'ga ulanadi — emulyator kerak emas.

| Kerak | Qayerdan |
|---|---|
| Flutter 3.47+ (Dart 3.13+) | https://docs.flutter.dev/get-started/install/windows |
| Google Chrome | (yo'q bo'lsa: `flutter run -d edge --web-port 5173`) |
| Internet | birinchi ishga tushirishda paketlar yuklanadi |
| Node.js LTS | faqat `firebase deploy` uchun |
| Java 21 + Android SDK | faqat APK yig'ish uchun |

**Kirish faqat telefon raqam + parol bilan.**
**Trener (admin) akkaunti:** telefon **`+998 90 000 00 00`** (maydonga `900000000`).
Parol lokal **`PAROLLAR.md`** faylida.

### Boshqa kompyuterga ko'chirishda
Butun papkani nusxalang. Quyidagilarni **o'tkazib yuborsa bo'ladi** (qayta yaratiladi):
`build/`, `.dart_tool/`, `android/.gradle/`, `.emulator-data/`.
**Albatta olib keting:** `assets/` (mahsulot rasmlari), `lib/firebase_options.dart`,
`public/` (yuklab olish sahifasi). Haqiqiy ma'lumotlar Firebase'da — hech narsa yo'qolmaydi.

---

## 2. Ilova haqida

Zal mijozlari uchun ovqatlanish rejasi ilovasi (Flutter + Firebase Auth + Firestore).

- **Mijoz (user):** ro'yxatdan o'tish, anketa (jins, yosh, bo'y, vazn, faollik) → kunlik
  kaloriya normasi va BMI; "Bugun" — reja, "yedim" belgisi, suv; vazn grafigi; trener bilan chat.
- **Trener (admin):** mijozlar ro'yxati va progressi, mahsulotlar bazasi (100 g uchun KBJU),
  reja yaratish/nusxalash, rejani mijozga biriktirish (normadan 300+ kkal farq qilsa ⚠), chat.
- **"Diamond shablonidan boshlash"** — trenerning 5 ta rasmdagi rejasi tayyor holda.

Admin qilish: foydalanuvchi `users/{uid}` hujjatida `role: "admin"` (emulyatorda
http://localhost:4000/firestore orqali).

---

## 3. Qilingan ishlar (xronologik)

### 3.1. Kompilyatsiya xatolari
- `profile_setup_screen.dart`: `double` kalitli **`const` map** Dartda taqiqlangan
  (`const_map_key_not_primitive_equality`) — ro'yxatga (records) almashtirildi.
- Eskirgan API'lar: `RadioListTile.groupValue/onChanged` → `RadioGroup`;
  `DropdownButtonFormField.value` → `initialValue` (+ `key`, reja o'zgarsa qayta qurilishi uchun).

### 3.2. Reja shabloni trenerning rasmlariga moslandi (`plans_screen.dart` → `kottaQaniTemplate`)
- 5 mahal: 07:00 nonushta, 10:30 protein/tvorog, 13:00 tushlik, 15:00 poldnik, 18:00 kechki.
- Poldnik yong'oq **30 g → 50 g**; kechki ovqatga "yoki 100 g fosol/noxat"; nonushtaga mayiz.
- Taqiqlanganlar: shakar, shirinliklar, non, hamirli, **mayonezli salat, shirin mevalar,
  sharbatlar, tez singuvchi uglevodlar**.
- Izoh: "1 mahal ovqatlanib ozib bo'lmaydi", kardio 40 daqiqa + protein, kechqurun uglevodsiz.
- Kunlik jami ≈ 1450 kkal (testda tekshiriladi).

### 3.3. Firebase — lokal emulyator (akkauntsiz)
- `firebase.json`, `.firebaserc` (loyiha `demo-kotta-qani`), `emulators.ps1`.
- `lib/main.dart`: `useEmulator = true`; manzil `--dart-define=EMULATOR_HOST=...` bilan beriladi
  (sukut: `localhost`). Firebase sozlanmagan bo'lsa qizil xato o'rniga ko'rsatma ekrani.
- Emulyator `0.0.0.0` da tinglaydi (tarmoqdan ulanish uchun), ma'lumotlar `.emulator-data/`.
- `firestore.rules` REST orqali tekshirildi: user o'zini admin qila olmaydi (403),
  admin bo'lmagan reja yoza olmaydi (403).
- `web/index.html`: emulyatorning pastki ogohlantirish banneri yashirildi (navigatsiyani to'sardi).

### 3.4. Dizayn (UI/UX) to'liq yangilandi
- `lib/theme.dart` — yagona dizayn tizimi (Material 3, brend qizil, 16–20 px radius,
  light/dark), `lib/widgets/ui.dart` — umumiy komponentlar (EmptyState, StatTile, KcalRing,
  Pill, GradientHeader, confirm dialog, o'zbekcha sana).
- Barcha ekranlar qayta yozildi: login (tab, parolni ko'rsatish, o'zbekcha xato matnlari),
  "Bugun" (kaloriya halqasi, 8 ta suv tomchisi, "Navbatdagi" ovqat, 🎉 bajarildi),
  progress (gradient grafik, tarix ↓/↑), profil (BMI shkala), chat (pufakchalar, sana
  ajratgichlari), anketa (jonli norma hisobi), trener paneli (statistika, qidiruv, statuslar,
  soat tanlagich, o'chirishdan oldin tasdiqlash).
- Keng ekranda (web) ilova telefon kengligida markazda ko'rinadi.
- Tuzatilgan xato: reja o'chirilganda "Bugun" cheksiz yuklanishda qolardi.

### 3.5. Mahsulot rasmlari
- 19 ta haqiqiy foto (Wikimedia Commons, faqat erkin litsenziya) → `assets/foods/*.jpg`,
  mualliflar: `assets/credits.txt` (ilovada "Rasm manbalari" tugmasi), `food_images.json`.
- `lib/widgets/food_image.dart`: rasm **nom bo'yicha** tanlanadi (kalit so'zlar),
  trener ixtiyoriy **rasm URL** kiritishi mumkin (`Food.image`, `MealItem.image`).
- Rasmlar: mahsulotlar ro'yxati, reja tahrirlovchi, mahsulot tanlash, "Bugun" kartochkalari.

### 3.6. Android / APK
- Android SDK: `%LOCALAPPDATA%\Android\Sdk` (platform 36, build-tools 36.0.0,
  NDK 28.2.13676358). Java 21 (portativ): `%LOCALAPPDATA%\jdk21\`.
  Eslatma: yangi cmdline-tools'da `sdkmanager` eskirgan — paketlarni
  `android.exe sdk install <paket>` bilan o'rnatish kerak (Gradle o'zi o'rnata olmaydi).
- `AndroidManifest.xml`: `INTERNET` ruxsati, nom "Diamond".
- APK'lar `build/app/outputs/flutter-apk/` da (`--split-per-abi` → ~20 MB).
- Telefon uchun: `usb.ps1` (USB + `adb reverse`), `main.dart` da `127.0.0.1` uchun
  host almashtirish o'chirilgan.

### 3.7. Testlar
`test/widget_test.dart` — 11 ta: kaloriya formulasi (defitsit, 1200 minimum), shablon
(vaqtlar, 50 g yong'oq, taqiqlar, kaloriya oralig'i) va telefon raqam (normallashtirish,
ichki email, ko'rinish). `flutter analyze` — xatosiz.

### 3.8. Telefon raqam bilan kirish (email o'rniga)
- Login/ro'yxatdan o'tish: faqat **`+998` + 9 ta raqam** va parol (SMS yo'q). Email maydoni
  va email funksiyalari kodda **kommentga olingan** (`login_screen.dart`, `services/db.dart`).
- Firebase Email/Password ichida raqam ichki emailga aylanadi (foydalanuvchi ko'rmaydi):
  `901234567` → `998901234567@phone.kottaqani.uz` (`normalizePhone`, `phoneToEmail`).
- `AppUser.phone` maydoni; profil va trener panelida raqam ko'rinadi, qidiruv raqam bo'yicha ham.
- Trener akkaunti raqamga o'tkazildi (uid va admin roli o'sha). Eski email bilan ochilgan
  akkauntlar (masalan "asdsad") endi kira olmaydi — raqam bilan qayta ro'yxatdan o'tish kerak.
- Haqiqiy Firebase'ga o'tganda ham ishlaydi (Console'da Email/Password yoqilgan bo'lishi kifoya).

### 3.9. Dizayn to'liq yangilandi — Diamond qorong'i tizimi (2026-09-12)

Ilova **faqat qorong'i rejimda** ishlaydi (`themeMode: ThemeMode.dark`) — olmos palitrasi
shunga qurilgan. Yorug' rejim yo'q, `AppTheme.light()` ham qorong'i temani qaytaradi.

**60 / 30 / 10 qoidasi** (`lib/theme.dart`):

| Ulush | Nima | Rang |
|---|---|---|
| 60% | Fon — mutlaqo qora emas, to'q grafit (ko'zni charchatmaydi) | `bg #16191E`, `bgDeep #11141A` |
| 30% | Matn va kartochkalar | `text #E3E8EE`, `textMuted #96A0AE`, `card #22262F` |
| 10% | Urg'u — faqat asosiy tugma va ko'rsatkich | `accent #4AF2FF` (Diamond Blue) |

Holat ranglari to'q fonga moslab yorug'lashtirildi: `success #4ADE80`, `warning #FBBF24`,
`danger #FB7185`, `water #38BDF8`, `protein #A78BFA`. `textMuted` fonda kontrast ~6.5:1.

- **Burchaklar 8–16 px:** `AppRadius.sm 8 / md 10 / lg 12 / xl 16`. Keskin ham,
  ortiqcha yumaloq ham emas.
- **Shisha effekti:** `BentoTile` — shaffof to'ldirish + ingichka oq qirra + yuqori
  qirradagi yorug' chiziq. `blur: true` bo'lsa haqiqiy `BackdropFilter` (18 px) qo'shiladi —
  u qimmat amal, shuning uchun faqat bosh bloklarda. Fonda (`AppBackdrop`) yumshoq olmos
  jilosi bor, shisha aynan shuni xiralashtiradi.
- **Ikonkalar faqat ingichka chiziqli.** Pastki menyudagi `selectedIcon` (to'la variant)
  butunlay olib tashlandi — tanlangani rang bilan ajraladi.
- **Pop-up yo'q.** `confirm()` va vazn kiritish endi pastdan chiquvchi varaqda
  (`showSheet()`), ekran o'rtasidan chiqmaydi va bosh barmoq zonasida turadi.
- **Keng bo'shliq:** `AppSpace` qadamlari kattalashtirildi (md 14, lg 20, xl 28, xxl 40),
  bosiladigan elementning eng kichik balandligi `kTouchTarget = 52` — mashqda qo'l titrasa
  ham noto'g'ri bosilmaydi.
- **Tipografika:** sarlavhalar zich (`letterSpacing` manfiy, w700), matn keng qatorli
  (`height` 1.5–1.55). Barcha raqamlar `tabular`.
- **Yangi komponentlar (`lib/widgets/ui.dart`):** `AppBackdrop` (fon + jilo),
  `BentoTile` (shisha katak, `feature`/`blur` bayroqlari), `showSheet()`, `Eyebrow`,
  `FadeInUp`, `CountUp`.

### 3.10. Suv va vazn o'lchovi aniqlashtirildi (2026-09-12)

- **Suv:** birlik endi ochiq yozilgan — "Suv · 1 stakan = 250 ml", katakda
  "N stakan / 8" va "N ml / 2000 ml".
- **Vazn:** haftada 1 marta kiritiladi. Progress ekranida keyingi o'lchovgacha necha kun
  qolgani ko'rsatiladi; muddat kelganda tugma laym rangga o'tadi. 7 kun o'tmasdan
  kiritilsa — ogohlantirish (to'smaydi, sabab tushuntiriladi: vazn kun davomida
  1–2 kg tebranadi).

---

## 4. Ochiq masalalar (keyingi qadamlar)

### Hal bo'lgan (2026-09-11)
- ~~Telefonda ishlamadi~~ — haqiqiy Firebase'ga o'tildi, APK istalgan tarmoqda ishlaydi.
- ~~Cleartext http~~ — `AndroidManifest.xml` dan `usesCleartextTraffic` olib tashlandi.
- ~~APK'ni yuborish~~ — hosting sahifasi orqali: https://kotta-qani-09111753.web.app

### Ochiq
1. **Ekranlar vizual tekshirilmagan.** Login va trener "Mijozlar" ekrani ko'rilgan; qolgan
   ekranlar (Bugun, Progress, Chat, Profil, Anketa, Rejalar editori, Mahsulotlar) haqiqiy
   Chrome'da va telefonda tekshirilmagan.
2. **Trener bilan aniqlashtirish** (mahsulot savollari, javob kerak):
   - "50 g grechka qaynatilgan holda" — quruq vazn yoki pishgan vazn? (shablonda quruq)
   - "Fruktozadan voz keching" deyilgan, lekin rejada olma/qulupnay bor — qoldiramizmi?
3. **Kunlik ratsion eslatmasi** — QOLLANMA 8-bo'lim. Ikki yo'l: bepul push-bildirishnoma
   (FCM, faqat ilova o'rnatganlarga) yoki SMS (Eskiz.uz + Firebase Blaze, pullik).
4. **Rasm sifati** — noxat rasmi zaif (bitta don). Litsenziya jihatidan muammo yo'q:
   rasmlar CC BY-SA, mualliflar ilovadagi "Rasm manbalari" oynasida ko'rsatilgan.

### Muhit haqida eslatma (2026-09-12)
Loyiha yangi kompyuterga ko'chirilgan (`C:\Windows.old` bor, eski profil yo'qolgan).
Bu kompyuterda Flutter / Node / Java / Android SDK **yo'q edi** — qaytadan o'rnatilmoqda:
Flutter 3.47.4 → `%USERPROFILE%\flutter`, Node 22 → `%LOCALAPPDATA%\node` (admin huquqisiz,
foydalanuvchi PATH'iga qo'shiladi). `build/` va `.dart_tool/` ichidagi kesh eski kompyuterniki —
birinchi yig'ishda qayta yaratiladi.

---

## 5. Foydali buyruqlar

```powershell
# Ishga tushirish (haqiqiy Firebase)
powershell -ExecutionPolicy Bypass -File .\start.ps1

# Tekshiruv
flutter analyze
flutter test

# APK (kichik, har bir protsessor uchun alohida)
flutter build apk --release --split-per-abi

# Yuklab olish sahifasini yangilash (havola o'zgarmaydi)
copy build\app\outputs\flutter-apk\app-arm64-v8a-release.apk public\app\kq.bin
copy build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk public\app\kq-eski.bin
firebase deploy --only hosting

# Qoidalarni joylash
firebase deploy --only firestore:rules

# Faqat lokal emulyator (main.dart da useEmulator = true bo'lsa)
powershell -ExecutionPolicy Bypass -File .\emulators.ps1
```

## 6. Tuzilma

```
lib/
  main.dart                 Firebase ulanishi, tema, keng ekran ramkasi
  theme.dart                Ranglar va Material 3 tema (light/dark)
  firebase_options.dart     Firebase sozlamalari (flutterfire configure)
  models/models.dart        AppUser (BMI, targetKcal), Food, MealItem, Meal, Plan, WeightLog, ChatMessage
  services/db.dart          Firebase Auth + Firestore, Riverpod providerlar
  widgets/ui.dart           Umumiy UI komponentlar
  widgets/food_image.dart   Mahsulot rasmi (nom -> rasm), rasm manbalari oynasi
  screens/auth/             AuthGate (rolga qarab), Login
  screens/user/             Bugun, Progress, Chat, Profil, Anketa
  screens/admin/            Mijozlar (+ tafsilot), Rejalar (+ editor, shablon), Mahsulotlar, Xodimlar
assets/foods/               19 ta mahsulot rasmi;  assets/credits.txt — mualliflar
test/widget_test.dart       Unit testlar (16 ta)
firestore.rules             Xavfsizlik qoidalari
firebase.json, .firebaserc  Firebase: hosting + firestore + emulyator sozlamalari
public/index.html           Yuklab olish sahifasi
public/app/kq.bin           APK arm64 (kq-eski.bin — armeabi-v7a)
start.ps1                   Ilovani ishga tushirish (haqiqiy Firebase)
emulators.ps1               Faqat lokal emulyator (Java 21 ni o'zi topadi/yuklaydi)
usb.ps1                     Telefonni USB orqali lokal emulyatorga ulash (endi shart emas)
internet.ps1                Lokal emulyatorni tunnel orqali ochish (endi shart emas)
deploy.ps1                  Firebase'ga joylash (qoidalar + hosting)
tools/make_icon.dart        Logotipdan ikonka rasmlarini yasaydi
tools/rules_test/           firestore.rules testlari (33 ta holat)
tools/bore-lite.mjs         Tunnel yordamchisi (internet.ps1 uchun)
assets/icon/logo_src.jpg    Ilova logotipi (manba rasm)
```

---

## 7. Brend nomi (2026-09-12)

Ilova nomi **"Kotta Qani" → "Diamond"** ga o'zgartirildi. O'zgargan joylar:

| Joy | Qiymat |
|---|---|
| Telefondagi ilova nomi | `android/app/src/main/AndroidManifest.xml` → `android:label="Diamond"` |
| Login / splash sarlavhasi | "Diamond zal" |
| Trener paneli sarbarg | "Trener paneli • Diamond" |
| Brauzer tab / web meta | `lib/main.dart`, `web/index.html` → "Diamond" |
| Yuklab olish sahifasi | `public/index.html` |
| Reja shabloni funksiyasi | `kottaQaniTemplate()` → `diamondTemplate()` |

**O'zgarmagan (ataylab):** Dart paket nomi `kotta_qani_diet`, Firebase loyihasi
`kotta-qani-09111753`, hosting havolasi `kotta-qani-09111753.web.app`, ichki email domeni
`@phone.kottaqani.uz`. Bularni o'zgartirish Firebase'ni qaytadan sozlashni va barcha
akkauntlarni yo'qotishni anglatadi — foydalanuvchi bularni ko'rmaydi.

> **Diqqat:** telefondagi nom faqat **yangi APK** o'rnatilgandan keyin "Diamond" bo'ladi.
> Ilova belgisi (ikonka) hali ham Flutter'ning standart logotipi —
> `android/app/src/main/res/mipmap-*/ic_launcher.png` almashtirilishi kerak.

---

## 8. Bosh admin roli (2026-09-12)

Endi **uchta rol** bor. Rolni faqat bosh admin o'zgartira oladi — qoidalar bilan himoyalangan.

| Rol | Kim | Nima qila oladi |
|---|---|---|
| `user` | shogird | o'z rejasi, progressi, treneri bilan chat |
| `admin` | trener | trener paneli: mijozlar, rejalar, mahsulotlar, chat |
| `owner` | **bosh admin** (zal egasi) | trener panelining hammasi **+ "Xodimlar" bo'limi** |

### Bosh admin nima qila oladi
- **Trener tayinlash / trenerlikdan olish** — oddiy foydalanuvchini trener qiladi.
  Trenerlikdan olinganda unga biriktirilgan shogirdlar avtomatik bo'shatiladi.
- **Hamma trenerni ko'rish** — har birida nechta shogird borligi; trenerni bosganda
  uning shogirdlari ro'yxati ochiladi.
- **Shogirdlarni ko'rish** — trenersiz qolganlar alohida ro'yxatda ("Biriktirish kerak").
- **Trenerga biriktirish** — mijoz tafsilotida "Biriktirilgan trener" ro'yxati
  (faqat bosh adminga ko'rinadi).
- **Bosh admin qilish / tushirish** — trenerni bosh admin qiladi yoki boshqa bosh adminni
  trenerga tushiradi. Himoya: o'zini o'zgartira olmaydi va **yagona** bosh adminni
  tushirib bo'lmaydi (`ownerCount <= 1` tekshiruvi) — aks holda rol tayinlaydigan hech kim
  qolmaydi.
- **Akkauntni o'chirish** — Firestore hujjati o'chadi.

### Kod
- `AppUser.role` — `user` / `admin` / `owner`; `isOwner`, `isAdmin` (admin **yoki** owner),
  `isTrainer` (faqat admin) getterlari.
- `AppUser.trainerId` — shogird qaysi trenerga biriktirilgan (`null` — biriktirilmagan).
- `Db.staff()`, `Db.setRole()`, `Db.assignTrainer()`, `Db.deleteUser()`.
- `lib/screens/admin/staff_screen.dart` — "Xodimlar" bo'limi va `TrainerDetail`.
- `admin_home.dart` — bosh adminda 4-chi bo'lim qo'shiladi.

### firestore.rules
- `isOwner()` — rolni o'zgartiradi va hujjat o'chiradi.
- `isStaff()` — trener + bosh admin: mijozlarni o'qiydi, reja/mahsulot yozadi.
- Trener rolni **o'zgartira olmaydi** (`same('role')`).
- Foydalanuvchi o'zining rolini, rejasini va trenerini o'zgartira olmaydi.
- `same(field)` — `.get(field, null)` orqali eski hujjatlarda maydon yo'q bo'lsa ham ishlaydi.

> ⚠️ **Bir martalik sozlash:** yangi qoidalarda faqat `owner` rol tayinlay oladi, lekin
> hozircha hech kim `owner` emas. Shuning uchun **qoidalarni joylashdan oldin** hozirgi
> trener akkauntining `role` maydonini qo'lda `owner` qilish kerak:
> Firebase Console → Firestore → `users` → trener hujjati → `role` = `owner`.
> Aks holda bosh admin tayinlab bo'lmaydi (qoidalar tuzog'i).

---

## 9. Ilova ikonkasi (2026-09-12)

Trenerning logotipi (soqolli bodibilder siluetı) ilova ikonkasiga qo'yildi.

- Manba: `assets/icon/logo_src.jpg`
- `tools/make_icon.dart` — oq fonni shaffofga aylantiradi, qirqadi va kvadratga
  markazlaydi. Ikki fayl chiqaradi: `icon.png` (oq fon, eski Android) va
  `icon_foreground.png` (shaffof, 60% — adaptiv ikonkaning xavfsiz zonasi uchun).
- `flutter_launcher_icons` (pubspec'dagi sozlama) barcha o'lchamlarni chiqaradi:
  `mipmap-*/ic_launcher.png`, `drawable-*/ic_launcher_foreground.png`, monoxrom variant
  (Android 13+ mavzuli ikonka) va web ikonkalari.

Logotip o'zgarsa:
```powershell
# yangi rasmni assets/icon/logo_src.jpg ga qo'ying, so'ng:
dart run tools/make_icon.dart
dart run flutter_launcher_icons
flutter build apk --release --split-per-abi
```

---

## 10. Xavfsizlik qoidalari sinovdan o'tdi (2026-09-12)

`tools/rules_test/` — `firestore.rules` ni **lokal emulyatorda** sinaydigan 33 ta test
(`@firebase/rules-unit-testing`). Haqiqiy bazaga tegmaydi.

```powershell
firebase emulators:start --only firestore --project demo-rules-test
cd tools\rules_test; npm install; node test.mjs      # 33 otdi, 0 xato
```

Tekshirilgan holatlar:

| Guruh | Nima tasdiqlandi |
|---|---|
| Rol o'zgartirish | bosh admin tayinlaydi/tushiradi; **trener rolga tega olmaydi**; trener o'zini bosh admin qila olmaydi; shogird o'zini trener qila olmaydi |
| O'chirish | faqat bosh admin o'chiradi; trener ham, shogird ham o'chira olmaydi |
| Trener biriktirish | bosh admin va trener biriktiradi; shogird o'z trenerini o'zgartira olmaydi |
| Shogird ma'lumoti | vaznini o'zgartiradi; **o'ziga reja biriktira olmaydi**; trener biriktiradi |
| O'qish | shogird faqat o'zini; trener va bosh admin hammani; kirmagan odam hech narsani |
| Reja/mahsulot | trener va bosh admin yozadi; shogird faqat o'qiydi |
| Chat | o'z chatiga yozadi; boshqaning chatiga yoza olmaydi; boshqa nom bilan yuborib bo'lmaydi |
| Ro'yxatdan o'tish | yangi odam faqat `user` bo'la oladi; `admin`/`owner` qilib yaratib bo'lmaydi |

> `firestore.rules` o'zgartirilsa, **joylashdan oldin** shu testni ishga tushiring.

### Tuzatilgan xato
Akkaunt o'chirilganda ilova cheksiz yuklanishda qolardi (`AuthGate` da hujjat `null`).
Endi 5 soniya kutadi (ro'yxatdan o'tish holati uchun), so'ng "Akkaunt topilmadi" ekrani
va chiqish tugmasi ko'rsatiladi — `_NoProfile`.

### Muhit (bu kompyuterda o'rnatildi)
| Nima | Qayerda |
|---|---|
| Flutter 3.47.4 | `%USERPROFILE%\flutter` |
| Node 22.20.0 | `%LOCALAPPDATA%\node` |
| Java 21 (Temurin) | `%LOCALAPPDATA%\jdk21` |
| Android SDK 36 + NDK 28 | `%LOCALAPPDATA%\Android\Sdk` |
| firebase-tools | global npm |

> `android/gradle.properties` da heap **8 GB → 1600 MB** ga tushirildi: bu kompyuterda
> RAM tang, 8 GB so'ralganda Gradle JVM qulab tushardi.

---

## 11. Joylash (deploy) — `deploy.ps1`

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy.ps1
```

Skript: kirishni tekshiradi (kerak bo'lsa brauzer ochadi) → `firestore:rules` →
`hosting`. Node/Java yo'llarini o'zi sozlaydi.

**Eslatma:** `.firebaserc` da sukut loyiha `demo-kotta-qani` dan **`kotta-qani-09111753`**
ga o'zgartirildi — deploy haqiqiy loyihaga ketishi uchun. Emulyator baribir ishlaydi:
`emulators.ps1` loyihani `--project demo-kotta-qani` bilan o'zi ko'rsatadi.

> **Diqqat — tartib:** avval ilovaga trener bo'lib kirib, "Bosh admin tayinlanmagan"
> bannerida **"Men"** tugmasini bosing. Keyingina `deploy.ps1` ni ishga tushiring.
> Yangi qoidalarda rolni faqat bosh admin o'zgartira oladi — bosh admin yo'q holatda
> qoidalar joylansa, trener tayinlab bo'lmay qoladi.
>
> Agar allaqachon joylab qo'ygan bo'lsangiz va bosh admin yo'q bo'lsa: Firebase Console →
> Firestore → `users` → trener hujjati → `role` maydonini `owner` qiling.

### Nega men joylay olmadim
Firebase CLI bu muhitda (TTY yo'q) brauzerni ochib, localhost orqali kirishni bajara
olmaydi — u faqat "kodni ko'chirib keling" usulini taklif qiladi. Foydalanuvchining
avtorizatsiya kodini so'ramaslik uchun joylash `deploy.ps1` ga topshirildi.

---

## 12. ⚠️ APK imzosi o'zgardi — eski ilovani o'chirish shart (2026-09-12)

Windows qayta o'rnatilganda `~/.android/debug.keystore` yo'qolgan. Bugungi birinchi
yig'ishda Gradle **yangi debug kaliti** yaratdi (14:27). Android imzosi boshqacha
bo'lgan yangilanishni o'rnatmaydi.

**Natija:** 11-sentabr APK'si o'rnatilgan telefonlarda yangi APK **tushmaydi**
("App not installed"). Avval eski ilovani o'chirish kerak, keyin yangisini o'rnatish.
Ma'lumotlar Firebase'da, shuning uchun hech narsa yo'qolmaydi.

Bu bir martalik — bundan keyingi yig'ishlar shu kalit bilan imzolanadi.

### Kelajakda takrorlanmasligi uchun
Hozir `android/app/build.gradle.kts` da release ham **debug kaliti** bilan imzolanadi
(Flutter shabloni shunday qoldirgan). To'g'ri yo'l — alohida release kaliti yaratib,
uni zaxiralab qo'yish:

```powershell
keytool -genkey -v -keystore %USERPROFILE%\diamond-release.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias diamond
```

So'ng `android/key.properties` yaratib (git'ga qo'shmang), `build.gradle.kts` da
`signingConfigs.release` ga ulash kerak. Kalit faylini yo'qotmang — yo'qolsa,
yana hamma mijoz ilovani o'chirib qayta o'rnatishga majbur bo'ladi.
