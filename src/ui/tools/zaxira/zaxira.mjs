// Bazaning to'liq haftalik zaxirasi — barcha kolleksiya va subcollectionlarni
// bitta JSON faylga yozadi (hech narsani o'zgartirmaydi, faqat o'qiydi).
// Ishga tushirish: node tools/zaxira/zaxira.mjs
// Natija: zaxira/YYYY-MM-DD_bazaning-zaxirasi.json (zaxira/ gitignore'da — repo'ga tushmaydi).
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
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
  (await fetch(`${base}/${path}?pageSize=300`, { headers: auth }).then((r) => r.json()))
    .documents ?? [];
const idOf = (d) => d.name.split('/').pop();

console.log('Yuklanmoqda...');

const topLevel = ['users', 'trainers', 'ratings', 'gyms', 'foods', 'plans', 'shop', 'orders',
  'reminders'];
const backup = { exportedAt: new Date().toISOString() };
for (const path of topLevel) {
  backup[path] = await get(path);
  console.log(` ${path}: ${backup[path].length} ta`);
}

// Har bir foydalanuvchining subcollectionlari (vazn, kunlik ovqat, abonement, davomat, chat)
backup.userSubcollections = {};
for (const u of backup.users) {
  const uid = idOf(u);
  const [weights, days, subscriptions, attendance, chatMessages] = await Promise.all([
    get(`users/${uid}/weights`),
    get(`users/${uid}/days`),
    get(`users/${uid}/subscriptions`),
    get(`users/${uid}/attendance`),
    get(`chats/${uid}/messages`),
  ]);
  backup.userSubcollections[uid] = { weights, days, subscriptions, attendance, chatMessages };
}
console.log(` userSubcollections: ${Object.keys(backup.userSubcollections).length} foydalanuvchi`);

mkdirSync(new URL('../../zaxira', import.meta.url), { recursive: true });
const today = new Date().toISOString().slice(0, 10);
const out = new URL(`../../zaxira/${today}_bazaning-zaxirasi.json`, import.meta.url);
writeFileSync(out, JSON.stringify(backup, null, 2));
console.log(`\nSaqlandi: zaxira/${today}_bazaning-zaxirasi.json`);
