# Diamond — loyihaning to'liq holati

> **Bu fayl bitta joyda hamma narsani saqlaydi.** Yangi kompyuterda yoki yangi suhbatda
> shu faylni o'qib, ishni to'xtagan joyidan davom ettirsa bo'ladi.
>
> Oxirgi yangilanish: **2026-10-08**
>
> Boshqa hujjatlar: [QOLLANMA.md](QOLLANMA.md) — trener va mijoz uchun foydalanuvchi
> qo'llanmasi; [README.md](README.md) va [HOLAT.md](HOLAT.md) — eski, batafsilroq
> yozuvlar. Ziddiyat bo'lsa **shu fayl to'g'ri**.

---

## 0. ▶ SHU YERDAN BOSHLANG (12-oktabr holati)

**▶ KEYINGI SAFAR SHU YERDAN (12-oktabr kechki holat).** Hamma kod GitHub'da. Qoidalar,
web va APK **saytga joylangan (14-okt)** — 91–99-bandlar jonli. APK nusxasi:
`Qobil-2026-10-14.apk` (zal egasining `Music` papkasi va Desktop). Zal egasi 12-okt APK ni
telefonda ko'rib ikki nuqson topdi — 13-okt tuzatildi (96-band). **Zal egasi 13-okt APK ni
telefonda tekshirdi:** "Chiqish" ishlaydi (qotmaydi); shogirdda skrinshot olinmaydi; tana
xaritasi — nuqtalar yig'iladi va qotmaydi, surganda aylanadi, "ORQA" da oyoq joyida, bosilgan
mushak to'g'ri yonadi, pastki menyu joyida; mashg'ulot navbati ("Boshlash", "Bajardim",
keyingi mushak ochilishi, belgilar saqlanishi); trener mashq qo'shishi, takror nom tekshiruvi,
video havolasi; shogirdda "Videoni ko'rish" va "YANGI" belgisi — **zal egasi "hammasi
ishladi" dedi**. Telefonda hali tasdiqlanmagani: do'kon (narx, buyurtma) va 8-oktabrdan
qolgan eski ro'yxat (til, rasm keshi, "+ Yedim", kamera, ovqat eslatmasi). Ochiq ishlar — pastda "⏳ Ochiq ishlar"; ertaga zal egasi trenerdan
so'raydi (mashqlar ro'yxati, bilak/qorin/trapetsiya kuni, mushaklar tartibi).

**12-oktabrda qilingan** (91–94-bandlar) — shogirdning "Zal" tabi butunlay yangilandi:
- **Tana xaritasi** (91): nuqtalardan yig'iladigan, 360° aylanadigan tana + qismli (har mushak
  alohida bo'lak) chizma; mushak bosilsa yonadi va mashqlari chiqadi; "Zal" tabi ichida
  ochiladi (pastki menyu joyida qoladi);
- **haftalik reja bo'yicha** (92): shogird faqat bugungi mashg'ulot mushaklarini ko'radi va
  tanlaydi; rejadan tashqari mushak bosilmaydi;
- **mashg'ulot navbati** (93): "Mashg'ulotni boshlash" → faqat navbatdagi mushak yonadi,
  mashqlarida "Bajardim"; hammasi bajarilgach keyingi mushak ochiladi;
- **trener mashq qo'shadi** (94): trenerning Zal tabi → "Mashqlar": tana sxemasidan mushak
  tanlab yangi mashq qo'shadi, har mashqqa (namunaviysiga ham) video havolasi qo'yadi.

- **videoni ilovadan ochish va "boshlash" tugmasi tepada** (95).

**Tekshirilgani:** `flutter analyze` toza, `flutter test` 144/144, qoida testlari 230/230
(emulyator); joylangandan keyin saytdagi web nusxada yangi matn borligi va `app/kq.bin`
hajmi yangi APK bilan bir xilligi tekshirildi. **Tekshirilmagani:** telefonda umuman
sinalmagan; trener ekrani va haqiqiy saqlash brauzerda qo'lda bosib ko'rilmagan.
Desktop'dagi `Qobil-tana-xaritasi.mp4` — 91-bandning dastlabki holati (92–95 unda yo'q).

**8-oktabrda qilingan:** "Rejadan tashqari yedim" tugmasi — shogird bazadan taom tanlab,
grammini yozadi; kunlik kaloriya hisobiga qo'shiladi; trener ko'radi (**90-band**). Bu Eda AI
kabi rasmdan o'lchash O'RNIGA qilindi (u tavsiya qilinmadi: xato katta, pullik, server kerak).
Brauzerda sinov shogirdi bilan boshidan oxirigacha tekshirildi.

