# Fluxo de execução com aquecimento

## Fases

O fluxo de execução usa fases locais da tela:

- `warmup`: mostra apenas a etapa automática de aquecimento.
- `warmupTargetExercise`: depois do aquecimento, mostra apenas o exercício usado como alvo.
- `remainingExercises`: depois da conclusão do exercício-alvo, mostra os demais pendentes e os concluídos.
- `finished`: sessão salva ou sem pendências.

As fases não são persistidas em `workouts` e não alteram a ficha original.

## Aquecimento

O aquecimento é criado automaticamente no início da execução com `createWarmupExecution`.
Ele não depende de existir um exercício chamado "Aquecimento" na ficha.

O seletor de alvo usa somente nomes presentes na ficha atual e remove duplicados. Em treinos com um exercício, esse exercício já fica selecionado.

## Modelo persistido

O aquecimento é salvo como um item de `WorkoutSession.exercises`:

```json
{
  "exerciseName": "Aquecimento",
  "isWarmup": true,
  "targetExerciseName": "Supino reto",
  "sets": [
    { "setNumber": 1, "reps": 15, "weightKg": 10 }
  ],
  "perceivedEffort": null,
  "completed": true
}
```

Campos adicionados em `ExerciseExecution`:

- `isWarmup`: identifica a etapa automática.
- `targetExerciseName`: registra o exercício usado no aquecimento.

Campos ausentes em sessões antigas recebem padrões seguros:

- `isWarmup` ausente equivale a `false`.
- `targetExerciseName` ausente equivale a `null`.
- `perceivedEffort` antigo é mantido e apenas convertido para rótulo ao exibir.

## Ordenação

A ordem temporária é armazenada somente em listas locais da tela de execução:

- pendentes podem ser movidos para cima e para baixo;
- concluídos não são reordenáveis;
- concluídos ficam no final, na ordem exata de conclusão;
- a ficha original em `workouts` não é salva nem reordenada.

A ordem salva no histórico é determinística:

1. aquecimento;
2. exercícios concluídos na ordem de conclusão;
3. exercícios pendentes restantes, na ordem atual da sessão incompleta.

## Percepção

Valores internos persistidos:

- `light`
- `adequate`
- `high_fatigue`
- `reduced_reps`
- `reduced_weight`
- `skipped_fatigue`
- `skipped_other`

Rótulos visíveis:

- Leve
- Adequado
- Fadiga intensa
- Concluído com menos repetições
- Concluído com menos carga
- Não realizado por fadiga
- Não realizado por outro motivo

Compatibilidade com valores antigos:

- `certo` -> Adequado
- `leve` -> Leve
- `fadiga` -> Fadiga intensa

O valor original antigo não é alterado ao desserializar.

## Regras de conclusão

O aquecimento:

- não solicita percepção;
- exige exercício-alvo;
- exige pelo menos uma série registrada;
- libera somente o exercício-alvo.

Exercícios realizados exigem pelo menos uma série:

- Leve
- Adequado
- Fadiga intensa
- Concluído com menos repetições
- Concluído com menos carga

Exercícios não realizados podem ser concluídos sem séries:

- Não realizado por fadiga
- Não realizado por outro motivo

## Volume

O volume usa:

```text
volume = repetições x carga
```

O volume total da sessão soma todos os itens de `WorkoutSession.exercises`, incluindo aquecimento. Exercícios não realizados sem séries têm volume zero.

## Histórico

As telas de histórico e detalhe usam apenas o snapshot salvo em `workout_history`.
O histórico continua abrindo mesmo se o treino original foi excluído ou se `workoutId` está ausente em sessão antiga.

O detalhe mostra:

- aquecimento separado;
- exercício utilizado no aquecimento;
- séries, repetições, carga e volume;
- ausência de percepção no aquecimento;
- percepção em português para exercícios normais;
- indicação de exercício não realizado quando aplicável.

## Gemini

Os prompts foram mantidos no mesmo serviço e passaram a incluir informações legíveis sobre:

- ordem executada;
- aquecimento;
- exercício-alvo;
- séries de aquecimento;
- volume;
- percepções novas em português;
- exercícios não realizados.

## Arquivos modificados

- `lib/models/workout_session.dart`: campos opcionais, percepção centralizada e cálculo de volume.
- `lib/models/workout_execution_flow.dart`: regras puras de fases, ordenação, aquecimento e ordem de sessão.
- `lib/screens/workout_execution_screen.dart`: fluxo de aquecimento, reordenação local e conclusão.
- `lib/screens/history_screen.dart`: volume centralizado e prompt de histórico com novo formato.
- `lib/screens/workout_session_detail_screen.dart`: exibição de aquecimento, volume e percepções.
- `test/workout_session_model_test.dart`: testes de modelo, compatibilidade e volume.
- `test/workout_execution_flow_test.dart`: testes de ordem, fases e percepção.
- `test/workout_execution_widget_test.dart`: testes de widget sem Firebase real para início e transição do aquecimento.

## Testes executados

- `dart format` nos arquivos alterados: concluído.
- `flutter test`: 31 testes aprovados.
- `flutter analyze`: 64 issues encontrados, sem erros de compilação; quantidade compatível com problemas preexistentes citados.
- `git diff --check`: aprovado, apenas avisos de LF/CRLF do Git.
- `git status --short`: repositório permanece com alterações preexistentes e alterações desta implementação.

## Limitações conhecidas

- Em fichas com nomes duplicados, o seletor de aquecimento exibe o nome uma única vez e usa a primeira ocorrência pendente como alvo.
- Não foi adicionado campo obrigatório de justificativa para "Não realizado por outro motivo".
- Não há recuperação de fase em andamento após fechar a tela antes de salvar; isso preserva o comportamento de sessão local atual.
