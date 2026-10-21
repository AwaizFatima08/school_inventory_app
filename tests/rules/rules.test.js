// Adversarial tests for firestore/firestore.rules against the Firestore emulator.
// Run from the repo root:
//   JAVA_HOME=$HOME/tools/jdk-21 PATH=$HOME/tools/jdk-21/bin:$PATH \
//   firebase emulators:exec --only firestore --project demo-school-inventory "npm --prefix tests/rules test"
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment, assertSucceeds, assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp,
} = require('firebase/firestore');

const ORG = 'org1';
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-school-inventory',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '../../firestore/firestore.rules'), 'utf8'),
      host: '127.0.0.1', port: 8086,
    },
  });
});
after(async () => { await env.cleanup(); });

const db = (uid) => env.authenticatedContext(uid).firestore();
const o = (...p) => ['orgs', ORG, ...p].join('/');

function member(uid, role, extra = {}) {
  return {
    uid, displayName: uid, email: `${uid}@x.test`, role, isAdmin: false,
    status: 'active', locationIds: [], createdAt: new Date(), ...extra,
  };
}

// Seed: admin incharge, supervisor, item with 10 in stock, staff member.
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    await setDoc(doc(f, 'orgs', ORG), { name: 'FF School', joinCode: 'ABC234', createdBy: 'admin', modules: ['janitorial'], schemaVersion: 1, createdAt: new Date() });
    await setDoc(doc(f, o('members/admin')), member('admin', 'incharge', { isAdmin: true }));
    await setDoc(doc(f, o('members/sup')), member('sup', 'supervisor'));
    await setDoc(doc(f, o('members/pend')), member('pend', 'viewer', { status: 'pending', requestedRole: 'supervisor' }));
    await setDoc(doc(f, o('items/soap')), { name: 'Soap', unit: 'bar', category: 'janitorial', reorderLevel: 2, currentStock: 10, active: true, createdBy: 'sup', createdAt: new Date() });
    await setDoc(doc(f, o('staff/s1')), { name: 'Aslam', employeeNo: '', phone: '', dutyArea: '', active: true, createdBy: 'sup', createdAt: new Date() });
  });
});

async function seed(p, data) {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), p), data));
}
const demand = (status, lines) => ({
  slipNo: '12', staffId: 's1', staffName: 'Aslam', lines, note: '', status,
  createdBy: 'sup', createdByName: 'sup', createdAt: new Date(),
});

function issueBatch(f, { qty, newStock, demandId = 'd1' }) {
  const b = writeBatch(f);
  b.update(doc(f, o(`demands/${demandId}`)), {
    status: 'issued', issuedBy: 'sup', issuedByName: 'sup', issuedAt: serverTimestamp(),
    'lines.soap.qtyIssued': qty,
  });
  b.update(doc(f, o('items/soap')), { currentStock: newStock, lastRef: { type: 'demand', id: demandId }, updatedAt: serverTimestamp() });
  b.set(doc(f, o(`ledger/${demandId}_soap`)), {
    itemId: 'soap', itemName: 'Soap', unit: 'bar', delta: -qty, balanceAfter: newStock, type: 'issue',
    refType: 'demand', refId: demandId, staffId: 's1', staffName: 'Aslam', reason: '',
    by: 'sup', byName: 'sup', at: serverTimestamp(),
  });
  return b.commit();
}
const approvedLines = (req, appr) => ({ soap: { itemName: 'Soap', unit: 'bar', qtyRequested: req, qtyApproved: appr, qtyIssued: 0 } });

// ---------------- onboarding ----------------
test('founder creates a new school and becomes incharge + admin', async () => {
  const f = db('newbie');
  const b = writeBatch(f);
  b.set(doc(f, 'orgs/org2'), { name: 'Other School', joinCode: 'ZZZ999', createdBy: 'newbie', createdAt: serverTimestamp(), modules: ['janitorial'], schemaVersion: 1 });
  b.set(doc(f, 'orgs/org2/members/newbie'), { uid: 'newbie', displayName: 'N', email: 'n@x', role: 'incharge', isAdmin: true, status: 'active', locationIds: [], createdAt: serverTimestamp() });
  b.set(doc(f, 'joinCodes/ZZZ999'), { orgId: 'org2', orgName: 'Other School' });
  await assertSucceeds(b.commit());
});

test('outsider cannot make themself admin of an existing school', async () => {
  await assertFails(setDoc(doc(db('evil'), o('members/evil')), { uid: 'evil', displayName: 'E', email: 'e@x', role: 'incharge', isAdmin: true, status: 'active', locationIds: [], createdAt: serverTimestamp() }));
});

