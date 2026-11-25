// Pure metric calculations for the weekly/monthly/overall reports.
// Numbers are computed here so the written analysis never does arithmetic.

const DAY_MS = 24 * 60 * 60 * 1000;

const EFFORT_ALIASES = { certo: 'adequate', leve: 'light', fadiga: 'high_fatigue' };
const INCREASE_TYPES = new Set([
  'weight_increased',
  'sets_increased',
  'repetitions_increased',
]);

// An event with no previous value is the initial setup of the machine, not progress.
const isRealIncrease = (e) =>
  INCREASE_TYPES.has(e.type) && !e.voided && e.occurredAt && e.previousValue !== null;

function round(value, digits = 1) {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

function dateKey(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function startOfDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

/** Monday 00:00 to next Monday 00:00 (local time) of the week containing ref. */
function weekRange(ref) {
  const day = startOfDay(ref);
  const offset = (day.getDay() + 6) % 7; // Monday = 0
  const start = new Date(day.getFullYear(), day.getMonth(), day.getDate() - offset);
  const end = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 7);
  return { start, end };
}

/** Calendar month before the month of ref. */
function previousMonthRange(ref) {
  const start = new Date(ref.getFullYear(), ref.getMonth() - 1, 1);
  const end = new Date(ref.getFullYear(), ref.getMonth(), 1);
  return { start, end };
}

/** The monthly + overall reports run on the first Sunday of the month. */
function isFirstSundayOfMonth(date) {
  return date.getDay() === 0 && date.getDate() <= 7;
}

function estimatedOneRepMax(set) {
  if (set.weightKg <= 0 || set.reps <= 0) return 0;
  return set.weightKg * (1 + set.reps / 30); // Epley
}

function normalizeEffort(value) {
  if (!value) return null;
  return EFFORT_ALIASES[value] || value;
}

// By name: old sessions used different IDs for the same machine.
function exerciseKey(exercise) {
  const name = (exercise.exerciseName || '').trim().toLowerCase();
  return name ? `nome:${name}` : (exercise.exerciseId || '').trim();
}

function workSets(exercise) {
  return (exercise.sets || []).filter((set) => set.reps > 0);
}

function inRange(date, range) {
  return date >= range.start && date < range.end;
}

/** Sessions that count for reports: finished and dated. */
function finishedSessions(sessions) {
  return sessions
    .filter((s) => s.date && s.status !== 'inProgress' && s.status !== 'abandoned')
    .sort((a, b) => a.date - b.date);
}

function summarizeExerciseHistory(sessions) {
  // Best set per exercise per session, in chronological order.
  const byExercise = new Map();
  for (const session of sessions) {
    for (const exercise of session.exercises || []) {
      if (exercise.isWarmup) continue;
      const sets = workSets(exercise);
      if (sets.length === 0) continue;
      const key = exerciseKey(exercise);
      if (!byExercise.has(key)) {
        byExercise.set(key, {
          key,
          name: exercise.exerciseName,
          category: exercise.category || null,
          cargaPorLado: false,
          pesoCorporal: false,
          entries: [],
        });
      }
      const item = byExercise.get(key);
      item.name = exercise.exerciseName || item.name;
      item.category = exercise.category || item.category;
      item.cargaPorLado = item.cargaPorLado || exercise.cargaPorLado === true;
      item.pesoCorporal = item.pesoCorporal || exercise.pesoCorporal === true;
      item.entries.push({
        date: session.date,
        maxWeightKg: Math.max(...sets.map((s) => s.weightKg)),
        bestE1rm: Math.max(...sets.map(estimatedOneRepMax)),
        volume: sets.reduce((sum, s) => sum + s.reps * s.weightKg, 0),
        sets: sets.length,
        reps: sets.reduce((sum, s) => sum + s.reps, 0),
      });
    }
  }
  return byExercise;
}

function periodTotals(sessions) {
  let volume = 0;
  let sets = 0;
  let reps = 0;
  const days = new Set();
  for (const session of sessions) {
    days.add(dateKey(session.date));
    for (const exercise of session.exercises || []) {
      if (exercise.isWarmup) continue;
      for (const set of workSets(exercise)) {
        volume += set.reps * set.weightKg;
        sets += 1;
        reps += set.reps;
      }
    }
  }
  return {
    sessoes: sessions.length,
    diasTreinados: days.size,
    volumeKg: round(volume),
    series: sets,
    repeticoes: reps,
  };
}

function percentChange(current, previous) {
  if (!previous) return null;
  return round(((current - previous) / previous) * 100);
}

/**
 * Metrics for one period plus a comparison with [previousRange].
 * [sessions] is the full history so records and "new" exercises are real.
 */
function computePeriodMetrics({ sessions, events = [], range, previousRange }) {
  const history = finishedSessions(sessions);
  const current = history.filter((s) => inRange(s.date, range));
  const before = history.filter((s) => s.date < range.start);
  const previous = previousRange
    ? history.filter((s) => inRange(s.date, previousRange))
    : [];

  const totals = periodTotals(current);
  const previousTotals = previousRange ? periodTotals(previous) : null;

  const effort = {};
  let warmupDone = 0;
  let warmupSkipped = 0;
  const byCategory = {};
  const notDone = [];
  for (const session of current) {
    for (const exercise of session.exercises || []) {
      if (exercise.isWarmup) {
        if (exercise.status === 'skipped') warmupSkipped += 1;
        else if (workSets(exercise).length > 0) warmupDone += 1;
        continue;
      }
      const normalized = normalizeEffort(exercise.perceivedEffort);
      if (normalized) effort[normalized] = (effort[normalized] || 0) + 1;
      if (exercise.status === 'skipped') notDone.push(exercise.exerciseName);
      const category = exercise.category || 'sem categoria';
      const sets = workSets(exercise);
      if (!byCategory[category]) byCategory[category] = { series: 0, volumeKg: 0 };
      byCategory[category].series += sets.length;
      byCategory[category].volumeKg += sets.reduce((sum, s) => sum + s.reps * s.weightKg, 0);
    }
  }
  for (const value of Object.values(byCategory)) value.volumeKg = round(value.volumeKg);

  const allExercises = summarizeExerciseHistory(history);
  const exercicios = [];
  for (const item of allExercises.values()) {
    const inPeriod = item.entries.filter((e) => inRange(e.date, range));
    if (inPeriod.length === 0) continue;
    const earlier = item.entries.filter((e) => e.date < range.start);
    const bestBefore = earlier.length ? Math.max(...earlier.map((e) => e.maxWeightKg)) : null;
    const bestE1rmBefore = earlier.length ? Math.max(...earlier.map((e) => e.bestE1rm)) : null;
    const maxWeight = Math.max(...inPeriod.map((e) => e.maxWeightKg));
    const bestE1rm = Math.max(...inPeriod.map((e) => e.bestE1rm));
    const last = earlier[earlier.length - 1];
    exercicios.push({
      nome: item.name,
      categoria: item.category,
      ...(item.cargaPorLado && { cargaPorLado: true }),
      ...(item.pesoCorporal && { pesoCorporal: true }),
      sessoes: inPeriod.length,
      series: inPeriod.reduce((sum, e) => sum + e.sets, 0),
      repeticoes: inPeriod.reduce((sum, e) => sum + e.reps, 0),
      volumeKg: round(inPeriod.reduce((sum, e) => sum + e.volume, 0)),
      cargaMaximaKg: maxWeight,
      melhor1rmEstimadoKg: round(bestE1rm),
      cargaMaximaAntesKg: bestBefore,
      ultimaCargaMaximaAntesKg: last ? last.maxWeightKg : null,
      novo: earlier.length === 0,
      recordeDeCarga: bestBefore !== null && maxWeight > bestBefore,
      recordeDe1rm: bestE1rmBefore !== null && bestE1rm > bestE1rmBefore,
    });
  }
  exercicios.sort((a, b) => b.volumeKg - a.volumeKg);

  const aumentos = events
    .filter((e) => isRealIncrease(e) && inRange(e.occurredAt, range))
    .map((e) => ({
      exercicio: e.exerciseName || e.exerciseId,
      tipo: e.type,
      de: e.previousValue ?? null,
      para: e.newValue ?? null,
      data: dateKey(e.occurredAt),
    }));

  return {
    periodo: {
      inicio: dateKey(range.start),
      fim: dateKey(new Date(range.end.getTime() - DAY_MS)),
    },
    totais: totals,
    periodoAnterior: previousTotals && {
      periodo: {
        inicio: dateKey(previousRange.start),
        fim: dateKey(new Date(previousRange.end.getTime() - DAY_MS)),
      },
      totais: previousTotals,
      variacaoPercentual: {
        sessoes: percentChange(totals.sessoes, previousTotals.sessoes),
        volumeKg: percentChange(totals.volumeKg, previousTotals.volumeKg),
        series: percentChange(totals.series, previousTotals.series),
      },
    },
    treinos: current.map((s) => ({
      data: dateKey(s.date),
      ficha: s.workoutName,
      duracaoMin:
        s.startAt && s.endAt ? Math.round((s.endAt - s.startAt) / 60000) : null,
      ...periodTotals([s]),
    })),
    aquecimento: { feitos: warmupDone, pulados: warmupSkipped },
    percepcao: effort,
    naoRealizados: notDone,
    porCategoria: byCategory,
    exercicios,
    aumentosRegistrados: aumentos,
    sessoesAntesDoPeriodo: before.length,
    ultimoTreinoAntes: before.length ? dateKey(before[before.length - 1].date) : null,
  };
}

/** Sessions before the Nova Era: kept only as the starting load of each exercise. */
function previousEra(sessions, since) {
  if (sessions.length === 0) return null;
  const pontoDePartida = [];
  for (const item of summarizeExerciseHistory(sessions).values()) {
    const last = item.entries[item.entries.length - 1];
    pontoDePartida.push({
      nome: item.name,
      categoria: item.category,
      ...(item.cargaPorLado && { cargaPorLado: true }),
      ...(item.pesoCorporal && { pesoCorporal: true }),
      sessoes: item.entries.length,
      ultimaData: dateKey(last.date),
      cargaKg: last.maxWeightKg,
      melhor1rmEstimadoKg: round(Math.max(...item.entries.map((e) => e.bestE1rm))),
    });
  }
  pontoDePartida.sort((a, b) => b.sessoes - a.sessoes);
  return {
    inicio: dateKey(sessions[0].date),
    fim: dateKey(sessions[sessions.length - 1].date),
    novaEraInicio: dateKey(since),
    totais: periodTotals(sessions),
    pontoDePartida,
  };
}

/**
 * Whole-history view: frequency, monthly series and long-term progression.
 * With `since` (start of the Nova Era) only later sessions count; earlier ones
 * become `eraAnterior` and each exercise gets its starting load.
 */
function computeOverallMetrics({ sessions, events = [], until, since = null }) {
  const all = finishedSessions(sessions).filter((s) => s.date < until);
  const history = since ? all.filter((s) => s.date >= since) : all;
  const eraAnterior = since ? previousEra(all.filter((s) => s.date < since), since) : null;
  const startLoads = new Map(
    eraAnterior ? eraAnterior.pontoDePartida.map((e) => [exerciseKey({ exerciseName: e.nome }), e.cargaKg]) : [],
  );
  if (history.length === 0) {
    return {
      inicio: since ? dateKey(since) : null,
      totais: periodTotals([]),
      meses: [],
      exercicios: [],
      eraAnterior,
    };
  }
  const first = since || history[0].date;
  const weeks = Math.max(1, (until - startOfDay(first)) / (7 * DAY_MS));

  const months = new Map();
  for (const session of history) {
    const key = dateKey(session.date).slice(0, 7);
    if (!months.has(key)) months.set(key, []);
    months.get(key).push(session);
  }

  const exercicios = [];
  for (const item of summarizeExerciseHistory(history).values()) {
    const firstEntry = item.entries[0];
    const lastEntry = item.entries[item.entries.length - 1];
    exercicios.push({
      nome: item.name,
      categoria: item.category,
      ...(item.cargaPorLado && { cargaPorLado: true }),
      ...(item.pesoCorporal && { pesoCorporal: true }),
      sessoes: item.entries.length,
      primeiraData: dateKey(firstEntry.date),
      ultimaData: dateKey(lastEntry.date),
      cargaInicialKg: firstEntry.maxWeightKg,
      cargaAtualKg: lastEntry.maxWeightKg,
      cargaMaximaKg: Math.max(...item.entries.map((e) => e.maxWeightKg)),
      melhor1rmEstimadoKg: round(Math.max(...item.entries.map((e) => e.bestE1rm))),
      pontoDePartidaKg: startLoads.get(item.key) ?? null,
    });
  }
  exercicios.sort((a, b) => b.sessoes - a.sessoes);

  return {
    eraAnterior,
    inicio: dateKey(first),
    ultimoTreino: dateKey(history[history.length - 1].date),
    totais: periodTotals(history),
    mediaSessoesPorSemana: round(history.length / weeks, 2),
    meses: [...months.entries()].map(([mes, list]) => ({ mes, ...periodTotals(list) })),
    exercicios,
    aumentosRegistrados: events.filter(
      (e) => isRealIncrease(e) && e.occurredAt < until && (!since || e.occurredAt >= since),
    ).length,
  };
}

module.exports = {
  weekRange,
  previousMonthRange,
  isFirstSundayOfMonth,
  estimatedOneRepMax,
  computePeriodMetrics,
  computeOverallMetrics,
  dateKey,
};
