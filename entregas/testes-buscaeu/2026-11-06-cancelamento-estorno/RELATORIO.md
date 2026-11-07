# Cancelamento e estorno simulado — BuscaEu

Data: 06/11/2026. Base: branch `desenvolvimento`, commit `83944d8219a4b0661d56eac8b5fc12b3f76bba54`. Implementação solicitada pelo usuário após definir as regras do protótipo. A referência histórica das skills foi adaptada a esse requisito novo.

## Comportamento implementado

- Participação com PAID confirmado não pode ser cancelada individualmente, por motorista ou passageiro. O backend bloqueia as tentativas durante a conferência, ordenando a operação com a confirmação concorrente.
- O motorista pode cancelar a carona inteira ATIVA/LOTADA. O aplicativo pede confirmação e explica o cancelamento dos pedidos e o estorno simulado. Viagens iniciadas ou encerradas são preservadas.
- A transação encerra solicitações PENDENTES/ACEITAS, preserva o histórico e registra os avisos. Canceladas passam a constar também no histórico do motorista.
- O pagamento mantém o estado do provedor. `estorno_simulado_em` registra somente a compensação local de PAID em Dev Mode; não existe devolução real de dinheiro.
- `participacao_encerrada_em` também identifica tentativas ainda pendentes. Um Pix antigo não paga uma nova reserva quando a solicitação é reutilizada.
- Confirmação tardia, por webhook ou conciliação, registra estorno simulado sem reativar participação. Repetições não duplicam os avisos nem alteram a data já registrada.
- Os modelos e cartões apresentam cancelamento/estorno; a tela Pix remove QR e simulação quando já existe estorno. Os avisos de cancelamento direcionam ao histórico.

## Evidências executadas

Os testes unitários usam mocks. O teste SQL executa os gatilhos reais da migração em PostgreSQL, com tabelas sintéticas mínimas e um registrador de notificações substituto, sem broadcasts. No modo de concorrência, usa duas conexões e barreiras observadas por `pg_blocking_pids`, em um esquema exclusivo descartado ao final. Não é um teste HTTP ou E2E da aplicação completa.

