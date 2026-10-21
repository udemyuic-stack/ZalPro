# ZalPro — loyiha haqida batafsil

## 1. Umumiy ma'lumot

ZalPro — bitta zal (Diamond) uchun yaratilgan boshqaruv tizimi. Firebase (Auth + Firestore) o'rniga o'z backend (FastAPI + PostgreSQL) ishlatiladi. Mobil ilova (Flutter, brend nomi "Aura Fit") saqlanadi va bosqichma-bosqich yangi API'ga ulanadi.

Loyiha CRM yoki ko'p zalli SaaS emas: `tenant_id` yo'q, `gymId` filial sifatida qoladi.

Bitta git repo (monorepo), ildiz: `ZalPro/`.

```
ZalPro/
  src/
    api/    FastAPI backend (pyproject.toml, zalpro_api/, tests/, alembic/)
    ui/     Flutter ilova (pubspec.yaml, lib/)
  deploy/   Docker Compose, Caddy, systemd (zaxira), Firebase freeze qoidalari
  specs/    spec fayllar (mahalliy, git'ga kirmaydi)
  tools/    yordamchi skriptlar
  new-features/  g'oya va tadqiqot skrinshotlari
```

Eski `diamond-zal`, `diamond-zal-ui`, `diamond-api` papkalariga tegilmaydi.

## 2. Asosiy qarorlar (roadmap)

- **Stek:** FastAPI, Pydantic v2, SQLAlchemy 2.0 (async) + asyncpg, Alembic, PostgreSQL 16+, argon2, PyJWT, pytest, httpx, ruff, uv.
- **Ruxsat mantig'i faqat API qatlamida:** `src/api/zalpro_api/services/permissions.py`. Endpoint ichida alohida `if role == ...` yozilmaydi. Eski `firestore.rules` dagi har bir holat pytest testiga aylantirilgan.
- **Kalitlar matn (`text`):** Firebase uid va hujjat ID'lari o'zgarishsiz saqlanadi.
- **Kirish:** telefon + parol, SMS yo'q. Access token 15 daqiqa, refresh token 30 kun.
- **Fayllar (rasm, video):** Cloudflare R2, S3 API orqali (`aioboto3`). Yuklash presigned URL bilan klientdan to'g'ridan-to'g'ri R2 ga. Bazada faqat fayl kaliti saqlanadi. Kod S3 API ga bog'langan, shuning uchun provayderni almashtirish mumkin.
- **MinIO ishlatilmaydi** (jamiyat versiyasi arxivlangan). Lokal ishlab chiqish va testlar uchun Garage (Docker).
- **Videolar:** hozircha YouTube havolasi sifatida. Yopiq video kerak bo'lsa keyin Bunny Stream.
- **Server:** bitta ijaradagi VPS (API + PostgreSQL + Caddy), taxminan 2 vCPU / 4 GB RAM. 1–5 bosqichlar lokal kompyuterda ishlab chiqilgan va sinalgan; server 6-bosqichda kerak bo'ldi.
- **Zaxira:** har kuni `pg_dump` R2 ga yuklanadi (systemd timer). Qo'shimcha himoya: provayderning avtomatik zaxirasi. Restore tekshiruvi uchun alohida timer bor.
- **Firebase:** production'da ishlashda davom etgan, ma'lumot ko'chirilgandan keyin mobil klientdan olib tashlangan (spec 09).

## 3. Texnologiyalar

### Backend (`src/api`)