test('outsider may only file a pending request', async () => {
  await assertSucceeds(setDoc(doc(db('joe'), o('members/joe')), { uid: 'joe', displayName: 'J', email: 'j@x', role: 'viewer', isAdmin: false, status: 'pending', requestedRole: 'supervisor', locationIds: [], createdAt: serverTimestamp() }));
});

test('pending member cannot read stock or approve themself', async () => {
  await assertFails(getDoc(doc(db('pend'), o('items/soap'))));
  await assertFails(updateDoc(doc(db('pend'), o('members/pend')), { status: 'active', role: 'supervisor' }));
});

test('outsider cannot read school data', async () => {
  await assertFails(getDoc(doc(db('evil'), o('items/soap'))));
  await assertFails(getDoc(doc(db('evil'), 'orgs/' + ORG)));
});

test('admin approves a request; non-admin incharge-less supervisor cannot', async () => {
  await assertFails(updateDoc(doc(db('sup'), o('members/pend')), { status: 'active', role: 'supervisor' }));
  await assertSucceeds(updateDoc(doc(db('admin'), o('members/pend')), { status: 'active', role: 'supervisor', approvedBy: 'admin' }));
});

test('admin cannot lock themself out', async () => {
  await assertFails(updateDoc(doc(db('admin'), o('members/admin')), { isAdmin: false }));
  await assertFails(updateDoc(doc(db('admin'), o('members/admin')), { status: 'disabled' }));
  await assertSucceeds(updateDoc(doc(db('admin'), o('members/admin')), { role: 'supervisor' }));
});

// ---------------- items ----------------
test('supervisor adds an item only with zero stock', async () => {
  const base = { name: 'Phenyl', unit: 'bottle', category: 'janitorial', reorderLevel: 3, active: true, createdBy: 'sup', createdAt: serverTimestamp() };
  await assertSucceeds(setDoc(doc(db('sup'), o('items/phenyl')), { ...base, currentStock: 0 }));
  await assertFails(setDoc(doc(db('sup'), o('items/phenyl2')), { ...base, currentStock: 50 }));
});

test('nobody can edit stock directly', async () => {
  await assertFails(updateDoc(doc(db('sup'), o('items/soap')), { currentStock: 99 }));
  await assertFails(updateDoc(doc(db('admin'), o('items/soap')), { currentStock: 99 }));
  await assertSucceeds(updateDoc(doc(db('sup'), o('items/soap')), { reorderLevel: 5 }));
});

