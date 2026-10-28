# Relatório de Avaliação de Segurança

## 1. Identificação

- **Sistema:** UniCarona — aplicativo de caronas universitárias (TCC). Backend em NestJS/Node.js com PostgreSQL (via Supabase) e aplicativo móvel em Flutter/Dart.
- **Data:** 15/09/2026
- **Tipo de análise:** análise estática de código e configuração.

## 2. Resumo executivo

O projeto apresenta uma base de segurança razoável para um TCC: autenticação centralizada por JWT validada contra o Supabase, controle de propriedade (ownership) em quase todas as rotas, validação manual de entradas, consultas parametrizadas (TypeORM), upload com verificação de conteúdo (magic bytes) e políticas de acesso restritas no banco de dados.

Os principais riscos estão concentrados em **segredos no código-fonte** (chave HMAC do webhook de pagamento embutida no repositório), **endpoint não autenticado que encaminha requisições para uma API paga externa** (`/rotas/calcular`), **exposição de placas de veículo** em endpoints de listagem e **ausência de controles transversais** (rate limiting, TLS em produção, cabeçalhos de segurança).

Quantidade de achados por severidade:

| Severidade | Quantidade |
|------------|-----------|
| Crítica    | 0         |
| Alta       | 1         |
| Média      | 6         |
| Baixa      | 4         |
| Informativa| 4         |

## 3. Escopo e limitações

**Diretórios e arquivos analisados:**

- `backend/src` — todos os módulos: `auth`, `users` (incluindo `foto-perfil.service.ts`), `caronas`, `solicitacoes`, `mensagens`, `avaliacoes`, `instituicoes`, `rotas`, `pagamentos` (incluindo webhook AbacatePay), `main.ts` e `app.module.ts`.
- `backend/database` — `schema.sql` (Postgres) e scripts de `atualizacoes` (supabase auth, chat, pagamentos).
- `backend/.env` — verificação da presença de variáveis (nomes apenas; valores não reproduzidos neste relatório).
- `.github/workflows/ci.yml` — pipeline de integração contínua.
- `frontend/lib` — configurações (`api_config`, `supabase_config`), serviços (auth, sessão, caronas, solicitações, mensagens, pagamentos, instituições, e-mail, rotas), telas de autenticação, validações de senha/e-mail e manifest Android.

**Tecnologias:** NestJS 11, TypeORM 0.3, PostgreSQL/Supabase, Flutter/Dart, supabase_flutter 2.x, flutter_secure_storage, http.

**Limitações:**

- Não foi possível inspecionar as configurações do projeto Supabase fora deste repositório (políticas RLS das tabelas não-pagamento, templates de e-mail, limites de GoTrue). As políticas vistas em `schema.sql` cobrem apenas pagamentos e o chat em tempo real.
- Não foi possível validar em execução o comportamento do webhook e do fluxo Pix, pois as variáveis `ABACATEPAY_API_KEY` e `ABACATEPAY_WEBHOOK_SECRET` **não estão presentes no `.env`** analisado.
- Análise exclusivamente estática; não foram executados ataques nem alterações no sistema.
- `backend/node_modules` e `frontend/build` não foram analisados; dependências com faixas `^` (ex.: `@nestjs/*`, `typeorm`, `supabase-js`, `pg`) devem ser conferidas com `npm audit`/`flutter pub outdated` antes de publicar.

## 4. Achados

### [ALTA] Chave criptográfica usada na assinatura do webhook hardcoded no código-fonte

- **Área:** pagamentos (webhook), proteção de segredos.
- **Evidência:** `backend/src/pagamentos/abacatepay-webhook.service.ts:18-19` define `ABACATEPAY_PUBLIC_HMAC_KEY` com um valor longevo (~300 caracteres, aparenta base64) diretamente no código, e a assinatura é calculada em `abacatepay-webhook.service.ts:117-119` com `createHmac('sha256', ABACATEPAY_PUBLIC_HMAC_KEY)`. O repositório é versionado e de acesso amplo (TCC).
- **Impacto:** se o valor exposto for realmente a chave usada para assinar os eventos, qualquer pessoa com acesso ao repositório consegue forjar a assinatura `x-webhook-signature`. Embora exista uma compensação (a assinatura é confirmada via consulta reversa à AbacatePay em `abacatepay-webhook.service.ts:83-92` e a validação exige `PAID`), a prática de embutir segredos no código viola o princípio de gestão de segredos e amplia superfície de ataque.
- **Recomendação:** mover a chave HMAC para variável de ambiente (ex.: `ABACATEPAY_WEBHOOK_HMAC_KEY`) lida via `ConfigService`; não rotular segredos de assinatura como "public". Rotacionar o valor caso ele já tenha sido publicado.
- **Prioridade:** Alta.

