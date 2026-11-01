# Metadados dos destinos de campus: primeira etapa

## Escopo

Prepara endereco e identificacao visual da unidade, sem mudar a selecao no app.
Nao inclui seed, novos campi, troca de nomes internos ou ajuste de coordenadas.

- `rotulo_unidade`: VARCHAR(150), opcional.
- `endereco_completo`: VARCHAR(500), opcional.
- `/instituicoes/destinos` retorna `rotuloUnidade` e `enderecoCompleto`, ou null
  quando nao preenchidos. Os campos atuais permanecem iguais.
- `campus` continua sendo o nome interno validado nos perfis.
- A estrutura pode ser reutilizada nacionalmente; a futura carga inicial sera
  limitada aos dados conferidos de Aracatuba/SP.

## Ordem obrigatoria de implantacao

1. Aplicar `supabase/migrations/20261101202707_adicionar_metadados_destinos_campi.sql`
   antes de publicar ou iniciar o backend desta branch contra o banco compartilhado.
2. Conferir as duas colunas opcionais e a preservacao dos registros existentes.
3. Publicar o backend. Aplicativos antigos ignoram os dois campos adicionais.
4. Em outra etapa, carregar somente enderecos/pontos aprovados e adaptar a lista.

A migration nao e executada automaticamente pelo backend (`synchronize: false`).
O script de estrutura atende bancos novos; nao substitui a migration para bancos
existentes. Nao fazer merge/deploy do backend antes de preparar o banco.

## Compatibilidade e reversao

Os campos novos nao sao obrigatorios, nao possuem valor padrao e nao modificam
registros, IDs, nomes, coordenadas, regras de acesso, perfis ou caronas existentes.
Reaplicar a migration nao apaga metadados que ja tenham sido preenchidos.
Endereco preenchido nao torna um campus sem coordenadas selecionavel diretamente.

Se for necessario voltar a versao anterior do backend, as colunas opcionais podem
permanecer no banco. Nao remover colunas como parte automatica da reversao: uma
futura carga pode conter informacoes que seriam perdidas.

## Verificacao

Testes de destinos cobrem retorno dos campos novos, ausencia/vazio, coordenadas
ausentes, unidades distintas, preservacao de nomes/ordenacao e uso em outra UF.
Testes de perfil preservam a validacao pelo nome interno, nao pelo rotulo.
A migration tambem deve ser testada em PostgreSQL isolado antes da implantacao.

Verificacao local em 01/11/2026, na branch `feature/campi-aracatuba`:

- 615 testes do backend aprovados, em 44 suites.
- 102 testes Flutter de modelo, servico, selecao, integracao e layout de destinos
  aprovados, sem alteracao de codigo do aplicativo.
- Compilacao TypeScript sem emissao e ESLint dos arquivos alterados aprovados.
- Dez cenarios de PostgreSQL isolado em memoria (PGlite 0.5.14): campos opcionais,
  preservacao de dados e de outras cidades, perfis/caronas, reaplicacao com dados
  preenchidos, inserts antigos, unicidade, chave estrangeira, limites de tamanho,
  consulta gerada pela entidade TypeORM e estrutura de banco novo.

O teste isolado nao acessa o Supabase e nao substitui a verificacao posterior no
servidor. Nenhuma migration ou seed foi aplicada ao banco compartilhado nesta
etapa. Nao houve teste manual no celular nem geracao de APK.
