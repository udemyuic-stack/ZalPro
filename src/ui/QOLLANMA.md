# Diamond — to'liq qo'llanma

> 📌 **Loyihaning to’liq holati bitta faylda: [DAVOM.md](DAVOM.md)** — ishni davom
> ettirish uchun avval o’shani o’qing. Bu fayl tafsilotlar uchun qoldirilgan.

Zal mijozlari uchun ovqatlanish rejasi ilovasi. Uch rol: **bosh admin**, **trener** va **mijoz**.
Kirish **telefon raqam + parol** bilan (SMS emas). Ilova haqiqiy Firebase'ga ulangan —
telefonda, kompyuterda, istalgan joyda va istalgan internetda ishlaydi. Telefon va kompyuter
**bitta bazani** ko'radi: biridan kiritilgani ikkinchisida ham ko'rinadi.

---

## 0. Noldan kompyuterga o'rnatish (dasturlar va paketlar)

> Ilovani telefonda ishlatish uchun **hech narsa o'rnatmaysiz** — 2-bo'limdagi havoladan yuklab
> olasiz. Bu bo'lim faqat ilovani **kompyuterda ochish yoki o'zgartirish** uchun.

### A) Ilovani kompyuterda ochish uchun (minimum)

| Dastur | Nima uchun | Havola / buyruq |
|---|---|---|
| **Flutter SDK** (3.24+ ) | ilovani ishga tushirish | https://docs.flutter.dev/get-started/install/windows |
| **Git** | Flutter va loyiha uchun | https://git-scm.com/download/win |
| **VS Code** | kod muharriri | https://code.visualstudio.com |
| **Google Chrome** | ilova brauzerda ochiladi | https://google.com/chrome |

