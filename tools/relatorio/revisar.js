#!/usr/bin/env node
// Lists the last workouts with what still needs review in the catalog.
// Usage: node revisar.js [quantidade=1]
// Pending = scientific name not reviewed, category outside the catalog keys,
// warmup left pending, exercise marked done without sets.

const { init, fixText } = require('./firestore');

const CATEGORIES = new Set(['peito', 'costas', 'ombros', 'biceps', 'triceps', 'pernas', 'gluteos',
  'panturrilhas', 'core', 'cardio', 'outros']);
const date = (t) => (t && t.toDate ? t.toDate().toLocaleString('pt-BR') : '-');
const millis = (s) => (s.performedAt || s.completedAt || s.endAt || s.startAt)?.toMillis?.() || 0;

async function main() {
  const count = Number(process.argv[2]) || 1;
  const { db, uid } = init();
  const [sessions, catalogSnap] = await Promise.all([
    db.collection('workout_history').where('ownerUid', '==', uid).get(),
    db.collection('machine_catalog').get(),
  ]);
  const catalog = Object.fromEntries(catalogSnap.docs.map((d) => [d.id, d.data()]));
  const latest = sessions.docs.map((d) => ({ id: d.id, ...d.data() }))
    .sort((a, b) => millis(b) - millis(a)).slice(0, count);

  for (const s of latest) {
    console.log(`\n=== ${s.workoutName} | ${date(s.startAt)} a ${date(s.endAt)} | ${s.status} | sessão ${s.id}`);
    for (const e of s.exercises || []) {
      const sets = (e.sets || []).map((x) => `${x.weightKg}x${x.reps}`).join(' ') || 'sem séries';
      if (e.isWarmup) {
        const flag = e.status === 'pending' ? '  <- aquecimento pendente' : '';
        console.log(`- Aquecimento (${e.status}) alvo=${e.targetExerciseName || '-'} | ${sets}${flag}`);
        continue;
      }
      const c = catalog[e.exerciseId] || {};
      const issues = [];
      if (!catalog[e.exerciseId]) issues.push('sem item no catálogo');
      if (c.nome_cientifico_pendente) issues.push('nome científico pendente');
      if (e.category && !CATEGORIES.has(e.category)) issues.push(`categoria "${e.category}"`);
      if (e.status === 'completed' && !(e.sets || []).length) issues.push('concluído sem séries');
      console.log(`- ${fixText(e.exerciseName)} [${e.exerciseId}] | ${e.status} | ${e.perceivedEffort || '-'} | ${sets}`);
      console.log(`    científico: "${c.nome_cientifico || '?'}" | ${c.categoria || '?'} | ${c.tipo || '?'}` +
        `${c.carga_por_lado ? ' | por lado' : ''} | origem ${c.origem || '?'}`);
      if (issues.length) console.log(`    PENDENTE: ${issues.join(', ')}`);
    }
  }
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
