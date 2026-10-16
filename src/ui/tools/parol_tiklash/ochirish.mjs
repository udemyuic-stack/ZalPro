// Shogird akkauntini TO'LIQ o'chirish (bosh admin uchun): Firestore ma'lumotlari + kirish akkaunti.
// Ilova ichidan o'chirilganda kirish akkaunti qolib, o'sha raqam bilan qayta ro'yxatdan o'tib
// bo'lmasdi — bu vosita shuni ham tozalaydi.
//   node tools/parol_tiklash/ochirish.mjs <telefon>
// Himoya: bosh admin va trener akkauntlari o'chirilmaydi.
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomBytes } from 'node:crypto';
import bcrypt from 'bcryptjs';

const PROJECT = 'kotta-qani-09111753';
const DOMAIN = 'phone.kottaqani.uz';
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const phoneArg = process.argv[2];
if (!phoneArg) {
  console.error('Foydalanish: node tools/parol_tiklash/ochirish.mjs <telefon>');
  process.exit(1);
}
const digits = phoneArg.replace(/\D/g, '');
const phone = digits.length === 9 ? '998' + digits : digits;
const email = `${phone}@${DOMAIN}`;
const key = readFileSync(join(ROOT, 'lib/firebase_options.dart'), 'utf8').match(/apiKey: '([^']+)'/)[1];

const firebase = (args, okText) => {
  const opts = { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] };
  try {
    return process.platform === 'win32'
      ? execFileSync('cmd.exe', ['/d', '/s', '/c', 'firebase', ...args], opts)
      : execFileSync('firebase', args, opts);
  } catch (e) {
    if (okText && String(e.stdout).includes(okText)) return e.stdout;
    throw e;
  }
};
const post = (method, body) =>
  fetch(`https://identitytoolkit.googleapis.com/v1/accounts:${method}?key=${key}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
  }).then((r) => r.json());

const dir = mkdtempSync(join(tmpdir(), 'diamond-del-'));
try {
  const exp = join(dir, 'e.json');
  firebase(['auth:export', exp, '--format=json', '--project', PROJECT], 'Exported');
  const u = JSON.parse(readFileSync(exp, 'utf8')).users.find((x) => x.email === email);
  if (!u) {
    console.log(`${email} kirish akkaunti yo'q — o'chirishga hojat yo'q.`);
    process.exit(0);
  }

  // Vaqtinchalik parol bilan shu akkaunt nomidan kirib, rolini tekshiramiz va o'chiramiz
  const temp = 'Del-' + randomBytes(12).toString('hex');
  const imp = join(dir, 'i.json');
  writeFileSync(imp, JSON.stringify({ users: [{
    localId: u.localId, email: u.email, emailVerified: false,
    passwordHash: Buffer.from(bcrypt.hashSync(temp, 10)).toString('base64'),
  }] }));
  firebase(['auth:import', imp, '--hash-algo=BCRYPT', '--project', PROJECT], 'Imported successfully');
  const s = await post('signInWithPassword', { email, password: temp, returnSecureToken: true });
  if (!s.idToken) throw new Error('kirib bo\'lmadi: ' + JSON.stringify(s.error));

  const docRes = await fetch(
    `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${u.localId}`,
    { headers: { Authorization: `Bearer ${s.idToken}` } },
  );
  const role = docRes.ok ? (await docRes.json()).fields?.role?.stringValue : undefined;
  if (role === 'owner' || role === 'admin') {
    console.error(`[X] +${phone} — ${role === 'owner' ? 'bosh admin' : 'trener'}. O'chirilmadi.`);
    console.error(`    Uning paroli vaqtincha o'zgardi: ${temp}  — PAROL_TIKLASH.bat bilan yangisini qo'ying.`);
    process.exit(3);
  }

  firebase(['firestore:delete', `users/${u.localId}`, '--recursive', '--force', '--project', PROJECT]);
  firebase(['firestore:delete', `chats/${u.localId}`, '--recursive', '--force', '--project', PROJECT]);
  const d = await post('delete', { idToken: s.idToken });
  if (d.error) throw new Error('kirish akkaunti o\'chmadi: ' + JSON.stringify(d.error));
  console.log(`[OK] +${phone} to'liq o'chirildi (ma'lumotlar va kirish akkaunti).`);
  console.log('     Endi shu raqam bilan qaytadan ro\'yxatdan o\'tish mumkin.');
} finally {
  rmSync(dir, { recursive: true, force: true });
}
