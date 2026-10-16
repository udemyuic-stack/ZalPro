// Vaqtinchalik SINOV shogirdi — ekranlarni brauzerda ko'rib tekshirish uchun (shogird akkaunti
// paroli bizda yo'q). Haqiqiy bazada yaratiladi, ish tugagach ALBATTA o'chiriladi.
//
//   node tools/sinov/shogird.mjs yarat   — akkaunt ochadi; rejali mavjud shogirdning anketa
//                                           maydonlarini (ism va telefonsiz) nusxalaydi
//   node tools/sinov/shogird.mjs parol   — kirish paroli (telefon: 900000099)
//   node tools/sinov/shogird.mjs ochir   — hujjat, ichki yozuvlar va kirish akkauntini o'chiradi
//
// Parol va uid tizimning vaqtinchalik papkasida turadi (repoga tushmaydi).
import { readFileSync, writeFileSync, existsSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setDefaultResultOrder } from 'node:dns';
import { maxfiy } from '../maxfiy.mjs';
setDefaultResultOrder('ipv4first');

const PROJECT = 'kotta-qani-09111753';
const STATE = join(tmpdir(), 'qobil-sinov-shogird.json');
const PHONE = '998900000099';
const EMAIL = `${PHONE}@phone.kottaqani.uz`;
const key = readFileSync(new URL('../../lib/firebase_options.dart', import.meta.url), 'utf8')
  .match(/apiKey: '([^']+)'/)[1];
const idt = (path, body) =>
  fetch(`https://identitytoolkit.googleapis.com/v1/accounts:${path}?key=${key}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
  }).then((r) => r.json());
const base = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const H = (t) => ({ Authorization: `Bearer ${t}`, 'Content-Type': 'application/json' });

const cmd = process.argv[2];
if (cmd === 'parol') {
  console.log(JSON.parse(readFileSync(STATE, 'utf8')).pass);
  process.exit(0);
}
const owner = await idt('signInWithPassword', {
  email: maxfiy('OWNER_EMAIL'), password: maxfiy('OWNER_PASS'), returnSecureToken: true,
});
if (!owner.idToken) throw new Error('bosh admin kira olmadi');

if (cmd === 'yarat') {
  const pass = 'sinov' + Math.random().toString(36).slice(2, 10);
  const u = await idt('signUp', { email: EMAIL, password: pass, returnSecureToken: true });
  if (!u.idToken) throw new Error('yaratilmadi: ' + JSON.stringify(u.error));
  writeFileSync(STATE, JSON.stringify({ uid: u.localId, pass }));
  let r = await fetch(`${base}/users?documentId=${u.localId}`, {
    method: 'POST', headers: H(u.idToken),
    body: JSON.stringify({ fields: {
      name: { stringValue: 'SINOV (ochiriladi)' }, role: { stringValue: 'user' }, phone: { stringValue: PHONE },
    } }),
  }).then((x) => x.json());
  if (r.error) throw new Error('hujjat: ' + r.error.message);
  const all = await fetch(`${base}/users?pageSize=300`, { headers: H(owner.idToken) }).then((x) => x.json());
  const src = (all.documents ?? []).find(
    (d) => d.fields?.role?.stringValue === 'user' && d.fields?.planId?.stringValue);
  const take = ['goal', 'gender', 'age', 'height', 'weight', 'metabolism', 'planId', 'planAssignedAt',
    'trainerId', 'gymDays', 'lastWeighIn'];
  const fields = {};
  for (const k of take) if (src?.fields?.[k]) fields[k] = src.fields[k];
  const mask = Object.keys(fields).map((k) => 'updateMask.fieldPaths=' + k).join('&');
  r = await fetch(`${base}/users/${u.localId}?${mask}`, {
    method: 'PATCH', headers: H(owner.idToken), body: JSON.stringify({ fields }),
  }).then((x) => x.json());
  if (r.error) throw new Error('anketa: ' + r.error.message);
  console.log('yaratildi; maydonlar:', Object.keys(fields).join(', '));
} else if (cmd === 'ochir') {
  if (!existsSync(STATE)) throw new Error('holat fayli yoq — akkaunt yaratilmagan yoki allaqachon ochirilgan');
  const st = JSON.parse(readFileSync(STATE, 'utf8'));
  const u = await idt('signInWithPassword', { email: EMAIL, password: st.pass, returnSecureToken: true });
  // ichki to'plamlardagi yozuvlar (kun, vazn, rasm ...) — shogirdning o'zi yoki bosh admin o'chiradi
  for (const sub of ['days', 'weights', 'photos', 'attendance', 'subscriptions']) {
    const l = await fetch(`${base}/users/${st.uid}/${sub}?pageSize=100`, { headers: H(owner.idToken) })
      .then((x) => x.json());
    for (const d of l.documents ?? []) {
      const path = d.name.split('/documents/')[1];
      let del = await fetch(`${base}/${path}`, { method: 'DELETE', headers: H(u.idToken ?? owner.idToken) });
      if (del.status !== 200) del = await fetch(`${base}/${path}`, { method: 'DELETE', headers: H(owner.idToken) });
      console.log('  ', sub, d.name.split('/').pop(), del.status === 200 ? 'ochirildi' : 'QOLDI (' + del.status + ')');
    }
  }
  let r = await fetch(`${base}/users/${st.uid}`, { method: 'DELETE', headers: H(owner.idToken) });
  console.log('hujjat ochirildi:', r.status);
  await fetch(`${base}/memberships/${st.uid}`, { method: 'DELETE', headers: H(owner.idToken) });
  if (u.idToken) {
    const d = await idt('delete', { idToken: u.idToken });
    console.log('kirish akkaunti ochirildi:', !d.error);
  }
  const chk = await fetch(`${base}/users/${st.uid}`, { headers: H(owner.idToken) });
  console.log('tekshiruv (404 kutiladi):', chk.status);
  unlinkSync(STATE);
} else {
  console.log('yarat | parol | ochir');
}
