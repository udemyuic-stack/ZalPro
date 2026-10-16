import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, addDoc, collection } from 'firebase/firestore';

const RULES = readFileSync(new URL('../firestore.freeze.rules', import.meta.url), 'utf8');

let pass = 0;
let fail = 0;
async function check(name, fn) {
  try {
    await fn();
    console.log('  OK   ' + name);
    pass++;
  } catch (e) {
    console.log('  XATO ' + name + '\n         ' + String(e.message).split('\n')[0]);
    fail++;
  }
}

const env = await initializeTestEnvironment({
  projectId: 'demo-freeze-test',
  firestore: { rules: RULES, host: '127.0.0.1', port: 8085 },
});

await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/owner1'), { role: 'owner', name: 'Egasi' });
  await setDoc(doc(db, 'users/trainer1'), { role: 'admin' });
  await setDoc(doc(db, 'users/user1'), { role: 'user', trainerId: 'trainer1' });
  await setDoc(doc(db, 'users/user1/subscriptions/s1'), { months: 1 });
  await setDoc(doc(db, 'chats/user1/messages/m1'), { text: 'salom' });
  await setDoc(doc(db, 'products/p1'), { name: 'Suv' });
});

const owner = env.authenticatedContext('owner1').firestore();
const trainer = env.authenticatedContext('trainer1').firestore();
const user = env.authenticatedContext('user1').firestore();
const anon = env.unauthenticatedContext().firestore();

const paths = ['users/user1', 'users/user1/subscriptions/s1', 'chats/user1/messages/m1', 'products/p1'];

for (const path of paths) {
  await check('owner reads ' + path, () => assertSucceeds(getDoc(doc(owner, path))));
  await check('trainer cannot read ' + path, () => assertFails(getDoc(doc(trainer, path))));
  await check('user cannot read ' + path, () => assertFails(getDoc(doc(user, path))));
  await check('anon cannot read ' + path, () => assertFails(getDoc(doc(anon, path))));
}

await check('owner lists users', () => assertSucceeds(getDocs(collection(owner, 'users'))));
await check('owner lists subcollection', () =>
  assertSucceeds(getDocs(collection(owner, 'users/user1/subscriptions'))));
await check('user cannot list users', () => assertFails(getDocs(collection(user, 'users'))));

for (const [label, db] of [['owner', owner], ['trainer', trainer], ['user', user], ['anon', anon]]) {
  await check(label + ' cannot set own user doc', () =>
    assertFails(setDoc(doc(db, 'users/user1'), { role: 'user', name: 'X' })));
  await check(label + ' cannot update user doc', () =>
    assertFails(updateDoc(doc(db, 'users/user1'), { name: 'Y' })));
  await check(label + ' cannot delete user doc', () => assertFails(deleteDoc(doc(db, 'users/user1'))));
  await check(label + ' cannot add message', () =>
    assertFails(addDoc(collection(db, 'chats/user1/messages'), { text: 'x' })));
  await check(label + ' cannot create product', () =>
    assertFails(setDoc(doc(db, 'products/p2'), { name: 'Y' })));
}

await env.cleanup();
console.log(`\n${pass} o'tdi, ${fail} xato`);
process.exit(fail ? 1 : 0);