| ID | Requisito/fonte | Camada | Preparação e ação | Esperado | Observado | Estado | Evidência |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CAN-01 | Regra aprovada: preservar quem pagou | Unidade NestJS | Motorista e passageiro tentam cancelar pedido ACEITO/PAID | Bloquear sem devolver vaga nem salvar pedido | As duas variantes bloqueadas | PASSOU | `solicitacoes.service.spec.ts` |
| CAN-02 | Preservar estados encerrados | Unidade NestJS | Cancelar FINALIZADA, EM_ANDAMENTO, ENCERRADA_POR_TEMPO e EXPIRADA | Recusar e manter estado | Quatro variantes preservadas | PASSOU | `caronas.service.spec.ts` |
| CAN-03 | Cancelamento integral | PostgreSQL isolado | Carona com pedido pago, aceito não pago e pendente; cancelar | Todos cancelados, PAID preservado e avisos distintos | Três pedidos encerrados, quatro avisos incluindo motorista | PASSOU | Cenário SQL 1 |
| CAN-04 | Idempotência | PostgreSQL isolado | Repetir cancelamento e PAID, tentar limpar data do estorno | Nenhum efeito duplicado | Data e número de avisos preservados | PASSOU | Cenário SQL 2 |
| CAN-05 | Confirmação tardia | PostgreSQL isolado | Cancelar carona antes de PAID | Estornar na simulação sem reativar | Cancelamento preservado, aviso de estorno único | PASSOU | Cenário SQL 3 |
| CAN-06 | Expiração | PostgreSQL isolado | Expirar pedido antes de PAID | Compensação simulada sem nova vaga | Pedido permanece EXPIRADO | PASSOU | Cenário SQL 4 |
| CAN-07 | Cancelamento antes da confirmação | PostgreSQL isolado | Cancelar pedido individual antes de PAID | Compensação simulada sem reativar | Pedido permanece cancelado | PASSOU | Cenário SQL 5 |
| CAN-08 | Não alterar pagamento válido | PostgreSQL isolado | Confirmar PAID de reserva ativa | Fluxo normal sem estorno | Dois avisos normais de pagamento; sem estorno | PASSOU | Cenário SQL 6 |
| CAN-09 | Reutilização de pedido | PostgreSQL isolado e unidade | Reutilizar pedido cancelado; confirmar tentativa antiga | Não pagar nova reserva com tentativa anterior | Tentativa antiga estornada e nova permanece PENDING; API bloqueia simulação antiga | PASSOU | Cenário SQL 7; `pagamentos.service.spec.ts` |
| CAN-10 | Atomicidade | PostgreSQL isolado | Cancelar e desfazer transação | Nenhum efeito parcial | Carona, pedido, estorno e avisos revertidos | PASSOU | Cenário SQL 8 |
| CAN-11 | Preservação no banco | PostgreSQL isolado | Tentar cancelar três estados iniciados/encerrados | Banco recusa mudança | Três variantes recusadas com 23514 | PASSOU | Cenário SQL 9 |
| CAN-12 | Confirmação concorrente primeiro | Duas conexões PostgreSQL | Segurar pagamento bloqueado; cancelar em outra transação; confirmar e liberar | Cancelamento não perde compensação | PAID preservado, pedido cancelado e estorno presente | PASSOU | Cenário SQL 10 |
| CAN-13 | Cancelamento concorrente primeiro | Duas conexões PostgreSQL | Cancelar sem commit; tentar confirmar em outra conexão; liberar | Confirmação observa encerramento | Pedido segue cancelado com estorno; sem aviso normal de PAID | PASSOU | Cenário SQL 11 |
| CAN-14 | Interface aprovada | Widget/modelos Flutter | Diálogo voltar/confirmar, PAID antigo com cancelamento e tela Pix estornada | Confirmação explícita, cancelamento visível e sem QR/ação | Cinco novos testes passaram | PASSOU | `cancelamento_estorno_simulado_test.dart` |
| CAN-15 | Integração da consulta nova | TypeORM + banco configurado, leitura | Executar consulta real com ID inexistente | Colunas e aliases válidos | Consulta concluída e quatro gatilhos ativos | PASSOU | Verificação de leitura após migração |
| CAN-16 | Avisos no aparelho e Realtime | E2E físico | Testar com duas contas após publicar código e atualizar app | Ver avisos, histórico e bloqueios no celular | Não executado nesta alteração | NAO_EXECUTADO | Depende da publicação e do novo app |
| CAN-17 | Devolução financeira real | Provedor real | Não aplicável ao protótipo | Nenhuma movimentação real | Nenhuma API de reembolso implementada ou chamada | FORA_DO_ESCOPO | Regra do protótipo |

## Resultados gerais

- Backend: build aprovado; **751 testes / 51 suítes aprovados**. Resumo em `backend-final.txt`.
- Frontend: análise sem problemas e **1.990 testes aprovados**. Resumo em `frontend-final.txt`.
- ESLint: arquivos TypeScript alterados aprovados, sem executar correção global.
- PostgreSQL: 11 cenários SQL aprovados, incluindo duas intercalações concorrentes. O cenário de estados encerrados contém três variantes.
- Duas falhas iniciais em testes Flutter foram causadas pela procura do botão antigo EXCLUIR. O fluxo passou novamente após atualizar os testes para CANCELAR CARONA.
- Nenhum servidor/jobs da aplicação foi iniciado para esses testes. Nenhuma API de pagamento foi chamada.

## Banco e implantação

A migração `supabase/migrations/20261106120000_cancelamento_estorno_simulado.sql` foi aplicada ao banco configurado em 06/11/2026. Antes de executá-la, a função remota de notificações foi comparada com a versão anterior do Git: coincidia. Regularizou seis tentativas antigas encerradas; uma delas recebeu registro de estorno simulado. A contagem de caronas e solicitações foi preservada. Nenhum aviso retroativo foi gerado. Os esquemas sintéticos foram removidos.