### [MÉDIA] Placa do veículo exposta em endpoints de listagem de caronas

- **Área:** API, proteção de dados (LGPD).
- **Evidência:** em `backend/src/caronas/caronas.controller.ts`, `criarCarona/atualizarCarona/iniciar/finalizar` usam `this.formatarCarona(...)`, que mascara a placa com `this.mascararPlaca(...)` (`caronas.controller.ts:425` e `:448-451`). Porém, `listarCaronas` e `listarMinhasCaronas` retornam a entidade crua (`dados: caronas`, `caronas.controller.ts:156-157` e `:168-169`) e a query em `caronas.service.ts:341-347` e `:409-415` faz `select([..., 'veiculo', ...])`, devolvendo a placa completa. O modelo do app consome esse campo em `frontend/lib/models/carona.dart:131` e exibe a placa em `frontend/lib/widgets/conteudo_detalhes_carona.dart:135-136`, ou seja, qualquer usuário autenticado vê a placa integral de todos os motoristas.
- **Impacto:** exposição de dado pessoal (placa — dado de veículo) a todos os usuários autenticados, de forma inconsistente com a máscara usada nos demais endpoints, com potencial classificação como tratamento irregular sob a LGPD.
- **Recomendação:** aplicar a mesma máscara nas listagens (ex.: reutilizar `formatarCarona`/`mascararPlaca` ou projetar apenas `modelo` e `cor`); considerar não expor a placa até o embarque confirmado.
- **Prioridade:** Média.

### [MÉDIA] Endpoint de cálculo de rota sem autenticação encaminha requisições para API paga externa

- **Área:** API, custo/DoS.
- **Evidência:** `backend/src/rotas/rotas.controller.ts` (`@Post('rotas/calcular')`) não possui `@UseGuards(JwtAuthGuard)` e `backend/src/rotas/rotas.service.ts:13-42` envia o corpo recebido (coordenadas) para `api.heigit.org/openrouteservice` usando `process.env.OPENROUTESERVICE_API_KEY`. Não há limite de quantidade de pontos, validação de faixa de coordenadas nem autenticação.
- **Impacto:** qualquer pessoa pode disparar chamadas anônimas em massa contra a API paga de terceiro usando a chave do servidor, causando esgotamento de cota e custo financeiro (furto de serviço), além de consumo de banda do backend.
- **Recomendação:** proteger a rota com `JwtAuthGuard`; validar tipo, quantidade (ex.: `2..200`) e faixa das coordenadas; aplicar rate limiting específico.
- **Prioridade:** Média.

### [MÉDIA] Comunicação com a API sem TLS por padrão (HTTP em claro)

- **Área:** configuração, transporte.
- **Evidência:** `frontend/lib/config/api_config.dart:4-9` usa `http://10.0.2.2:3000` como `defaultValue` da `API_BASE_URL`; `backend/src/main.ts:7` faz `app.listen(..., '0.0.0.0')` sem `helmet`, `enableCors` ou TLS; e o `AndroidManifest.xml` de produção (`frontend/android/app/src/main/AndroidManifest.xml`) não define `usesCleartextTraffic`, de modo que em release o Android 9+ bloqueará o HTTP em claro (ou exigirá liberação insegura).
- **Impacto:** nesse cenário, o token de acesso (`Authorization: Bearer`) e dados pessoais trafegariam em texto plano em produção/redes públicas, viabilizando captura de sessão; o padrão HTTP também impede o uso futuro em web.
- **Recomendação:** em produção, servir a API somente por HTTPS (reverse proxy com TLS), manter `usesCleartextTraffic` desabilitado e injetar `API_BASE_URL=https://...` via `--dart-define`, sem defaultValue HTTP nos builds de release.
- **Prioridade:** Média.

### [MÉDIA] Ausência de rate limiting nas rotas autenticadas