| Soha           | Texnologiya / modul                                                                                                                                                                       |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Web framework  | FastAPI, Pydantic v2 (`StrictModel`, `extra="forbid"`), Uvicorn                                                                                                                           |
| Konfiguratsiya | pydantic-settings (`core/config.py`)                                                                                                                                                      |
| ORM / DB       | SQLAlchemy 2.0 async, asyncpg, PostgreSQL 16                                                                                                                                              |
| Migratsiya     | Alembic, 22 ta versiya (`0001_users_gyms_trainers` … `0022_payment_orders`)                                                                                                               |
| Auth           | argon2 (parol xeshi), PyJWT (access + refresh), `refresh_tokens` jadvali, `login_throttle.py` (urinishlarni cheklash), `legacy_password.py` (eski Firebase parollarini migratsiya qilish) |
| Xato formati   | `{"detail": {"code": "...", "message": "...", "errors"?: ...}}` (`core/errors.py`)                                                                                                        |
| Fayl saqlash   | aioboto3 → Cloudflare R2 (`services/storage.py`, `images.py`, `chat_media.py`, `exercise_videos.py`)                                                                                      |
| Video          | ffmpeg bilan siqish (`services/video_transcode.py`)                                                                                                                                       |
| Real-time      | WebSocket (`api/routes/chat_ws.py`, `services/chat_hub.py`)                                                                                                                               |
| To'lov         | Payme (`services/payme.py`), Click (`services/click.py`), buyurtma holati (`services/payments.py`)                                                                                        |
| Push           | push tokenlar (`/users/me/push-tokens`), `push_tokens.py`                                                                                                                                 |
| Test           | pytest, pytest-asyncio, httpx; `tests/` papkasi                                                                                                                                           |
| Lint           | ruff (line-length 100, py312)                                                                                                                                                             |

### Mobil ilova (`src/ui`)

| Soha | Texnologiya / paket |
|---|---|
| Framework | Flutter, Dart SDK >= 3.2 |
| Holat boshqaruvi | flutter_riverpod |
| HTTP / WebSocket | dio, web_socket_channel |
| Saqlash | flutter_secure_storage (token), shared_preferences (sozlamalar) |
| Grafik | fl_chart (vazn, progress) |
| Kamera / AI | camera, google_mlkit_pose_detection (skelet, takror sanash), `services/rep_camera.dart`, `services/hr_camera.dart` (yurak urishi) |
| QR | qr_flutter (a'zo kartasi), mobile_scanner (skaner) |
| Media | image_picker, cached_network_image, video_player, record (ovoz), just_audio |
| Bildirishnoma | flutter_local_notifications, `services/reminders.dart`, `notifications.dart` |
| Lokalizatsiya | intl, flutter_localizations; `lib/l10n/` (uz, ru, en) |
| Shrift | Inter (400/500/600/700) |
| Ekran himoyasi | `services/screen_guard.dart` |

### Deploy va infratuzilma

| Komponent | Fayl |
|---|---|
| Docker image (API) | `src/api/Dockerfile`, `src/api/scripts/start.sh` |
| Compose stack | `deploy/compose.yaml`: `db` (postgres:16), `migrate` (alembic), `api`, `caddy` (caddy:2) |
| Reverse proxy / TLS | `deploy/Caddyfile` |
| Render.com (test) | `render.yaml`: web (docker, `/health`), managed PostgreSQL |
| Zaxira | `deploy/systemd/zalpro-backup.{service,timer}`, `zalpro-restore-check.{service,timer}` |
| Firebase qoldiqlari | `deploy/firebase/` (`firestore.freeze.rules`, rules testlari `freeze.test.mjs`) |
| Sirlar | `.env.example` (haqiqiy `.env` repoga kirmaydi) |

Muhim env o'zgaruvchilar: `DATABASE_URL`, `JWT_SECRET`, `GYM_TIMEZONE` (Asia/Tashkent), `MIN_APP_BUILD`, `R2_*`, `PAYME_*`, `CLICK_*`.

## 4. Ma'lumotlar modeli

PostgreSQL jadvallari (`src/api/zalpro_api/models/`):

| Guruh | Jadvallar |
|---|---|
| Foydalanuvchi va zal | `users`, `gyms`, `trainers`, `refresh_tokens`, `push_tokens` |
| Katalog | `foods`, `plans`, `exercises`, `products` |
| Kunlik ma'lumot | `days`, `weights`, `day_feedback` (mashg'ulotdan keyingi fikr) |
| Abonement va davomat | `subscriptions`, `memberships`, `attendance`, `reminders` |
| Do'kon | `products`, `orders`, `payment_orders` |
| Aloqa | `messages` (matn, rasm, video, ovoz), `photos`, `announcements` |
| O'yin | `coin_ledger`, `rep_sessions`, `user_challenges` |
| Baholash | `ratings` (trener baholari, faqat owner) |

