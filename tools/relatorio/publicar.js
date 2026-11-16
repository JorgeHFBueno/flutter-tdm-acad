#!/usr/bin/env node
// Saves a written analysis to workout_analysis_logs and sends the push.
// Usage: node publicar.js --tipo semanal|mensal|geral --titulo "..." \
//          --periodo "semanal (09/11 a 15/11)" --arquivo analise.md [--sem-push]

const fs = require('node:fs');
const { init, admin } = require('./firestore');

const TYPES = new Set(['semanal', 'mensal', 'geral']);

function parseArgs(argv) {
  const args = { push: true };
  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    if (flag === '--sem-push') args.push = false;
    else if (flag.startsWith('--')) args[flag.slice(2)] = argv[++i];
  }
  return args;
}

async function sendPush(db, messaging, uid, body) {
  const userRef = db.collection('users').doc(uid);
  const tokens = ((await userRef.get()).data() || {}).fcmTokens || [];
  if (tokens.length === 0) return { sent: 0, invalid: 0 };
  const result = await messaging.sendEachForMulticast({
    tokens,
    notification: { title: 'Vanguard', body },
    data: { route: 'analises' },
    android: { priority: 'high' },
  });
  const invalid = tokens.filter((_, i) => {
    const code = result.responses[i].error?.code;
    return (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token'
    );
  });
  if (invalid.length) {
    await userRef.update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalid) });
  }
  return { sent: result.successCount, invalid: invalid.length };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!TYPES.has(args.tipo)) throw new Error('--tipo deve ser semanal, mensal ou geral');
  if (!args.titulo || !args.periodo || !args.arquivo) {
    throw new Error('Informe --titulo, --periodo e --arquivo');
  }
  const response = fs.readFileSync(args.arquivo, 'utf8').trim();
  if (!response) throw new Error('Arquivo de análise vazio');

  const { db, messaging, uid } = init();
  const ref = await db.collection('workout_analysis_logs').add({
    ownerUid: uid,
    workoutId: null,
    workoutName: args.titulo,
    type: args.tipo,
    prompt: `Relatório ${args.tipo} gerado pela tarefa agendada do Claude`,
    response,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const push = args.push
    ? await sendPush(db, messaging, uid, `Sua análise ${args.periodo} está disponível`)
    : { sent: 0, invalid: 0, skipped: true };
  console.log(JSON.stringify({ logId: ref.id, push }));
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
