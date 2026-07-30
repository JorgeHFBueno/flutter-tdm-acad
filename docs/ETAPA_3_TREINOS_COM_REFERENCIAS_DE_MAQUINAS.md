# Etapa 3 - Treinos com referencias de Maquinas

## Objetivo

O treino deixa de armazenar configuracao propria de exercicios e passa a ser uma lista ordenada de referencias para Maquinas cadastradas pelo usuario.

Arquitetura desta etapa:

- `users/{uid}/machines/{exerciseId}`: estado atual da Maquina.
- `users/{uid}/workouts/{workoutId}`: nome do treino e lista ordenada de `machineIds`.
- `workout_history/{sessionId}`: snapshot completo e independente da sessao.

## Novo modelo Workout

Campos do documento novo:

- `name`
- `ownerUid`
- `machineIds`
- `createdAt`
- `updatedAt`
- `schemaVersion`

`schemaVersion` usa valor `2`. `machineIds` preserva a ordem da ficha, remove duplicados na camada de modelo/validacao e nao aceita lista vazia na validacao de criacao/edicao.

Campos removidos do treino como fonte de dados:

- nome duplicado da Maquina
- categoria duplicada
- peso
- series
- repeticoes
- OBS
- aumentos
- contador

## Caminho canonico

O caminho canonico dos treinos novos e `users/{uid}/workouts/{workoutId}`. As regras atuais permitem leitura ampla e escrita autenticada, entao nao foi necessario alterar `firestore.rules`.

O `WorkoutService` centraliza listagem, observacao, criacao, atualizacao, exclusao fisica e busca por ID. O servico lista somente documentos com `schemaVersion == 2`.

## Criacao

A tela de criacao carrega as Maquinas do usuario uma vez pelo `MachineService`. O usuario seleciona Maquinas existentes, define a ordem com botoes de mover para cima/baixo e salva o treino.

A tela nao usa mais o catalogo diretamente, nao cria Maquinas automaticamente e nao altera configuracao atual. Se nao houver Maquinas, mostra estado vazio com acao para abrir a tela de Maquinas.

## Edicao

A edicao permite somente:

- alterar nome;
- adicionar Maquinas existentes;
- remover Maquinas;
- alterar ordem.

Series, repeticoes, peso, OBS, aumentos e contador continuam pertencendo a Maquina. A tela mostra a configuracao atual como leitura e informa que ela e compartilhada por todos os treinos.

## Execucao

A execucao usa `Workout.machineIds` e `MachineProfile` resolvido. Para cada Maquina e criado um `ExerciseExecution` em memoria com snapshot de:

- `exerciseId`;
- nome;
- categoria;
- series configuradas;
- repeticoes configuradas;
- peso configurado;
- OBS inicial;
- series realizadas;
- percepcao;
- conclusao.

A ordem inicial vem de `machineIds`. A reordenacao durante a sessao continua temporaria e nao altera o treino salvo.

## Aquecimento

O aquecimento continua como primeiro passo:

- inicialmente aparece apenas Aquecimento;
- o seletor mostra somente Maquinas presentes no treino;
- a conclusao do aquecimento libera somente a Maquina escolhida;
- depois de concluir a Maquina alvo, o restante e liberado.

Nao existe Maquina chamada Aquecimento.

## Snapshots e historico

A sessao continua sendo snapshot independente em `workout_history`. O historico abre sessoes antigas sem depender do treino ou da Maquina atuais.

Excluir um treino remove somente o documento do treino novo. Maquinas e sessoes sao preservadas.

## Referencias ausentes

Se um treino apontar para Maquina removida ou inacessivel, a listagem indica referencia ausente e bloqueia o inicio. A edicao permite remover a referencia ausente.

## Treinos antigos

Nao ha migracao automatica, leitura dupla ou conversao dos treinos antigos. Documentos antigos nao sao apagados automaticamente. Se estiverem no caminho antigo, ficam ignorados pelo novo fluxo. Se aparecerem no caminho novo sem `schemaVersion == 2`, o `WorkoutService` nao os lista.

Os dois treinos antigos conhecidos serao recriados manualmente pelo usuario.

## Arquivos alterados

- `lib/models/workout.dart`: novo modelo `Workout` com `machineIds` e `schemaVersion = 2`.
- `lib/models/workout_execution_flow.dart`: entradas de execucao baseadas em `MachineProfile`.
- `lib/models/workout_machine_resolution.dart`: resolucao em memoria e identificacao de referencias ausentes.
- `lib/services/workout_service.dart`: caminho canonico e formato novo.
- `lib/screens/workout_creation_screen.dart`: selecao de Maquinas existentes.
- `lib/screens/workout_edit_screen.dart`: edicao de nome/lista/ordem.
- `lib/screens/workout_list_screen.dart`: resolucao eficiente de Maquinas e bloqueio de referencias ausentes.
- `lib/screens/workout_execution_screen.dart`: execucao baseada em Maquinas e snapshot de sessao.
- `lib/screens/home_screen.dart`: uso de `machineIds.length`.
- `lib/screens/history_screen.dart`: checagem de treinos ativos pelo `WorkoutService`.
- `test/workout_model_test.dart`: testes do novo modelo.
- `test/workout_execution_flow_test.dart`: testes do fluxo com Maquinas.
- `test/workout_execution_widget_test.dart`: testes de aquecimento com Maquinas resolvidas.

## Testes

Foram atualizados testes sem Firebase real para modelo, resolucao, ordem, snapshot, aquecimento, referencias ausentes e regressao do fluxo de execucao. Os testes existentes de Maquinas, OBS, aumentos, contador, idempotencia, percepcoes, aquecimento, volume e peso decimal permanecem.

## Limitacoes

Ainda nao foram implementados:

- eventos ilimitados;
- simbolos visuais derivados das percepcoes;
- interface estilo Google Keep;
- progressao automatica;
- graficos;
- Machine Learning.

Nao foram executados deploy, commit, push, migracao, exclusao de documentos ou limpeza automatica.

## Validacao manual documentada

Nao foi executada validacao contra Firebase real para evitar migracao, exclusao ou operacao administrativa. Checklist recomendado em ambiente controlado:

1. Confirmar que treinos antigos nao aparecem no novo fluxo.
2. Abrir Maquinas e confirmar configuracoes atuais intactas.
3. Criar Treino A selecionando Maquinas existentes e ordenando a ficha.
4. Criar Treino B reutilizando uma Maquina do Treino A.
5. Alterar a Maquina na tela Maquinas e confirmar a mesma configuracao atual em A e B.
6. Editar Treino A e confirmar que somente nome, lista e ordem mudam.
7. Iniciar Treino A e validar aquecimento com seletor restrito as Maquinas do treino.
8. Concluir aquecimento, Maquina alvo e restante.
9. Reordenar pendentes durante a sessao e confirmar que a ficha salva nao muda.
10. Finalizar e confirmar contador idempotente.
11. Abrir historico e confirmar snapshot independente.
12. Excluir Treino A e confirmar historico e Maquinas preservados.
13. Criar referencia ausente de forma controlada e confirmar bloqueio da execucao.
14. Testar peso decimal ao registrar serie.