- **Área:** API, disponibilidade.
- **Evidência:** não há nenhum uso de `@nestjs/throttler`, `express-rate-limit` ou equivalente em `backend/src` (grep por `throttl|RateLimit` sem resultados). Rotas como envio de mensagem (`mensagens.controller.ts:78-97`), criação/obtenção de Pix (`pagamentos.controller.ts:20-35`) e `atualizarPosicaoAtual` (`caronas.controller.ts:114-130`) podem ser chamadas repetidamente.
- **Impacto:** spam de mensagens no chat, abuso de chamadas à AbacatePay, ruído em transações e maior consumo de banco. Exige conta válida, mas não há teto por usuário.
- **Recomendação:** adotar throttling por IP e por usuário no gateway (ex.: `@nestjs/throttler`), e limites adicionais por endpoints sensíveis (Pix, mensagens, posição).
- **Prioridade:** Média.

### [MÉDIA] Segredo de webhook transmitido via query string na URL

- **Área:** configuração, pagamentos.
- **Evidência:** `backend/src/pagamentos/abacatepay-webhook.controller.ts:25` lê `@Query('webhookSecret')` e é comparado com `ABACATEPAY_WEBHOOK_SECRET` em `abacatepay-webhook.service.ts:95-111`.
- **Impacto:** segredos em parâmetros de URL podem aparecer em logs de proxies, gateways, CDNs e no histórico de ferramentas de monitoramento, vazando a credencial de autenticação do webhook.
- **Recomendação:** enviar o segredo exclusivamente em cabeçalho (ex.: `X-Webhook-Secret`) ou confiar apenas na assinatura HMAC; evitar segredos na query string.
- **Prioridade:** Média.

### [MÉDIA] Persistência de sessão do Supabase em armazenamento local não criptografado

- **Área:** frontend, proteção de tokens.
- **Evidência:** o app guarda token/usuario em `flutter_secure_storage` (`frontend/lib/services/sessao_service.dart:8-15`), o que é positivo. Porém, `frontend/lib/services/supabase_auth_service.dart:20-23` inicializa o Supabase sem `persistSession: false`; por padrão o `supabase_flutter` persiste a sessão em armazenamento local (shared_preferences) sem criptografia.
- **Impacto:** o token de acesso pode existir em dois lugares, um deles sem criptografia, aumentando o risco em caso de backup/extração de dados do dispositivo.
- **Recomendação:** desabilitar a persistência automática do SDK (`authOptions: PersistSessionOption` / `persistSession: false`) e manter única fonte no `flutter_secure_storage`, restaurando a sessão manualmente.
- **Prioridade:** Média.

### [BAIXA] Validação de entradas manual e ausência de DTOs/ValidationPipe global

- **Área:** validação de entradas / arquitetura.
- **Evidência:** `backend/src/main.ts` não registra `ValidationPipe` global e não há DTOs declarativos; as rotas usam `Record<string, unknown>` e validação manual (ex.: `caronas.controller.ts:172-382`, `solicitacoes.controller.ts`, `users.controller.ts`). Apesar de as verificações atuais serem minuciosas, o modelo é mais sujeito a inconsistências e a validações esquecidas em novos endpoints.
- **Impacto:** risco aumentado de rotas novas aceitarem payloads malformados; menor claridade sobre o contrato da API.
- **Recomendação:** adotar class-validator + `ValidationPipe` global com `whitelist: true, forbidNonWhitelisted: true` e DTOs por rota, mantendo as regras de negócio existentes.
- **Prioridade:** Baixa.

### [BAIXA] Cabeçalhos de segurança HTTP ausentes no backend

- **Área:** configuração / hardening.
- **Evidência:** `backend/src/main.ts` não aplica `helmet` (nem `X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security`, etc.) e não há configuração de CORS.
- **Impacto:** maior superfície para ataques baseados em navegador (sniffing de tipo, clickjacking) caso a API seja consumida por frontends web; hoje o consumo é nativo (Flutter), reduzindo o impacto.
- **Recomendação:** aplicar `helmet` e, se houver cliente web, configurar CORS com lista de origens permitidas e `credentials` adequadas.
- **Prioridade:** Baixa.

### [BAIXA] Exposição de mensagens internas de erro ao usuário final

