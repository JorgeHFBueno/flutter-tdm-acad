const test = require('node:test');
const assert = require('node:assert/strict');
const m = require('./metricas');

function session(date, exercises, extra = {}) {
  return { id: date, workoutName: 'Peito', date: new Date(date), exercises, ...extra };
}
function ex(id, sets, extra = {}) {
  return {
    exerciseId: id,
    exerciseName: id,
    category: 'peito',
    status: 'completed',
    perceivedEffort: 'adequate',
    sets: sets.map(([reps, weightKg]) => ({ reps, weightKg })),
    ...extra,
  };
}
const warmup = (status) => ({ isWarmup: true, status, sets: status === 'skipped' ? [] : [{ reps: 10, weightKg: 10 }] });

test('week range is Monday to next Monday for a Sunday run', () => {
  const { start, end } = m.weekRange(new Date(2026, 10, 15, 19)); // Sun 15/11
  assert.equal(m.dateKey(start), '2026-11-09');
  assert.equal(m.dateKey(end), '2026-11-16');
});

test('previous month and first Sunday rules', () => {
  const { start, end } = m.previousMonthRange(new Date(2026, 11, 6)); // 06/12
  assert.equal(m.dateKey(start), '2026-11-01');
  assert.equal(m.dateKey(end), '2026-12-01');
  assert.equal(m.isFirstSundayOfMonth(new Date(2026, 11, 6)), true);
  assert.equal(m.isFirstSundayOfMonth(new Date(2026, 11, 13)), false);
  assert.equal(m.isFirstSundayOfMonth(new Date(2026, 11, 5)), false); // Saturday
});

test('period metrics: totals, comparison, records, new exercises, warmup', () => {
  const sessions = [
    session('2026-11-03T10:00', [ex('supino', [[10, 40], [10, 40]])]),
    session('2026-11-10T10:00', [warmup('done'), ex('supino', [[8, 45], [8, 45]]), ex('crucifixo', [[12, 10]])]),
    session('2026-11-12T10:00', [warmup('skipped'), ex('supino', [[10, 42]], { perceivedEffort: 'certo' }), ex('voador', [], { status: 'skipped', perceivedEffort: 'skipped_fatigue' })]),
    session('2026-11-13T10:00', [ex('supino', [[10, 99]])], { status: 'abandoned' }),
    session('2026-11-14T10:00', [ex('supino', [[10, 99]])], { status: 'inProgress' }),
  ];
  const range = m.weekRange(new Date(2026, 10, 15, 19));
  const previousRange = m.weekRange(new Date(2026, 10, 8, 19));
  const r = m.computePeriodMetrics({
    sessions,
    events: [
      { exerciseId: 'supino', exerciseName: 'Supino', type: 'weight_increased', previousValue: 40, newValue: 45, occurredAt: new Date('2026-11-10T11:00') },
      { exerciseId: 'supino', type: 'weight_increased', voided: true, occurredAt: new Date('2026-11-11T11:00') },
      { exerciseId: 'supino', type: 'completion', occurredAt: new Date('2026-11-11T11:00') },
    ],
    range,
    previousRange,
  });

  assert.deepEqual(r.totais, { sessoes: 2, diasTreinados: 2, volumeKg: 1260, series: 4, repeticoes: 38 });
  assert.equal(r.periodoAnterior.totais.volumeKg, 800);
  assert.equal(r.periodoAnterior.variacaoPercentual.volumeKg, 57.5);
  assert.deepEqual(r.aquecimento, { feitos: 1, pulados: 1 });
  assert.deepEqual(r.percepcao, { adequate: 3, skipped_fatigue: 1 });
  assert.deepEqual(r.naoRealizados, ['voador']);

  const supino = r.exercicios.find((e) => e.nome === 'supino');
  assert.equal(supino.cargaMaximaKg, 45);
  assert.equal(supino.cargaMaximaAntesKg, 40);
  assert.equal(supino.recordeDeCarga, true);
  assert.equal(supino.novo, false);
  assert.equal(r.exercicios.find((e) => e.nome === 'crucifixo').novo, true);
  assert.equal(r.exercicios.some((e) => e.nome === 'voador'), false);
  assert.equal(r.aumentosRegistrados.length, 1);
  assert.equal(r.aumentosRegistrados[0].para, 45);
});

