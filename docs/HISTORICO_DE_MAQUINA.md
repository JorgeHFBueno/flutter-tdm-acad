# Histórico de Máquina

## Finalidade

O Histórico de Máquina mantém o estado acumulado de um exercício para um usuário: contador de conclusões válidas, OBS atual, último aumento e penúltimo aumento.

Ele não substitui o Histórico de Treino.

## Dois históricos

Histórico de Treino:
- sessão completa executada;
- treino, data, aquecimento, exercícios, séries, cargas, percepções e volume;
- persistido em `workout_history`.

Histórico de Máquina:
- estado acumulado por exercício;
- contador, OBS atual, último aumento e penúltimo aumento;
- persistido em `users/{uid}/machine_history/{exerciseId}`.

## Firestore

Cada documento representa um único exercício de um único usuário:

```text
users/{uid}/machine_history/{exerciseId}
```

O ID do documento é o `exerciseId`. Não são usados IDs automáticos para esse módulo.

Campos principais:
- `exerciseId`
- `exerciseName`
- `category`
- `ownerUid`
- `completionCount`
- `observation`
- `lastIncrease`
- `previousIncrease`
- `createdAt`
- `updatedAt`

## Modelos

`MachineHistory` representa o documento acumulado.

`MachineIncrease` representa um aumento manual com:
- `type`
- `value`
- `date`

Tipos internos:
- `weight`
- `sets`
- `repetitions`

Rótulos visíveis:
- Peso
- Séries
- Repetições

## IDs Estáveis

`ExerciseCatalogItem` possui `id`, `name` e `category`.

Novos treinos salvam `WorkoutExercise.exerciseId`.

Novas sessões salvam `ExerciseExecution.exerciseId`.

IDs não dependem de posição na lista nem de `hashCode`.

## Compatibilidade Legada

Treinos antigos podem não ter `exerciseId`.

A resolução segue:
- usa `exerciseId` quando existir;
- procura por nome e categoria no catálogo;
- procura por nome quando não houver ambiguidade;
- gera fallback determinístico `legacy__nome__categoria`.

Documentos antigos não são atualizados em massa. Quando um treino antigo é salvo pela edição, o ID resolvido passa a ser gravado.

## Contador

A contagem acontece somente ao tocar em `Concluir treino`.

Regra:

```text
Concluir treino
  -> filtrar exercícios normais com light | adequate | high_fatigue
  -> deduplicar por exerciseId
  -> salvar sessão e incrementar contadores de forma idempotente
```

Percepções que contam:
- `light`
- `adequate`
- `high_fatigue`

Percepções que não contam:
- `reduced_reps`
- `reduced_weight`
- `skipped_fatigue`
- `skipped_other`
- ausente
- desconhecida

Compatibilidade documentada: valores legados `leve`, `certo` e `fadiga` são normalizados para `light`, `adequate` e `high_fatigue` antes da decisão.

Aquecimento não incrementa contador.

Cada `exerciseId` conta no máximo uma vez por sessão.

## Idempotência

A tela de execução cria uma referência estável de sessão antes de salvar.

`MachineHistoryService.saveSessionAndApplyMachineCounts` usa transação:
- verifica `machineHistoryCountApplied`;
- salva a sessão;
- incrementa históricos elegíveis;
- cria histórico ausente quando necessário;
- marca a sessão como processada.

Retry e duplo toque não devem duplicar contagem.

## OBS

A fonte persistente única da OBS é:

```text
users/{uid}/machine_history/{exerciseId}.observation
```

A OBS pode ser editada:
- na criação do treino;
- na edição do treino;
- durante a execução;
- nos detalhes do Histórico de Máquina.

Alterar OBS substitui o valor anterior, não concatena e não grava em `workouts` nem em `workout_history`.

Quando uma OBS é salva para exercício sem histórico, o histórico é criado automaticamente com contador zero e aumentos vazios.

## Aumentos

O histórico guarda somente último e penúltimo aumento.

Ao registrar novo aumento:
- último atual vira penúltimo;
- novo aumento vira último;
- penúltimo antigo é descartado.

Na criação manual é possível informar penúltimo e último aumento inicialmente. Ambos são opcionais.

Datas são salvas como `Timestamp` e exibidas como `dd/MM` ou `dd/MM/yyyy` quando necessário.

## Marcas

As conclusões são exibidas com marcas `|`, agrupadas em blocos de cinco:

```text
0 -> vazio
1 -> |
5 -> |||||
6 -> ||||| |
13 -> ||||| ||||| |||
```

O número exato também é exibido.

## Submenu

O drawer possui submenu:

```text
Histórico
  Histórico de Treino
  Histórico de Máquina
```

Histórico de Treino abre a tela atual. Histórico de Máquina abre a nova tela.

## Arquivos Criados

- `lib/models/machine_history.dart`
- `lib/services/machine_history_service.dart`
- `lib/screens/machine_history_screen.dart`
- `test/machine_history_test.dart`
- `docs/HISTORICO_DE_MAQUINA.md`

## Arquivos Alterados

- `lib/data/exercise_catalog.dart`
- `lib/models/workout.dart`
- `lib/models/workout_session.dart`
- `lib/models/workout_execution_flow.dart`
- `lib/screens/workout_creation_screen.dart`
- `lib/screens/workout_edit_screen.dart`
- `lib/screens/workout_execution_screen.dart`
- `lib/menu2.dart`
- testes existentes de catálogo e sessão.

## Testes

Os testes cobrem IDs do catálogo, resolução legada, serialização dos modelos, formatação, regras de aumentos, marcas e regras puras do contador.

Não há teste conectado ao Firebase real.

## Limitações

Não há importação retroativa de `workout_history`.

Não há ajuste manual do contador.

As regras atuais do Firestore foram apenas lidas para compatibilidade e não foram alteradas.