- **Área:** frontend, tratamento de erro.
- **Evidência:** `frontend/lib/services/auth_service.dart:129-167` devolve `erro.message` do Supabase (AuthException) diretamente como mensagem ao usuário; `frontend/lib/services/email_verificacao_service.dart:21` e `:32-33` também retornam `erro.message`.
- **Impacto:** detalhes internos do provedor de autenticação podem ser revelados ao usuário, auxiliando reconhecimento de configurações do serviço.
- **Recomendação:** traduzir códigos/frases conhecidas e exibir uma mensagem genérica padrão para erros inesperados.
- **Prioridade:** Baixa.

### [BAIXA] Endpoint público de busca de instituições sem limite de uso

- **Área:** API.
- **Evidência:** `backend/src/instituicoes/instituicoes.controller.ts` é público (sem guard) e ilimitado; executar consultas parametrizadas em `instituicoes.service.ts`.
- **Impacto:** uso abusivo do endpoint (volume) eleva consumo de banco; exposição se limita a dados públicos do MEC, portanto risco baixo.
- **Recomendação:** aplicar rate limiting básico e, se desejado, exigir autenticação.
- **Prioridade:** Baixa.

### [INFORMATIVA] Integração de pagamentos AbacatePay incompleta/configuração ausente

- **Área:** pagamentos, configuração.
- **Evidência:** o `.env` analisado não contém `ABACATEPAY_API_KEY` nem `ABACATEPAY_WEBHOOK_SECRET` (nomes verificado, valores ocultos). Sem eles, `pagamentos.service.ts` e `abacatepay-webhook.service.ts:96-104` respondem `503`. O fluxo também força `modoTeste: true` (`abacatepay.service.ts:47-50`,`:159-166`) e bloqueia chaves `prod_`.
- **Impacto:** funcional — o fluxo Pix está indisponível ao vivo; não configura risco adicional, mas deve ser tratado antes de qualquer lançamento (a proteção de testes deverá ser removida de forma controlada).
- **Recomendação:** definir as variáveis em ambiente seguro e revisar (com o provedor) o modelo de produção — chave em variável de ambiente, remoção das travas `modoTeste`/`NODE_ENV` após validação, e rotação das chaves.
- **Prioridade:** Informativa.

### [INFORMATIVA] Variável `JWT_SECRET` não utilizada

- **Área:** configuração.
- **Evidência:** `backend/.env` define `JWT_SECRET`, mas não há `@nestjs/jwt` nem uso da variável no código (grep sem resultados), pois a autenticação é feita por Supabase (`auth/supabase-auth.service.ts`).
- **Impacto:** informação obsoleta que pode induzir a erro (suposição de assinatura local de tokens).
- **Recomendação:** remover a variável e documentar que o JWT é emitido/validado pelo Supabase.
- **Prioridade:** Informativa.

### [INFORMATIVA] Schema MySQL legado no repositório contendo coluna de senha

- **Área:** banco de dados (legado).
- **Evidência:** `backend/database/estrutura/schema.sql` (MySQL, fora de uso) define `senha VARCHAR(255)` e códigos de verificação em `usuarios` (`:44-64`). O schema atual Postgres (`backend/database/postgres/estrutura/schema.sql`) não possui essas colunas e o script `remover_autenticacao_antiga.sql` as remove.
- **Impacto:** baixo, pois não é a versão utilizada; porém confunde auditorias, pois aparenta repositório armazenar senhas.
- **Recomendação:** remover o schema legado ou marcá-lo explicitamente como descontinuado em texto.
- **Prioridade:** Informativa.

### [INFORMATIVA] Chave pública do Supabase e URL embutidas no aplicativo

- **Área:** frontend, proteção de segredos.
- **Evidência:** `frontend/lib/config/supabase_config.dart:4-11` embute `SUPABASE_URL` e a `publishableKey` (padrão `sb_publishable_...`) como `defaultValue`, ficando acessível no binário do app.
- **Impacto:** é esperado para clientes móveis (chave publicável). O risco real depende das políticas de RLS/PostgREST do projeto Supabase, que não podem ser verificadas aqui; as tabelas de pagamento já estão bloqueadas (`schema.sql` revoga `anon`/`authenticated`), mas é preciso garantir o mesmo para as demais tabelas (`usuarios`, `caronas`, `mensagens`, etc.).
- **Recomendação:** rever as políticas de RLS de todo o schema `unicarona` no painel Supabase e manter todas as tabelas de negócio acessíveis apenas pelo backend (role de serviço), removendo acesso `anon`/`authenticated` às APIs PostgREST não desejadas.
- **Prioridade:** Informativa.

