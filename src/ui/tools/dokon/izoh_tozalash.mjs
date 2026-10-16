// Do'kon tovarlari izohidan (`note`) ICHKI eslatmani olib tashlaydi — u mijozga ko'rinardi:
//   "… Narx AllPituz kanalidan (24-sent)."            → olib tashlanadi
//   "… Narx AllPituz kanalidan (…) - hozirgi narxni tekshiring."
//   "… Rasm AllPituz kanalidan, narx internetdan (…) - tekshiring."
// Tovarning haqiqiy tavsifi (ishlab chiqaruvchi, porsiya, o'lcham) qoladi.
// Uch joyni birga tozalaydi, aks holda tarjima uzilib qoladi:
//   1) bazadagi `shop` hujjatlari — faqat `note` maydoni (narx, qoldiq, tarjima tegilmaydi);
//   2) tools/dokon/*.json manba fayllari;
//   3) tools/dokon/tovar-tarjima.json `izohlar` kalitlari (kalit — o'zbekcha izohning o'zi;
//      tozalanmasa `tarjima_yozish.mjs` keyingi safar ruscha/inglizcha izohni o'chirib yuboradi).
// Qayta ishga tushirish xavfsiz (toza izoh o'zgarmaydi).
//   node tools/dokon/izoh_tozalash.mjs korish   (faqat ko'rsatadi, hech narsa yozmaydi)
//   node tools/dokon/izoh_tozalash.mjs          (yozadi)
import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { setDefaultResultOrder } from 'node:dns';
import { maxfiy } from '../maxfiy.mjs';
setDefaultResultOrder('ipv4first');

/// Ichki eslatma jumlasi: "Narx/Rasm AllPituz kanalidan …" — keyingi nuqtagacha (qavs
/// ichidagi "mihome.uz" kabi nuqtalar bilan birga) va oxirigacha
export const toza = (izoh) =>
  izoh.replace(/\s*(Narx|Rasm) AllPituz kanalidan.*$/s, '').trim();

const faqatKorish = process.argv[2] === 'korish';
const dir = new URL('./', import.meta.url);

// --- 2) manba fayllar va 3) tarjima kalitlari
let fayl = 0;
for (const nom of readdirSync(dir).filter((n) => n.endsWith('.json'))) {
  const yol = new URL(nom, dir);
  const asl = readFileSync(yol, 'utf8');
  const data = JSON.parse(asl);
  let ozgardi = false;
  if (nom === 'tovar-tarjima.json') {
    const yangi = {};
    for (const [k, v] of Object.entries(data.izohlar ?? {})) {
      const t = toza(k);
      if (t !== k) ozgardi = true;
      // tozalangach bo'sh qolgan izohning tarjimasi ham kerak emas
      if (t) yangi[t] = v;
    }
    data.izohlar = yangi;
  } else {
    const yur = (x) => {
      if (Array.isArray(x)) return x.forEach(yur);
      if (x && typeof x === 'object') {
        if (typeof x.note === 'string' && toza(x.note) !== x.note) {
          x.note = toza(x.note);
          ozgardi = true;
        }
        Object.values(x).forEach(yur);
      }
    };
    yur(data);
  }
  if (!ozgardi) continue;
  fayl++;
  if (!faqatKorish) writeFileSync(yol, JSON.stringify(data, null, 2) + '\n');
}
console.log(`manba fayl: ${faqatKorish ? 'ozgaradi' : 'ozgardi'}: ${fayl}`);

// --- 1) baza
const PROJECT = 'kotta-qani-09111753';
const key = readFileSync(new URL('../../lib/firebase_options.dart', import.meta.url), 'utf8')
  .match(/apiKey: '([^']+)'/)[1];
const s = await fetch(
  `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${key}`,
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: maxfiy('OWNER_EMAIL'), password: maxfiy('OWNER_PASS'), returnSecureToken: true,
    }),
  },
).then((r) => r.json());
if (!s.idToken) throw new Error('kirib bolmadi: ' + JSON.stringify(s.error));
const base = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const auth = { Authorization: `Bearer ${s.idToken}`, 'Content-Type': 'application/json' };

let docs = [], tok = '';
do {
  const r = await fetch(`${base}/shop?pageSize=300${tok ? '&pageToken=' + tok : ''}`, { headers: auth })
    .then((x) => x.json());
  docs.push(...(r.documents ?? []));
  tok = r.nextPageToken ?? '';
} while (tok);

let yozildi = 0, toza_edi = 0, namuna = 0;
for (const d of docs) {
  const eski = d.fields?.note?.stringValue ?? '';
  const yangi = toza(eski);
  if (yangi === eski) { toza_edi++; continue; }
  if (namuna++ < 4) console.log(`  "${eski}"\n   -> "${yangi}"`);
  if (faqatKorish) { yozildi++; continue; }
  const r = await fetch(
    `${base}/shop/${d.name.split('/').pop()}?updateMask.fieldPaths=note&currentDocument.exists=true`,
    { method: 'PATCH', headers: auth, body: JSON.stringify({ fields: { note: { stringValue: yangi } } }) },
  ).then((x) => x.json());
  if (r.error) console.log('XATO', d.fields?.name?.stringValue, r.error.message); else yozildi++;
}
console.log(`tovar: ${docs.length} | ${faqatKorish ? 'tozalanadi' : 'tozalandi'}: ${yozildi} | toza edi: ${toza_edi}`);
