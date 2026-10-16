// Do'kon tovarlaridan ustamani olib tashlaydi: narx (`price`) tan narxga (`costPrice`)
// tenglashtiriladi. Tan narx o'zgarmaydi — keyin `narx_ustama.mjs <foiz>` bilan ustamani
// qaytarsa bo'ladi. Tan narxi yozilmagan (0) tovarga tegilmaydi.
// Zal egasi qarori (13-okt): "narx ustiga qo'yma, hozircha o'sha narxda qolsin".
// Faqat `price` maydoniga tegadi. Qayta ishga tushirish xavfsiz.
//   node tools/dokon/ustama_olish.mjs korish   (faqat ko'rsatadi)
//   node tools/dokon/ustama_olish.mjs          (yozadi)
import { readFileSync } from 'node:fs';
import { setDefaultResultOrder } from 'node:dns';
import { maxfiy } from '../maxfiy.mjs';
setDefaultResultOrder('ipv4first');

const PROJECT = 'kotta-qani-09111753';
const key = readFileSync(new URL('../../lib/firebase_options.dart', import.meta.url), 'utf8')
  .match(/apiKey: '([^']+)'/)[1];
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

const num = (f) => Number(f?.integerValue ?? f?.doubleValue ?? 0);
let yozildi = 0, teng = 0, tansiz = 0, namuna = 0;
for (const d of docs) {
  const f = d.fields ?? {};
  const narx = num(f.price), tan = num(f.costPrice);
  if (tan <= 0) { tansiz++; continue; }
  if (narx === tan) { teng++; continue; }
  if (namuna++ < 5) console.log(`  ${f.name?.stringValue}: ${narx} -> ${tan}`);
  if (faqatKorish) { yozildi++; continue; }
  // narx bazada qanday turda bo'lsa (butun yoki kasr), shu turda yoziladi
  const qiymat = f.price?.doubleValue !== undefined ? { doubleValue: tan } : { integerValue: String(tan) };
  const r = await fetch(
    `${base}/shop/${d.name.split('/').pop()}?updateMask.fieldPaths=price&currentDocument.exists=true`,
    { method: 'PATCH', headers: auth, body: JSON.stringify({ fields: { price: qiymat } }) },
  ).then((x) => x.json());
  if (r.error) console.log('XATO', f.name?.stringValue, r.error.message); else yozildi++;
}
console.log(`tovar: ${docs.length} | ${faqatKorish ? 'ozgaradi' : 'ozgardi'}: ${yozildi} | ustamasiz edi: ${teng} | tan narxi yoq: ${tansiz}`);
