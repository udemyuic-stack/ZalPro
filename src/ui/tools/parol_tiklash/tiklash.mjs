// Parolni unutgan foydalanuvchiga yangi parol o'rnatish (bosh admin uchun).
//   node tools/parol_tiklash/tiklash.mjs <telefon> <yangi_parol>
//   masalan: node tools/parol_tiklash/tiklash.mjs 901234567 Yangi123
//
// Qanday ishlaydi: Firebase CLI (bu kompyuterda loyiha egasi akkaunti bilan kirgan) orqali
// akkaunt eksport qilinadi, yangi parolning BCRYPT xeshi bilan shu uid qayta import qilinadi —
// Firebase shu foydalanuvchining parolini almashtiradi. Boshqa akkauntlarga tegilmaydi.
// Vaqtinchalik fayllar (ularda parol xeshlari bor) ish tugashi bilan o'chiriladi.
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import bcrypt from 'bcryptjs';

const PROJECT = 'kotta-qani-09111753';
const DOMAIN = 'phone.kottaqani.uz';

const [phoneArg, newPass] = process.argv.slice(2);
if (!phoneArg || !newPass) {
  console.error('Foydalanish: node tools/parol_tiklash/tiklash.mjs <telefon> <yangi_parol>');
  process.exit(1);
}
if (newPass.length < 6) {
  console.error("[X] Parol kamida 6 belgi bo'lsin");
  process.exit(1);
}
const digits = phoneArg.replace(/\D/g, '');
const phone = digits.length === 9 ? '998' + digits : digits;
const email = `${phone}@${DOMAIN}`;

// Windows'da firebase — .cmd fayl, uni cmd.exe orqali chaqiramiz (argumentlar — faqat
// vaqtinchalik fayl yo'llari va loyiha nomi, foydalanuvchi matni buyruqqa tushmaydi)
// Firebase CLI Windows'da ba'zan ish tugagach libuv xatosi bilan chiqadi (natija esa tayyor) —
// shuning uchun muvaffaqiyat stdout'dagi matndan tekshiriladi
const firebase = (args, okText) => {
  const opts = { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] };
  try {
    return process.platform === 'win32'
      ? execFileSync('cmd.exe', ['/d', '/s', '/c', 'firebase', ...args], opts)
      : execFileSync('firebase', args, opts);
  } catch (e) {
    if (okText && String(e.stdout).includes(okText)) return e.stdout;
    throw e;
  }
};

const dir = mkdtempSync(join(tmpdir(), 'diamond-parol-'));
try {
  const exportFile = join(dir, 'export.json');
  firebase(['auth:export', exportFile, '--format=json', '--project', PROJECT], 'Exported');
  const users = JSON.parse(readFileSync(exportFile, 'utf8')).users ?? [];
  const u = users.find((x) => x.email === email);
  if (!u) {
    console.error(`[X] ${email} topilmadi — telefon raqamni tekshiring`);
    process.exit(2);
  }

  const record = {
    localId: u.localId,
    email: u.email,
    emailVerified: u.emailVerified ?? false,
    passwordHash: Buffer.from(bcrypt.hashSync(newPass, 10)).toString('base64'),
    createdAt: u.createdAt,
    lastSignedInAt: u.lastSignedInAt,
    disabled: u.disabled ?? false,
  };
  const importFile = join(dir, 'import.json');
  writeFileSync(importFile, JSON.stringify({ users: [record] }));
  firebase(['auth:import', importFile, '--hash-algo=BCRYPT', '--project', PROJECT], 'Imported successfully');

  console.log(`[OK] +${phone} uchun yangi parol o'rnatildi. Foydalanuvchi shu parol bilan kirib,`);
  console.log("     Profil → «Parolni o'zgartirish» orqali o'zinikini qo'ysin.");
} finally {
  rmSync(dir, { recursive: true, force: true });
}
