# Banco de dados do BuscaEu

A versão atual usa **PostgreSQL no Supabase**, com entidades TypeORM e schema de domínio `unicarona`.

[Voltar ao backend](../README.md)

## Onde encontrar

| Caminho | Uso |
|---|---|
| [postgres/estrutura/schema.sql](postgres/estrutura/schema.sql) | Referência da estrutura PostgreSQL |
| [postgres/atualizacoes/](postgres/atualizacoes/) | Scripts e notas das alterações históricas do PostgreSQL |
| [postgres/cargas/](postgres/cargas/) | Cargas de instituições e campi |
| [../../supabase/migrations/](../../supabase/migrations/) | Migrações incrementais mais recentes, incluindo regras de percurso e estorno simulado |
| [consultas/conferir_banco.sql](consultas/conferir_banco.sql) | Consulta histórica; conferir dialeto e compatibilidade antes do uso |

As pastas fora de `postgres/` preservam materiais de fases anteriores, inclusive da migração de banco. Elas não devem ser tratadas como instruções atuais de instalação.

## Entidades no código

- [Carona](../src/caronas/carona.entity.ts)
- [Solicitação](../src/solicitacoes/solicitacao.entity.ts)
- [Conversa](../src/mensagens/conversa.entity.ts)
- [Pagamento](../src/pagamentos/pagamento.entity.ts)
- [Usuário](../src/users/user.entity.ts)

A conexão está em [app.module.ts](../src/app.module.ts), com `synchronize: false`.

## Preparação de ambiente

Os scripts registram a evolução do projeto; não formam, por si só, um instalador automático único. Antes de preparar outro banco, confronte a estrutura-base com as atualizações já incorporadas e as migrações posteriores. Revise as pré-condições de cada alteração e execute apenas o que falta no ambiente de destino.

Não reexecute o schema completo no banco já utilizado pela equipe. As notas específicas do [fluxo de pagamentos](../src/pagamentos/FLUXO.md) indicam as migrações exigidas por essa funcionalidade.

Na apresentação, entidades, relacionamentos e a transação de aceite explicam a persistência. Mostre somente dados de demonstração e mantenha credenciais fora da gravação.