test('overall metrics: frequency, months and long-term progression', () => {
  const sessions = [
    session('2026-10-01T10:00', [ex('supino', [[10, 30]])]),
    session('2026-10-15T10:00', [ex('supino', [[10, 35]])]),
    session('2026-11-10T10:00', [ex('supino', [[10, 45]])]),
  ];
  const r = m.computeOverallMetrics({ sessions, until: new Date(2026, 10, 16) });
  assert.equal(r.inicio, '2026-10-01');
  assert.equal(r.totais.sessoes, 3);
  assert.deepEqual(r.meses.map((x) => [x.mes, x.sessoes]), [['2026-10', 2], ['2026-11', 1]]);
  const supino = r.exercicios[0];
  assert.equal(supino.cargaInicialKg, 30);
  assert.equal(supino.cargaAtualKg, 45);
  assert.ok(r.mediaSessoesPorSemana > 0.4 && r.mediaSessoesPorSemana < 0.5);
});

test('overall metrics with Nova Era: old sessions become the starting point', () => {
  const sessions = [
    session('2026-08-01T10:00', [ex('supino', [[10, 40]])]),
    session('2026-08-05T10:00', [ex('supino', [[10, 44]]), ex('Voador', [[10, 55]])]),
    session('2026-11-18T10:00', [ex('supino', [[10, 38]])]),
    session('2026-11-20T10:00', [ex('supino', [[10, 40]])]),
  ];
  const since = new Date(2026, 10, 16);
  const r = m.computeOverallMetrics({
    sessions,
    events: [
      { type: 'weight_increased', previousValue: null, newValue: 40, occurredAt: new Date('2026-11-18T11:00') },
      { type: 'weight_increased', previousValue: 38, newValue: 40, occurredAt: new Date('2026-11-20T11:00') },
    ],
    until: new Date(2026, 10, 23),
    since,
  });
  assert.equal(r.inicio, '2026-11-16');
  assert.equal(r.totais.sessoes, 2);
  assert.equal(r.aumentosRegistrados, 1); // the initial setup does not count
  assert.equal(r.eraAnterior.fim, '2026-08-05');
  assert.equal(r.eraAnterior.totais.sessoes, 2);
  assert.deepEqual(r.eraAnterior.pontoDePartida.map((e) => [e.nome, e.cargaKg]), [['supino', 44], ['Voador', 55]]);
  const supino = r.exercicios.find((e) => e.nome === 'supino');
  assert.equal(supino.pontoDePartidaKg, 44);
  assert.equal(supino.cargaAtualKg, 40);

  const empty = m.computeOverallMetrics({ sessions: sessions.slice(0, 2), until: new Date(2026, 10, 23), since });
  assert.equal(empty.totais.sessoes, 0);
  assert.equal(empty.eraAnterior.pontoDePartida.length, 2);
});

test('per-side exercises are flagged in the outputs', () => {
  const sessions = [session('2026-11-16T20:00', [ex('cross', [[10, 30]], { cargaPorLado: true }), ex('voador', [[10, 50]])])];
  const range = m.weekRange(new Date(2026, 10, 22, 19));
  const result = m.computePeriodMetrics({ sessions, events: [], range, previousRange: range });
  const cross = result.exercicios.find((e) => e.nome === 'cross');
  const voador = result.exercicios.find((e) => e.nome === 'voador');
  assert.equal(cross.cargaPorLado, true);
  assert.equal(cross.cargaMaximaKg, 30);
  assert.equal('cargaPorLado' in voador, false);
});