// ---------------- demand flow ----------------
test('supervisor records a demand but cannot approve it', async () => {
  const f = db('sup');
  await assertSucceeds(setDoc(doc(f, o('demands/d1')), { ...demand('pending', approvedLines(3, 0)), createdAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(f, o('demands/d1')), { status: 'approved', decidedBy: 'sup', decidedAt: serverTimestamp() }));
});

test('incharge approves; cannot issue', async () => {
  await seed(o('demands/d1'), demand('pending', approvedLines(3, 0)));
  await assertSucceeds(updateDoc(doc(db('admin'), o('demands/d1')), { status: 'approved', decidedBy: 'admin', decidedByName: 'A', decidedAt: serverTimestamp(), 'lines.soap.qtyApproved': 3 }));
  await assertFails(updateDoc(doc(db('admin'), o('demands/d1')), { status: 'issued', issuedBy: 'admin', issuedAt: serverTimestamp() }));
});

test('supervisor issues approved quantity: stock, demand and ledger move together', async () => {
  await seed(o('demands/d1'), demand('approved', approvedLines(3, 3)));
  await assertSucceeds(issueBatch(db('sup'), { qty: 3, newStock: 7 }));
});

test('cannot issue more than approved', async () => {
  await seed(o('demands/d1'), demand('approved', approvedLines(5, 2)));
  await assertFails(issueBatch(db('sup'), { qty: 3, newStock: 7 }));
});

test('cannot issue more than in stock', async () => {
  await seed(o('demands/d1'), demand('approved', approvedLines(20, 20)));
  await assertFails(issueBatch(db('sup'), { qty: 12, newStock: -2 }));
});

test('stock change must equal issued quantity', async () => {
  await seed(o('demands/d1'), demand('approved', approvedLines(3, 3)));
  await assertFails(issueBatch(db('sup'), { qty: 3, newStock: 8 }));
});

test('cannot issue a pending demand or issue twice', async () => {
  await seed(o('demands/d1'), demand('pending', approvedLines(3, 3)));
  await assertFails(issueBatch(db('sup'), { qty: 3, newStock: 7 }));
  await seed(o('demands/d2'), demand('approved', approvedLines(3, 3)));
  await assertSucceeds(issueBatch(db('sup'), { qty: 3, newStock: 7, demandId: 'd2' }));
  await assertFails(issueBatch(db('sup'), { qty: 3, newStock: 4, demandId: 'd2' }));
});

test('ledger cannot be forged, edited or deleted', async () => {
  const f = db('sup');
  await assertFails(setDoc(doc(f, o('ledger/x_soap')), { itemId: 'soap', itemName: 'Soap', unit: 'bar', delta: -1, balanceAfter: 9, type: 'issue', refType: 'demand', refId: 'x', by: 'sup', byName: 's', at: serverTimestamp() }));
  await seed(o('demands/d1'), demand('approved', approvedLines(3, 3)));
  await issueBatch(f, { qty: 3, newStock: 7 });
  await assertFails(updateDoc(doc(f, o('ledger/d1_soap')), { delta: -1 }));
  await assertFails(deleteDoc(doc(db('admin'), o('ledger/d1_soap'))));
});

// ---------------- receipts ----------------
function approveReceiptBatch(f, { qty, newStock, by = 'admin' }) {
  const b = writeBatch(f);
  b.update(doc(f, o('receipts/r1')), { status: 'approved', decidedBy: by, decidedByName: by, decidedAt: serverTimestamp() });
  b.update(doc(f, o('items/soap')), { currentStock: newStock, lastRef: { type: 'receipt', id: 'r1' }, updatedAt: serverTimestamp() });
  b.set(doc(f, o('ledger/r1_soap')), { itemId: 'soap', itemName: 'Soap', unit: 'bar', delta: qty, balanceAfter: newStock, type: 'receipt', refType: 'receipt', refId: 'r1', reason: '', by, byName: by, at: serverTimestamp() });
  return b.commit();
}
const receipt = { source: 'Bazaar', reference: 'B-1', lines: { soap: { itemName: 'Soap', unit: 'bar', qty: 24 } }, note: '', status: 'pending', createdBy: 'sup', createdByName: 'sup', createdAt: new Date() };

test('receipt adds stock only after incharge approval', async () => {
  await assertSucceeds(setDoc(doc(db('sup'), o('receipts/r1')), { ...receipt, createdAt: serverTimestamp() }));
  await assertFails(approveReceiptBatch(db('sup'), { qty: 24, newStock: 34, by: 'sup' }));
  await assertFails(approveReceiptBatch(db('admin'), { qty: 30, newStock: 40 }));
  await assertSucceeds(approveReceiptBatch(db('admin'), { qty: 24, newStock: 34 }));
});

// ---------------- adjustments ----------------
function adjustBatch(f, by, delta, newStock) {
  const b = writeBatch(f);
  b.set(doc(f, o('adjustments/a1')), { lines: { soap: { itemName: 'Soap', unit: 'bar', delta } }, reason: 'Physical count', createdBy: by, createdByName: by, createdAt: serverTimestamp() });
  b.update(doc(f, o('items/soap')), { currentStock: newStock, lastRef: { type: 'adjustment', id: 'a1' }, updatedAt: serverTimestamp() });
  b.set(doc(f, o('ledger/a1_soap')), { itemId: 'soap', itemName: 'Soap', unit: 'bar', delta, balanceAfter: newStock, type: 'adjustment', refType: 'adjustment', refId: 'a1', reason: 'Physical count', by, byName: by, at: serverTimestamp() });
  return b.commit();
}

test('only incharge adjusts stock, and never below zero', async () => {
  await assertFails(adjustBatch(db('sup'), 'sup', -2, 8));
  await assertFails(adjustBatch(db('admin'), 'admin', -12, -2));
  await assertSucceeds(adjustBatch(db('admin'), 'admin', -2, 8));
});

// ---------------- staff ----------------
test('operators manage staff records; viewers and outsiders cannot', async () => {
  const s = { name: 'Bashir', employeeNo: '7', phone: '', dutyArea: 'Block A', active: true, createdBy: 'sup', createdAt: serverTimestamp() };
  await assertSucceeds(setDoc(doc(db('sup'), o('staff/s2')), s));
  await assertFails(setDoc(doc(db('pend'), o('staff/s3')), { ...s, createdBy: 'pend' }));
  await assertFails(deleteDoc(doc(db('admin'), o('staff/s1'))));
});
