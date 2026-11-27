#!/usr/bin/env node
// Prints the metrics JSON for the reports due on a given date.
// Usage: node coletar.js [--data AAAA-MM-DD] [--forcar-mensal]
//   Without --data the reference is the most recent Sunday (today if Sunday).
//   Always includes "semanal". On the first Sunday of the month (or with
//   --forcar-mensal) also includes "mensal" (previous month) and "geral".

const { init, loadSessions, loadEvents, loadEraStart, loadProfile } = require('./firestore');
const m = require('./metricas');

function parseArgs(argv) {
  const args = { data: null, forcarMensal: false };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--data') args.data = argv[++i];
    else if (argv[i] === '--forcar-mensal') args.forcarMensal = true;
  }
  return args;
}

// The scheduled run may start late (app closed on Sunday): report the week
// that ended on the most recent Sunday, never the one just starting.
function lastSunday(now) {
  return new Date(now.getFullYear(), now.getMonth(), now.getDate() - now.getDay(), 19);
}

function fmt(key) {
  const [y, mo, d] = key.split('-');
  return `${d}/${mo}/${y}`;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const ref = args.data ? new Date(`${args.data}T19:00:00`) : lastSunday(new Date());
  const { db, uid } = init();
  const [sessions, events, eraStart, profile] = await Promise.all([
    loadSessions(db, uid),
    loadEvents(db, uid),
    loadEraStart(db, uid),
    loadProfile(db, uid),
  ]);

  const week = m.weekRange(ref);
  const previousWeek = {
    start: new Date(week.start.getTime() - 7 * 86400000),
    end: week.start,
  };
  const semanal = m.computePeriodMetrics({ sessions, events, range: week, previousRange: previousWeek, profile });
  const relatorios = {
    semanal: {
      titulo: `Análise semanal ${fmt(semanal.periodo.inicio)} a ${fmt(semanal.periodo.fim)}`,
      periodoTexto: `semanal (${fmt(semanal.periodo.inicio).slice(0, 5)} a ${fmt(semanal.periodo.fim).slice(0, 5)})`,
      metricas: semanal,
    },
  };

  if (args.forcarMensal || m.isFirstSundayOfMonth(ref)) {
    const month = m.previousMonthRange(ref);
    const previousMonth = m.previousMonthRange(month.start);
    const mensal = m.computePeriodMetrics({ sessions, events, range: month, previousRange: previousMonth, profile });
    const monthLabel = month.start.toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' });
    relatorios.mensal = {
      titulo: `Análise mensal ${monthLabel}`,
      periodoTexto: `mensal (${monthLabel})`,
      metricas: mensal,
    };
    relatorios.geral = {
      titulo: `Análise geral até ${fmt(m.dateKey(ref))}`,
      periodoTexto: 'geral',
      metricas: m.computeOverallMetrics({ sessions, events, until: week.end, since: eraStart, profile }),
    };
  }

  process.stdout.write(
    JSON.stringify({ geradoEm: new Date().toISOString(), referencia: m.dateKey(ref), relatorios }, null, 2),
  );
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
