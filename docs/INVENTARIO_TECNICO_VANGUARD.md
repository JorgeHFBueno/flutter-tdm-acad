# Inventario tecnico Vanguard

## Modelos

- `MachineProfile`: documento canonico da Maquina.
- `MachineIncrease`: cache de aumento da Maquina.
- `MachineEvent`: evento estruturado da Maquina.
- `Workout`: treino schema 2 por referencias a Maquinas.
- `WorkoutSession`: snapshot independente de sessao.
- `ExerciseExecution`: execucao de exercicio dentro da sessao.
- `ExerciseSet`: serie realizada.
- `ResolvedWorkoutMachines`: resolucao de referencias de treino.
- `ResolvedExerciseConfiguration`: configuracao efetiva da Maquina.

## Servicos

- `MachineService`: Maquinas, eventos, aumentos, OBS, contador e finalizacao coordenada.
- `WorkoutService`: CRUD e streams de treinos do usuario.
- `WorkoutHistoryService`: leitura de `workout_history`.
- `AuthService`: autenticacao.
- `UserService`: usuario basico.
- `UserProfileService`: perfil do usuario.
- `WorkoutAnalysisService`: analise Gemini.
- `WorkoutAnalysisLogService`: historico de analises.
- `NotificationService`: Firebase Messaging.

## Telas

- `MachinesScreen`: lista/cadastro de Maquinas.
- `MachineDetailScreen`: detalhes, eventos, OBS e aumentos da Maquina.
- `WorkoutCreationScreen`: cria treino por `machineIds`.
- `WorkoutEditScreen`: edita treino por `machineIds`.
- `WorkoutListScreen`: lista/inicia/edita/exclui treinos.
- `WorkoutExecutionScreen`: execucao, aquecimento, percepcoes e finalizacao.
- `HistoryScreen`: historico de sessoes.
- `WorkoutSessionDetailScreen`: detalhe de sessao.
- `WorkoutAnalysisHistoryScreen`: lista de analises.
- `WorkoutAnalysisDetailScreen`: detalhe de analise.
- `HomeScreen`, `menu2.dart`: navegacao principal.
- `login.dart`, `register.dart`, `auth.dart`: autenticacao.

## Rotas

- Navegacao principal por widgets em `menu2.dart`.
- Navegacao secundaria por `MaterialPageRoute` entre treino, execucao, maquinas e detalhes.

## Colecoes

- `users`: usuarios.
- `users/{uid}/machines`: Maquinas canonicas.
- `users/{uid}/workouts`: treinos schema 2.
- `workout_history`: sessoes historicas.
- `workout_analysis_logs`: logs de analise.

## Subcolecoes

- `users/{uid}/machines/{exerciseId}/events`: eventos estruturados da Maquina.

## Configuracao

- `pubspec.yaml`: dependencias, assets e versao `1.0.0+1`.
- `firebase.json`: configuracao Firebase, nao alterada na etapa.
- `firestore.rules`: regras lidas/auditadas, nao alteradas.
- `analysis_options.yaml`: lints.
- `.env`: carregado como asset, nao alterado.
- `android/app/build.gradle`: build Android.

## Testes

- `exercise_catalog_test.dart`: catalogo e IDs.
- `machine_history_test.dart`: Maquinas, eventos, contador, baseline e configuracao.
- `machine_observation_lifecycle_test.dart`: OBS e ciclo de vida.
- `workout_model_test.dart`: treino schema 2.
- `workout_execution_flow_test.dart`: fluxo puro de execucao.
- `workout_execution_widget_test.dart`: fluxo critico de widget.
- `workout_session_model_test.dart`: sessoes novas e antigas.
- `widget_test.dart`: smoke test do catalogo compartilhado.

## Documentos tecnicos

- `ETAPA_1_MAQUINAS_ENTIDADE_PRINCIPAL.md`: base da entidade Maquina.
- `ETAPA_2_CONFIGURACAO_ATUAL_DAS_MAQUINAS.md`: configuracao atual.
- `ETAPA_3_TREINOS_COM_REFERENCIAS_DE_MAQUINAS.md`: treinos por referencias.
- `ETAPA_4_EVENTOS_COMPLETOS_DAS_MAQUINAS.md`: eventos estruturados.
- `ETAPA_5_CONSOLIDACAO_TECNICA.md`: consolidacao atual.
- `ARQUITETURA_ATUAL_VANGUARD.md`: arquitetura final atual.
- `INVENTARIO_TECNICO_VANGUARD.md`: inventario tecnico.

