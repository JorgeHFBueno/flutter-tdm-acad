# ETAPA 9 — Carga por lado, máquinas por categoria e ajustes do treino de 16/11

## Máquinas agrupadas por categoria

Criar e editar treino listam as máquinas por categoria (ordem de
`MachineCatalogCategory.values`: peito, costas, ombros...) e, dentro de cada
grupo, por nome sem acento (`groupMachinesByCategory`). O subtítulo mostra só a
configuração atual.

## Categoria sempre como chave do catálogo

`MachineProfile.fromMap` passa a devolver a chave (`peito`), não o rótulo do
catálogo local antigo (`Peito`), via `machineCategoryKey`. Era isso que gravava
"Peito" em máquinas e sessões depois da limpeza da Nova Era.

## Carga por lado

- Campo `machine_catalog/{id}.carga_por_lado` (bool). No web, a chave
  "Carga por lado" fica no formulário do catálogo.
- Você continua digitando o que vê (15 = cada polia, cada halter ou cada lado
  da barra). O app mostra "15 kg/lado".
- O snapshot da sessão grava `loadPerSide: true`. O volume desse exercício
  conta os dois lados (x2).
- Relatórios: `tools/relatorio/firestore.js` dobra as cargas e os aumentos de
  peso desses exercícios e marca `cargaPorLado: true` no JSON. O peso da barra
  não entra na conta.
- Marcados em 17/11/2026: Cross Alto, Cross Peito Baixa, Supino Simples,
  Supino inclinado com halteres, Biceps Halters, Elevação lateral com halteres
  e Encolhimento. As sessões antigas desses exercícios receberam `loadPerSide`.

## Ajustes de dados (17/11/2026)

Backup: `~/.vanguard/backup-2026-11-17T19-10-40-331Z.json`.

- Cross Alto: nome científico "Crucifixo no cross-over com polias altas",
  tipo polia.
- Sessão de 16/11 ("Peito NE"): aquecimento marcado como feito (1 série de 12
  com 10 kg por lado no Supino Simples) e categorias "Peito" → `peito`.
- Máquinas Supino Simples e Supino inclinado com halteres: categoria `peito`.

## Peso do corpo (25/11/2026)

- Exercícios do catálogo com tipo `peso_corporal` não pedem peso: o diálogo de
  série mostra "Peso do corpo" e grava 0 kg. Séries antigas com carga continuam
  mostrando o kg.
- Relatórios marcam `pesoCorporal: true` e trazem `repeticoes` por exercício.
- Marcados: Barra Supino (barra fixa), Abdominal inclinado, "ABS Perna" e
  "ABS Invertido".

## Fluxo de revisão depois de cada treino

1. `node tools/relatorio/revisar.js [n]` lista os últimos treinos e o que está
   pendente (nome científico, categoria, aquecimento, exercício sem séries).
2. Definimos os nomes e tipos e escrevemos um plano JSON (formato no topo de
   `corrigir.js`).
3. `node tools/relatorio/corrigir.js plano.json [--detalhe]` simula;
   `--aplicar` grava, com backup em `~/.vanguard/`. Ele atualiza o catálogo e
   alinha máquinas e todo o histórico (nome, categoria, tipo, carga por lado),
   para a análise não dividir o mesmo exercício em dois.

Aplicado em 25/11/2026 (backup `backup-2026-11-25T13-28-14-995Z.json`):
Barra Supino = barra fixa; Remada Baixa Curvada = remada curvada com barra
(por lado); Biceps Corda = rosca martelo na polia baixa com corda; "Tríceps
corda costas" = extensão de tríceps acima da cabeça na polia com corda; Barra W
por lado; "tríceps banco costas" = bíceps com halteres por lado (nome
pendente); aquecimento de 17/11 marcado como feito.

## Editar treino traz as máquinas feitas fora da ficha (26/11/2026)

Máquinas adicionadas no meio do treino ficavam só no snapshot da sessão. A
edição agora traz marcadas, como "(nova)", as máquinas concluídas ou parciais em
sessões daquele treino feitas depois da última edição da ficha
(`machinesAddedDuringSessions`). Desmarcar e salvar remove de vez.

Treino "Perna NE" de 25/11 corrigido em 26/11/2026:
- "adutor" (criação rápida) era o Abdutor: unido ao `abdutor_abre` (sessão,
  evento de conclusão e contagem); o item duplicado foi aposentado. Backup
  `backup-unir-abdutor-2026-11-26T11-15-21-734Z.json`.
- Leg 45° = máquina com carga por lado (vale para o histórico inteiro);
  aquecimento de 25/11 marcado como feito.
- "levantamento pelvico" = Elevação pélvica no Smith (glúteos, por lado);
  "stiff" = Stiff com barra (por lado). Backup
  `backup-2026-11-26T11-15-30-339Z.json`.
