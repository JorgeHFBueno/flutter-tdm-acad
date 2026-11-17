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
