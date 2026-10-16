// Do'kon tovarlariga ustama foiz qo'shadi (narxni oshiradi), tan narxni (costPrice) saqlaydi.
// Ishga tushirish: node tools/dokon/narx_ustama.mjs <foiz>   (masalan: 20 -> narx 20% oshadi)
//
// Qayta ishga tushirish xavfsiz: costPrice allaqachon bor bo'lsa, yangi narx undan qayta
// hisoblanadi (joriy narxdan emas) — shuning uchun ikki marta ustama qo'shilib ketmaydi.
import { readFileSync } from 'node:fs';
import { setDefaultResultOrder } from 'node:dns';
import { maxfiy } from '../maxfiy.mjs';
setDefaultResultOrder('ipv4first');

const PROJECT = 'kotta-qani-09111753';
const OWNER_EMAIL = maxfiy('OWNER_EMAIL');
const OWNER_PASS = maxfiy('OWNER_PASS');

const root = new URL('../..', import.meta.url);
const key = readFileSync(new URL('lib/firebase_options.dart', root), 'utf8')
  .match(/apiKey: '([^']+)'/)[1];

const pct = Number(process.argv[2]);
if (!Number.isFinite(pct) || pct <= 0) {
  console.error('Foydalanish: node tools/dokon/narx_ustama.mjs <foiz>   (masalan: 20)');
  process.exit(1);
}

const s = await fetch(
  `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${key}`,
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: OWNER_EMAIL, password: OWNER_PASS, returnSecureToken: true }),
  },
).then((r) => r.json());
if (!s.idToken) throw new Error('kirib bolmadi: ' + JSON.stringify(s.error));

const base = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const auth = { Authorization: `Bearer ${s.idToken}`, 'Content-Type': 'application/json' };

const num = (f) => (f == null ? 0 : Number(f.integerValue ?? f.doubleValue ?? 0));
const val = (v) => (Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v });

const bor = await fetch(`${base}/shop?pageSize=300`, { headers: auth }).then((x) => x.json());

let n = 0;
for (const d of bor.documents ?? []) {
  const id = d.name.split('/').pop();
  const name = d.fields?.name?.stringValue ?? id;
  const price = num(d.fields?.price);
  // birinchi marta ishga tushirilganda — joriy narx tan narx bo'lib saqlanadi
  const costPrice = num(d.fields?.costPrice) || price;
  const newPrice = Math.round(costPrice * (1 + pct / 100));
  const fields = { costPrice: val(costPrice), price: val(newPrice) };
  const url =
    `${base}/shop/${id}?` + Object.keys(fields).map((k) => `updateMask.fieldPaths=${k}`).join('&');
  const r = await fetch(url, { method: 'PATCH', headers: auth, body: JSON.stringify({ fields }) })
    .then((x) => x.json());
  if (r.error) {
    console.error('XATO:', name, r.error.message);
  } else {
    console.log(name, '| tan narx:', costPrice, '-> narx:', newPrice);
    n++;
  }
}
console.log(`\nJami ${n} ta tovar yangilandi (+${pct}%).`);