Asosiy qoidalar (spec 01):

- `users.role` — `user`, `admin`, `owner`, `barmen`. "Staff" = `admin` yoki `owner`. Barmen faqat do'kon bilan ishlaydi.
- `users.phone` unique. `users.password_hash` hech qachon javobda, logda yoki xato matnida chiqmaydi.
- `users.gym_id`, `role`, `plan_id`, `program` — foydalanuvchi o'zi o'zgartira olmaydi.
- `trainers.gym_id` har doim `users.gym_id` ning ko'zgusi; mijoz yuborgan qiymat e'tiborga olinmaydi.
- Matn chegaralari `firestore.rules` dagidek: gym `name` 1–60, `address` ≤200.

## 5. API

Barcha yo'llar `/v1` prefiksi ostida. Router'lar (`api/routes/`): `auth`, `users`, `gyms`, `trainers`, `foods`, `plans`, `exercises`, `days`, `weights`, `subscriptions`, `memberships`, `attendance`, `checkin`, `reminders`, `finance`, `stats`, `analytics`, `products`, `orders`, `payments`, `messages` (`/chats`), `photos`, `announcements`, `ratings`, `leaderboard`, `game`, `app_config`, `chat_ws` (`/ws`).

Ruxsat qoidalari:

- Har bir endpoint uchun kamida bitta ruxsat testi (ruxsat berilgan va rad etilgan holat).
- Yangi endpoint `firestore.rules` dagi tegishli holat bilan bir xil bo'lishi kerak.
- Javob shartnomalari o'zgarmaydi: `StrictModel` (`extra="forbid"`), `/v1` prefiks, xato formati.

## 6. Funksional modullar (spec bo'yicha)

### 6.1 Asosiy (1–2 bosqich)
- **Auth:** telefon + parol, login throttle, eski parollarni migratsiya.
- **Foydalanuvchilar va zallar:** profil, rol, zal, trener biriktirish (`PATCH` cheklovlari bilan).
- **Katalog:** ovqatlar, rejalar (`plans`), mashqlar (`exercises`), kunlik belgilar (`days`), vazn (`weights`). Vazn uchun haftalik o'zgarish cheklovi (`weightChangeOk`).

