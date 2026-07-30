# Etapa 2 - Configuracao atual das Maquinas

## Objetivo

Tornar a entidade `MachineProfile` a fonte principal da configuracao atual de cada exercicio: series, repeticoes, peso e OBS.

O documento canonico continua sendo:

`users/{uid}/machines/{exerciseId}`

O caminho legado continua como fallback progressivo:

`users/{uid}/machine_history/{exerciseId}`

## Fonte unica da configuracao

Os campos oficiais da configuracao atual sao:

- `currentSets`
- `currentRepetitions`
- `currentWeightKg`
- `observation`

`WorkoutExercise.defaultWeightKg` foi preservado somente como snapshot/fallback temporario. Treinos ainda nao foram convertidos para listas puras de referencias.

## Validacoes

Series atuais e repeticoes atuais aceitam apenas inteiro positivo. Valor vazio e permitido para maquinas legadas/incompletas, mas novas maquinas manuais e maquinas selecionadas em treino devem ser completadas antes de salvar.

Peso atual aceita decimal com virgula ou ponto e e persistido como numero (`double`). Valores antigos em `int` continuam legiveis.

OBS e opcional. Valor vazio salva OBS canonica vazia, impedindo que uma OBS legada volte pelo fallback.

## Compatibilidade canonico/legado

A regra permanece:

1. documento canonico prevalece;
2. documento legado e fallback;
3. edicoes materializam o documento canonico quando necessario;
4. contador, OBS, ultimo aumento e penultimo aumento sao preservados ao materializar.

Campos antigos nao sao removidos dos treinos ou sessoes.

## Criacao e edicao

Na tela de Maquinas, novas maquinas pedem series, repeticoes, peso e OBS opcional. A tela de detalhes permite editar a configuracao atual sem apagar contador ou aumentos.

Criacao e edicao de treinos carregam as maquinas do usuario uma vez, indexam por `exerciseId` e exibem a configuracao atual de forma compacta. Ao salvar, a maquina e criada ou completada quando necessario, mantendo `defaultWeightKg` como fallback temporario.

## Execucao

Ao iniciar a execucao, as maquinas sao carregadas uma vez e a configuracao inicial e copiada para snapshots opcionais na sessao:

- `configuredSets`
- `configuredRepetitions`
- `configuredWeightKg`
- `observationSnapshot`

A primeira serie usa `currentRepetitions` e `currentWeightKg` quando disponiveis. Series seguintes continuam usando a ultima serie registrada. `currentSets` e exibido como referencia e nao bloqueia a conclusao.

Editar configuracao atual durante a execucao atualiza a maquina canonica e o estado local, sem alterar series ja registradas e sem registrar aumento.

## Aumentos

Registrar novo aumento usa transacao e atualiza atomica e simultaneamente:

- `lastIncrease`
- `previousIncrease`
- o campo atual correspondente (`currentWeightKg`, `currentSets` ou `currentRepetitions`)
- `updatedAt`

Corrigir ou limpar manualmente `lastIncrease` ou `previousIncrease` nao altera a configuracao atual.

## Peso decimal e volume

`WorkoutExercise.defaultWeightKg` e `ExerciseSet.weightKg` aceitam `double`. Leituras antigas com `int` continuam validas. O calculo de volume usa os pesos efetivamente realizados na sessao, nao a configuracao atual da maquina.

## Gemini e historico

O historico continua independente da maquina atual. Quando existe snapshot, os detalhes e prompts da IA usam a configuracao esperada salva na propria sessao.

## Arquivos alterados

- `lib/models/machine_configuration.dart`: resolvedor puro, parsing e formatacao.
- `lib/models/machine_history.dart`: aumento atualiza configuracao atual.
- `lib/models/workout.dart`: peso fallback decimal.
- `lib/models/workout_session.dart`: peso realizado decimal e snapshots opcionais.
- `lib/services/machine_history_service.dart`: `updateCurrentConfiguration`, materializacao e aumento atomico.
- `lib/screens/machine_history_screen.dart`: cadastro/edicao da configuracao.
- `lib/screens/workout_creation_screen.dart`: consulta e materializacao da maquina ao criar treino.
- `lib/screens/workout_edit_screen.dart`: consulta e atualizacao da maquina ao editar treino.
- `lib/screens/workout_execution_screen.dart`: carregamento de maquinas, snapshots, primeira serie e edicao durante execucao.
- `lib/screens/history_screen.dart`: volume decimal e snapshot no prompt historico.
- `lib/screens/workout_session_detail_screen.dart`: snapshot no detalhe e prompt da sessao.
- `test/machine_history_test.dart`: resolucao de configuracao e aumentos.
- `test/workout_session_model_test.dart`: snapshot e peso decimal.

## Testes

Foram adicionados testes puros para:

- precedencia da maquina sobre `defaultWeightKg`;
- fallback seguro quando a maquina nao existe;
- aumento de peso, series e repeticoes atualizando campos atuais;
- sessao com snapshot de configuracao;
- sessao antiga sem snapshot;
- volume com peso decimal.

## Limitacoes

Ainda nao foram implementados:

- treino como lista pura de referencias;
- remocao de `defaultWeightKg`;
- historico ilimitado de eventos;
- interface estilo Google Keep;
- progressao automatica.