**VS Code kengaytmalari** (Extensions bo'limidan qidirib "Install"):
- **Flutter** (nomi: `Dart-Code.flutter`) — Dart ham o'zi bilan keladi.

O'rnatgach, tekshirish (VS Code terminalida — `Terminal → New Terminal`):
```powershell
flutter doctor
```

### B) Dart paketlari (avtomatik)

Alohida o'rnatilmaydi. Loyiha papkasida bir marta:
```powershell
flutter pub get
```
Bu `pubspec.yaml` dagi hamma paketni yuklaydi: `firebase_core`, `firebase_auth`,
`cloud_firestore`, `flutter_riverpod`, `fl_chart`, `intl`.

### C) Firebase buyruqlari uchun (deploy, APK havolasini yangilash)

| Dastur | Havola / buyruq |
|---|---|
| **Node.js LTS** | https://nodejs.org |
| **firebase-tools** | `npm install -g firebase-tools` → keyin `firebase login` |

### D) APK (Android) yig'ish uchun qo'shimcha

| Dastur | Izoh |
|---|---|
| **Java (JDK) 21** | https://adoptium.net (Temurin 21). `emulators.ps1` uni `%LOCALAPPDATA%\jdk21` ga o'zi ham yuklab oladi. |
| **Android SDK** | Eng oson: **Android Studio** (https://developer.android.com/studio) — SDK, platform-tools, NDK bilan keladi. |

Android Studio o'rnatgach, bir marta:
```powershell
flutter doctor --android-licenses
flutter build apk --release --split-per-abi
```
> Eslatma: bu loyihada Android SDK `%LOCALAPPDATA%\Android\Sdk` ga, Java `%LOCALAPPDATA%\jdk21`
> ga qo'lda o'rnatilgan (platform 36, build-tools 36.0.0, NDK 28.2.13676358). Android Studio
> ishlatsangiz, shu versiyalar yoki yuqorirog'i bo'lsa kifoya.

### Eng qisqa yo'l
`flutter`, `node`, Chrome o'rnatilgan bo'lsa — qolganini `start.ps1` o'zi qiladi:
```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

---

## 1. Muhim havola va parollar

| Nima | Qiymat |
|---|---|
| **Ilovani yuklab olish** (telefonda oching) | **https://kotta-qani-09111753.web.app** |
| **Trener telefon** | `+998 90 000 00 00` (maydonga `900000000`) |
| **Trener parol** | lokal `PAROLLAR.md` faylida |
| Firebase loyiha | `kotta-qani-09111753` (CLI akkaunti: `PAROLLAR.md` da) |
| Firebase konsol | https://console.firebase.google.com/project/kotta-qani-09111753 |

APK fayl kompyuterda:
`build\app\outputs\flutter-apk\app-arm64-v8a-release.apk` (20,5 MB, deyarli barcha telefonlar).
Eski telefon uchun: `app-armeabi-v7a-release.apk`.

---

## 2. Telefonga o'rnatish

1. Telefon brauzerida oching: **https://kotta-qani-09111753.web.app**
2. **"Ilovani yuklab olish (APK)"** tugmasini bosing — fayl yuklanadi.
3. Yuklangan faylni oching. "Noma'lum manbadan o'rnatish" so'rasa — **ruxsat bering**.
4. O'rnating va oching.

> Yuqoridagi tugma ishlamasa, "Eski telefon uchun" tugmasini bosing.

### iPhone yoki kompyuterda

O'rnatish shart emas — brauzerda ochiladi:
**https://kotta-qani-09111753.web.app/ilova/**

Hamma bo'lim ishlaydi (reja, zal, do'kon, chat). Farqi bitta: brauzerda
**bildirishnoma kelmaydi**, shuning uchun Android'da APK o'rnatgan ma'qul.
Trener uchun esa kompyuterda ishlash qulay — reja va tovarlarni klaviatura bilan
tez kiritadi.

---

## 3. Trener (admin) sifatida ishlash

Kirish: telefon `+998 90 000 00 00`. Parol lokal `PAROLLAR.md` faylida.

Pastda 5 bo'lim bor:

- **Mijozlar** — ro'yxatdan o'tgan mijozlar, ularning vazni, BMI, normasi va statusi
  ("Anketa yo'q" / "Rejasiz" / "Reja bor"). Ism yoki telefon raqam bo'yicha qidirish bor.
  - Mijozni bosing → tafsiloti ochiladi.
  - **"Biriktirilgan reja"** ro'yxatidan rejani tanlab, mijozga biriktirasiz.
  - Yuqoridagi **Chat** tugmasi orqali mijoz bilan yozishasiz.
  - Reja mijoz normasidan 300+ kkal farq qilsa, yonida ⚠ chiqadi.
- **Rejalar** — ovqatlanish rejalarini yaratish/nusxalash/o'chirish.
  - **"Shablon"** tugmasi tayyor rejani yaratadi. 6 ta shablon bor: Ozish 3 ta
    (biri **1 haftalik ratsion**), Massa nabor 3 ta.
  - Reja ichida mahal (vaqt + nom) va har mahalga mahsulot (gramm bilan) qo'shasiz.
  - Reja 1200 kkal dan kam bo'lsa, ogohlantirish chiqadi.
  - **Haftalik reja:** muharrirda **"Har kunga alohida menyu"** tugmasini yoqing —
    hozirgi menyu 7 kunga nusxalanadi, so'ng Du…Yak tugmalaridan kunni tanlab
    har biriga alohida ovqat yozasiz. **"Hamma kunga"** — shu kun menyusini
    qolgan 6 kunga ko'chiradi. Shogirdda har kuni o'sha kunning menyusi chiqadi.
  - **Kun rasmi:** "1 haftalik ratsion" shablonida har kunga trener bergan surat
    biriktirilgan — shogird uni "Bugun" ekranida ko'radi va bosib kattalashtiradi.
- **Ovqat** — mahsulotlar bazasi (100 g uchun kaloriya/oqsil/yog'/uglevod).
  - **"Standart mahsulotlarni qo'shish"** — 19 ta asosiy mahsulotni rasmi bilan qo'shadi.
  - Yangi mahsulotga rasm havolasini (URL) qo'yish mumkin; qo'ymasangiz, nomiga qarab
    rasm avtomatik tanlanadi.
- **Zal** — kim qaysi kunlari keladi, bugun kim mashq qiladi, kim uyda.
- **Do'kon** — forma, anjomlar va sport pitaniya (protein, kreatin) savdosi:
  - **Tovarlar** varag'i → **"+ Tovar"**: bo'lim, nomi, izoh, narxi (so'm), qoldiq,
    rasm havolasi (ixtiyoriy), "Sotuvda" tugmasi. Tovarni bosib tahrirlaysiz yoki o'chirasiz.
  - **Buyurtmalar** varag'i: shogird buyurtma bersa shu yerda **va chatda** chiqadi.
    **"Berildi"** bossangiz — qoldiq bittaga (necha dona bo'lsa shuncha) kamayadi va shogirdga
    xabar boradi. Yuqorida 30 kunlik savdo summasi turadi.
  - **To'lov ilovada olinmaydi** — shogird zalga kelganda naqd to'laydi.

### Birinchi sozlash (bir marta)
1. **"Bosh admin tayinlanmagan"** banneri chiqsa — **"Men"** tugmasini bosing.
   Shu bilan siz zalning bosh admini bo'lasiz (pastda 3-bo'limga qarang).
2. **Mahsulotlar** → "Standart mahsulotlarni qo'shish".
3. **Rejalar** → "Shablon" → kerak bo'lsa tahrirlang → Saqlash.
4. **Mijozlar** → mijozni tanlang → reja biriktiring.

---

## 3a. Bosh admin (zal egasi)

Ilovada **uch xil rol** bor:

| Rol | Kim | Nima ko'radi |
|---|---|---|
| Shogird | zal mijozi | o'z rejasi, progressi, trener bilan chat |
| Trener | murabbiy | Mijozlar, Rejalar, Mahsulotlar |
| **Bosh admin** | zal egasi | yuqoridagilarning hammasi **+ Xodimlar** |

Bosh adminda pastda **to'rtinchi bo'lim — "Xodimlar"** paydo bo'ladi. U yerda:

- **Trener tayinlash** — "Trener tayinlash" tugmasi → ro'yxatdan odamni tanlaysiz →
  u trener paneliga kira boshlaydi.
- **Trenerni ko'rish** — har trener yonida nechta shogirdi borligi yozilgan.
  Trenerni bossangiz, uning shogirdlari ro'yxati ochiladi.
- **Trenerlikdan olish** — trener yonidagi **⋯** tugmasi. U oddiy foydalanuvchiga
  aylanadi; shogirdlari trenersiz qoladi (ularni boshqa trenerga biriktirasiz).
- **Bosh admin qilish** — trener yonidagi **⋯** tugmasi → "Bosh admin qilish".
  U ham sizga teng huquq oladi. Bir nechta bosh admin bo'lishi mumkin.
- **Bosh adminlikdan olish** — boshqa bosh admin ustidagi **⋯** dan; u trener bo'lib qoladi.
  **Yagona** bosh adminni tushirib bo'lmaydi, o'zingizni ham o'zgartira olmaysiz —
  aks holda hech kim rol tayinlay olmay qoladi.
- **Akkauntni o'chirish** — o'sha **⋯** tugmasidan. Qaytarib bo'lmaydi.
- **Trenersiz shogirdlar** — pastda alohida ro'yxat: kim hali trenerga biriktirilmagan.

Shogirdni trenerga biriktirish: **Mijozlar** → mijozni tanlang →
**"Biriktirilgan trener"** ro'yxati (bu maydon faqat bosh adminga ko'rinadi).

> Trenerlar rol o'zgartira olmaydi — trener tayinlash va akkaunt o'chirish
> faqat bosh adminning qo'lida.

---

## 4. Mijoz sifatida ishlash

1. Ilovada **"Ro'yxatdan o'tish"** → ism, telefon raqam, parol.
2. **Anketa**: jins, yosh, bo'y, vazn, faollik → kunlik kaloriya normasi va BMI hisoblanadi.
3. Pastdagi bo'limlar:
   - **Bugun** — bugungi ovqat rejasi (vaqt, gramm, kaloriya), "yedim" belgisi va suv hisobi.
     Reja haftalik bo'lsa, tepada **"REJA · PAYSHANBA"** kabi yozuv va o'sha kunning
     ratsion rasmi chiqadi — rasmni bosib kattalashtirsa bo'ladi.
     Suv **stakan** bilan sanaladi: **1 stakan = 250 ml**, kunlik maqsad **8 stakan = 2000 ml**.
     Tomchini bosib belgilaysiz; oxirgi to'la tomchini bossangiz — bittaga kamayadi.
   - **Progress** — vazn va grafik. Vazn **haftada 1 marta** kiritiladi (ertalab, nahorga
     tortilgan). Ekranda keyingi o'lchovgacha necha kun qolgani ko'rinadi, muddat kelganda
     tugma yashil-laym rangga o'tadi. Bir hafta o'tmasdan kiritsangiz, ilova ogohlantiradi
     (baribir kiritsa bo'ladi) — vazn kun davomida 1–2 kg tebranadi, shuning uchun tez-tez
     o'lchash grafikni chalg'itadi.
   - **Zal** — mashq kunlari: **Se/Pay/Sha** yoki **Du/Chor/Ju** variantidan birini tanlaysiz,
     jadval va bugungi mashg'ulot ko'rinadi.
   - **Do'kon** — forma, anjom va sport pitaniya. **"Olaman"** → sonini tanlab buyurtma berasiz;
     trenerga xabar boradi, to'lov zalda naqd. Trener bermaguncha **"Bekor"** qila olasiz.
   - **Trener** — trener bilan chat.
   - **Profil** — ma'lumotlar, BMI, kunlik norma; ma'lumotlarni o'zgartirish, chiqish.

Mijozga reja ko'rinishi uchun **trener uni biriktirishi** kerak ("Reja hali biriktirilmagan"
yozuvi shuni bildiradi).

---

## 5. Kompyuterda ko'rish/ishlatish

Loyiha papkasida:
```
powershell -ExecutionPolicy Bypass -File .\start.ps1
```
Ilova Chrome'da ochiladi (http://localhost:5173) va **o'sha haqiqiy bazaga** ulanadi —
telefon bilan bir xil ma'lumot. Trener bo'lib kirib, mijozlarni boshqarasiz.

Kerak: **Flutter** o'rnatilgan bo'lishi. Chrome yo'q bo'lsa: `flutter run -d edge --web-port 5173`.

---

## 6. Boshqa kompyuterda davom ettirish

1. Butun loyiha papkasini nusxalang. `build/`, `.dart_tool/`, `android/.gradle/` shart emas.
2. U kompyuterda **Flutter** o'rnatilgan bo'lsin.
3. Loyiha Firebase'ga allaqachon ulangan (`lib/firebase_options.dart` ichida). Qo'shimcha
   sozlash shart emas — `start.ps1` ni ishga tushiring.
4. Kod o'zgartirilsa, APK'ni qayta yig'ish:
   ```
   flutter build apk --release --split-per-abi
   ```
   Yangi APK'ni yangilash (yuklab olish havolasi o'zgarmaydi):
   ```
   copy build\app\outputs\flutter-apk\app-arm64-v8a-release.apk public\app\kq.bin
   copy build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk public\app\kq-eski.bin
   firebase deploy --only hosting
   ```

---

## 7. Texnik ma'lumot (qisqacha)

- **Flutter + Firebase** (Auth: Email/Password — telefon raqam ichki emailga aylanadi:
  `901234567` → `998901234567@phone.kottaqani.uz`; Firestore: baza; Hosting: yuklab olish sahifasi).
- Xavfsizlik: foydalanuvchi o'zini admin qila olmaydi; reja/mahsulotni faqat admin o'zgartiradi;
  har kim faqat o'z ma'lumotini yozadi. Qoidalar: `firestore.rules`.
- Batafsil ishlab chiqish holati va ochiq masalalar: `HOLAT.md`.

---

## 8. Keyingi qadam — har kuni SMS bilan ratsion

Reja: har kuni belgilangan vaqtda har bir mijozning telefon raqamiga kunlik ovqatlanish
ro'yxati SMS bo'lib ketadi. Buning uchun kerak:

1. **O'zbek SMS provayderi** — Eskiz.uz yoki Play Mobile (akkaunt + "Diamond" jo'natuvchi
   nomi; har SMS ~50–80 so'm).
2. **Firebase Blaze** (pullik) tarifi — har kuni ishga tushadigan server funksiyasi (Cloud
   Functions) uchun. Bepul Spark tarifida bunday funksiya ishlamaydi.

Kod tarafini men yozaman; akkaunt va to'lovni siz hal qilasiz. Arzonroq muqobil — ilova ichida
bepul push-bildirishnoma (faqat ilova o'rnatgan mijozlarga boradi).

---

## 9. Muammo bo'lsa

- **"Firebase sozlanmagan" ekrani** — internet yo'q yoki `firebase_options.dart` o'chirilgan.
- **Kirolmayapti** — telefon raqam 9 xonali (`900000000`), parol kamida 6 belgi.
- **Mijozda reja yo'q** — trener hali biriktirmagan.
- **APK o'rnatilmayapti** — "Noma'lum manba"ga ruxsat bering yoki "Eski telefon uchun" APK'ni oling.
- **Yangi APK eski ilova ustiga tushmayapti** ("App not installed") — 12-sentabrdan
  imzo kaliti o'zgargan. **Eski ilovani o'chirib tashlang, keyin yangisini o'rnating.**
  Ma'lumotlar bulutda (Firebase), shuning uchun hech narsa yo'qolmaydi. Bu bir martalik.
