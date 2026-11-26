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

const nameKey = (name) => fixText(name).trim().toLowerCase();

// Catalog flags: load entered per side (carga_por_lado, optionally only from
// the date carga_por_lado_desde on) and bodyweight only (tipo peso_corporal).
// Matched by id or, for old sessions, by name.
let catalogFlags = null;
function loadPerSideIndex(db) {
  if (!catalogFlags) {
    catalogFlags = db.collection('machine_catalog').get().then((snapshot) => {
      const flags = { ids: new Map(), names: new Map(), bodyIds: new Set(), bodyNames: new Set() };
      for (const doc of snapshot.docs) {
        const name = nameKey(doc.get('nome_popular'));
        if (doc.get('carga_por_lado') === true) {
          const since = perSideSince(doc.get('carga_por_lado_desde'));
          flags.ids.set(doc.id, since);
          flags.names.set(name, since);
        }
        if (doc.get('tipo') === 'peso_corporal') {
          flags.bodyIds.add(doc.id);
          flags.bodyNames.add(name);
        }
      }
      return flags;
    });
  }
  return catalogFlags;
}

/** "2026-11-25" -> local midnight of that day, or null when not set. */
function perSideSince(value) {
  return typeof value === 'string' && value ? new Date(`${value}T00:00:00`) : null;
}

/** Per side for this exercise at [date] (no date = per side whenever flagged). */
function isPerSide(index, id, name, date) {
  const key = nameKey(name);
  if (!index.ids.has(id) && !index.names.has(key)) return false;
  const since = index.ids.has(id) ? index.ids.get(id) : index.names.get(key);
  return !since || !date || date >= since;
}
const isBodyweight = (index, id, name) => index.bodyIds.has(id) || index.bodyNames.has(nameKey(name));

// Per-side weights become totals (x2) so volume and loads are comparable.
function mapSession(doc, perSide) {
  const d = doc.data();
  const date = toDate(d.performedAt) || toDate(d.completedAt) || toDate(d.endAt);
  const startAt = toDate(d.startAt);
  return {
    id: doc.id,
    workoutName: d.workoutName || '',
    status: d.status || '',
    date,
    startAt,
    endAt: toDate(d.endAt),
    exercises: (d.exercises || []).map((e) => {
      const target = e.isWarmup ? e.targetExerciseId : e.exerciseId;
      const targetName = e.isWarmup ? e.targetExerciseName : e.exerciseName;
      const cargaPorLado = e.loadPerSide === true || isPerSide(perSide, target, targetName || '', startAt || date);
      const factor = cargaPorLado ? 2 : 1;
      return {
      exerciseId: e.exerciseId || null,
      exerciseName: fixText(e.exerciseName),
      category: e.category ? fixText(e.category) : null,
      isWarmup: e.isWarmup === true || isWarmupName(fixText(e.exerciseName)),
      status: e.status || (e.completed ? 'completed' : 'pending'),
      perceivedEffort: e.perceivedEffort || null,
      cargaPorLado,
      pesoCorporal: e.type === 'peso_corporal' || isBodyweight(perSide, target, targetName || ''),
      sets: Array.isArray(e.sets)
        ? e.sets.map((s) => ({ reps: num(s.reps), weightKg: num(s.weightKg) * factor }))
        : [],
      };
    }),
  };
}

async function loadSessions(db, uid) {
  const [snapshot, perSide] = await Promise.all([
    db.collection('workout_history').where('ownerUid', '==', uid).get(),
    loadPerSideIndex(db),
  ]);
  return snapshot.docs.map((doc) => mapSession(doc, perSide));
}

async function loadEvents(db, uid) {
  const [machines, perSide] = await Promise.all([
    db.collection('users').doc(uid).collection('machines').get(),
    loadPerSideIndex(db),
  ]);
  const events = [];
  for (const machine of machines.docs) {
    const name = fixText(machine.data().exerciseName) || machine.id;
    const snapshot = await machine.ref.collection('events').get();
    for (const doc of snapshot.docs) {
      const e = doc.data();
      const when = toDate(e.occurredAt) || toDate(e.createdAt);
      const factor = isPerSide(perSide, machine.id, name, when) ? 2 : 1;
      const scale = (value) =>
        e.type === 'weight_increased' && typeof value === 'number' ? value * factor : value ?? null;
      events.push({
        exerciseId: machine.id,
        exerciseName: name,
        type: e.type,
        previousValue: scale(e.previousValue),
        newValue: scale(e.newValue),
        occurredAt: when,
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
