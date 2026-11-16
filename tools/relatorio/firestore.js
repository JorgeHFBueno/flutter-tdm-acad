// Firestore access with a service account kept OUTSIDE the repository.
// Default: ~/.vanguard/service-account.json and ~/.vanguard/config.json ({"uid": "..."}).

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const admin = require('firebase-admin');

const CONFIG_DIR = process.env.VANGUARD_DIR || path.join(os.homedir(), '.vanguard');

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function init() {
  const keyFile =
    process.env.VANGUARD_SERVICE_ACCOUNT || path.join(CONFIG_DIR, 'service-account.json');
  if (!fs.existsSync(keyFile)) {
    throw new Error(`Chave da conta de serviço não encontrada em ${keyFile}`);
  }
  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(readJson(keyFile)) });
  }
  const configFile = path.join(CONFIG_DIR, 'config.json');
  const uid = process.env.VANGUARD_UID || (fs.existsSync(configFile) && readJson(configFile).uid);
  if (!uid) throw new Error(`Defina {"uid": "..."} em ${configFile}`);
  return { db: admin.firestore(), messaging: admin.messaging(), uid };
}

const toDate = (value) => (value && typeof value.toDate === 'function' ? value.toDate() : null);
const num = (value) => (typeof value === 'number' ? value : Number(value) || 0);

// Some names were saved double-encoded ("AntebraÃ§o"); repair for reading only.
function fixText(value) {
  const text = String(value || '');
  if (!/[ÃÂ]/.test(text)) return text;
  const repaired = Buffer.from(text, 'latin1').toString('utf8');
  return repaired.includes('�') ? text : repaired;
}

// Sessions before the warmup flag existed stored it as a normal exercise.
const isWarmupName = (name) => /^aquecimento/i.test(name.trim());

function mapSession(doc) {
  const d = doc.data();
  return {
    id: doc.id,
    workoutName: d.workoutName || '',
    status: d.status || '',
    date: toDate(d.performedAt) || toDate(d.completedAt) || toDate(d.endAt),
    startAt: toDate(d.startAt),
    endAt: toDate(d.endAt),
    exercises: (d.exercises || []).map((e) => ({
      exerciseId: e.exerciseId || null,
      exerciseName: fixText(e.exerciseName),
      category: e.category ? fixText(e.category) : null,
      isWarmup: e.isWarmup === true || isWarmupName(fixText(e.exerciseName)),
      status: e.status || (e.completed ? 'completed' : 'pending'),
      perceivedEffort: e.perceivedEffort || null,
      sets: Array.isArray(e.sets)
        ? e.sets.map((s) => ({ reps: num(s.reps), weightKg: num(s.weightKg) }))
        : [],
    })),
  };
}

async function loadSessions(db, uid) {
  const snapshot = await db.collection('workout_history').where('ownerUid', '==', uid).get();
  return snapshot.docs.map(mapSession);
}

async function loadEvents(db, uid) {
  const machines = await db.collection('users').doc(uid).collection('machines').get();
  const events = [];
  for (const machine of machines.docs) {
    const name = fixText(machine.data().exerciseName) || machine.id;
    const snapshot = await machine.ref.collection('events').get();
    for (const doc of snapshot.docs) {
      const e = doc.data();
      events.push({
        exerciseId: machine.id,
        exerciseName: name,
        type: e.type,
        previousValue: e.previousValue ?? null,
        newValue: e.newValue ?? null,
        occurredAt: toDate(e.occurredAt) || toDate(e.createdAt),
        voided: Boolean(e.voidedAt) || e.isDeleted === true,
      });
    }
  }
  return events;
}

/** Start of the "Nova Era" (users/{uid}.novaEraInicio), or null. */
async function loadEraStart(db, uid) {
  return toDate((await db.collection('users').doc(uid).get()).get('novaEraInicio'));
}

module.exports = { init, loadSessions, loadEvents, loadEraStart, admin, fixText, CONFIG_DIR };
