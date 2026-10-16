// Do'konga tovar qo'shish (bosh admin nomidan).
// Ishga tushirish: node tools/dokon/tovar_qoshish.mjs <fayl.json>
// Nomi bir xil tovar bazada bor bo'lsa — yangilanadi (nusxa yaratilmaydi).
// JSON: { "category": "Forma", "name": "...", "note": "...", "price": 35,
//         "currency": "USD", "stock": 10, "active": true,
//         "sizes": ["XL"], "colors": ["qora"], "image": "https://...", "images": ["https://..."] }
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

const file = process.argv[2];
if (!file) {
  console.error('Foydalanish: node tools/dokon/tovar_qoshish.mjs <fayl.json>');
  process.exit(1);
}
const items = JSON.parse(readFileSync(file, 'utf8'));
const list = Array.isArray(items) ? items : [items];

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

/** JS qiymatini Firestore ko'rinishiga o'giradi */
const val = (v) => {
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (Number.isInteger(v)) return { integerValue: String(v) };
  if (typeof v === 'number') return { doubleValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(val) } };
  throw new Error('nomalum tur: ' + JSON.stringify(v));
};

// mavjud tovarlar — nomi bir xil bo'lsa yangilanadi, yangi yozuv yaratilmaydi
const bor = await fetch(`${base}/shop?pageSize=300`, { headers: auth }).then((x) => x.json());
const byName = new Map(
  (bor.documents ?? []).map((d) => [d.fields?.name?.stringValue ?? '', d.name.split('/').pop()]),
);

for (const p of list) {
  const doc = {
    category: p.category ?? 'Forma',
    name: p.name,
    note: p.note ?? '',
    image: p.image ?? '',
    images: p.images ?? [],
    sizes: p.sizes ?? [],
    price: p.price ?? 0,
    currency: p.currency ?? 'UZS',
    stock: p.stock ?? 0,
    active: p.active ?? true,
  };
  const fields = Object.fromEntries(Object.entries(doc).map(([k, v]) => [k, val(v)]));
  const id = byName.get(doc.name);
  if (p.colors) {
    doc.colors = p.colors;
    fields.colors = val(p.colors);
  }
  // Yangi o'lchamli tovar: umumiy qoldiq o'lchamlarga teng bo'linadi. Usiz ilova tovarni
  // "Tugagan" deb ko'rsatadi (jami qoldiq = sizeStock yig'indisi). Mavjud tovarda
  // qo'lda kiritilgan o'lcham qoldig'iga tegilmaydi.
  if (!id && doc.sizes.length) {
    const n = doc.sizes.length;
    doc.sizeStock = true; // updateMask/kalit ro'yxati uchun
    fields.sizeStock = { mapValue: { fields: Object.fromEntries(doc.sizes.map((sz, i) =>
      [sz, { integerValue: String(Math.floor(doc.stock / n) + (i < doc.stock % n ? 1 : 0)) }])) } };
  }
  const url = id
    ? `${base}/shop/${id}?` + Object.keys(doc).map((k) => `updateMask.fieldPaths=${k}`).join('&')
    : `${base}/shop`;
  const r = await fetch(url, {
    method: id ? 'PATCH' : 'POST',
    headers: auth,
    body: JSON.stringify({ fields }),
  }).then((x) => x.json());
  if (r.error) {
    console.error('XATO:', doc.name, r.error.message);
  } else {
    console.log(id ? 'yangilandi:' : 'qoshildi:', doc.name, '|', doc.price, doc.currency,
      '| qoldiq:', doc.stock, '|', doc.sizes.join(', '), '|', doc.images.length + 1, 'rasm');
  }
}
