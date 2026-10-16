// O'lchamli tovarlarda `sizeStock` (o'lcham bo'yicha qoldiq) bo'lmasa, umumiy `stock` ni
// o'lchamlarga teng bo'lib yozadi. Usiz ilova bunday tovarni "Tugagan" deb ko'rsatadi
// (jami qoldiq = sizeStock yig'indisi). Kiritilgan sizeStock'ga tegilmaydi.
// Ishga tushirish: node tools/dokon/olcham_qoldiq.mjs
import { readFileSync } from 'node:fs';
import { setDefaultResultOrder } from 'node:dns';
import { maxfiy } from '../maxfiy.mjs';
setDefaultResultOrder('ipv4first');

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

/** Umumiy sonni o'lchamlarga teng bo'ladi: 10 ta, 4 o'lcham -> 3, 3, 2, 2 */
export const taqsimla = (jami, sizes) =>
  Object.fromEntries(sizes.map((sz, i) =>
    [sz, Math.floor(jami / sizes.length) + (i < jami % sizes.length ? 1 : 0)]));

const bor = await fetch(`${base}/shop?pageSize=300`, { headers: auth }).then((x) => x.json());
let n = 0;
for (const d of bor.documents ?? []) {
  const f = d.fields ?? {};
  const sizes = (f.sizes?.arrayValue?.values ?? []).map((v) => v.stringValue);
  const has = Object.keys(f.sizeStock?.mapValue?.fields ?? {}).length > 0;
  if (!sizes.length || has) continue;
  const jami = Number(f.stock?.integerValue ?? 0);
  const map = taqsimla(jami, sizes);
  const id = d.name.split('/').pop();
  const r = await fetch(`${base}/shop/${id}?updateMask.fieldPaths=sizeStock`, {
    method: 'PATCH', headers: auth,
    body: JSON.stringify({ fields: { sizeStock: { mapValue: { fields:
      Object.fromEntries(Object.entries(map).map(([k, v]) => [k, { integerValue: String(v) }])) } } } }),
  }).then((x) => x.json());
  console.log(r.error ? 'XATO: ' + r.error.message : 'OK', '|', f.name?.stringValue, '|', jami, '->',
    Object.entries(map).map(([k, v]) => `${k}:${v}`).join(' '));
  n++;
}
console.log(`\n${n} ta tovarga o'lcham bo'yicha qoldiq yozildi.`);
