#!/usr/bin/env node
// Applies a correction plan and reconciles machines and session snapshots with
// the catalog (name, category, type, per-side load). Dry run unless --aplicar.
// Usage: node corrigir.js plano.json [--aplicar] [--detalhe]
//
// plano.json:
// {
//   "catalogo": { "<id>": { "nome_popular": "...", "nome_cientifico": "...",
//                  "tipo": "polia", "categoria": "costas", "carga_por_lado": true,
//                  "carga_por_lado_desde": "2026-11-25" } },   // optional: older sessions are totals
//   "aquecimentos": { "<sessionId>": { "status": "completed",
//                  "targetExerciseId": "<id>", "sets": [{ "reps": 12, "weightKg": 10 }] } },
//   "motivos": { "<sessionId>": { "<exerciseId>": "fadiga" | "tempo" | "substituida" } }
// }                // why a machine was not done (sessions saved by older app versions)
// Old sessions are matched to the catalog by exerciseId, so renames reach the
// whole history (reports group exercises by name).

const fs = require('node:fs');
const path = require('node:path');
const { init, admin, fixText, CONFIG_DIR } = require('./firestore');

const CATEGORIES = ['peito', 'costas', 'ombros', 'biceps', 'triceps', 'pernas', 'gluteos',
  'panturrilhas', 'core', 'cardio', 'outros'];
const CATALOG_FIELDS = ['nome_popular', 'nome_cientifico', 'tipo', 'categoria', 'carga_por_lado',
  'carga_por_lado_desde'];

/** Same rules as canonicalMachineCategory/machineCategoryKey in the app. */
function categoryKey(category, id = '') {
  if (CATEGORIES.includes(category)) return category;
  const value = fixText(category).toLowerCase();
  if (id.includes('panturrilha')) return 'panturrilhas';
  if (id.includes('ombro') || id.includes('elevacao_lateral')) return 'ombros';
  if (id.includes('triceps')) return 'triceps';
  if (id.includes('biceps') || id === 'barra_w') return 'biceps';
  if (value.includes('abdomin')) return 'core';
  if (value.includes('perna')) return 'pernas';
  if (value.includes('peito')) return 'peito';
  if (value.includes('costa')) return 'costas';
  return 'outros';
}

const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const SKIP_EFFORTS = { fadiga: 'skipped_fatigue', tempo: 'skipped_time', substituida: 'skipped_replaced' };

/** Per side in a session on [date]; carga_por_lado_desde limits it to newer sessions. */
function perSideAt(item, date) {
  if (!item || item.carga_por_lado !== true) return false;
  const since = item.carga_por_lado_desde;
  return !since || !date || date >= new Date(`${since}T00:00:00`);
}

function patchExercise(e, item, warmupPatch, catalog, date, reason) {
  const out = { ...e };
  if (reason && !e.isWarmup) {
    out.perceivedEffort = SKIP_EFFORTS[reason];
    out.completed = true;
    if (!(e.sets || []).length) out.status = 'skipped';
  }
  if (e.isWarmup) {
    if (warmupPatch) {
      Object.assign(out, warmupPatch);
      out.completed = warmupPatch.status !== 'pending';
      if (warmupPatch.sets) {
        out.sets = warmupPatch.sets.map((s, i) => ({ setNumber: i + 1, reps: s.reps, weightKg: s.weightKg }));
      }
    }
    const target = catalog[out.targetExerciseId];
    if (target) {
      out.targetExerciseName = target.nome_popular;
      if (perSideAt(target, date)) out.loadPerSide = true;
      else delete out.loadPerSide;
      out.type = target.tipo;
    }
    return out;
  }
  if (item) {
    out.exerciseName = item.nome_popular;
    out.category = item.categoria;
    out.type = item.tipo;
    if ('scientificName' in e || !item.nome_cientifico_pendente) out.scientificName = item.nome_cientifico;
    if (perSideAt(item, date)) out.loadPerSide = true;
    else delete out.loadPerSide;
  } else if (e.category) {
    out.category = categoryKey(e.category, e.exerciseId || '');
  }
  return out;
}