### 6.2 Abonement, davomat, eslatma (3 bosqich)
- Abonement yaratish, `subscription_expires_at` va `memberships` ko'zgusi bitta tranzaksiyada.
- Davomat: QR karta (a'zo) skaner qilinadi, bugungi davomat avtomatik belgilanadi (spec 12).
- Eslatmalar: qo'lda yuboriladigan va avtomatik (`auto_reminders.py`, spec 28) abonement eslatmalari.
- Moliya: oylik abonement tushumi hisoboti (`GET /finance/monthly`).

### 6.3 Do'kon va buyurtmalar (4 bosqich)
- Tovarlar katalogi (`products`), narx bazadan olinadi (klient narxi yubormaydi).
- Buyurtma yaratish, holat: berildi / bekor.
- Berilganda ombor qoldig'i atomik kamayadi.
- Tan narxi (`order cost_price`, migratsiya 0016) va do'kon tahlili (spec 24).

### 6.4 Chat va progress rasmlari (5 bosqich, 13, 23, 42)
- Chat: REST orqali yozish/o'qish, yangi xabarlar WebSocket orqali real vaqtda.
- Matn, rasm, video, ovozli xabar (Telegram uslubida, spec 42). Fayllar R2 ga presigned URL orqali yuklanadi, video serverda ffmpeg bilan siqiladi.
- Progress rasmlari (`photos`), oldin/keyin solishtirish slayderi (spec 16).

### 6.5 Mashq va kamera
- Takror sanagich kamera orqali (ML Kit pose), otjimaniya sanagichi aldashga qarshi (spec 17, 43, 55, pushup-counter).
- Universal takror sanagich va o'xshash mashq videolari (spec 43).
- Dam olish taymeri, "Bajardim" bosilgach boshlanadi (spec 12, 18).
- Yurak urishini kamera orqali o'lchash (spec 49, `hr_camera.dart`).
- Mashg'ulotdan keyin 1-tap fikr: "Oson / To'g'ri / Qiyin", trener ko'radi (spec 14).

### 6.6 O'yin tizimi (gamifikatsiya)
- Kamera orqali sanalgan takrorlar uchun coin, XP, daraja (`coin_ledger`, `rep_sessions`).
- Zal reytingi, davrlar (kunlik/haftalik) va ko'rinish sozlamasi (spec 19, 53, migratsiya 0014).
- Yutuqlar va challenge'lar (`user_challenges`, hex nishonlar, spec 54, 56).
- O'yin do'koni (spec 50), o'yinni yoqish/o'chirish bayrog'i (migratsiya 0020).

### 6.7 Zal e'lonlari
- Admin e'lon yaratadi, mijozlar ilovada banner ko'radi (spec 15).

### 6.8 Trener va tana xaritasi
- Trener shogird rejasini moslashtiradi, fikrlarni ko'radi (spec 14).
- Tana xaritasi (MusclesScreen) — mushak guruhlari bo'yicha mashg'ulot ko'rinishi (spec 60, 61).
- Admin "Mashqlar" sahifasi qayta dizayni (spec 40).

### 6.9 Ilova va UI
- Mavzular: graphite va qo'shimcha mavzular (Kiber Zumrad, Tungi Oltin), mavzu tanlash varag'i (spec 31, 33, 35).
- Tarjima: uz, ru, en; tarjima sifati bo'yicha alohida ishlar (spec 47, 57).
- Startup chidamliligi: APK ochilganda yopilib qolmasligi (spec 34).
- Profil ixtiyoriy maydonlari (spec 52).

### 6.10 To'lov (oxirgi bosqich)
- Obuna ilova ichidan Payme yoki Click orqali sotib olinadi (spec 59, `payment_orders`, `payments.py`).
- Webhook'lar `payme.py` va `click.py` da, to'lov natijasi `payment_orders` holatida saqlanadi.

## 7. Spec-driven ish tartibi

- Har bir o'zgarish avval `specs/` ichidagi spec fayl bilan boshlanadi (`NN-nom.md`).
- Spec tuzilmasi: Goal, Constraints, Boundaries (Always / Ask first / Never), Out of scope, Files, Ma'lumotlar modeli, Endpointlar, Open questions.
- `specs/` mahalliy, git'ga kirmaydi (`.git/info/exclude`).
- Spec 01 dan boshlab har bir bosqichda `firestore.rules` va `tools/rules_test/test.mjs` dagi holatlar pytest'ga aylantiriladi.

## 8. Test va sifat

- Backend: pytest (`asyncio_mode = auto`, session loop scope), testlar `tests/` da; har bir endpoint uchun ruxsat testi.
- Testlar lokal Postgres (yoki Garage) bilan ishlaydi; `conftest.py` har testdan oldin jadvallarni `TRUNCATE` qiladi.
- Lint: `ruff check` (E, F, I, UP, B, ASYNC).
- Mobil: `flutter_test`, `flutter_lints`; UI kontrast hisobotlari (`test: 4 mavzu uchun kontrast hisoboti`).
- Deploy oldidan: `alembic upgrade head` migrate servisi orqali, `/health` tekshiruvi.

## 9. Ma'lum cheklovlar va ochiq savollar

- Videolar hozircha YouTube havolasi (yopiq video yo'q).
- Rejadan o'chirilganda foydalanuvchilarni qayta belgilash ochiq savol (spec 02).
- `ratings` (trener baholari) faqat owner uchun, alohida bandda.
- Ish daraxtida commit qilinmagan o'zgarishlar bor (ko'p `src/ui/lib/...` fayllari). Bu hujjat commit'lar va spec'lar asosida yozilgan.
