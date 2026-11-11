# Arquitetura atual Vanguard

## Autenticacao

- Firebase Auth.
- Telas: `auth.dart`, `login.dart`, `register.dart`, `login_or_register.dart`.
- Servicos: `AuthService`, `UserService`, `UserProfileService`.
- Nao houve alteracao de autenticacao, Gemini, `.env`, applicationId ou assinatura.

## Usuario

- Caminho: `users/{uid}`.
- Responsabilidade: perfil basico e raiz das subcolecoes de dominio do usuario.

## Maquinas

- Caminho: `users/{uid}/machines/{exerciseId}`.
- Modelo: `MachineProfile`.
- Servico: `MachineService`.
- Telas: `MachinesScreen`, `MachineDetailScreen`.
- Campos principais: `exerciseId`, `exerciseName`, `category`, `ownerUid`, `currentSets`, `currentRepetitions`, `currentWeightKg`, `observation`, `completionCount`, `lastIncrease`, `previousIncrease`, campos de tracking, timestamps e `schemaVersion`.
- ID: `exerciseId` estavel do catalogo ou resolucao deterministica.
- Exclusao: nao ha limpeza fisica automatica nesta etapa.
- Compatibilidade: caminho legado `machine_history` nao e mais lido.

## Eventos

- Caminho: `users/{uid}/machines/{exerciseId}/events/{eventId}`.
- Modelo: `MachineEvent`.
- Servico: `MachineService` centraliza escrita e leitura paginada.
- Tipos: conclusao, aumento de peso, aumento de series, aumento de repeticoes, alteracao de OBS.
- IDs: `completion_{sessionId}` para conclusao; fingerprint deterministico para aumentos/OBS.
- Ordenacao: `occurredAt DESC`, `createdAt DESC`, `documentId DESC`.
- Eventos anulados: nao entram na linha ativa, simbolos, estatisticas ou auditoria de contador.

## Treinos

- Caminho: `users/{uid}/workouts/{workoutId}`.
- Modelo: `Workout`.
- Servico: `WorkoutService`.
- Telas: criacao, edicao e lista de treinos.
- Campos: `id`, `name`, `ownerUid`, `machineIds`, `createdAt`, `updatedAt`, `schemaVersion = 2`.
- ID: Firestore auto ID.
- Exclusao: exclusao fisica de treino via fluxo atual; historico de sessoes permanece independente.
- Compatibilidade: colecao raiz antiga `workouts` e `workout.exercises` nao sao lidos no fluxo ativo.

## Sessoes

- Caminho: `workout_history/{sessionId}`.
- Modelo: `WorkoutSession`, `ExerciseExecution`, `ExerciseSet`.
- Responsabilidade: snapshot independente da execucao.
- Compatibilidade: sessoes antigas continuam desserializando, inclusive formatos antigos de sets e percepcoes.
- Idempotencia: `machineHistoryCountApplied`/`machineCountApplied` impedem duplo processamento.

## Historico

- Tela: `history_screen.dart` e detalhe de sessao.
- Continua abrindo sessoes antigas por snapshot.
- Nao depende do documento atual do treino.

## Gemini

- Servicos e telas de analise permanecem separados do dominio Maquina/Treino/Sessao.
- Configuracao e chaves nao foram alteradas.

## Fluxos

1. Cadastrar Maquina: tela de Maquinas cria `MachineProfile` em `users/{uid}/machines`.
2. Criar treino: tela salva `Workout` schema 2 com lista ordenada de `machineIds`.
3. Iniciar sessao: treino resolve `machineIds` para `MachineProfile`; referencia ausente bloqueia execucao.
4. Aquecimento: cria execucao local com `isWarmup`, sem perfil proprio.
5. Executar: cada maquina gera snapshot de configuracao, OBS e sets realizados.
6. Finalizar: servico coordenado salva `workout_history/{sessionId}` e aplica eventos/contador.
7. Criar eventos: conclusao elegivel cria evento canonico; aumentos e OBS criam eventos manuais.
8. Incrementar contador: apenas percepcoes `light`, `adequate`, `high_fatigue`.
9. Abrir historico: le snapshot da sessao, incluindo sessoes antigas.
10. Registrar aumento: atualiza configuracao atual, cache `lastIncrease/previousIncrease` e evento.
# Atualização — Etapa 6 (catálogo global)

As definições atuais de Máquinas passaram a ter fonte principal em
`machine_catalog/{machineId}`. `users/{uid}/machines/{machineId}` contém apenas
estado pessoal; treinos continuam referenciando IDs e sessões são snapshots.
O catálogo local de 31 itens permanece exclusivamente como seed idempotente.
Consulte `ETAPA_6_CATALOGO_GLOBAL_DE_MAQUINAS.md` para campos, ciclo de vida e
regras de resolução.

# Atualização — Etapa 7 (treino livre, fase 1)

A execução aceita adicionar exercícios no meio (busca no catálogo ou criação
rápida com `origem = criacao_rapida`) e o aquecimento pode ser pulado
(`status = skipped`). A ficha não é alterada. Detalhes em
`ETAPA_7_TREINO_LIVRE.md`.

