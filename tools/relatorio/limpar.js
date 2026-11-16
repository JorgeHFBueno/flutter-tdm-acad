#!/usr/bin/env node
// One-off cleanup that turns the old history into the "Nova Era" starting point.
// Dry run by default; --aplicar writes a full backup to ~/.vanguard first.
// Usage: node limpar.js [--aplicar] [--inicio AAAA-MM-DD]

const fs = require('node:fs');
const path = require('node:path');
const { init, admin, fixText, CONFIG_DIR } = require('./firestore');

const CATEGORIES = [
  'peito', 'costas', 'ombros', 'biceps', 'triceps', 'pernas',
  'gluteos', 'panturrilhas', 'core', 'cardio', 'outros',
];
const OLD_SESSION = { date: '2026-07-27', from: 'Treino Costas Completo', to: 'Peito Ombro Triceps' };

const plain = (text) => String(text || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();

// Same rules as _canonicalCategory in lib/data/machine_catalog_seed.dart, catalog first.
function canonicalCategory(raw, id, name, catalog) {
  if (catalog.has(id)) return catalog.get(id).categoria;
  const key = `${id} ${plain(name)}`;
  const value = plain(raw);
  if (key.includes('panturrilha')) return 'panturrilhas';
  if (key.includes('ombro') || key.includes('elevacao lateral') || key.includes('elevacao_lateral')) return 'ombros';
  if (key.includes('triceps')) return 'triceps';
  if (key.includes('biceps')) return 'biceps';
  if (CATEGORIES.includes(value)) return value;
  if (value.includes('abdomin')) return 'core';
  if (value.includes('perna')) return 'pernas';
  if (value.includes('peito')) return 'peito';
  if (value.includes('costa')) return 'costas';
  return 'outros';
}

const dateKey = (ts) => (ts && ts.toDate ? ts.toDate().toLocaleDateString('sv-SE') : null);

async function loadAll(db, uid) {
  const userRef = db.collection('users').doc(uid);
  const [user, machines, workouts, sessions, catalog, logs] = await Promise.all([
    userRef.get(),
    userRef.collection('machines').get(),
    userRef.collection('workouts').get(),
    db.collection('workout_history').where('ownerUid', '==', uid).get(),
    db.collection('machine_catalog').get(),
    db.collection('workout_analysis_logs').where('ownerUid', '==', uid).get(),
  ]);
  const events = {};
  for (const machine of machines.docs) {
    events[machine.id] = (await machine.ref.collection('events').get()).docs.map((d) => ({ id: d.id, ...d.data() }));
  }
  return { userRef, user, machines, workouts, sessions, catalog, logs, events };
}

function backup(data) {
  const dump = (snap) => snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const file = path.join(CONFIG_DIR, `backup-${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
  fs.writeFileSync(file, JSON.stringify({
    user: data.user.data() || null,
    machines: dump(data.machines),
    machineEvents: data.events,
    workouts: dump(data.workouts),
    workout_history: dump(data.sessions),
    machine_catalog: dump(data.catalog),
    workout_analysis_logs: dump(data.logs),
  }, null, 2));
  return file;
}

function planChanges(data, eraStart) {
  const changes = [];
  const catalog = new Map(data.catalog.docs.map((d) => [d.id, d.data()]));

  for (const doc of data.catalog.docs) {
    const name = doc.get('nome_popular');
    if (fixText(name) !== name) {
      changes.push({ ref: doc.ref, op: 'update', data: { nome_popular: fixText(name) }, desc: `catálogo ${doc.id}: "${name}" → "${fixText(name)}"` });
      catalog.get(doc.id).nome_popular = fixText(name);
    }
  }

  const machineCategory = new Map();
  const machineByName = new Map();
  for (const doc of data.machines.docs) {
    const d = doc.data();
    const name = fixText(d.exerciseName);
    const category = canonicalCategory(d.category, doc.id, name, catalog);
    machineCategory.set(doc.id, category);
    machineByName.set(plain(name), doc.id);
    const update = {};
    if (name !== d.exerciseName) update.exerciseName = name;
    if (category !== d.category) update.category = category;
    if (Object.keys(update).length) {
      changes.push({ ref: doc.ref, op: 'update', data: update, desc: `máquina ${name}: ${JSON.stringify(update)} (era ${JSON.stringify(d.category)})` });
    }
  }

  for (const doc of data.sessions.docs) {
    const d = doc.data();
    const day = dateKey(d.startAt);
    if (d.status === 'abandoned') {
      changes.push({ ref: doc.ref, op: 'delete', desc: `sessão abandonada ${day} "${d.workoutName}"` });
      continue;
    }
    let touched = 0;
    const exercises = (d.exercises || []).map((e) => {
      const next = { ...e };
      const name = fixText(e.exerciseName);
      next.exerciseName = name;
      const warmup = e.isWarmup === true || /^aquecimento/i.test(name.trim());
      if (warmup && e.isWarmup !== true) next.isWarmup = true;
      if (!warmup) {
        if (!next.exerciseId && machineByName.has(plain(name))) next.exerciseId = machineByName.get(plain(name));
        const category = machineCategory.get(next.exerciseId) || canonicalCategory(e.category, next.exerciseId || '', name, catalog);
        next.category = category;
      }
      if (JSON.stringify(next) !== JSON.stringify(e)) touched++;
      return next;
    });
    const update = {};
    if (touched) update.exercises = exercises;
    if (day === OLD_SESSION.date && d.workoutName === OLD_SESSION.from) update.workoutName = OLD_SESSION.to;
    if (Object.keys(update).length) {
      changes.push({ ref: doc.ref, op: 'update', data: update, desc: `sessão ${day} "${d.workoutName}": ${touched} exercício(s)${update.workoutName ? ` e nome → "${update.workoutName}"` : ''}` });
    }
  }

  changes.push({
    ref: data.userRef,
    op: 'set',
    data: { novaEraInicio: admin.firestore.Timestamp.fromDate(eraStart) },
    desc: `início da Nova Era: ${eraStart.toLocaleDateString('pt-BR')}`,
  });
  return changes;
}

async function main() {
  const argv = process.argv.slice(2);
  const apply = argv.includes('--aplicar');
  const i = argv.indexOf('--inicio');
  const eraStart = new Date(`${i >= 0 ? argv[i + 1] : new Date().toLocaleDateString('sv-SE')}T00:00:00`);

  const { db, uid } = init();
  const data = await loadAll(db, uid);
  const changes = planChanges(data, eraStart);
  changes.forEach((c) => console.log(`${c.op.padEnd(6)} ${c.desc}`));
  if (argv.includes("--detalhe")) {
    for (const c of changes.filter((x) => x.data && x.data.exercises)) {
      console.log(`
${c.desc}`);
      c.data.exercises.forEach((e) => console.log(`  ${e.isWarmup ? "[aquec] " : ""}${e.exerciseName} | ${e.exerciseId || "-"} | ${e.category || "-"}`));
    }
  }
  console.log(`\n${changes.length} alteração(ões).`);
  if (!apply) {
    console.log('Simulação: nada foi gravado. Use --aplicar para gravar.');
    return;
  }
  console.log(`Backup: ${backup(data)}`);
  const batch = db.batch();
  for (const c of changes) {
    if (c.op === 'delete') batch.delete(c.ref);
    else if (c.op === 'set') batch.set(c.ref, c.data, { merge: true });
    else batch.update(c.ref, c.data);
  }
  await batch.commit();
  console.log('Aplicado.');
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