**7-oktabrda qilingan** (84–89-bandlar):
- ilova nomi **"Qobil"**, yangi ikonka ("QOBIL", ko'krakda "Q", "ZAL · TOSHKENT") — 84;
- tillar to'liq yopildi: viloyat-tumanlar, tizim oynalari, chatdagi tizim xabarlari, o'lchov
  birliklari — 85; do'kondagi 146 tovar nomi va izohi uch tilda — 86;
- shogirdda skrinshot bloklandi (`FLAG_SECURE`) — 87;
- suv belgisi — pahlavon rasmi; ism-telefon yozuvi olib tashlandi — 88;
- til tugmasi ichkarida ham (xodimlar tepa paneli, shogird Profili) — 89.

**Saytdagi APK — 8-oktabr** ("Yedim" tugmasi bilan, 90-band; nusxasi: `Qobil-2026-10-08.apk`, zal egasining `Music`
papkasida). ⚠️ **Telefonda sinalmagan** — bu kompyuterda telefon ham, emulyator ham yo'q; zal
egasi "joyla" dedi. Ichida yangi Android kodi bor: rasm keshi (sqflite, path_provider) va
`MainActivity.kt` dagi skrinshot bloki. Ishlamasa qaytarish: `Diamond-2026-10-05.apk` ni
`public/app/kq.bin` ga ko'chirib `firebase deploy --only hosting`.
Ichki nomlar (paket, imzo, Firebase loyihasi, repo `diamond-zal`, bildirishnoma kanali
`diamond_general`) O'ZGARMAGAN — yangi APK eski ilova ustiga o'rnatiladi.

Commit'lar zal egasi nomidan (`Diamond <…@users.noreply.github.com>`), Claude hammuallif
qatorisiz — u shunday so'radi.

**6-oktabr:** uch ish qilindi, hammasi kodda va **web'da joylangan**:
1. **Tezlik** (81-band) — bo'limlar birinchi ochilganda yuklanadi, rasmlar telefonda
   keshlanadi, do'kon ro'yxatlari dangasa, do'konda rasm bosilsa kattalashadi.
2. **Uch til: o'zbek / rus / ingliz** (82-band) — hamma ekran, 711 ta matn; tayyor reja
   shablonlari va standart mahsulotlar ham (jami lug'atda 870 kalit).
3. **Ish rejasi** raqobatchilar bilan solishtirib tuzildi (83-band).

(6-oktabr holati — 7-oktabrda APK joylandi, yuqoriga qarang.) Saytdagi APK — 5-oktabr 17:55 (Crashlytics'siz, ishlaydi, lekin
tezlik va til yo'q). Yangi kod bilan sinov nusxasi: `Diamond-SINOV-2026-10-06.apk` (loyihadan
tashqarida, zal egasining `Music` papkasida). Unda yangi Android plaginlari bor (rasm keshi:
sqflite, path_provider) — **telefonda ochilishi tekshirilgach** `deploy.ps1` bilan joylanadi.
Sabab: 5-oktabrda Crashlytics qo'shilgan APK telefonda ochilmagan edi (80-band).

**5-oktabr (kechqurun):** abonementga kunlik tur va belgilangan narx (kunlik 50 000, oylik
500 000), mijoz o'z to'lovini ko'radi, zal xodimlari hamma to'lovni ko'radi (78-band); yangi
ilova ikonkasi; **Crashlytics olib tashlandi** (80-band).


**5-oktabr:** 4-oktabr ishlari **haqiqiy Firebase'ga joylandi** — qoidalar, web (`/ilova/`) va
yangi APK (25,3 MB, `CN=Diamond Zal`). Do'kondagi **hamma 115 tovarga 15% ustama** qo'yildi
(tan narx `costPrice` da saqlandi). **Birinchi haftalik zaxira** olindi:
`zaxira/2026-10-05_bazaning-zaxirasi.json`. Haqiqiy qoldiqlar hali kiritilmagan
(foydalanuvchi: keyinroq). Batafsil — **66-band**.
O'sha kuni yana: 28 ta yangi tovar (jami 144), **barmen faqat o'z zali, rang tanlash, oylik
moliyaviy hisobot, Crashlytics** — **67–72-band**. ⚠️ Eski APK'da buyurtma ishlamaydi — yangilash shart.

**4-oktabr:** 13-bo'limdagi tavsiyalardan 5 tasi qilindi — **abonement + davomat + haftalik
eslatma jurnali, do'kon narxiga ustama, o'lcham bo'yicha qoldiq, QR ro'yxat kodi, haftalik
zaxira skripti** (batafsil — **61–65-band**). Hammasi lokal emulyatorda brauzer orqali
(headless Chrome + `tools/brauzer/cdp.mjs`) qo'lda sinaldi — real xato topildi va tuzatildi
(o'lchami tugagan tovarni baribir buyurtma qilish mumkin edi, 63-bandga qarang).
**Hali haqiqiy Firebase'ga joylanmagan** — bu kompyuterda `.env` yo'q (parollar), shuning
uchun `narx_ustama.mjs`/`zaxira.mjs` skriptlari va APK/web joylash haqiqiy bazaga qarshi
tekshirilmagan. Qolgan 13-bo'lim band: narxga ustamani haqiqiy do'konga qo'llash, haftalik
zaxirani birinchi marta olish, deploy.

**2-oktabr:** loyiha GitHub'da ochiq (public) nashr qilindi — <https://github.com/xojaurunov/diamond-zal>, shox `main`. Maxfiy ma'lumot repodan va tarixdan olib tashlandi, **parollar o'zgarmadi** (**14-bo'lim** — u yerda yangi qoida: parol kuzatiladigan faylga yozilmaydi; haqiqiy parollar `PAROLLAR.md` va `.env` da).

**Hammasi joylangan** (Cloud Functions bundan mustasno — Blaze kerak). `flutter analyze` 0 xato,
`flutter test` **124/124**, qoida testlari **213/213**.

Oxirgi APK: **5-oktabr 09:57, 25,3 MB** (abonement, davomat, QR, o'lcham bo'yicha qoldiq) —
saytda ham, `public/app/kq.bin` da ham shu turibdi. Web versiyasi ham shu kunniki.
Fayl: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (asosiy),
`app-armeabi-v7a-release.apk` (eski telefon). Yuklab olish:
<https://kotta-qani-09111753.web.app> → `app/kq.bin`.
Qoidalar **5-okt** qayta joylandi (abonement, davomat, eslatmalar jurnali qo'shilgan).
**Loyiha git'da** (52-band) — kod o'chsa `git checkout -- <fayl>` bilan qaytariladi.

**Hujjatlar:** `hujjatlar\Diamond-TZ.docx` — texnik topshiriq va reja (Word);
`hujjatlar\figma\` — 14 ta SVG maket (13 ekran + dizayn tizimi) va `png/` da rasm nusxasi;
`hujjatlar\figma-plugin\` — Figma plagini (Figma ichida maketni o'zi chizadi).

**Foydali vositalar:** `node tools/holat/holat.mjs` — bazadagi holatni ko'rsatadi
(zallar, xodimlar, shogirdlar, rejalar, do'kon, buyurtmalar);
`node tools/brauzer/cdp.mjs` — ilovani brauzerda boshqarib tekshirish
(`PORT=9223` bilan boshqa portda; `cdp.mjs yop` — faqat o'sha brauzerni yopadi,
**`taskkill /IM chrome.exe` ishlatilmaydi**, u foydalanuvchining oynalarini ham yopadi);
`node tools/dokon/tovar_qoshish.mjs <fayl.json>` — do'konga tovar qo'shadi/yangilaydi;
`python tools/dokon/narx_kesish.py <rasm> <papka> <nom> [tepa|past|aralash]` —
javon suratidan har bir mahsulotni narx yorlig'i bo'yicha alohida kesib oladi.

### Kirish

> **Haqiqiy telefon raqamlar va parollar `PAROLLAR.md` faylida** — u git'ga tushmaydi
> (`.gitignore`), shuning uchun faqat shu kompyuterda turadi. Bu repo ochiq (public)
> bo'lgani uchun hujjatlarda parol yozilmaydi.

| Rol | Telefon | Parol | Zal |
|---|---|---|---|
| Bosh admin | `PAROLLAR.md` da | `PAROLLAR.md` da | — |
| Trener 1 (Kotta Qani) | `900000000` | `PAROLLAR.md` da | Kotta Qani zali |
| Trener 2 | `900000001` | `PAROLLAR.md` da | Kotta Qani zali |
| Trener 3 | `900000002` | `PAROLLAR.md` da | Kotta Qani zali |
| **Barmen** | `900000003` | `PAROLLAR.md` da | Kotta Qani zali |

Trener parollarini bosh admin `Xodimlar → Qo'shish → Yangi trener akkaunti` orqali
o'zi belgilaydi; qo'shilgandan keyin ekranda telefon va parol ko'rsatiladi.

**Bazada (18-sent 19:00):** 1 zal (Kotta Qani zali), 3 trener, 1 barmen, 1 bosh admin,
**3 shogird** — Shogird 1, Shogird 2 va **Shogird 3** (18-sent ro'yxatdan o'tgan, Kotta Qani'ni
tanlagan). Hammasining rejasi bor. **Do'konda 107 ta tovar**, 3 asosiy bo'lim: **Forma** 17 (7 komplekt 30–45 $ va 10 mayka/kofta 14–23 $, XL–4XL, qoldiq 10); **Suv idishlari** 6 ta va **Anjomlar** 1 ta; **Dobavkalar** 91 ta — ichida Protein 21, Gainer 14, Kreatin 12, L-Karnitin 10, L-Arginin 5, Boshqa 29 (180 000 – 2 200 000 so'm, qoldiq 5). Jami **115 ta**. Hammasi taxminiy qoldiq. Buyurtma yo'q. 3 ta reja shabloni saqlangan.
(15-sent 12:00 da eski 5 shogird o'chirilgan — zaxira `zaxira/2026-09-15_ochirilgan_shogirdlar.json`.)
Holatni tekshirish: `node tools/holat/holat.mjs`.

### ✅ Tayyor (qisqa)
1. Shablonlar: Ozish 2 variant, Massa nabor 3 variant; trener faqat shogird maqsadiga mos rejani beradi,
   mos kelmaydigan reja bloklanadi. (Ozish tanlagan shogirdda "2 ta variant" chiqishi — to'g'ri, xato emas.)
2. Shogird anketasi: maqsad, trener (katalogdan), metabolizm; norma = vazn × 31/33/35 (±%).
3. Trener faqat o'z shogirdlarini ko'radi; bosh adminni ko'rmaydi; katalogdagi profilini o'zi boshqaradi.
4. Bosh admin: Xodimlar, trenerlar reytingi (avtomatik ball + qo'lda baho).
5. Vazn haftada 1 marta (ilova + server), parolni o'zgartirish/tiklash, o'chirilgan akkauntni qayta ro'yxat.
6. Yorug'/qorong'i rejim; bildirishnomalar (ovqat, vazn, chat, reja — Android).
7. **Zal bo'limi** (42-band): Se/Pay/Sha yoki Du/Chor/Ju; trener "Uyda mashq" (shogird chatda yozsa).
8. **Ikonka** (43-band): oq fon va qora ramka yo'q — adaptiv ikonka olib tashlangan, faqat shaffof PNG.
9. **Do'kon bo'limi** (46-band): forma, anjomlar, sport pitaniya. Trener tovar kiritadi va buyurtmani
   "Berildi" deb belgilaydi (qoldiq avtomatik kamayadi), shogird buyurtma beradi. To'lov zalda naqd.
10. **Haftalik reja imkoniyati** (47-band): rejaga hafta kunlari qo'shildi — har kunga alohida
    menyu va kun rasmi. **Tayyor ratsion va rasmlar 51-bandda olib tashlandi** — imkoniyatning
    o'zi qoldi, trener xohlasa o'zi haftalik reja tuzadi.
11. **Ilova brauzerda** (49-band): https://kotta-qani-09111753.web.app/ilova/ — iPhone va kompyuter.
12. **Hujjatlar va maketlar** (48, 50-band): TZ (Word + web), 13 ta ekran maketi (SVG + PNG),
    Figma plagini.
13. **Zallar (filiallar)** (53, 54-band): bosh admin zal qo'shadi — mamlakat → viloyat →
    tuman → nom; zalga trener yollaydi, zal bo'yicha ajratib ko'radi.
14. **"Eslatma" bo'limi** (55-band): pastki menyuda bildirishnomalar ro'yxati — telefonda
    bildirishnoma o'chirilgan bo'lsa ham hamma narsa shu yerda turadi.
15. **Barmen roli va sotuv hisoboti** (56-band): 4-rol — faqat do'kon; zal egasi
    "kim nechta sotdi" hisobotini ko'radi.
16. **Do'konda o'lcham, rasm galereyasi va dollar narxi** (57-band): tovarga bir nechta rasm
    va o'lchamlar (XL–4XL) qo'shiladi, narx so'mda yoki dollarda bo'ladi; shogird
    buyurtmada o'lchamni tanlaydi, hisobot valyuta bo'yicha alohida chiqadi.
17. **Do'kon to'ldirildi — 115 ta tovar** (57–60-band): Forma 17, Suv idishlari 6,
    Anjomlar 13, Dobavkalar 91 (Protein 21, Gainer 14, Kreatin 12, L-Karnitin 10,
    L-Arginin 5, Boshqa 29). Rasm va narxlar AllPituz kanalidan olingan, rasmlardagi
    begona yozuvlar tozalangan.
18. **Yangi ko'rinish** (59-band): pahlavon rasmi — kirish ekrani foni va ilova ikonkasi.
19. **Abonement, davomat, do'kon ustamasi/o'lchami, QR, zaxira** (4-okt, 61–65-band):
    kod tayyor va lokal emulyatorda sinaldi, **haqiqiy bazaga hali joylanmagan**.

### ⏳ Ochiq ishlar (12-oktabr holati)

**Zal va mashqlar (91–94-bandlar) bo'yicha:**
- trener tasdiqlashi: mashqlar ro'yxati; bilak / qorin / trapetsiya qaysi kunga; mushaklar
  tartibi;
- trener har mashqqa video havolasini qo'yib chiqishi;
- taklif (qilinmagan): trener shogird bajargan
  mashqlarni ko'rishi; uydagi mashqlar; rasmdagi kepkani olib tashlash.

Quyidagilar — 8-oktabrdan qolgan ro'yxat:

**Birinchi navbatda — zal egasi telefonda tekshiradi (hech biri sinalmagan):**
- yangi APK ochiladimi (eng muhimi);
- shogird akkauntida skrinshot olinmasligi, xodimda olinishi;
- rasmlar chiqishi va ikkinchi ochilishda darhol ko'rinishi (kesh), tezlik;
- til almashtirish (tepa paneldagi globus, shogird Profilidagi "Til"), tovar nomlari tarjimasi;
- suv belgisi (pahlavon rasmi) "Bugun" ekranida;
- ovqat eslatmasi bildirishnomasi, Progress'da kamera.

**Zal egasidan kutilayotgan ma'lumot:**
- **Kiyimlarning haqiqiy qoldig'i** (19 ta, o'lcham bo'yicha). Hozir hammasida taxminiy
  XL 3 / XXL 3 / 3XL 2 / 4XL 2. Yo barmen ilovada yozadi (Do'kon → Tovarlar → tovar →
  "Qoldiq (o'lcham bo'yicha)"), yo zal egasi `Nom: XL 2, XXL 0, …` ko'rinishida yuboradi.
- **Sport sumka** — rasm va narx.
- **Trener bilan gaplashgach:** guruh mashg'ulotlari bormi (jadval kerakmi), abonement oynasi
  va "To'lovlar" unga to'g'ri ishlayaptimi. Ungacha bu "kutilayotgan" — qayta so'ralmaydi.
- Tarjimani ruscha biladigan odam ko'rib chiqsa (Claude tarjima qilgan).

**Javob kutayotgan takliflar:**
- mahsulotlar bazasiga 20–30 ta tayyor o'zbek taomini (somsa, lag'mon, manti, shashlik, non,
  sho'rva …) kaloriyasi bilan qo'shish — "Yedim" tugmasi foydali bo'lishi uchun. Hozir bazada
  20 ta mahsulot, tayyor taomlardan faqat Osh. Raqamlar taxminiy bo'ladi — trener tasdiqlasin.
- "Yedim" ni telefonda va haqiqiy shogird bilan sinash (hozir faqat brauzerda ko'rilgan).

**Zal egasiga bog'liq bo'lmagan navbatdagi ishlar** (83-banddagi reja, boshlanmagan):
1. pul — abonementni muzlatish, muddati o'tganlar ro'yxati, kunlik kassa (uchalasi kichik);
2. Play Market shartlari — akkauntni o'zi o'chirish tugmasi, maxfiylik siyosati sahifasi;
3. davomat — kirishda QR skaner, keyin davomat seriyasi (trener bilan gaplashgach ma'qul);
4. boyitish — "rejadan tashqari yedim" + kun yakuni, mashq jurnali, chegirma, tana o'lchamlari;
5. katta — Play Market'ga topshirish, Payme/Click, iPhone, o'z serverga o'tish.

**Qarorlar (qayta so'ralmaydi):** Blaze va push — kerak emas; `ZAXIRA.bat` ni
avtomatlashtirish — pauzada (zal egasi qo'lda bosadi); Crashlytics — hozir kerak emas, Play
Market vaqtida; trener parolini almashtirish, imzo kaliti nusxasi, mijozning o'zi abonement
so'rovi yuborishi — kerak emas.

**Zal egasiga tushuntirilgan mavzular (7-okt, kod emas):** Firebase bepul chegaralari
(eng yaqini — saytdan kuniga ~360 MB, ya'ni ~14 ta APK yuklab olish); o'z serverga o'tish
(5–8 hafta, hozir tavsiya qilinmadi); Play Market va App Store to'siqlari — Word hujjati
`Qobil-Play-Market-va-App-Store.docx` (`Music` papkasida, repoda yo'q). Asosiy to'siqlar:
ikonka, suv belgisi va tovar rasmlari birovniki; mijoz akkauntini o'zi o'chira olmaydi;
shaxsiy ma'lumotni mamlakat ichida saqlash talabi (yuristdan so'rash kerak).

### Eski ochiq ro'yxat (5-oktabrgacha — ko'pi hal bo'lgan, tarix uchun)
- **Qaror kutilmoqda: skrinshotni bloklash yoki suv belgisi** (51-band oxiri). Variantlar:
  A — suv belgisi (shogird ismi rejada xira turadi, tavsiya qilingan);
  B — `FLAG_SECURE` bilan skrinshotni bloklash (web'da ishlamaydi, ikkinchi telefon kamerasini
  to'smaydi); C — ikkalasi; D — kerak emas.
- **Trener paroli almashtirilsin** — u saytda ochiq turgan edi (49-band).
- **Foydalanuvchi telefonda tekshiradi:** ikonka ramkasiz chiqdimi (chiqmasa: ilovani o'chirib qayta
  o'rnatish; Samsung'da "Icon frames" o'chirish; telefon rusumini so'rash) va **bildirishnomalar**
  (ular hali hech qayerda ko'rilmagan — emulyator yo'q).
  Zal ekranlari 16-sent brauzerda to'liq tekshirildi (45-band) — ishlayapti.
- **Zal mashqlari** — hozir "ishlab chiqilmoqda" yozuvi; mashqlar ro'yxati keyin qo'shiladi
  (trenerdan matn kutiladi: har mashg'ulotga 6–8 mashq, yondashuv va takror).
- **Suv idishlari 6 ta** (3873 va 3370-postlar), **Anjomlar 1 ta** (press roller,
  foydalanuvchi rasm berdi — 200 000 so'm). Kanalning **476 ta posti** (3370–4069)
  ko'rildi; kamar, qo'lqop, bint, lyamka kabi anjomlar hali topilmadi — undan eski
  postlarni ko'rish yoki foydalanuvchidan rasm olish kerak.
- **Razmer tanlash tekshirildi (24-sent):** vaqtinchalik TEST shogird akkaunti bilan
  brauzerda: Do'kon → Olaman → "O'lchamni tanlang" (XL/XXL/3XL/4XL), tanlanmaguncha
  tugma o'chiq ("Avval o'lchamni tanlang"). Test akkaunt keyin o'chirildi.
- **Barmen hozir hamma zal buyurtmasini ko'radi** (zal bitta bo'lgani uchun). Filial ko'paysa —
  buyurtmaga zal biriktirib, barmenni o'z zaliga cheklash kerak (56-band).
- **Do'kon tovarlari** — 2 ta komplekt kiritildi (57-band). Qolganlari foydalanuvchidan
  kutiladi ("keyingilarini qo'shamiz"): nomi, narxi, o'lchamlari, rasmi.
  Tez qo'shish: `node tools/dokon/tovar_qoshish.mjs <fayl.json>`; qo'lda — "Do'kon → Tovarlar → + Tovar".
- **Do'kondagi qoldiq taxminiy** — ikkala komplektga 10 dona qo'yildi (haqiqiy son so'ralmagan).
  Zal egasi "Do'kon → Tovarlar" dan to'g'rilasin. Qoldiq **o'lcham kesimida emas**, umumiy.
- **Venumning yana 2 ta modeli kiritilmagan** — yashil-qora "Technical" va oq-qora "Logos"
  (ikkalasi ham 4 qismli, narxi va o'lchami o'sha). Rasmlari diskka tushmagan.
  **Sabab va qoida:** Claude ishlayotgan paytda yuborilgan xabarning rasmlari faylga
  saqlanmaydi — shunday rasmlarni **alohida, bo'sh xabarda** qayta yuborish kerak.
- **Rang/dizayn tanlash yo'q** — bitta tovarda bir nechta rang rasmi turadi, lekin shogird
  buyurtmada faqat **o'lchamni** tanlaydi. Kerak bo'lsa o'lcham kabi "rang" tanlovini ham
  qo'shish mumkin (`Product.sizes` bilan bir xil naqsh).
- **Figma** — plagin yozildi, lekin haqiqiy Figma'da sinalmagan (bu kompyuterda Figma yo'q,
  hisobga kirish imkoni ham yo'q). Foydalanuvchi ishga tushirib skrinshot bersa — tuzatiladi.
- **Blaze** (faqat Firebase Console orqali, bank karta) → `FUNKSIYALAR_JOYLASH.bat` — ilova yopiq bo'lganda
  chat/reja push.
- Ozish uchun 3-variant kerak bo'lsa — matn kutiladi.
- Taxminiy qiymatlar (Osh KBJU, massa 2-/3-versiya porsiyalari) — trener ko'rib chiqsin.

### Bu kompyuterda
Firebase CLI kirgan — `deploy.ps1`, `PAROL_TIKLASH.bat`, `AKKAUNT_OCHIRISH.bat` ishlaydi.
Firebase CLI Windows'da ba'zan ish tugagach "Assertion failed ... async.c" bilan chiqadi — buyruq bajarilgan
bo'ladi (skriptlar natijani stdout'dan tekshiradi).
APK imzosi: `apksigner` (JAVA_HOME = `%LOCALAPPDATA%\jdk21\jdk-21.0.12.1+1`) → `CN=Diamond Zal`.
Qoida testlari: `firebase emulators:start --only firestore --project demo-rules-test`, keyin
`node tools\rules_test\test.mjs`.
Web: `flutter build web --release`, `python -m http.server 5173 --bind 127.0.0.1 --directory build\web`.
Ikonka: `dart run tools/make_icon.dart` → `dart run flutter_launcher_icons`
(**mipmap-anydpi-v26 papkasi paydo bo'lsa — o'chirish kerak**, aks holda ramka qaytadi).

---

## 1. Ilova nima qiladi

Zal mijozlari uchun ovqatlanish rejasi ilovasi. **Flutter + Firebase**, telefon (Android)
va brauzerda ishlaydi, ikkalasi **bitta bazani** ko'radi.

- **Shogird:** ro'yxatdan o'tadi → anketa (**maqsad: ozish / massa nabor**, jins, yosh,
  bo'y, vazn, faollik) → kunlik kaloriya normasi (ozish −20%, massa +10%) va BMI.
  "Bugun" ekranida trener bergan reja, "yedim" belgisi, suv hisobi, "Trener maslahati".
  Vazn grafigi — vazn **haftada faqat 1 marta**. Trener bilan chat.
- **Trener:** mijozlar ro'yxati (maqsad belgisi bilan) va progressi, mahsulotlar bazasi
  (100 g uchun KBJU), reja yaratish/nusxalash (kategoriya majburiy), 5 ta tayyor shablon,
  shogirdga **faqat uning maqsadiga mos** rejani biriktirish, chat.
- **Bosh admin:** yuqoridagilarning hammasi + trener tayinlash, hamma trener va
  shogirdni ko'rish, akkaunt o'chirish, **trenerlar reytingi**.

Kirish **telefon raqam + parol** bilan, SMS yo'q.

---

## 2. Kirish ma'lumotlari va havolalar

| Nima | Qiymat |
|---|---|
| **Bosh admin** | telefon va parol lokal `PAROLLAR.md` faylida |
| **Trener** | maydonga `900000000` · parol `PAROLLAR.md` da (+998 90 000 00 00) |
| Ilovani yuklab olish | https://kotta-qani-09111753.web.app |
| **Ilova brauzerda (iPhone, kompyuter)** | https://kotta-qani-09111753.web.app/ilova/ |
| Firebase loyiha | `kotta-qani-09111753` (CLI akkaunti: `PAROLLAR.md` da) |
| Firebase konsol | https://console.firebase.google.com/project/kotta-qani-09111753 |
| Tarif | **Spark** (bepul) — hozircha yetarli |
| Parolni unutgan foydalanuvchi | `PAROL_TIKLASH.bat` (shu kompyuterda, Firebase CLI kirgan bo'lsa) |

APK kompyuterda: `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`
(21,6 MB — deyarli barcha telefonlar). Eski telefon uchun: `app-armeabi-v7a-release.apk`.
Saytda ular `public/app/kq.bin` va `kq-eski.bin` nomida turadi (`deploy.ps1` o'zi ko'chiradi).

> Telefon raqam faqat **login** vazifasini bajaradi (SMS ketmaydi). Firebase ichida u
> emailga aylanadi, foydalanuvchi buni ko'rmaydi:
> `99XXXXXXX` → `998XXXXXXXXX@phone.kottaqani.uz`

---

## 3. Rollar

| Rol (`users/{uid}.role`) | Kim | Nima ko'radi |
|---|---|---|
| `user` | shogird | Bugun, Progress, Zal, Do'kon, Eslatma, Trener (chat), Profil. Anketada trenerini katalogdan tanlaydi |
| `admin` | trener | Mijozlar (**faqat o'ziga biriktirilganlar**), Zal, Rejalar, Ovqat, Do'kon, Eslatma. Bosh adminni ko'rmaydi |
| `barmen` | zal bari / sotuvchi | **Faqat** Do'kon, Hisobim (o'z sotuvi), Eslatma. Shogird, reja, chatni ko'rmaydi |
| `owner` | **bosh admin** | yuqoridagilar **+ Xodimlar** (zallar, trenerlar reytingi, sotuv hisoboti) |

Kodda: `AppUser.isOwner`, `isAdmin` (admin **yoki** owner), `isTrainer` (faqat admin).
`AppUser.trainerId` — shogird qaysi trenerga biriktirilgan (`null` — biriktirilmagan).

### Bosh admin nima qila oladi
- **Trener tayinlash** — oddiy foydalanuvchini trener qiladi.
- **Bosh admin qilish / tushirish** — trenerni bosh admin qiladi yoki boshqa bosh adminni
  trenerga tushiradi.
- **Trenerlikdan olish** — shogirdlari avtomatik bo'shatiladi (`trainerId = null`).
- **Akkauntni o'chirish** — Firestore hujjati o'chadi.
- **Shogirdni trenerga biriktirish** — mijoz tafsilotidagi "Biriktirilgan trener" maydoni.

**Himoyalar:** o'zini o'zgartira olmaydi; **yagona** bosh adminni tushirib bo'lmaydi
(`ownerCount <= 1` tekshiruvi) — aks holda rol tayinlaydigan hech kim qolmaydi.

### Hozirgi holat
`99XXXXXXX` → `owner`, `900000000` → `admin`. Ikkalasi Firestore'da shunday turibdi
(REST orqali qo'yilgan, tekshirilgan).

---

## 4. Dizayn tizimi — "Diamond"

Ilova **faqat qorong'i rejimda** (`themeMode: ThemeMode.dark`). Hammasi
[lib/theme.dart](lib/theme.dart) da.

**60 / 30 / 10 qoidasi:**

| Ulush | Nima | Rang |
|---|---|---|
| 60% | Fon — mutlaqo qora emas, to'q grafit | `bg #16191E`, `bgDeep #11141A` |
| 30% | Matn va kartochkalar | `text #E3E8EE`, `textMuted #96A0AE`, `card #22262F` |
| 10% | Urg'u — faqat asosiy tugma va ko'rsatkich | `accent #4AF2FF` (Diamond Blue) |

Holat ranglari: `success #4ADE80`, `warning #FBBF24`, `danger #FB7185`,
`water #38BDF8`, `protein #A78BFA`.

**Qoidalar:**
- Burchaklar 8–16 px (`AppRadius.sm 8 / md 10 / lg 12 / xl 16`)
- Kartochkalar — **shisha effekti**: shaffof to'ldirish + ingichka oq qirra + yuqori
  qirrada yorug' chiziq. `BentoTile(blur: true)` haqiqiy `BackdropFilter` qo'shadi
  (qimmat, faqat bosh bloklarda). Fonda (`AppBackdrop`) yumshoq olmos jilosi bor —
  shisha aynan shuni xiralashtiradi.
- **Ikonkalar faqat ingichka chiziqli.** Pastki menyuda `selectedIcon` yo'q — tanlangani
  rang bilan ajraladi.
- **Pop-up yo'q.** Tasdiqlash va vazn kiritish pastdan chiquvchi varaqda (`showSheet()`).
- Keng bo'shliq: `AppSpace` (xs 4, sm 8, md 14, lg 20, xl 28, xxl 40),
  bosiladigan element eng kami `kTouchTarget = 52` px.
- Raqamlar `tabular` (jadvalda sakramaydi).

**Komponentlar** ([lib/widgets/ui.dart](lib/widgets/ui.dart)): `AppBackdrop`, `BentoTile`
(`feature`/`blur`), `StatTile`, `KcalRing`, `Pill`, `IconBadge`, `UserAvatar`,
`EmptyState`, `SectionHeader`, `Eyebrow`, `FadeInUp`, `CountUp`, `showSheet()`,
`confirm()`, `GradientHeader`.

---

## 5a. Muhit — bu kompyuterda nima o'rnatilgan

Windows qayta o'rnatilgani uchun hammasi noldan tiklandi. Hech biri admin huquqi
talab qilmaydi (foydalanuvchi papkasiga o'rnatilgan):

| Nima | Versiya | Qayerda |
|---|---|---|
| Flutter | 3.47.4 (Dart 3.13.3) | `%USERPROFILE%\flutter` |
| Node.js | 22.20.0 | `%LOCALAPPDATA%\node` |
| Java (Temurin) | 21 | `%LOCALAPPDATA%\jdk21` |
| Android SDK | platform 36, build-tools 36.0.0, NDK 28 | `%LOCALAPPDATA%\Android\Sdk` |
| firebase-tools | global npm | `%APPDATA%\npm` |
| Git | — | `C:\Program Files\Git` |

Yo'llar foydalanuvchi `PATH` iga qo'shilgan — **yangi terminal** ochsangiz ishlaydi.

> ⚠️ **Xotira tang.** Kompyuterda 15,7 GB RAM, lekin Chrome ko'pincha 10 GB dan ortiq
> egallaydi. Shu sababli `flutter analyze`, `flutter run` va Gradle bir necha marta
> "Out of memory" bilan qulagan. Ish boshlashdan oldin Chrome varaqlarini kamaytiring
> yoki Gradle demonini to'xtating (`Get-Process java | Stop-Process -Force`).
>
> `android/gradle.properties` da heap **8 GB → 1600 MB** ga tushirilgan — 8 GB
> so'ralganda JVM shu kompyuterda qulaydi.

---

## 5b. Boshqa kompyuterga ko'chirish

### Nimani ko'chirish kerak

> ⚠️ **Butun papkani to'g'ridan-to'g'ri zip qilmang.** 14-sentabrda shunday qilinganda
> zip **2,3 GB** chiqdi (haqiqiy kod ~40 MB), boshqa kompyuterdagi Claude Code esa
> "Stewing..." da uzoq turib qoldi. Sabablari:
>
> | Nima | Hajm | Muammo |
> |---|---|---|
> | `build/` | 1174 MB | qayta yig'iladi |
> | `assets/Изображения/kotta_qani_diet.zip` | 513 MB | loyihaning **eski zip nusxasi o'z ichida** |
> | `.dart_tool/` | 411 MB | qayta yaratiladi |
> | `tools/rules_test/node_modules/` | 143 MB | qayta o'rnatiladi |
> | `windows/flutter/ephemeral/.plugin_symlinks/` | — | plagin **havolalari**: nusxalanganda haqiqiy papkaga aylanib, Windows'ning 260 belgilik yo'l chegarasidan oshadi |

> ✅ **18-sentabrdan loyiha `git` da.** Endi eng ishonchli yo'l — `.git` papkasi bilan
> ko'chirish: unda butun tarix bor, ish jarayonida biror fayl buzilsa
> `git checkout -- <fayl>` bilan qaytariladi.

**To'g'ri yo'l — toza nusxa** (`.git` bilan ~50 MB; 14-sentabrda sinalgan: ochildi →
`flutter pub get` → `flutter analyze` 0 xato):

```powershell
$src   = "E:\kotta_qani_diet"
$stage = "$env:TEMP\diamond-stage\kotta_qani_diet"
robocopy $src $stage /E /XJ `
  /XD "$src\build" "$src\.dart_tool" "$src\android\.gradle" "$src\android\app\.cxx" `
      "$src\tools\rules_test\node_modules" "$src\windows\flutter\ephemeral" `
      "$src\public\ilova" `
  /XF "kotta_qani_diet.zip" "desktop.ini" "joylash-log.txt" "*.log" "kq.bin" "kq-eski.bin"
tar -a -c -f E:\Diamond-toza.zip -C "$env:TEMP\diamond-stage" kotta_qani_diet
```

`public\ilova` (web nusxasi, 47 MB) va `public\app\*.bin` (APK, 45 MB) ko'chirilmaydi —
ular `flutter build` bilan qayta yig'iladi. `.git` esa **ko'chadi** (robocopy uni oladi).

**Yoki git bilan (yanada ishonchli):**

```powershell
# eski kompyuterda
git bundle create E:\diamond.bundle --all
# yangi kompyuterda
git clone E:\diamond.bundle kotta_qani_diet
```

Bundle — bitta fayl, ichida butun tarix. Lekin `.gitignore` ga kirgan fayllar
(APK, web nusxasi) unda yo'q — ular baribir qayta yig'iladi.

`/XJ` — havolalarni (symlink) kuzatmaslik; aynan shu uzun yo'llar muammosini oldini oladi.

**Albatta kerak** (toza nusxada bor, tekshirilgan):

| Fayl | Nega |
|---|---|
| `android/diamond-release.jks` | **Imzo kaliti.** Yo'qolsa — hamma mijoz ilovani o'chirib qayta o'rnatishga majbur bo'ladi |
| `android/key.properties` | kalit paroli |
| `lib/firebase_options.dart` | Firebase ulanishi |
| `android/app/google-services.json` | Firebase (Android) |
| `assets/` | mahsulot rasmlari va logotip |
| `public/index.html`, `public/img/` | yuklab olish sahifasi va suratlari |
| `.git/` | **butun tarix** — fayl buzilsa qaytarish uchun |
| `hujjatlar/` | TZ (Word), Figma maketlari va plagini |
| `DAVOM.md` | shu hujjat |

> Haqiqiy ma'lumotlar (mijozlar, rejalar, chatlar) Firebase'da — ular ko'chmaydi va
> yo'qolmaydi.

### Yangi kompyuterda Claude Code bilan boshlash

1. Zipni oching, **`kotta_qani_diet` papkasini** VS Code'da oching (ichidagi emas, aynan shu).
2. Claude Code'ga **bitta** xabar yozing, bir nechta ketma-ket emas:
   > `DAVOM.md faylini o'qib chiq va ishni davom ettir`
3. "Stewing..." — bu xato emas, "o'ylayapman" degani. 3–4 daqiqadan oshsa, qizil
   to'xtatish tugmasini bosib, xabarni qayta yuboring.

**Birinchi buyruqlar (yangi kompyuterda, shu tartibda):**

```powershell
flutter pub get                 # paketlar
flutter analyze                 # 0 xato bo'lishi kerak
flutter test                    # 85/85
git log --oneline | select -First 5   # tarix joyidami
```

Git sozlanmagan bo'lsa (`git log` xato bersa):
```powershell
git config user.name "Diamond"
git config user.email "sizning-email@example.com"   # sizning email
```

Har ish kuni oxirida: `git add -A` → `git commit -m "nima qilindi"`.

### Yangi kompyuterda nima o'rnatish kerak

| Nima | Havola / buyruq |
|---|---|
| Flutter 3.47+ | https://docs.flutter.dev/get-started/install/windows |
| Google Chrome | https://google.com/chrome |
| Node.js LTS | https://nodejs.org — faqat `deploy` uchun |
| firebase-tools | `npm install -g firebase-tools` |
| Java 21 (Temurin) | https://adoptium.net — faqat APK uchun |
| Android SDK | Android Studio, yoki cmdline-tools (platform 36, build-tools 36.0.0) |

Faqat ilovani **ko'rish** kerak bo'lsa — Flutter va Chrome yetadi.
APK yig'ish kerak bo'lsa — Java va Android SDK ham.

### Birinchi ishga tushirish

```powershell
flutter pub get
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

Tekshirish: `flutter analyze` (0 xato) va `flutter test` (16/16).

### Diqqat
- APK yig'ishdan oldin `android/diamond-release.jks` va `key.properties` joyida
  ekaniga ishonch hosil qiling. Bo'lmasa Gradle debug kaliti bilan imzolaydi va
  yangilanish eski ilova ustiga tushmaydi.
- `flutter doctor --android-licenses` ni bir marta bajarish kerak bo'lishi mumkin.

---

## 6. Buyruqlar

```powershell
# Ilovani brauzerda ishga tushirish (xotira tang bo'lsa web-server rejimi yengilroq)
powershell -ExecutionPolicy Bypass -File .\start.ps1
flutter run -d web-server --web-port 5173 --web-hostname 127.0.0.1   # keyin Chrome'da oching

# Tekshiruv
flutter analyze
flutter test                          # 16 ta test

# Xavfsizlik qoidalari testi (33 ta holat, lokal emulyator, haqiqiy bazaga tegmaydi)
firebase emulators:start --only firestore --project demo-rules-test
cd tools\rules_test; npm install; node test.mjs

# APK
flutter build apk --release --split-per-abi
copy build\app\outputs\flutter-apk\app-arm64-v8a-release.apk public\app\kq.bin
copy build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk public\app\kq-eski.bin

# Firebase'ga joylash (qoidalar + yuklab olish sahifasi)
powershell -ExecutionPolicy Bypass -File .\deploy.ps1
# yoki JOYLASH.bat ustiga ikki marta bosing

# Ikonka (logotip o'zgarsa)
dart run tools/make_icon.dart
dart run flutter_launcher_icons
```

---

## 7. Tuzilma

```
lib/
  main.dart                   Firebase ulanishi, qorong'i tema, fon, keng ekran ramkasi
  theme.dart                  Diamond dizayn tizimi (ranglar, AppSpace, AppRadius)
  firebase_options.dart       Firebase sozlamalari (flutterfire configure)
  models/models.dart          AppUser (rol, goal, trainerId, BMI, targetKcal), Food, MealItem,
                              Meal, Plan (category), WeightLog (canAdd/daysLeft), ChatMessage
  models/stats.dart           Trenerlar reytingi hisobi (ClientStat, TrainerStat) — Firestore'siz
  models/gym.dart             Zal mashg'ulotlari: kun variantlari, guruhlar, "kelolmayman" matni
  models/shop.dart            Do'kon: Product, ShopOrder, SalesReport (kim nechta sotdi)
  models/feed.dart            "Eslatma" bo'limi: bildirishnomalar ro'yxatini yig'ish
  models/hudud.dart           O'zbekiston viloyat va tumanlari (zal manzili uchun)
  services/db.dart            Auth + Firestore, Riverpod providerlar, Db.trainerStats()
  widgets/ui.dart             Umumiy komponentlar (BentoTile, showSheet, ...)
  widgets/food_image.dart     Mahsulot rasmi (nomdagi birinchi mahsulot -> rasm), mualliflar oynasi
  screens/auth/               AuthGate (rolga qarab; maqsadsiz shogird -> anketa), Login
  screens/user/               Bugun, Progress (vazn qulfi), Chat, Profil, Anketa (maqsad)
  screens/admin/              Mijozlar, Rejalar (shablonlar, haftalik menyu), Ovqat bazasi,
                              Zal (trener), Do'kon, Xodimlar (zallar va rollar),
                              trainer_stats_screen (reyting), sales_report_screen (sotuv hisoboti)
  screens/barmen/             Barmen paneli (Do'kon · Hisobim · Eslatma)
  screens/notifications_screen.dart   "Eslatma" bo'limi va menyudagi qizil raqam (FeedBadge)
assets/foods/                 34 ta mahsulot rasmi; assets/credits.txt — mualliflar (CC litsenziya)
assets/icon/logo_src.jpg      Ilova logotipi (manba)
test/widget_test.dart         50 ta test
tools/make_icon.dart          Logotipdan ikonka rasmlari
tools/rules_test/             firestore.rules testlari (77 ta holat)
functions/                    Push bildirishnomalar (Cloud Functions, Blaze kerak) — FUNKSIYALAR_JOYLASH.bat
tools/parol_tiklash/          Parolni unutganlarga yangi parol (PAROL_TIKLASH.bat chaqiradi)
                              va akkauntni to'liq o'chirish (ochirish.mjs)
tools/brauzer/cdp.mjs         Brauzerni buyruq qatoridan boshqarish (ilovani tekshirish uchun)
hujjatlar/                    Diamond-TZ.docx, figma/ (13 ekran SVG + PNG), figma-plugin/
firestore.rules               Xavfsizlik qoidalari
firebase.json, .firebaserc    Firebase sozlamalari
public/                       Yuklab olish sahifasi + APK fayllari
start.ps1                     Ilovani ishga tushirish
deploy.ps1, JOYLASH.bat       Firebase'ga joylash
emulators.ps1                 Lokal emulyator
usb.ps1, internet.ps1         Eski yordamchilar (endi shart emas)
```

---

## 8. Xavfsizlik qoidalari

[firestore.rules](firestore.rules) — asosiy mantiq:

- `isOwner()` — rol o'zgartiradi va hujjat o'chiradi
- `isStaff()` — trener + bosh admin: reja/mahsulot yozadi
- `isTrainerOf(uid)` — trener faqat o'ziga biriktirilgan shogirdni o'qiydi/yangilaydi, uning
  kunlari, vaznlari, chatiga kiradi; `canManage(uid)` = bosh admin yoki shu trener
- Trener rolni **o'zgartira olmaydi** (`same('role')`)
- Foydalanuvchi o'zining rolini, rejasini, reja berilgan vaqtini (`planAssignedAt`) va
  trenerini o'zgartira olmaydi; maqsadini (`goal`) o'zi tanlaydi
- Ro'yxatdan o'tayotgan har kim faqat `user` bo'la oladi
- `same(field)` — `.get(field, null)` orqali, eski hujjatlarda maydon yo'q bo'lsa ham ishlaydi

**77 ta test o'tgan** (`tools/rules_test/`): rol o'zgartirish, bosh admin tayinlash,
o'chirish, trener biriktirish, o'qish huquqlari, reja/mahsulot, chat, ro'yxatdan o'tish.

> `firestore.rules` o'zgartirilsa — **joylashdan oldin** testni ishga tushiring.

---

## 9. ⚠️ Ochiq masalalar

### 9.1. ~~Qoidalar hali joylanmagan~~ — HAL BO'LDI (14-sent kechqurun)
Yangi `firestore.rules` Firebase'ga joylandi (`released rules firestore.rules`). Endi
rolni faqat bosh admin o'zgartiradi. Firebase CLI bu kompyuterda kirgan holatda —
`deploy.ps1` to'g'ridan-to'g'ri ishlaydi.

### 9.2. ~~Yuklab olish sahifasi eski~~ — HAL BO'LDI (14-sent kechqurun)
Saytda eng yangi APK (21,6 MB, `CN=Diamond Zal` imzosi) turibdi — HEAD so'rovi bilan
tekshirildi.

### 9.3. ~~APK'da eng yangi kod yo'q~~ — HAL BO'LDI (14-sent)
APK **14-sentabr 08:54** da qayta yig'ildi, unda "Bosh admin qilish / tushirish" ham bor.
`public/app/kq.bin` va `kq-eski.bin` ham yangilandi. Faqat hostingga joylash qoldi (9.2).

### 9.4. Imzo kaliti — HAL BO'LDI (14-sent), lekin oxirgi marta o'chirish kerak

**Muammo shu edi:** Windows qayta o'rnatilganda `~/.android/debug.keystore` yo'qolgan,
Gradle har kompyuterda yangi debug kaliti yaratardi. Android imzosi boshqacha
yangilanishni o'rnatmaydi — shuning uchun yangi APK eski ilova ustiga tushmasdi.

**Yechim (14-sent):** loyihaning o'zida **doimiy release kaliti** yaratildi:

| Fayl | Nima |
|---|---|
| `android/diamond-release.jks` | kalit (JKS, 10000 kun amal qiladi) |
| `android/key.properties` | parol va alias: `diamond` / `diamond2026` |
| `android/app/build.gradle.kts` | `signingConfigs.release` shu kalitni o'qiydi |

Sertifikat: `CN=Diamond Zal, OU=Diamond, O=Diamond Zal, L=Tashkent, C=UZ`
SHA-256: `7f6ad1c620eb6330ea36ca16c2826ef566220b7ae3274567deebf0f462e0007c`

Endi APK **qaysi kompyuterda yig'ilishidan qat'i nazar bir xil imzoga ega** —
yangilanishlar eski ilova ustiga bemalol tushadi.

> ⚠️ **`android/diamond-release.jks` va `key.properties` ni YO'QOTMANG.**
> Ko'chirishda albatta olib keting, zaxira nusxa saqlang. Yo'qolsa — hamma mijoz
> ilovani o'chirib qayta o'rnatishga majbur bo'ladi va bu tuzatib bo'lmaydigan holat.
>
> `key.properties` bo'lmasa, Gradle jimgina debug kalitiga qaytadi — build buzilmaydi,
> lekin imzo boshqacha chiqadi. APK yig'ishdan oldin fayl joyida ekanini tekshiring.

**Oxirgi marta o'chirish kerak:** 14-sentabr 09:06 dan oldingi barcha APK'lar debug
kaliti bilan imzolangan. Kimda ular o'rnatilgan bo'lsa — **bir marta** o'chirib,
yangisini o'rnatadi. Bundan keyin hech qachon kerak bo'lmaydi.

### 9.5. Ekranlar vizual tekshiruvi — ASOSAN HAL BO'LDI (15-sent)
Trener va bosh admin ekranlari telefon o'lchamida (390×844) brauzerda ko'rildi va topilgan
kamchiliklar tuzatildi (30-band). **Qolgani:** shogird ekranlari (Bugun, Anketa, Progress,
Profil, Chat) — shogird akkaunti paroli yo'q, ko'rilmagan.

### 9.6. ~~Parolni o'zgartirish / tiklash yo'q~~ — HAL BO'LDI (15-sent)
- **O'zgartirish:** shogird Profil → "Parolni o'zgartirish"; trener/bosh admin — yuqoridagi kalit.
- **Unutganlar:** login ekranida "Parolni unutdim" → zal egasiga murojaat qilish yo'riqnomasi.
  Bosh admin shu kompyuterda `PAROL_TIKLASH.bat` ni ishga tushiradi: telefon raqam va
  vaqtinchalik parol kiritadi. Ichida `tools/parol_tiklash/tiklash.mjs`: `firebase auth:export`
  → shu akkauntni BCRYPT xeshli yangi parol bilan `firebase auth:import` (uid saqlanadi,
  Firestore ma'lumotlari joyida qoladi). Vaqtinchalik fayllar o'chiriladi.
  Test akkauntida sinaldi: yangi parol bilan kirdi, eskisi ishlamadi, hujjat o'sha uid'da.
- Cheklov: faqat Firebase CLI kirgan kompyuterda ishlaydi (telefondan emas).

### 9.7. Trener bilan aniqlashtirish kerak (mahsulot savollari)
- "50 g grechka qaynatilgan holda" — quruq vazn yoki pishgan vazn? (shablonda quruq)
- "Fruktozadan voz keching" deyilgan, lekin rejada olma/qulupnay bor — qoldiramizmi?

### 9.8. Akkaunt o'chirilganda qoldiqlar
`Db.deleteUser()` faqat `users/{uid}` hujjatini o'chiradi. Ichki to'plamlar
(`days/`, `weights/`) va Firebase Auth akkaunti qoladi — mijoz kutubxonasi ularni
o'chira olmaydi. Amalda muammo emas: hujjatsiz kirishni `AuthGate` to'sadi
("Akkaunt topilmadi" ekrani). To'liq tozalash uchun Cloud Functions (Blaze tarifi) kerak.

### 9.9. ~~Shogirdlar maqsad tanlamagan~~ — ESKIRDI (15-sent 12:00)
Barcha shogirdlar foydalanuvchi so'rovi bilan o'chirildi (39-band). Yangi shogirdlar
ro'yxatdan o'tganda anketada maqsad va metabolizmni tanlaydi; bosh admin trenerga biriktiradi.

### 9.10. ~~Trener formulasi~~ — QILINDI (15-sent)
`AppUser.targetKcal` = vazn × `kcalPerKg` (ayol 31/33, erkak 33/35; metabolizm tanlanmagan —
sekin). Ozish: −20% (BMI < 23 bo'lsa defitsit yo'q, minimum erkak 1500 / ayol 1200),
massa: +10%. Anketada "Faollik darajasi" o'rniga "Moddalar almashinuvi" (sekin/tez).
`activity` maydoni modelda qoldi, hisobda ishlatilmaydi.
**Qaror (men qabul qildim):** −20% / +10% tuzatish formula ustidan saqlandi — trener
formulaning o'zini xohlasa, `targetKcal` dagi ikki qatorni olib tashlash kifoya.

### 9.11. ~~Har trener faqat o'z shogirdlarini ko'rsin~~ — QILINDI (15-sent)
Ilova: trener uchun `Db.clientsOf(trainerId)`, bosh admin uchun `Db.clients()`.
Qoidalar: trener faqat `trainerId == o'zi` bo'lgan shogirdni o'qiydi/yangilaydi (trenerni
o'zgartira olmaydi), uning kunlari/vaznlari/chatiga faqat shu trener va bosh admin kiradi;
xodimlar hujjatlarini o'qiy oladi (bosh admin bormi — tekshirish uchun). 49 qoida testi;
haqiqiy bazada trenerning "hamma shogirdlar" so'rovi 403 bilan rad etildi.
**Oqibat:** eski APK dagi trener panelida Mijozlar ishlamaydi — yangi APK kerak.

### 9.12. Bosh admin trenerga qo'lda baho qo'ysin — QILINMADI
Foydalanuvchi bu safar so'ramadi (faqat 9.10 va 9.11 ni tanladi). Hozir reyting avtomatik.

### 9.13. Shablonlar — TUZATILDI (15-sent)
- **Massa nabor 3-versiya** — trener maslahatlari asosida 6 mahal (har 2–3 soat, sekin
  uglevodlar, gainer mashg'ulotdan oldin/keyin), ~2720 kkal. Porsiyalar taxminiy.
- **Massa nabor 2-versiya** — muqobil mahsulotlar bir qatorda, ikkinchi protein olib
  tashlandi: ~2700 kkal, ~205 g oqsil (avval 2915 / 258). Bazadagi saqlangan reja ham
  yangilandi (Axror shu rejada).
- 1-versiya va Ozish 2-versiyadagi izohlar o'zgarmadi (9.13 eski yozuvlari o'rinli).
- **Abdusamad (BMI 18,3):** ilovaga himoya qo'shildi — BMI < 18,5 bo'lsa anketada "Ozish"
  o'chiq, trener ham belgilay olmaydi, sahifada qizil ogohlantirish. Uning rejasini
  men o'zgartirmadim.

### 9.14. Cheklovlar (bilib qo'yish uchun)
- Vazn qulfi faqat ilova ichida — `firestore.rules` da tekshirilmaydi (qoidalar oxirgi
  o'lchov sanasini so'rov bilan topa olmaydi).
- 9.8 ga qo'shimcha: akkaunt o'chirilganda Auth akkaunti qoladi, shuning uchun **o'sha raqam
  bilan qayta ro'yxatdan o'tib bo'lmaydi** ("raqam band"). Parolni unutganlarga `PAROL_TIKLASH.bat`.
- ~~Reytingda "rioya" 7 kunga bo'linadi~~ — hal bo'ldi (15-sent): `planAssignedAt` saqlanadi,
  rioya shu kundan hisoblanadi. Eski biriktirishlarda vaqt yo'q — ular uchun hali 7 kun.
  Chatga javobni istalgan xodim bersa hisoblanadi.
- Maqsadga mos reja **sarlavha** bo'yicha aniqlanadi ("Ozish • ..." / "Massa nabor • ...").
  Reja muharriri buni kategoriya tugmasi bilan o'zi qo'yadi.

---

## 10. Keyingi funksiyalar (rejalashtirilgan, boshlanmagan)

| Funksiya | Pul kerakmi | Taxminiy mehnat |
|---|---|---|
| **Ovqat vaqti eslatmasi** (lokal bildirishnoma) | ❌ Bepul | ~0,5 kun |
| **Trener: "bugun kim yedi"** paneli | ❌ Bepul | ~0,5 kun |
| **Mashg'ulotlar bo'limi** | ❌ Bepul | ~1,5 kun |
| **Rus tili** | ❌ Bepul | ~1 kun |
| Kunlik SMS ratsion | ✅ Blaze + Eskiz.uz | ~1 kun |
| Payme / Click obuna | ✅ Merchant + Blaze | ~3 kun |

**Muhim topilma:** kunlik eslatmani SMS'siz ham qilsa bo'ladi.
`flutter_local_notifications` bilan telefonning o'zi reja vaqtlarida
(`Meal.time`: 07:00, 10:30, 13:00, 15:00, 18:00) eslatadi — server ham, Blaze tarifi
ham, SMS puli ham kerak emas. Kamchiligi: faqat ilova o'rnatganlarga boradi.

---

## 11. Qilingan ishlar (qisqacha tarix)

**2026-09-11 va oldin** — ilova yozildi: mijoz va trener panellari, Kotta Qani
shabloni (5 mahal, ~1450 kkal), 19 ta mahsulot rasmi (Wikimedia, erkin litsenziya),
telefon+parol bilan kirish, haqiqiy Firebase'ga ulanish, birinchi APK.

**2026-09-12:**
1. **Muhit tiklandi** — yangi kompyuterda Flutter, Node, Java, Android SDK,
   firebase-tools noldan o'rnatildi.
2. **Hujjatlar tuzatildi** — README haqiqiy holatga moslandi, kirill harf xatolari.
3. **Dizayn to'liq yangilandi** — avval "expressive minimalism" (issiq qog'oz + ink),
   so'ng foydalanuvchi spetsifikatsiyasi bo'yicha **Diamond qorong'i tizimi**
   (to'q grafit + olmos ko'ki, shisha effekti, 8–16 px burchaklar, ingichka ikonkalar,
   pop-up o'rniga pastdan chiquvchi varaqlar).
4. **Suv va vazn aniqlashtirildi** — suv "1 stakan = 250 ml" deb yozildi; vazn haftada
   1 marta, keyingi o'lchovgacha necha kun qolgani ko'rsatiladi, erta kiritilsa
   ogohlantiradi (to'smaydi).
5. **Brend nomi** — "Kotta Qani" → **"Diamond"** (ilova ichi, telefondagi nom, web).
   Firebase loyihasi va havolalar o'zgarmadi (o'zgartirsa akkauntlar yo'qoladi).
6. **Ilova ikonkasi** — trenerning logotipi (bodibilder silueti) ikonkaga aylantirildi:
   oq fon shaffofga o'tkazildi, barcha o'lchamlar + adaptiv + monoxrom variantlar.
7. **Bosh admin roli** — `owner` roli, "Xodimlar" bo'limi, trener tayinlash/olish,
   shogirdni trenerga biriktirish, akkaunt o'chirish.
8. **Xavfsizlik qoidalari qayta yozildi** va **33 ta test** bilan sinovdan o'tkazildi.
9. **Tuzatilgan xato** — akkaunt o'chirilganda ilova cheksiz yuklanishda qolardi;
   endi 5 soniya kutib, "Akkaunt topilmadi" ekranini ko'rsatadi.

**2026-09-13:**
10. **Bosh admin qilish / tushirish** amali qo'shildi (avval faqat "trener qilish" bor edi),
    yagona bosh adminni tushirishga himoya.
11. **Ikkita alohida akkaunt** yaratildi: `99XXXXXXX` (bosh admin) va `900000000` (trener).
    Bosh admin akkaunti Firebase REST orqali yaratilib, roli `owner` qilindi; trener
    `owner` dan `admin` ga tushirildi.

**2026-09-14:**
12. **DAVOM.md yaratildi** — hamma narsa bitta faylda; qolgan uch hujjatga bu yerga
    yo'naltiruvchi qator qo'yildi.
13. **APK qayta yig'ildi** (08:54) — endi "Bosh admin qilish / tushirish" ham ichida.
    `public/app/` fayllari yangilandi.
14. **`deploy.ps1` yaxshilandi** — joylashdan oldin `build/` dagi APK `public/app/` dan
    yangiroq bo'lsa, uni o'zi ko'chiradi. Endi APK'ni qo'lda nusxalash esdan chiqmaydi.
15. **Doimiy imzo kaliti** yaratildi (`android/diamond-release.jks`) va yig'ishga ulandi —
    endi APK qaysi kompyuterda yig'ilishidan qat'i nazar bir xil imzoga ega.
    APK qayta yig'ilib tekshirildi: `CN=Diamond Zal`. Batafsil — 9.4.
16. **"Boshqa kompyuterga ko'chirish" bo'limi** qo'shildi (5b): nimani ko'chirish,
    nimani tashlab ketish, yangi kompyuterda nima o'rnatish kerak.
17. **Boshqa kompyuterga ko'chirishda muammo** — butun papka zip qilinganda 2,3 GB chiqdi
    va u yerdagi Claude Code "Stewing..." da turib qoldi. Sabab: `build/`, `.dart_tool/`,
    loyiha ichidagi eski 513 MB zip va plagin havolalari (260 belgidan uzun yo'llar).
    **`E:\Diamond-toza.zip`** yasaldi — 23 MB, 149 fayl; ochib, `pub get` + `analyze`
    bilan sinaldi. 5b-bo'limga to'g'ri usul yozildi.
18. `deploy.ps1` endi natijani `joylash-log.txt` ga yozadi; avvalgi urinishdan qolgan
    yarim Firebase kirish holati (`tempLoginState`) tozalandi.
19. **Ikkinchi ozish shabloni** — "Ozish • 60 / 65 / 75 kg (2-versiya)" (trener matni
    bo'yicha, 6 mahal, ~1630 kkal, ~160 g oqsil). "Shablon" tugmasi endi tanlash
    varag'ini ochadi (`planTemplates()`). **APK hali qayta yig'ilmagan.**
20. **Massa nabor kategoriyasi** — 2 ta shablon: "1-versiya (grammli)" (4 mahal, ~2540
    kkal) va "2-versiya (tanlovli)" (6 mahal, ~2900 kkal; trener matnida gramm yo'q edi,
    porsiyalar taxminiy). Shablon varag'i kategoriya bo'yicha guruhlanadi
    (`Plan.category` — sarlavhaning " • " gacha qismi). Qaysi rejani berishni
    trener tanlaydi.
21. **Shogird maqsadi** — `users/{uid}.goal`: `'lose'` (Ozish) / `'gain'` (Massa nabor).
    Anketaning birinchi bo'limi "Maqsad", tanlamasdan saqlab bo'lmaydi. `AuthGate`
    maqsadi yo'q **eski shogirdlarni ham bir marta anketaga qaytaradi**.
    Massa nabor uchun norma TDEE +10% (ozishda -20% qoldi).
    Trener: mijozlar ro'yxatida maqsad belgisi (Ozish ↓ / Massa nabor ↑), mijoz
    tafsilotida maqsad, reja ro'yxatida mos kategoriya **★ bilan tepada**, boshqa
    kategoriyadagi reja biriktirilsa ogohlantirish. Profilda ham maqsad ko'rinadi.
    `AppUser.goalLabel` va `planCategories` bir xil nomlar — reja sarlavhasi
    "Ozish • ..." / "Massa nabor • ..." bilan boshlanishi kerak. Qoidalar o'zgarmadi
    (shogird o'z `goal` ini yoza oladi). **APK qayta yig'ilmagan.**
22. **Trener rasmlaridagi matnlar to'liq** — "Ozish 2-versiya" izohiga trener matni
    so'zma-so'z qo'shildi. **"Massa nabor • 3-versiya (maslahatlar)"** shabloni:
    kaloriya hisoblash (1 kg vaznga 31/33/35), metabolizm, gamburger va guruch-tovuq
    solishtiruvi, massa nabor maslahatlari, sekin singuvchi uglevodlar indeksi.
    Rasmlarda ovqat jadvali yo'q — mahallari bo'sh, trener qo'shadi. Matn shogirdda
    "Bugun" ekranidagi "Trener maslahati" kartochkasida chiqadi.
23. **Trenerlar reytingi** (faqat bosh admin): Xodimlar → "Trenerlar reytingi".
    So'nggi 7 kun bo'yicha har trenerga 0–100 ball va 1–5 yulduz. Tarkibi: reja berilgan
    shogirdlar 30%, chatga javob (oxirgi xabar shogirddan emas) 25%, shogirdlarning
    "yedim" rioyasi 25%, vazn maqsad tomon siljishi 20%. Ma'lumoti yo'q qism hisobga
    olinmaydi. Trenerlar ko'rsatkichlar bo'yicha yonma-yon solishtiriladi; trener
    ichida "E'tibor kerak" shogirdlar sababi bilan (reja yo'q, javob kutmoqda, rioya <50%,
    vazn 14 kundan beri yo'q, natija yo'q). Mantiq — [lib/models/stats.dart](lib/models/stats.dart),
    yuklash — `Db.trainerStats()`, ekran — `trainer_stats_screen.dart`. Qo'lda baho
    qo'yish yo'q (qoidalar o'zgarishi kerak bo'lardi).
24. **Vazn qat'iy haftada 1 marta** — avval faqat ogohlantirardi, endi to'sadi.
    `WeightLog.canAdd/daysLeft` (kalendar kun bo'yicha, 7 kun). Progress'da tugma
    "Vazn: N kundan keyin" bo'lib o'chadi; anketada vazn birinchi kiritilgach
    qulflanadi. Faqat ilova ichida tekshiriladi (qoidalarda emas). Testlar 34/34.
    Web release yig'ildi (`build\web`), lokal: `python -m http.server 5173 --directory build\web`.
    Bosh admin va trener loginlari REST orqali tekshirildi — ishlaydi.
25. **Trener massa nabor rejasini bera olmasdi** — sabab: bazada faqat bitta reja
    ("Ozish • 80-90 kg") saqlangan, shablonlar esa faqat "Shablon" tugmasida edi.
    Endi mijoz sahifasida: **Maqsad** tugmalari (shogird tanlamagan bo'lsa trener
    belgilaydi, `Db.setGoal`) va maqsadga mos **barcha variantlar** ro'yxati (shablonlar +
    shu kategoriyada saqlangan rejalar). Saqlanmagan shablon tanlansa — avval bazaga reja
    bo'lib saqlanadi, keyin biriktiriladi (`Db.savePlan` endi id qaytaradi). Mijozlar
    ro'yxatida maqsadi yo'qlarga "Maqsad ?" belgisi. 14-sentabr holati: 5 shogirddan
    faqat Axror maqsad tanlagan (gain), qolganlari hali yangi versiyada kirmagan.
26. **Birinchi joylash** — APK yig'ildi (imzo tekshirildi), `deploy.ps1` bilan qoidalar +
    hosting joylandi. Firebase CLI bu muhitda kirgan holatda ekan — ishladi.
27. **Trener faqat maqsadga mos rejani beradi** (foydalanuvchi talabi: "massa tanlagan
    bo'lsa trener faqat massadan beradi, ozish tanlasa ozishdan"). Mijoz sahifasidagi
    "barcha rejalar" ro'yxati olib tashlandi — faqat maqsad variantlari va "Rejani olib
    tashlash". Shogird tanlagan maqsadni trener o'zgartira olmaydi (faqat bo'sh bo'lsa
    belgilaydi). Reja muharririda **Kategoriya** (Ozish / Massa nabor) majburiy —
    sarlavha "Kategoriya • nomi" bo'lib saqlanadi. Qayta yig'ilib joylandi.
28. **Mahsulot rasmlari** — foydalanuvchi: "bir xil mahsulotlarning rasmi yo'q". Sabablar:
    (a) guruch, banan, sut, bodom, brokkoli, makaron, kartoshka, kefir, pishloq, shokolad,
    limon, piyoz, kivi, meva, bolgar qalampiri uchun rasm yo'q edi; (b) qoida tartibi
    tufayli "Yong'oq (yoki protein)" → protein rasmi, "Tovuq / ... / baliq" → baliq.
    15 ta yangi rasm Wikimedia Commons'dan (ko'z bilan ko'rib tanlandi, mualliflar
    `credits.txt` da). `foodAsset()` endi so'z boshidan qidiradi va nomdagi **eng oldin
    kelgan** mahsulotni oladi; teng bo'lsa uzunroq kalit ("tuxum oqi" > "tuxum").
    "Osh" → guruch rasmi. Test: shablonlardagi har bir mahsulotning rasmi bor; bazadagi
    20 ta mahsulot ham tekshirildi.
29. **Oxirgi joylash (14-sent kechqurun)** — testlar 38/38, web + APK qayta yig'ildi,
    imzo `CN=Diamond Zal`, `deploy.ps1` → qoidalar va hosting joylandi, saytdagi
    `kq.bin` 21,6 MB (yangi) ekani tekshirildi.

**2026-09-15:**
30. **Ekranlar ko'z bilan tekshirildi** — headless Chrome + CDP skripti (scratchpad'da,
    loyihaga kirmaydi), 390×844, trener va bosh admin akkauntlari, bazaga hech narsa
    yozilmadi. Topilgan va tuzatilgan kamchiliklar:
    - Mijoz sahifasida **ichma-ich o'ralish** (yuqori 60% o'raladi, progress kartochkasi
      variantlarni yopardi) → **"Reja" / "Progress" tablari**.
    - **Maqsad ko'rinmasdi** — ikkala ChoiceChip o'chiq va bir xil kulrang → maqsad bo'lsa
      `GoalPill`, bo'lmasa ikkita tugma.
    - `StatTile` sarlavhalari qirqilardi ("REJA B…", "NORMA, …") → `FittedBox` bilan kichrayadi.
    - "Maqsad ?" belgisi xira edi → sariq.
    - Vazn o'zgarmaganda (0.0) "pastga" o'qi → tekis o'q; massa naborda vazn oshishi
      urg'u rangida (avval ogohlantirish rangida edi).
    - Mahsulotlarda **"Osh" 0 kkal** → "Kaloriya kiritilmagan" qizil belgisi.
31. **Parolni o'zgartirish** (9.6) — `lib/widgets/change_password.dart`, tekshiruv
    `validateNewPassword` testlangan.
32. **Reja berilgan vaqt** — `Db.assignPlan` `planAssignedAt: serverTimestamp` yozadi;
    `ClientStat.trackedDays` rioyani shu kundan hisoblaydi; `firestore.rules` shogird uni
    o'zgartira olmasligini tekshiradi (+3 qoida testi: planAssignedAt, goal shogird, goal trener).
33. **Joylash (09:17)** — testlar 40/40, qoida testlari 36/36 (emulyator), web + APK,
    imzo `CN=Diamond Zal`, qoidalar + hosting joylandi.
34. **Foydalanuvchi "hammasini qil" dedi** (trener formulasi, trener faqat o'z shogirdlari,
    Osh, Abdusamad, maqsadsizlar, massa shablonlari, shogird ekranlarini tekshirish,
    parolni unutganlar):
    - Trener formulasi + metabolizm anketada (9.10).
    - Trener faqat o'z shogirdlari: ilova + qoidalar, 49 qoida testi (9.11).
    - BMI < 18,5 da ozish bloklangan (9.13).
    - Massa 2- va 3-versiya qayta tuzildi; bazadagi 2-versiya rejasi yangilandi (9.13).
    - "Osh" ga taxminiy KBJU yozildi (REST, bosh admin nomidan).
    - Login'da "Parolni unutdim", `PAROL_TIKLASH.bat` + `tools/parol_tiklash/` (9.6).
    - Profilda metabolizm katagi.
35. **Shogird ekranlari tekshirildi** — vaqtinchalik "TEST Claude" (+998 97 777 77 77)
    akkaunti brauzerda ro'yxatdan o'tkazildi: anketa (BMI 17 da Ozish o'chiq, 55 kg × 35
    + 10% = 2118 kkal), Bugun, Progress (vazn qulfi "7 kundan keyin"), Profil, parolni
    o'zgartirish (server tekshirdi), parol tiklash vositasi (2 marta). Keyin **to'liq
    o'chirildi**: `firebase firestore:delete users/<uid> -r` + Auth `accounts:delete`;
    bazada yana asl 7 ta akkaunt.
36. **Joylash (10:10)** — testlar 44/44, qoida testlari 49/49, web + APK (`CN=Diamond Zal`),
    qoidalar + hosting; haqiqiy bazada trener so'rovlari tekshirildi (o'zinikilar — 2 ta,
    hammasi — 403).
37. **Reja kategoriyasi qat'iy** (foydalanuvchi: "shogird kategoriyasiga mos kelmaydigan
    retsept blokda bo'lsin, ozish narsasi chiqib qolmasin"): `planCategories` models.dart ga
    ko'chdi, `AppUser.fitsPlan(plan)`; mijoz sahifasida mos kelmaydigan reja nomi o'rniga
    "bloklangan" yozuvi, BMI past bo'lsa "Ozish" tugmasi yashirin; mijozlar ro'yxatida
    "Reja mos emas" (Kutmoqda soniga kiradi); shogird "Bugun"da bloklangan reja o'rniga
    "Reja yangilanmoqda".
38. **Trener bosh adminni ko'rmaydi** (foydalanuvchi: "trener bosh adminni ko'rmasligi,
    borligini bilmasligi kerak"): `Db.trainers()` (faqat `admin`) — trener tanlash va
    reytingda; `_OwnerBootstrap` banneri olib tashlandi; `ChatScreen.onlyMineAndClient` —
    trener faqat o'zi va shogird xabarlarini ko'radi; qoidalar: trener faqat
    `trainerId == o'zi` hujjatlarni o'qiydi (+2 test: bosh admin va boshqa trener hujjati).
    Testlar 45/45, qoida testlari 51/51, joylandi.
39. **Baza tozalandi** (foydalanuvchi: "trener va admindan boshqa userlarni o'chir"):
    avval `zaxira/2026-09-15_ochirilgan_shogirdlar.json` ga users hujjati, weights, days,
    chat saqlandi; keyin `firebase firestore:delete users/<uid> -r` va `chats/<uid> -r`;
    Auth akkauntlari — vaqtinchalik BCRYPT parol import qilinib `accounts:delete` bilan.
    Natija: Auth 2 ta, Firestore users 2 ta; ikkala login REST bilan tekshirildi.
    `tools/parol_tiklash/tiklash.mjs` ham CLI'ning chiqishdagi qulashiga chidamli qilindi.
40. **Shogird trenerni o'zi tanlaydi; katalogni trener boshqaradi** (foydalanuvchi: "mijoz
    trener tanlashi kerak va u trenerga chiqishi kerak, adminda emas; admin trenerni va
    nechta shogirdi borligini ko'radi"; "katalogni trener boshqaradi"):
    - `trainers/{uid}` katalogi (`TrainerInfo`: name, bio, accepting). Shogird trenerning
      `users` hujjatini ko'rmaydi (telefon yopiq) — faqat katalog yozuvini.
    - Anketada "Treneringiz" bo'limi (qabul qilayotgan trenerlar); `AuthGate` katalogda
      trener bo'lsa trenersiz shogirdni anketaga qaytaradi (`trainerDirectoryProvider`).
    - Qoidalar: `trainerChoiceOk()` — shogird `trainerId` ni faqat bo'sh bo'lsa va katalogda
      `accepting == true` trener bo'lsa qo'yadi. Katalog: o'qish — hamma kirganlar; yozish —
      faqat shu trener (ism ≤ 60, bio ≤ 300, faqat 3 maydon); bosh admin faqat qo'shadi/o'chiradi.
    - `Db.setRole` trener tayinlanganda yozuv qo'shadi (bor bo'lsa tegmaydi), olinganda o'chiradi;
      `Db.syncTrainerDirectory()` bosh admin ilovani ochganda yo'q yozuvlarni qo'shadi,
      trener bo'lmaganlarnikini o'chiradi (trener sozlamalariga tegmaydi).
    - Trener Mijozlar tepasida "Katalogdagi profilim" (tahrirlash, qabul qilish tugmasi);
      shogird profilida "Treneringiz".
    - `AppUser.kcalFormula` — profil va anketada "80 kg × 33 − 20%" ko'rinishi.
    - Tekshiruv: qoida testlari 64/64 (+13), testlar 46/46; brauzerda to'liq oqim: bosh admin
      kirdi (katalog yozuvi yaratildi) → test shogird ro'yxatdan o'tib trenerni tanladi →
      trener Mijozlarida paydo bo'ldi. Test akkaunt o'chirildi.
41. **Qolgan ishlar + tema + bildirishnomalar** (foydalanuvchi: "qilinmaganlarni qil; tema va
    notification bitganmi"; tanlovi: yorug'/qorong'i rejim; ovqat, vazn, chat, reja bildirishnomasi):
    - **Tema**: `AppColors` endi getter (`AppColors.light`), yorug' palitra (urg'u #0891B2);
      `AppTheme.current()`; 249 ta `const` avtomatik tozalandi (analyzer xatolari bo'yicha skript);
      `AppSettings` (shared_preferences) — `themeMode`; `MaterialApp` kaliti rejimga bog'liq
      (almashganda butun daraxt qayta quriladi). `lib/widgets/settings_sheet.dart`.
    - **Bildirishnomalar**: `flutter_local_notifications` 22 + `timezone` (Asia/Tashkent),
      `lib/services/notifications.dart` (ovqat — kunlik `zonedSchedule`, vazn — bir martalik,
      `inexactAllowWhileIdle`), `lib/services/reminders.dart` (sof hisob, testlangan),
      `lib/widgets/notification_sync.dart` (shogird: reja/vazn/chat/yangi reja; trener: shogird
      xabarlari; faqat ilova orqa fonda bo'lsa). Android: POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED,
      receiverlar, core library desugaring.
    - **Push (FCM)**: `firebase_messaging`, token `users/{uid}.fcmTokens` (chiqishda o'chiriladi),
      `functions/index.js` (v1 triggerlar, europe-west1): `onChatMessage`, `onPlanAssigned`;
      `tag` lokal bildirishnoma bilan bir xil — takrorlanmaydi. **Joylanmadi: Blaze kerak**
      (`firebase deploy --only functions` → "must be on the Blaze plan").
    - **Qo'lda baho**: `ratings/{trainerId}` (faqat bosh admin; stars 1–5, comment ≤ 500),
      reyting tafsilotida `_OwnerRatingCard`, kartochkada "Bahongiz: N/5".
    - **Vazn qulfi serverda**: `Db.addWeight` — batch (weights + `lastWeighIn: serverTimestamp`);
      qoidalar `weightChangeOk()` va weights create `getAfter(...).lastWeighIn == request.time`.
    - **O'chirilgan akkaunt**: `_NoProfile` → parol bilan qayta tasdiqlab `currentUser.delete()`
      (yaqinda kirish talabi tufayli parol so'raladi — birinchi urinishda shu xato topilib tuzatildi);
      `tools/parol_tiklash/ochirish.mjs` + `AKKAUNT_OCHIRISH.bat` (bosh admin/trenerni o'chirmaydi).
    - **Trenerni almashtirish**: qoidada "faqat bo'sh bo'lsa" sharti olib tashlandi (faqat
      qabul qilayotgan trenerga), Profil → "Trenerni almashtirish".
    - Tekshiruv: testlar 50/50, qoida testlari 77/77; brauzerda (yorug' rejimda): trener
      Mijozlar, mijoz sahifasi, chat (bo'sh va xabarli), bosh admin baho qo'yish, test shogird
      anketasi (yangi vazn qoidasi bilan), Progress qulfi, trener almashtirish, "Akkaunt
      topilmadi" → qayta ro'yxatdan o'tish (Auth o'chgani REST bilan tasdiqlandi). Test baho
      va test akkaunt o'chirildi. Bildirishnomalar telefonda KO'RILMAGAN (emulyator yo'q).

---

## 12. Holat: nima ishlaydi

| Tekshiruv | Natija |
|---|---|
| `flutter analyze` | ✅ 0 xato |
| `flutter test` | ✅ 100/100 (4-okt) |
| Qoida testlari | ✅ 164/164 (4-okt, emulyatorda) |
| 61–65-band (abonement/davomat/ustama/o'lcham/QR/zaxira) | ✅ lokal emulyatorda brauzerda sinaldi; ❌ haqiqiy bazaga hali joylanmagan |
| APK yig'ish | ✅ ishlaydi (24-sent 18:00, 25,2 MB arm64, `CN=Diamond Zal`) — 61–65-band o'zgarishlari bilan **hali qayta yig'ilmagan** |
| Web release | ✅ `build\web` — lokal: `python -m http.server 5173 --bind 127.0.0.1 --directory build\web` |
| Firebase'ga joylash | ✅ qoidalar + hosting (24-sent); ❌ Cloud Functions — Blaze kerak |
| Bosh admin / trener login | ✅ REST orqali tekshirilgan (`owner` / `admin`) |
| Ekranlarni ko'z bilan tekshirish | ✅ trener, bosh admin va shogird (15-sent; chat ko'rilmagan) |

42. **Zal bo'limi** (shogird va trenerda): 3 mashg'ulot — 1) Ko'krak + biceps, 2) Qanot (orqa) + oyoq,
    3) Yelka + triceps. Shogird ikki variantdan birini tanlaydi: Se/Pay/Sha yoki Du/Chor/Ju
    (`users.gymDays`, qoidalar faqat shu ikki ro'yxatni qabul qiladi). Shogird: bugungi mashg'ulot,
    jadval, "Mashqlar — tuzatish ishlari olib borilmoqda" (belgilash yo'q). Trener: bugun kim keladi,
    kim uyda, hamma jadvali; **"Uyda mashq"** (`homeWorkoutDate`) faqat shogird bugun chatda
    "kelolmayman / boromiman" kabi yozgan bo'lsa ochiladi (`saysCantCome`), shogird o'zi belgilay
    olmaydi. `lib/models/gym.dart`, `screens/user/gym_screen.dart`, `screens/admin/gym_admin_screen.dart`.
    Testlar 54/54, qoida testlari 84/84, joylandi (APK 22,8 MB). Ekranlar brauzerda ko'rilmagan.
43. **Ilova ikonkasi** (foydalanuvchi: "orqa oq fonni olib tashla, rasm kattaroq, orqa fon shaffof";
    keyin telefonda qora ramka chiqdi — "ramkani ichida png ga o'xshab orqa fon bilan bir xil bo'lsin"):
    - `tools/make_icon.dart`: faqat TASHQI oq fon shaffof (chetlardan flood fill) — logotip ichidagi oq
      detallar saqlanadi; `icon.png` shaffof, logotip 96%.
    - Birinchi urinish — adaptiv ikonka shaffof fon (`#00000000`) + inset 0: launcher shaffof fonni
      **qora plashka** bilan to'ldirdi (Android adaptiv ikonkani doim shaklga soladi).
    - Yakuniy yechim: **adaptiv ikonka olib tashlandi** (pubspec'dan `adaptive_icon_*` kalitlari,
      `res/mipmap-anydpi-v26/`, `drawable-*/ic_launcher_foreground|monochrome.png`, `values/colors.xml`
      o'chirildi) — faqat shaffof `mipmap-*/ic_launcher.png`. Burchak alpha 0 tekshirildi.
    - Eslatma: Samsung "Icon frames" yoqilgan bo'lsa tizim baribir ramka qo'shadi; monoxrom (Android 13
      mavzuli) ikonka endi yo'q.
    - APK 17:59 da yig'ildi va saytga joylandi. Telefonda natija hali tasdiqlanmagan.
44. **Savol: "massa naborda 2 ta versiya chiqyapti"** — tekshirildi: ikkala shogird (Shogird 1, Shogird 2)
    maqsadi "Ozish" → trener faqat 2 ta ozish variantini ko'radi (to'g'ri). Massa nabor 3 varianti faqat
    maqsadi massa bo'lgan shogirdda chiqadi. Kod o'zgarmadi.
45. **Zal bo'limi brauzerda tekshirildi (16-sent)** — vaqtinchalik "TEST Zal" akkaunti bilan to'liq oqim:
    anketa → Zal → "Kunlarni tanlash" (2 variant: Se/Pay/Sha, Du/Chor/Ju) → jadval va bugungi mashg'ulot
    ("Chorshanba — Qanot (orqa) + oyoq") → chatda "bugun zalga kelolmayman" → trener Zal bo'limida
    "Uyda mashq" tugmasi **ochildi** (boshqa shogirdda o'chiq turdi) → bosildi → shogird "Bugun uyda"
    ro'yxatiga o'tdi, trenerda "Bekor" tugmasi, shogirdda "Uyda mashq" kartochkasi chiqdi.
    Test akkaunt **`AKKAUNT_OCHIRISH` vositasi bilan** o'chirildi (vosita ham shu bilan sinaldi:
    Firestore + Auth tozalandi, tekshirildi). Baza: trener, bosh admin, Shogird 1, Shogird 2.
    Kod o'zgarmadi — testlar 54/54, analyze 0 xato.
46. **Do'kon bo'limi (16-sent, 45-banddan keyin)** — foydalanuvchi so'rovi: "bita bo'lim bo'ladi forma va
    anjomla va pitaniyala (protein, kreatin)".
    - **Model** `lib/models/shop.dart`: `shopCategories` = Forma / Anjomlar / Sport pitaniya;
      `Product` (nomi, izoh, narx so'mda, qoldiq, rasm havolasi, sotuvda-mi), `ShopOrder`
      (holatlari: `new` kutilmoqda, `given` berildi, `canceled` bekor), `SalesReport` (30 kunlik savdo),
      `fmtSum` (450000 → "450 000").
    - **Shogird** (`lib/screens/user/shop_screen.dart`, pastdagi 4-bo'lim "Do'kon"): bo'limlar bo'yicha
      filtr, narx, "Qoldi: N" ogohlantirishi, "Olaman" → sonini tanlash → buyurtma. Yuqorida o'z
      buyurtmalari ("Bekor" tugmasi bilan) va tarix.
    - **Trener** (`lib/screens/admin/shop_admin_screen.dart`, "Do'kon" bo'limi): ikki varaq —
      **Buyurtmalar** (30 kunlik summa, "Kutilmoqda" + "Tarix", "Berildi"/"Bekor") va **Tovarlar**
      (bo'limlarga ajratilgan ro'yxat, "+ Tovar" varag'i, o'chirish). Trener faqat O'Z shogirdlari
      buyurtmasini ko'radi, bosh admin — hammasini.
    - **Bog'lanish:** buyurtma berilganda chatga "🛒 Buyurtma: ..." yoziladi — trener mavjud chat
      bildirishnomasi orqali xabar topadi; "Berildi" bosilganda shogirdga "✅ Buyurtma berildi ..."
      xabari boradi va tovar qoldig'i tranzaksiya bilan kamayadi.
    - **Qoidalar** (`firestore.rules`): `shop` — hamma o'qiydi, faqat xodim yozadi; `orders` — shogird
      faqat o'zi nomidan va **bazadagi narx bilan** yarata oladi (arzon narx yozib bo'lmaydi), trener
      faqat status/updatedAt ni o'zgartiradi, o'chirish faqat bosh adminda. Qoida testiga 27 ta holat
      qo'shildi (jami 111, 0 xato — emulyator JDK 21 bilan: `%LOCALAPPDATA%\jdk21\...`).
    - **Brauzerda to'liq tekshirildi:** trener 2 ta tovar kiritdi (Forma 120 000, Sport pitaniya
      450 000 / qoldiq 5) → vaqtinchalik "TEST Dokon" shogirdi 2 dona protein buyurtma qildi →
      chatda xabar chiqdi → trener "Berildi" bosdi → 30 kunlik savdo "900 000 so'm", qoldiq 5 → 3.
      Yorug' mavzu ham ko'rildi. Test ma'lumotlari (akkaunt, buyurtma, 2 tovar) o'chirildi — baza
      yana faqat trener, bosh admin, Shogird 1, Shogird 2.
    - Eslatma: shogird akkaunti o'chirilganda uning **buyurtmalari qoladi** (savdo hisobi uchun) —
      `AKKAUNT_OCHIRISH` faqat `users/` va `chats/` ni tozalaydi.
    - To'lov ilovada YO'Q (Payme/Click keyin, Blaze + merchant hujjatlari kerak) — zalda naqd.
47. **Haftalik reja va ratsion rasmlari (17-sent)** — foydalanuvchi trenerdan olingan 7 ta rasm berdi
    (1300–1700 kkal, har biri 5 mahal) va "1 haftalik ratsion" so'radi.
    - **Model** (`lib/models/models.dart`): `Plan` ga ikki maydon qo'shildi —
      `week` (1..7 → o'sha kun mahallari) va `photos` (1..7 → rasm yo'li).
      `mealsFor(weekday)`, `kcalFor`, `proteinFor`, `mealsPerDay`, `isWeekly`, `photoFor`.
      Haftalik bo'lmagan reja ilgarigidek ishlaydi; `kcal` haftalikda 7 kun o'rtachasini beradi.
      **Eski hujjat xatosi:** `(d['week'] ?? {}) as Map<String, dynamic>` bo'sh `{}` ni
      `Map<dynamic,dynamic>` deb chiqarib TypeError bergan — rejalar ekrani cheksiz "yuklanmoqda"
      bo'lib qolgan edi. To'g'risi: `(d['week'] as Map<String, dynamic>?) ?? const {}`.
      Shu bilan birga `plans_screen` ga xato ko'rsatuvchi blok qo'shildi (avval xato ko'rinmasdi).
    - **Trener muharriri**: "Har kunga alohida menyu" tugmasi (yoqilganda hozirgi menyu 7 kunga
      nusxalanadi), Du…Yak chiplar, "Hamma kunga" nusxalash, kun rasmi ko'rinadi.
      Saqlashda asosiy `meals` — dushanba nusxasi (eski APK'lar uchun).
    - **Shogird**: "Bugun" ekrani o'sha kun menyusini ko'rsatadi ("REJA · PAYSHANBA"),
      kaloriya va oqsil shu kunniki, tepasida trener bergan **ratsion rasmi** — bosilsa
      to'liq ekranda kattalashtirib ko'riladi (`lib/widgets/plan_photo.dart`).
    - **Rasmlar**: suhbatdagi 7 ta surat `assets/ratsion/1-kun.jpg … 7-kun.jpg` ga yozildi
      (pubspec'ga qo'shildi, `assets/credits.txt` da manbasi izohlangan).
    - **Shablon**: `haftalikRatsionTemplate()` — 7 kun × 5 mahal, grammlari rasmdagi ko'rinishga
      qarab olingan (**taxminiy**), izohda trenerning kirish matni ham bor.
      Kunlik kaloriya: Du 1458, Se 1320, Chor 1498, Pay 1699, Ju 1452, Sha 1505, Yak 1679.
    - **Brauzerda tekshirildi**: shablondan reja yaratildi → kun chiplari va kun rasmi trenerda
      ko'rindi → vaqtinchalik "TEST Rasm" shogirdiga biriktirildi → shogirdda Payshanba menyusi
      (1699 kkal, 156 g oqsil) va o'sha kunning rasmi chiqdi, rasm to'liq ekranda ochildi.
      Test akkaunt o'chirildi.
    - **Do'kon tuzatishi**: tovar rasmi endi nomiga qarab avtomatik chiqadi (protein, gainer …),
      xuddi ovqat bazasidagidek; rasm havolasi bo'lmasa bo'lim ikonkasi qoladi.
    - Testlar: 68/68 (haftalik reja uchun 6 ta yangi test), analyze 0 xato.
48. **Hujjatlar (17-sent)** — `hujjatlar/` papkasi yaratildi:
    - `Diamond-TZ.docx` — 14 bo'limli texnik topshiriq: maqsad (o'lchanadigan natijalar bilan),
      rollar, ekranlar, 40+ funksional talab, biznes qoidalari, ma'lumotlar modeli, xavfsizlik,
      dizayn, stek, hozirgi holat, 6 bosqichli reja, xavflar, qabul mezonlari, ochiq savollar.
      (Yaratuvchi skript: `python-docx`; web nusxasi ham bor — Claude artifact havolasi.)
    - `figma/` — 7 ta SVG (dizayn tizimi + 6 ekran), Figma sudrab tashlaganda qatlamga aylanadi.
    - `figma-plugin/` — `manifest.json` + `code.js`: Figma ichida 7 ramka, 248 matn qatlami va
      15 rang stilini o'zi chizadi. **Haqiqiy Figma'da sinalmagan** (soxta muhitda ishladi).
49. **Chiqarish va sayt (17-sent 13:00)**
    - **Shogird tomoni tekshirildi** (bu band 47-bandning ochiq qolgan qismi): vaqtinchalik
      "TEST Rasm" shogirdi (62 kg, Ozish) ga haftalik reja biriktirildi → "Bugun" ekranida
      **"REJA · PAYSHANBA"**, 1699 kkal, 156 g oqsil va **Payshanba ratsion rasmi** chiqdi;
      rasm bosilganda to'liq ekranda ochildi. Test akkaunt o'chirildi.
    - **APK** qayta yig'ildi: `app-arm64-v8a-release.apk` **24,4 MB** (rasmlar +1,7 MB),
      `app-armeabi-v7a` 22,1 MB. `public/app/kq.bin` va `kq-eski.bin` yangilandi.
    - **Ilovaning web versiyasi joylandi:** `flutter build web` → `public/ilova/`
      (`index.html` dagi `<base href>` qo'lda `/ilova/` ga o'zgartirildi — `--base-href`
      bayrog'i shablondagi `$FLUTTER_BASE_HREF` ni almashtirmay qoldi).
      **https://kotta-qani-09111753.web.app/ilova/** — iPhone'lilar endi ilovadan foydalana oladi,
      trener kompyuterda ishlaydi. Brauzerda kirish tekshirildi (trener paneli ochildi).
      Cheklov: brauzerda bildirishnoma yo'q.
    - ⚠️ **Xavfsizlik tuzatildi:** eski yuklab olish sahifasida **trener telefoni va paroli
      ochiq yozilgan edi** — havolani bilgan har kim trener paneliga kira olardi.
      Olib tashlandi. Sahifa qaytadan yozildi: ilova haqida, 3 ta tugma (Android / eski telefon /
      brauzer), 3 ta ekran surati (`public/img/`, ismlar umumiy — Jasur/Aziz), o'rnatish yo'riqnomasi
      va Play Protect izohi. **Trener paroli o'zgartirilsa yaxshi bo'ladi** — eski parol
      ochiq turgan edi.
    - `assets/credits.txt` ga ratsion rasmlari manbasi yozildi.
    - `QOLLANMA.md` yangilandi: haftalik reja qanday tuziladi, kun rasmi, web versiya.
    - Yakuniy tekshiruv: `flutter analyze` 0 xato, `flutter test` 68/68.
50. **Maketlar to'ldirildi (17-sent)** — foydalanuvchi savoli: "trener uchunligi qani, admin uchun qani".
    Avval 6 ta ekran bor edi (3 shogird + 3 trener), bosh admin ekranlari umuman yo'q edi.
    Qo'shildi: **trener** — Zal, Ovqat bazasi; **bosh admin** — Xodimlar, Trenerlar reytingi;
    **shogird** — Progress, Chat, Profil. Jami **13 ekran + dizayn tizimi taxtasi**.
    - `hujjatlar/figma/*.svg` — Figma sudrab tashlaganda qatlamga aylanadi (brauzerda ham ishlaydi).
    - `hujjatlar/figma/png/*.png` — 2x sifatda rasm (Figma kerak emas, Telegramga tashlash uchun).
    - Generatorlar scratchpad'da edi (`figma_svg.py`, `figma_svg2.py`) — **ular saqlanmagan**,
      kerak bo'lsa qaytadan yozilishi mumkin; SVG fayllarning o'zi loyihada.
    - Figma plagini hamon 6 ta ekranni chizadi (qolgan 7 tasi faqat SVG). Plagin haqiqiy
      Figma'da hali sinalmagan.
51. **Haftalik ratsion olib tashlandi (17-sent, foydalanuvchi so'rovi)**
    "1 haftalik bitani ... 7 kunlik retsept, o'shani olib tashlab APK yig'ib ber".
    - O'chirildi: `haftalikRatsionTemplate()`, `assets/ratsion/*.jpg` (7 rasm), pubspec dagi
      `assets/ratsion/` yozuvi, `credits.txt` dagi izoh, 2 ta test. Shablonlar: 6 → **5**.
    - **Haftalik reja imkoniyati qoldi** (model `week`/`photos`, muharrirdagi "Har kunga alohida
      menyu", kun rasmi ko'rsatuvchi `PlanPhoto`) — trener kelajakda o'zi tuzishi uchun.
    - Bazadagi "Ozish • 1 haftalik ratsion" rejasi hali **o'chirilmagan** — trener panelidan
      (Rejalar → ⋯ → O'chirish) yoki so'rov bilan o'chirish kerak. Unga biriktirilgan shogird yo'q.
    - ⚠️ **Xato va tiklash:** o'chirish skripti qavslarni noto'g'ri hisoblab, yonidagi
      **`massaNabor3Template()`** ni ham kesib tashladi (loyiha git'da emas — orqaga qaytarish yo'q).
      Tiklandi: `public/ilova/main.dart.js` (o'chirishdan oldin yig'ilgan web bundle) dagi
      matn konstantalaridan mahal nomlari, grammlar va KBJU qiymatlari, izoh matni esa suhbat
      yozuvidan olindi. Tekshirildi: **6 mahal, 2722 kkal, 185 g oqsil** — avvalgisi bilan bir xil.
    - **Xulosa: loyihada git yo'q.** Shu sababli kod o'chsa faqat build artefaktlaridan tiklanadi.
      Tavsiya: `git init` qilib, har kun oxirida commit qilish (fayllar kompyuterda qoladi,
      hech qayerga yuborilmaydi). Buni bir marta sozlash 5 daqiqa.
    - Yakuniy tekshiruv: `analyze` 0 xato, `flutter test` **66/66**.
    - **APK yig'ilmadi** — foydalanuvchi "to'xta" dedi, skrinshot savoli bilan (yuqoridagi qaror).
52. **Kunlik ish (18-sent ertalab)** — "qilinishi kerak bo'lgan ishlarni boshla".
    - **APK qayta yig'ildi**: 22,7 MB (ratsion rasmlari olib tashlangani uchun 24,4 dan tushdi),
      `public/app/kq.bin` va `kq-eski.bin` yangilandi, saytga joylandi.
    - **Web versiya qayta yig'ildi** va `public/ilova/` ga qo'yildi (`<base href>` qo'lda `/ilova/`).
      Tekshirildi: sayt 200, ilova 200, APK Content-Length 23 835 303,
      `main.dart.js` da "1 haftalik ratsion" yo'q — ya'ni chiqarilgan versiya kod bilan mos.
    - **Bazadagi "Ozish • 1 haftalik ratsion" rejasi o'chirildi** (avval unga biriktirilgan
      shogird yo'qligi tekshirildi). Qolgan rejalar: Massa nabor 2-versiya, Ozish 80-90,
      Ozish 60/65/75.
    - **`git init` qilindi** — 233 fayl, birinchi commit. `.gitignore` yozildi:
      `build/`, `.dart_tool/`, `node_modules/`, `public/ilova/`, `public/app/*.bin` kirmaydi;
      **`android/diamond-release.jks` va `key.properties` ataylab saqlanadi** (imzo kaliti
      yo'qolsa hamma mijoz ilovani qayta o'rnatishga majbur bo'ladi).
      Repo faqat shu kompyuterda — hech qayerga yuborilmagan (remote yo'q).
      Kundalik ish: `git add -A` → `git commit -m "nima qilindi"`.
53. **Zallar va trener yollash (18-sent)** — foydalanuvchi so'rovi: "bosh admin zal tanlaydi va
    trener qo'sha oladi ... zal nomlaydi Admin va yollaydi zalga trener".
    - **Model**: `gyms/{id}` (`name`, `address`) va `AppUser.gymId`. `gymId` **toMap() ga
      kirmaydi** — shogird o'z profilini saqlaganda zal o'zgarmasin; uni faqat bosh admin yozadi.
      Shogirdda zal maydoni yo'q: u treneri orqali zalga tegishli.
    - **Db**: `gyms()`, `saveGym()`, `deleteGym()` (zal o'chsa trenerlar zalsiz qoladi),
      `setUserGym()`, `createTrainer()`.
    - **`createTrainer` qanday ishlaydi:** Firebase mijoz kutubxonasi yangi akkaunt yaratganda
      o'sha akkauntga kirib oladi va bosh admin seansini buzadi. Shuning uchun akkaunt
      **ikkinchi Firebase ulanishida** (`Firebase.initializeApp(name: ...)`) yaratiladi va
      `users/{uid}` hujjati ham o'sha seansdan yoziladi (qoida: har kim faqat o'z hujjatini,
      faqat `user` roli bilan). So'ng bosh admin rolni `admin` ga o'zgartiradi va zalga
      biriktiradi, ulanish `app.delete()` bilan yopiladi.
    - **Xodimlar ekrani**: yuqorida zal tugmachalari (Hammasi + har zal, trener soni bilan),
      "＋ Zal", tanlangan zal manzili va "Tahrirlash"; ko'rsatkichlar zal bo'yicha; "Trenerlar"
      ro'yxati (zalsizlarda "Zalsiz" yorlig'i va ogohlantirish); "Bosh adminlar" alohida bo'lim;
      trener ustidagi amallarga **"Zalga biriktirish"** qo'shildi. Zal tugmachasini uzoq bosish —
      tahrirlash/o'chirish.
    - **Qoidalar**: `gyms` — hamma kirganlar o'qiydi, yozish/o'chirish faqat bosh adminda,
      maydonlar `name` (1–60) va `address` (≤200) bilan cheklangan. `users` yangilashda
      `same('gymId')` qo'shildi: shogird ham, trener ham o'z zalini o'zgartira olmaydi.
      Qoida testlariga 14 ta holat qo'shildi — **jami 125, 0 xato**.
    - **Brauzerda to'liq sinaldi**: zal "Kotta Qani zali" (Toshkent) yaratildi → "Trener 1"
      va "Trener 2" trener akkauntlari ilovaning o'zidan yaratildi (bosh admin seansi
      buzilmadi, ekranda telefon va parol ko'rsatildi) → mavjud trener "Kotta Qani" ham shu
      zalga biriktirildi → Trener 1 o'z telefon-paroli bilan kirdi va trener panelini ko'rdi.
    - Testlar: `analyze` 0 xato, `flutter test` **69/69**.
54. **Zal joyi: mamlakat → viloyat → tuman (18-sent)** — "zal tanlashdan oldin O'zbekistonmi
    tanlaydi, qaysi shahar, qaysi rayon — keyin nomlaydi".
    - `lib/models/hudud.dart`: 14 viloyat/shahar va ularning tumanlari (Toshkent shahri —
      12 tuman). Har viloyat oxirida **"Boshqa…"** varianti bor: ro'yxatda yo'q tumanni
      qo'lda yozish mumkin (ro'yxat to'liq bo'lmasligi mumkin).
    - `Gym` ga `country`, `region`, `district` qo'shildi; `place` ("Chilonzor, Toshkent shahri")
      va `fullAddress` (joy + ko'cha) getterlari.
    - Zal varag'i ketma-ket: Mamlakat → Viloyat/shahar → Tuman (viloyat tanlanmaguncha
      o'chiq turadi) → Zal nomi → Ko'cha (ixtiyoriy).
    - Qoidalarga yangi maydonlar qo'shildi (har biri ≤60 belgi, notanish maydon o'tmaydi);
      qoida testlari **127/127**, Dart testlari **71/71**.
    - Brauzerda ko'rildi: viloyatlar ro'yxati, Toshkent shahri tumanlari (12 + Boshqa…).
      **"Kotta Qani zali" ning tumani hali tanlanmagan** — foydalanuvchidan so'raladi.
55. **"Eslatma" bo'limi (18-sent)** — "notifikatsiyani pastki menyuga qo'sh, user o'chirib
    qo'ygan bo'lsa ham ilovada ko'rinsin".
    - `lib/models/feed.dart` — ro'yxat **saqlanmaydi**, bazadagi narsalardan yig'iladi:
      chat xabarlari, biriktirilgan reja, vazn muddati, bugungi belgilanmagan mahallar,
      buyurtmalar; trenerda — shogird xabarlari, yangi buyurtma, rejasiz shogird va zal
      kunlarini tanlamaganlar. Shu sababli telefon sozlamasiga bog'liq emas.
    - `lib/screens/notifications_screen.dart`: `FeedBuilder` (oqimlarni yig'adi),
      `FeedBadge` (menyudagi qizil raqam), `NotificationsScreen` ("Amal kutilmoqda" + "Tarix").
    - "Ko'rilgan" vaqti qurilmada saqlanadi (`AppSettings.feedSeen`) — bo'lim ochilganda
      yangilanadi, yangilari "Yangi" yorlig'i bilan chiqadi.
    - Menyu: shogirdda 7 ta, trenerda 6 ta bo'lim bo'lgani uchun yozuvlar faqat tanlanganida
      ko'rinadi (`labelBehavior: onlyShowSelected`).
    - Brauzerda ko'rildi: trenerda Shogird 3 va Shogird 1ning xabarlari ro'yxatda chiqdi.
56. **Barmen roli va sotuv hisoboti (18-sent)** — "barmen degan rol qo'sh, u sotuvga javob
    beradi; faqat zal egasiga hisob beradi — nechta nima sotdi".
    - **4-rol: `barmen`.** Faqat do'kon: tovar qo'shadi, qoldiqni boshqaradi, buyurtmani
      "Berildi" qiladi. Shogird, reja, chat va zal sozlamalariga kirmaydi.
      Kirish `BarmenHome` (3 bo'lim: Do'kon · Hisobim · Eslatma).
    - **Kim sotgani yoziladi:** buyurtmaga `givenBy` (uid) va `givenAt` qo'shildi —
      "Berildi" bosilganda yoziladi. Qoidalar: boshqa odam nomidan yozib bo'lmaydi.
    - **Sotuv hisoboti** (`sales_report_screen.dart`): davr (Bugun / 7 / 30 kun / Hammasi),
      jami tushum, **kim sotdi** (xodim kesimida), **qaysi tovar** (dona va summa) va har bir
      sotuv ro'yxati. Zal egasi Xodimlar bo'limidan ochadi; barmen "Hisobim" da faqat
      o'zinikini ko'radi.
    - **Qoidalar:** barmen `shop` ga yozadi, hamma `orders` ni o'qiydi va statusni o'zgartiradi;
      `users`, `chats`, `plans`, `gyms` ga tegmaydi. Qoida testlariga 11 ta holat qo'shildi —
      jami **138, 0 xato**. Dart testlari **85/85**.
    - Brauzerda sinaldi: bosh admin "Yangi barmen akkaunti" orqali Barmenni yaratdi
      (+998 90 000 00 03, parol `PAROLLAR.md` da) → barmen kirdi va faqat do'kon panelini ko'rdi.
    - **Eslatma:** hozir barmen **hamma zal** buyurtmasini ko'radi (zal bittaligi uchun).
      Filial ko'paysa, buyurtmaga zal biriktirib, barmenni o'z zaliga cheklash kerak.

57. **Do'kon: o'lcham, rasm galereyasi, dollar narxi va birinchi tovarlar (24-sent)** —
    foydalanuvchi Venum komplekt rasmlarini berdi: "XL-XXL-3XL-4XL razmerlar bor, narxi 35 $".
    - **O'lchamlar:** `Product.sizes` (masalan `XL, XXL, 3XL, 4XL`) — trener vergul bilan
      yozadi; shogird buyurtmada o'lchamni tanlamaguncha tugma ishlamaydi. Tanlangani
      `ShopOrder.size` ga yoziladi va hamma joyda `Venum komplekt (XL)` ko'rinishida chiqadi.
    - **Rasm galereyasi:** `Product.images` — muharrirda har bir havola yangi qatorda;
      buyurtma oynasida rang variantlari yonma-yon ko'rinadi (`gallery` getteri).
    - **Valyuta:** `Product.currency` — `UZS` yoki `USD` (muharrirda tugmacha).
      `fmtMoney(35, 'USD')` → `35 $`. Buyurtmaga valyuta ham yoziladi (keyin kurs
      o'zgarsa ham eski buyurtma o'z narxida qoladi). Sotuv hisoboti valyutalarni
      **qo'shmaydi**, alohida ko'rsatadi: `450 000 so'm · 70 $` (`SalesReport.sums`).
    - **Qoidalar:** buyurtmada `size` (≤ 20 belgi) va `currency` maydonlari ruxsat etildi;
      valyuta tovardagi bilan bir xil bo'lishi shart. 24-sent joylandi.
    - **Rasmlar:** `public/img/tovar/venum-vm2008-{sariq,kulrang,yashil,oq-qora}.jpg` — saytda turadi.
    - **Kiritilgan tovarlar** (hammasi Forma, 35 $, XL–4XL, qoldiq 10 — taxminiy):
      `Venum komplekt (VM2008)` (4 rasm), `UFC komplekt (VM202101)` (2 rasm: haki, qora),
      `Reebok komplekt (R-615)` (3 rasm: qora, haki, ko'k).
      Yana uchtasi — **45 $**: `Nike komplekt (4-5 qismli)` (1 rasm),
      `Under Armour komplekt (4-5 qismli)` (2 rasm: qora, qora-yashil) va
      `Pro Combat komplekt (5 qismli)` (3 rasm: qora, kulrang, ko'k).
      Eng arzoni — **30 $**: `Pro Combat komplekt (2 qismli)` (rashgard + tayts, 3 rasm).
    - **Maykalar va kofta (10 ta, 24-sent):** narxi har rasmda yozilgan edi, o'sha olindi —
      Kapyushonli kofta 23 $; Kapyushonli mayka 17 $; Mayka qora-kulrang / salat / kulrang va
      Under Armour oq — 15 $; UA Project Rock, UA "Earn Greatness" (oq va qora), Nike — 14 $.
      Hammasi `tools/dokon/maykalar.json` da.
    - **Taxmin qilingan joy:** ikkita rasmda narx yorlig'i yo'q edi (qora-kulrang va salat rang
      maykalarning orqa tomoni ko'rinishi). Ular alohida tovar emas, o'sha maykaning
      **2-rasmi** qilib qo'yildi. Noto'g'ri bo'lsa — ajratish kerak.
58. **"Qo'shimcha" bo'limi va sport pitaniya (24-sent)** — "Qo'shimcha deb bo'lim qo'sh,
    t.me/AllPituz kanalidan kreatin va proteinlarning rasmi va narxini ol".
    - **Bo'limlar ikki darajali** (foydalanuvchi so'rovi: "Dobavkalar degan bo'lim bo'lsin,
      Protein, Gainer, Kreatin, L-Karnitin, L-Arginin o'shaning ichida"):
      - `shopGroups` — asosiy bo'limlar: `Forma`, `Suv idishlari`, `Anjomlar`,
        `Dobavkalar` (foydalanuvchi: "2 ta bo'lim — suv idishlari va anjomlar");
      - `supplementCategories` — Dobavkalar ichidagilar: `Protein`, `Gainer`, `Kreatin`,
        `L-Karnitin`, `L-Arginin`, `Boshqa`;
      - `shopCategories` = Forma + Anjomlar + yuqoridagilar (bazada shu nomlar saqlanadi);
      - `shopGroupOf(category)` — tovar qaysi asosiy bo'limga kirishini aytadi.
      Shogirdda: birinchi qator chiplari — asosiy bo'lim; `Dobavkalar` tanlansa, ostida
      ikkinchi qator chiplari chiqadi. Trener/barmenda: `Dobavkalar` sarlavhasi ostida
      har turga `SubHeader` (yangi vidjet, `lib/widgets/ui.dart`).
      Har bo'limga o'z ikonkasi va rangi (`lib/widgets/product_image.dart`).
      Bo'sh turgan `Sport pitaniya` olib tashlandi.
    - Tekshiruv (brauzer, vaqtinchalik TEST shogird): shogirdda ikki qatorli chip ishlaydi,
      trener ro'yxatida "Dobavkalar → Protein (21)" ko'rinishi chiqdi. Test akkaunt o'chirildi.
    - Kanal ochiq ko'rinishdan (`https://t.me/s/AllPituz`, 5 sahifa) 71 ta post va 74 rasm
      yuklandi; javon suratlaridan **har bir mahsulot alohida kesib olindi**.
    - **Yangi vosita:** `tools/dokon/narx_kesish.py` — suratdagi oq narx yorliqlarini topib
      (bog'langan oq sohalar), har yorliqqa tegishli mahsulot ustunini kesadi.
      Joylashuv: `tepa` / `past` / `aralash` (yorliq mahsulot ustidami yoki ostidami).
    - **Kiritildi: 30 ta tovar** — 9 ta Optimum Nutrition kreatini (340 000 – 900 000 so'm)
      va 21 ta protein (320 000 – 2 200 000 so'm: ON Gold Standard, Hydro Whey, Isolate,
      Isopure, Dymatize ISO100, Labrada, MuscleTech, BSN Syntha-6, Ultimate Nutrition).
      Ro'yxat: `tools/dokon/qoshimchalar.json`. Qoldiq 5 (taxminiy).
    - **Diqqat:** narxlar 24-sent holatiga, AllPituz'niki (yetkazib beruvchi narxi) — zal
      o'z ustamasini qo'shishi mumkin. Ta'm/hajm nomlari suratdan o'qilgan, ba'zilari taxminiy.
    - **Ikkinchi to'lqin (o'sha kuni):** gainer 14, L-karnitin 9, L-arginin 5 va
      "Qo'shimcha" 29 ta (BCAA, amino, glutamin, mashqdan oldingi kompleks, multivitamin,
      izotonik) + 3 ta kreatin qo'shildi — jami **107 ta tovar**.
      Ro'yxatlar: `tools/dokon/gainer-karnitin-arginin.json`, `tools/dokon/qoshimcha-boshqa.json`.
    - **Kiritilmadi:** narx yorlig'i yo'q mahsulotlar — Executioner Whey, Atomic Whey,
      Rule 1 Mass Gainer (4061-post), kichik N.O.-Xplode va Max Motion stik.
    - **Rasmlardagi begona yozuvlar tozalanadi:** narx yorlig'i kesish bilan, xitoycha
      yozuv esa atrof fon rangi bilan bo'yab yopish bilan (Pillow; `numpy` bilan qizil
      piksellar topiladi). Shunday tozalangan: Nike/UA rasmlari va Pro Combat 2 qismli 1-rasmi.
      Maykalarda oq narx yorlig'i pastki-o'ng burchakda edi — qatorlardagi oq bo'laklar
      bo'yicha topilib, rasm o'sha joydan kesildi (1280 → ~1110–1170 px).
    - **Rasmdagi narx yorlig'i olib tashlandi** (foydalanuvchi so'rovi): Nike/UA rasmlarida
      pastki-o'ng burchakda "45 $" oq yorlig'i bor edi — rasm 800×800 dan 800×710 ga
      kesildi (Pillow), narx endi faqat ilovada turadi.
    - **Yangi vosita:** `tools/dokon/tovar_qoshish.mjs` — JSON fayldan tovar qo'shadi
      (bosh admin nomidan, Firestore REST orqali). **Nomi bir xil tovar bazada bo'lsa —
      nusxa yaratmay, o'sha yozuvni yangilaydi.** Namunalar: `tools/dokon/*.json`.
    - Tekshiruv: `flutter analyze` 0 xato, `flutter test` **90/90**.

59. **Yangi ko'rinish: pahlavon rasmi (24-sent)** — foydalanuvchi sticker rasm berdi:
    "glavni fonga shu rasmni qo'y, yozuvlarini olib tashla, APK yuzi ham shunaqa bo'lsin".
    - Rasm tozalandi (Pillow): "TRAIN HARD OR STAY WEAK" yozuvi rasmning chap yarmida edi —
      o'ng tomondagi figura kesib olindi; shaxmat (shaffoflik) foni chekkadan to'lqin bilan
      topilib shaffofga aylantirildi → `assets/brand/pahlavon.png` (748×1394).
    - **Kirish ekrani foni:** `login_screen.dart` dagi `GradientHeader` ichiga `Stack` bilan
      o'ngdan qo'yildi (opacity 0.38); sarlavha ostidagi matn 260 px ga cheklandi.
    - **Ilova ikonkasi almashtirildi:** figuraning yuqori qismi (bosh + yelka + orqa) kvadratga
      solinib `assets/icon/icon.png` va `icon_foreground.png` yasaldi, so'ng
      `dart run flutter_launcher_icons`. `mipmap-anydpi-v26` yaratilmadi (tekshirildi).
      Eski "Diamond" ikonkasi git tarixida qoldi.
    - **Eslatma:** web'da eski nusxa service worker'da saqlanadi — yangisini ko'rish uchun
      `Ctrl+Shift+R` (qattiq yangilash) kerak.

60. **Do'kon bo'limlari yakuniy ko'rinishi (24-sent kechqurun)** — foydalanuvchi bir necha
    bosqichda aniqlashtirdi: "Dobavkalar degan bo'lim bo'lsin, Protein/Gainer/Kreatin/
    L-Karnitin/L-Arginin o'shaning ichida" → "Hammasi degan narsa kerakmas" →
    "2 ta bo'lim: suv idishlari va anjomlar".
    - `shopGroups` = `Forma`, `Suv idishlari`, `Anjomlar`, `Dobavkalar`;
      `supplementCategories` = Protein, Gainer, Kreatin, L-Karnitin, L-Arginin, Boshqa;
      `shopGroupOf()` tovarni asosiy bo'limga bog'laydi.
    - Shogird do'konida **"Hammasi" chiplari olib tashlandi** — bo'limlardan biri doim
      tanlangan turadi (birinchi to'la bo'lim), Dobavkalar tanlansa ichidagi turlardan biri.
    - Trener/barmen ro'yxatida "Dobavkalar" katta sarlavhasi ostida `SubHeader` bilan
      har bir tur (yangi vidjet: `lib/widgets/ui.dart`).
    - **Anjomlar:** kanalning 476 ta posti ko'rildi (3370–4069) — shakerlar (3873),
      UFC suv shishasi (3370) topildi; press rollerni foydalanuvchi o'zi berdi (200 000).
      Rasmdagi "200 000" va ruscha yozuv olib tashlandi.
    - **Do'konda jami 115 ta tovar:** Forma 19, Suv idishlari 23, Anjomlar 13, Dobavkalar 91.
    - Tekshiruv: brauzerda vaqtinchalik TEST shogird akkaunti bilan ikkala daraja ham
      sinaldi; akkaunt keyin o'chirildi. `flutter analyze` 0 xato, `flutter test` 90/90.

61. **Abonement + davomat + haftalik eslatma jurnali (4-okt)** — 13.1-bandning eng muhim
    qismi: zalning asosiy daromadi (abonement) endi hisobga olinadi.
    - **Model** (`lib/models/subscription.dart`, yangi): `Subscription` (`users/{uid}/subscriptions/{id}`
      — boshlanish sana, oy soni 1/3/6/12, narx, to'langan sana; `WeightLog` uslubida sof statik
      `daysLeft`/`isActive`/`isExpiringSoon`/`isExpired`); `Reminder` (top-level `reminders/{id}`
      — yuborilgan eslatma jurnali); `ReminderReport.byDay` — `SalesReport` uslubida haftalik sanoq.
      `AppUser.subscriptionExpiresAt` — `homeWorkoutDate` kabi faqat trener/bosh admin yozadi,
      `toMap()` ga kirmaydi.
    - **Davomat**: `users/{uid}/attendance/{kun}` (`present`/`markedBy`/`markedAt`) — `gym_admin_screen.dart`
      dagi mavjud "bugun kim keladi" qatoriga qo'shildi (yangi ekran emas), uyda-mashq
      tugmasi yonida "Keldi"/"Bekor" tugmasi.
    - **Qoidalar**: `subscriptions`/`attendance` subcollectionlari (`canManage(uid)`-gated,
      `gyms` uslubidagi `hasOnly` validatori), yangi top-level `reminders` (`orders` uslubidagi
      cross-check: trener faqat o'z shogirdiga, bosh admin — hammaga). `users` update blokiga
      `same('subscriptionExpiresAt')` qo'shildi. Qoida testlariga 26 ta yangi holat (ABONEMENT/
      DAVOMAT/ESLATMALAR bo'limlari) — jami **164, 0 xato**.
    - **Yangi ekran** `lib/screens/admin/subscriptions_screen.dart` — "Abonement" bo'limi
      (trener va bosh adminda, Mijozlar yonida): "Mijozlar" varag'i (har kimda qolgan kun
      `Pill`i — yashil/sariq/qizil, bosilsa abonement qo'shish varag'i, tugashi yaqin bo'lsa
      "Eslatma yubor" tugmasi) va "Haftalik eslatmalar" varag'i (oxirgi 7 kun, kuni nechta
      eslatma jo'natilgani). Eslatma yuborish — `Db.sendSubscriptionReminder`: jurnalga yozadi
      va shogirdga chatga "⏰ Abonementingiz N kundan keyin tugaydi" xabari yuboradi.
    - **Eslatma feed**: `FeedKind.subscription` — shogirdda "Abonement tugashi yaqinlashdi"
      (tugashiga 0–3 kun qolganda), trenerda har shogird uchun xuddi shunday "E'tibor" elementi.
    - **Brauzerda to'liq sinaldi** (lokal emulyator, `node tools/brauzer/cdp.mjs`): test shogirdga
      3 oylik abonement qo'shildi ("92 kun qoldi" yashil belgi to'g'ri chiqdi); REST orqali
      muddat 2 kunga qisqartirilib "tugashi yaqin" holat va "Eslatma yubor" tugmasi tekshirildi;
      eslatma yuborilgach haftalik hisobotda bugungi kunga "1" yozildi; shogird tomonida
      bildirishnoma qizil belgisida "1" chiqdi (feed ishlayapti). **Davomat tugmasi jonli
      tekshirilmadi** — bugun yakshanba, ikkala zal kunlari varianti ham (Se/Pay/Sha, Du/Chor/Ju)
      yakshanbani o'z ichiga olmaydi; kod `homeWorkoutDate` tugmasi bilan bir xil naqsh.

62. **Do'kon narxiga ustama (4-okt)** — 13.2-band: narxlar yetkazib beruvchi narxida edi, foyda yo'q.
    - `Product.costPrice` (tan narx) qo'shildi, `margin` getter (`price - costPrice`).
    - `shop_admin_screen.dart` tovar varag'ida "Tan narxi" maydoni + jonli "Foyda: N" matni;
      `_ProductAdminTile`da foyda `Pill`i (yashil).
    - **Yangi skript** `tools/dokon/narx_ustama.mjs <foiz>` — hamma tovarga bir martalik
      `costPrice` belgilaydi (joriy narxdan) va `price = costPrice × (1+foiz/100)` qiladi;
      qayta ishga tushirish narxni ikki marta oshirmaydi (har doim `costPrice`dan hisoblanadi).
      Root launcher `NARX_USTAMA.bat`. **`.env` yo'qligi sababli haqiqiy bazaga qarshi
      sinalmagan** — faqat `node --check` bilan sintaksis tekshirildi.
    - `firestore.rules` — o'zgarishsiz (tasdiqlandi: `shop/{id}` yozuvi validatorsiz,
      `costPrice` uchun qoida kerak emas).
    - Brauzerda sinaldi: "Test Mayka" 150 000 so'm, tan narx 100 000 kiritilganda
      "Foyda: 50 000 so'm" jonli chiqdi, saqlangach tovar kartochkasida "Foyda: 50 000" pilli.

63. **Do'kon — o'lcham bo'yicha qoldiq (4-okt)** — 13.2/9-band: "XL bor, 4XL yo'q" deyish
    imkonsiz edi, hammasi bitta sonda edi.
    - `Product.sizeStock` (`Map<String,int>`, `sizes` bo'yicha kalitlangan), `totalStock`
      (jamlangan), `stockFor(size)` getterlari. Flat `stock` saqlanadi — endi u jamlangan qiymat
      (`toMap()` har doim `totalStock`ni yozadi), eski kod buzilmaydi.
    - `shop_admin_screen.dart`: `sizes` bo'sh bo'lmasa, yagona "Qoldiq" maydoni o'rniga har
      o'lcham uchun alohida son maydoni (jonli, `sizes` matni o'zgarganda qayta chiziladi).
    - `Db.setOrderStatus` — "Berildi" bosilganda, o'lchami bor buyurtmada faqat o'sha o'lcham
      (`sizeStock.<o'lcham>`) kamayadi, jamlangan `stock` ham birga yangilanadi (tranzaksiyada).
    - `shop_screen.dart` (shogird): qoldiq va "Olaman" tugmasi endi `totalStock`ga, buyurtma
      varag'idagi dona stepperi tanlangan o'lchamning `stockFor(size)`iga qaraydi.
    - ⚠️ **Brauzerda topilgan va tuzatilgan xato:** tugagan o'lchamni (qoldiq 0) tanlasa ham
      "Buyurtma berish" tugmasi yoqilib qolardi (dona stepperi 0 ga tushmagani uchun eski
      "o'lcham tanlanganmi" sharti yetarli emas edi). Tuzatildi: tugma endi `stockFor(size) <= 0`
      bo'lsa ham o'chadi va "Tugagan" deb yozadi.
    - `firestore.rules` — o'zgarishsiz (tasdiqlandi: `shop/{id}` validatorsiz).
    - **To'liq oqim brauzerda sinaldi**: "Test Mayka" (XL: 5, XXL: 0) yaratildi → shogird
      XXL tanlaganda tugma "Tugagan" deb o'chdi (tuzatishdan keyin) → XL tanlab buyurtma berdi →
      trener "Berildi" bosdi → tovar qoldig'i 5 dan **4**ga tushdi (XL kamaydi, XXL tegilmadi).

64. **QR kod bilan ro'yxatdan o'tish (4-okt)** — 13.4-band: zal eshigiga osish uchun QR yo'q edi.
    - `pubspec.yaml`ga `qr_flutter: ^4.1.0`. Yangi `lib/widgets/join_qr_sheet.dart` —
      `showJoinQr(context)`, `https://kotta-qani-09111753.web.app/ilova/` manzilini QR qilib
      ko'rsatadi + "Havolani nusxalash" tugmasi. `admin_home.dart` AppBar'iga QR tugmasi
      qo'shildi (trener va bosh adminda).
    - Qoidalar/`Db` — kerak emas, sof UI.
    - Brauzerda ochib tekshirildi — QR kod to'g'ri chizildi.

65. **Haftalik zaxira skripti (4-okt)** — 13.3-band: bazaning hech qanday zaxirasi yo'q edi.
    - `tools/zaxira/zaxira.mjs` — `holat.mjs`/`tovar_qoshish.mjs` bilan bir xil auth+REST
      naqshi: barcha top-level kolleksiyalar (`users`, `trainers`, `ratings`, `gyms`, `foods`,
      `plans`, `shop`, `orders`, yangi `reminders`) va har foydalanuvchining subcollectionlari
      (`weights`, `days`, `subscriptions`, `attendance`, chat xabarlari) bitta JSON ga yig'ilib
      `zaxira/YYYY-MM-DD_bazaning-zaxirasi.json` ga yoziladi (`zaxira/` allaqachon gitignore'da).
      Root launcher `ZAXIRA.bat`. Avtomatik jadval (Task Scheduler) qilinmadi — qo'lda,
      haftada bir marta ishga tushiriladi.
    - **`.env` yo'qligi sababli haqiqiy bazaga qarshi hali bir marta ham ishga tushirilmagan** —
      faqat `node --check` bilan sintaksis tekshirildi. Zal egasi birinchi marta qo'lda
      ishga tushirib ko'rishi kerak.

66. **Joylash, ustama va birinchi zaxira (5-okt)** — foydalanuvchi ro'yxatdan 1, 2, 3 va
    5-ishni tanladi; 5-ish (haqiqiy qoldiq) "hozircha tursin, keyin qilamiz" deb qoldirildi.
    - **Zaxira (birinchi):** `node tools/zaxira/zaxira.mjs` →
      `zaxira/2026-10-05_bazaning-zaxirasi.json` (202 KB): users 9, trainers 3, gyms 1, foods 20,
      plans 3, shop 115, orders 0, reminders 0 + har foydalanuvchining subcollectionlari.
      Ustamadan **oldin** olindi — eski narxlar shu faylda saqlangan.
    - **Ustama:** `node tools/dokon/narx_ustama.mjs 15` — 115 tovar, 0 xato. Foydalanuvchi
      "yaxlitlamaslik"ni tanladi; so'm narxlari butun son bo'lib chiqdi (masalan 280 000 →
      322 000), dollar narxlari skript ichida butun dollarga yaxlitlanadi (35 $ → 40 $,
      30 $ → 35 $, 23 $ → 26 $). Ustamani qayta ishga tushirish ikki marta qo'shmaydi.
    - **Tekshiruv:** `flutter analyze` 0 xato, `flutter test` 100/100, qoida testlari 164/164.
    - **Joylash:** web `--base-href /ilova/` bilan PowerShell'da yig'ildi (Git Bash `/ilova/`
      yo'lini Windows yo'liga aylantirib buzadi — web'ni Bash'da yig'mang);
      `public/ilova/` ga ko'chirildi. APK `--split-per-abi`, imzo `CN=Diamond Zal` tekshirildi.
      `deploy.ps1` — qoidalar + hosting. Saytdagi `kq.bin` (25 333 852 bayt) va
      `ilova/main.dart.js` (3 630 141 bayt) lokal fayllar bilan aynan bir xil.
    - Eslatma: telefondagi ilovani yangilash uchun saytdan yangi APK'ni yuklab, ustiga
      o'rnatish kerak; web'da `Ctrl+Shift+R`.

67. **Anjomlar: 11 ta yangi tovar (5-okt)** — foydalanuvchi: "anjomlarda faqat bitta narsa
    turibdi, o'sha kanaldan qo'sh".
    - AllPituz kanali **to'liq** yig'ildi: 2095 post (1–4069, 2018–2024); matn bo'yicha
      qidiruv + matnsiz 174 ta rasmli post kollajda ko'z bilan ko'rildi. Anjomlar asosan
      **1594 va 1615-postlarda** (2020-aprel) topildi.
    - Qo'shildi (`tools/dokon/anjomlar-2.json`): otjimaniya tayanchi, turnik palka 1 / 1,2 /
      1,5 m (3 ta alohida tovar — narxi har xil), devor turnigi 2 in 1, pedalli ekspander,
      4 g'ildirakli press roller, elektron tarozi, boks lapasi (Venum/Reebok, 2 rasm),
      Everlast kik lapasi, yoga mat. Rasmlardagi narx va yozuvlar olib tashlandi
      (`public/img/tovar/anjom-*.jpg`).
    - Narxlar kanaldagi 2020 yil narxi + 15% ustama (`narx_ustama.mjs 15` — eski tovarlar
      o'zgarmadi). **Narxlar eski — zal egasi tekshirsin.**
    - Topilgan, lekin qo'shilmagan: TRX lentalari (1609–1613, 1615 — narx yo'q),
      sport sumkalar Puma 35 $ / Motodor 30 $ (2601 — rasm yo'q), shakerlar va suv idishlari
      (2182, 2366, 2376, 2423, 2830, 2840, 3365–3368 — "Suv idishlari" bo'limi uchun, so'ralmadi).
    - Do'konda jami **126 ta tovar**.

68. **Do'kon: 17 ta suv idishi va TRX (5-okt)** — `tools/dokon/suv-idishlari-2.json`
    (kanalning 2830, 2840, 3365–3368-postlari: 400 ml shakerdan 3 L butilkagacha, 2 ta to'plam)
    va `tools/dokon/trx.json` (rasm kanaldan 1609/1611-post, narx internetdan — mihome.uz,
    490 000). Hammasiga +15% ustama. Do'konda jami **144 ta tovar**: Forma 17,
    Suv idishlari 23, Anjomlar 13, Dobavkalar 91.
    Qo'shilmadi: Venum Technical/Logos (rasm kerak — foydalanuvchi alohida xabarda yuboradi),
    sport sumka (kanalda rasm yo'q; uzum/mihome/sello avtomatik yuklashni bloklaydi).

69. **Barmen faqat o'z zali (5-okt)** — har zalda bitta barmen bo'ladi.
    - Buyurtmaga `gymId` yoziladi (shogird trenerining zali). Shogird trenerning `users`
      hujjatini o'qiy olmaydi, shuning uchun zal **trenerlar katalogida ko'zgu** sifatida
      saqlanadi (`trainers/{id}.gymId`); qoida uni `users/{tid}.gymId` ga teng bo'lishga
      majbur qiladi. Ko'zgu yoziladigan joylar: `Db.setUserGym`, `deleteGym`,
      `_ensureTrainerEntry`, `syncTrainerDirectory`, `saveTrainerProfile`.
    - Qoidalar: `gymOf(uid)`; `orders` yaratishda `gymId` trener zaliga teng bo'lishi shart;
      barmen o'qish/yangilash faqat `resource.data.gymId == gymOf(barmen)`. Katalogni bosh
      admin faqat `gymId` bo'yicha yangilay oladi.
    - `Db.gymOrders(gymId)`, `Db.ordersFor(user)` (bosh admin — hammasi, barmen — o'z zali,
      trener — o'z shogirdlari). Zalsiz barmen hech narsa ko'rmaydi.
    - Bir martalik: `node tools/holat/katalog_zal.mjs` — 3 trener katalogiga zal yozildi.
    - Haqiqiy bazada barmen nomidan tekshirildi: o'z zali — OK, filtrsiz va boshqa zal — rad.
    - ⚠️ **Eski APK'da buyurtma berish va barmen ekrani ishlamaydi** — hamma yangilasin.

70. **Buyurtmada rang tanlash (5-okt)** — `Product.colors`, `ShopOrder.color`; shogird
    o'lcham kabi rangni tanlaydi (tanlanmaguncha tugma "Avval rangni tanlang"), buyurtma nomi
    "Venum komplekt (XL, sariq)". Tovar formasida "Ranglar" maydoni. Qoida: `color` ≤ 30 belgi.
    Qoldiq rang bo'yicha yuritilmaydi. 6 ta komplektga ranglar yozildi
    (`node tools/dokon/ranglar.mjs tools/dokon/forma-ranglar.json`).

71. **Oylik moliyaviy hisobot (5-okt)** — bosh admin: Xodimlar → "Oylik hisobot".
    Oy (← →) va zal tanlanadi; kartalar: jami tushum, abonement (soni, summasi — to'langan
    sana bo'yicha), do'kon tushumi (berilgan buyurtmalar), do'kon foydasi (sotilgan narx −
    hozirgi tan narx; tan narxsiz buyurtmalar alohida sanaladi). Valyuta bo'yicha alohida.
    `lib/models/finance.dart` (`MonthlyReport`, sof hisob), `finance_screen.dart`,
    `Db.allSubscriptions()` (collectionGroup; qoida `/{path=**}/subscriptions` — faqat bosh admin).
    Saytda bosh admin nomidan ochib ko'rildi — ishlaydi (hozir bazada sotuv yo'q, 0 chiqadi).

72. **Crashlytics (5-okt)** — `firebase_crashlytics`; ilova qulasa yoki tutilmagan xato bo'lsa
    Firebase Console → Crashlytics'ga yuboriladi. Faqat Android release'da (web va emulyatorda
    o'chiq), faqat `uid` yuboriladi. Gradle: `com.google.firebase.crashlytics` 3.0.3,
    `google-services` 4.3.15 → 4.4.2. **Telefonda hali tasdiqlanmagan** — birinchi ma'lumot
    Console'da ilova yangi APK bilan ochilgandan keyin paydo bo'ladi.

    **5-okt yakuni:** `flutter analyze` 0, `flutter test` **110/110**, qoida testlari
    **181/181**. Qoidalar, web va APK (CN=Diamond Zal) joylandi. Rejalar: `specs/okt-paket/`
    (lokal). **Qolgan: 05-blaze-push** — zal egasi Blaze'ni yoqishi kerak.

73. **Xato tuzatildi: o'lchamli tovarlar "Tugagan" chiqardi (5-okt)** — 4-oktabrda
    `sizeStock` qo'shilganda mavjud 17 ta Forma tovariga o'lcham bo'yicha qoldiq yozilmagan
    edi; `totalStock` = `sizeStock` yig'indisi = 0, ya'ni yangi ilovada Forma'ni buyurtma
    qilib bo'lmasdi. `node tools/dokon/olcham_qoldiq.mjs` umumiy qoldiqni o'lchamlarga teng
    bo'ldi (10 → XL 3, XXL 3, 3XL 2, 4XL 2). `tovar_qoshish.mjs` endi yangi o'lchamli
    tovarga `sizeStock` ni o'zi yozadi va `colors` ni qabul qiladi. Tekshirildi: bazada
    o'lchamli-yu qoldig'i 0 bo'lgan tovar yo'q.

74. **Venum Logos va Technical (5-okt)** — kanalning 2791-postidan topildi (2790-post:
    "4-1 Venum"). `tools/dokon/venum-2.json`, 35 $ + 15% = 40 $, XL–4XL. Do'konda jami
    **146 ta tovar**. Sport sumka (Puma/Motodor, 2601-post) — kanalda rasmi yo'q, qo'shilmadi.

75. **Suv belgisi (5-okt)** — skrinshot masalasida A varianti tanlandi (foydalanuvchi:
    "buni ham qil"; tavsiya qilingan variant). `lib/widgets/watermark.dart`: shogirdning
    "Bugun" ekrani ustida ism va telefon xira (5,5%), qiya takrorlanadi; bosishga xalaqit
    bermaydi. Skrinshot bloklanmaydi (`FLAG_SECURE` qilinmadi).

76. **Trenerlar haqi (5-okt)** — oylik hisobot pastida: har trener — shogirdlar soni, shu
    oyda sotilgan abonement soni va summasi, ulush. Foiz ekranda −/+ bilan tanlanadi (5 qadam,
    standart 40%), qurilmada saqlanadi (`AppSettings.trainerSharePct`). `MonthlyReport.byTrainer`,
    `TrainerShare`. **Taxmin:** trener o'z shogirdlari abonement tushumidan foiz oladi —
    qoida foydalanuvchi tomonidan berilmagan, boshqacha bo'lsa o'zgartiriladi.

77. **Rasmli progress — "oldin / keyin" (5-okt)** — Progress ekranida "Rasmlar" bo'limi:
    shogird kamera yoki galereyadan rasm qo'shadi, birinchi va oxirgisi yonma-yon, bosilsa
    kattalashadi va o'chiriladi. Trener va bosh admin shogird progressida ko'radi (o'chira
    olmaydi). **Cloud Storage ishlatilmadi** (Blaze kerak): rasm `image_picker` bilan
    kichraytirilib (720 px, sifat 60) `users/{uid}/photos/{id}.data` ga bayt sifatida yoziladi,
    350 KB gacha (qoida). `lib/models/photo.dart`, `lib/widgets/progress_photos.dart`.
    **Telefonda sinalmagan** — kamera va galereya faqat haqiqiy qurilmada tekshiriladi.

    **Tekshiruvlar (5-okt kechqurun):** davomat "Keldi"/"Bekor" haqiqiy saytda trener nomidan
    sinaldi — ishlaydi (iz qoldirilmadi). Anjom narxlari Toshkent do'konlari bilan
    solishtirildi: hammasi bozor oralig'ida, **pedalli ekspander bundan mustasno** — bizda
    172 500, bozorda 36 000–60 000 (kanalning 2020 yilgi narxi shubhali). `flutter test`
    **112/112**, qoida testlari **191/191**. Reja: `specs/okt-paket-2/` (lokal).

78. **Abonement: narx, kunlik tur, to'lov ko'rinishi (5-okt)** — zal egasi narxni aytdi:
    **kunlik 50 000, oylik 500 000 so'm** (`subscriptionDayPrice`, `subscriptionMonthPrice` —
    `lib/models/subscription.dart`).
    - **Kunlik tur:** abonement oynasida `Kunlik` chipi; yozuvda `days: 1, months: 0`, faqat
      shu kuni amal qiladi. Narx tanlangan turga qarab o'zi to'ladi (qo'lda o'zgaradi).
      Qoida: `months` 0..24, `days` 0..31, ikkalasidan aynan bittasi > 0.
    - **Mijoz o'z to'lovini ko'radi:** Profil ekranida `MySubscriptionCard`
      (`lib/widgets/subscription_card.dart`) — tur, summa, to'langan sana, tugash sanasi,
      qolgan kun, oldingi to'lovlar.
    - **Xodimlar zal to'lovlarini ko'radi:** yangi ko'zgu to'plam `memberships/{uid}`
      (`name, gymId, months, days, price, currency, paidDate, expiresAt, updatedAt`) —
      `Db.addSubscription` abonement bilan bitta batch'da yozadi. O'qish: bosh admin — hammasi;
      trener va barmen — faqat o'z zali (`gymId`), zalsiz xodim — hech narsa; mijoz — o'ziniki.
      Yozish: faqat `canManage`, `gymId` = mijoz trenerining zali (soxta qilib bo'lmaydi).
      `users/{uid}` boshqa trenerga ochilmadi — vazn, telefon, reja yopiq.
      Ekran: `lib/screens/payments_screen.dart` — trenerda Abonement → "To'lovlar",
      barmenda alohida tab.
    - `node tools/holat/tolovlar_kozgu.mjs` — mavjud abonementlardan ko'zguni to'ldiradi
      (eski APK ko'zgu yozmaydi; kerak bo'lsa qayta ishga tushiriladi).
    - Bir shogirdning 3-oktabrdagi oylik to'lovi bazaga o'tgan sana bilan yozildi (ilova
      boshlanish sanasini faqat "bugun" qiladi).
    - **Ma'lum cheklovlar:** mijoz trenerini almashtirsa ko'zgudagi zal keyingi to'lovgacha
      eskicha qoladi; abonement yozuvini ilovadan o'chirib/tahrirlab bo'lmaydi (faqat Firebase
      Console); kunlik mijozga shu kuni "abonement tugayapti" eslatmasi chiqadi.
    - Tekshirildi: `flutter analyze` 0, `flutter test` **116/116**, qoida testlari **213/213**;
      qoidalar, web va APK joylandi. Ekranlar telefonda sinalmagan.
      Reja: `specs/abonement/` (lokal).

79. **Qarorlar (5-okt, zal egasi)** — pedalli ekspander narxi bozorga tushirildi:
    172 500 → **60 000** (tan narx 52 000; `anjomlar-2.json` ham yangilandi). Trener haqi
    qoidasi tasdiqlandi: o'z shogirdlari abonement tushumining 40%. Kunlik mijozga
    "abonement tugayapti" eslatmasi chiqaveradi. Ovqat vaqti eslatmasi allaqachon bor
    (`Notifications.scheduleMeals`, Sozlamalar → "Ovqat vaqti eslatmasi") — yangi ish emas.
    **Zal egasida qoldi:** Blaze tarifi.

80. **Yangi ikonka; Crashlytics olib tashlandi (5-okt)** — ilova ikonkasi almashtirildi
    (`assets/icon/logo_src_2.png` → `icon.png`, burchaklari yumaloq kvadrat).
    **Crashlytics (`867bef6`) butunlay olindi:** u qo'shilgan APK telefonda ochilmadi —
    "Firebase sozlanmagan", `NullPointerException: FirebaseCrashlytics component is not present`
    (`Firebase.initializeApp()` ichida). Manifestda registrar ham, build ID ham bor edi —
    sabab logcat'siz aniqlanmadi (taxmin: Crashlytics gradle plagini 3.0.3 + AGP 9.1.0).
    Qayta qo'shish — faqat telefonda sinab, alohida ish. **Saboq:** Android plagini qo'shilgan
    APK telefonda ochib ko'rilmaguncha saytga joylanmaydi. 5-okt 17:41 gacha saytda turgan
    APK'lar (Crashlytics bilan) ishlamaydi — 17:55 dagi APK ishlatiladi.

81. **Tezlik (6-okt)** — shikoyat: hamma telefonda ilova sekin, ro'yxatlar kech chiqadi,
    rasmlar sekin yuklanadi, do'konda rasmni ochib bo'lmaydi. Telefonda o'lchanmadi —
    sabablar kod o'qib topildi:
    - `IndexedStack` hamma bo'limni ilova ochilishida birdan qurardi (shogirdda 7 ta, trenerda
      7–8 ta bo'lim bir vaqtda Firestore so'rovi yuborardi) → `LazyIndexedStack`
      (`lib/widgets/lazy_stack.dart`): bo'lim birinchi tanlanganda quriladi, keyin saqlanadi.
    - Do'kon ro'yxatlari bir yo'la chizilardi → shogirdda `SliverList.builder`, trener/barmenda
      `ListView.builder`.
    - Tarmoq rasmlari diskda saqlanmasdi → `netImage()` (`lib/widgets/food_image.dart`):
      telefonda `cached_network_image`, web'da avvalgidek `Image.network`.
    - Do'konda rasm bosilsa to'liq ekranda ochiladi (`lib/widgets/image_viewer.dart`:
      varaqlash, barmoq bilan kattalashtirish).
    - Progress rasmlari kichraytirib dekodlanadi (`cacheWidth`).
    - 18 ta katta tovar rasmi siqildi (eng kattasi 465 → 199 KB); hosting'da `/img/**` keshi
      1 soat → 7 kun.
    - Firestore `eur3` (Yevropa)da — har so'rovdagi kechikish qoladi, o'zgartirib bo'lmaydi.
    `flutter test` **117/117**. Web va rasmlar joylandi (web brauzerda bosh admin bo'lib
    sinaldi). **APK saytga QO'YILMADI** — yangi Android plaginlari (sqflite, path_provider)
    bor; sinov nusxasi `Diamond-SINOV-2026-10-06.apk` zal egasida, telefonda ochilgach
    `deploy.ps1` bilan joylanadi. Reja: `specs/tezlik/` (lokal).

82. **Uch til: o'zbek / rus / ingliz (6-okt, davom etmoqda)** — yangi kutubxonasiz:
    `lib/l10n/tr.dart` — `tr('O'zbekcha matn')` (kalit — matnning o'zi, tarjima bo'lmasa
    o'zbekchasi chiqadi) va `trf('{0} kun qoldi', [n])`. Til `appLang` (`AppSettings.setLang`,
    qurilmada saqlanadi); o'zgarsa `MaterialApp` qayta quriladi. Tanlash: kirish ekrani
    (o'ng tepada) va Sozlamalar (`lib/widgets/lang_picker.dart`).
    - Manba: `tools/l10n/tarjima.json`; `lib/l10n/ru.dart`, `en.dart` — GENERATSIYA
      (`python tools/l10n/l10n.py gen`), qo'lda tahrirlanmaydi.
    - Vosita `tools/l10n/l10n.py`: `scan` (matnlarni topadi), `wrap` (o'raydi), `unconst`,
      `add`, `gen`, `check` (tarjimasi yo'q kalitlar).
    - **Tayyor (711 kalit):** hamma ekran — kirish, anketa, sozlamalar, shogird, trener,
      bosh admin, barmen; holat yorliqlari, lenta, eslatmalar, do'kon bo'limlari, sana.
    - **Reja mazmuni ham tarjima bo'ladi:** tayyor shablon matni (reja nomi, taqiq ro'yxati,
      trener maslahati, mahal va mahsulot nomlari) va standart mahsulotlar lug'atga kiritildi;
      ekranda `tr(plan.title)`, `tr(meal.title)`, `tr(i.name)`, `tr(note)` — bazadagi matn
      shablon bilan AYNAN bir xil bo'lsa tarjima chiqadi, trener o'zgartirgan bo'lsa o'zbekcha
      qoladi. 6-okt: bazadagi 3 reja va 20 mahsulotning hamma matni lug'atda bor.
    - **O'zbekcha qoldi:** viloyat-tuman nomlari (`hudud.dart`), Android bildirishnoma kanali nomi,
      tizim oynalaridagi tugmalar (vaqt tanlash — inglizcha, `flutter_localizations` yo'q).
    - **Tarjima qilinmaydi:** foydalanuvchi kiritgan matn (tovar, reja va taom nomi, chat,
      ism) va chatga yoziladigan buyurtma xabarlari.
    - Bazadagi kalit qiymatlar (`Forma`, `Ozish`, hafta kunlari) o'zgarmadi — faqat ekranda
      `tr()` bilan ko'rsatiladi. Reja: `specs/tillar/` (lokal).

83. **Raqobatchilar bilan solishtirish va ish rejasi (6-okt)** — O'zbekiston bozoridagi
    ilovalar saytidagi tavsifi bo'yicha solishtirildi (o'rnatib sinalmagan): **FitBase** (zallar
    uchun pullik tizim, 50+ klub, brendli ilova, Uzcard/Humo, muzlatish), **1Fit** (ko'p zalga
    bitta abonement), **UzFit** (o'zbekcha fitnes ilovasi), **Eda AI / Bodring AI /
    Kaloriya.uz** (rasmdan kaloriya).
    - **Bizning ustunlik:** jonli trener tuzgan reja + zal + do'kon bitta ilovada; oylik
      to'lovsiz; o'zbek taomlari. Raqobatchilarning hech birida bu uchalasi birga yo'q.
    - **Orqada qolgan joylar:** onlayn to'lov, muzlatish, do'konlarda (Play Market) yo'qligi,
      push, iPhone, mashq jurnali; davomat qo'lda. (Rus tili — shu kuni yopildi, 82-band.)
    - **Rasmdan kaloriya (AI) tavsiya qilinmadi:** tadqiqotlarda aralash taomda 25–35% xato,
      porsiyani aniqlash 39% gacha tushadi; har so'rov pullik. O'rniga — "rejadan tashqari
      yedim": mijoz bazadan taomni tanlab, porsiyani o'zi yozadi.
    - **Reja (zal egasi bilan kelishilgan tartib, boshlanmagan):**
      1) pul — abonementni muzlatish, muddati o'tganlar ro'yxati, kunlik kassa;
      2) davomat — kirishda QR skaner, davomat seriyasi va "N kundan beri kelmadi";
      3) kengayish — Play Market (25 $), push (Blaze);
      4) boyitish — "rejadan tashqari yedim" + kun yakuni, mashq jurnali (kg, takror),
         do'konda chegirma, tana o'lchamlari;
      5) katta — Payme/Click, mashg'ulotga yozilish, iPhone (Mac + yiliga 99 $).
    - **Hozircha kerak emas:** zal bandligi (mijoz kam), "do'st olib kel" (Play Market'dan
      oldin ishlamaydi), oylik natija kartasi, Excel.
    - Qiziqtirish g'oyalari (ball, daraja, nishon, seriya, zal reytingi, ball evaziga chegirma)
      muhokama qilindi — qaror yo'q; QR skanerdan keyin ma'noli (davomat aniq bo'lishi kerak).

84. **Ilova nomi "Qobil", yangi ikonka, APK joylandi (7-okt)** — zal egasi so'rovi:
    - **Ikonka:** `assets/icon/logo_src_3.png` — oldingi rasmdagi "DISCIPLINA · FOCO · FORÇA ·
      CONSTÂNCIA" o'rniga oltin "QOBIL" va "ZAL · TOSHKENT", ko'krakdagi "W" o'rniga "Q"
      (eski belgi `cv2.inpaint` bilan atrofdagi to'qimadan tiklab yopildi). Rasm asli
      internetdan — mualliflik xavfi qoladi.
    - **Nom:** `android:label`, `MaterialApp.title`, "Qobil zal" (kirish ekrani),
      "Bosh admin • Qobil" / "Trener paneli • Qobil" / "Barmen • Qobil", bildirishnoma kanali
      nomi, `web/index.html`, `web/manifest.json`, yuklab olish sahifasi (`public/index.html`),
      lug'at kalitlari. Kod izohlaridagi "Diamond dizayn tizimi" va hujjatlardagi eski nom qoldi.
    - **Brauzerda sinaldi** (vaqtinchalik sinov shogirdi ochilib, keyin o'chirildi — hujjat
      va kirish akkaunti, 404 bilan tasdiqlandi), rus tilida: "Bugun" (reja nomi, mahallar,
      taqiq ro'yxati, trener maslahati tarjimada; suv belgisi ko'rinadi), Do'kon (bo'limlar
      tarjimada, rasm bosilsa to'liq ekranda ochiladi, rangli tovarda o'lcham va rang tanlash),
      Profil (abonement kartasi). Tovar nomi va rang nomlari bazadan — o'zbekcha.
    - "g" (gramm) birligi ham tarjimaga ulandi. `flutter test` 120/120, lug'at 871 kalit.
    - **Sinalmagan:** telefondagi APK (ochilishi, rasm keshi, bildirishnomalar, kamera).
      Reja: `specs/nom-qobil.md` (lokal).

85. **Tillar to'liq yopildi (7-okt)** — qolgan ikki guruh:
    - **Viloyat va tumanlar** (`hudud.dart`, 199 nom) rus va ingliz tiliga tarjima qilindi;
      "Zal qo'shish" oynasi ro'yxatlarida va zal manzilida (`Gym.place`) `tr()` bilan chiqadi.
      Bazaga avvalgidek o'zbekcha kalit yoziladi.
    - **Tizim oynalari** (vaqt tanlash, "Orqaga" va h.k.) — `flutter_localizations` qo'shildi
      (sof Dart, Android plagini emas); `MaterialApp.locale` = ilova tili. `intl` 0.19 → 0.20.3.
    - **Bildirishnoma kanali tavsifi** — ilova tilida.
    - **Chatdagi tizim xabarlari** (buyurtma, abonement eslatmasi) bazada o'zbekcha turadi,
      ko'rsatishda `trChat()` (`lib/l10n/tr.dart`) naqsh bo'yicha tarjima qiladi; odam yozgan
      xabar o'zgarmaydi.
    - O'lchov birliklari (`kkal`, `kg`, `g`, `sm`, `yosh`) ham ulandi — bular birinchi
      o'tishda o'tkazib yuborilgan edi (vosita bitta kichik harfli so'zni matn deb hisoblamaydi).
    - Lug'at: **1 081 kalit**, koddagi hamma `tr`/`trf` kalitida rus va ingliz tarjimasi bor.
    - Kodda tarjimaga ulanmagan qolgan matnlar (ataylab): brend nomi ("Qobil"), Firestore
      maydon nomlari, sana formatlari, misol tariqasidagi maydon ko'rsatmalari ("Bunyodkor 12",
      "Anvar aka"), "OK", ishlab chiquvchi uchun "Firebase sozlanmagan" ekrani.

86. **Do'kon tovarlari uch tilda (7-okt)** — `Product` ga `nameRu`, `nameEn`, `noteRu`, `noteEn`
    qo'shildi (ixtiyoriy; bo'sh bo'lsa o'zbekchasi chiqadi). Ekranda `displayName` /
    `displayNote`. Tovar tahrirlash oynasida "Tarjima (ixtiyoriy)" bo'limi. Rang nomlari
    lug'at orqali (`tr(c)`), qiymati bazada o'zbekcha.
    - Bazadagi **146 tovarning hammasi** to'ldirildi: `tools/dokon/tovar-tarjima.json`
      (90 nom, 121 izoh) + `node tools/dokon/tarjima_yozish.mjs` (faqat shu 4 maydonga tegadi,
      qayta ishga tushirish xavfsiz; `korish` — faqat ko'rsatadi).
    - Tarjimada ichki eslatma ("Narx AllPituz kanalidan (24-sent)", "hozirgi narxni tekshiring")
      tashlab ketildi. **O'zbekcha izohda u hali turibdi va mijozga ko'rinadi** — tozalash
      taklif qilingan, qilinmagan.
    - Buyurtma ro'yxatlarida tovar nomi o'zbekcha qoladi (`orders.productName` shunday yozilgan).
    - Eski APK'da tovar tahrirlansa (`set`), tarjima maydonlari o'chadi — keyin skriptni qayta
      ishga tushirish kerak. `flutter test` **122/122**, lug'at 1 100 kalit.
      Reja: `specs/tovar-tarjima.md` (lokal).

87. **Shogirdda skrinshot bloklandi (7-okt)** — zal egasi so'rovi (5-oktabrdagi "faqat suv
    belgisi" qarori o'zgardi; suv belgisi ham qoldi). Android `FLAG_SECURE`:
    `MainActivity.kt` da `qobil/ekran` kanali, Dart tomoni `lib/services/screen_guard.dart`,
    `auth_gate.dart` shogird kirganda yoqadi, xodim yoki kirish ekranida o'chiradi.
    Skrinshot va ekran yozuvi qora chiqadi; "oxirgi ilovalar" ro'yxatida ham ko'rinmaydi.
    - **Faqat shogirdda** (taxmin — xodimlar xatoni skrinshot qilib yubora olsin).
    - **Web versiyada bloklanmaydi** — shogird brauzerdan (`/ilova/`) kirsa skrinshot oladi.
      Ikkinchi telefon bilan suratga olishni ham to'smaydi.
    - **Telefonda sinalmagan** (Kotlin kodi kompilyatsiya bo'ldi, APK yig'ildi).
      Reja: `specs/skrinshot-bloklash.md` (lokal).

88. **Suv belgisi — rasm (7-okt)** — zal egasi bergan rasm (pahlavon) "Bugun" ekrani o'rtasida
    juda xira (10%) turadi: `assets/brand/suv_belgisi.png` — asl rasmning yorqinligi
    shaffoflikka aylantirilgan (qora fon yo'q), `Image.asset(color: onSurface, srcIn)` bilan
    matn rangiga bo'yaladi (qorong'i va yorug' rejimda ko'rinadi). `lib/widgets/watermark.dart`.
    - **Ism va telefon yozuvi olib tashlandi** (zal egasi so'rovi). Oqibati: rasm tarqalsa
      kimniki ekani ko'rinmaydi; himoya endi faqat `FLAG_SECURE` ga tayanadi (87-band) —
      web versiyada va ikkinchi telefon bilan suratga olishda himoya yo'q.
    - Vaqtinchalik sinov shogirdi bilan brauzerda ko'rildi (akkaunt o'chirildi).
      Rasm internetdan — mualliflik xavfi (ikonka kabi).

89. **Til tugmasi ichkarida ham (7-okt)** — avval faqat kirish ekranida va Sozlamalar ichida
    edi (topish qiyin). Endi: xodimlar tepa panelida globus belgisi (`LangPicker(iconOnly)`),
    shogird Profilida alohida "Til" qatori. Brauzerda bosh admin bo'lib sinaldi. Til
    almashganda ilova qayta chiziladi va birinchi bo'limga qaytadi.

    **7-oktabr yakuni:** nom "Qobil" va ikonka (84), tillar to'liq (85), tovarlar uch tilda
    (86), skrinshot bloki (87), suv belgisi rasmi (88). Web va APK joylangan;
    APK nusxasi `Qobil-2026-10-07.apk`. **Bu kungi APK'larning hech biri telefonda
    sinalmagan.** Qarorlar: Blaze kerak emas; guruh mashg'ulotlari — trener bilan gaplashgach;
    zaxirani avtomatlashtirish — pauzada.
      `flutter test` **121/121**. Web va APK joylandi.
    - **Tarjima bo'lmaydigan yagona narsa** — odam yozgan matn: tovar nomi/izohi/rangi, trener
      o'zi yozgan reja va taom nomi, zal nomi, ismlar, chat.

90. **"Rejadan tashqari yedim" (8-okt)** — Eda AI kabi rasmdan kaloriya o'lchash so'ralgan edi;
    tavsiya qilinmadi (aralash taomda 25–35% xato, har rasm pullik, server kerak — Blaze
    rad etilgan). O'rniga: shogird "Bugun" ekranida **"+ Yedim"** → mahsulotlar bazasidan
    taom tanlaydi → gramm yozadi (tez tugmalar 50/100/150/200/300) → kkal va oqsil darhol
    ko'rinadi → qo'shiladi.
    - `ExtraFood` (`models.dart`), `Db.extras / addExtra / removeExtra`; yozuv
      `users/{uid}/days/{sana}.extras` ro'yxatida (qoidalar o'zgarmadi). Kaloriya qo'shilgan
      paytda hisoblanib yoziladi: `kkal = food.kcal * gramm / 100`.
    - `lib/widgets/extra_food_sheet.dart`: tanlash oynasi va `ExtrasToday` ro'yxati.
    - Kunlik halqa va "kkal qoldi" rejadagi + qo'shimchalarni birga sanaydi; rejadan oshsa
      "N kkal ortiqcha" (qizil).
    - Trener / bosh admin shogird kartasida ("Reja" tabi) bugungi qo'shimchalarni ko'radi.
    - **Brauzerda sinaldi** (vaqtinchalik sinov shogirdi, keyin o'chirildi): Osh 300 g →
      600 kkal, halqa 600 / 1454, bosh adminda ko'rindi.
    - **Cheklov:** faqat gramm ("1 kosa", "1 dona" yo'q); bazada 20 ta mahsulot, ko'pi
      xomashyo — tayyor taomlarni (somsa, lag'mon …) trener qo'shishi kerak; bazada yo'q
      taomni shogird o'zi yarata olmaydi.
    - Yangi vosita: `node tools/sinov/shogird.mjs yarat | parol | ochir` — ekranlarni ko'rish
      uchun vaqtinchalik shogird (haqiqiy bazada; ish tugagach ALBATTA `ochir`).
    - `flutter test` **124/124**, lug'at 1 113 kalit. Web va APK joylandi
      (`Qobil-2026-10-08.apk`), telefonda sinalmagan. Reja: `specs/yedim-tugmasi.md` (lokal).

91. **"Tana xaritasi" — mashqlar ekrani, sinov versiyasi (12-okt)** — zal egasi "Dala" sayti
    uslubida (qora fon, binafsha urg'u, sariq yorliqlar, kartochkasiz) tana xaritasini so'radi:
    tanadagi joy bosilsa — o'sha mushak mashqlari chiqsin. Zal → "Tana xaritasi" kafeli
    (`gym_screen.dart`) → `lib/screens/user/muscles_screen.dart`. Ranglar shu faylda,
    `AppColors` ga qo'shilmagan (faqat shu ekran).
    - **Ma'lumot:** `lib/models/exercises.dart` — 12 mushak guruhi, 36 mashq (nomi, yondashuv ×
      takror, maslahat, yordamchi mushaklar). **Namunaviy ro'yxat** — trener tasdiqlamagan.
    - **Nuqtali tana** (`lib/widgets/particle_body.dart`): qomat 8 tomondan (har 45°), har
      ko'rinishda 12 480 nuqta. Ekran ochilganda nuqtalar sochilib yig'iladi; barmoq bilan
      surilsa yoki "O'GIRISH" bosilsa aylanadi (ko'rinishlar so'nib-paydo bo'ladi); mushak
      bosilsa o'sha joyga yaqinlashadi va soya-yorug' bilan sariq yonadi. Mushak joylari
      hamma 8 ko'rinishda qo'lda belgilangan (`_regions`): old va orqada aniqroq, qiya va yon
      ko'rinishlarda taxminiy to'rtburchak.
    - **Nuqtalar manbasi:** zal egasi bergan "360 gradus" rasmi (bitta qomat 8 tomondan).
      `python tools/tana/zarrachalar.py <rasm>` → `lib/widgets/body_photo_points.dart` (1,3 MB,
      generatsiya qilingan). **Manba rasm repoda yo'q** — faqat undan olingan nuqtalar. Skript
      ichida: fonni ayirish, pol aksini kesish, qora kiyim ostidagi relyefni ko'tarish (mahalliy
      kontrast), gavda ichidagi teshiklarni to'ldirish, uzilgan mayda dog'larni tashlash.
    - **Tezlik:** har (ko'rinish, tanlangan mushak) uchun nuqtalar bir marta hisoblanib
      saqlanadi (`_Layer`, `Float32List`); kadrda 15 ta `drawRawPoints`. Nuqtama-nuqta harakat
      faqat ekran ochilgandagi yig'ilishda. Brauzerda debug rejimi sekin — ko'rish uchun
      `flutter run -d chrome --release`.
    - **Qismli tana** (`lib/widgets/body_map.dart`): har mushak alohida ko'pburchak, old va
      orqa; nuqtali tana ostida ikkita shakl (bosiladi) va har mashq yonida kichik shakl
      (asosiy mushak to'q, yordamchilar och binafsha). Chizma — **react-body-highlighter**
      (MIT, Copyright (c) 2020 GV79): `python tools/tana/qismlar.py <index.ts>` →
      `lib/widgets/body_parts_data.dart`; litsenziya matni
      `tools/tana/LICENSE-react-body-highlighter.txt`.
    - **Faqat zal:** ekran tepasida hammaga ko'rinadigan yozuv — "Hozircha faqat zaldagi
      mashqlar. Uydagi mashqlar hali tayyor emas." (uch tilda). Uy mashqlari — ochiq ish.
    - **Video joyi:** mashq ochilganda "Video hali tayyorlanmagan. Trener tayyorlab qo'ygach,
      shu yerda ko'rinadi." (uch tilda). Video yuklash va ko'rsatish **hali yo'q**.
    - **Sinalgani:** `flutter analyze` toza, `flutter test` **127/127**, lug'at 1 221 kalit.
      Ko'rinishlar test rasmlari orqali tekshirildi; trener uchun video ko'rinmas Chrome'da
      yozildi (bosish, surish, aylanish ishladi). **Telefonda sinalmagan.** Saytga va saytdagi
      APK ga chiqarilmagan.
    - **Ma'lum kamchiliklar:** rasmda kepka bor (avval "kepka kerak emas" deyilgan); ko'krak
      ko'ylak ostida — ikki bo'lagi ajralmaydi; 225° va 270° da bosh yonida bir-ikki ortiqcha
      nuqta; manbada 135° va 225° ko'rinishlar deyarli bir xil; qismli chizma burchakli.
    - Reja va qarorlar tarixi: `specs/tana-xaritasi.md` (lokal).

92. **Mashqlar haftalik reja bo'yicha; pastki menyu (12-okt)** — zal egasi: "bosganda pastki
    menyu yo'qolyapti" va "shogird mashg'ulot kunida mashg'ulotdan tashqari mashqni belgilay
    olmaydi, faqat o'shalar turadi".
    - `MusclesScreen` endi `Navigator.push` bilan emas — `GymScreen` (endi `StatefulWidget`)
      ichida ko'rsatiladi; orqaga `onBack` + `PopScope`. Pastki menyu joyida qoladi.
    - `lib/models/gym.dart`: `workoutMuscles` (3 mashg'ulot → mushak id'lari), `musclesFor`,
      `weekdayOfMuscle`. Taqsimot: 1) ko'krak, biceps, **bilak**; 2) qanot, son oldi, son
      orqasi, dumba, boldir, **qorin**; 3) yelka, triceps, **trapetsiya**. Qalin yozilganlari
      mashg'ulot nomida yo'q edi — taxminan qo'shilgan, **trener tasdiqlashi kerak**.
    - Ekran: tepada "BUGUN · kun" va mashg'ulot nomi; bugungi mushaklar yonib turadi
      (`ParticleBody.today`); nomlar ro'yxatida va pastda faqat shu mashg'ulot. Rejadan
      tashqari mushak tanada ham bosilmaydi. Dam olish va "uyda mashq" kunida — keyingi
      mashg'ulot (oldindan ko'rish). Zal kunlari tanlanmagan shogirdda hamma mushak ochiq.
    - Hammaga ko'rinadigan yozuv: "Hozircha faqat zaldagi mashqlar. Uydagi mashqlar hali
      tayyor emas." (uch tilda).

93. **Mashg'ulot navbati (12-okt)** — zal egasi: "boshlagandan keyin, masalan birinchi yelka
    bo'lsa, yelka mashqlari tugamaguncha qo'lniki yonmaydi".
    - `gym.dart`: `WorkoutProgress(started, done)`, `activeMuscle(plan, done, keysOf)` — reja
      tartibida birinchi tugallanmagan mushak. `Exercise.key` — "bajardim" kaliti.
    - Baza: kunlik yozuv `users/{uid}/days/{sana}` ga `gymStarted`, `gymDone: [kalit]`
      (qoidalar o'zgarmadi). `Db.workout / startWorkout / toggleExercise`.
    - Ekran: zal kunida "Tartib: A → B → C" va "Mashg'ulotni boshlash". Boshlangach faqat
      navbatdagi mushak yonadi va faqat uning mashqlari ochiq, har birida "Bajardim" (qayta
      bosilsa belgi olinadi). Tugagani — "✓ … — tugadi", keyingilari — "Navbatda: …".
      Hammasi tugasa — "Bugungi mashg'ulot tugadi". Navbat rejimida mushak qo'lda tanlanmaydi.
    - Holat bazada: ilova yopilib ochilsa ham davom etadi; ertasi kuni toza.
    - **Yo'q:** trener shogird bajargan mashqlarni ko'radigan ekran (ma'lumot bazada bor);
      "qaytadan boshlash" tugmasi.

94. **Trener mashq qo'shadi, video havolasi (12-okt)** — zal egasi: "trener yangi mashq
    qo'shayotganda tana sxemasida qayerga qo'shayotgani ko'rinsin; bir xil bo'lib qolmasin;
    bor mashqlarga ham video qo'ysin".
    - Baza: `exercises/{id}` — `name, muscle, sets, tip, also, video, createdAt (ms),
      createdBy, base`. Qoida (`firestore.rules`): o'qish — kirgan hamma; yaratish — trener
      va bosh admin, `createdBy == uid`; tahrir — xodim, `createdBy/createdAt/base`
      o'zgarmaydi; o'chirish — xodim; maydonlar va uzunliklar tekshiriladi. Mashqlar hamma
      zal uchun umumiy. **Qoidalar 12-okt jonli bazaga joylandi.**
    - Trener / bosh admin: Zal tabi → "Mashqlar" (`lib/screens/admin/exercises_admin_screen.dart`).
      Tepada nuqtali tana (shogird ko'radigani), ostida qismli chizma, mushaklar ro'yxati
      sonlari bilan. Mushak bosilsa — shu mushak mashqlari va "Mashq qo'shish".
    - Qo'shish varag'i (`ExerciseForm`): tana chizmasida asosiy mushak to'q, yordamchilar och
      — bosib o'zgartiriladi; nom, yondashuv × takror, maslahat, video havolasi. "Bu mushakda
      bor mashqlar" ro'yxati turadi; **bir xil nom saqlanmaydi** (`sameExercise` — harf,
      tutuq belgisi, bo'shliq farqsiz; boshqa mushakda bo'lsa ham).
    - **Namunaviy 36 mashq ham tahrirlanadi:** o'zgartirilganda bazaga nusxasi yoziladi
      (`base` = namunaviy nomi) va ro'yxatda aslining o'rniga chiqadi; "Asl holiga qaytarish"
      nusxani o'chiradi. Tegilmagan maydonlar tarjimasi saqlanadi; "bajardim" kaliti o'zgarmaydi.
    - Shogird: trener qo'shganini darhol ko'radi (APK yangilamasdan); 7 kun "YANGI" yorlig'i,
      mushak nomi yonida "· yangi"; video havolasi bo'lsa — havola va "Havolani nusxalash".
    - **Cheklovlar:** video FAYL yuklanmaydi (Storage Blaze talab qiladi — rad etilgan), faqat
      havola (YouTube, Telegram …); havola ilovadan ochilmaydi (loyihada `url_launcher` yo'q —
      qo'shish zal egasi ruxsati bilan), shogird nusxalab brauzerda ochadi; trener yozgan matn
      tarjima qilinmaydi; takror tekshiruvi faqat aynan bir xil nomni ushlaydi.
    - Qoida testlari: `tools/rules_test` — **230 o'tdi** (17 tasi yangi). Emulyator Java 21
      talab qiladi: `JAVA_HOME=%LOCALAPPDATA%\jdk21\jdk-21…` (PATH dagi Java 15 emas).
    - `flutter test` **144/144**, lug'at 1 272 kalit. Reja va qarorlar:
      `specs/trener-mashqlari/00-overview.md`, `specs/tana-xaritasi.md` (lokal).

95. **Videoni ilovadan ochish; "boshlash" tepada; saytga joylash (12-okt kech)** — zal egasi
    "qil" dedi (kutubxona qo'shishga ruxsat) va "boshlash degan joyim qani" deb so'radi.
    - **Yangi kutubxona: `url_launcher`.** Mashqda video havolasi bo'lsa — "Videoni ko'rish"
      tugmasi (`LaunchMode.externalApplication`: YouTube, Telegram yoki brauzer); ochilmasa
      xabar chiqadi; "Havolani nusxalash" ham qoladi. `AndroidManifest.xml` `<queries>` ga
      `VIEW` + `https` qo'shildi (Android 11+).
    - **"Mashg'ulotni boshlash"** avval mashqlar ro'yxati oldida (ikki tana ostida, juda
      pastda) edi — ko'rinmas edi. Endi ekran tepasida, sarlavha ostida, "Tartib: …" bilan.
      Boshlangach o'rnida "Hozir: mushak · N / M bajarildi" turadi.
    - **Tugma faqat zal kunida chiqadi:** dam olish kunida, "uyda mashq" kunida va zal
      kunlari tanlanmagan shogirdda yo'q (o'sha kunlari sarlavhada sababi yozilgan).
    - **Joylandi:** qoidalar + web (`public/ilova`) + APK (`public/app/kq.bin`) —
      `deploy.ps1`. `flutter test` 144/144, lug'at 1 274 kalit.

96. **Telefonda topilgan nuqsonlar; tovar izohlari (13-okt)** — zal egasi 12-okt APK ni
    telefonda ko'rdi: "Chiqish bossa qotyapti (hamma rolda)" va "tana xaritasini orqaga
    o'girsa oyoq sochilib yotibdi".
    - **Chiqish qotishi.** Brauzerda qayta tekshirildi (sinov shogirdi): 1,5 soniyadan tez —
      demak faqat telefonda. Sabab (kod bo'yicha; telefonda tasdiqlanmagan): `signOut`
      chiqishdan oldin ketma-ket kutardi — FCM token yozuvini o'chirish (server javobi),
      `deleteToken()` (tarmoq), `Notifications.cancelAll()`. Endi: token yozuvi 1,5 s dan
      oshsa kutilmaydi, `deleteToken` umuman kutilmaydi, `cancelAll` 1 s (`push.dart`,
      `db.dart`). Brauzerda token yo'q — u yerda bu qadamlar o'tkazib yuboriladi.
    - **Orqada oyoq.** Orqa ko'rinishda (180°) boldirdan pastda pol yaltiraydi, botinka esa
      qora — nuqtalar pol dog'larini chizgan edi. `tools/tana/pol_tozalash.py`: shu zonadagi
      nuqtalar olib tashlanib, ikki botinka shakli qo'lda chizildi. Manba 360° rasm
      saqlanmagan — tuzatish tayyor nuqtalar ustida. Ko'rinishlarda nuqtalar soni endi har
      xil (`particle_body.dart` massivlari eng uzun ko'rinish bo'yicha). 135° va 225°
      tegilmadi.
    - **Tovar izohlari.** Mijozga ko'rinadigan ichki eslatma ("Narx AllPituz kanalidan …",
      "… hozirgi narxni tekshiring") olib tashlandi: `node tools/dokon/izoh_tozalash.mjs` —
      bazada 146 tovardan 129 tasi, manba json'lar va `tovar-tarjima.json` kalitlari birga
      (aks holda tarjima uzilardi). Qayta tekshirildi: bazada 0 qoldi, tarjimalar joyida.
    - `flutter test` 144/144. Web va APK joylandi (`Qobil-2026-10-13.apk`). Reja:
      `specs/chiqish-va-orqa-oyoq.md` (lokal).
    - **Telefonda tasdiqlandi (zal egasi, 13-okt):** "Chiqish" qotmaydi; shogird akkauntida
      skrinshot olinmaydi (`FLAG_SECURE`, 87-band — birinchi marta haqiqiy telefonda ko'rildi).
      Tana xaritasi ham (91-band): 12 480 nuqta bilan qotmaydi, aylanadi, orqada oyoq joyida,
      mushak to'g'ri tanlanadi, pastki menyu turadi.
      Keyin 92–95-bandlar ham: mashg'ulot navbati, trener mashq qo'shishi, video havolasi va
      "Videoni ko'rish" — "hammasi ishladi".

97. **Do'kon ustamasi olib tashlandi (13-okt)** — zal egasi: "bardagi narsalar narxining
    ustiga qo'yma, hozircha o'sha narxda qolsin". 4-oktabrda hamma tovarga ~15% ustama
    qo'yilgan edi (62-band). Aniqlashtirildi (uch variantdan "ustamani olib tashla" tanlandi).
    `node tools/dokon/ustama_olish.mjs` — 146 tovarning hammasida `price` = `costPrice`
    (masalan 632 500 → 550 000; forma 16 → 14 $). Tan narx o'zgarmadi — ustamani
    `node tools/dokon/narx_ustama.mjs <foiz>` bilan qaytarsa bo'ladi. Qayta tekshirildi:
    ustamali tovar 0 ta. **Oqibati:** "Do'kon foydasi" (sotilgan narx − tan narx) yangi
    sotuvlarda 0 chiqadi. Ilova kodi o'zgarmadi — yangi APK kerak emas, narx bazadan o'qiladi.

98. **Video ilova ichida, muqova bilan (13-okt kech)** — zal egasi telefonda ko'rib: "video
    programmaning o'zidan ochilishi kerak; foni qop-qora"; keyin brauzerda: "boshqa havola
    ochyapti, o'zida qo'ysin; ramkani kichraytir, cho'zilmasin".
    - `lib/models/video_link.dart`: `youtubeId` (youtu.be, watch?v=, shorts, embed, live,
      m./music.) va `youtubeThumb` (muqova: `img.youtube.com/vi/<id>/hqdefault.jpg`).
    - YouTube havolali mashqda video joyida muqova va "o'ynatish" tugmasi; bosilganda video
      **shu joyning o'zida** o'ynaydi — boshqa ilova yoki oyna ochilmaydi. Telefonda
      `lib/widgets/youtube_embed_io.dart` (**yangi kutubxona `webview_flutter`**), brauzerda
      `youtube_embed_web.dart` (`<iframe>`, `HtmlElementView.fromTagName`); shartli import.
      Sahifa `youtube-nocookie.com` manzili bilan yuklanadi (aks holda pleyer "153" xatosi).
    - Ramka doim yotiq 16:9, eni 560 gacha; tik video (Shorts) ichida o'z nisbatida.
      Video va maslahat mashq qatorida butun kenglikda (avval kichik shakl yonida siqilgan).
    - Video yo'q mashqda joy binafsha tusli va hoshiyali (qora bo'sh quti emas).
    - YouTube bo'lmagan havola (Telegram …) avvalgidek tashqarida ochiladi. Video egasi
      boshqa joyda ko'rsatishni taqiqlagan bo'lsa — pleyer ostida "YouTube'da ochish".
    - **Tekshirildi:** brauzerda sinov shogirdi bilan — muqova, joyida o'ynash, ixcham ramka.
      `flutter test` 147/147. **Telefonda (WebView) tekshirilmagan** — zal egasi "joyla"
      dedi. Web va APK joylandi (`Qobil-2026-10-13.apk`, kechki nusxa).
    - **Eslatma:** release web nusxada `flutter_service_worker.js` eski kodni keshlaydi —
      yangilangan sayt brauzerda ikkinchi yuklashda ko'rinadi.
    - Video FAYL yuklash hali yo'q — saqlash joyi bo'yicha qaror kutilmoqda (Firebase
      Storage/Blaze, Cloudflare R2 yoki bazada bo'laklab). Telegram YOPIQ kanal videosi ilova
      ichida ko'rsatilmaydi; tavsiya — YouTube "Havola orqali" (Unlisted).
      Reja: `specs/video-ilova-ichida.md` (lokal).

99. **Mashq darajasi va shogirdga mashq tanlash (14-okt)** — zal egasi modeli: mashq va video
    kutubxonaga bir marta kiritiladi; har mashqda daraja (faqat trener ko'radi); trener har
    shogirdga o'z mashqlarini tanlaydi (kimga ko'p, kimga kam) va mushak o'rganib qolmasligi
    uchun istagan payt almashtiradi; o'zgartirmasa — eski tanlov turadi.
    - **Daraja:** `Exercise.level` ('' / beginner / middle / pro), `levels` nomlari. Trener
      formasida tanlanadi; ro'yxatda belgi va daraja bo'yicha saralash. Shogird ko'rmaydi.
      Namunaviy 36 mashq belgisiz — trener qo'yadi.
    - **Tanlash:** `users/{uid}.program` (`{mushak: [mashq kaliti]}`, toMap'ga kirmaydi),
      `Db.setProgram`. Trener: Mijozlar → shogird → yangi **"Mashqlar"** tabi
      (`lib/screens/admin/student_program_tab.dart`) — zal kunlari bo'yicha mushaklar,
      kutubxonadan belgilash, "Standartga qaytarish". Shogird: `exercisesForStudent` —
      tanlangan bo'lsa shular (trener tartibida, o'chirilgan mashq tashlanadi); bo'lmasa
      "Boshlovchi" belgililar; ular ham bo'lmasa hammasi. "Bajardim" navbati shu ro'yxat bo'yicha.
    - **Qoidalar:** `exercises.level` faqat 4 qiymat; shogird o'z `program`ini o'zgartira
      olmaydi; trener — faqat o'z shogirdiniki. **Joylandi (14-okt)** — majburiy edi: yangi
      ilova mashqqa `level` yozadi, eski qoida uni rad etardi.
    - **Diqqat:** trener biror mashqqa "Boshlovchi" qo'yishi bilan tanlovi yo'q shogirdlar
      o'sha mushakda faqat boshlovchi mashqlarni ko'radi.
    - `flutter test` 153/153, qoida testlari 237/237. Trenerning "Mashqlar" tabi telefonda
      va ekranda ko'rilmagan. Zal egasi "webga chiqaz" dedi — web va APK joylandi.
    - Keyingi: video FAYL yuklash va o'chirish (Blaze yoqilgach; `specs/mashq-dasturi/00-overview.md`).


---

## 13. Tavsiyalar — nimani keyingi navbatda qilish kerak (2-oktabr)

Loyihaning hozirgi holatiga qarab tuzilgan ro'yxat. Tartib muhimlik bo'yicha: yuqoridagisi
ko'proq foyda beradi yoki ko'proq xavfni yopadi. Kod o'zgarmagan — bu faqat reja.

### 13.1. ~~Abonement va davomat yo'q~~ — ASOSAN HAL BO'LDI (4-okt, 61-band)

Abonement yozuvi (boshlanish/oy/narx/to'langan sana), status va haftalik eslatma jurnali
qilindi; davomat — mavjud "bugun kim keladi" ro'yxatiga belgilash qo'shildi. **Qolgani:**
bosh adminda oylik/yillik moliyaviy hisobot (nechta abonement sotildi, qancha tushum —
`SalesReport` naqshida qilish mumkin, hali qilinmagan); eslatmalarni **avtomatik** (trener
kirmasa ham) yuborish yo'q — hozir faqat trener/bosh admin "Eslatma yubor" bosganda yuboriladi
(Cloud Functions/Blaze bo'lmagani uchun chinakam fon vazifasi yo'q).

### 13.2. ~~Do'kon narxlari foyda bermasdi~~ — HAL BO'LDI (4-okt, 62–63-band)

`costPrice`/`margin` va bir martalik ustama skripti (`narx_ustama.mjs`) qilindi va
**5-oktabrda haqiqiy do'konga qo'llandi: +15%**, 115 tovar, xato yo'q (66-band). Qoldiq endi o'lcham bo'yicha (`Product.sizeStock`) — "XL 2 ta, 4XL yo'q" ishlaydi.
**Qolgani:** har
tovarning haqiqiy qoldiq sonini `shop_admin_screen.dart` orqali kiritishi kerak (hozir
taxminiy raqamlar turibdi).

### 13.3. Xavfsizlik

- ~~**Bosh admin paroli skript ichida ochiq turadi**~~ — **HAL BO'LDI (2-okt, 14-bo'lim).**
  Parol endi `.env` da, skriptlar `tools/maxfiy.mjs` orqali o'qiydi. Git tarixidan ham
  olib tashlandi (`git filter-repo`).
- **Trener paroli almashtirilmagan** — u saytda ochiq turgan edi (49-band). Parolning
  o'zi hujjatlardan olib tashlandi, lekin **Firebase'da hali o'sha parol turadi**.
  Zal egasi `Xodimlar` bo'limidan almashtirsin. Haqiqiy qiymat `PAROLLAR.md` da.
- ~~**Bazaning zaxirasi yo'q.**~~ — **Skript tayyor (4-okt, 65-band)**, `ZAXIRA.bat`.
  **Birinchi zaxira 5-oktabrda olindi** (`zaxira/2026-10-05_bazaning-zaxirasi.json`, 202 KB).
  Keyin haftada bir marta `ZAXIRA.bat` ni takrorlash kerak.

### 13.4. ~~Foydalanuvchi kam~~ — QR TAYYOR (4-okt, 64-band), qolgani ochiq

Do'konda 115 ta tovar bor, bazada esa 3 shogird. Nomutanosib — ilova to'ldirilgan, lekin
undan foydalanadigan odam yo'q.

- ~~Zal eshigiga QR kod~~ — tayyor: trener/bosh admin panelida QR tugmasi (`/ilova/` ga olib
  boradi), chop etib osish mumkin.
- Trener har yangi mijozga ilovani o'zi o'rnatib beradi (5 daqiqa).
- Birinchi 20 ta shogirddan keyin qaysi bo'lim ishlatilayotgani ko'rinadi va keyingi ish
  taxmin emas, ma'lumot asosida tanlanadi.

### 13.5. Push bildirishnoma — Blaze kerak

Ilova yopiq bo'lganda xabar bormaydi (Cloud Functions joylanmagan, 0-bo'limda yozilgan).
Chat va yangi reja bildirishnomasi ishlamasa shogird ilovaga qaytmaydi.

Blaze tarifi — bank karta bog'lash kerak, lekin bu hajmda (3–50 foydalanuvchi) hisob
amalda nolga yaqin. Limit qo'yib yoqish tavsiya qilinadi → `FUNKSIYALAR_JOYLASH.bat`.

### 13.6. Kichik, lekin sezilarli

- **Xatolarni yig'ish yo'q** (Crashlytics yoki shunga o'xshash): hozir ilova
  foydalanuvchining telefonida qulasa, bu haqda hech kim bilmaydi.
- **Vazn/o'lcham tarixi rasm bilan** ("oldin / keyin"): vazn allaqachon haftada bir marta
  yoziladi — unga rasm va o'lchov (bel, ko'krak) qo'shilsa, shogird natijani ko'radi va
  ilovada qoladi.
- **Trener haqi hisobi:** trener reytingi bor (4-band), lekin har trener nechta shogirddan
  qancha pul olgani hisoblanmaydi.

### 13.7. Rasm va narx haqida ogohlantirish

Do'kondagi rasmlar va narxlar **AllPituz do'konining** suratlaridan olingan (57–60-band).
Agar AllPituz yetkazib beruvchi bo'lsa — muammo yo'q. Agar raqobatchi bo'lsa, o'z
suratlarini qo'yish kerak, aks holda da'vo kelishi mumkin. Buni zal egasi aniqlasin.

### Taklif qilingan tartib

1. ~~Abonement + davomat~~ (13.1, 4-okt qilindi — kod tayyor)
2. ~~Narxga ustama va o'lcham bo'yicha qoldiq~~ (13.2, 4-okt qilindi — kod tayyor)
3. ~~Parollarni muhit o'zgaruvchisiga chiqarish~~ (2-okt qilindi) + trener parolini
   almashtirish (hali qilinmagan) va ~~bazaning haftalik zaxirasi~~ (13.3, skript tayyor)
4. Blaze va push (13.5)
5. ~~QR bilan mijoz yig'ish~~ (13.4, 4-okt qilindi)

**Keyingi navbatdagi ish:** 61–65-bandni haqiqiy Firebase'ga joylash — APK/web qayta
yig'ish, `deploy.ps1`, so'ng `ZAXIRA.bat` va `NARX_USTAMA.bat` ni bir marta qo'lda ishga
tushirish (`.env` kerak). Shundan keyin trener parolini almashtirish va Blaze/push qoladi.

---

## 14. GitHub — ochiq repo (2-oktabr)

Loyiha **<https://github.com/xojaurunov/diamond-zal>** manzilida **ochiq (public)**.
Shox: `main`. 26 commit.

### Nima qilingan

Repo ochiq bo'lgani uchun maxfiy ma'lumot push'dan **oldin** butunlay olib tashlandi —
ishchi nusxadan ham, 25 commit tarixidan ham (`git filter-repo`). Shuning uchun
**Firebase parollari o'zgarmadi**: hamma eski parol bilan kirishda davom etadi.

Olib tashlangani:

| Nima | Qayerda edi | Endi qayerda |
|---|---|---|
| Bosh admin paroli | `tools/holat/holat.mjs`, `tools/dokon/tovar_qoshish.mjs` | `.env` (git'da yo'q) |
| Hamma rol paroli | `DAVOM.md`, `HOLAT.md`, `QOLLANMA.md`, `README.md`, `start.ps1` | `PAROLLAR.md` (git'da yo'q) |
| Zal egasining haqiqiy raqami | hujjatlar | `PAROLLAR.md` |
| Shaxsiy Gmail manzil | hujjatlar, `deploy.ps1`, `JOYLASH.bat`, `tiklash.mjs` | `PAROLLAR.md` |
| Shogird va xodim ismlari | `DAVOM.md`, Figma maketlari (SVG + plagin) | namuna: Shogird 1/2/3, Trener 1/2, Barmen |
| Emulyator parol hash'lari | `.emulator-data/` | git'dan chiqdi, diskda qoldi |
| O'chirilgan 5 shogirdning ismi, telefoni, chati, vazni | `zaxira/2026-09-15_ochirilgan_shogirdlar.json` | git'dan chiqdi, diskda qoldi |
| Commit muallifi email'i | 25 commit metama'lumoti | `xojaurunov@users.noreply.github.com` |

### Yangi qoida — buni buzmaslik kerak

**Hech qanday parol, haqiqiy telefon raqam, email yoki mijoz ma'lumoti kuzatiladigan
faylga yozilmaydi.** Repo ochiq — commit qilingan narsa darhol hammaga ko'rinadi.

- Skriptga parol kerak bo'lsa: `import { maxfiy } from '../maxfiy.mjs'` →
  `maxfiy('OWNER_PASS')`. Qiymat `.env` da turadi.
- Yangi kalit qo'shilsa, `.env.namuna` ga ham **qiymatsiz** holda yoziladi.
- Hujjatda parol kerak bo'lsa — `PAROLLAR.md` ga yoziladi (u `.gitignore` da).
- Shogird yoki xodimning haqiqiy ismi hujjatga yozilmaydi.

### Git'ga tushmaydigan fayllar (lokal, muhim)

| Fayl | Nima | Yo'qolsa |
|---|---|---|
| `PAROLLAR.md` | hamma rolning paroli, Firebase va GitHub ma'lumotlari | parollarni ilovadan tiklash kerak |
| `.env` | `OWNER_EMAIL`, `OWNER_PASS` — vositalar uchun | `.env.namuna` dan nusxa olib to'ldiriladi |
| `android/diamond-release.jks` | APK imzo kaliti | **yangi versiya eski ilova ustiga o'rnatilmaydi** — hamma mijoz qayta o'rnatadi |
| `android/key.properties` | imzo kaliti parollari | yuqoridagi bilan bir xil |
| `zaxira/` | o'chirilgan shogirdlarning ma'lumoti | zaxira yo'qoladi |
| `.emulator-data/` | emulyator eksporti | qayta yaratiladi |

Imzo kalitini **repodan tashqarida** ham saqlang (flesh karta, bulut).

### Zaxira

Tarix qayta yozilishidan oldingi to'liq nusxa (haqiqiy parollar bilan, 25 commit):
`C:\Users\n_urunov\Music\diamond-zaxira-2026-10-02.bundle`.
Qaytarish: `git clone <bundle-yoli> qaytarilgan-nusxa`.

### Buyruqlar

```
git push                      # o'zgarishni GitHub'ga yuborish
git pull                      # boshqa kompyuterdan kelgan o'zgarishni olish
git clone https://github.com/xojaurunov/diamond-zal.git   # yangi kompyuterda
```

Yangi kompyuterda `clone` qilgandan keyin `.env` va `PAROLLAR.md` yo'q bo'ladi —
ularni qo'lda ko'chirish kerak (`.env.namuna` dan nusxa olib to'ldirish).
Imzo kalitisiz APK yig'ilmaydi.

### To'liq tekshiruv (2-oktabr kechqurun)

| Tekshiruv | Natija |
|---|---|
| `flutter analyze` | ✅ 0 xato |
| `flutter test` | ✅ 90/90 |
| Qoida testlari (emulyator) | ✅ 138/138 |
| Hosting: bosh sahifa, `/ilova/` | ✅ 200 |
| Hosting: `app/kq.bin` | ✅ 200, 25 202 368 bayt — lokal `app-arm64-v8a-release.apk` bilan aynan bir xil |
| 5 ta rol bilan kirish (REST) | ✅ hammasi kirdi |
| Baza | 1 zal, 5 xodim, 3 shogird, 3 reja, 115 tovar, 0 buyurtma |
| GitHub | ✅ public, shox `main`, lokal bilan sinxron |
| Kuzatiladigan fayllarda parol/telefon/ism | ✅ topilmadi |
| Imzo kaliti zaxirasi | ✅ `C:\Users\n_urunov\Music\diamond-imzo-kaliti-zaxira\` (SHA-256 mos) |

**Qolgan ikki ish — zal egasi o'zi qiladi** (Claude'ning ruxsat tizimi bu ikkisini to'xtatdi):

1. **Trener paroli (`900000000`) hali eski.** `PAROL_TIKLASH.bat` ni ishga tushiring,
   telefon `900000000` va yangi parolni kiriting. So'ng `PAROLLAR.md` dagi qiymatni
   yangilang va trenerga ayting.
2. **`35d632a` commit'ida shaxsiy email qolgan** — muallif sifatida va `DAVOM.md` ning
   o'sha nusxasida. Keyingi commit'larda u yo'q (repo sozlamasi
   `xojaurunov@users.noreply.github.com` ga o'zgartirildi). Tarixdan butunlay olish uchun
   `git filter-repo` va `git push --force` kerak. Email sizning o'zingizniki va GitHub
   profilingizda baribir ko'rinishi mumkin, shuning uchun bu shart emas — o'zingiz hal qiling.

**Imzo kaliti zaxirasi o'sha diskda turibdi.** Disk buzilsa ikkala nusxa ham ketadi —
`diamond-imzo-kaliti-zaxira` papkasini flesh kartaga yoki bulutga ham ko'chiring.

GitHub sozlamasi (tavsiya): **Settings → Emails → "Keep my email addresses private"** va
**"Block command line pushes that expose my email"** ni yoqing — keyin shaxsiy email bilan
qilingan commit'ni GitHub o'zi qabul qilmaydi.