async function main() {
  const planFile = process.argv[2];
  if (!planFile || planFile.startsWith('--')) throw new Error('Uso: node corrigir.js plano.json [--aplicar]');
  const apply = process.argv.includes('--aplicar');
  const detail = process.argv.includes('--detalhe');
  const plan = JSON.parse(fs.readFileSync(planFile, 'utf8'));
  const { db, uid } = init();

  const backup = {};
  const writes = [];
  const log = [];
  const write = (ref, before, update, label) => {
    backup[ref.path] = before;
    writes.push([ref, update]);
    log.push(`${ref.path}  ${label}`);
  };

  // 1. Catalog
  const catalogSnap = await db.collection('machine_catalog').get();
  const catalog = {};
  for (const doc of catalogSnap.docs) {
    const data = doc.data();
    const patch = (plan.catalogo || {})[doc.id];
    const merged = { ...data, ...(patch || {}) };
    catalog[doc.id] = merged;
    if (!patch) continue;
    const bad = Object.keys(patch).filter((k) => !CATALOG_FIELDS.includes(k));
    if (bad.length) throw new Error(`Campos inválidos em ${doc.id}: ${bad.join(', ')}`);
    if (patch.categoria && !CATEGORIES.includes(patch.categoria)) throw new Error(`Categoria inválida: ${patch.categoria}`);
    const changed = Object.keys(patch).filter((k) => !same(data[k], patch[k]));
    if (patch.nome_cientifico && data.nome_cientifico_pendente) changed.push('nome_cientifico_pendente');
    if (!changed.length) continue;
    const update = Object.fromEntries(changed.map((k) => [k, k === 'nome_cientifico_pendente' ? false : patch[k]]));
    merged.nome_cientifico_pendente = patch.nome_cientifico ? false : data.nome_cientifico_pendente;
    update.atualizado_em = admin.firestore.FieldValue.serverTimestamp();
    write(doc.ref, data, update, JSON.stringify(Object.fromEntries(changed.map((k) => [k, update[k]]))));
  }
  for (const id of Object.keys(plan.catalogo || {})) {
    if (!catalog[id]) throw new Error(`Item do catálogo não encontrado: ${id}`);
  }

  // 2. User machines follow the catalog name and category
  const machines = await db.collection('users').doc(uid).collection('machines').get();
  for (const doc of machines.docs) {
    const data = doc.data();
    const item = catalog[doc.id];
    const update = {};
    const name = item ? item.nome_popular : data.exerciseName;
    const category = item ? item.categoria : categoryKey(data.category || '', doc.id);
    if (name && name !== data.exerciseName) update.exerciseName = name;
    if (category && category !== data.category) update.category = category;
    if (Object.keys(update).length) write(doc.ref, data, update, JSON.stringify(update));
  }

  // 3. Session snapshots
  const sessions = await db.collection('workout_history').where('ownerUid', '==', uid).get();
  const warmups = plan.aquecimentos || {};
  const reasons = plan.motivos || {};
  for (const id of [...Object.keys(warmups), ...Object.keys(reasons)]) {
    if (!sessions.docs.some((d) => d.id === id)) throw new Error(`Sessão não encontrada: ${id}`);
  }
  for (const [id, byExercise] of Object.entries(reasons)) {
    const ids = (sessions.docs.find((d) => d.id === id).data().exercises || []).map((e) => e.exerciseId);
    for (const [exerciseId, reason] of Object.entries(byExercise)) {
      if (!SKIP_EFFORTS[reason]) throw new Error(`Motivo inválido: ${reason} (use fadiga, tempo ou substituida)`);
      if (!ids.includes(exerciseId)) throw new Error(`Exercício ${exerciseId} não está na sessão ${id}`);
    }
  }
  for (const doc of sessions.docs) {
    const data = doc.data();
    const exercises = data.exercises || [];
    const date = (data.startAt || data.performedAt)?.toDate?.();
    const fixed = exercises.map((e) =>
      patchExercise(e, e.isWarmup ? null : catalog[e.exerciseId], warmups[doc.id], catalog, date,
        (reasons[doc.id] || {})[e.exerciseId]));
    const diffs = fixed
      .map((e, i) => {
        if (same(e, exercises[i])) return null;
        const label = e.isWarmup ? 'Aquecimento' : e.exerciseName;
        if (!detail) return label;
        const keys = [...new Set([...Object.keys(e), ...Object.keys(exercises[i])])]
          .filter((k) => !same(e[k], exercises[i][k]))
          .map((k) => `${k}: ${JSON.stringify(exercises[i][k])} -> ${JSON.stringify(e[k])}`);
        return `
    ${label} { ${keys.join('; ')} }`;
      })
      .filter(Boolean);
    if (diffs.length) write(doc.ref, data, { exercises: fixed }, diffs.join(', '));
  }

  console.log(log.join('\n') || 'Nada a corrigir.');
  if (!apply) {
    console.log(`\n${writes.length} documento(s) a alterar (simulação; use --aplicar)`);
    return;
  }
  if (!writes.length) return;
  const file = path.join(CONFIG_DIR, `backup-${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
  fs.writeFileSync(file, JSON.stringify(backup, null, 1));
  for (let i = 0; i < writes.length; i += 400) {
    const batch = db.batch();
    for (const [ref, update] of writes.slice(i, i + 400)) batch.update(ref, update);
    await batch.commit();
  }
  console.log(`\nAplicado em ${writes.length} documento(s). Backup: ${file}`);
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
