// Trenerlar katalogiga (`trainers/{id}.gymId`) zal ko'zgusini yozadi — bir martalik
// to'g'rilash. Ilovada bosh admin kirganda `syncTrainerDirectory` ham shuni qiladi.
// Ishga tushirish: node tools/holat/katalog_zal.mjs
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

const users = await fetch(`${base}/users?pageSize=300`, { headers: auth }).then((x) => x.json());
for (const d of users.documents ?? []) {
  if (d.fields?.role?.stringValue !== 'admin') continue;
  const id = d.name.split('/').pop();
  const gymId = d.fields?.gymId?.stringValue ?? '';
  const r = await fetch(`${base}/trainers/${id}?updateMask.fieldPaths=gymId&currentDocument.exists=true`, {
    method: 'PATCH', headers: auth,
    body: JSON.stringify({ fields: { gymId: { stringValue: gymId } } }),
  }).then((x) => x.json());
  console.log(d.fields?.name?.stringValue, '->', gymId || '(zalsiz)', r.error ? 'XATO: ' + r.error.message : 'OK');
}
