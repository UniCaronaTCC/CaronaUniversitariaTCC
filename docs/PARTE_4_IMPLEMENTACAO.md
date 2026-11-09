# Parte 4 — implementação do BuscaEu

Guia de navegação pelo repositório para preparar os slides narrados da pré-banca de **TDS**. A demonstração do aplicativo funcionando pertence à Parte 3; aqui o foco é mostrar como a implementação produz aquele comportamento.

Os códigos podem aparecer como recortes legíveis em slides. Identifique o arquivo e a função, preserve a lógica do trecho e explique a ligação com o restante do fluxo. Não é necessário navegar ao vivo pelo editor.

[Índice da documentação](README.md) · [Projeto](../README.md)

## 1. Organização do projeto

Mostre a separação entre `frontend/`, `backend/`, `supabase/migrations/` e testes.

No backend, use [app.module.ts](../backend/src/app.module.ts) para localizar os módulos. Explique o papel de controller, guard, service, entidade e repository usando a mesma operação, sem percorrer todos os arquivos.

Referências: [backend](../backend/README.md), [Flutter](../frontend/README.md) e [banco](../backend/database/README.md).

## 2. Fluxo completo: motorista aceita uma solicitação

**Cenário:** já existe uma carona com vaga e um pedido pendente de outro estudante. O motorista toca em aceitar.

| Etapa | Código para mostrar | O que explicar |
|---|---|---|
| Ação na interface | [painel_solicitacoes_carona.dart](../frontend/lib/widgets/painel_solicitacoes_carona.dart), `onAceitar` e `responder` | O clique inicia a operação e a tela sinaliza o processamento |
| Requisição HTTP | [solicitacao_service.dart](../frontend/lib/services/solicitacao_service.dart), `responderSolicitacao` | Envia PATCH, JSON e token Bearer; interpreta a resposta |
| Autenticação | [jwt-auth.guard.ts](../backend/src/auth/jwt-auth.guard.ts), `canActivate` | Identifica o usuário a partir do token validado pelo Supabase |
| Entrada na API | [solicitacoes.controller.ts](../backend/src/solicitacoes/solicitacoes.controller.ts), `responderSolicitacao` | Valida identificador e resposta; utiliza o usuário autenticado |
| Regras e gravação | [solicitacoes.service.ts](../backend/src/solicitacoes/solicitacoes.service.ts), `responderSolicitacao` | Confere motorista, pedido pendente e vagas; aplica transação e bloqueio |
| Mapeamento do banco | [solicitacao.entity.ts](../backend/src/solicitacoes/solicitacao.entity.ts), [carona.entity.ts](../backend/src/caronas/carona.entity.ts) e [conversa.entity.ts](../backend/src/mensagens/conversa.entity.ts) | Mostra os relacionamentos que permitem persistir o resultado |
| Retorno à interface | Os mesmos controller, service Flutter e painel | A API devolve JSON; o aplicativo mostra a mensagem e recarrega os dados |

### Requisição do exemplo

```http
PATCH /solicitacoes/123/status
Authorization: Bearer <token-de-acesso>
Content-Type: application/json

{"status":"ACEITA"}
```

O identificador é ilustrativo. Não exponha um token real no material.

### Trechos mais úteis da regra

Na função `responderSolicitacao`, destaque em recortes separados:

1. `dataSource.transaction` e `setLock('pessimistic_write', ...)`: a operação bloqueia solicitação e carona durante a transação para proteger a alteração das vagas.
2. Verificação do motorista, status `PENDENTE` e disponibilidade da carona.
3. `vagas -= 1`, mudança para `LOTADA` quando necessário, `save` da carona e da solicitação e criação da conversa.

Um ponto sugerido pelo passageiro torna-se oficial após o aceite. O aceite também prepara o prazo de pagamento quando aplicável; **aceitar não significa que o Pix já foi pago**.

Para as regras atuais de prazo, pagamento confirmado antes da partida e cancelamento, use [FLUXO.md](../backend/src/pagamentos/FLUXO.md).

## 3. Autenticação, autorização e erros

Mostre a relação entre:

