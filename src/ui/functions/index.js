// Diamond — push bildirishnomalar (ilova yopiq bo'lsa ham keladi).
// Joylash uchun Firebase loyihasi Blaze tarifida bo'lishi kerak: FUNKSIYALAR_JOYLASH.bat
//
//  * chats/{uid}/messages/{id} yaratilganda:
//      - shogird yozgan bo'lsa → uning treneriga
//      - trener (yoki bosh admin) yozgan bo'lsa → shogirdga
//  * users/{uid}.planId o'zgarganda (yangi reja) → shogirdga
//
// Token: users/{uid}.fcmTokens (ilova kirganda yozadi). Yaroqsiz tokenlar o'chiriladi.
// Bildirishnoma `tag` i ilovadagi lokal bildirishnoma bilan bir xil — ikki marta chiqmaydi.
const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();
const REGION = 'europe-west1'; // Firestore eur3 ga yaqin

async function tokensOf(uid) {
  if (!uid) return [];
  const snap = await db.collection('users').doc(uid).get();
  return (snap.exists && Array.isArray(snap.get('fcmTokens'))) ? snap.get('fcmTokens') : [];
}

async function send(uid, tag, title, body) {
  const tokens = await tokensOf(uid);
  if (tokens.length === 0) return;
  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    android: {
      priority: 'high',
      notification: { channelId: 'diamond_general', tag },
    },
  });
  const bad = [];
  res.responses.forEach((r, i) => {
    const code = r.error && r.error.code;
    if (code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token') {
      bad.push(tokens[i]);
    }
  });
  if (bad.length) {
    await db.collection('users').doc(uid)
      .update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...bad) });
  }
}

const short = (s, n = 120) => (s && s.length > n ? s.slice(0, n - 1) + '…' : s || '');

exports.onChatMessage = functions.region(REGION).firestore
  .document('chats/{uid}/messages/{msgId}')
  .onCreate(async (snap, ctx) => {
    const { uid, msgId } = ctx.params;
    const msg = snap.data() || {};
    const student = await db.collection('users').doc(uid).get();
    if (!student.exists) return;
    const tag = `msg-${msgId}`;
    if (msg.senderId === uid) {
      // shogird yozdi → treneriga
      const trainerId = student.get('trainerId');
      await send(trainerId, tag, student.get('name') || 'Shogird', short(msg.text));
    } else {
      // trener / bosh admin yozdi → shogirdga
      await send(uid, tag, 'Treneringizdan xabar', short(msg.text));
    }
  });

exports.onPlanAssigned = functions.region(REGION).firestore
  .document('users/{uid}')
  .onUpdate(async (change, ctx) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    if (!after.planId || before.planId === after.planId) return;
    await send(ctx.params.uid, `plan-${after.planId}`, 'Yangi reja biriktirildi',
      "Trener sizga ovqatlanish rejasini berdi — 'Bugun' bo'limida ko'ring");
  });
