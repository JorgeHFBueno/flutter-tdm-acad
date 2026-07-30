# Etapa 4 - Eventos completos das Maquinas

## Objetivo

Criar o historico estruturado de eventos das Maquinas em:

```text
users/{uid}/machines/{exerciseId}/events/{eventId}
```

A Maquina continua sendo a fonte do estado atual, com `completionCount`,
configuracao atual, OBS, `lastIncrease` e `previousIncrease`. A sessao continua
como snapshot independente em `workout_history/{sessionId}`.

## Modelo de eventos

O modelo tipado e `MachineEvent`, com `schemaVersion = 1`.

Tipos internos:

- `completion`
- `weight_increased`
- `sets_increased`
- `repetitions_increased`
- `observation_changed`

Campos comuns:

- `exerciseId`
- `ownerUid`
- `type`
- `occurredAt`
- `createdAt`
- `schemaVersion`
- `source`

Eventos de conclusao salvam resumo da execucao e referencia a `sessionId`, sem
duplicar a sessao completa. Eventos de aumento salvam `increaseType`,
`previousValue` e `newValue`. Eventos de OBS salvam `previousObservation` e
`newObservation`.

## Baseline

Foram adicionados ao `MachineProfile`:

- `eventTrackingStartedAt`
- `eventTrackingBaselineCount`
- `increaseEventsInitializedAt`
- `eventSchemaVersion`

`eventTrackingBaselineCount` e definido uma unica vez. Maquinas novas começam
com baseline `0`. Maquinas existentes recebem o `completionCount` atual quando
o rastreamento e inicializado. Nao sao criados eventos falsos de conclusao para
o passado.

## Aumentos existentes

`lastIncrease` e `previousIncrease` existentes sao copiados de forma
idempotente para a subcolecao `events`, usando IDs deterministicos com prefixo
`legacy_increase_`. O fingerprint considera `exerciseId`, tipo, valor e data.
Nao usa `hashCode`, valor aleatorio ou data de criacao atual.

`lastIncrease` e `previousIncrease` permanecem no documento da Maquina como
cache para exibicao rapida durante a execucao.

## Conclusoes

Ao finalizar treino, a transacao salva a sessao e cria um evento de conclusao
por Maquina normal concluida com percepcao final. Aquecimento, pendencias sem
resultado, percepcao ausente, ID invalido e duplicidade da mesma Maquina na
sessao nao geram evento.

O contador continua incrementando somente para:

- `light`
- `adequate`
- `high_fatigue`

Tambem geram evento, sem incrementar contador:

- `reduced_reps`
- `reduced_weight`
- `skipped_fatigue`
- `skipped_other`

O ID de conclusao e `completion_{sessionId}` dentro da subcolecao da Maquina.

## Simbolos

Os simbolos sao derivados de `perception`:

- `light` -> `|`
- `adequate` -> `|`
- `high_fatigue` -> `|`
- `reduced_reps` -> `!`
- `reduced_weight` -> `¡`
- `skipped_fatigue` -> `i`
- `skipped_other` -> `i`

Valor desconhecido usa `?` e nao incrementa contador.

## Linha historica

A tela de detalhes combina:

1. barras derivadas de `eventTrackingBaselineCount`;
2. simbolos de eventos novos em ordem cronologica.

Isso evita dupla contagem: a linha nao usa `completionCount` total mais eventos.
O `completionCount` segue exibido numericamente.

## OBS

Alterar OBS cria evento apenas quando o texto muda. Salvar o mesmo valor nao
cria evento. Limpar OBS cria evento com novo valor vazio e a interface exibe
`Sem OBS`.

## Idempotencia

- Inicializacao pode ser repetida sem duplicar aumentos copiados.
- Aumentos usam ID deterministico e gravam `eventId` opcional no cache novo.
- Conclusoes usam `completion_{sessionId}`.
- A transacao de finalizacao respeita `machineHistoryCountApplied` e
  `machineCountApplied`.
- A tela de detalhes bloqueia duplo toque durante escritas de OBS/aumento.
- Ao limpar aumento, o evento associado e marcado com `isDeleted` e `voidedAt`
  quando a relacao e inequivoca pelo `eventId` ou fingerprint legado. Essa
  estrategia evita apagar historico possivelmente diferente.

## Paginacao e interface

A lista geral de Maquinas nao carrega eventos e continua exibindo contador,
ultimo aumento e penultimo aumento.

A tela de detalhes inicializa o rastreamento da Maquina, carrega os 50 eventos
mais recentes e oferece `Carregar mais`. Os filtros locais sao:

- Todos
- Execucoes
- Aumentos
- OBS

A interface principal de execucao permanece exibindo somente configuracao, OBS,
ultimo aumento e penultimo aumento.

## Arquivos alterados

- `lib/models/machine_event.dart`: modelo de evento, simbolos, IDs e resumo.
- `lib/models/machine_history.dart`: campos de tracking e linha historica.
- `lib/services/machine_history_service.dart`: inicializacao, eventos,
  transacoes e paginacao.
- `lib/screens/machine_history_screen.dart`: detalhes com historico completo.
- `lib/screens/workout_execution_screen.dart`: envio dos resultados
  estruturados para a finalizacao.
- `test/machine_history_test.dart`: testes puros dos modelos e regras.

## Testes

Foram adicionados testes para serializacao/desserializacao de eventos, simbolos,
resumos de conclusao, elegibilidade, IDs deterministicos e linha historica.

## Limitacoes

Ainda nao foram implementados:

- interface estilo Google Keep;
- progressao automatica;
- graficos;
- Machine Learning.

Nao ha migracao em massa, varredura de `workout_history`, criacao retroativa de
conclusoes antigas, deploy ou alteracao retroativa de sessoes.
