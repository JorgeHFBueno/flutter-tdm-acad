# Etapa 1 - Maquinas como entidade principal

## Objetivo

Esta etapa transforma o antigo conceito de Historico de Maquina em uma entidade permanente de estado atual chamada `MachineProfile`.

A maquina passa a representar, por usuario e por exercicio, o estado acumulado do exercicio: identificacao estavel, nome, categoria, OBS atual, contador de conclusoes validas, ultimo aumento, penultimo aumento, campos opcionais de configuracao atual e metadados de esquema.

## Estrutura anterior

A estrutura anterior concentrava estes dados em:

```text
users/{uid}/machine_history/{exerciseId}
```

O documento ja usava `exerciseId` como ID estavel e armazenava campos como:

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

Esse caminho continua legivel durante a migracao progressiva.

## Estrutura nova

O caminho canonico da entidade Maquina e:

```text
users/{uid}/machines/{exerciseId}
```

O ID do documento e sempre o `exerciseId`. Nao sao usados IDs automaticos para maquinas.

As regras atuais do Firestore foram apenas lidas para verificacao. Elas permitem tecnicamente o caminho canonico acima. O arquivo `firestore.rules` nao foi alterado.

## Modelo

O modelo principal e `MachineProfile`, definido em `lib/models/machine_history.dart` para preservar compatibilidade com imports existentes.

Campos principais:

- `exerciseId`
- `exerciseName`
- `category`
- `ownerUid`
- `completionCount`
- `schemaVersion`

Campos opcionais:

- `observation`
- `lastIncrease`
- `previousIncrease`
- `currentSets`
- `currentRepetitions`
- `currentWeightKg`
- `createdAt`
- `updatedAt`

Valores padrao:

- `completionCount`: `0`
- `schemaVersion`: `1`
- OBS ausente: `null`, exposta com seguranca por `observationText`
- configuracao atual ausente: `null`
- aumentos ausentes: `null`

Valores numericos vindos do Firestore sao lidos como `num` quando necessario e convertidos com seguranca para `int` ou `double`.

## Servico central

O servico central e `MachineService`, mantido no arquivo `lib/services/machine_history_service.dart` para reduzir impacto nos imports existentes.

Responsabilidades:

- listar maquinas;
- observar maquinas;
- buscar por `exerciseId`;
- criar maquina;
- garantir existencia;
- atualizar OBS;
- atualizar configuracao atual opcional;
- registrar aumento;
- editar ultimo e penultimo aumento;
- incrementar contador ao concluir sessao;
- mesclar resultados canonicos e legados;
- preservar dados durante atualizacoes parciais.

`MachineHistoryService` continua existindo como alias temporario de compatibilidade.

## Compatibilidade e precedencia

Durante esta etapa, leituras consultam:

1. `users/{uid}/machines/{exerciseId}`;
2. `users/{uid}/machine_history/{exerciseId}` como fallback.

Na listagem, documentos canonicos e legados sao unidos por `exerciseId`.

Regra de precedencia:

1. documento canonico prevalece;
2. documento legado e usado quando o canonico nao existe;
3. campos opcionais ausentes no canonico podem ser preenchidos em memoria por dados legados;
4. simples leitura nao sobrescreve o canonico;
5. ao salvar uma alteracao real, o estado passa a ser persistido no caminho canonico com `set(..., merge: true)`.

Contadores nao sao somados. OBS, ultimo aumento e penultimo aumento nao sao duplicados.

## OBS

A OBS atual continua pertencendo a maquina.

Telas de criacao de treino, edicao de treino, execucao e detalhes de maquina leem e salvam OBS via `MachineService`.

Se a OBS existir apenas no documento legado, ela aparece por fallback. Ao editar, a atualizacao e salva no documento canonico e o legado nao e apagado.

## Contador

O contador `completionCount` e preservado.

