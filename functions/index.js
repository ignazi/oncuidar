const admin = require('firebase-admin');
const crypto = require('crypto');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
admin.initializeApp();
const db = admin.firestore();
const master = defineSecret('ONCUIDAR_RECOVERY_MASTER_KEY');
const ref = uid => db.collection('recoveryKeys').doc(uid);
const key = () => { const k = Buffer.from(master.value(), 'base64'); if (k.length !== 32) throw Error('Invalid recovery master key'); return k; };
function seal(data) { const iv=crypto.randomBytes(12); const c=crypto.createCipheriv('aes-256-gcm',key(),iv); const ciphertext=Buffer.concat([c.update(data),c.final()]); return {iv:iv.toString('base64'),tag:c.getAuthTag().toString('base64'),ciphertext:ciphertext.toString('base64')}; }
function open(x) { const d=crypto.createDecipheriv('aes-256-gcm',key(),Buffer.from(x.iv,'base64')); d.setAuthTag(Buffer.from(x.tag,'base64')); return Buffer.concat([d.update(Buffer.from(x.ciphertext,'base64')),d.final()]); }
function auth(request) { if (!request.auth?.uid) throw new HttpsError('unauthenticated','Inicia sesión nuevamente.'); }
exports.getOrCreateDataKey = onCall({secrets:[master], region:'southamerica-west1'}, async request => { auth(request); const r=ref(request.auth.uid); const old=await r.get(); if(old.exists) return {dataKey:open(old.data()).toString('base64')}; const data=crypto.randomBytes(32); await r.set({...seal(data),createdAt:admin.firestore.FieldValue.serverTimestamp()}); return {dataKey:data.toString('base64')}; });