- [supabase_auth_service.dart](../frontend/lib/services/supabase_auth_service.dart): integração do aplicativo com Auth.
- [auth_service.dart](../frontend/lib/services/auth_service.dart): uso e restauração da sessão no aplicativo.
- [supabase-auth.service.ts](../backend/src/auth/supabase-auth.service.ts): consulta `auth.getUser(token)`.
- [jwt-auth.guard.ts](../backend/src/auth/jwt-auth.guard.ts): associa Auth ao usuário de domínio.
- [solicitacoes.service.ts](../backend/src/solicitacoes/solicitacoes.service.ts): verifica quem pode responder ao pedido.

**Explicação:** Supabase Auth é o serviço de autenticação; JWT é o formato do access token usado nas requisições. A sessão autenticada não dá autorização para alterar qualquer carona.

Como exemplo de erro, mostre `ConflictException` para pedido já respondido ou falta de vagas, o tratamento em `_tratarErro` no service Flutter e a mensagem apresentada pelo painel. Isso liga a validação do backend ao retorno que o usuário vê.

## 4. Integrações e decisões técnicas

Escolha trechos que comprovem as decisões mais relevantes, sem repetir a visão geral da Parte 2.

| Tema | Referências | Ponto principal |
|---|---|---|
| Persistência | [app.module.ts](../backend/src/app.module.ts) e o fluxo de aceite | Mapeamento TypeORM e transação PostgreSQL para alterações relacionadas |
| Pix | [pagamentos.service.ts](../backend/src/pagamentos/pagamentos.service.ts), [abacatepay-webhook.service.ts](../backend/src/pagamentos/abacatepay-webhook.service.ts) e [FLUXO.md](../backend/src/pagamentos/FLUXO.md) | Criação e confirmação em Dev Mode; validação e tratamento de repetição do evento |
| Rotas | [rotas.service.ts](../backend/src/rotas/rotas.service.ts) | Chamada ao OpenRouteService, tratamento de falhas e conversão das coordenadas |
| CNH | [ocr_cnh_mobile.dart](../frontend/lib/services/ocr_cnh_mobile.dart) e [FLUXO_CNH.md](../backend/src/users/FLUXO_CNH.md) | OCR no dispositivo e conferência interna, sem consulta oficial |
| Comunicação | [mensagens/](../backend/src/mensagens/) e [mensagem_service.dart](../frontend/lib/services/mensagem_service.dart) | Persistência das conversas e integração com atualização por Realtime |

## 5. Testes e GitHub

Mostre exemplos ligados ao que acabou de explicar:

| Evidência | Arquivo | Alcance |
|---|---|---|
| Regra de solicitação e aceite | [solicitacoes.service.spec.ts](../backend/src/solicitacoes/solicitacoes.service.spec.ts) | Casos de aceite/recusa, vagas e pontos com repositories e transação simulados |
| Autenticação | [jwt-auth.guard.spec.ts](../backend/src/auth/jwt-auth.guard.spec.ts) | Validação do guard com dependências controladas |
| Comunicação Flutter–API | [solicitacao_recebida_service_test.dart](../frontend/test/solicitacao_recebida_service_test.dart) | Requisições e respostas do service em teste |
| HTTP da CNH | [verificacao-cnh.e2e-spec.ts](../backend/test/verificacao-cnh.e2e-spec.ts) | Endpoints com autenticação e conferência simuladas; não executa OCR real |
| Integração contínua | [ci.yml](../.github/workflows/ci.yml) | Testes e builds automáticos a cada alteração nas branches configuradas |
| Evidência complementar | [relatórios](../entregas/testes-buscaeu/) | Resultados por versão, ambiente e limitações |

Ao mostrar o GitHub, apresente a branch `desenvolvimento`, as pastas, um commit relevante e uma execução de Actions correspondente à versão escolhida. Use resultados de testes já executados e identificados; não apresente testes simulados como prova de funcionamento integral dos serviços externos.

## Preparar os recortes para os slides

- Separe a operação em interface, requisição, API/regra, persistência e retorno.
- Mostre funções curtas ou recortes, com fonte legível; evite um arquivo inteiro em miniatura.
- Use setas e o nome do arquivo para ligar os trechos.
- Diferencie o que o código faz, o que o teste simula e o que foi demonstrado no aplicativo.
- Termine com a relação entre organização do repositório, testes e manutenção do projeto.
