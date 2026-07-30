# Correcoes de Catalogo e Historico

## Catalogo unificado

O catalogo compartilhado foi criado em `lib/data/exercise_catalog.dart`. Ele
usa `ExerciseCatalogItem`, com `name` e `category`, e expoe a lista imutavel
`exerciseCatalog`, alem de agrupamento por categoria e funcoes de busca e
resolucao.

As telas `workout_creation_screen.dart` e `workout_edit_screen.dart` consomem
essa mesma fonte. Os exercicios da criacao e da edicao foram consolidados sem
listas locais duplicadas.

Exercicios consolidados somente da edicao: `Supino reto (máquina)`,
`Puxada frente`, `Leg press 45º`, `Desenvolvimento ombro`. `Remada baixa` ja
existia na criacao.

Itens classificados como `Outros`: `Aquecimento`, por ser um nome duplicado em
categorias diferentes na implementacao anterior, e `Desenvolvimento ombro`, por
nao ter categoria propria clara no conjunto atual.

## Categoria

Na criacao, a categoria vem diretamente do catalogo unificado por nome. Na
edicao, os exercicios salvos sao carregados preservando a categoria existente;
se ela estiver ausente ou vazia, o app procura no catalogo; se nao encontrar,
usa `Outros`.

Exercicios legados fora do catalogo continuam selecionados, aparecem na edicao,
permitem alteracao de peso e sao salvos com a categoria existente ou `Outros`.
Nao ha migracao em massa de documentos antigos.

## Exclusao e historico

A exclusao de treino permanece fisica: `WorkoutService.deleteWorkout` continua
apagando o documento em `workouts/{workoutId}` com `delete()`.

Nenhum documento de `workout_history` e apagado em cascata. As telas de
historico e detalhe continuam usando o snapshot salvo na sessao: `workoutId`,
`workoutName`, `ownerUid`, datas e exercicios executados.

A tela de historico carrega uma vez os IDs dos treinos ativos do usuario e
marca sessoes cujo `workoutId` nao esta nesse conjunto como origem excluida.
Sessoes antigas sem `workoutId` sao tratadas como origem indisponivel, sem
impedir abertura, volume ou analise de IA.

O modelo de sessao nao recebeu novo campo.

## Firebase

O `firebase.json` preserva as configuracoes existentes de Flutter e Hosting. A
configuracao relevante de Firestore ficou:

```json
{
  "firestore": {
    "rules": "firestore.rules"
  }
}
```

O arquivo `firestore.rules` existe na raiz e nao foi alterado por esta tarefa.
Nao foi executado deploy. Observacao: o Hosting continua apontando para a pasta
`n`, que parece incomum para um projeto Flutter, mas nao foi alterado por estar
fora do escopo.

## Testes

Foram adicionados testes unitarios para catalogo, serializacao de
`WorkoutExercise` e desserializacao de `WorkoutSession`.

Comandos executados:

- `dart format lib test`: executado; arquivos fora do escopo formatados pelo
  comando foram restaurados, e os arquivos da tarefa foram mantidos formatados.
- `flutter test`: aprovado, 13 testes passaram.
- `node -e "JSON.parse(...firebase.json...)"`: aprovado.
- `flutter analyze`: ainda falha com 64 avisos/lints preexistentes do projeto,
  principalmente dependencias Firebase/Intl/Gemini declaradas em
  `dev_dependencies`, `print` em telas existentes e lints antigos. Nao foram
  encontrados erros de compilacao novos nos testes.
- `git diff --check`: aprovado; o Git apenas avisou sobre normalizacao futura
  de fim de linha CRLF/LF em arquivos modificados.
- `git status --short`: executado ao inicio e ao final.

`firestore.rules` permaneceu sem alteracao; o SHA-256 conferido antes e depois
foi `5D6BA48B8EADA12B47B30F1FD947DEA542F625A5095881030D37F4259121AAA8`.
