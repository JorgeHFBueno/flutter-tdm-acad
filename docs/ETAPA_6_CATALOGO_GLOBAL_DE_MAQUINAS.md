# ETAPA 6 — Catálogo global de Máquinas

## Arquitetura

O Firestore é a fonte principal das definições atuais de Máquinas. A coleção
canônica é `machine_catalog/{machineId}`. O estado pessoal continua isolado em
`users/{uid}/machines/{machineId}`, os treinos guardam apenas a lista ordenada
de IDs e `workout_history/{sessionId}` continua sendo snapshot independente.

As telas acessam o catálogo por `MachineCatalogService`; `MachineService`
continua responsável apenas por configuração, contador, aumentos, OBS e
eventos pessoais. Catálogo e perfis são carregados uma vez e indexados por ID,
sem leitura por card.

## Documento, identidade e auditoria

Os campos são `nome_popular`, `nome_cientifico`, `categoria`, `criado_por`,
`tipo`, `aposentada`, `criado_em`, `atualizado_em`, `atualizado_por`,
`aposentado_em`, `aposentado_por`, `schema_version`, `origem` e
`nome_cientifico_pendente`. Timestamps de mutações são do servidor. O modelo
`MachineCatalogItem` faz leitura defensiva, preserva `doc.id` e não atribui um
nome científico quando ele está ausente.

Os 31 IDs locais existentes são preservados. Itens manuais recebem uma única
ID automática do Firestore; edição/renomeação nunca troca a ID. `criado_por`,
`criado_em` e `origem` não fazem parte do patch de edição.

## Categorias e tipos

Categorias canônicas: `peito`, `costas`, `ombros`, `biceps`, `triceps`,
`pernas`, `gluteos`, `panturrilhas`, `core`, `cardio`, `outros`.

Tipos canônicos: `maquina`, `halteres`, `barra`, `polia`, `peso_corporal`,
`elastico`, `equipamento_livre`, `outro`.

Valores e rótulos visíveis estão centralizados no modelo. O arquivo local só
possuía um nome; por isso o seed copia esse valor para os dois nomes e marca os
31 itens com `nome_cientifico_pendente = true`. Não foi inventada terminologia.
Itens pendentes: `abdutor_abre`, `adutor_fecha`, `agachamento`,
`aquecimento_esteira_1km`, `extensora`, `leg_45`, `leg_press_45`,
`mesa_flexora`, `panturrilha_cadeira`, `abdominal_inclinado`,
`elevacao_lateral_halteres`, `ombro_maquina`, `peitoral_robo`,
`supino_simples`, `supino_inclinado_halteres`, `supino_reto_maquina`,
`triceps_barra`, `triceps_corda`, `voador`, `abs_invertido`, `abs_perna`,
`antebraco_barra`, `barra_w`, `biceps_halters`, `biceps_cadeira`,
`dorsal_maquina`, `encolhimento`, `puxada_alta_barra`, `puxada_frente`,
`remada_baixa`, `desenvolvimento_ombro`.

## Importação

Após autenticação e antes do primeiro stream, o serviço lista IDs existentes e
executa uma transação por seed ausente. A transação relê a ID e só cria quando
ela ainda não existe. Documento existente — inclusive aposentado ou corrigido
— nunca é sobrescrito ou reativado. Itens manuais não são tocados. Execução
parcial registra falhas por ID e a próxima tentativa processa apenas ausentes.
Uma guarda por UID evita repetição desnecessária na mesma sessão. O relatório
de debug contém total, criados, ignorados e falhas. Não há fallback silencioso
para o arquivo local após erro do Firestore.

## Tela, busca e ciclo de vida

A tela Máquinas combina catálogo e perfis em memória. A ordem fixa é: ativos
cadastrados, ativos não cadastrados, aposentados cadastrados e aposentados não
cadastrados. Dentro do grupo há ordenação estável por nome popular (padrão) ou
científico, normalizada apenas para comparação, com outro nome e ID como
desempates. Busca simultânea nos dois nomes ignora caixa e acentos. Categoria e
status são filtros locais combináveis.

Cada card mostra nomes, categoria, tipo, cadastro/aposentadoria e o resumo do
perfil. Item ativo sem perfil abre a configuração pessoal e grava sob a mesma
ID com contador zero. Item aposentado sem perfil é bloqueado. Item cadastrado
abre os detalhes e preserva todo o histórico.

Adicionar e editar exigem nomes (trim, 1–120 caracteres), categoria e tipo. A
duplicidade considera aposentados, normaliza caixa/acentos/espaços e bloqueia
nome científico já existente. Botões ficam desabilitados durante gravação.
Aposentar e reativar usam confirmação e auditoria; não existe exclusão física.

## Treinos, execução e snapshots

Criação oferece somente perfil existente cujo catálogo esteja ativo. Edição
preserva aposentado já selecionado, permite removê-lo e não o oferece novamente.
Execução resolve catálogo e perfis em lote no início e aceita aposentado já
referenciado. Novos exercícios do snapshot incluem ID, nome popular atual,
nome científico, categoria, tipo, configuração e OBS. A desserialização aceita
snapshots antigos sem os campos novos; sessões antigas nunca são reescritas.
Campos legados de nome/categoria no perfil permanecem como fallback defensivo.

## Firestore, índices e segurança

`firestore.rules` foi apenas lido. A regra atual permite leitura pública de toda
a base e escrita em qualquer caminho para usuário autenticado. Logo o catálogo
é acessível e o CRUD funcional, mas isso **não é uma garantia de segurança**:
qualquer autenticado pode alterar qualquer documento. O risco deve ser tratado
em etapa própria de regras e autorização.

O `firebase.json` não declara arquivo de índices. O catálogo usa leitura simples
da coleção; busca, filtros e ordenação são locais, sem índice composto. Nenhuma
regra, índice ou deploy foi alterado/executado.

## Testes, validação e limitações

Há testes puros para mapeamento defensivo, campos em português, seed vazio/
parcial/completo/repetido, retomada, IDs, combinação, grupos, ordenação,
normalização, filtros, aposentadoria em edição e snapshots retrocompatíveis.
Validação manual deve seguir os 40 passos definidos na solicitação em dispositivo
autenticado, incluindo offline, duplo toque e persistência de edição. Testes
automatizados não escrevem no Firebase real; por isso não afirmam quantidade
real criada no projeto remoto.

