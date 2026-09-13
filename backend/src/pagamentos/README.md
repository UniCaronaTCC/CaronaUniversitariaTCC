# Pagamentos: cliente da API e estrutura SQL

O cliente da API v2 da AbacatePay, a entidade TypeORM e a rota autenticada para
criar ou reutilizar um Pix estao implementados. Ainda nao existe webhook nem tela
de pagamento no Flutter.

## Arquivos

- `abacatepay.service.ts`: monta as requisicoes HTTP para criar um Pix e consultar
  seu status, trata erros e valida os campos utilizados da resposta.
- `abacatepay.types.ts`: define os dados de entrada e de saida em TypeScript.
  Estes tipos nao criam tabelas nem validam JSON sozinhos; o service valida os dados.
- `pagamentos.module.ts`: registra e exporta o service para uso futuro no NestJS.
- `abacatepay.service.spec.ts`: testa o service com chave e respostas ficticias.
- `pagamento.entity.ts`: mapeia a tabela `unicarona.pagamentos`.
- `pagamentos.service.ts`: valida a solicitacao, evita duplicacao e persiste o Pix.
- `pagamentos.controller.ts`: expoe a rota autenticada do backend.
- `abacatepay-webhook.controller.ts`: recebe notificacoes da AbacatePay sem JWT.
- `abacatepay-webhook.service.ts`: valida o webhook e confirma o Pix no provedor.
- `pagamento-evento-webhook.entity.ts`: impede processar o mesmo evento duas vezes.

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

## Rota do backend

`POST /pagamentos/solicitacoes/:idSolicitacao/pix`

A rota nao recebe valor no corpo. Ela usa o usuario autenticado pelo Supabase e
busca o valor da carona no banco. Somente o passageiro de uma solicitacao ACEITA
e nao recorrente pode usa-la nesta primeira versao.

Antes da chamada externa, o backend bloqueia brevemente a solicitacao e salva uma
tentativa PREPARADA com uma referencia UUID. Tentativas PREPARADA, CONFIRMADA ou
INCERTA sao reutilizadas; isso impede que repeticoes da rota criem novos Pix.
FALHOU permite uma nova tentativa porque representa uma falha definitiva antes
da criacao. Essa classificacao e conservadora: timeout e respostas duvidosas ficam
INCERTA e exigem conciliacao futura.

O bloqueio do banco termina antes da chamada HTTP. Ao receber a cobranca, o
backend salva identificador, status, QR Code, codigo copia e cola e vencimento.
CONFIRMADA quer dizer que a cobranca foi criada, nao que o Pix foi pago.

## Webhook

`POST /pagamentos/webhooks/abacatepay?webhookSecret=...`

Essa rota nao usa JWT de usuario porque e chamada pelos servidores da AbacatePay.
Ela exige as duas verificacoes oficiais: `webhookSecret` comparado com
`ABACATEPAY_WEBHOOK_SECRET` e HMAC-SHA256 do corpo bruto recebido no header
`X-Webhook-Signature`. O `main.ts` preserva esse corpo com `rawBody: true`.

Somente `transparent.completed` e processado. Antes de marcar `PAID`, o backend
confere identificador, referencia UUID, valor, metodo, pagamento integral e modo
de teste, e consulta o status diretamente na API da AbacatePay. O payload bruto e
dados do pagador nao sao armazenados.

Cada `id` de evento e salvo em `pagamentos_eventos_webhook`. A atualizacao do
pagamento e o registro do evento ocorrem na mesma transacao com bloqueio da linha.
Uma entrega repetida retorna sucesso sem aplicar a operacao novamente.

Antes de configurar o webhook no painel, executar manualmente somente
`database/postgres/atualizacoes/criar_eventos_webhook_pagamentos.sql`. Depois,
criar um secret aleatorio forte com pelo menos 32 caracteres e guarda-lo apenas no
`.env` do backend como `ABACATEPAY_WEBHOOK_SECRET`. Nunca usar a chave da API como
secret do webhook e nunca colocar nenhum dos dois valores no Flutter ou Git.

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
- https://docs.abacatepay.com/pages/webhooks/security
- https://docs.abacatepay.com/pages/webhooks/events/transparent
- https://docs.nestjs.com/faq/raw-body

As regras de quando cobrar, reservar vaga, expirar reserva e reembolsar ainda
serao discutidas. Esta etapa nao define nem altera essas regras.