A conclusao de treino continua usando a regra atual de percepcoes validas. Aquecimento nao incrementa contador proprio. O exercicio alvo do aquecimento continua usando o ID real do exercicio, mas o aquecimento em si nao vira uma maquina.

A idempotencia de sessao foi preservada com o marcador legado `machineHistoryCountApplied` e o novo marcador `machineCountApplied`.

## Aumentos

A estrutura atual foi mantida:

- `lastIncrease`
- `previousIncrease`

Cada aumento preserva:

- tipo (`weight`, `sets`, `repetitions`);
- novo valor;
- data.

Nao foi criada subcolecao de eventos nesta etapa.

## Configuracao atual opcional

Foram preparados os campos:

- `currentSets`
- `currentRepetitions`
- `currentWeightKg`

Eles ainda nao substituem os valores de `WorkoutExercise` nem alteram os formularios de treino ou execucao.

## IDs

O `exerciseId` estavel existente continua sendo usado.

Exercicios do catalogo mantem IDs unicos. Exercicios legados continuam resolvendo IDs deterministicos por nome e categoria. Nao foi introduzido `hashCode`.

## Compatibilidade com treinos

`Workout` e `WorkoutExercise` nao foram reformulados nesta etapa.

Treinos continuam armazenando seus campos atuais, incluindo:

- `exerciseId`;
- nome;
- categoria;
- `defaultWeightKg`.

Nenhuma migracao dos documentos de `workouts` foi executada.

## Compatibilidade com sessoes

`WorkoutSession` nao foi reformulado.

Sessoes continuam armazenando snapshots e seguem independentes da maquina. Sessoes antigas continuam abrindo mesmo quando a maquina nao existir ou quando campos novos estiverem ausentes.

## Eventos futuros

A estrutura recomendada para uma etapa futura e:

```text
users/{uid}/machines/{exerciseId}/events/{eventId}
```

Eventos futuros poderao incluir:

- `completed`
- `weight_increased`
- `sets_increased`
- `repetitions_increased`
- `observation_changed`

Nenhum documento vazio ou subcolecao sem uso foi criado nesta etapa.

## Limites desta etapa

Ainda nao foram implementados:

- treino como lista de referencias;
- configuracao atual obrigatoria;
- eventos completos;
- simbolos derivados das percepcoes;
- nova interface estilo Google Keep;
- migracao em massa do Firestore;
- historico ilimitado de aumentos;
- progressao automatica;
- graficos;
- Machine Learning.

## Proximas etapas

Proximas etapas recomendadas:

1. expor edicao isolada da configuracao atual da maquina;
2. adicionar eventos de progressao em subcolecao;
3. migrar treinos gradualmente para referencias a maquinas;
4. manter sessoes como snapshots independentes;
5. redesenhar a interface depois que o modelo estiver consolidado.

## Validacao manual

Checklist para executar em ambiente autenticado com dados reais ou base de homologacao:

1. abrir o submenu Historico;
2. confirmar Historico de Treino;
3. confirmar Maquinas;
4. abrir Maquinas;
5. verificar registros existentes;
6. confirmar que nao aparecem duplicados;
7. abrir uma maquina existente;
8. verificar OBS;
9. verificar contador;
10. verificar marcas;
11. verificar ultimo aumento;
12. verificar penultimo aumento;
13. editar OBS;
14. reabrir a tela;
15. confirmar persistencia;
16. cadastrar nova maquina;
17. confirmar contador zero;
18. cadastrar aumento;
19. confirmar preservacao da OBS;
20. executar um treino existente;
21. concluir exercicio elegivel;
22. concluir o treino;
23. confirmar incremento da maquina;
24. confirmar que Historico de Treino permanece funcional;
25. confirmar que sessoes antigas continuam abrindo;
26. testar um exercicio legado;
27. confirmar que nenhum dado antigo foi apagado.

Esta validacao manual nao foi executada durante a implementacao automatizada para evitar escrita em Firebase real fora de um fluxo controlado pelo usuario.
