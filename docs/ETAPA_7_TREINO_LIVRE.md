# ETAPA 7 — Treino mais livre (Fase 1)

## Objetivo

Refletir o treino atual, mais livre: a ficha ("dia de peito", "dia de costas")
continua sendo o ponto de partida, mas a sessão aceita exercícios novos no meio
e o aquecimento passa a ser opcional.

## Adicionar exercício durante o treino

- Botão "Adicionar exercicio" (ícone de lista com +) na barra da execução.
- Busca no catálogo global ignorando caixa e acentos, nos dois nomes. Mostra só
  itens ativos que ainda não estão na sessão.
- Se o nome digitado não existe no catálogo (nem aposentado), aparece
  "Novo exercicio" com categoria obrigatória e o botão "Criar e adicionar".
- Criação rápida grava em `machine_catalog` com:
  - `nome_popular` e `nome_cientifico` = nome digitado;
  - `categoria` escolhida;
  - `tipo = outro`;
  - `origem = criacao_rapida`;
  - `nome_cientifico_pendente = true`.
- Se o usuário não tem perfil da máquina, o perfil pessoal é criado com contador
  zero e sem configuração (séries/reps/peso ficam a definir).
- O exercício entra como pendente no fim da sessão. Se todos já estavam
  concluídos, a tela volta para "Escolha o proximo exercicio".
- A ficha original **não** é alterada; só a sessão.
- Retomada: a sessão em andamento já reconstrói o treino a partir dos IDs
  salvos, então o exercício adicionado volta junto.
- Finalização, contador e eventos funcionam igual aos demais exercícios.

## Aquecimento opcional

- Botão "Pular aquecimento" no card de aquecimento.
- Persistido como item de aquecimento com `completed = true`,
  `status = skipped`, sem séries e sem alvo.
- Detalhe da sessão e prompts de análise mostram "Aquecimento não realizado".
- Percepção ao concluir exercícios continua obrigatória.

## Fora desta fase

- Fase 2: tela "Revisar pendentes" (de preferência na web) para completar nome
  científico, tipo e categoria dos itens `origem = criacao_rapida`. A edição
  completa do catálogo continua disponível na tela Máquinas.
- Fase 3 (provavelmente desnecessária): mesclar duplicatas.

## Ideias aceitas, não implementadas

- **Pendentes visíveis só para quem criou.** Quando amigos tiverem acesso, itens
  `origem = criacao_rapida` ainda não revisados devem aparecer apenas para
  `criado_por == uid`, para não poluir o catálogo global dos outros.

## Testes

- `appendPendingEntry`: novo exercício entra pendente com o próximo índice.
- Widget: "Pular aquecimento" libera a escolha dos exercícios.
- Modelo: aquecimento pulado mantém `status = skipped` após serializar.
- A gravação no Firestore (catálogo + perfil) não tem teste automatizado;
  validar manualmente no aparelho.
