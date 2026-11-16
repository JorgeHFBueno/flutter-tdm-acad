# ETAPA 8 — Relatórios periódicos e Nova Era

## Objetivo

Trocar a análise do Gemini por relatórios semanal, mensal e geral escritos por
uma tarefa agendada do Claude, com aviso por push no celular. Os números são
calculados em código; o texto só interpreta.

## Fluxo

1. `node tools/relatorio/coletar.js` lê o Firestore e imprime o JSON de métricas.
   - Sempre gera o **semanal** (segunda a domingo da data de referência).
   - No primeiro domingo do mês (ou com `--forcar-mensal`) também gera o
     **mensal** (mês anterior) e o **geral**.
   - `--data AAAA-MM-DD` muda a data de referência.
2. O Claude escreve a análise em texto puro (a tela de detalhe não renderiza
   markdown).
3. `node tools/relatorio/publicar.js --tipo semanal|mensal|geral --titulo "..."
   --periodo "..." --arquivo analise.txt [--sem-push]`:
   - grava em `workout_analysis_logs` (`type` = semanal/mensal/geral);
   - envia o push "Sua análise PERIODO está disponível" para
     `users/{uid}.fcmTokens` e remove tokens inválidos.

Cron não expressa "primeiro domingo"; por isso há uma única tarefa aos domingos
às 19h e o script decide se inclui mensal e geral (dia do mês ≤ 7).

## Credenciais (fora do repositório)

- `~/.vanguard/service-account.json`: chave da conta de serviço do projeto
  `tdm-25-2` (ou variável `VANGUARD_SERVICE_ACCOUNT`).
- `~/.vanguard/config.json`: `{"uid": "..."}` (ou `VANGUARD_UID`).
- Nunca commitar esses arquivos.

## Métricas (`tools/relatorio/metricas.js`)

- Sessões contam se têm data e não estão `inProgress`/`abandoned`.
- Data da sessão: `performedAt`, depois `completedAt`, depois `endAt`.
- Aquecimento (`isWarmup` ou nome começando por "Aquecimento") fica fora das
  cargas e do volume.
- Exercícios são agrupados pelo nome normalizado (sessões antigas tinham IDs
  diferentes para a mesma máquina).
- 1RM estimado por Epley.
- Aumento registrado = evento de aumento não anulado **com valor anterior**.
  O cadastro inicial (valor anterior nulo) não conta como progresso.
- Nomes com acento quebrado são corrigidos na leitura.

## App

- Nova página "Análises" no grupo Histórico (lista de `workout_analysis_logs`).
- Push só no Android: o token é registrado depois do login, sem `await` no
  `main()` (o `await` antigo travava o carregamento). Ao tocar na notificação o
  app abre em "Análises".
- Tela de máquinas mostra o rótulo da categoria (`MachineCatalogCategory.display`).
- Máquinas adicionadas pelo catálogo local passam a ser gravadas com a categoria
  padrão (`canonicalMachineCategory`).

## Nova Era (limpeza de 16/11/2026)

`node tools/relatorio/limpar.js [--aplicar] [--inicio AAAA-MM-DD] [--detalhe]`
simula por padrão. Com `--aplicar`, grava antes um backup completo em
`~/.vanguard/backup-*.json`. Aplicado em 16/11/2026:

- acentos corrigidos em 4 máquinas, 4 itens do catálogo e nos snapshots de sessão;
- categorias das máquinas e dos exercícios das sessões no padrão do catálogo
  (`peito`, `costas`, `ombros`, `biceps`, `triceps`, `pernas`, `panturrilhas`,
  `core`...);
- exercícios sem `exerciseId` religados à máquina pelo nome; aquecimentos
  antigos marcados com `isWarmup`;
- sessão de 27/07 renomeada de "Treino Costas Completo" para
  "Peito Ombro Triceps" (era o conteúdo real);
- sessão abandonada de 04/08 removida;
- `users/{uid}.novaEraInicio = 16/11/2026`.

Com `novaEraInicio`, o relatório geral mede só os treinos a partir dessa data.
A fase anterior vira `eraAnterior` e cada exercício recebe `pontoDePartidaKg`
(última carga antes da Nova Era). O mensal e o semanal continuam comparando
recordes com todo o histórico.

A conta de teste (login por senha) foi mantida.

## Pendente

- Tarefa agendada no app do Claude (domingo 19h). Só roda com o app aberto;
  se estiver fechado, roda ao abrir.
- Remover o Gemini do app (pacote, `.env`, botões e serviço), mantendo o
  histórico de análises.
