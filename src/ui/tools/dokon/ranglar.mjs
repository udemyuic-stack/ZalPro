// Tovarlarga ranglar ro'yxatini yozadi (shogird buyurtmada rangni tanlaydi).
// Ishga tushirish: node tools/dokon/ranglar.mjs <fayl.json>
// JSON: { "Tovar nomi": ["sariq", "kulrang"], ... } — nom bazadagi bilan aynan bir xil.
// Bo'sh ro'yxat ([]) — rang tanlovini olib tashlaydi.
import { readFileSync } from 'node:fs';
import { setDefaultResultOrder } from 'node:dns';
import { maxfiy } from '../maxfiy.mjs';
setDefaultResultOrder('ipv4first');

const PROJECT = 'kotta-qani-09111753';
const file = process.argv[2];
if (!file) {
  console.error('Foydalanish: node tools/dokon/ranglar.mjs <fayl.json>');
  process.exit(1);
}
const want = JSON.parse(readFileSync(file, 'utf8'));
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

const bor = await fetch(`${base}/shop?pageSize=300`, { headers: auth }).then((x) => x.json());
const byName = new Map(
  (bor.documents ?? []).map((d) => [d.fields?.name?.stringValue ?? '', d.name.split('/').pop()]),
);
for (const [name, colors] of Object.entries(want)) {
  const id = byName.get(name);
  if (!id) { console.error('TOPILMADI:', name); continue; }
  const r = await fetch(`${base}/shop/${id}?updateMask.fieldPaths=colors`, {
    method: 'PATCH', headers: auth,
    body: JSON.stringify({ fields: { colors: { arrayValue: { values: colors.map((c) => ({ stringValue: c })) } } } }),
  }).then((x) => x.json());
  console.log(r.error ? 'XATO: ' + r.error.message : 'OK', '|', name, '->', colors.join(', ') || '(rangsiz)');
}
