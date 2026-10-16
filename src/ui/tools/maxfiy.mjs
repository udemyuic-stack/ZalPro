// Maxfiy qiymatlarni (parol, email) `.env` faylidan o'qiydi — ular kodda saqlanmaydi,
// shuning uchun git'ga va GitHub'ga tushmaydi.
//
// Birinchi marta ishlatishdan oldin loyiha ildizida `.env` yaratish kerak:
//   copy .env.namuna .env
// so'ng `.env` ichidagi qiymatlarni to'ldirish. `.env` `.gitignore` da — hech qachon
// commit qilinmaydi.
import { readFileSync, existsSync } from 'node:fs';

const fayl = new URL('../.env', import.meta.url);

/** `.env` faylini kalit=qiymat juftliklariga o'giradi. Fayl bo'lmasa — bo'sh. */
function faylniOqi() {
  if (!existsSync(fayl)) return {};
  const juftliklar = {};
  for (const qator of readFileSync(fayl, 'utf8').split(/\r?\n/)) {
    const t = qator.trim();
    if (!t || t.startsWith('#')) continue;
    const tenglik = t.indexOf('=');
    if (tenglik < 0) continue;
    const kalit = t.slice(0, tenglik).trim();
    const qiymat = t.slice(tenglik + 1).trim().replace(/^["']|["']$/g, '');
    juftliklar[kalit] = qiymat;
  }
  return juftliklar;
}

// Muhit o'zgaruvchisi `.env` dan ustun turadi (CI yoki bir martalik ishga tushirish uchun).
const qiymatlar = { ...faylniOqi(), ...process.env };

/**
 * Maxfiy qiymatni qaytaradi. Topilmasa — tushunarli xato bilan to'xtaydi,
 * chunki parolsiz skript baribir ishlamaydi.
 */
export function maxfiy(kalit) {
  const qiymat = qiymatlar[kalit];
  if (!qiymat) {
    console.error(
      `XATO: "${kalit}" topilmadi.\n\n` +
        `Loyiha ildizida .env fayli kerak. Namunadan nusxa oling va to'ldiring:\n` +
        `    copy .env.namuna .env\n\n` +
        `Yoki bir martaga muhit o'zgaruvchisi bilan bering:\n` +
        `    set ${kalit}=...`,
    );
    process.exit(1);
  }
  return qiymat;
}
