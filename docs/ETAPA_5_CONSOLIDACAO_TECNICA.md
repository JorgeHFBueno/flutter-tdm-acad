# Etapa 5 - Consolidacao tecnica

## Objetivo

Consolidar a arquitetura atual do Vanguard sem criar funcionalidades novas e sem alterar os fluxos aprovados nas etapas 1 a 4.

## Baseline

- Worktree inicial ja continha alteracoes em Android, web, `firebase.json`, `pubspec.*`, telas, servicos, testes e docs.
- Testes iniciais: 85 testes passando.
- `flutter analyze` inicial: 1 warning em `lib/main.dart` por import nao usado de `firebase_messaging`; 58 infos; 0 erros.
- Versao atual do app: `1.0.0+1`. Recomendacao futura: incrementar build number antes de distribuicao.

## Legado identificado

| Item | Referencias | Necessario fluxo atual | Necessario sessao antiga | Pode remover | Acao |
| --- | --- | --- | --- | --- | --- |
| Alias `MachineHistory` | `lib/models/machine_history.dart` | Nao | Nao | Sim | Removido |
| Alias `MachineHistoryService` | `lib/services/machine_history_service.dart` | Nao | Nao | Sim | Removido |
| Alias `MachineHistoryCompletion` | `lib/services/machine_history_service.dart` | Nao | Nao | Sim | Removido |
| Colecao `users/{uid}/machine_history` | `MachineService` | Nao | Nao | Sim | Fallback removido |
| `WorkoutExercise` | Modelo e testes | Nao | Nao | Sim | Classe e testes removidos |
| `defaultWeightKg` | Modelo/testes antigos | Nao | Sessao antiga usa `ExerciseSet.weightKg`, nao `WorkoutExercise` | Sim | Fallback removido |
| Colecao raiz `workouts` | Nenhuma referencia ativa | Nao | Nao | Nao aplicavel | Mantido sem uso |
| Arquivos `machine_history.*` | Imports ativos | Sim, por risco de diff fisico | Sim indiretamente para modelos atuais | Nao nesta etapa | Nome fisico mantido e documentado |

## Legado removido

- Leitura/observacao do caminho `users/{uid}/machine_history/{exerciseId}`.
- Merge entre perfil canonico e perfil legado.
- `WorkoutExercise` e helpers ligados a `defaultWeightKg`.
- Nomes publicos `MachineHistoryScreen` e `MachineHistoryDetailScreen`, substituidos por `MachinesScreen` e `MachineDetailScreen`.

## Legado mantido

- Nome fisico de arquivos `machine_history.dart`, `machine_history_service.dart` e `machine_history_screen.dart`, para evitar renomeacao ampla em worktree ja modificado.
- Campo `machineHistoryCountApplied` em `WorkoutSession`, porque sessoes antigas ainda podem depender dele para desserializacao/idempotencia.
- IDs `legacy__...` do catalogo, apenas como resolucao deterministica para exercicios fora do catalogo, nao como colecao legada.

## Servicos e Firestore

- `MachineService`: maquinas canonicas, eventos, OBS, aumentos, contador, inicializacao de tracking e finalizacao coordenada de sessao/eventos.
- `WorkoutService`: `users/{uid}/workouts`, schema 2, listar/observar/criar/editar/excluir/buscar.
- `workout_history_service.dart`: leitura do historico raiz `workout_history`.
- Chamadas diretas a Firestore ainda existem em telas de historico/autenticacao legadas; nao foram movidas quando nao havia servico claro ou quando seria refatoracao fora de escopo.

## Erros, envio e ciclo de vida

- Acoes criticas revisadas usam flags como `_isSaving`, `_isLoading`, `_isWritingMachineEvent` e `mounted` antes de atualizar UI depois de `await`.
- Controllers revisados possuem `dispose`.
- Mensagens de erro seguem linguagem de usuario; detalhes tecnicos nao sao exibidos.
- Nenhum sistema offline novo foi introduzido.

## Eventos

- Eventos canonicos ficam em `users/{uid}/machines/{exerciseId}/events/{eventId}`.
- Conclusao usa `completion_{sessionId}`.
- Aumentos usam fingerprint deterministico com `exerciseId`, tipo, valor e data UTC; retries com o mesmo objeto de aumento preservam ID.
- OBS usa fingerprint de transicao; valor igual nao cria evento.
- Eventos anulados sao removidos da linha ativa, dos simbolos e da auditoria de contador.

## Paginacao

Ordenacao atual de eventos:

1. `occurredAt DESC`
2. `createdAt DESC`
3. `documentId DESC`

Essa ordenacao da cursor deterministico para `startAfterDocument`. Pode exigir indice composto na subcolecao `events`.

## Baseline

Foi adicionada funcao pura de auditoria:

`completionCount == eventTrackingBaselineCount + eventos ativos elegiveis`

Ela detecta divergencia sem sobrescrever dados reais.

## Analyze

- Warning inicial removido: import nao usado de `firebase_messaging` em `lib/main.dart`.
- Resultado final: 0 erros, 0 warnings, 60 infos.
- Infos mantidas: dependencias Firebase/Gemini/Intl/SVG estao em `dev_dependencies`; prints e lints antigos em telas fora do escopo; constructors/key em widgets antigos; `BuildContext` em `register.dart` nao alterado para evitar tocar autenticacao.

## Testes

- Testes finais: 83 passando.
- Removidos testes que preservavam `WorkoutExercise`.
- Adicionados/refocados testes para machineIds compartilhados, ausencia de fallback de treino, ordenacao de eventos, eventos anulados e auditoria de baseline.

## Regras

`firestore.rules` foi lido e nao alterado.

Risco encontrado: regra global permite leitura publica de qualquer documento e escrita por qualquer usuario autenticado em qualquer caminho. Isso nao garante isolamento por UID nem protege `ownerUid`, maquinas, treinos, eventos ou historico.

## Indices

Nao existe `firestore.indexes.json`.

Consulta potencialmente dependente de indice: subcolecao `events` ordenada por `occurredAt DESC`, `createdAt DESC` e `documentId DESC`, com paginacao.

## Builds

- Debug APK: compilou em `build/app/outputs/flutter-apk/app-debug.apk`.
- Release APK: primeira tentativa excedeu 5 minutos do executor; segunda tentativa compilou em `build/app/outputs/flutter-apk/app-release.apk` com 51,5 MB.
- App bundle: nao executado; APK release ja estava configurado e passou.

## Limitacoes

- Validacao manual nao foi executada contra Firebase real nesta etapa; deve seguir a lista de validacao do pedido.
- Nenhuma migracao, deploy, exclusao de documento, commit ou push foi executado.
