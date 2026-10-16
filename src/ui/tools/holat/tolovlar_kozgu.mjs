// To'lov ko'zgusini (`memberships/{uid}`) mavjud abonementlardan to'ldiradi — bir martalik
// to'g'rilash (eski APK qo'shgan yoki qo'lda yozilgan abonementlar uchun). Ilova yangi
// abonementda ko'zguni o'zi yozadi (`Db.addSubscription`).
// Ishga tushirish: node tools/holat/tolovlar_kozgu.mjs
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
const db = `projects/${PROJECT}/databases/(default)/documents`;
const base = `https://firestore.googleapis.com/v1/${db}`;
const auth = { Authorization: `Bearer ${s.idToken}`, 'Content-Type': 'application/json' };

const users = (await fetch(`${base}/users?pageSize=300`, { headers: auth }).then((x) => x.json()))
  .documents ?? [];
const gymOf = Object.fromEntries(
  users.map((d) => [d.name.split('/').pop(), d.fields?.gymId?.stringValue ?? '']),
);

let n = 0;
for (const u of users) {
  if (u.fields?.role?.stringValue !== 'user') continue;
  const uid = u.name.split('/').pop();
  const exp = u.fields?.subscriptionExpiresAt?.timestampValue;
  const subs = (await fetch(`${base}/users/${uid}/subscriptions`, { headers: auth })
    .then((x) => x.json())).documents ?? [];
  if (!subs.length || !exp) continue;
  // eng yangisi — boshlanish sanasi bo'yicha
  subs.sort((a, b) => (b.fields.startDate?.timestampValue ?? '')
    .localeCompare(a.fields.startDate?.timestampValue ?? ''));
  const f = subs[0].fields;
  const tid = u.fields?.trainerId?.stringValue ?? '';
  const r = await fetch(`https://firestore.googleapis.com/v1/${db}:commit`, {
    method: 'POST', headers: auth,
    body: JSON.stringify({
      writes: [{
        update: {
          name: `${db}/memberships/${uid}`,
          fields: {
            name: { stringValue: u.fields?.name?.stringValue ?? '' },
            gymId: { stringValue: tid ? (gymOf[tid] ?? '') : '' },
            months: { integerValue: f.months?.integerValue ?? '0' },
            days: { integerValue: f.days?.integerValue ?? '0' },
            price: { integerValue: f.price?.integerValue ?? '0' },
            currency: { stringValue: f.currency?.stringValue ?? 'UZS' },
            paidDate: { timestampValue: f.paidDate?.timestampValue ?? f.startDate.timestampValue },
            expiresAt: { timestampValue: exp },
          },
        },
        updateTransforms: [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }],
      }],
    }),
  }).then((x) => x.json());
  n++;
  console.log(uid.slice(0, 6) + '…', r.error ? 'XATO: ' + r.error.message : 'OK');
}
console.log(`jami: ${n}`);
