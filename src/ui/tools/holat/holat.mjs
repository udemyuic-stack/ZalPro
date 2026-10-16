// Bazaning hozirgi holati: foydalanuvchilar, zallar, rejalar, do'kon, buyurtmalar.
// Ishga tushirish: node tools/holat/holat.mjs
// Bosh admin nomidan o'qiydi (faqat ko'rsatadi, hech narsa o'zgartirmaydi).
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
const auth = { Authorization: `Bearer ${s.idToken}` };
const get = async (path) =>
  (await fetch(`${base}/${path}?pageSize=200`, { headers: auth }).then((r) => r.json()))
    .documents ?? [];
const f = (d, k) => d.fields?.[k]?.stringValue ?? '';

const users = await get('users');
const gyms = await get('gyms');
const gymName = (id) =>
  gyms.filter((g) => g.name.endsWith('/' + id)).map((g) => f(g, 'name'))[0] ?? '—';

console.log('--- ZALLAR ---');
for (const g of gyms) {
  console.log(` ${f(g, 'name')} | ${f(g, 'district')} ${f(g, 'region')} | ${f(g, 'address')}`);
}

console.log('--- XODIMLAR ---');
for (const d of users.filter((d) => f(d, 'role') !== 'user')) {
  console.log(` ${f(d, 'role').padEnd(6)} | ${f(d, 'name')} | ${f(d, 'phone')}`,
    `| zal: ${gymName(f(d, 'gymId'))}`);
}

console.log('--- SHOGIRDLAR ---');
for (const d of users.filter((d) => f(d, 'role') === 'user')) {
  const id = d.name.split('/').pop();
  const trainer = users.find((u) => u.name.endsWith('/' + f(d, 'trainerId')));
  console.log(` ${f(d, 'name').padEnd(14)} | ${f(d, 'phone')} |`,
    `reja: ${f(d, 'planId') ? 'bor' : "yo'q"} | trener: ${trainer ? f(trainer, 'name') : '—'}`,
    `| id: ${id.slice(0, 6)}`);
}

for (const [label, path] of [['REJALAR', 'plans'], ['DOKON', 'shop'], ['BUYURTMA', 'orders']]) {
  const docs = await get(path);
  console.log(`--- ${label} --- ${docs.length} ta`);
  for (const d of docs.slice(0, 10)) {
    console.log('  -', f(d, 'title') || f(d, 'name') || f(d, 'productName'));
  }
}
