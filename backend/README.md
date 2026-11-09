# BuscaEu — backend

API em **NestJS, TypeScript e Node.js**, com **TypeORM e PostgreSQL**. Centraliza as regras de negócio e as operações de persistência do aplicativo.

[Voltar ao projeto](../README.md) · [Guia da Parte 4](../docs/PARTE_4_IMPLEMENTACAO.md)

## Organização do código

| Pasta em `src/` | Responsabilidade |
|---|---|
| `auth/` | Validação do token Supabase e identificação do usuário da aplicação |
| `users/` | Perfil, veículo, fotos e conferência dos dados extraídos da CNH |
| `caronas/` | Ofertas, recorrências, vagas e ciclo de vida da viagem |
| `solicitacoes/` | Pedidos, aceite, recusa, cancelamento e expiração |
| `pagamentos/` | Pix Dev Mode, tentativas, webhook e estornos simulados |
| `mensagens/` | Conversas e mensagens entre participantes |
| `notificacoes/` | Avisos internos |
| `avaliacoes/` | Avaliações e resumo de reputação |
| `instituicoes/` | Instituições e destinos acadêmicos |
| `rotas/` | Cálculo de percurso pela integração com OpenRouteService |
| `database/` | Conversores de tipos utilizados nas entidades |

A composição dos módulos e a conexão com o banco ficam em [app.module.ts](src/app.module.ts). A inicialização HTTP fica em [main.ts](src/main.ts).

## Camadas de uma operação

- **Controller:** recebe a requisição, valida os dados de entrada e monta a resposta.
- **Guard:** valida a autenticação e identifica o usuário.
- **Service:** aplica autorização e regras de negócio.
- **Entity / Repository:** mapeia os dados e executa consultas e gravações.
- **Transação:** mantém relacionadas as alterações que precisam ser confirmadas juntas.

Exemplo completo: [aceitar uma solicitação](../docs/PARTE_4_IMPLEMENTACAO.md). O service verifica o motorista, o estado do pedido e a disponibilidade; bloqueia as linhas durante a transação, reduz a vaga e grava a resposta e a conversa.

## Autenticação

O Supabase Auth gerencia a autenticação e a sessão. O aplicativo envia o access token no header `Authorization: Bearer <token>`.

O [JwtAuthGuard](src/auth/jwt-auth.guard.ts) usa o [SupabaseAuthService](src/auth/supabase-auth.service.ts) para consultar `auth.getUser(token)` e associa o identificador do Auth ao usuário de domínio. JWT é o formato do token; não é um segundo sistema independente de login. A autorização sobre cada recurso também é verificada nos services.

## Configuração local

Use Node.js compatível com NestJS 11 (Node 20 ou superior), npm e acesso ao PostgreSQL e aos serviços configurados para o projeto.

Crie `backend/.env` localmente. Os principais nomes utilizados pelo código são:

| Grupo | Variáveis |
|---|---|
| API | `PORT` (padrão 3000) |
| PostgreSQL | `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`, `DB_DATABASE`, `DB_SCHEMA` |
| TLS do banco | `DB_SSL`, `DB_SSL_REJECT_UNAUTHORIZED` |
| Supabase Auth | `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` |
| Fotos | `SUPABASE_SECRET_KEY`, `SUPABASE_PROFILE_BUCKET` |
| Rotas | `OPENROUTESERVICE_API_KEY` |
| Pix de teste | `ABACATEPAY_API_KEY`, `ABACATEPAY_WEBHOOK_SECRET` |

Essa lista cobre os principais serviços, não todas as opções do projeto. Use os valores e requisitos do ambiente da equipe. Senhas e chaves secretas ficam somente no servidor e nunca devem aparecer no repositório, nos slides ou na gravação.

```bash
npm ci
npm run start:dev
```

Para compilar e iniciar o código compilado:

```bash
npm run build
npm run start:prod
```

A configuração utiliza `synchronize: false`: iniciar a API não cria ou atualiza automaticamente as tabelas. Consulte o [guia do banco](database/README.md) antes de preparar outro ambiente.

## Testes

```bash
npm test -- --runInBand
npm run test:cnh:http
npm run build
```

- `src/**/*.spec.ts`: testes unitários junto aos módulos.
- `test/verificacao-cnh.e2e-spec.ts`: teste HTTP com autenticação e conferência simuladas.
- `npm run test:cov`: gera relatório de cobertura; cobertura não é apresentada aqui como resultado já medido.
- `npm run lint`: executa ESLint **com correção automática**, conforme o script atual.

Os testes isolados não comprovam por si só o funcionamento do banco, do OCR nativo, do GPS ou dos provedores reais. Evidências complementares estão em [entregas](../entregas/testes-buscaeu/).

## Referências do próprio projeto

- [Regras de pagamento e cancelamento](src/pagamentos/FLUXO.md)
- [Integração Pix](src/pagamentos/README.md)
- [Conferência da CNH](src/users/FLUXO_CNH.md)
- [Fotos de perfil](src/users/FOTO_PERFIL.md)
