# Pagamentos: cliente da API e estrutura SQL

O cliente da API v2 da AbacatePay esta implementado e o script da tabela esta
preparado para execucao manual. Ainda nao existe endpoint publico, entidade
TypeORM, persistencia pelo backend, webhook ou tela de pagamento no Flutter.

## Arquivos

- `abacatepay.service.ts`: monta as requisicoes HTTP para criar um Pix e consultar
  seu status, trata erros e valida os campos utilizados da resposta.
- `abacatepay.types.ts`: define os dados de entrada e de saida em TypeScript.
  Estes tipos nao criam tabelas nem validam JSON sozinhos; o service valida os dados.
- `pagamentos.module.ts`: registra e exporta o service para uso futuro no NestJS.
- `abacatepay.service.spec.ts`: testa o service com chave e respostas ficticias.

## Como funciona

1. `criarPix` recebe valor em centavos, referencia e, opcionalmente, descricao e
   expiracao. Exemplo: 1250 centavos representam R$ 12,50.
2. O service le `ABACATEPAY_API_KEY` do ambiente somente ao executar a operacao.
   A ausencia da chave nao impede o restante do backend de iniciar.
3. Envia `POST /v2/transparents/create`, com `method: PIX` e os campos em `data`.
   A referencia segue como `externalId`; persistencia e controle de duplicacoes
   dentro do nosso sistema pertencem a proxima etapa.
4. Confere valor, identificador, status, expiracao, QR Code e `devMode: true`.
5. `consultarPix` usa `GET /v2/transparents/check?id=...` e confere se o id
   retornado corresponde ao solicitado. A resposta dessa consulta nao documenta
   `devMode`, por isso ela nao e uma forma de validar o ambiente da chave.

## Limites e seguranca

- Usar exclusivamente uma chave criada no Dev Mode do painel. A URL da API e a
  mesma nos dois ambientes; `NODE_ENV` nao transforma uma chave real em sandbox.
- O service bloqueia `NODE_ENV=production` e o prefixo documentado `prod_` como
  protecoes adicionais. Outros formatos de chave nao comprovam o ambiente.
- A verificacao de `devMode` ocorre DEPOIS da criacao. Ela recusa a resposta fora
  do sandbox, mas nao desfaz uma cobranca. Conferir o painel antes de testes reais.
- Chave apenas no `.env` do backend, nunca no Flutter, Git ou logs.
- Requisicoes expiram em 10 segundos e nao seguem redirecionamentos.
- Nenhuma requisicao e repetida automaticamente. Em uma falha de rede, pode ser
  necessario conciliar a cobranca ja criada antes de tentar criar outra.
- A criacao do modulo nao gera cobrancas nem acessa o banco.

## Testes isolados

Na pasta `backend`, execute `npm test -- --runInBand pagamentos`.
Os testes substituem `fetch` e `ConfigService`: nao leem sua chave, nao acessam
a AbacatePay e nao se conectam ao PostgreSQL. Eles nao confirmam que a chave real
tem as permissoes corretas. A validacao no sandbox real ainda sera feita por etapa.

## Estrutura SQL: execucao manual

Para o banco existente, executar somente
`database/postgres/atualizacoes/criar_pagamentos.sql`, inteiro, na conexao
PostgreSQL do projeto no DBeaver. Nao reexecutar o schema completo.
`database/postgres/estrutura/schema.sql` recebeu a mesma estrutura para futuras
instalacoes. Preparar o arquivo nao significa que a tabela foi criada no banco.

A tabela `unicarona.pagamentos` guarda uma tentativa de cobranca por registro:

- Solicitacao vinculada por chave estrangeira, sem exclusao em cascata.
- Valor em centavos, sem ponto flutuante. `BIGINT` chega como string no driver
  PostgreSQL; a futura entidade deve converter e validar explicitamente.
- Referencia UUID gerada pelo backend antes da chamada e enviada como `externalId`.
- Identificador da AbacatePay unico por provedor e ambiente.
- Codigo Pix, QR Code, vencimento e status recebido do provedor.
- `status_criacao`: PREPARADA antes do envio, CONFIRMADA ao confirmar a criacao,
  INCERTA quando nao se sabe se a API criou a cobranca, FALHOU em falha definitiva.
  CONFIRMADA significa cobranca criada, nunca pagamento aprovado.
- `atualizado_em` devera ser atualizado pelo backend a cada alteracao.

Uma solicitacao pode ter tentativas antigas: nao ha UNIQUE em `id_solicitacao`.
Os identificadores unicos nao impedem duas referencias diferentes de cobrarem a
mesma solicitacao. O controle de concorrencia, a reutilizacao da tentativa ativa
e a conciliacao de resultados incertos ainda serao implementados no backend.
Uma tentativa INCERTA nao deve provocar automaticamente outra cobranca.

RLS esta habilitado sem politicas para clientes e as permissoes de tabelas e
sequencias foram revogadas de PUBLIC, anon e authenticated. O backend continua
usando a conexao PostgreSQL atual com o proprietario da tabela. Uma futura role
restrita exigira permissoes/politicas proprias. Nao conceder acesso ao Flutter.
`modo_teste` e apenas um registro local; nao transforma a chave em sandbox.
Nao sao guardadas chaves da API, dados de cartao ou payloads brutos de clientes.
Ainda nao ha tabela de eventos de webhook, carteira, saldo ou repasse.

## Referencias

- https://docs.abacatepay.com/pages/transparents/create
- https://docs.abacatepay.com/pages/transparents/check
- https://docs.abacatepay.com/pages/authentication

As regras de quando cobrar, reservar vaga, expirar reserva e reembolsar ainda
serao discutidas. Esta etapa nao define nem altera essas regras.