Para outro banco, aplicar a migração inteira antes de publicar o backend. A estrutura SQL para instalações futuras também contém as duas novas colunas. O código permanece local, sem commit/push ou reinstalação nesta etapa. O comportamento completo no Render/aparelho depende da publicação.

## Arquivos e tamanho

Os serviços maiores já existiam. A nova regra de remoção individual foi extraída para um helper, e o aviso/diálogo do aplicativo foram compartilhados. Não houve separação ampla de arquivos ou alteração de fluxos fora deste pedido. O maior arquivo novo é o teste SQL; ele não é carregado pelo aplicativo.

| Arquivo | Linhas após alteração |
| --- | ---: |
| `backend/database/postgres/atualizacoes/criar_notificacoes.sql` | 238 |
| `backend/database/postgres/atualizacoes/criar_pagamentos.sql` | 62 |
| `backend/database/postgres/estrutura/schema.sql` | 845 |
| `backend/src/caronas/caronas.controller.ts` | 331 |
| `backend/src/caronas/caronas.service.spec.ts` | 594 |
| `backend/src/caronas/caronas.service.ts` | 666 |
| `backend/src/caronas/pagamentos-inicio.ts` | 33 |
| `backend/src/pagamentos/FLUXO.md` | 60 |
| `backend/src/pagamentos/README.md` | 199 |
| `backend/src/pagamentos/pagamento.entity.ts` | 98 |
| `backend/src/pagamentos/pagamentos-participacao.spec.ts` | 52 |
| `backend/src/pagamentos/pagamentos-participacao.ts` | 25 |
| `backend/src/pagamentos/pagamentos.controller.spec.ts` | 118 |
| `backend/src/pagamentos/pagamentos.controller.ts` | 97 |
| `backend/src/pagamentos/pagamentos.service.spec.ts` | 646 |
| `backend/src/pagamentos/pagamentos.service.ts` | 341 |
| `backend/src/solicitacoes/expiracao-solicitacoes.service.ts` | 181 |
| `backend/src/solicitacoes/solicitacao.entity.ts` | 92 |
| `backend/src/solicitacoes/solicitacoes.controller.ts` | 305 |
| `backend/src/solicitacoes/solicitacoes.service.spec.ts` | 637 |
| `backend/src/solicitacoes/solicitacoes.service.ts` | 545 |
| `backend/test/cancelamento-estorno-temporario.cjs` | 427 |
| `frontend/lib/home/detalhes_carona.dart` | 645 |
| `frontend/lib/home/pagamento_pix.dart` | 452 |
| `frontend/lib/home/tela_inicial.dart` | 597 |
| `frontend/lib/models/pagamento_pix.dart` | 86 |
| `frontend/lib/models/solicitacao_enviada.dart` | 167 |
| `frontend/lib/models/solicitacao_recebida.dart` | 137 |
| `frontend/lib/widgets/aviso_estorno_simulado.dart` | 16 |
| `frontend/lib/widgets/card_solicitacao_enviada.dart` | 274 |
| `frontend/lib/widgets/card_solicitacao_recebida.dart` | 257 |
| `frontend/lib/widgets/dialogo_cancelar_carona.dart` | 28 |
| `frontend/test/avisos_caronas_solicitacoes_test.dart` | 507 |
| `frontend/test/cancelamento_estorno_simulado_test.dart` | 120 |
| `supabase/migrations/20261106120000_cancelamento_estorno_simulado.sql` | 273 |

## Reproduzir os testes isolados

- Backend, pasta `backend`: `npm run build` e `node node_modules/jest/bin/jest.js --runInBand`.
- Frontend, pasta `frontend`: `flutter analyze --no-pub` e `flutter test --no-pub`.
- SQL, pasta `backend`, em banco de teste autorizado: `node test/cancelamento-estorno-temporario.cjs` usa somente `pg_temp`; `--concorrencia` cria um esquema sintético exclusivo e o remove ao terminar. O arquivo lê a conexão do `.env` sem exibir credenciais. Não iniciar o AppModule para executar esses casos.
