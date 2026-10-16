// Do'kon tovarlariga ruscha va inglizcha nom/izohni yozadi (`nameRu`, `nameEn`, `noteRu`,
// `noteEn`). Manba: tools/dokon/tovar-tarjima.json — kalit tovarning o'zbekcha nomi / izohi.
// Faqat shu to'rt maydonga tegadi; nom, narx, qoldiq o'zgarmaydi. Qayta ishga tushirish xavfsiz.
// Ishga tushirish: node tools/dokon/tarjima_yozish.mjs        (yozadi)
//                  node tools/dokon/tarjima_yozish.mjs korish (faqat ko'rsatadi)
import { readFileSync } from 'node:fs';
import { setDefaultResultOrder } from 'node:dns';
import { maxfiy } from '../maxfiy.mjs';
setDefaultResultOrder('ipv4first');

const PROJECT = 'kotta-qani-09111753';
const key = readFileSync(new URL('../../lib/firebase_options.dart', import.meta.url), 'utf8')
  .match(/apiKey: '([^']+)'/)[1];
const tarjima = JSON.parse(readFileSync(new URL('./tovar-tarjima.json', import.meta.url), 'utf8'));
const faqatKorish = process.argv[2] === 'korish';

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

const maydonlar = ['nameRu', 'nameEn', 'noteRu', 'noteEn'];
let yozildi = 0, ozgarmadi = 0, tarjimasiz = 0;
for (const d of docs) {
  const f = d.fields ?? {};
  const nom = tarjima.nomlar[f.name?.stringValue ?? ''];
  const izoh = tarjima.izohlar[f.note?.stringValue ?? ''];
  const yangi = {
    nameRu: nom?.ru ?? '', nameEn: nom?.en ?? '', noteRu: izoh?.ru ?? '', noteEn: izoh?.en ?? '',
  };
  if (!nom && !izoh) { tarjimasiz++; continue; }
  if (maydonlar.every((m) => (f[m]?.stringValue ?? '') === yangi[m])) { ozgarmadi++; continue; }
  if (faqatKorish) { console.log(f.name?.stringValue, '->', yangi.nameRu || '(nom ozgarmaydi)'); yozildi++; continue; }
  const mask = maydonlar.map((m) => 'updateMask.fieldPaths=' + m).join('&');
  const r = await fetch(`${base}/shop/${d.name.split('/').pop()}?${mask}&currentDocument.exists=true`, {
    method: 'PATCH', headers: auth,
    body: JSON.stringify({ fields: Object.fromEntries(maydonlar.map((m) => [m, { stringValue: yangi[m] }])) }),
  }).then((x) => x.json());
  if (r.error) console.log('XATO', f.name?.stringValue, r.error.message); else yozildi++;
}
console.log(`tovar: ${docs.length} | ${faqatKorish ? 'yoziladi' : 'yozildi'}: ${yozildi} | ozgarmadi: ${ozgarmadi} | tarjimasi yoq: ${tarjimasiz}`);