## 5. Pontos positivos

- Autenticação centralizada: `JwtAuthGuard` valida o token contra o Supabase e resolve o usuário por `authId` antes de processar a rota (`backend/src/auth/jwt-auth.guard.ts`), com tratamento correto do cabeçalho `Authorization`.
- Controle de propriedade em toda a cadeia: caronas (`caronas.service.ts:432-455`), solicitações (`solicitacoes.service.ts:283-287`, `:387-391`), conversas/mensagens (`mensagens.service.ts:187-195`) e pagamentos (`pagamentos.service.ts:99`) verificam que o solicitante é dono/participante — o back-end não confia no `id` da URL.
- Validações consistentes de entrada: limites de comprimento, IDs inteiros positivos, faixas de coordenadas, notas 1–5, valores monetários e placa via regex (`users.controller.ts:58-74`, `caronas.controller.ts:172-382`, `avaliacoes.controller.ts:27-41`).
- Upload com verificação de conteúdo real (magic bytes de JPEG/PNG/WebP), limite de 5 MB e pasta por usuário no Supabase Storage (`users.controller.ts:133-177`, `foto-perfil.service.ts`).
- Webhook de pagamento com múltiplas camadas: HMAC + verificação do segredo + consulta reversa à AbacatePay exigindo `PAID` + idempotência por `id_evento` e locks pessimistas (`abacatepay-webhook.service.ts:53-204`).
- Transações com `pessimistic_write` para integridade de vagas e pagamentos (`solicitacoes.service.ts:276`, `pagamentos.service.ts:96`).
- Senhas fora do banco de aplicação (Supabase Auth) e coluna `senha` removida no schema Postgres.
- Banco seguro por padrão: RLS habilitado nas tabelas de pagamento e revogação de privilégios para `PUBLIC`, `anon` e `authenticated` no schema `unicarona` (`schema.sql:288-318`, `:484-496`).
- SQL parametrizado via TypeORM — não foram encontrados concatenações de entrada em queries (sem SQL Injection observada).
- App: token em `flutter_secure_storage`, `android:allowBackup="false"`, sem `usesCleartextTraffic` habilitado no manifest de produção, e logout/exclusão de sessão em `401`.
- CI sem segredos e com testes+build; `.env` corretamente ignorado pelo Git (nenhum `.env` rastreado).

## 6. Recomendações priorizadas

1. **Alta:** mover a chave HMAC do webhook para variável de ambiente e rotacioná-la; remover a dependência do `webhookSecret` da query string.
2. **Média:** proteger `POST /rotas/calcular` com autenticação e validar/limitar as coordenadas.
3. **Média:** mascarar a placa também nos endpoints `GET /caronas` e `GET /caronas/minhas`.
4. **Média:** garantir HTTPS apenas em produção (`--dart-define` com URL TLS, proxy reverso com TLS, `usesCleartextTraffic` desabilitado).
5. **Média:** adicionar rate limiting global e específico (mensagens, Pix, posição).
6. **Média:** desabilitar a persistência automática da sessão do Supabase no app e centralizar o token no `flutter_secure_storage`.
7. **Baixa:** adotar DTOs + `ValidationPipe` global com `whitelist`; aplicar `helmet`; padronizar mensagens de erro ao cliente.
8. **Informativa:** revisar RLS de todas as tabelas no painel do Supabase; configurar/resolver as variáveis da AbacatePay antes de qualquer lançamento; limpar `JWT_SECRET` e schema MySQL legado.

## 7. Conclusão

O UniCarona demonstra boas práticas de segurança em arquitetura — autenticação centralizada, autorização por propriedade, validação de entradas, uploads verificados por conteúdo e proteções no banco — o que coloca o núcleo funcional do sistema em nível adequado para um trabalho de conclusão de curso. Os pontos que merecem correção imediata são a exposição da chave de assinatura do webhook no código e o endpoint de rota sem autenticação; em seguida, as correções de médio impacto (máscara de placa, TLS, rate limiting e persistência de sessão) elevariam o nível de segurança para produção. Não foram identificadas vulnerabilidades críticas comprovadas, mas dois achados (segredo no código e abuso do endpoint de rota) devem ser tratados antes de qualquer publicação para usuários reais.